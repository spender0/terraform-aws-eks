output "eks_iam_role_arn" {
  value = "${aws_iam_role.eks_iam_role.arn}"
}