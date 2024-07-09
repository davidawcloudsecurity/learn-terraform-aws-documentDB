# Define AWS provider and region
provider "aws" {
  region = "ap-southeast-1"  # Replace with your desired region
}

# Variables
variable "docdb_name" {
  type    = string
  default = "docdb-02"
}

variable "docdb_username" {
  type    = string
  default = "docdbadmin"
}

variable "docdb_password" {
  type    = string
  default = "SecurePass123!"
}

variable "instance_class" {
  description = "The instance class to use. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html#db-instance-class-specs"
  type        = string
  default     = "db.r5.large"
}

variable "cluster_size" {
  type        = number
  default     = 1
  description = "Number of DB instances to create in the cluster"
}

variable "storage_type" {
  type        = string
  description = "The storage type to associate with the DB cluster. Valid values: standard, iopt1"
  default     = "standard"
}

variable "snapshot_identifier" {
  type        = string
  default     = ""
  description = "Specifies whether or not to create this cluster from a snapshot. You can use either the name or ARN when specifying a DB cluster snapshot, or the ARN when specifying a DB snapshot"
}

variable "db_port" {
  type        = number
  default     = 27017
  description = "DocumentDB port"
}

variable "cluster_family" {
  type        = string
  default     = "docdb5.0"
  description = "The family of the DocumentDB cluster parameter group. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-cluster-parameter-group-create.html"
}

variable "cluster_parameters" {
  type = list(object({
    name         = string
    value        = string
    apply_method = string
  }))
  default = [
    {
      name         = "tls"
      value        = "disabled"
      apply_method = "pending-reboot"
    }
  ]
}

# Resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create Public Subnets in two AZs
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"  # Specify AZ for the subnet

  tags = {
    Name = "${var.docdb_name}-public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1b"  # Specify different AZ for the subnet

  tags = {
    Name = "${var.docdb_name}-public-subnet-b"
  }
}

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

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat.id
  subnet_id      = aws_subnet.public_a.id

  tags = {
    Name = "main-nat-gateway"
  }
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_b.id  # Specify the second public subnet ID

  tags = {
    Name = "main-nat-gateway-b"
  }
}

# Create Private Subnets in two AZs
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"  # Specify AZ for the subnet

  tags = {
    Name = "${var.docdb_name}-private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1b"  # Specify different AZ for the subnet

  tags = {
    Name = "${var.docdb_name}-private-subnet-a"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

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

resource "aws_instance" "app_server" {
  ami                  = "ami-018ba43095ff50d08"  # Replace with your desired AMI
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.private_a.id
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  user_data = <<EOF
#!/bin/bash
# Your user data script here
EOF

  tags = {
    Name = "${var.docdb_name}-private-ec2-instance"
  }

  depends_on = [aws_docdb_cluster.docdb_cluster]
}

resource "aws_docdb_cluster" "docdb_cluster" {
  cluster_identifier         = "${var.docdb_name}-cluster"
  master_username            = var.docdb_username
  master_password            = var.docdb_password
  backup_retention_period    = 5
  preferred_backup_window    = "07:00-09:00"
  storage_type               = var.storage_type
  port                       = var.db_port
  vpc_security_group_ids     = [aws_security_group.allow_all.id]
  db_subnet_group_name       = aws_docdb_subnet_group.default.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.default.name
}

resource "aws_docdb_cluster_instance" "docdb_instance" {
  count                = var.cluster_size
  identifier           = "docdb-instance-${count.index}"
  cluster_identifier   = aws_docdb_cluster.docdb_cluster.id
  instance_class       = var.instance_class

  tags = {
    Name = "${var.docdb_name}-instance-${count.index}"
  }
}

resource "aws_docdb_cluster_parameter_group" "default" {
  name        = "${var.docdb_name}-docdb-cluster-parameter-group"
  description = "DB cluster parameter group"
  family      = var.cluster_family

  dynamic "parameter" {
    for_each = var.cluster_parameters
    content {
      apply_method = parameter.value.apply_method
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  tags = {
    Name = "${var.docdb_name}-cluster-parameter-group"
  }
}

resource "aws_docdb_subnet_group" "default" {
  name       = "${var.docdb_name}-docdb-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]

  tags = {
    Name = "${var.docdb_name}-subnet-group"
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.docdb_name}-ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.docdb_name}-ec2_role"
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.docdb_name}-ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Outputs
output "ec2_instance_id" {
  value = aws_instance.app_server.id
}

output "ec2_instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ec2_instance_private_ip" {
  value = aws_instance.app_server.private_ip
}

output "docdb_cluster_id" {
  value = aws_docdb_cluster.docdb_cluster.id
}

output "docdb_cluster_endpoint" {
  value = aws_docdb_cluster.docdb_cluster.endpoint
}

output "docdb_cluster_port" {
  value = aws_docdb_cluster.docdb_cluster.port
}
