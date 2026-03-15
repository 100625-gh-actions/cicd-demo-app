# =============================================================================
# Input Variables
# =============================================================================
# These variables allow you to customize the deployment without modifying
# the main configuration. You can set them via:
#   1. A terraform.tfvars file      (terraform apply)
#   2. Command-line flags           (terraform apply -var="app_version=1.0.0")
#   3. Environment variables        (export TF_VAR_ghcr_token="ghp_...")
#
# Variables marked as "sensitive" won't show their values in plan output.
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where all resources will be created. us-east-1 has the most free-tier services."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Project Naming
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name prefix for all resources. Used in tags and resource names to identify this project."
  type        = string
  default     = "cicd-demo"
}

# -----------------------------------------------------------------------------
# EC2 Instance Configuration
# -----------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. t2.micro is free-tier eligible (750 hours/month for 12 months)."
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access. Leave empty to disable SSH key-based access."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the instances. Restrict to your IP in production (e.g., [\"203.0.113.50/32\"])."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Docker / Application Configuration
# -----------------------------------------------------------------------------

variable "docker_image" {
  description = "Full GHCR image path without the tag. Example: ghcr.io/100625-gh-actions/cicd-demo-app"
  type        = string
  default     = "ghcr.io/100625-gh-actions/cicd-demo-app"
}

variable "app_version" {
  description = "Docker image tag to deploy. Can be a semantic version (e.g., '1.2.3'), a Git SHA, or 'latest'."
  type        = string
  default     = "latest"
}

variable "ghcr_token" {
  description = "GitHub Personal Access Token (PAT) with read:packages scope, used to authenticate with GHCR. Set via TF_VAR_ghcr_token env var to avoid storing in files."
  type        = string
  sensitive   = true
}
