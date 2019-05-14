resource "aws_iam_instance_profile" "iam_instance_profile" {
  count = "${var.node_create}"
  name = "${var.node_iam_instance_profile_name}"
  role = "${var.node_iam_role_name}"
}

#get latest eks node ami
data "aws_ami" "ami" {
  count = "${var.node_create}"
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.node_k8s_version}-v*"]
  }
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

//https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh
locals {
  eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh \
--apiserver-endpoint '${var.node_eks_endpoint}' \
--kubelet-extra-args '${var.node_kubelet_extra_args}' \
--b64-cluster-ca '${var.node_eks_ca}' '${var.node_eks_cluster_name}'
USERDATA
}

resource "aws_launch_configuration" "node_launch_configuration" {
  count = "${var.node_create}"
  spot_price = "${var.node_launch_configuration_type!="spot"?"":var.node_launch_configuration_spot_price}"
  key_name                    = "${var.node_key_pair_name}"
  //having public ips is cheaper than nat gateway
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.iam_instance_profile.name}"
  image_id                    = "${data.aws_ami.ami.id}"
  instance_type               = "${var.node_launch_configuration_instance_type}"
  root_block_device {
    volume_type                 = "${var.node_launch_configuration_volume_type}"
    volume_size                 = "${var.node_launch_configuration_volume_size}"
  }
  name_prefix                 = "${var.node_launch_configuration_name_prefix}"
  security_groups             = ["${var.node_security_group_id}"]
  user_data_base64            = "${base64encode(local.eks-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "node_autoscaling_group" {
  count = "${var.node_create}"
  desired_capacity     = "${var.node_autoscaling_group_desired_capacity}"
  launch_configuration = "${aws_launch_configuration.node_launch_configuration.id}"
  max_size             = "${var.node_autoscaling_group_max_number}"
  min_size             = "${var.node_autoscaling_group_min_number}"
  name                 = "${var.node_autoscaling_group_name}"
  vpc_zone_identifier  = ["${var.node_vpc_zone_identifier}"]
  tag {
    key                 = "Name"
    value               = "${var.node_autoscaling_group_name}"
    propagate_at_launch = true
  }
  tag {
    key                 = "kubernetes.io/cluster/${var.node_eks_cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
  //enable cluster-autoscaler
//  tag {
//    key                 = "kubernetes.io/cluster-autoscaler/${var.node_eks_cluster_name}"
//    value               = "true"
//    propagate_at_launch = true
//  }
  tag {
    key = "k8s.io/cluster-autoscaler/enabled"
    value = "true"
    propagate_at_launch = true
  }
}



