## Infrastructure Architecture

A Pilot Light disaster recovery solution that uses Terraform and PowerShell to promote an RDS Read Replica and provision EC2 compute resources in a secondary region during a failover.

### Primary Region (`us-east-1`)
* **Amazon EC2 (`app_primary`):** A `t3.micro` instance acting as the primary web server.
* **Amazon RDS (`primary`):** A `db.t3.micro` MySQL database instance. This is the **Master** database handling both read and write operations.
* **Amazon EBS (Elastic Block Store):**
    * **Root Volume:** 8 GB (default) for the EC2 Operating System.
    * **DB Storage:** 20 GB dedicated volume for the RDS instance.

---

### Disaster Recovery Region (`sa-east-1`)
* **Amazon RDS (`dr_replica`):** A database instance that functions as a **Read Replica**. It receives continuous asynchronous data updates from the primary region via the AWS backbone network.
* **Amazon EC2 (`app_dr`):** Defined in the Infrastructure as Code (IaC), but in this **Pilot Light** configuration, it is only provisioned during a failover event (when the `disaster_occurred` variable is set to `true`).
* **Amazon EBS:**
    * **Replica Storage:** RDS storage volume (mirrors the primary size).
    * **DR Root Volume:** Provisioned only during the failover process.

---

### Standby Assets Summary (The "Pilot Light" Strategy)

Unlike a traditional *Backup & Restore* system, the **Pilot Light** strategy keeps the "core" (the database) alive and synchronized in the secondary region while keeping the "rest of the house" (the computing layer) unprovisioned.

> **Key Benefits:**
> * **Low RPO (Recovery Point Objective):** Data is kept nearly up-to-date through continuous replication.
> * **Cost Efficiency:** Significant savings by avoiding hourly costs for idle EC2 instances in the DR region.
> * **Automated Failover:** Uses Terraform and PowerShell to promote the database and spin up computing resources in minutes.

---

### Automated Failover Testing (`fail-over.ps1`)

The project includes a PowerShell script designed to simulate a regional disaster and automate the recovery process. This script bridges the gap between the infrastructure state and the AWS Control Plane actions.

#### **What the script does:**
1.  **Disaster Simulation:** Identifies and terminates the primary EC2 instance in `us-east-1`.
2.  **RDS Promotion:** Communicates with the AWS API to convert the `db-dr-replica` from a Read Replica into a standalone Master database.
3.  **Promotion Monitoring:** Polls the RDS status until the database is `available` and ready for write operations.
4.  **Infrastructure Scaling:** Automatically executes `terraform apply` with the necessary flags to provision the recovery compute layer in `sa-east-1`.



#### **How to run the test:**

1.  **Prerequisites:** Ensure you have the AWS PowerShell module (`AWS.Tools.RDS` and `AWS.Tools.EC2`) installed and your AWS credentials configured.
2.  **Initialize Environment:** Deploy the initial state (Primary + Replica) using Terraform:
    ```powershell
    terraform init
    terraform apply -auto-approve
    ```
3.  **Execute Failover:** Run the simulation script from your terminal:
    ```powershell
    .\fail-over.ps1
    ```
4.  **Verify:** Once the script completes, check the final report in the console. It will display the new Database Endpoint and the Instance ID of the recovered server in São Paulo.

> **Warning:** The promotion of an RDS Read Replica is an irreversible action in terms of replication. To return to the original state, you must recreate the replica relationship via Terraform.