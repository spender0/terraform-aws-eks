data "template_file" "cluster_autoscaler_helm_chart_values_t_yaml" {
  template = "${file("cluster-autoscaler-helm-chart-values.t.yaml")}"
  vars = {
    aws_region = "${data.aws_region.current.name}"
    eks_cluster_name = "${var.eks_cluster_name}"
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
  }
}

data "template_file" "efs_persistent_volume" {
  template = "${file("efs-persistent-volume.t.yaml")}"
  vars = {
    efs_fs_id  = "${module.efs.efs_fs_id}"
  }
}

data "template_file" "kube2iam_helm_chart_values_t_yaml" {
  template = "${file("kube2iam-helm-chart-values.t.yaml")}"
  vars = {
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    aws_region = "${data.aws_region.current.name}"
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

resource "local_file" "efs_persistent_volume" {
  content  = "${data.template_file.efs_persistent_volume.rendered}"
  filename = "./terraform.tfstate.d/${terraform.workspace}/efs-persistent-volume.yaml"
}

output "ebs_csi_driver_iam_role_arn" {
  value = "${module.ebs_csi_driver_iam_role.ebs_csi_driver_iam_role_arn}"
}

output "ebs_csi_driver_iam_role_name" {
  value = "${module.ebs_csi_driver_iam_role.ebs_csi_driver_iam_role_name}"
}

output execute {
  value = <<RUN
Run "export KUBECONFIG=./terraform.tfstate.d/${terraform.workspace}/kubeconfig.conf" to apply kubeconfig file
Run "kubectl apply -f ./terraform.tfstate.d/${terraform.workspace}/config-map-aws-auth.yaml" to finish nodes bootstrapping
Run "install.sh" script to install main components and helm charts
RUN
}
