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


module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"
  version = "2.24.0"

  name = var.eks_cluster_name

  cidr = var.net_vpc_cidr_block

  enable_dns_hostnames = true

  azs             = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}b",
    "${data.aws_region.current.name}c",
    "${data.aws_region.current.name}d"
  ]
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



resource "aws_efs_file_system" "efs" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_90_DAYS"
  }
  tags = {
    Terraform   = true
    Name        = var.eks_cluster_name
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}

module "efs_security_group" {
  source                                = "terraform-aws-modules/security-group/aws"
  version                               = "3.4.0"
  name                                  = "${var.eks_cluster_name}-efs"
  description                           = "Security group for TeamCity EFS storage"
  vpc_id                                = module.vpc.vpc_id
  egress_rules                          = ["all-all"]
  ingress_with_source_security_group_id = [
    {
      from_port                = 2049
      to_port                  = 2049
      protocol                 = "tcp"
      description              = "Allow EC2 instantes connect to EFS"
      source_security_group_id = module.eks_cluster.worker_security_group_id
    },
  ]
  tags = {
    Terraform   = true
    Name        = "${var.eks_cluster_name}-efs"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}

resource "aws_efs_mount_target" "public_subnets" {
  count           = length(module.vpc.public_subnets)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = "${element(module.vpc.public_subnets, count.index)}"
  security_groups = ["${module.efs_security_group.this_security_group_id}"]
}






#create admin eks role and group
module "eks_admin_iam_role" {
  source = "./modules/eks_admin_iam_role"
  eks_admin_iam_group_name  = "${var.eks_cluster_name}-eks-admin"
  eks_admin_iam_role_name  = "${var.eks_cluster_name}-eks-admin"
  eks_admin_iam_policy_name  = "${var.eks_cluster_name}-eks-admin"
}


data "aws_eks_cluster_auth" "eks" {
  name = module.eks_cluster.cluster_id
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
  load_config_file       = false
}



module "eks_cluster" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "8.1.0"
  cluster_version = var.k8s_version
  create_eks   = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_name = var.eks_cluster_name
  subnets      = module.vpc.public_subnets
  tags = {
    Terraform   = true
    Name        = "${var.eks_cluster_name}"
    Environment = terraform.workspace
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
  vpc_id = module.vpc.vpc_id
  worker_groups_launch_template = [
    {
      name                 = "system-node"
      instance_type        = var.system_node_instance_type
      root_volume_size     = var.system_node_volume_size
      root_volume_type     = var.system_node_volume_type
      asg_desired_capacity = var.system_node_asg_desired_capacity
      asg_min_size         = var.system_node_asg_min_number
      asg_max_size         = var.system_node_asg_max_number
      public_ip            = true
      autoscaling_enabled  = true
      protect_from_scale_in= true
      kubelet_extra_args   =  <<ARGS
--register-with-taints=node-role.kubernetes.io/system=system:PreferNoSchedule \
--node-labels=node-role.kubernetes.io/system=system,\
aws_autoscaling_group_name=${var.eks_cluster_name}-system-node\
ARGS
    },
    {
      name                 = "regular-node"
      instance_type        = var.on_demand_node_instance_type
      root_volume_size     = var.on_demand_node_volume_size
      root_volume_type     = var.on_demand_node_volume_type
      asg_desired_capacity = var.on_demand_node_asg_desired_capacity
      asg_min_size         = var.on_demand_node_asg_min_number
      asg_max_size         = var.on_demand_node_asg_max_number
      public_ip            = true
      autoscaling_enabled  = true
      protect_from_scale_in= true
      kubelet_extra_args   =  <<ARGS
--node-labels=node-role.kubernetes.io/regular=regular,\
aws_autoscaling_group_name=${var.eks_cluster_name}-regular-node\
ARGS
    },
    {
      name                 = "spot"
      override_instance_types = var.spot_node_override_instance_types
      spot_max_price          = var.spot_node_max_price
      spot_instance_pools     = 4
      root_volume_size     = var.spot_node_volume_size
      root_volume_type     = var.spot_node_volume_type
      asg_desired_capacity = var.spot_node_asg_desired_capacity
      asg_min_size         = var.spot_node_asg_min_number
      asg_max_size         = var.spot_node_asg_max_number
      public_ip            = true
      autoscaling_enabled  = false
      kubelet_extra_args   =  <<ARGS
--register-with-taints=node-role.kubernetes.io/system=system:PreferNoSchedule \
--node-labels=node-role.kubernetes.io/spot=spot,kubernetes.io/lifecycle=spot\
aws_autoscaling_group_name=${var.eks_cluster_name}-spot-node\
ARGS
    },
  ]
  #allow workers assume cluster-autoscaller role
  workers_additional_policies = [
    "${aws_iam_policy.workers_can_assume_cluster_autoscaler_role.arn}",
    "${module.ebs_csi_driver_iam_role.ebs_csi_driver_iam_assume_policy_arn}"
  ]
  map_roles = [
    {
      rolearn  = module.eks_admin_iam_role.eks_admin_iam_role_arn
      username = "system:*"
      groups   = ["system:masters"]
    }
  ]
  #map_users                            =
  #map_accounts                         =
}


resource "kubernetes_service_account" "tiller" {
  depends_on =  [module.eks_cluster,]
  metadata {
    name = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  depends_on =  [module.eks_cluster,]
  metadata {
    name = "tiller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
  }
}

provider "helm" {
  kubernetes {
    load_config_file = false
    host     = module.eks_cluster.cluster_endpoint
    token    = data.aws_eks_cluster_auth.eks.token
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  }
  service_account = "${kubernetes_service_account.tiller.metadata.0.name}"
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "kube2iam" {
  depends_on =  [module.eks_cluster,]
  name       = "kube2iam"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "kube2iam"
  namespace  = "kube-system"
  version    = "2.1.0"
  set {
    name  = "aws.region"
    value = data.aws_region.current.name
  }
  set {
    name  = "host.interface"
    value = "eni+"
  }
  set {
    name  = "host.iptables"
    value = "true"
  }
//  set {
//    name  = "extraArgs.base-role-arn"
//    value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/"
//  }
  set {
    name  = "extraArgs.auto-discover-default-role"
    value = "true"
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
}


data "aws_iam_policy_document" "cluster_autoscaler_can_be_assumed_by" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = ["${module.eks_cluster.worker_iam_role_arn}"]
      type = "AWS"
    }
    effect = "Allow"
  }
}
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.eks_cluster_name}-claster-autoscaller"
  assume_role_policy = "${data.aws_iam_policy_document.cluster_autoscaler_can_be_assumed_by.json}"
}
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = module.eks_cluster.worker_autoscaling_policy_arn
  role       = aws_iam_role.cluster_autoscaler.name
}
resource "aws_iam_policy" "workers_can_assume_cluster_autoscaler_role" {
  name        = "${var.eks_cluster_name}-claster-autoscaller-assume"
  path        = "/"
  description = "For assuming ${aws_iam_role.cluster_autoscaler.name} role"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Resource": ["${aws_iam_role.cluster_autoscaler.arn}"]
      }
    ]
}
EOF
}

