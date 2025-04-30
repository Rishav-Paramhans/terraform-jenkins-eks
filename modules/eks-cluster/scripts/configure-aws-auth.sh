#!/bin/bash
set -e

CLUSTER_NAME="my-eks-cluster-vjuser"
REGION="us-east-1"

echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "📦 Applying aws-auth ConfigMap..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::891612581521:user/vaibhav-user
      username: vaibhav-user
      groups:
        - system:masters
    - userarn: arn:aws:iam::891612581521:user/rishav-user
      username: rishav-user
      groups:
        - system:masters
  mapRoles: |
    - rolearn: arn:aws:iam::891612581521:role/jenkins-eks_cluster_admin_access-role
      username: jenkins-access
      groups:
        - system:masters
EOF

echo "✅ aws-auth updated."
