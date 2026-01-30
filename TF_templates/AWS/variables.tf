variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret key"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "rhel-server"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  #default     = "t2.medium"
  default     = "t3.small"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 0
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change this default to your IP for production!
}

# Vault Configuration
variable "vault_addr" {
  description = "HashiCorp Vault address"
  type        = string
  default     = "https://vault"
  # Set via TF_VAR_vault_addr or in terraform.tfvars
}

# variable "vault_token" {
#   description = "Vault authentication token"
#   type        = string
#   sensitive   = true
# }

variable "vault_role_id" {
  description = "Vault AppRole Role ID for Terraform"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "Vault AppRole Secret ID for Terraform"
  type        = string
  sensitive   = true
}

# Ansible Automation Platform Configuration
variable "aap_host" {
  description = "Ansible Automation Platform URL"
  type        = string
  # Example: https://aap.example.com
  default     = "https://control"
}

variable "aap_username" {
  description = "AAP username"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "aap_password" {
  description = "AAP password"
  type        = string
  sensitive   = true
  default     = "password"
}

variable "aap_workflow_job_template" {
  description = "Ansible Automation Platform workflow job template name (Already exists in AAP)"
  type = object({
    name         = string
    organization = string
  })
}

variable "aap_inventory" {
  description = "The Terraform Inventory name in AAP. (Already exists in AAP)"
  type = object({
    name         = string
    organization = string
  })
}
