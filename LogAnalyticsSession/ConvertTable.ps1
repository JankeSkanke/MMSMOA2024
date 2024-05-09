# convert a table that uses the Data Collector API to data collection rules
# POST https://management.azure.com/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}/tables/{tableName}/migrate?api-version=2021-12-01-preview

$TenantID = ""  #Your Tenant ID
$SubscriptionID = "" #Your Subscription ID
$ResourceGroup = "" #Your resroucegroup
$WorkspaceName = "" #Your workspace name
$TableName = "" #Your table name

Connect-AzAccount -Tenant $TenantID

#Select the subscription
Select-AzSubscription -SubscriptionId $SubscriptionID


#Create Auth Token
$auth = Get-AzAccessToken

$AuthenticationHeader = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer " + $auth.Token
    }

$requestURL = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourcegroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/tables/$($TableName)/migrate?api-version=2021-12-01-preview"

Invoke-RestMethod -Uri $requestURL -Headers $AuthenticationHeader -Method POST 
