
provider "aws" {
  region = "us-east-1"
}

data "aws_iam_policy_document" "platform_admin_trust" {
  statement {
    sid     = "AllowTrustedPrincipal"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }
  }
}

resource "aws_iam_role" "platform_admin" {
  name               = "eks-platform-admin"
  assume_role_policy = data.aws_iam_policy_document.platform_admin_trust.json

  tags = {
    Project   = "eks-platform"
    ManagedBy = "terraform"
  }
}
