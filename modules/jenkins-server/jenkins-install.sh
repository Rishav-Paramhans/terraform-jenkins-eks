#!/bin/bash

# Update system
sudo yum update -y

# Install Amazon Corretto 17 (Java 17)
sudo amazon-linux-extras enable corretto17
sudo yum install -y java-17-amazon-corretto

# Verify Java version
java -version

# Install Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade -y
sudo yum install -y jenkins

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Install Git
sudo yum install -y git

# Install Terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

# Install kubectl
sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.27.3/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mkdir -p $HOME/bin && sudo cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin

# (Optional) Print Jenkins initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
