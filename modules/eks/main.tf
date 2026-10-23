module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.33"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  endpoint_public_access  = true
  endpoint_private_access = true

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

    # Use managed node groups instead of EKS Auto Mode
  compute_config = {
    enabled = false
  }
  # Use EKS Access Entries for cluster access
   authentication_mode = "API"
  # Manage administrator access explicitly
   enable_cluster_creator_admin_permissions = false


  # EKS Managed Node Groups
  eks_managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 4
      desired_size = 2

      disk_size = 30

      labels = {
        role = "general"
      }

      tags = merge(var.tags, {
      Name = "platform-${var.env}-general-nodes"
    })
    }
  }


  # Explicit Kubernetes administrator access
  access_entries = {
    platform_admin = {
      principal_arn = var.platform_admin_role_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
  tags = var.tags
}
