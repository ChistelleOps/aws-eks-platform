
# IAM role that GitHub Actions can assume using OIDC
resource "aws_iam_role" "github_actions" {
  name = "aws-eks-platform-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:ChistelleOps/aws-eks-platform:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}


# Allow GitHub Actions to authenticate to Amazon ECR
resource "aws_iam_role_policy" "github_ecr_push" {
  name = "github-actions-ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "GetECRLoginToken"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Sid    = "PushImagesToECR"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]

        Resource = [
          aws_ecr_repository.platform_api.arn,
          aws_ecr_repository.portfolio.arn
        ]
      }
    ]
  })
}
