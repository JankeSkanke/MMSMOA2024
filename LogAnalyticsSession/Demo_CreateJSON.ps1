# Script to create JSON file containing custom data. Used for creating table in log analytics workspace and sending data to the workspace.

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
$CustomData.Add("TimeGenerated", (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ"))
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

#Convert to JSON Array and Save to file
$CustomData | ConvertTo-Json -Depth 5 -AsArray | Out-File -FilePath ".\CustomData.json" 