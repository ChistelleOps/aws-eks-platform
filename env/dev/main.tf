module "networking" {
  source = "../../modules/networking"

  name                 = "platform-${var.env}-vpc"
  env                  = var.env
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  tags = local.common_tags
}
module "eks" {
  source = "../../modules/eks"

  cluster_name                 = var.cluster_name
  env                          = var.env
  aws_region                   = var.aws_region
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  vpc_id                       = module.networking.vpc_id
  private_subnet_ids           = module.networking.private_subnet_ids
  platform_admin_role_arn      = aws_iam_role.eks_platform_admin.arn
  tags                         = local.common_tags
}

data "aws_caller_identity" "current" {}
locals {
  common_tags = {
    Project     = "eks-platform"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "eks_admin_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        data.aws_caller_identity.current.arn
      ]
    }
  }
}

resource "aws_iam_role" "eks_platform_admin" {
  name               = "eks-platform-admin"
  assume_role_policy = data.aws_iam_policy_document.eks_admin_trust.json

  tags = local.common_tags
}