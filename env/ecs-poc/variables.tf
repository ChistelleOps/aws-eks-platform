
variable "aws_region" {
  description = "AWS region for the ECS POC"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}

variable "project_name" {
  description = "Name used to identify project resources"
  type        = string
  default     = "aws-eks-platform"
}

variable "allowed_cidr" {
  description = "Public IPv4 address allowed to access the ECS POC, in /32 CIDR format"
  type        = string
}