resource "helm_release" "cluster-autoscaler" {
  depends_on =  [module.eks_cluster,]
  name       = "cluster-autoscaler"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "6.2.0"
  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }
  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks_cluster.cluster_id
  }
  set_string {
    name  = "nodeSelector.node-role\\.kubernetes\\.io/system"
    value = "system"
  }
  set_string {
    name  = "podAnnotations.iam\\.amazonaws\\.com/role"
    value = aws_iam_role.cluster_autoscaler.name
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
}


resource "helm_release" "kubernetes-dashboard" {
  depends_on =  [module.eks_cluster,]
  name       = "kubernetes-dashboard"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "kubernetes-dashboard"
  namespace  = "kube-system"
  version    = "1.10.1"
  set_string {
    name  = "nodeSelector.node-role\\.kubernetes\\.io/system"
    value = "system"
  }
}

#create iam role for aws-ebs-csi-driver
module "ebs_csi_driver_iam_role" {
  source = "./modules/ebs_csi_driver_iam_role"
  ebs_csi_driver_iam_role_name         = "${var.eks_cluster_name}-ebs-csi-driver"
  ebs_csi_driver_iam_policy_name       = "${var.eks_cluster_name}-ebs-csi-driver"
  ebs_csi_driver_can_be_assumed_by_iam_role_arns = [
    "${module.eks_cluster.worker_iam_role_arn}"
  ]
}

resource "null_resource" "install_aws-ebs-csi-driver" {
  depends_on = [module.eks_cluster]
  provisioner "local-exec" {
    command = <<CMD
kubectl --kubeconfig=kubeconfig_${var.eks_cluster_name} \
  apply -k 'github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master'
CMD
  }
}

resource "kubernetes_storage_class" "aws-ebs-csi-driver" {
  depends_on = [null_resource.install_aws-ebs-csi-driver]
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
}

resource "null_resource" "delete_old_sc" {
  depends_on = [kubernetes_storage_class.aws-ebs-csi-driver]
  provisioner "local-exec" {
    command = <<CMD
kubectl --kubeconfig=kubeconfig_${var.eks_cluster_name} delete sc gp2|| \
echo 'storage class gp2 already deleted'
CMD
  }
}


resource "null_resource" "install_aws-efs-csi-driver" {
  depends_on = [module.eks_cluster]
  provisioner "local-exec" {
    command = <<CMD
kubectl --kubeconfig=kubeconfig_${var.eks_cluster_name} \
  apply -k 'github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master'
CMD
  }
}

resource "kubernetes_storage_class" "aws-efs-csi-driver" {
  depends_on = [null_resource.install_aws-efs-csi-driver]
  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
}

data "template_file" "efs_persistent_volume" {
  template = "${file("efs-persistent-volume.t.yaml")}"
  vars = {
    efs_fs_id  = "${aws_efs_file_system.efs.id}"
  }
}

resource "local_file" "efs_persistent_volume" {
  content  = "${data.template_file.efs_persistent_volume.rendered}"
  filename = "./terraform.tfstate.d/${terraform.workspace}/efs-persistent-volume.yaml"
}

resource "null_resource" "install_efs-pv" {
  depends_on = [module.eks_cluster]
  provisioner "local-exec" {
    command = <<CMD
kubectl --kubeconfig=kubeconfig_${var.eks_cluster_name} \
  apply -f ./terraform.tfstate.d/${terraform.workspace}/efs-persistent-volume.yaml
CMD
  }
}

resource "kubernetes_namespace" "monitoring" {
  depends_on = [module.eks_cluster,]
  metadata {
    annotations = {
      name = "monitoring"
    }
    name = "monitoring"
  }
}


resource "helm_release" "prometheus-operator" {
  depends_on =  [kubernetes_storage_class.aws-ebs-csi-driver]
  name       = "prometheus-operator"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "prometheus-operator"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "8.5.14"
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }
  set {
    name  = "prometheus.prometheusSpec.retentionSize"
    value = "9GB"
  }
  set {
    name  = "prometheusprometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = kubernetes_storage_class.aws-ebs-csi-driver.metadata[0].name
  }
  set {
    name  = "prometheusprometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes"
    value = "[\"ReadWriteOnce\"]"
  }
  set {
    name  = "prometheusprometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }
}
