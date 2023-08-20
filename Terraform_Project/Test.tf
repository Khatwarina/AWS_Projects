terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2c"
}

resource "aws_vpc" "myvpc" {   #myvpc is for internal understanding
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ohio-vpc" #ohiovps is for GUI page
  }
}

#public subnet
resource "aws_subnet" "pubsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.10.0/24"

  tags = {
    Name = "pubsub-ohio"
  }
}

#private subnet
resource "aws_subnet" "pvtsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.20.0/24"

  tags = {
    Name = "pvtsub-ohio"
  }
}

#IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "igw-ohio"
  }
}

#public route table and association 
resource "aws_route_table" "pub-rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "pubrt-ohio"
  }
}

resource "aws_route_table_association" "publicassociation" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.pub-rt.id
}

#elastic ip
resource "aws_eip" "myeip" {
  instance = aws_instance.web.id
  domain   = "vpc"
}

#NAT gateway
resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "mynat-ohio"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.example]
}

#private route table and association with NAT GW
resource "aws_route_table" "pvt-rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.mynat.id
  }

  tags = {
    Name = "pvtrt-ohio"
  }
}

resource "aws_route_table_association" "pvtassociation" {
  subnet_id      = aws_subnet.pvtsub.id
  route_table_id = aws_route_table.pvt-rt.id
}


#pub security group 
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress { # ingress means inbound
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  egress { #egress means outbound can't do any changes keep as it is
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_tls"
  }
}

# tyring to launch an ec2 instance

resource "aws_instance" "pubec2" {
  ami                         	=  "ami-024e6efaf93d85776"
  instance_type               	=  "t2.micro"  
  subnet_id                  		=  aws_subnet.pubsub.id
  key_name                    	=  "ubuntukeypair"
  vpc_security_group_ids      	=  [aws_security_group.allow_all.id]
  associate_public_ip_address 	=  true
}

resource "aws_instance" "pvtec2" {
  ami                         	=  "ami-024e6efaf93d85776"
  instance_type               	=  "t2.micro"  
  subnet_id                   	=  aws_subnet.pvtsub.id
  key_name                    	=  "ubuntukeypair"
  vpc_security_group_ids      	=  [aws_security_group.allow_all.id]
  
}