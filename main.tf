provider "aws" {
  region = "eu-central-1"
}


resource "aws_vpc" "dev_vpc" {
  cidr_block = "11.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "DEV"
  }
}

resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "PROD"
  }
}


resource "aws_subnet" "private_subnet_dev" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "11.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone = "eu-central-1a"
  tags = {
    Name = "private-dev"
  }
}

resource "aws_subnet" "private_subnet_prod" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone = "eu-central-1a"
  tags = {
    Name = "private-prod"
  }
}


resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id
}

resource "aws_internet_gateway" "prod_igw" {
  vpc_id = aws_vpc.prod_vpc.id
}


resource "aws_eip" "dev_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "dev_nat" {
  allocation_id = aws_eip.dev_nat_eip.id
  subnet_id     = aws_subnet.private_subnet_dev.id
}

resource "aws_eip" "prod_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "prod_nat" {
  allocation_id = aws_eip.prod_nat_eip.id
  subnet_id     = aws_subnet.private_subnet_prod.id
}

resource "aws_route_table" "dev_private_route_table" {
  vpc_id = aws_vpc.dev_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev_nat.id
  }
}

resource "aws_route_table_association" "dev_private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet_dev.id
  route_table_id = aws_route_table.dev_private_route_table.id
}

resource "aws_route_table" "prod_private_route_table" {
  vpc_id = aws_vpc.prod_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prod_nat.id
  }
}

resource "aws_route_table_association" "prod_private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet_prod.id
  route_table_id = aws_route_table.prod_private_route_table.id
}

resource "aws_instance" "vpn_server" {
  ami           = "ami-023adaba598e661ac"
  instance_type = "t3.nano"
  key_name      = "github"
  subnet_id     = aws_subnet.private_subnet_dev.id
  associate_public_ip_address = true
  user_data     = file("install.sh")
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]

  tags = {
    Name = "OpenVPN Server"
  }
}

resource "aws_security_group" "vpn_sg" {
  name   = "vpn-security-group"
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
