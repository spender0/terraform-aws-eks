
output "ebs_csi_driver_iam_role_arn" {
  value = "${aws_iam_role.ebs_csi_driver.arn}"
}

output "ebs_csi_driver_iam_role_name" {
  value = "${aws_iam_role.ebs_csi_driver.name}"
}

output "ebs_csi_driver_iam_assume_policy_arn" {
  value = "${aws_iam_policy.assume.arn}"
}

output "ebs_csi_driver_iam_assume_policy_name" {
  value = "${aws_iam_policy.assume.name}"
}