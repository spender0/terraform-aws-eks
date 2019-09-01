output "eks_iam_role_arn" {
  value = "${aws_iam_role.eks_iam_role.arn}"
}

output "eks_admin_iam_role_arn" {
  value = "${aws_iam_role.eks_admin_iam_role.arn}"
}

output "eks_admin_iam_group_arn" {
  value = "${aws_iam_group.eks_admin_iam_group.arn}"
}

