##################
### RDS
##################
resource "aws_db_subnet_group" "this" {
  name = "database"
  subnet_ids = [
    aws_subnet.private[0].id,
    aws_subnet.private[1].id,
    aws_subnet.private[2].id
  ]

  tags = {
    Name = "Database subnet group"
  }
}

resource "aws_db_instance" "this" {
  db_subnet_group_name        = aws_db_subnet_group.this.id
  allocated_storage           = var.database_requested_storage_in_GiB
  max_allocated_storage       = var.database_max_storage_in_GiB
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  db_name                     = var.database_name
  deletion_protection         = false
  instance_class              = var.database_instance_class
  engine                      = var.database_engine
  engine_version              = var.database_engine_version
  identifier                  = var.database_identifier
  password                    = var.database_password
  username                    = var.database_master_username
  port                        = var.database_port
  skip_final_snapshot         = true
  ca_cert_identifier          = "rds-ca-rsa4096-g1"
  vpc_security_group_ids = [
    aws_security_group.database.id
  ]
}

resource "aws_security_group" "database" {
  name        = "allow_db_connection"
  description = "Allow all traffic on port ${var.database_port} coming from the VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = var.database_port
    to_port     = var.database_port
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
