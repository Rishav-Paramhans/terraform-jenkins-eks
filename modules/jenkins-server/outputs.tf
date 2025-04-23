output "jenkins_instance_id" {
  value = aws_instance.jenkins-ec2-server.id
}
output "jenkins_public_ip" {
  value = aws_instance.jenkins-ec2-server.public_ip
}
