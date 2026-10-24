
# Register GitHub Actions as an OIDC identity provider in AWS.
# An AWS account only needs one GitHub OIDC provider.

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}
