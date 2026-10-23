terraform {
  backend "s3" {
    bucket       = "eks-platform-tfstate-cnt"
    key          = "dev/eks-platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
