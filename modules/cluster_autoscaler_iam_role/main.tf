data "aws_iam_policy_document" "can_be_assumed_by" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = var.cluster_autoscaler_can_be_assumed_by_iam_role_arns
      type = "AWS"
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "cluster-autoscaler" {
  name = "${var.cluster_autoscaler_iam_role_name}"
  assume_role_policy = "${data.aws_iam_policy_document.can_be_assumed_by.json}"
}

resource "aws_iam_policy" "assume" {
  name        = "${var.cluster_autoscaler_iam_policy_name}-assume"
  path        = "/"
  description = "For assuming ${var.cluster_autoscaler_iam_role_name} role"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Resource": ["${aws_iam_role.cluster-autoscaler.arn}"]
      }
    ]
}
EOF
}

resource "aws_iam_policy" "cluster-autoscaler" {
  name        = "${var.cluster_autoscaler_iam_policy_name}"
  path        = "/"
  description = "For kubernetes cluster autoscaller"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster-autoscaler" {
  policy_arn = "${aws_iam_policy.cluster-autoscaler.arn}"
  role       = "${aws_iam_role.cluster-autoscaler.name}"
}
