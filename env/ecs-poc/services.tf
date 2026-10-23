
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-poc-api"
  cluster         = aws_ecs_cluster.poc.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]

    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ecs_service" "portfolio" {
  name            = "${var.project_name}-poc-portfolio"
  cluster         = aws_ecs_cluster.poc.id
  task_definition = aws_ecs_task_definition.portfolio.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]

    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
