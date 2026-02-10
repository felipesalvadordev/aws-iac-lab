##################
### VPC
##################
resource "aws_vpc" "this" {
  cidr_block = local.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc"
  }
}

resource "aws_subnet" "public" {
  count = local.max_number_of_azs

  vpc_id            = aws_vpc.this.id
  cidr_block        = "${local.vpc_first_two_octets}.${tonumber(local.vpc_third_octet) + count.index}.${local.vpc_fourth_octet}/24"
  availability_zone = data.aws_availability_zones.this.names[count.index]

  tags = {
    Name = "public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count = local.max_number_of_azs

  vpc_id            = aws_vpc.this.id
  cidr_block        = "${local.vpc_first_two_octets}.${tonumber(local.vpc_third_octet) + local.max_number_of_azs + count.index}.${local.vpc_fourth_octet}/24"
  availability_zone = data.aws_availability_zones.this.names[count.index]

  tags = {
    Name = "private-${count.index}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "vpc-rt-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "vpc-rt-private"
  }
}

resource "aws_route_table_association" "public" {
  count = local.max_number_of_azs

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = local.max_number_of_azs

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id] # [cite: 36]
}