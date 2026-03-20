# --- Configuration Paths ---
$Config = Get-Content "./config.json" | ConvertFrom-Json
$ProviderFile = "./provider.tf"

$PrimaryRegion = $Config.primary_region
$DRRegion      = $Config.dr_region
$PrimaryBucket = "$($Config.project_name)-terraform-state-$($PrimaryRegion)"
$DRBucket      = "$($Config.project_name)-terraform-state-$($DRRegion)"

Write-Host "----------------------------------------------------"
Write-Host "   STARTING FAILBACK & DR CLEANUP PROCEDURE   "
Write-Host "----------------------------------------------------"

# (1/3) REVERT PROVIDER CONFIGURATION
Write-Host "[1/3] Restoring Backend to Primary Region ($PrimaryRegion)..."
$Content = Get-Content $ProviderFile -Raw
# Replaces DR Bucket with Primary Bucket and updates the region string
$Content = $Content -replace [regex]::Escape($DRBucket), $PrimaryBucket
$Content = $Content -replace "region\s*=\s*`"$DRRegion`"", "region = `"$PrimaryRegion`""
$Content | Set-Content $ProviderFile

# (2/3) RECONFIGURE TERRAFORM STATE
Write-Host "[2/3] Synchronizing Terraform state with Primary Region..."
# The -reconfigure flag is essential to point to the new (old) S3 backend path
terraform init -reconfigure -no-color
if ($LASTEXITCODE -ne 0) { 
    Write-Host "ERROR: Terraform initialization failed!" -ForegroundColor Red; exit 
}

# (3/3) SELECTIVE CLEANUP OF RECOVERY RESOURCES
Write-Host "[3/3] Decommissioning DR Infrastructure (Compute & Promoted RDS)..."
# Running with dr_mode=false tells Terraform to return to the 'Pilot Light' baseline.
# We target the promoted DB specifically to ensure it is terminated first.
terraform destroy -var="dr_mode=false" -target=aws_db_instance.dr_replica -auto-approve

Write-Host "----------------------------------------------------"
Write-Host "   FAILBACK COMPLETED SUCCESSFULLY   " -ForegroundColor Green
Write-Host "   Infrastructure is now managed from $PrimaryRegion"
Write-Host "----------------------------------------------------"