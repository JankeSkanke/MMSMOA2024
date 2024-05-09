Add-Type -AssemblyName System.Web

function Send-LogAnalyticsData {
    <#
   .SYNOPSIS
       Send log data to Log Azure Montior using Log Ingestion API

   .DESCRIPTION
        Send log data to Log Azure Montior using Log Ingestion API
   
   .NOTES
       Author:      Jan Ketil Skanke
       Contact:     @JankeSkanke
       Created:     2022-01-14
       Updated:     2023-11-13
   
       Version history:
        1.0.0 - (2022-01-14) Function created
        2.0.0 - (2023-11-13) Moving from HTTP Collector API to Log Ingestion API
   #>
    param(
        $Body, 
        $Table, 
        $dcrImmutableId,
        $dceEndpoint,
        $headers
    )  
    
    #Construct header
    
    # Construct URI for Data Collection Endpoint
    $uri = "$($dceEndpoint)/dataCollectionRules/$($dcrImmutableId)/streams/Custom-$($Table)_CL"+"?api-version=2021-11-01-preview"
    #Write-Information "Using URI: $($uri)"
    # Validate that payload data does not exceed limits
    if($Body.Length -gt (1*1024*1024))
    {
        throw ("Upload payload is too big and exceed the 1mb limit for a single upload.  Please reduce the payload size.  Current payload size is: " + ($Body.Length/1024/1024).ToString("#.#") + "Mb")
    }
    $payloadsize = ("Upload payload size is " + ($Body.Length/1024).ToString("#.#") + "Kb")
    
    # Send data to Data Collection Endpoint for ingestion
    $Response = Invoke-WebRequest -Uri $uri -Method "Post" -Body $Body -Headers $headers -UseBasicParsing
    Write-Verbose "Response: $($Response)"
    $StatusMessage = "$($Response.StatusCode): $($payloadsize)"
    return $Statusmessage
}#end function

### Step 0: Set variables required for the rest of the script.

# information needed to authenticate to AAD and obtain a bearer token
$TenantID = ""  #Tenant ID the data collection endpoint resides in
$appId = "" # MMS_LA_loginjection - Application ID created and granted permissions
$appSecret = "" #Secret created for the application

# information needed to send data to the DCR endpoint
$dceEndpoint = ""
#the endpoint property of the Data Collection Endpoint object
$dcrImmutableId = "" #the immutableId property of the DCR object
$streamName = "" #name of the stream in the DCR that represents the destination table
### Step 1: Obtain a bearer token used later to authenticate against the DCE.

