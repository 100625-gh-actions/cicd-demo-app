# =============================================================================
# Main Terraform Configuration
# =============================================================================
# This configuration deploys a Flask Docker application to AWS on TWO separate
# EC2 instances: one for STAGING and one for PRODUCTION.
#
# Architecture:
#   - Both instances live in the same region and default VPC
#   - Each instance is t2.micro (AWS free tier eligible)
#   - Docker is installed via user_data boot scripts
#   - The Flask app container is pulled from GHCR (GitHub Container Registry)
#   - Staging and Production are completely independent instances
#
# Usage:
#   terraform init
#   terraform plan -var="ghcr_token=ghp_..."
#   terraform apply -var="ghcr_token=ghp_..."
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform & Provider Configuration
# -----------------------------------------------------------------------------
# We pin the Terraform version and AWS provider to ensure reproducible builds.
# The ~> 5.0 constraint allows any 5.x release but not 6.0+.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
# These data sources dynamically look up values so we don't hardcode AMI IDs
# or VPC/subnet IDs. This makes the config portable across AWS accounts.
# -----------------------------------------------------------------------------

# Look up the latest Amazon Linux 2023 AMI.
# Amazon Linux 2023 is the recommended general-purpose Linux AMI from AWS.
# We filter by name pattern and owner (Amazon) to always get the newest version.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Look up the default VPC in the current region.
# Every AWS account has a default VPC created automatically.
# We use it here to keep things simple (no custom networking needed).
data "aws_vpc" "default" {
  default = true
}

# Look up all subnets in the default VPC.
# We'll place our EC2 instances in the first available subnet.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------
# This security group controls network access to both EC2 instances.
# We allow:
#   - Inbound SSH (port 22) for remote management
#   - Inbound HTTP on port 5000 (Flask app default port)
#   - All outbound traffic (needed for Docker pulls, yum updates, etc.)
# -----------------------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for ${var.project_name} - allows SSH and Flask app traffic"
  vpc_id      = data.aws_vpc.default.id

  # --- Inbound Rules ---

  # Allow SSH access (port 22) from specified CIDR blocks.
  # In production, you should restrict this to your IP address only!
  # Default is 0.0.0.0/0 (open to the world) for demo purposes.
  ingress {
    description = "SSH access for remote management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Allow HTTP access to the Flask app (port 5000).
  # Open to the world so anyone can access the demo app.
  ingress {
    description = "Flask application traffic"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- Outbound Rules ---

  # Allow all outbound traffic.
  # The instances need this to:
  #   - Download Docker packages (yum install)
  #   - Pull container images from GHCR
  #   - Reach external APIs if the app needs them
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-app-sg"
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance: STAGING
# -----------------------------------------------------------------------------
# The staging instance is where we deploy first to verify changes before
# promoting to production. It runs the same Docker image but with
# ENVIRONMENT=staging so the app knows which environment it's in.
#
# The user_data script (user_data_staging.sh) runs once at first boot and:
#   1. Installs Docker
#   2. Logs in to GHCR (GitHub Container Registry)
#   3. Pulls the specified Docker image
#   4. Runs the Flask app container on port 5000
# -----------------------------------------------------------------------------
resource "aws_instance" "staging" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # SSH key pair (optional - set var.ssh_key_name to enable SSH access)
  key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

  # The user_data script runs as root on first boot.
  # We use templatefile() to inject our Terraform variables into the bash script.
  # This is how we pass the Docker image name, GHCR token, etc. to the instance.
  user_data = templatefile("${path.module}/user_data_staging.sh", {
    ghcr_token   = var.ghcr_token
    docker_image = var.docker_image
    app_version  = var.app_version
    build_sha    = var.app_version  # Using app_version as build SHA reference
  })

  # Ensure a public IP is assigned so we can access the app from the internet
  associate_public_ip_address = true

  # Tags help identify resources in the AWS console and for billing
  tags = {
    Name        = "${var.project_name}-staging"
    Environment = "staging"
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance: PRODUCTION
# -----------------------------------------------------------------------------
# The production instance serves real traffic. It's identical to staging
# in terms of infrastructure, but runs with ENVIRONMENT=production.
#
# In a real-world setup, you'd deploy to staging first, run smoke tests,
# and only then deploy the same image version to production.
# -----------------------------------------------------------------------------
resource "aws_instance" "production" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # SSH key pair (optional - set var.ssh_key_name to enable SSH access)
  key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

  # Same pattern as staging, but uses the production user_data script
  # which sets ENVIRONMENT=production in the container.
  user_data = templatefile("${path.module}/user_data_production.sh", {
    ghcr_token   = var.ghcr_token
    docker_image = var.docker_image
    app_version  = var.app_version
    build_sha    = var.app_version  # Using app_version as build SHA reference
  })

  # Ensure a public IP is assigned so we can access the app from the internet
  associate_public_ip_address = true

  # Tags help identify resources in the AWS console and for billing
  tags = {
    Name        = "${var.project_name}-production"
    Environment = "production"
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
