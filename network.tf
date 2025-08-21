#----------------------------------------------------------
# VPC
#----------------------------------------------------------
resource "aws_vpc" "vpc" {
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
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.vpc.id
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

resource "aws_subnet" "public_subnet_1c" {
  vpc_id                  = aws_vpc.vpc.id
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

resource "aws_subnet" "private_subnet_1a" {
  vpc_id                  = aws_vpc.vpc.id
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
resource "aws_subnet" "private_subnet_1c" {
  vpc_id                  = aws_vpc.vpc.id
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
resource "aws_route_table" "public_route_table_1a" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-route-table"
    project     = var.project_name
    environment = var.environment
    type        = "public"
  }
}

resource "aws_route_table_association" "public_route_table_1a" {
  route_table_id = aws_route_table.public_route_table_1a.id
  subnet_id      = aws_subnet.public_subnet_1a.id
}

resource "aws_route_table" "public_route_table_1c" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-route-table"
    project     = var.project_name
    environment = var.environment
    type        = "public"
  }
}

resource "aws_route_table_association" "public_route_table_1c" {
  route_table_id = aws_route_table.public_route_table_1c.id
  subnet_id      = aws_subnet.public_subnet_1c.id
}

resource "aws_route_table" "private_route_table_1a" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-route-table-1a"
    project     = var.project_name
    environment = var.environment
    type        = "private"
  }
}

resource "aws_route_table_association" "private_route_table_1a" {
  route_table_id = aws_route_table.private_route_table_1a.id
  subnet_id      = aws_subnet.private_subnet_1a.id
}

resource "aws_route_table" "private_route_table_1c" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-route-table-1c"
    project     = var.project_name
    environment = var.environment
    type        = "private"
  }
}

resource "aws_route_table_association" "private_route_table_1c" {
  route_table_id = aws_route_table.private_route_table_1c.id
  subnet_id      = aws_subnet.private_subnet_1c.id
}

#----------------------------------------------------------
# Internet Gateway
#----------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_route" "public_rt_igw_1a" {
  route_table_id         = aws_route_table.public_route_table_1a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "public_rt_igw_1c" {
  route_table_id         = aws_route_table.public_route_table_1c.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

#----------------------------------------------------------
# NAT Gateway
#----------------------------------------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1a.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gateway"
    project     = var.project_name
    environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

#----------------------------------------------------------
# Private Route Table Routes (NAT Gateway)
#----------------------------------------------------------
resource "aws_route" "private_rt_nat_1a" {
  route_table_id         = aws_route_table.private_route_table_1a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route" "private_rt_nat_1c" {
  route_table_id         = aws_route_table.private_route_table_1c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}