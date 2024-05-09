$ResourceID = "" #Your Data collection rule resource ID

# get DCR content and put into a file
$FilePath = "temp.dcr"
$DCR = Invoke-AzRestMethod -Path ("$ResourceId"+"?api-version=2021-09-01-preview") -Method GET
$DCR.Content | ConvertFrom-Json | ConvertTo-Json -Depth 20 | Out-File $FilePath



#write DCR content back from the file
$DCRContent = Get-Content $FilePath -Raw
Invoke-AzRestMethod -Path ("$ResourceId"+"?api-version=2021-09-01-preview") -Method PUT -Payload $DCRContent		
