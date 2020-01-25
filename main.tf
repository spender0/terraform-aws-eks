provider "aws" {
}
terraform {
  backend "s3" {
    #dynamodb_table = "terraform-state-lock"
    encrypt= "true"
    key= "terraform-aws-eks.state"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

//import ssh public key
resource "aws_key_pair" "key-pair" {
  key_name   = "${var.eks_cluster_name}"
  public_key = "${file(var.aws_key_pair_public_key_path)}"
}


module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"
  version = "2.24.0"

  name = var.eks_cluster_name

  cidr = var.net_vpc_cidr_block

  enable_dns_hostnames = true

  azs             = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b"]
  private_subnets = var.net_private_subnet_cidr_blocks
  public_subnets  = var.net_public_subnet_cidr_blocks


  enable_nat_gateway = false # No need in nat, EC2 instances public IPs are free

  tags = {
    Terraform   = true
    Environment = terraform.workspace
    Name        = var.eks_cluster_name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}


#create security groups
module "eks_node_security_group" {
  source                                = "terraform-aws-modules/security-group/aws"
  version                               = "3.4.0"

  name                                  = "${var.eks_cluster_name}-node"
  description                           = "Security group for EKS nodes"
  vpc_id                                = module.vpc.vpc_id
  egress_rules                          = ["all-all"]
  ingress_with_source_security_group_id = [
    {
      from_port                = 0
      to_port                  = 65535
      protocol                 = "-1"
      description              = "Allow k8s nodes ccommunicate to each other"
      source_security_group_id = module.eks_node_security_group.this_security_group_id
    },
    {
      from_port                = 1025
      to_port                  = 65535
      protocol                 = "tcp"
      description              = "Allow EKS server connect to nodes"
      source_security_group_id = module.eks_server_security_group.this_security_group_id
    },
  ]
  tags = {
    Terraform   = true
    Name        = "${var.eks_cluster_name}-node"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}


module "eks_server_security_group" {
  source                                = "terraform-aws-modules/security-group/aws"
  version                               = "3.4.0"

  name                                  = var.eks_cluster_name
  description                           = "Security group for example usage with ALB"
  vpc_id                                = module.vpc.vpc_id
  egress_rules                          = ["all-all"]
  ingress_with_source_security_group_id = [
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "Allow k8s nodes connect to EKS server"
      source_security_group_id = module.eks_node_security_group.this_security_group_id
    }
  ]
  ingress_with_cidr_blocks = [
    for cidr in var.security_group_eks_external_cidr_blocks: {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow users connect to EKS server"
      cidr_blocks = cidr
    }
  ]
  tags = {
    Terraform   = true
    Name        = "${var.eks_cluster_name}"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}


#create cluster autoscaler iam role
module "cluster_autoscaler_iam_role" {
  source = "./modules/cluster_autoscaler_iam_role"
  cluster_autoscaler_iam_role_name         = "${var.eks_cluster_name}-cluster-autoscaler"
  cluster_autoscaler_iam_policy_name       = "${var.eks_cluster_name}-cluster-autoscaler"
  cluster_autoscaler_can_be_assumed_by_iam_role_arns = [
    "${module.system_node_iam_role.node_iam_role_arn}"
  ]
}

#create ebs_csi_driver iam role
module "ebs_csi_driver_iam_role" {
  source = "./modules/ebs_csi_driver_iam_role"
  ebs_csi_driver_iam_role_name         = "${var.eks_cluster_name}-ebs-csi-driver"
  ebs_csi_driver_iam_policy_name       = "${var.eks_cluster_name}-ebs-csi-driver"
  ebs_csi_driver_can_be_assumed_by_iam_role_arns = [
    "${module.system_node_iam_role.node_iam_role_arn}",
    "${module.regular_node_iam_role.node_iam_role_arn}"
  ]
}

#create iam role for system nodes
module "system_node_iam_role" {
  source                                          = "./modules/node_iam_role"
  node_iam_role_name                              = "${var.eks_cluster_name}-system-node"
  node_iam_role_can_assume_role_policy_arns       = [
      "${module.ebs_csi_driver_iam_role.ebs_csi_driver_iam_assume_policy_arn}",
      "${module.cluster_autoscaler_iam_role.cluster_autoscaler_iam_assume_policy_arn}"
  ]
  node_iam_role_aws_account_id                    = "${data.aws_caller_identity.current.account_id}"
}

#create iam role for other nodes
module "regular_node_iam_role" {
  source                                          = "./modules/node_iam_role"
  node_iam_role_name                              = "${var.eks_cluster_name}-regular-node"
  node_iam_role_can_assume_role_policy_arns       = [
      "${module.ebs_csi_driver_iam_role.ebs_csi_driver_iam_assume_policy_arn}"
  ]
  node_iam_role_aws_account_id                    = "${data.aws_caller_identity.current.account_id}"
}

#create eks role
module "eks_iam_role" {
  source = "./modules/eks_iam_role"
  eks_iam_role_name         = var.eks_cluster_name
  eks_admin_iam_group_name  = "${var.eks_cluster_name}-eks-admin"
  eks_admin_iam_role_name  = "${var.eks_cluster_name}-eks-admin"
  eks_admin_iam_policy_name  = "${var.eks_cluster_name}-eks-admin"
}

#efs volume
module "efs" {
  source                        = "./modules/efs"
  efs_name                      = var.eks_cluster_name
  efs_node_security_group_id    = module.eks_node_security_group.this_security_group_id
  efs_node_subnet_ids           = module.vpc.public_subnets
}

#create eks
module "eks" {
  source = "./modules/eks"
  eks_cluster_name          = "${var.eks_cluster_name}"
  eks_k8s_version           = "${var.k8s_version}"
  eks_vpc_id                = "${module.vpc.vpc_id}"
  eks_cluster_subnet_ids    = module.vpc.public_subnets
  eks_security_group_ids     = ["${module.eks_server_security_group.this_security_group_id}"]
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
  //node_eks_security_group_id              = "${ module.eks_node_security_group.this_security_group_id}"
  node_eks_ca                             = "${module.eks.eks_cluster_ca_data}"
  node_k8s_version                        = "${var.k8s_version}"
  node_vpc_id                             = "${module.vpc.vpc_id}"
  node_vpc_zone_identifier                = module.vpc.public_subnets
  node_security_group_id                  = module.eks_node_security_group.this_security_group_id
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
  //node_eks_security_group_id              = "module.eks_node_security_group.this_security_group_id
  node_eks_ca                             = "${module.eks.eks_cluster_ca_data}"
  node_k8s_version                        = "${var.k8s_version}"
  node_vpc_id                             = module.vpc.vpc_id
  node_vpc_zone_identifier                = module.vpc.public_subnets
  node_security_group_id                  = module.eks_node_security_group.this_security_group_id
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
  //node_eks_security_group_id              = "${module.security_group.security_group_id_eks}"
  node_eks_ca                             = "${module.eks.eks_cluster_ca_data}"
  node_k8s_version                        = "${var.k8s_version}"
  node_vpc_id                             = "${module.vpc.vpc_id}"
  node_vpc_zone_identifier                = module.vpc.public_subnets
  node_security_group_id                  = module.eks_node_security_group.this_security_group_id
  node_kubelet_extra_args                 = "--node-labels=aws_autoscaling_group_name=${var.eks_cluster_name}-on-demand-node,node-role.kubernetes.io/regular=regular"
}
