variable "subnet_id" {
  type = string
}

variable "ops_sg_id" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "key_name" {
  type = string
}

variable "ec2_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# App backend IPs passed in from root
variable "admin_ui_ip" {
  type = string
}

variable "wordpress_ip" {
  type = string
}

variable "node_app_ip" {
  type = string
}

# DNS
variable "domain" {
  type = string
}

variable "root_domain" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "image_tag" {
  type = string
}


variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}


#variable "az" {
#  description = "Availability Zone for resources"
#  type        = string
#}



