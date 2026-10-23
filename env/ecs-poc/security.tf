resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-poc-ecs-tasks"
  description = "Security group for ECS Fargate POC tasks"
  vpc_id      = aws_vpc.poc.id

  tags = {
    Name        = "${var.project_name}-poc-ecs-tasks"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "api" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow FastAPI access from approved IP"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 8000
  to_port           = 8000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "portfolio" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow portfolio access from approved IP"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow outbound traffic for POC tasks"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
