resource "aws_vpc" "main" {
  provider   = aws.primary
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_1" {
  provider          = aws.primary
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_2" {
  provider          = aws.primary
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_db_subnet_group" "default" {
  provider   = aws.primary
  name       = "main-subnet-group"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
}

# --- Network in DR region (sa-east-1) ---

resource "aws_vpc" "dr_vpc" {
  provider   = aws.dr
  cidr_block = "10.1.0.0/16" # CIDR different from primary to avoid conflicts
}

resource "aws_subnet" "dr_subnet_1" {
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "sa-east-1a"
}

resource "aws_subnet" "dr_subnet_2" {
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "sa-east-1c" # AZs differents for better resilience
}

resource "aws_db_subnet_group" "dr_subnet_group" {
  provider   = aws.dr
  name       = "dr-subnet-group"
  subnet_ids = [aws_subnet.dr_subnet_1.id, aws_subnet.dr_subnet_2.id]
}