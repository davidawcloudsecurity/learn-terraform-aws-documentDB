provider "aws" {  region = "us-west-2"  # Change to your desired region}
# VPCresource "aws_vpc" "main" {  cidr_block = "10.0.0.0/16"
  tags = {    Name = "main-vpc"  }}
# Internet Gatewayresource "aws_internet_gateway" "igw" {  vpc_id = aws_vpc.main.id
  tags = {    Name = "main-igw"  }}
# Public Subnetresource "aws_subnet" "public" {  vpc_id            = aws_vpc.main.id  cidr_block        = "10.0.1.0/24"  map_public_ip_on_launch = true
  tags = {    Name = "public-subnet"  }}
# Route Table for Public Subnetresource "aws_route_table" "public" {  vpc_id = aws_vpc.main.id
  route {    cidr_block = "0.0.0.0/0"    gateway_id = aws_internet_gateway.igw.id  }
  tags = {    Name = "public-route-table"  }}
# Route Table Association for Public Subnetresource "aws_route_table_association" "public" {  subnet_id      = aws_subnet.public.id  route_table_id = aws_route_table.public.id}
# NAT Gatewayresource "aws_eip" "nat" {  vpc = true}
resource "aws_nat_gateway" "nat" {  allocation_id = aws_eip.nat.id  subnet_id     = aws_subnet.public.id
  tags = {    Name = "main-nat-gateway"  }}
# Private Subnetsresource "aws_subnet" "private_a" {  vpc_id     = aws_vpc.main.id  cidr_block = "10.0.2.0/24"
  tags = {    Name = "private-subnet-a"  }}
resource "aws_subnet" "private_b" {  vpc_id     = aws_vpc.main.id  cidr_block = "10.0.3.0/24"
  tags = {    Name = "private-subnet-b"  }}
# Route Table for Private Subnetsresource "aws_route_table" "private" {  vpc_id = aws_vpc.main.id
  route {    cidr_block     = "0.0.0.0/0"    nat_gateway_id = aws_nat_gateway.nat.id  }
  tags = {    Name = "private-route-table"  }}
# Route Table Associations for Private Subnetsresource "aws_route_table_association" "private_a" {  subnet_id      = aws_subnet.private_a.id  route_table_id = aws_route_table.private.id}
resource "aws_route_table_association" "private_b" {  subnet_id      = aws_subnet.private_b.id  route_table_id = aws_route_table.private.id}
# Security Group for EC2 and DocumentDBresource "aws_security_group" "allow_all" {  vpc_id = aws_vpc.main.id
  ingress {    from_port   = 0    to_port     = 65535    protocol    = "tcp"    cidr_blocks = ["10.0.0.0/16"]  }
  egress {    from_port   = 0    to_port     = 0    protocol    = "-1"    cidr_blocks = ["0.0.0.0/0"]  }
  tags = {    Name = "allow_all_sg"  }}
# EC2 Instanceresource "aws_instance" "ec2" {  ami           = "ami-0c55b159cbfafe1f0"  # Change to your desired AMI  instance_type = "t2.micro"  subnet_id     = aws_subnet.private_a.id  security_groups = [aws_security_group.allow_all.name]
  tags = {    Name = "private-ec2-instance"  }}
# DocumentDB Clusterresource "aws_docdb_cluster" "docdb_cluster" {  cluster_identifier      = "docdb-cluster"  master_username         = "docdbadmin"  master_password         = "SecurePass123!"  # Change to a secure password  backup_retention_period = 5  preferred_backup_window = "07:00-09:00"
  vpc_security_group_ids = [aws_security_group.allow_all.id]}
# DocumentDB Instancesresource "aws_docdb_cluster_instance" "docdb_instance" {  count                = 2  identifier           = "docdb-instance-${count.index}"  cluster_identifier   = aws_docdb_cluster.docdb_cluster.id  instance_class       = "db.r5.large"  subnet_id            = element([aws_subnet.private_a.id, aws_subnet.private_b.id], count.index)
  tags = {    Name = "docdb-instance-${count.index}"  }}
# Subnet Group for DocumentDBresource "aws_docdb_subnet_group" "docdb_subnet_group" {  name       = "docdb-subnet-group"  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags = {    Name = "docdb-subnet-group"  }}

