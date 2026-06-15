# Auto-Scaling Private EC2 Instances

- Custom VPC with 2 public and 2 private subnets
- Security group in the public subnets that allows traffic from the internet and associate it with the Application Load Balancer, Internet Gateway and a NAT gateway
- Auto-Scaling Group of EC2 instances running Nginx service that allows traffic from the Application Load Balancer in the private subnets

**1. Inbound Traffic (Internet to EC2)**

Internet users access the ALB public DNS name on port 80
ALB Security Group allows all ingress on port 80 from 0.0.0.0/0 (lines 84-90)
ALB forwards traffic to EC2 instances in private subnets via Target Group on port 80
ASG Security Group allows port 80 ingress only from ALB security group (lines 106-112)
This restricts direct internet access to EC2 instances - traffic must go through ALB

**2. Network Isolation**

Public Subnets: ALB deployed here with auto-assigned public IPs (line 13)
Private Subnets: EC2 instances deployed here without public IPs (line 144)
Public Route Table: routes 0.0.0.0/0 traffic to Internet Gateway (lines 25-32)
Private Route Table: routes 0.0.0.0/0 traffic to NAT Gateway (lines 42-49)

**3. Outbound Traffic (EC2 to Internet)**

EC2 instances in private subnets send outbound traffic through NAT Gateway
NAT Gateway uses an Elastic IP (lines 64-76) for source IP translation
This allows instances to reach external resources while remaining private
All security groups allow egress to 0.0.0.0/0 (lines 92-97, 114-119)

**4. Auto-Scaling Management**

CloudWatch monitors CPU utilization on the Auto-Scaling Group
When CPU drops below 25% for 5 consecutive periods, scale-down policy triggers (lines 168-183)
Minimum 2 instances, maximum 5 instances (lines 141-143)

**5. Load Balancing**

ALB listens on port 80 and forwards to Target Group (lines 202-211)
Target Group contains EC2 instances from the Auto-Scaling Group
Health checks determine which instances receive traffic

![ec2-auto-scalling](https://github.com/user-attachments/assets/0560a737-3595-4f1e-8314-2615c58e1555)

https://medium.com/nerd-for-tech/auto-scaling-private-ec2-instances-with-terraform-9a7b5a079b72  
https://spacelift.io/blog/terraform-autoscaling-group
