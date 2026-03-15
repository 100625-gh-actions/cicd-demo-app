# =============================================================================
# Outputs
# =============================================================================
# After running `terraform apply`, these values are printed to the console.
# They give you the information needed to access both environments.
#
# You can also retrieve them later with:
#   terraform output                    # Show all outputs
#   terraform output staging_app_url    # Show a specific output
# =============================================================================

# -----------------------------------------------------------------------------
# Staging Environment Outputs
# -----------------------------------------------------------------------------

output "staging_instance_id" {
  description = "AWS Instance ID of the staging EC2 instance. Useful for AWS CLI commands."
  value       = aws_instance.staging.id
}

output "staging_public_ip" {
  description = "Public IP address of the staging instance. May change if the instance is stopped and started."
  value       = aws_instance.staging.public_ip
}

output "staging_app_url" {
  description = "URL to access the Flask app on the staging instance (port 5000)."
  value       = "http://${aws_instance.staging.public_ip}:5000"
}

# -----------------------------------------------------------------------------
# Production Environment Outputs
# -----------------------------------------------------------------------------

output "production_instance_id" {
  description = "AWS Instance ID of the production EC2 instance. Useful for AWS CLI commands."
  value       = aws_instance.production.id
}

output "production_public_ip" {
  description = "Public IP address of the production instance. May change if the instance is stopped and started."
  value       = aws_instance.production.public_ip
}

output "production_app_url" {
  description = "URL to access the Flask app on the production instance (port 5000)."
  value       = "http://${aws_instance.production.public_ip}:5000"
}
