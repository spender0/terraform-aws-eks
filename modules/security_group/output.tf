output "security_group_id_eks" {
  value = "${aws_security_group.security_group_eks.id}"
}

output "security_group_id_node" {
  value = "${aws_security_group.security_group_node.id}"
}