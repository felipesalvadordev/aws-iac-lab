# 1. Configuration
$FunctionName = "api" 
$Region = "us-east-1"

# 2. SQL Command
$SQLCommand = @"
CREATE TABLE IF NOT EXISTS api_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    request_id VARCHAR(100),
    path VARCHAR(255),
    method VARCHAR(10),
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"@

# 3. Creating Payload Object (Matches what index.js expects)
$PayloadObj = @{
    is_setup = $true
    sql      = $SQLCommand
}

# Convert to JSON and save to file to avoid terminal escaping issues
$PayloadObj | ConvertTo-Json | Out-File -FilePath payload_setup.json -Encoding utf8

Write-Host "--- Starting table creation via Lambda ---" -ForegroundColor Cyan
Write-Host "Sending command to function: $FunctionName"

# 4. Invoking Lambda
aws lambda invoke `
    --function-name $FunctionName `
    --region $Region `
    --payload file://payload_setup.json `
    --cli-binary-format raw-in-base64-out `
    response_setup.json

# 5. Processing Response
if (Test-Path response_setup.json) {
    $RawResponse = Get-Content response_setup.json -Raw
    $Response = $RawResponse | ConvertFrom-Json
    
    # If Lambda returned a body (Standard API Gateway format)
    if ($Response.body) {
        $Body = $Response.body | ConvertFrom-Json
        Write-Host "Result: $($Body.message)" -ForegroundColor Green
    } 
    # If Lambda returned the object directly (Setup mode)
    elseif ($Response.message) {
        Write-Host "Result: $($Response.message)" -ForegroundColor Green
    }
    else {
        Write-Host "Raw Lambda Response: $RawResponse" -ForegroundColor Yellow
    }
    
    Remove-Item response_setup.json
}

if (Test-Path payload_setup.json) { Remove-Item payload_setup.json }