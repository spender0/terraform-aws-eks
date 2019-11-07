variable "node_iam_role_name" {}
#variable "node_iam_role_cluster_autoscaler_role_name" {}
#variable "node_iam_role_ebs_csi_driver_role_name" {}
variable "node_iam_role_can_assume_role_policy_arns" {type="list"}
variable "node_iam_role_aws_account_id" {}
