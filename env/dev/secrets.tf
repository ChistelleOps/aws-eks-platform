
# PostgreSQL credentials stored in AWS Secrets Manager

resource "aws_secretsmanager_secret" "postgres" {
  name        = "platform/dev/postgres"
  description = "PostgreSQL credentials for the development EKS platform"

  recovery_window_in_days = 7

  tags = {
    Environment = "dev"
    Application = "postgres"
    ManagedBy   = "terraform"
  }
}
