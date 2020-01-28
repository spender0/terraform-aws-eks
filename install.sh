#!/usr/bin/bash

# exit when any command fails
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd $DIR

TERRAFORM_WORKSPACE="$(terraform workspace show | grep -oP '(.*:)?\K(.*)')"

# kubeconfig located in workspace folder
export KUBECONFIG=./terraform.tfstate.d/$TERRAFORM_WORKSPACE/kubeconfig.conf

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


#fix efs permissions
kubectl apply --wait -f fix-efs-file-permissions-job.yaml
kubectl delete --wait -f fix-efs-file-permissions-job.yaml
#release efs volume
kubectl patch pv efs-pv --patch '{"spec":{"claimRef": null}}'




