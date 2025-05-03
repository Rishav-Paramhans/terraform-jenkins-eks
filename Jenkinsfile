pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
    }

    environment {
        TF_TOKEN_app_terraform_io = credentials('TF_API_TOKEN')
        AWS_DEFAULT_REGION = "us-east-1"
        KUBECONFIG = "/var/lib/jenkins/.kube/config"
        HELM_INSTALL_DIR = "/var/lib/jenkins/.local/bin" // Ensure Helm is installed in this directory
        PATH = "${HELM_INSTALL_DIR}:${env.PATH}" // Add Helm directory to PATH
    }

    stages {
        stage('Checkout SCM') {
            steps {
                // Use SSH for GitHub. Make sure you have added the SSH key to Jenkins credentials.
                checkout scmGit(branches: [[name: '*/dev']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/Rishav-Paramhans/terraform-jenkins-eks.git']])
                //checkout([
                    //$class: 'GitSCM',
                   //branches: [[name: '*/dev']],
                    //userRemoteConfigs: [[
                        //url: 'https://github.com/Rishav-Paramhans/terraform-jenkins-eks.git',
                        //credentialsId: 'github-pat-jenkins-eks' // <-- Replace with your SSH key credential ID
                    //]]
                //])
                sh 'ls -lR EKS/ConfigurationFiles'
            }
        }

        stage('Terraform and EKS Operations') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-cred', // <-- Replace with your AWS credential ID
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir('modules/eks-cluster') {
                        //sh 'terraform init -reconfigure'
                        //sh 'terraform init -upgrade'
                        sh 'terraform init'
                        sh 'terraform fmt'
                        sh 'terraform validate'
                        sh 'terraform plan'
                        sh "terraform ${params.ACTION} --auto-approve"
                    }
                    script {
                        sh 'aws eks update-kubeconfig --name my-eks-cluster-vjuser --region us-east-1'
                        
                        // Install Helm and add to PATH within same shell session
                        //sh '''
                        //export HELM_INSTALL_DIR=/var/lib/jenkins/.local/bin
                        //mkdir -p $HELM_INSTALL_DIR
                        //export PATH=$HELM_INSTALL_DIR:$PATH
                        //curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                        //chmod 700 get_helm.sh
                        //./get_helm.sh
                        //helm version
                        //'''
                        // Ensure Helm is installed only once and in the path for all future steps
                        sh '''
                        if ! command -v helm &> /dev/null
                        then
                            curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                            chmod 700 get_helm.sh
                            ./get_helm.sh
                        fi
                        helm version
                        '''

                        // Use Helm to deploy NVIDIA GPU operator
                        //export PATH=/var/lib/jenkins/.local/bin:$PATH
                        sh '''
                        helm repo add nvidia https://helm.ngc.nvidia.com/nvidia --force-update
                        helm repo update

                        helm upgrade --install gpu-operator nvidia/gpu-operator \
                          --namespace gpu-operator --create-namespace \
                          --set driver.enabled=true \
                          --set toolkit.enabled=true \
                          --set devicePlugin.enabled=true \
                          --atomic --timeout=10m

                        
                        '''
                        // Install AWS EBS CSI Driver using Helm
                        sh '''
                        helm repo add ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
                        helm repo update
                        helm upgrade --install ebs-csi-driver ebs-csi-driver/aws-ebs-csi-driver \
                          --namespace kube-system 
                        '''

                        // Wait for AWS EBS CSI Driver pods to be ready
                        sh '''
                        kubectl rollout status deployment/ebs-csi-controller -n kube-system --timeout=1000s
                        '''

                        //kubectl wait --for=condition=ready pod \
                        //   --all \
                        //  -n gpu-operator \
                        //  --timeout=1000s
                        // Get the node name with 'SchedulingDisabled' state dynamically
                        //def nodeName = sh(script: "kubectl get nodes --no-headers | grep 'SchedulingDisabled' | awk '{print \$1}'", returnStdout: true).trim()
        
                        // Uncordon the node dynamically
                        //sh "kubectl uncordon ${nodeName}"
                        // Step 2: Wait for nodes to be Ready
                        sh 'kubectl wait --for=condition=Ready nodes --all --timeout=1000s'

                        // Step 3: # Check if the clusterrolebinding already exists, and create it only if it doesn't
                        sh '''
                        kubectl get clusterrolebinding vaibhav-admin-binding --ignore-not-found || kubectl create clusterrolebinding vaibhav-admin-binding --clusterrole=cluster-admin --user=arn:aws:iam::891612581521:user/vaibhav-user
                        '''
                        // Step 4: Apply PersistentVolume and PersistentVolumeClaim
                        sh 'kubectl apply -f modules/eks-cluster/ConfigurationFiles/pv/eks-cluster-pv.yaml'
                        sh 'kubectl apply -f modules/eks-cluster/ConfigurationFiles/pv/eks-cluster-pvc.yaml'
                        def apps = ['frontend', 'backend', 'redis', 'weaviate', 'ollama']
                        //sh 'aws eks update-kubeconfig --name my-eks-cluster-vjuser --region us-east-1'
                        // ✅ Deploy NVIDIA plugin only to ollama nodes
                        //sh 'kubectl apply -f modules/eks-cluster/ConfigurationFiles/ollama/gpu-device-plugin.yaml'
                        // ✅ Deploy NVIDIA plugin from official source
                        //sh 'kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/deployments/static/nvidia-device-plugin.yml'
                        // Wait for NVIDIA plugin pods to be ready
                        //sh '''
                        //kubectl rollout status daemonset/nvidia-device-plugin-daemonset -n kube-system --timeout=180s
                        //'''
                        for (app in apps) {
                            dir("modules/eks-cluster/ConfigurationFiles/${app}") {
                                sh 'kubectl apply -f deployment.yaml'
                                sh 'kubectl apply -f service.yaml'
                            }
                        }
                    }
                }
            }
        }
    }
}
