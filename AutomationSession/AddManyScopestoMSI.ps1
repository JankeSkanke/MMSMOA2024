#Requires -Modules Microsoft.Graph
# Install the module. (You need admin on the machine.)
# Install-Module Microsoft.Graph

# Set the name of your service principal app (Logic App, Function App etc.)
$ServicePrincipalAppDisplayName = ""

# Define dynamic variables
$ServicePrincipalFilter = "displayName eq '$($ServicePrincipalAppDisplayName)'" 7
$GraphAPIAppName = "Microsoft Graph"
$ApiServicePrincipalFilter = "displayName eq '$($GraphAPIAppName)'"

# Scopes needed for the managed identity (Add only the scopes you need.)
$Scopes = @("DeviceManagementServiceConfig.Read.All", "DeviceManagementConfiguration.Read.All")

# Connect to MG Graph - scopes must be consented the first time you run this. 
# Connect with Global Administrator
Connect-MgGraph -Scopes "Application.Read.All","Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All"


# Get the service principal for your managed identity.
$ServicePrincipal = Get-MgServicePrincipal -Filter $ServicePrincipalFilter

# Get the service principal for Microsoft Graph. 
# Result should be AppId 00000003-0000-0000-c000-000000000000
$ApiServicePrincipal = Get-MgServicePrincipal -Filter "$ApiServicePrincipalFilter"


# Apply permissions
Foreach ($Scope in $Scopes) {
    Write-Output "Getting App Role '$Scope'"
    $AppRole = $ApiServicePrincipal.AppRoles | Where-Object {$_.Value -eq $Scope -and $_.AllowedMemberTypes -contains "Application"}
    if ($null -eq $AppRole) { Write-Error "Could not find the specified App Role on the Api Service Principal"; continue; }
    if ($AppRole -is [array]) { Write-Error "Multiple App Roles found that match the request"; continue; }
    Write-Output "Found App Role, Id '$($AppRole.Id)'"

    $ExistingRoleAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipal.Id | Where-Object { $_.AppRoleId -eq $AppRole.Id }
    if ($null -eq $existingRoleAssignment) {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipal.Id -PrincipalId $ServicePrincipal.Id -ResourceId $ApiServicePrincipal.Id -AppRoleId $AppRole.Id
    } else {
        Write-Output "App Role has already been assigned, skipping"
    }
}
