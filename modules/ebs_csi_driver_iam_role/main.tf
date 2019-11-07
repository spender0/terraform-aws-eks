data "aws_iam_policy_document" "can_be_assumed_by" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = var.ebs_csi_driver_can_be_assumed_by_iam_role_arns
      type = "AWS"
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.ebs_csi_driver_iam_role_name}"
  assume_role_policy = "${data.aws_iam_policy_document.can_be_assumed_by.json}"
}

resource "aws_iam_policy" "assume" {
  name        = "${var.ebs_csi_driver_iam_policy_name}-assume"
  path        = "/"
  description = "For assuming ${var.ebs_csi_driver_iam_role_name} role"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Resource": ["${aws_iam_role.ebs_csi_driver.arn}"]
      }
    ]
}
EOF
}

resource "aws_iam_policy" "ebs_csi_driver" {
  name        = "${var.ebs_csi_driver_iam_policy_name}"
  path        = "/"
  description = "For ebs_csi_driver"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DetachVolume"
        ],
        "Resource": "*"
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "${aws_iam_policy.ebs_csi_driver.arn}"
  role       = "${aws_iam_role.ebs_csi_driver.name}"
}
