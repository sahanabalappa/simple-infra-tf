provider "aws" {
  region = "us-east-1" # Specify your AWS region
}

# Create VPC
resource "aws_vpc" "sahana-vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "vpc-sahana"
  }
}

# Create Public Subnet
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.sahana-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create Private Subnet
resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.sahana-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private-subnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "aws-igw" {
  vpc_id = aws_vpc.sahana-vpc.id

  tags = {
    Name = "vpc-igw"
  }
}

# Create NAT Gateway elastic ip 
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "aws-ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-subnet.id

  tags = {
    Name = "nat-gw"
  }
}

# Create Route Table for Public Subnet
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.sahana-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws-igw.id
  }
}

resource "aws_route_table_association" "public-rta" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

# Create Route Table for Private Subnet
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.sahana-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.aws-ngw.id
  }
}

resource "aws_route_table_association" "private-rta" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-rt.id
}

# Create Security Group for EC2 Instances
resource "aws_security_group" "aws-sg" {
  vpc_id = aws_vpc.sahana-vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  user_data = templatefile("${path.root}/files/docker.tpl", {} )

}

# Create EC2 Instance in Public Subnet
resource "aws_instance" "publicinstance" {
  ami                         = "ami-04a81a99f5ec58529" # Replace with a valid AMI ID for your region
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.aws-sg.id]
  key_name                    = "ec2-key2"
  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = {
    Name = "PublicInstance"
  }
}

# Create EC2 Instance in Private Subnet
resource "aws_instance" "privateinstance" {
  count                       = 2
  ami                         = "ami-04a81a99f5ec58529" # Replace with a valid AMI ID for your region
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private-subnet.id
  vpc_security_group_ids      = [aws_security_group.aws-sg.id]
  key_name                    = "ec2-key2"
  user_data                   = local.user_data
  user_data_replace_on_change = true
  tags = {
    Name = "PrivateInstance"
  }
}



