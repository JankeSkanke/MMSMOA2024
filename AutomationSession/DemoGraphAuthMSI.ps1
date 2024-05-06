# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# Write an information log with the current time.
Write-Information "PowerShell timer trigger function ran! TIME: $currentUTCtime"

#Function App Managed Service Identity Authentication Function

function Get-AuthToken {
    Process {
        # Get Managed Service Identity details from the Azure Functions application settings
        $MSIEndpoint = $env:MSI_ENDPOINT
        $MSISecret = $env:MSI_SECRET

        # Define the required URI and token request params
        $APIVersion = "2017-09-01"
        $ResourceURI = "https://graph.microsoft.com"
        $AuthURI = $MSIEndpoint + "?resource=$($ResourceURI)&api-version=$($APIVersion)"

        # Call resource URI to retrieve access token as Managed Service Identity
        $Response = Invoke-RestMethod -Uri $AuthURI -Method "Get" -Headers @{ "Secret" = "$($MSISecret)" }

        # Construct authentication header to be returned from function
        $Global:AuthenticationHeader = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $($Response.access_token)"
            "ExpiresOn" = $Response.expires_on
        }
        # Handle return value
        return $AuthenticationHeader
    }
}#end function 

#Autehnticate to Graph API
Get-AuthToken

# Construct a request using GET method
#
$Parameters = @{
    Method = "Get"
    Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    Headers = $AuthenticationHeader
    ContentType = "application/json"
}

$ManagedDevices = Invoke-RestMethod @Parameters

Write-Information "Managed Devices: $($ManagedDevices.value.deviceName)" 

Write-Information "PowerShell timer trigger function completed TIME: $currentUTCtime"
