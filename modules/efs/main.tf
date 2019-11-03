resource "aws_efs_file_system" "efs" {
  tags  = {
    Name = "${var.efs_name}"
  }
}
resource "aws_efs_mount_target" "efs_provisioner" {
  count = "${length(var.efs_node_subnet_ids)}"
  file_system_id = "${aws_efs_file_system.efs.id}"
  subnet_id = "${var.efs_node_subnet_ids[count.index]}"
  # This example uses the nodes security group
  # but you should create a dedicated one for better security.
  security_groups = ["${var.efs_node_security_group_id}"]
}