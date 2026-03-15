#!/bin/bash
# =============================================================================
# EC2 User Data Script - STAGING Environment
# =============================================================================
# This script runs automatically as root when the EC2 instance first boots.
# It installs Docker, authenticates with GitHub Container Registry (GHCR),
# pulls the Flask application image, and runs it as a container.
#
# Variables like ${ghcr_token} are replaced by Terraform's templatefile()
# function before the script is passed to the EC2 instance.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Send all output to a log file for debugging
exec > /var/log/user-data.log 2>&1
echo "=== User data script started at $(date) ==="
echo "=== Environment: STAGING ==="

# -----------------------------------------------------------------------------
# Step 1: Install Docker
# -----------------------------------------------------------------------------
echo ">>> Installing Docker..."
yum update -y
yum install -y docker

# Start Docker and enable it to start on boot
systemctl start docker
systemctl enable docker

# Verify Docker is running
docker --version
echo ">>> Docker installed and running."

# -----------------------------------------------------------------------------
# Step 2: Authenticate with GitHub Container Registry (GHCR)
# -----------------------------------------------------------------------------
# GHCR requires authentication even for pulling private images.
# The token is passed from Terraform via the templatefile() function.
echo ">>> Logging in to GHCR..."
echo "${ghcr_token}" | docker login ghcr.io -u USERNAME --password-stdin
echo ">>> GHCR login successful."

# -----------------------------------------------------------------------------
# Step 3: Pull the Docker image
# -----------------------------------------------------------------------------
echo ">>> Pulling image: ${docker_image}:${app_version}"
docker pull ${docker_image}:${app_version}
echo ">>> Image pulled successfully."

# -----------------------------------------------------------------------------
# Step 4: Run the Flask application container
# -----------------------------------------------------------------------------
# Flags explained:
#   -d                        Run in background (detached mode)
#   --name cicd-demo          Give the container a friendly name
#   --restart unless-stopped  Auto-restart on crash or reboot (unless manually stopped)
#   -p 5000:5000              Map host port 5000 to container port 5000
#   -e APP_VERSION            Tell the app which version it is (shown on /health)
#   -e ENVIRONMENT=staging    Tell the app it's running in staging
#   -e BUILD_SHA              Git commit SHA for traceability
echo ">>> Starting container..."
docker run -d \
  --name cicd-demo \
  --restart unless-stopped \
  -p 5000:5000 \
  -e APP_VERSION=${app_version} \
  -e ENVIRONMENT=staging \
  -e BUILD_SHA=${build_sha} \
  ${docker_image}:${app_version}

echo ">>> Container started successfully."
echo "=== User data script completed at $(date) ==="
