
# ECR repository for the FastAPI application
resource "aws_ecr_repository" "platform_api" {
  name                 = "aws-eks-platform/platform-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# ECR repository for the portfolio application
resource "aws_ecr_repository" "portfolio" {
  name                 = "aws-eks-platform/portfolio"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
