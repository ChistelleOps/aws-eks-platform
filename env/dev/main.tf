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
  platform_admin_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-platform-admin"
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