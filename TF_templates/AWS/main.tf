terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    aap = {
      source  = "ansible/aap"
      version = "~> 1.4"
    }
  }
}

# Data source to retrieve AWS credentials from Vault
#
# data "vault_generic_secret" "aws_creds" {
#   path = "secret/data/aws_creds"
#   namespace = "admin"
# }

# Provider configuration for AWS (credentials from Vault)
provider "aws" {
  region     = var.aws_region

  # Use secrets defined in Terraform Enterprise
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  
  # Alternative: Use Vault to get the AWS credentials
  # access_key = data.vault_generic_secret.aws_creds.data.access_key
  # secret_key = data.vault_generic_secret.aws_creds.data.secret_key
}

# Provider configuration for Vault using AppRole authentication
provider "vault" {
  address           = var.vault_addr

# Alternative: Use AppRole authentication (commented out for now)
  auth_login {
    path = "auth/approle/login"
    
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
      skip_child_token  = true
    }
  }
}

# Data source to retrieve AAP credentials from Vault
#
# data "vault_generic_secret" "aap_creds" {
#   path = "secret/data/aap_creds"
#   namespace = "admin"
# }

# Provider configuration for Ansible Automation Platform
provider "aap" {
  host     = var.aap_host
  # Use secrets defined in Terraform Enterprise
  username = var.aap_username
  password = var.aap_password
  
  # Alternative: Use Vault to get the AAP credentials
  # username = data.vault_generic_secret.aap_creds.data.username
  # password = data.vault_generic_secret.aap_creds.data.password
}

# Generate TLS private key for SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key-latest"
  public_key = tls_private_key.ssh_key.public_key_openssh
  
  tags = {
    Name        = "${var.project_name}-ssh-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Generate random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Store SSH private key and instance info in Vault
resource "vault_generic_secret" "ssh_private_key" {
  path = "secret/${var.project_name}/ssh-keys/latest"

  data_json = jsonencode({
    private_key  = tls_private_key.ssh_key.private_key_pem
    public_key   = tls_private_key.ssh_key.public_key_openssh
    key_name     = aws_key_pair.deployer.key_name
    instance_ids = aws_instance.rhel_server[*].id
    public_ips   = aws_instance.rhel_server[*].public_ip
  })
}

# Get latest RHEL AMI
##data "aws_ami" "rhel" {
##  most_recent = true
##  owners      = ["309956199498"] # Red Hat's official AWS account ID
  
##  filter {
##    name   = "name"
##    values = ["RHEL-9*_HVM-*-x86_64-*"]
##  }
  
##  filter {
##    name   = "architecture"
##    values = ["x86_64"]
##  }
  
##  filter {
##    name   = "virtualization-type"
##    values = ["hvm"]
##  }
##}

data "aws_ami" "rhel" {
  most_recent = true
##  owners      = ["309956199498"] # Red Hat's official AWS account ID
  owners      = ["629017097470"]
  filter {
    name   = "name"
    values = ["Amazon*Linux*2023*(kernel-6.1)"]
  }
  
##  filter {
##    name   = "architecture"
##    values = ["x86_64"]
##  }
  
##  filter {
##    name   = "virtualization-type"
##    values = ["hvm"]
##  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create security group
resource "aws_security_group" "rhel_server" {
  name_prefix = "${var.project_name}-sg-"
  description = "Security group for RHEL server"
  vpc_id      = aws_vpc.main.id
  
  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }
  
  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.project_name}-security-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create RHEL EC2 instance(s)
resource "aws_instance" "rhel_server" {
  count                  = var.instance_count
  ami                    = data.aws_ami.rhel.id
  #ami                    = ami-03ea746da1a2e36e7
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.rhel_server.id]

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Server ${count.index + 1} provisioned by Terraform" > /tmp/terraform-provisioned.txt
              EOF

  tags = {
    Name        = "${var.project_name}-rhel-server-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    OS          = "RHEL"
    Index       = count.index
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ############### Trigger and AAP Workflow below ################# 
# Launch existing AAP workflow job template after instances are ready
#
data "aap_inventory" "inventory" {
  name              = "Terraform Inventory"
  organization_name = "Default"
}

data "aap_workflow_job_template" "workflow_job_template" {
  name              = "WF-Launched by TFE"
  organization_name = "Default"
}

# Launch the workflow_job_template
resource "aap_workflow_job" "workflow_job" {
  workflow_job_template_id = data.aap_workflow_job_template.workflow_job_template.id
  inventory_id             = data.aap_inventory.inventory.id

# Force creation of this resource to wait for the rhel_server resource to be created
# Wait for instances to be ready and SSH key stored
  depends_on = [
    aws_instance.rhel_server,
    vault_generic_secret.ssh_private_key
  ]
}

# End of main.tf file
