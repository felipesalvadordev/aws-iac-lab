locals {
  account_id    = data.aws_caller_identity.current.account_id
  frontend_fqdn = "${var.frontend_subdomain}.${var.domain_name}"
  backend_fqdn  = "${var.backend_subdomain}.${var.domain_name}"
}


# VPC RELATED
locals {
  vpc_mask             = 16
  vpc_cidr             = "${var.network_ip}/${local.vpc_mask}"
  vpc_first_two_octets = join(".", slice(split(".", var.network_ip), 0, 2))
  vpc_third_octet      = element(split(".", var.network_ip), 2)
  vpc_fourth_octet     = element(split(".", var.network_ip), 3)
  max_number_of_azs    = 3
}
