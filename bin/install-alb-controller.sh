#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ROLE_ARN=$(terraform -chdir="$ROOT/tf-eks" output -raw alb_controller_role_arn)
CLUSTER=$(terraform -chdir="$ROOT/tf-eks" output -raw cluster_name)
REGION=$(terraform -chdir="$ROOT/tf-eks" output -raw aws_region)

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version 3.6.0 \
  --set clusterName="$CLUSTER" \
  --set region="$REGION" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set-string "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ROLE_ARN"

echo "Controller installed. Apply deploy/k8s/22-ingress.yaml, then:"
echo "kubectl get ingress productservice -n csr-lab"
