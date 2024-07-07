provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                = aws_vpc.main.id
  cidr_block            = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Route Table Association for Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id     = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "main-nat-gateway"
  }
}

# Private Subnets
resource "aws_subnet" "private_a" {
  vpc_id    = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id    = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "private-subnet-b"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block    = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private_a" {
  subnet_id     = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id     = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security Group for EC2 and DocumentDB
resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all_sg"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami             = "ami-018ba43095ff50d08"  # Change to your desired AMI
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.allow_all.name]
  user_data = <<EOF
#!/bin/bash
# Define the path to the sshd_config file
sshd_config="/etc/ssh/sshd_config"

# Define the string to be replaced
old_string="PasswordAuthentication no"
new_string="PasswordAuthentication yes"

# Check if the file exists
if [ -e "$sshd_config" ]; then
    # Use sed to replace the old string with the new string
    sudo sed -i "s/$old_string/$new_string/" "$sshd_config"

    # Check if the sed command was successful
    if [ $? -eq 0 ]; then
        echo "String replaced successfully."
        # Restart the SSH service to apply the changes
        sudo service ssh restart
    else
        echo "Error replacing string in $sshd_config."
    fi
else
    echo "File $sshd_config not found."
fi

echo "123" | passwd --stdin ec2-user
systemctl restart sshd

# Install Docker
yum update -y
yum install docker -y
systemctl start docker

# Pull and run Ambience from Docker
yum install git -y
cd /home/ec2-user
git clone https://github.com/ambience-cloud/elixir-ambience.git
curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
cd elixir-ambience

# sed -i 's/"//g' ".env"
# sed -i 's/mongourl=mongodb:\/\/mongo:27017/mongourl=mongodb:\/\/10.2.4.199:27017/g' ".env"
# sed -i 's/externalhost=localhost/externalhost=testssl123.click/g' ".env"
# sed -i 's/externalport=1740/externalport=443/g' ".env"
# sed -i 's/externalprotocol=http/externalprotocol=https/g' ".env"
cat << EOF3 > ./docker-compose.yaml
version: "3"
services:
  elixir-ambience:
    container_name: elixir-ambience
    image: elixirtech/elixir-ambience
    environment:
       #mongodb running in host for Windows and OSx
       #mongodb part of docker compose
       - mongourl=$\{mongourl\}
       - externalhost=$\{externalhost\}
       - externalport=$\{externalport\}
       - externalprotocol=$\{externalprotocol\}
    ports:
       - 1740:1740
#volumes:
#  elixirmongodbdata:
EOF3
sed -i 's/\\//g' "./docker-compose.yaml"
# docker-compose up
EOF
  tags = {
    Name = "private-ec2-instance"
  }
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "docdb_cluster" {
  cluster_identifier      = "docdb-cluster"
  master_username         = "docdbadmin"
  master_password         = "SecurePass123!"  # Change to a secure password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  vpc_security_group_ids  = [aws_security_group.allow_all.id]
  db_subnet_group_name    = aws_docdb_subnet_group.docdb_subnet_group.id  # Use subnet group ID
}

# DocumentDB Instances
resource "aws_docdb_cluster_instance" "docdb_instance" {
  count              = 2
  identifier         = "docdb-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb_cluster.id
  instance_class     = "db.r5.large"
  subnet_group_name  = aws_docdb_subnet_group.docdb_subnet_group.id  # Use subnet group ID
  tags = {
    Name = "docdb-instance-${count.index}"
  }
}

# Subnet Group for DocumentDB
resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "docdb-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]

  tags = {
    Name = "docdb-subnet-group"
  }
}
