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
  password             = "12345678" # In production, use AWS Secrets Manager
  backup_retention_period = 1 # Minimum required to enable replication
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.default.name
}

# 2. Primary EC2 Instance (Region A - N. Virginia)
resource "aws_instance" "app_primary" {
  provider      = aws.primary
  ami           = var.primary_ami
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet_1.id
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
  replicate_source_db = var.dr_mode ? null : aws_db_instance.primary.arn
  instance_class      = "db.t3.micro"
  storage_type        = "standard" # Keeping costs low
  skip_final_snapshot = true
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.dr_subnet_group.name
  lifecycle {
    ignore_changes = [replicate_source_db]
  }
}

# 4. DR EC2 Instance (On-demand Computing)
resource "aws_instance" "app_dr" {
  # Instance is only provisioned if dr_mode is true
  count         = var.dr_mode ? 1 : 0
  provider      = aws.dr
  ami           = var.dr_ami 
  instance_type = "t3.micro"
  subnet_id           = aws_subnet.dr_subnet_1.id
  associate_public_ip_address = true
  
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.01" # Define max price to control costs
      spot_instance_type = "one-time"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "DB_HOST=${aws_db_instance.dr_replica.address}" > /etc/db_config
              EOF

  tags = { 
    Name = "App-DR-Recovered" 
  }
}