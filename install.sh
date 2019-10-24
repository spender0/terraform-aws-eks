#!/usr/bin/bash

# exit when any command fails
set -e

KUBE2IAM_HELM_CHART_VERSION="${KUBE2IAM_HELM_CHART_VERSION:-2.0.2}"
CLUSTER_AUTOSCALER_HELM_CHART_VERSION="${CLUSTER_AUTOSCALER_HELM_CHART_VERSION:-6.0.0}"
KUBERNETES_DASHBOARD_HELM_CHART_VERSION="${KUBERNETES_DASHBOARD_HELM_CHART_VERSION:-1.10.0}"
PROMETHEUS_OPERATOR_HELM_CHART_VERSION="${PROMETHEUS_OPERATOR_HELM_CHART_VERSION:-6.21.0}"


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd $DIR

TERRAFORM_WORKSPACE="$(terraform workspace show | grep -oP '(.*:)?\K(.*)')"

#1 kubeconfig is located in workspace folder
export KUBECONFIG=./terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf
#2 apply map-aws-auth.yaml to finish nodes bootstraping
kubectl apply -f ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/config-map-aws-auth.yaml
#3 wait for at least 1 node

while [[ ! $(kubectl get nodes | grep -i ready) ]]; do
  echo "INFO waiting for nodes"
  sleep 1;
done
# create service account and role for admin
kubectl apply -f $DIR/eks-admin-service-account.yaml
kubectl apply -f $DIR/eks-admin-cluster-role-binding.yaml

# init helm and run local tiller
helm init --wait --client-only
helm repo update
killall tiller; tiller &
export HELM_HOST=localhost:44134

#deploy kube2iam
helm upgrade --install --wait --dry-run \
  --namespace kube-system \
  --values ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/kube2iam-helm-chart-values.yaml \
  --version $KUBE2IAM_HELM_CHART_VERSION \
  kube2iam stable/kube2iam
helm upgrade --install --wait \
  --namespace kube-system \
  --values ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/kube2iam-helm-chart-values.yaml \
  --version $KUBE2IAM_HELM_CHART_VERSION \
  kube2iam stable/kube2iam

#deploy cluster autoscaler
helm upgrade --install --wait --dry-run \
  --namespace kube-system \
  --values ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/cluster-autoscaler-helm-chart-values.yaml \
  --version $CLUSTER_AUTOSCALER_HELM_CHART_VERSION \
  cluster-autoscaler stable/cluster-autoscaler
helm upgrade --install --wait \
  --namespace kube-system \
  --values ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/cluster-autoscaler-helm-chart-values.yaml \
  --version $CLUSTER_AUTOSCALER_HELM_CHART_VERSION \
  cluster-autoscaler stable/cluster-autoscaler

#deploy dashboard
helm upgrade --install --wait --dry-run \
  --namespace kube-system  \
  --version $KUBERNETES_DASHBOARD_HELM_CHART_VERSION \
  kubernetes-dashboard stable/kubernetes-dashboard
helm upgrade --install --wait \
  --namespace kube-system  \
  --version $KUBERNETES_DASHBOARD_HELM_CHART_VERSION \
  kubernetes-dashboard stable/kubernetes-dashboard

#install prometheus operator
helm upgrade --install --wait --dry-run \
  --namespace monitoring \
  --values ./prometheus-operator-helm-chart-values.yaml \
  --version $PROMETHEUS_OPERATOR_HELM_CHART_VERSION \
  prometheus-operator stable/prometheus-operator
helm upgrade --install --wait \
  --namespace monitoring \
  --values ./prometheus-operator-helm-chart-values.yaml \
  --version $PROMETHEUS_OPERATOR_HELM_CHART_VERSION \
  prometheus-operator stable/prometheus-operator

helm upgrade --install --wait \
  --namespace logging \
  elastic-stack stable/elastic-stack

cat << EOF
Your kubeconfig is here: terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf
Run "export KUBECONFIG=terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf" to manage the cluster via kubectl
EOF