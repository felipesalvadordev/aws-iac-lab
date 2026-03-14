# --- Prerequisites Check ---
$RequiredModules = @("AWS.Tools.Common", "AWS.Tools.RDS", "AWS.Tools.EC2")

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Write-Host "Module $Module not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name $Module -Force -AllowClobber -Scope CurrentUser
    }
    Import-Module $Module
}

# --- Project Configuration ---
$PrimaryRegion = "us-east-1"
$DRRegion      = "sa-east-1"
$DBIdentifier  = "db-dr-replica" 

Write-Host "`n--- STARTING DISASTER RECOVERY SIMULATION (PILOT LIGHT) ---" -ForegroundColor Cyan

# 1. Simulate Disaster (Destroy Region A)
Write-Host "[1/4] Identifying resources in the primary region ($PrimaryRegion)..." -ForegroundColor White
try {
    # Searching for the primary instance by tag
    $InstanceId = (Get-EC2Instance -Region $PrimaryRegion -Filter @{Name="tag:Name";Values="App-Primary-Active"}).Instances.InstanceId
    if ($InstanceId) {
        Write-Host "!! DISASTER DETECTED !! Terminating instance $InstanceId..." -ForegroundColor Red
        Remove-EC2Instance -InstanceId $InstanceId -Region $PrimaryRegion -Force | Out-Null
        Write-Host "Primary instance terminated." -ForegroundColor Gray
    } else {
        Write-Host "Primary instance not found or already destroyed. Proceeding..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error accessing Primary Region: $_" -ForegroundColor Gray
}

# 2. Promote RDS Read Replica in Region B (sa-east-1)
Write-Host "[2/4] Initiating Read Replica promotion in $DRRegion..." -ForegroundColor Yellow
try {
    # Specific command for AWS.Tools.RDS version 5.0.174
    Convert-RDSReadReplicaToStandalone -DBInstanceIdentifier $DBIdentifier -Region $DRRegion -BackupRetentionPeriod 7 | Out-Null
    Write-Host "Promotion command sent successfully." -ForegroundColor Gray
} catch {
    if ($_.Exception.Message -match "is not a read replica") {
        Write-Host "Database is already standalone (already promoted)." -ForegroundColor Blue
    } else {
        Write-Host "Fatal error during promotion: $_" -ForegroundColor Red
        exit
    }
}

# 3. Validate Database Status (Wait for 'available')
Write-Host "[3/4] Monitoring promotion status..." -ForegroundColor Cyan
$startTime = Get-Date
do {
    $dbInstance = Get-RDSDBInstance -DBInstanceIdentifier $DBIdentifier -Region $DRRegion
    $currentStatus = $dbInstance.DBInstanceStatus
    $elapsed = (Get-Date) - $startTime
    Write-Host "Current Status: $currentStatus | Elapsed Time: $($elapsed.Minutes)m$($elapsed.Seconds)s (Waiting for 'available'...)" -ForegroundColor Gray
    
    if ($currentStatus -ne "available") {
        Start-Sleep -Seconds 15 
    }
} while ($currentStatus -ne "available")

Write-Host "✓ Database $DBIdentifier is ONLINE and ready for Read/Write!" -ForegroundColor Green

# 4. Activate Computing via Terraform
Write-Host "[4/4] Provisioning servers in DR Region via Terraform..." -ForegroundColor Cyan
# Passing variables to trigger the 'count = 1' logic in your .tf files
terraform apply -var="dr_mode=true" -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host "!! Terraform Apply FAILED !! Check your .tf configuration and variables." -ForegroundColor Red
    exit
}

# --- FINAL VALIDATION REPORT ---
Write-Host "`n--- DR VALIDATION REPORT ---" -ForegroundColor Cyan
$DR_EC2 = Get-EC2Instance -Region $DRRegion -Filter @{Name="tag:Name";Values="App-DR-Recovered"} | Select-Object -ExpandProperty Instances

Write-Host "DB STATUS (DR):       " -NoNewline
Write-Host "ONLINE (Standalone)" -ForegroundColor Green

Write-Host "EC2 STATUS (DR):      " -NoNewline
if ($DR_EC2.State.Name -eq "running") {
    Write-Host "RUNNING (ID: $($DR_EC2.InstanceId))" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND OR PENDING" -ForegroundColor Red
}

Write-Host "DB ENDPOINT:          " -NoNewline
Write-Host $dbInstance.Endpoint.Address -ForegroundColor Yellow

Write-Host "`n--- RECOVERY COMPLETED SUCCESSFULLY IN $($DRRegion.ToUpper()) ---" -ForegroundColor Green