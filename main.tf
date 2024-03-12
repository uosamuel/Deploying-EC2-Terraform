#create a VPC 
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo VPC"
  }

}

#create a subnet within the VPC
resource "aws_subnet" "demo_subnet" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Demo subnet"
  }

  depends_on = [aws_vpc.demo_vpc]
}

#creates an internet gateway for the VPC
resource "aws_internet_gateway" "demo_gateway" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "gateway for demo VPC"
  }

  depends_on = [aws_vpc.demo_vpc]
}

resource "aws_egress_only_internet_gateway" "demo_ipv6_gateway" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "1pv6_gateway"
  }
}

# Creates a route table for the subnet to route to the internet
resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.demo_ipv6_gateway.id
  }

  tags = {
    Name = "demo_rt"
  }

}

# Associate the created route table with the subnet making it a public subnet
resource "aws_route_table_association" "demo_public_rt_association" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_rt.id
}


# Creates a security group
resource "aws_security_group" "demo_SG" {
  name        = "demo SG"
  description = "Demo SG to allow SSH"
  vpc_id      = aws_vpc.demo_vpc.id

  tags = {
    Name = "SG_SSH"
  }
}

# Create an ingress security group rule
resource "aws_vpc_security_group_ingress_rule" "demo_allow_tls_ipv4" {
  security_group_id = aws_security_group.demo_SG.id
  cidr_ipv4         = aws_vpc.demo_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Creates an RSA encryption for keypair
resource "tls_private_key" "demo_rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Creates a keypair using the above created encryption
resource "aws_key_pair" "demo_key" {
  key_name   = var.keypair
  public_key = tls_private_key.demo_rsa.public_key_openssh
}

# Stores the private key in local system
resource "local_file" "private_key" {
  content  = tls_private_key.demo_rsa.private_key_pem
  filename = var.keypairfilepath
}

#Creates an EC2 instance and apply security group and keypair to it
resource "aws_instance" "demo_instance" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.demo_subnet.id
  key_name      = aws_key_pair.demo_key.key_name
  vpc_security_group_ids = [
    aws_security_group.demo_SG.id
  ]
}