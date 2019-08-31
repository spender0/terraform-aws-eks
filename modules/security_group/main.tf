resource "aws_security_group" "security_group_eks" {
  name        = "${var.security_group_name_eks}"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.security_group_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security_group_name_eks}"
  }
}

resource "aws_security_group_rule" "security_group_eks_rule" {
  cidr_blocks       = var.security_group_eks_external_cidr_blocks
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.security_group_eks.id}"
  type              = "ingress"
}


resource "aws_security_group" "security_group_node" {
  name        = "${var.security_group_name_node}"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${var.security_group_vpc_id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = "${
    map(
     "Name", "${var.security_group_name_node}",
     "kubernetes.io/cluster/${var.security_group_eks_cluster_name}", "owned"
    )
  }"
}

resource "aws_security_group_rule" "eks-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.security_group_node.id}"
  source_security_group_id = "${aws_security_group.security_group_node.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.security_group_node.id}"
  source_security_group_id = "${aws_security_group.security_group_eks.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.security_group_eks.id}"
  source_security_group_id = "${aws_security_group.security_group_node.id}"
  type                     = "ingress"
}