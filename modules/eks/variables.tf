variable "eks_cluster_name" {}
variable "eks_k8s_version" {}
variable "eks_security_group_id" {}
variable "eks_vpc_id" {}
variable "eks_cluster_subnet_ids" {
  type = "list"
}

variable "eks_iam_role_arn" {}

