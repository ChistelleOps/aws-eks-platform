
variable "name" {
  description = "Name of the VPC"
  type        = string
}
variable "env" {
  description = "Deployment env"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the VPC"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnets are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnets are required."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways"
  type        = bool
}

variable "single_nat_gateway" {
  description = "Whether to use one shared NAT gateway"
  type        = bool
}
variable "tags" {
  description = "Common tags applied to AWS resources"
  type        = map(string)
}