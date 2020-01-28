data "aws_caller_identity" "current" {}

resource "aws_iam_role" "eks_admin_iam_role" {
  name = "${var.eks_admin_iam_role_name}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_group" "eks_admin_iam_group" {
  name = var.eks_admin_iam_group_name
}

resource "aws_iam_policy" "eks_admin_iam_policy" {
  name        = "${var.eks_admin_iam_policy_name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": [
                "${aws_iam_role.eks_admin_iam_role.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_group_policy_attachment" "eks_admin_iam_policy" {
  policy_arn = aws_iam_policy.eks_admin_iam_policy.arn
  group       = aws_iam_group.eks_admin_iam_group.name
}
