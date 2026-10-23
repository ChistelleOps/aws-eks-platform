output "platform_admin_role_arn" {
  description = "ARN of the platform administrator IAM role"
  value       = aws_iam_role.platform_admin.arn
}