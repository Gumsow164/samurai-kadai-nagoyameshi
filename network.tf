#----------------------------------------------------------
# VPC
#----------------------------------------------------------
resource "aws_vpc" "vpc_prod" {
  cidr_block                       = "192.168.0.0/20"
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# Subnet
#----------------------------------------------------------
resource "aws_subnet" "public_subnet_prod_1a" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet"
    project     = var.project_name
    environment = var.environment
    type        = "public"
  }
}

resource "aws_subnet" "public_subnet_prod_1c" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet"
    project     = var.project_name
    environment = var.environment
    type        = "public"
  }
}

resource "aws_subnet" "private_subnet_prod_1a" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "192.168.4.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-1a"
    project     = var.project_name
    environment = var.environment
    type        = "private"
  }
}
resource "aws_subnet" "private_subnet_prod_1c" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-1c"
    project     = var.project_name
    environment = var.environment
    type        = "private"
  }
}
#----------------------------------------------------------
# Route Table
#----------------------------------------------------------
resource "aws_route_table" "public_route_table_prod_1a" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-route-table"
    project     = var.project_name
    environment = var.environment
    type        = "public"
  }
}

resource "aws_route_table_association" "public_route_table_prod_1a" {
  route_table_id = aws_route_table.public_route_table_prod_1a.id
  subnet_id      = aws_subnet.public_subnet_prod_1a.id
}

resource "aws_route_table" "public_route_table_prod_1c" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-route-table"
    project     = var.project_name
    environment = var.environment
    type        = "public"
  }
}

resource "aws_route_table_association" "public_route_table_prod_1c" {
  route_table_id = aws_route_table.public_route_table_prod_1c.id
  subnet_id      = aws_subnet.public_subnet_prod_1c.id
}

resource "aws_route_table" "private_route_table_prod_1a" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-route-table-1a"
    project     = var.project_name
    environment = var.environment
    type        = "private"
  }
}

resource "aws_route_table_association" "private_route_table_prod_1a" {
  route_table_id = aws_route_table.private_route_table_prod_1a.id
  subnet_id      = aws_subnet.private_subnet_prod_1a.id
}

resource "aws_route_table" "private_route_table_prod_1c" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-route-table-1c"
    project     = var.project_name
    environment = var.environment
    type        = "private"
  }
}

resource "aws_route_table_association" "private_route_table_prod_1c" {
  route_table_id = aws_route_table.private_route_table_prod_1c.id
  subnet_id      = aws_subnet.private_subnet_prod_1c.id
}

#----------------------------------------------------------
# Internet Gateway
#----------------------------------------------------------
resource "aws_internet_gateway" "igw_prod" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_route" "public_rt_igw_prod_1a" {
  route_table_id         = aws_route_table.public_route_table_prod_1a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_prod.id
}