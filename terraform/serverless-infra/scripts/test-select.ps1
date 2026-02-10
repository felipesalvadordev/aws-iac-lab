# 1. Configuration
$FunctionName = "api" 
$Region = "us-east-1"

# 2. Test SQL Query
$SQLQuery = "SELECT * FROM api_logs ORDER BY created_at DESC LIMIT 10;"

# 3. Creating Payload
$PayloadObj = @{
    is_query = $true
    sql      = $SQLQuery
}
$PayloadObj | ConvertTo-Json | Out-File -FilePath payload_query.json -Encoding utf8

Write-Host "Querying data from api_logs table..." -ForegroundColor Cyan

# 4. Invoking Lambda
aws lambda invoke `
    --function-name $FunctionName `
    --region $Region `
    --payload file://payload_query.json `
    --cli-binary-format raw-in-base64-out `
    response_query.json

# 5. Displaying Results
if (Test-Path response_query.json) {
    $RawResponse = Get-Content response_query.json -Raw
    $Response = $RawResponse | ConvertFrom-Json
    
    # Decode the body containing the records
    $Data = $Response.body | ConvertFrom-Json
    
    if ($Data.Count -gt 0) {
        Write-Host "Records found:" -ForegroundColor Green
        $Data | Format-Table id, method, path, ip_address, created_at -AutoSize
    } else {
        Write-Host "The table is empty. Try accessing your API via browser first!" -ForegroundColor Yellow
    }
    
    Remove-Item response_query.json
}

if (Test-Path payload_query.json) { Remove-Item payload_query.json }