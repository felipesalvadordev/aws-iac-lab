# 1. Primary Database (Region A)
resource "aws_db_instance" "primary" {
  provider             = aws.primary
  identifier           = "db-primary"
  allocated_storage    = 20
  storage_type         = "standard" # Lowest cost
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "testedr"
  username             = "admin"
  password             = "SenhaSegura123" # In production, use AWS Secrets Manager
  backup_retention_period = 1 # Minimum required to enable replication
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.default.name
}

# 2. Primary EC2 Instance (Region A - N. Virginia)
resource "aws_instance" "app_primary" {
  provider      = aws.primary
  ami           = "ami-0c101f26f147fa7fd" # Amazon Linux 2 AMI in us-east-1
  instance_type = "t3.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "DB_HOST=${aws_db_instance.primary.address}" > /etc/db_config
              EOF

  tags = {
    Name = "App-Primary-Active"
  }
}

# 3. Read Replica (Region B - The "Pilot Light")
resource "aws_db_instance" "dr_replica" {
  provider            = aws.dr
  identifier          = "db-dr-replica"
  replicate_source_db = aws_db_instance.primary.arn # Correct cross-region reference
  instance_class      = "db.t3.micro"
  storage_type        = "standard" # Keeping costs low
  skip_final_snapshot = true
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.dr_subnet_group.name
}

# 4. DR EC2 Instance (On-demand Computing)
resource "aws_instance" "app_dr" {
  # Instance is only provisioned if dr_mode is true
  count         = var.dr_mode ? 1 : 0
  provider      = aws.dr
  ami           = "ami-04076f7c7035f2998" # Amazon Linux 2 AMI in sa-east-1
  instance_type = "t3.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "DB_HOST=${aws_db_instance.dr_replica.address}" > /etc/db_config
              EOF

  tags = { 
    Name = "App-DR-Recovered" 
  }
}