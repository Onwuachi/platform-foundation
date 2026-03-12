variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

# Node API ECR repo
variable "ecr_repo_node" {
  description = "Node API ECR repository name"
  type        = string
}

# WordPress ECR repo
variable "ecr_repo_wordpress" {
  description = "WordPress ECR repository name"
  type        = string
}

variable "ecr_repo_go" {
  description = "ECR repo for Go API"
  type        = string
}


# Image tag (CI/CD updates this)
variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
  default     = "latest"
}

variable "vpc_id" {
  description = "Shared VPC ID"
  type        = string
}

variable "admin_ip" {
  description = "Admin IP for SSH access"
  type        = string
  default     = "47.12.88.38/32"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+/\\d+$", var.admin_ip))
    error_message = "admin_ip must be CIDR format like 192.168.1.0/24"
  }
}

variable "mongo_uri" {
  description = "MongoDB connection URI"
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}



variable "enable_node_api" {
  description = "Enable Node API EC2 instance"
  type        = bool
  default     = false
}

variable "enable_web" {
  type    = bool
  default = false
}

variable "enable_wordpress" {
  type    = bool
  default = false
}

variable "enable_admin_ui" {
  type    = bool
  default = false
}

variable "enable_secrets_manager" {
  type = bool
  default = false
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}