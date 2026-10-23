
resource "aws_vpc" "poc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-poc-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "poc" {
  vpc_id = aws_vpc.poc.id

  tags = {
    Name = "${var.project_name}-poc-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.poc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-poc-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.poc.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-poc-public-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.poc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.poc.id
  }

  tags = {
    Name = "${var.project_name}-poc-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
