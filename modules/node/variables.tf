variable "node_create" { default = "0" }
variable "node_vpc_id" {}
variable "node_vpc_zone_identifier" {type = "list" }
variable "node_security_group_id" {}
variable "node_eks_cluster_name" {}
variable "node_k8s_version" {}
variable "node_eks_endpoint" {}
variable "node_eks_security_group_id" {}
variable "node_eks_ca" {}
variable "node_iam_instance_profile_name" {}
variable "node_key_pair_name" {}
variable "node_launch_configuration_instance_type" {default = "t2.micro"}
variable "node_launch_configuration_volume_type" {default = "standard"}
variable "node_launch_configuration_volume_size" {default = "20"}
variable "node_launch_configuration_type" {} //values: on_demand or spot
variable "node_launch_configuration_spot_price" {default = "0.0035"}
variable "node_launch_configuration_name_prefix" {}
variable "node_autoscaling_group_desired_capacity" {default = "1"}
variable "node_autoscaling_group_min_number" {default = "1"}
variable "node_autoscaling_group_max_number" {default = "3"}
variable "node_autoscaling_group_name" {}
variable "node_iam_role_name" {}

// e.g. --register-with-taints=key=value:NoSchedule --node-labels=aws_autoscaling_group_name=${var.node_autoscaling_group_name}'
variable "node_kubelet_extra_args" {}


