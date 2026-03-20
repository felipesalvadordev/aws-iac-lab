variable "dr_mode" {
  description = "Flag to indicate if we are in DR mode (after disaster recovery)"
  type        = bool
  default     = false
}

variable "spot_price" {
  description = "Preço máximo que aceitamos pagar pela instância Spot"
  type        = string
  default     = "0.01"
}

variable "primary_ami" {
  description = "AMI for us-east-1 (Amazon Linux 2)"
  type        = string
  default     = "ami-0c101f26f147fa7fd"
}

variable "dr_ami" {
  description = "AMI for us-east-2 (Ohio - Amazon Linux 2)"
  type        = string
  default     = "ami-05fb0b8c1424f266b"
}