locals {
  name = "Set-21"
}

// Creating VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "${local.name}-vpc"
  }
}

//Creating my public subnet 
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "${local.name}-subnet1"
  }
}

//Creating my private subnet 
resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "${local.name}-subnet2"
  }
}

//Craeting Internet Gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.name}-igw"
  }
}
//Creating Nat Gateway 
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "${local.name}-gw-NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

//creating eip 
resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "${local.name}-eip"
  }

}

//Creating public route tables 
resource "aws_route_table" "pub-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-Pub-rt"
  }
}

//Public Subnet Aoociation
resource "aws_route_table_association" "Pub-rt" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.pub-rt.id
}

//Creating private route tables 
resource "aws_route_table" "pri-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw.id
  }
  tags = {
    Name = "${local.name}-Pri-rt"
  }
}

//Private Subnet Association
resource "aws_route_table_association" "Pri-rt" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.pri-rt.id
}

//Creating Security Group for ansible
resource "aws_security_group" "ansible-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "This my ansible security group"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-ansible-sg"
  }
}

//Creating Security Group for manage nodes 
resource "aws_security_group" "manage-nodes-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "This my manage node security group"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-manage-nodes-sg"
  }
}

//Craeting keypair RSA key of size 4096 bits
resource "tls_private_key" "key" {
    algorithm = "RSA"
    rsa_bits = 4096  
}

//creating private key 
resource "local_file" "key" {
    content = tls_private_key.key.private_key_pem
    filename = "acp-key"
    file_permission = "600"
}

//creating public key
resource "aws_key_pair" "key" {
    key_name = "acp-pub-key"
    public_key = tls_private_key.key.public_key_openssh  
}

//Creating my ansiblle  instance 
resource "aws_instance" "ansible" {
  ami                         = "ami-0d53d72369335a9d6" //ubuntu 
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.ansible-sg.id]
  key_name                    = aws_key_pair.key.id
  associate_public_ip_address = true
  user_data                   = file("./user-data.sh")

  tags = {
    Name = "${local.name}-ansible-node"
  }
}

//Creating managed node 1 instance 
resource "aws_instance" "redhat" {
  ami                         = "ami-0c5ebd68eb61ff68d" //redhat 
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  key_name                    = aws_key_pair.key.id
  vpc_security_group_ids      = [aws_security_group.manage-nodes-sg.id]
  associate_public_ip_address = true


  tags = {
    Name = "${local.name}-redhat-node"
  }
}

//Creating manage node 2 instance 
resource "aws_instance" "ubuntu" {
  ami                         = "ami-0d53d72369335a9d6" //ubuntu 
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  key_name                    = aws_key_pair.key.id
  vpc_security_group_ids      = [aws_security_group.manage-nodes-sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "${local.name}-ubuntu-node"
  }
}