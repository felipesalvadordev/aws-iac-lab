# Pilot Light Disaster Recovery with Terraform and PowerShell

## Infrastructure Architecture

A Pilot Light disaster recovery solution that uses Terraform and PowerShell to promote an RDS Read Replica and provision EC2 compute resources in a secondary region during a failover.

### Primary Region (us-east-1)
* **Amazon EC2 (app_primary):** A t3.micro instance acting as the primary web server.
* **Amazon RDS (primary):** A db.t3.micro MySQL database instance. This is the Master database handling both read and write operations.
* **Amazon EBS (Elastic Block Store):**
    * **Root Volume:** 8 GB (default) for the EC2 Operating System.
    * **DB Storage:** 20 GB dedicated volume for the RDS instance.

---

### Disaster Recovery Region (us-east-2)
* **Amazon RDS (dr_replica):** A database instance that functions as a Read Replica. It receives continuous asynchronous data updates from the primary region via the AWS backbone network.
* **Amazon EC2 (app_dr):** Defined in the Infrastructure as Code (IaC), but in this Pilot Light configuration, it is only provisioned during a failover event (when the disaster_occurred variable is set to true).
* **Amazon EBS:**
    * **Replica Storage:** RDS storage volume (mirrors the primary size).
    * **DR Root Volume:** Provisioned only during the failover process.

---

### Standby Assets Summary (The Pilot Light Strategy)

Unlike a traditional Backup and Restore system, the Pilot Light strategy keeps the core (the database) alive and synchronized in the secondary region while keeping the computing layer unprovisioned.

* **Low RPO (Recovery Point Objective):** Data is kept nearly up-to-date through continuous replication.
* **Cost Efficiency:** Significant savings by avoiding hourly costs for idle EC2 instances in the DR region.
* **Automated Failover:** Uses Terraform and PowerShell to promote the database and spin up computing resources in minutes.

---

### Automated Failover Testing (fail-over.ps1)

The project includes a PowerShell script designed to simulate a regional disaster and automate the recovery process.

#### What the script does:
1.  **Disaster Simulation:** Identifies and terminates the primary EC2 instance in us-east-1.
2.  **RDS Promotion:** Communicates with the AWS API to convert the db-dr-replica into a standalone Master database.
3.  **Promotion Monitoring:** Polls the RDS status until the database is available and ready for write operations.
4.  **Infrastructure Scaling:** Automatically executes terraform apply to provision the recovery compute layer in us-east-2.

---

## Terraform Infrastructure and Backend Management

### 1. Initial Backend Setup (Bootstrap)
To store the state in S3, the bucket and DynamoDB table must exist first.

1.  **Preparation**: Comment out the backend "s3" block in provider.tf.
2.  **Local Init**: Initialize Terraform to use local state temporarily: `terraform init`
3.  **Bootstrap Resources**: Create the support infrastructure: `terraform apply -target=aws_s3_bucket.state_primary -target=aws_dynamodb_table.terraform_lock`
4.  **Migrate to Cloud**: Un-comment the backend "s3" block and run: `terraform init`
5.  **Confirmation**: When prompted to copy local state to S3, type: yes.

# S3 Bucket and Versioning
aws s3api create-bucket --bucket pilot-light-dr-salvador-terraform-state-us-east-1 --region us-east-1
aws s3api put-bucket-versioning --bucket pilot-light-dr-salvador-terraform-state-us-east-1 --versioning-configuration "Status=Enabled"

# DynamoDB Lock Table
aws dynamodb create-table `
    --table-name terraform-lock-table `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 `
    --region us-east-1

# Import commands to sync state
terraform import aws_s3_bucket.state_primary pilot-light-dr-salvador-terraform-state-us-east-1

### 2. Manual Resource Import (CLI Method)
If resources were created via AWS CLI, bring them under Terraform control:

# S3 Bucket and Versioning
```powershell
# S3 Bucket and Versioning
aws s3api create-bucket --bucket pilot-light-dr-salvador-terraform-state-us-east-1 --region us-east-1
aws s3api put-bucket-versioning --bucket pilot-light-dr-salvador-terraform-state-us-east-1 --versioning-configuration "Status=Enabled"

# DynamoDB Lock Table
aws dynamodb create-table `
    --table-name terraform-lock-table `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 `
    --region us-east-1

# Import commands to sync state
terraform import aws_s3_bucket.state_primary pilot-light-dr-salvador-terraform-state-us-east-1
terraform import aws_dynamodb_table.terraform_lock terraform-lock-table
```

### 3. Failback and Regional Cleanup
After a DR test, revert to the Primary Region and delete secondary resources:

1.  **Destroy DR Region**: Execute `terraform destroy -var="dr_mode=true" -auto-approve` to remove recovery assets.
2.  **Revert Provider Configuration**: Open `provider.tf`, update the bucket and region back to primary values (us-east-1), and save the file.
3.  **Reconfigure Backend**: Run `terraform init -reconfigure` to point the state back to the primary bucket.
4.  **Finalize Primary Cleanup**: Run `terraform destroy -var="dr_mode=false" -auto-approve` to clean up remaining primary resources.

### 4. Total Decommissioning (Full Cleanup)
To remove all resources including the Terraform Backend itself and avoid any further AWS charges:

1.  **Switch to Local State**: Comment out the entire `backend "s3"` block in `provider.tf`.
2.  **Migrate State Locally**: Move the state from the cloud to your local machine by running `terraform init -migrate-state`. Type `yes` when prompted.
3.  **Final Destroy**: With the state now managed locally, run `terraform destroy -auto-approve` to delete the S3 buckets and DynamoDB tables.
4.  **Post-Cleanup Verification**: Manually check S3 and RDS consoles. If S3 deletion fails, empty the bucket manually to remove all object versions first.