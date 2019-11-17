#!/usr/bin/bash

# exit when any command fails
set -e

KUBE2IAM_HELM_CHART_VERSION="${KUBE2IAM_HELM_CHART_VERSION:-2.0.2}"
CLUSTER_AUTOSCALER_HELM_CHART_VERSION="${CLUSTER_AUTOSCALER_HELM_CHART_VERSION:-6.0.0}"
KUBERNETES_DASHBOARD_HELM_CHART_VERSION="${KUBERNETES_DASHBOARD_HELM_CHART_VERSION:-1.10.0}"
PROMETHEUS_OPERATOR_HELM_CHART_VERSION="${PROMETHEUS_OPERATOR_HELM_CHART_VERSION:-8.2.0}"


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd $DIR

TERRAFORM_WORKSPACE="$(terraform workspace show | grep -oP '(.*:)?\K(.*)')"

# kubeconfig is located in workspace folder
export KUBECONFIG=./terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf

# apply map-aws-auth.yaml to finish nodes bootstraping
kubectl apply -f ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/config-map-aws-auth.yaml

kubectl delete sc gp2 || echo "storage class 'gp2' already deleted"

# install aws-ebs-csi-driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
EBS_CSI_DRIVER_IAM_ROLE_NAME=$(terraform output ebs_csi_driver_iam_role_name)
EBS_CSI_CONTROLLER_PATCH=$(cat << EOF
{"spec": {
   "template": {
     "metadata": {
       "annotations": {
         "iam.amazonaws.com/role": "${EBS_CSI_DRIVER_IAM_ROLE_NAME}"}
      }
    }
  }
}
EOF
)
kubectl -n kube-system patch deploy ebs-csi-controller --patch="$EBS_CSI_CONTROLLER_PATCH"
# create ebs default storage class
kubectl apply -f ebs-storage-class.yaml

# install aws-efs-csi-driver
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
# create efs storage class
kubectl apply -f efs-storage-class.yaml
#create efs volume
kubectl apply -f ./terraform.tfstate.d/$TERRAFORM_WORKSPACE/efs-persistent-volume.yaml
#fix efs permissions
kubectl apply --wait -f fix-efs-file-permissions-job.yaml
kubectl delete --wait -f fix-efs-file-permissions-job.yaml
#release efs volume
kubectl patch pv efs-pv --patch '{"spec":{"claimRef": null}}'

# create service account and role for admin
kubectl apply -f $DIR/eks-admin-service-account.yaml
kubectl apply -f $DIR/eks-admin-cluster-role-binding.yaml

# init helm
helm repo add stable https://kubernetes-charts.storage.googleapis.com
#helm init --wait --client-only
helm repo update

#helm 3 doesn't need Tiller
#killall tiller || echo "no tiller started"
#tiller &
#export HELM_HOST=localhost:44134

# wait for at least 1 node
while [[ ! $(kubectl get nodes | grep -i ready) ]]; do
  echo "INFO waiting for nodes"
  sleep 1;
done

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
# helm 3 doesn't install it for some reason
#helm upgrade --install --wait --dry-run \
#  --namespace monitoring \
#  --values ./prometheus-operator-helm-chart-values.yaml \
#  --version $PROMETHEUS_OPERATOR_HELM_CHART_VERSION \
#  prometheus-operator stable/prometheus-operator
#helm upgrade --install --wait \
#  --namespace monitoring \
#  --values ./prometheus-operator-helm-chart-values.yaml \
#  --version $PROMETHEUS_OPERATOR_HELM_CHART_VERSION \
#  prometheus-operator stable/prometheus-operator


cat << EOF
Your kubeconfig is here: terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf
Run "export KUBECONFIG=terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf" to manage the cluster via kubectl
EOF
