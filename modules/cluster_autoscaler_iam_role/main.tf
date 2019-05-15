resource "aws_iam_role" "cluster-autoscaler" {
  name = "${var.cluster_autoscaler_iam_role_name}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${var.cluster_autoscaler_assuming_iam_role_arn}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
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
