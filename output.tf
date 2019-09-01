data "template_file" "cluster_autoscaler_helm_chart_values_t_yaml" {
  template = "${file("cluster-autoscaler-helm-chart-values.t.yaml")}"
  vars = {
    aws_region = "${data.aws_region.current.name}"
    eks_cluster_name = "${var.eks_cluster_name}"
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
  }
}

data "template_file" "config_map_aws_auth" {
  template = "${file("config-map-aws-auth.t.yaml")}"
  vars = {
    system_node_iam_role_arn  = "${module.system_node_iam_role.node_iam_role_arn}"
    regular_node_iam_role_arn = "${module.regular_node_iam_role.node_iam_role_arn}"
    eks_admin_iam_role_arn   = "${module.eks_iam_role.eks_admin_iam_role_arn}"
  }
}

data "template_file" "kube2iam_helm_chart_values_t_yaml" {
  template = "${file("kube2iam-helm-chart-values.t.yaml")}"
  vars = {
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    aws_region = "${data.aws_region.current.name}"
  }
}

resource "local_file" "cluster_autoscaller_yaml" {
  filename  = "./terraform.tfstate.d/${terraform.workspace}/cluster-autoscaler-helm-chart-values.yaml"
  content   = "${data.template_file.cluster_autoscaler_helm_chart_values_t_yaml.rendered}"
}

resource "local_file" "config_map_aws_auth" {
  content  = "${data.template_file.config_map_aws_auth.rendered}"
  filename = "./terraform.tfstate.d/${terraform.workspace}/config-map-aws-auth.yaml"
}

resource "local_file" "kube2iam_helm_chart_values" {
  content  = "${data.template_file.kube2iam_helm_chart_values_t_yaml.rendered}"
  filename = "./terraform.tfstate.d/${terraform.workspace}/kube2iam-helm-chart-values.yaml"
}

output execute {
  value = <<RUN
#Genereted kubeconfig.conf, cluster-autoscaler.yaml and map-aws-auth.yaml
#Tun this to finish nodes bootstraping.
#1 kubeconfig is located in workspace folder
export KUBECONFIG=./terraform.tfstate.d/${terraform.workspace}/kubeconfig.conf
#2 apply map-aws-auth.yaml to finish nodes bootstraping
kubectl apply -f ./terraform.tfstate.d/${terraform.workspace}/config-map-aws-auth.yaml
#3 wait for at least 1 node
kubectl get nodes --watch
#4 init helm and run local tiller
helm init --wait --client-only
helm repo update
killall tiller; tiller &
export HELM_HOST=localhost:44134
#5 deploy kube2iam
helm upgrade --install --wait --namespace kube-system --values ./terraform.tfstate.d/${terraform.workspace}/kube2iam-helm-chart-values.yaml kube2iam stable/kube2iam
#6 deploy cluster autoscaler
helm upgrade --install --wait --namespace kube-system --values ./terraform.tfstate.d/${terraform.workspace}/cluster-autoscaler-helm-chart-values.yaml cluster-autoscaler stable/cluster-autoscaler
#7 deploy dashboard
helm upgrade --install --wait --namespace kube-system  kubernetes-dashboard stable/kubernetes-dashboard
#9 create service accout and role for admin
kubectl apply -f eks-admin-service-account.yaml
kubectl apply -f eks-admin-cluster-role-binding.yaml
#10 get a token to login dashboard with
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')
#11 proxy dashboard port on your localhost
kubectl proxy &
#12 open dashboard and login with that token from the step #10
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#!/login
#13 Add additional AWS IAM users that are supposed to be EKS admins to the group ${module.eks_iam_role.eks_admin_iam_group_arn}
#The users then should assume the role in order to get AWS EKS credentials
#OPTION 1
aws sts assume-role --role-arn ${module.eks_iam_role.eks_admin_iam_role_arn} --role-session-name ${var.eks_cluster_name}
export AWS_ACCESS_KEY_ID="get it from 'aws sts assume-role' output"
export AWS_SECRET_ACCESS_KEY="get it from 'aws sts assume-role' output"
export AWS_SESSION_TOKEN="get it from 'aws sts assume-role' output"
#OPTION 2: add new profile to your ~/.aws/config:
[${var.eks_cluster_name}]
role_arn = ${module.eks_iam_role.eks_admin_iam_role_arn}
source_profile = YOUR_EXISTING_AWS_PROFILE
#then activate the profile
export AWS_PROFILE=${var.eks_cluster_name}
RUN
}
