# --- Substitua o bloco de Prerequisites Check por este ---
$RequiredModules = @("AWS.Tools.RDS", "AWS.Tools.EC2", "AWS.Tools.S3")

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -Name $Module)) {
        if (Get-Module -ListAvailable -Name $Module) {
            Import-Module $Module -ErrorAction SilentlyContinue
        } else {
            Write-Host "Instalando módulo faltante: $Module..." -ForegroundColor Yellow
            Install-AWSToolsModule $Module -Force -Scope CurrentUser
            Import-Module $Module
        }
    }
}
# --- Project Configuration ---
if (-not (Test-Path "./config.json")) { 
    Write-Host "ERROR: config.json file not found!"; exit 
}

$Config = Get-Content "./config.json" | ConvertFrom-Json
$DBIdentifier  = "db-dr-replica" 
$ProviderFile  = "./provider.tf"

$PrimaryRegion = $Config.primary_region
$DRRegion      = $Config.dr_region
$PrimaryBucket = "$($Config.project_name)-terraform-state-$($PrimaryRegion)"
$DRBucket      = "$($Config.project_name)-terraform-state-$($DRRegion)"

Write-Host "----------------------------------------------------"
Write-Host "   STARTING DISASTER RECOVERY SIMULATION   "
Write-Host "----------------------------------------------------"

# (1/5) BACKEND FAILOVER
Write-Host "[1/5] Checking S3 Backend Availability..."
try {
    # Testing access to the primary bucket
    Get-S3Bucket -BucketName $PrimaryBucket -Region $PrimaryRegion -ErrorAction Stop | Out-Null
    Write-Host "  > Primary Backend is ONLINE."
} catch {
    Write-Host "  > PRIMARY REGION UNREACHABLE" -ForegroundColor Red
    Write-Host "  > Redirecting state to DR Region: $DRRegion..." -ForegroundColor Yellow
    
    # Read the whole file first to avoid stream corruption
    $Content = Get-Content $ProviderFile -Raw
    
    # Perform replacements for both Bucket and Region using regex escape for safety
    $Content = $Content -replace [regex]::Escape($PrimaryBucket), $DRBucket
    $Content = $Content -replace "region\s*=\s*`"$PrimaryRegion`"", "region = `"$DRRegion`""
    
    # Overwrite the file with the new configuration
    $Content | Set-Content $ProviderFile

    # Reconfigure Terraform to point to the new S3 Backend in DR region
    terraform init -reconfigure -no-color
    Write-Host "  > Terraform reconfigured successfully." -ForegroundColor Green
}

# (2/5) REPLICATION CHECK
Write-Host "[2/5] Validating Data Replication (RPO)..."
$dbStatus = Get-RDSDBInstance -DBInstanceIdentifier $DBIdentifier -Region $DRRegion
$lag = $dbStatus.ReplicationProgressLag

if ($null -eq $lag) {
    Write-Host "  > Could not determine lag. Verify if replica exists."
} elseif ($lag -gt 60) {
    Write-Host "  > WARNING: High replication lag ($lag seconds)!" -ForegroundColor Yellow
} else {
    Write-Host "  > Replication is healthy ($lag seconds lag)." -ForegroundColor Green
}

# (3/5) RDS PROMOTION
Write-Host "[3/5] Promoting Database in DR Region..."
try {
    Write-Host "  > Converting replica to standalone..."
    Convert-RDSReadReplicaToStandalone -DBInstanceIdentifier $DBIdentifier -Region $DRRegion -BackupRetentionPeriod 7 | Out-Null
    
    # Monitoring Loop for visual feedback
    Write-Host "  > Monitoring promotion status..."
    $IsAvailable = $false
    while (-not $IsAvailable) {
        $Instance = Get-RDSDBInstance -DBInstanceIdentifier $DBIdentifier -Region $DRRegion
        $Status = $Instance.DBInstanceStatus
        
        Write-Host "  > Current Status: $Status" -ForegroundColor Gray
        
        if ($Status -eq "available") {
            $IsAvailable = $true
        } else {
            Start-Sleep -Seconds 15
        }
    }

    Write-Host "  > Database PROMOTED successfully." -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "is not a read replica") {
        Write-Host "  > Database is already standalone." -ForegroundColor Blue
    } else {
        Write-Host "  > Promotion error: $($_.Exception.Message)" -ForegroundColor Red; exit
    }
}

# (4/5) COMPUTE PROVISIONING
Write-Host "[4/5] Provisioning Recovery Servers (SPOT)..."
Write-Host "  > Running Terraform Apply..."
terraform apply -var="dr_mode=true" -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host "  > TERRAFORM APPLY FAILED" -ForegroundColor Red; exit
}
Write-Host "  > Compute infrastructure is ready." -ForegroundColor Green

# (5/5) VALIDATION & EXPORT
Write-Host "[5/5] Generating Recovery Report..."

# Wait for AWS metadata propagation (Public IP assignment)
Write-Host "  > Waiting for Public IP assignment..."
Start-Sleep -Seconds 15

$FinalDB = Get-RDSDBInstance -DBInstanceIdentifier $DBIdentifier -Region $DRRegion
$DR_EC2 = Get-EC2Instance -Region $DRRegion -Filter @{Name="tag:Name";Values="App-DR-Recovered"} | Select-Object -ExpandProperty Instances

$NewIP = $DR_EC2.PublicIpAddress
$NewDB = $FinalDB.Endpoint.Address

# Retry logic if IP is not immediately available
if (-not $NewIP) {
    Write-Host "  > IP not found, retrying in 15s..." -ForegroundColor Gray
    Start-Sleep -Seconds 15
    $DR_EC2 = Get-EC2Instance -Region $DRRegion -Filter @{Name="tag:Name";Values="App-DR-Recovered"} | Select-Object -ExpandProperty Instances
    $NewIP = $DR_EC2.PublicIpAddress
}

$RecoveryInfo = @"
====================================================
DISASTER RECOVERY DETAILS (US-EAST-2)
====================================================
Timestamp: $(Get-Date)
DB Status: ONLINE
DB Endpoint: $NewDB
App Public IP: $NewIP
----------------------------------------------------
MANUAL TEST: Access http://$NewIP in your browser.
====================================================
"@

$RecoveryInfo | Out-File "./recovery_details.txt"

Write-Host "----------------------------------------------------"
Write-Host "RECOVERY COMPLETED" -ForegroundColor Green
Write-Host "APP IP: $NewIP" -ForegroundColor Yellow
Write-Host "DB ENDPOINT: $NewDB" -ForegroundColor Yellow
Write-Host "----------------------------------------------------"
Write-Host "Detailed log saved to: ./recovery_details.txt"