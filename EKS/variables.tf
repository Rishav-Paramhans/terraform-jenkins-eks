variable "vpc_id" {
  description = "The ID of the existing VPC"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs to use for EKS"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs (optional, if needed)"
  type        = list(string)
}
