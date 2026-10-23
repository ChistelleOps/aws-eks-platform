
output "ecs_cluster_name" {
  description = "Name of the ECS POC cluster"
  value       = aws_ecs_cluster.poc.name
}

output "platform_api_ecr_url" {
  description = "ECR repository URL for the FastAPI application"
  value       = aws_ecr_repository.platform_api.repository_url
}

output "portfolio_ecr_url" {
  description = "ECR repository URL for the portfolio"
  value       = aws_ecr_repository.portfolio.repository_url
}
