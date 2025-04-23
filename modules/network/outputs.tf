output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "jenkins_sg_id" {
  value       = aws_security_group.jenkins-ec2.id
  description = "Security group ID for Jenkins EC2 instance"
}