$scope= [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
$body = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials";
$headers = @{"Content-Type"="application/x-www-form-urlencoded"};
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$bearerToken = (Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers).access_token

### Step 2: Create some sample data.
#Some standard function for finding Entra Join information
function Get-EntraDeviceID {
	<#
    .SYNOPSIS
        Get the Entra device ID from the local device.
    
    .DESCRIPTION
        Get the Entra device ID from the local device.
    
    .NOTES
        Author:      Nickolaj Andersen / Jan Ketil Skanke 
        Contact:     @NickolajA @JankeSkanke
    
        Version history:
        1.0.0 - (2021-05-26) Function created
		1.0.1 - (2022-15.09) Updated to support CloudPC (Different method to find DeviceID)
    #>
	Process {
		# Define Cloud Domain Join information registry path
		$EntraJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
		
		# Retrieve the child key name that is the thumbprint of the machine certificate containing the device identifier guid
		$EntraJoinInfoKey = Get-ChildItem -Path $EntraJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($EntraJoinInfoKey -ne $null) {
			# Retrieve the machine certificate based on thumbprint from registry key
            
			if ($EntraJoinInfoKey -ne $null) {
				# Match key data against GUID regex
				if ([guid]::TryParse($EntraJoinInfoKey, $([ref][guid]::Empty))) {
					$EntraJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Subject -like "CN=$($EntraJoinInfoKey)" }
				}
				else {
					$EntraJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $EntraJoinInfoKey }    
				}
			}
			if ($EntraJoinCertificate -ne $null) {
				# Determine the device identifier from the subject name
				$EntraDeviceID = ($EntraJoinCertificate | Select-Object -ExpandProperty "Subject") -replace "CN=", ""
				# Handle return value
				return $EntraDeviceID
			}
		}
	}
} #endfunction 
function Get-EntraJoinDate {
	<#
    .SYNOPSIS
        Get the Azure AD Join Date from the local device.
    
    .DESCRIPTION
        Get the Azure AD Join Date from the local device.
    
    .NOTES
        Author:      Jan Ketil Skanke (and Nickolaj Andersen)
        Contact:     @JankeSkanke
        Created:     2021-05-26
        Updated:     2021-05-26
    
        Version history:
        1.0.0 - (2021-05-26) Function created
		1.0.1 - (2022-15.09) Updated to support CloudPC (Different method to find Entra DeviceID)
    #>
	Process {
		# Define Cloud Domain Join information registry path
		$EntraJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
		
		# Retrieve the child key name that is the thumbprint of the machine certificate containing the device identifier guid
		$EntraJoinInfoKey = Get-ChildItem -Path $EntraJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($EntraJoinInfoKey -ne $null) {
			# Retrieve the machine certificate based on thumbprint from registry key
            
			if ($EntraJoinInfoKey -ne $null) {
				# Match key data against GUID regex
				if ([guid]::TryParse($EntraJoinInfoKey, $([ref][guid]::Empty))) {
					$EntraJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Subject -like "CN=$($EntraJoinInfoKey)" }
				}
				else {
					$EntraJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $EntraJoinInfoKey }    
				}
			}
			if ($EntraJoinCertificate -ne $null) {
				# Determine the device identifier from the subject name
				$EntraJoinDate = ($EntraJoinCertificate | Select-Object -ExpandProperty "NotBefore") 
				# Handle return value
				return $EntraJoinDate
			}
		}
	}
} #endfunction 
#Function to get Entra TenantID
function Get-EntraTenantID {
	# Cloud Join information registry path
	$EntraTenantInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo"
	# Retrieve the child key name that is the tenant id for Entra
	$EntraTenantID = Get-ChildItem -Path $EntraTenantInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
	return $EntraTenantID
}       

# Collect some custom data and add to hash table 
$CustomData = [Ordered]@{}
$CustomData.Add("TimeGenerated", (Get-Date -AsUTC).ToString("yyyy-MM-ddTHH:mm:ssZ"))
$CustomData.Add("EntraDeviceID", (Get-EntraDeviceID))
$CustomData.Add("EntraJoinDate", (Get-EntraJoinDate).ToString("yyyy-MM-ddTHH:mm:ssZ"))
$CustomData.Add("EntraTenantID", (Get-EntraTenantID))
$CustomData.Add("ComputerName", $env:COMPUTERNAME)
$CustomData.Add("ComputerSystem", (Get-CimInstance -ClassName Win32_ComputerSystem).Model)
$CustomData.Add("Manufacturer", (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer)
$CustomData.Add("BIOSVendor", (Get-CimInstance -ClassName Win32_BIOS).Manufacturer)
$CustomData.Add("BIOSVersion", (Get-CimInstance -ClassName Win32_BIOS).SMBIOSBIOSVersion)
$CustomData.Add("OSName", (Get-CimInstance -ClassName Win32_OperatingSystem).Caption)
$CustomData.Add("OSVersion", (Get-CimInstance -ClassName Win32_OperatingSystem).Version)
$CustomData.Add("OSInstallDate", ((Get-CimInstance -ClassName Win32_OperatingSystem).InstallDate).ToString("yyyy-MM-ddTHH:mm:ssZ"))
$CustomData.Add("OSLastBootUpTime", ((Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime).ToString("yyyy-MM-ddTHH:mm:ssZ"))
$CustomData.Add("OSArchitecture", (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture)
$CustomData.Add("OSBuildNumber", (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber)

# Convert the hash table to JSON
$Logbody = $CustomData | ConvertTo-Json -Depth 10 -AsArray

### Step 3: Send the data to the Log Analytics workspace via the DCE.
$headers = @{"Authorization"="Bearer $bearerToken";"Content-Type"="application/json"};
$uri = "$dceEndpoint/dataCollectionRules/$dcrImmutableId/streams/$($streamName)?api-version=2023-01-01"


$uploadResponse = Invoke-WebRequest -Uri $uri -Method "Post" -Body $Logbody -Headers $headers
$uploadResponse.StatusCode

