variable "vpc_cidr" {}
variable "vpc_name" {}
variable "public_subnets" {
  type = list(object({
    cidr = string
    az   = string
  }))
}
variable "private_subnets" {
  type = list(object({
    cidr = string
    az   = string
  }))
}

