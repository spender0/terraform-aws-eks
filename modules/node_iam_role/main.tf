resource "aws_iam_role" "node_iam_role" {
  name = "${var.node_iam_role_name}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.node_iam_role.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.node_iam_role.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.node_iam_role.name}"
}


resource "aws_iam_policy" "cluster-autoscaler" {
  name        = "${var.node_iam_role_name}-ca-assume"
  path        = "/"
  description = "For assuming kubernetes cluster autoscaller role"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Resource": ["arn:aws:iam::${var.node_iam_role_aws_account_id}:role/${var.node_iam_role_cluster_autoscaler_role_name}"]
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster-autoscaler" {
  policy_arn = "${aws_iam_policy.cluster-autoscaler.arn}"
  role       = "${aws_iam_role.node_iam_role.name}"
}

