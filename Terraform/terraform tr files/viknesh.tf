#creating terraform block and provider block

terraform {
  required_providers {
    aws ={
        source = "hashicorp/aws"
        version = "5.54.1"
    }
  }
}
provider "aws" {
    region="us-east-1"  
}

#step 1: create vpc
resource "aws_vpc" "myVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "myVPC"
  }
}

#step 2: create public and private subnet
#public subnet
resource "aws_subnet" "myPublicSubnet" {
  vpc_id     = aws_vpc.myVPC.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "myPublicSubnet"
  }
}
#private subnet
resource "aws_subnet" "myPrivateSubnet" {
  vpc_id     = aws_vpc.myVPC.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "myPrivateSubnet"
  }
}

#step 3: create internet gateway
resource "aws_internet_gateway" "myInternetGateway" {
    vpc_id = aws_vpc.myVPC.id

  tags = {
    Name = "myInternetGateway"
  }
  
}

#step 4: create public and private Route Table
#Public Route Table
resource "aws_route_table" "myPublicRouteTable" {
  vpc_id = aws_vpc.myVPC.id
    
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myInternetGateway.id
  }
    
  tags ={
    Name = "myPublicRouteTable"
  }
}
#Private Route Table
resource "aws_route_table" "myPrivateRouteTable" {
  vpc_id = aws_vpc.myVPC.id
  /*
  route {
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_internet_gateway.myInternetGateway.id
  }
  */
  tags ={
    Name = "myPrivateRouteTable"
  }
}

#step 5: create subnet Associations
#public subnet with public route table
resource "aws_route_table_association" "pubsubpubrt" {
  subnet_id      = aws_subnet.myPublicSubnet.id
  route_table_id = aws_route_table.myPublicRouteTable.id
}
#private subnet with private route table
resource "aws_route_table_association" "pvtsubpvtrt" {
  subnet_id      = aws_subnet.myPrivateSubnet.id
  route_table_id = aws_route_table.myPrivateRouteTable.id
}

#step 6: create security group
#public security group
resource "aws_security_group" "myPublicSecurityGroup" {
  
  name        = "myPublicSecurityGroup"
  description = "Allow SSH and http inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myVPC.id

  tags = {
    Name = "myPublicSecurityGroup"
  }
}
#http inbound rules for public security group
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.myPublicSecurityGroup.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}
#ssh inbound rules for public security group
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.myPublicSecurityGroup.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}
#Allow all outbound traffic for public security group
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_public" {
  security_group_id = aws_security_group.myPublicSecurityGroup.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "-1"
  to_port     = 0
}

#private security group
resource "aws_security_group" "myPrivateSecurityGroup" {
  
  name        = "myPrivateSecurityGroup"
  description = "Allow public security group inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myVPC.id

  
  tags = {
    Name = "myPrivateSecurityGroup"
  }
}
#public security inbound rules for public security group
resource "aws_security_group_rule" "allow_public_security_group" {
  type                   = "ingress"
  from_port              = 0
  to_port                = 65535
  protocol               = "tcp"
  source_security_group_id = aws_security_group.myPublicSecurityGroup.id
  security_group_id      = aws_security_group.myPrivateSecurityGroup.id
}

/*
#ssh inbound rules for public security group
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.myPrivateSecurityGroup.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "ssh"
  to_port     = 22
}
*/
#Allow all outbound traffic for private security group
resource "aws_security_group_rule" "allow_all_outbound_private" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.myPrivateSecurityGroup.id
}

#step 7: create public and private server
#public server
resource "aws_instance" "public_server" {
  ami           = "ami-08a0d1e16fc3f61ea"
  instance_type = "t2.micro"
  key_name = "keyjoe"
  vpc_security_group_ids = [aws_security_group.myPublicSecurityGroup.id]
  subnet_id = aws_subnet.myPublicSubnet.id
  associate_public_ip_address = true
  
  tags = {
    Name = "public_server"
  }
}
#private server
resource "aws_instance" "private_server" {
  ami           = "ami-08a0d1e16fc3f61ea"
  instance_type = "t2.micro"
  key_name = "keyjoe"
  vpc_security_group_ids = [aws_security_group.myPrivateSecurityGroup.id]
  subnet_id = aws_subnet.myPrivateSubnet.id
  associate_public_ip_address = false
  
  tags = {
    Name = "private_server"
  }
}

#step 8: create NAT gateway and EIP
#EIP
resource "aws_eip" "myEIP" {
  domain = "vpc"

  tags ={
    Name = "myEIP"
  }
}
#NAT gateway
resource "aws_nat_gateway" "myNATgateway" {
  allocation_id = aws_eip.myEIP.id
  subnet_id = aws_subnet.myPublicSubnet.id

  tags = {
    Name = "myNATgateway"
  }
}

#step 9: Update the private Route Table
resource "aws_route" "private_route" {
  route_table_id = aws_route_table.myPrivateRouteTable.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.myNATgateway.id
}

