
resource "aws_ecs_cluster" "poc" {
  name = "${var.project_name}-${var.environment}-ecs"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
