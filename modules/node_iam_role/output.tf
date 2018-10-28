output "node_iam_role_arn" {
  value = "${aws_iam_role.node_iam_role.arn}"
}

output "node_iam_role_name" {
  value = "${aws_iam_role.node_iam_role.name}"
}

output "node_iam_role_id" {
  value = "${aws_iam_role.node_iam_role.id}"
}
