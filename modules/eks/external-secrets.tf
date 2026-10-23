
# IAM policy for External Secrets Operator
data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadPostgresSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:platform/dev/postgres-*"
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "platform-external-secrets-read"
  description = "Allow External Secrets Operator to read the PostgreSQL secret"

  policy = data.aws_iam_policy_document.external_secrets.json
}


# IAM role assumed through EKS Pod Identity
data "aws_iam_policy_document" "external_secrets_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "platform-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_trust.json
}

# Attach our Secrets Manager read policy to the role
resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}


# Connect External Secrets Operator to its IAM role
resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name = module.eks.cluster_name

  namespace       = "external-secrets"
  service_account = "external-secrets"

  role_arn = aws_iam_role.external_secrets.arn

  depends_on = [
    aws_iam_role_policy_attachment.external_secrets
  ]
}
