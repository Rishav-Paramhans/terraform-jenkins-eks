vpc_cidr = "10.0.0.0/16"
vpc_name = "dev-vpc"

public_subnets = [
  { cidr = "10.0.1.0/24", az = "us-east-1a" },
  { cidr = "10.0.2.0/24", az = "us-east-1b" }
]

private_subnets = [
  { cidr = "10.0.3.0/24", az = "us-east-1a" },
  { cidr = "10.0.4.0/24", az = "us-east-1b" }
]
