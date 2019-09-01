provider "aws" {
}
terraform {
  backend "s3" {}
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

//import ssh public key
resource "aws_key_pair" "key-pair" {
  key_name   = "${var.eks_cluster_name}"
  public_key = "${file(var.aws_key_pair_public_key_path)}"
}

module "net" {
  source                = "./modules/net"
  net_vpc_name          = "${var.eks_cluster_name}"
  net_eks_cluster_name  = "${var.eks_cluster_name}"
  net_route_table_name  = "${var.eks_cluster_name}"
  net_vpc_cidr_block    = "${var.net_vpc_cidr_block}"
  net_subnet_cidr_block = "${var.net_subnet_cidr_block}"
}

#create security groups
module "security_group" {
  source = "./modules/security_group"
  security_group_name_eks                 = "${var.eks_cluster_name}"
  security_group_name_node                = "${var.eks_cluster_name}-node"
  security_group_vpc_id                   = "${module.net.net_vpc_id}"
  security_group_eks_external_cidr_blocks = "${var.security_group_eks_external_cidr_blocks}"
  security_group_eks_cluster_name         = "${var.eks_cluster_name}"
}



#create iam role for system nodes
module "system_node_iam_role" {
  source                                          = "./modules/node_iam_role"
  node_iam_role_name                              = "${var.eks_cluster_name}-system-node"
  node_iam_role_cluster_autoscaler_role_name      = "${var.eks_cluster_name}-cluster-autoscaler"
  node_iam_role_aws_account_id                    = "${data.aws_caller_identity.current.account_id}"
}

#create iam role for other nodes
module "regular_node_iam_role" {
  source                                          = "./modules/node_iam_role"
  node_iam_role_name                              = "${var.eks_cluster_name}-regular-node"
  node_iam_role_cluster_autoscaler_role_name      = "${var.eks_cluster_name}-cluster-autoscaler"
  node_iam_role_aws_account_id                    = "${data.aws_caller_identity.current.account_id}"
}

#create cluster autoscaler iam role
module "cluster_autoscaler_iam_role" {
  source = "./modules/cluster_autoscaler_iam_role"
  cluster_autoscaler_iam_role_name         = "${var.eks_cluster_name}-cluster-autoscaler"
  cluster_autoscaler_iam_policy_name       = "${var.eks_cluster_name}-cluster-autoscaler"
  cluster_autoscaler_assuming_iam_role_arn = "${module.system_node_iam_role.node_iam_role_arn}"
}

#create eks role
module "eks_iam_role" {
  source = "./modules/eks_iam_role"
  eks_iam_role_name         = var.eks_cluster_name
  eks_admin_iam_group_name  = "${var.eks_cluster_name}-eks-admin"
  eks_admin_iam_role_name  = "${var.eks_cluster_name}-eks-admin"
  eks_admin_iam_policy_name  = "${var.eks_cluster_name}-eks-admin"
}

#create eks
module "eks" {
  source = "./modules/eks"
  eks_cluster_name          = "${var.eks_cluster_name}"
  eks_k8s_version           = "${var.k8s_version}"
  eks_vpc_id                = "${module.net.net_vpc_id}"
  eks_cluster_subnet_ids    = module.net.net_vpc_subnet_ids
  eks_security_group_ids     = ["${module.security_group.security_group_id_eks}"]
  eks_iam_role_arn         = "${module.eks_iam_role.eks_iam_role_arn}"
}

#create system nodes for running such applications as kubernetes-dashboard and cluster-autscaller
module "system_node" {
  source                                  = "./modules/node"
  node_create                             = "${var.system_node_create}"
  node_iam_role_name                      = "${module.system_node_iam_role.node_iam_role_name}"
  node_iam_instance_profile_name          = "${var.eks_cluster_name}-system-node"
  node_key_pair_name                      = "${aws_key_pair.key-pair.key_name}"
  node_launch_configuration_name_prefix   = "${var.eks_cluster_name}-system-node"
  node_autoscaling_group_name             = "${var.eks_cluster_name}-system-node"
  node_autoscaling_group_desired_capacity = "${var.system_node_autoscaling_group_desired_capacity}"
  node_autoscaling_group_min_number       = "${var.system_node_autoscaling_group_min_number}"
  node_autoscaling_group_max_number       = "${var.system_node_autoscaling_group_max_number}"
  node_launch_configuration_instance_type = "${var.system_node_launch_configuration_instance_type}"
  node_launch_configuration_volume_type   = "${var.system_node_launch_configuration_volume_type}"
  node_launch_configuration_volume_size   = "${var.system_node_launch_configuration_volume_size}"
  node_launch_configuration_type          = "on_demand"
  node_eks_cluster_name                   = "${var.eks_cluster_name}"
  node_eks_endpoint                       = "${module.eks.eks_cluster_endpoint}"
  node_eks_security_group_id              = "${module.security_group.security_group_id_eks}"
  node_eks_ca                             = "${module.eks.eks_cluster_ca_data}"
  node_k8s_version                        = "${var.k8s_version}"
  node_vpc_id                             = "${module.net.net_vpc_id}"
  node_vpc_zone_identifier                = module.net.net_vpc_subnet_ids
  node_security_group_id                  = "${module.security_group.security_group_id_node}"
  node_kubelet_extra_args                 = "--register-with-taints=node-role.kubernetes.io/system=system:PreferNoSchedule --node-labels=aws_autoscaling_group_name=${var.eks_cluster_name}-system-node,node-role.kubernetes.io/system=system"
}


#create spot nodes for running stateless and replicated applications
#where removing a host doesn't harm distributed application cluster
module "spot_node" {
  source                                  = "./modules/node"
  node_create                             = "${var.spot_node_create}"
  node_iam_role_name                      = "${module.regular_node_iam_role.node_iam_role_name}"
  node_iam_instance_profile_name          = "${var.eks_cluster_name}-spot-node"
  node_key_pair_name                      = "${aws_key_pair.key-pair.key_name}"
  node_launch_configuration_name_prefix   = "${var.eks_cluster_name}-spot-node"
  node_autoscaling_group_name             = "${var.eks_cluster_name}-spot-node"
  node_autoscaling_group_desired_capacity = "${var.spot_node_autoscaling_group_desired_capacity}"
  node_autoscaling_group_min_number       = "${var.spot_node_autoscaling_group_min_number}"
  node_autoscaling_group_max_number       = "${var.spot_node_autoscaling_group_max_number}"
  node_launch_configuration_instance_type = "${var.spot_node_launch_configuration_instance_type}"
  node_launch_configuration_volume_type   = "${var.spot_node_launch_configuration_volume_type}"
  node_launch_configuration_volume_size   = "${var.spot_node_launch_configuration_volume_size}"
  node_launch_configuration_type          = "spot"
  node_launch_configuration_spot_price    = "${var.spot_node_launch_configuration_spot_price}"
  node_eks_cluster_name                   = "${var.eks_cluster_name}"
  node_eks_endpoint                       = "${module.eks.eks_cluster_endpoint}"
  node_eks_security_group_id              = "${module.security_group.security_group_id_eks}"
  node_eks_ca                             = "${module.eks.eks_cluster_ca_data}"
  node_k8s_version                        = "${var.k8s_version}"
  node_vpc_id                             = "${module.net.net_vpc_id}"
  node_vpc_zone_identifier                = module.net.net_vpc_subnet_ids
  node_security_group_id                  = "${module.security_group.security_group_id_node}"
  node_kubelet_extra_args                 = "--register-with-taints=node-role.kubernetes.io/spot=spot:PreferNoSchedule --node-labels=aws_autoscaling_group_name=${var.eks_cluster_name}-spot-node,node-role.kubernetes.io/regular=regular,node-role.kubernetes.io/spot=spot"
}


#create on_demand nodes group for running other applications
#these are default nodes
module "on_demand_node" {
  source                                  = "./modules/node"
  node_create                             = "${var.on_demand_node_create}"
  node_iam_role_name                      = "${module.regular_node_iam_role.node_iam_role_name}"
  node_iam_instance_profile_name          = "${var.eks_cluster_name}-on-demand-node"
  node_key_pair_name                      = "${aws_key_pair.key-pair.key_name}"
  node_launch_configuration_name_prefix   = "${var.eks_cluster_name}-on-demand-node"
  node_autoscaling_group_name             = "${var.eks_cluster_name}-on-demand-node"
  node_autoscaling_group_desired_capacity = "${var.on_demand_node_autoscaling_group_desired_capacity}"
  node_autoscaling_group_min_number       = "${var.on_demand_node_autoscaling_group_min_number}"
  node_autoscaling_group_max_number       = "${var.on_demand_node_autoscaling_group_max_number}"
  node_launch_configuration_instance_type = "${var.on_demand_node_launch_configuration_instance_type}"
  node_launch_configuration_volume_type   = "${var.on_demand_node_launch_configuration_volume_type}"
  node_launch_configuration_volume_size   = "${var.on_demand_node_launch_configuration_volume_size}"
  node_launch_configuration_type          = "on_demand"
  node_eks_cluster_name                   = "${var.eks_cluster_name}"
  node_eks_endpoint                       = "${module.eks.eks_cluster_endpoint}"
  node_eks_security_group_id              = "${module.security_group.security_group_id_eks}"
  node_eks_ca                             = "${module.eks.eks_cluster_ca_data}"
  node_k8s_version                        = "${var.k8s_version}"
  node_vpc_id                             = "${module.net.net_vpc_id}"
  node_vpc_zone_identifier                = module.net.net_vpc_subnet_ids
  node_security_group_id                  = "${module.security_group.security_group_id_node}"
  node_kubelet_extra_args                 = "--node-labels=aws_autoscaling_group_name=${var.eks_cluster_name}-on-demand-node,node-role.kubernetes.io/regular=regular"
}
