data "aws_caller_identity" "current" {
}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

data "aws_availability_zones" "this" {
  state = "available"
  filter {
    name   = "region-name"
    values = [var.aws_region]
  }
}
