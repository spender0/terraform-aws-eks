
output "cluster_autoscaler_iam_role_arn" {
  value = "${aws_iam_role.cluster-autoscaler.arn}"
}

output "cluster_autoscaler_iam_role_name" {
  value = "${aws_iam_role.cluster-autoscaler.name}"
}

output "cluster_autoscaler_iam_assume_policy_arn" {
  value = "${aws_iam_policy.assume.arn}"
}