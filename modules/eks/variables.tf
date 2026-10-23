
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC where EKS will run"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for EKS worker nodes"
  type        = list(string)
}
variable "platform_admin_role_arn" {
  description = "ARN of the IAM role authorized to administer EKS"
  type        = string
}
variable "env" {
  description = "Deployment env"
  type        = string
}
variable "endpoint_public_access_cidrs" {
  description = "IPv4 CIDR ranges allowed to access the public EKS API endpoint"
  type        = list(string)
}
variable "tags" {
  description = "Common tags applied to AWS resources"
  type        = map(string)
}