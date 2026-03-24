####  Why data instead of resource for AMI SSM?  packer ami ID into ssm -> tf reads via data now = no broken CI flow
#resource "aws_ssm_parameter" "ops_ami" {
#  name        = "/devopslab/ami/ops"
#  description = "AMI ID for Ops service"
#  type        = "String"
#  value       = "ami-05dd2db733186be21"   # OPS Packer AMI ID new with internal backend 
#  overwrite   = true
#}

#resource "aws_instance" "ops" {
#  ami                         = aws_ssm_parameter.ops_ami.value

##############################
# Read AMI from SSM (Packer writes it)
##############################
data "aws_ssm_parameter" "ops_ami" {
  name = "/devopslab/ami/ops"
}

##############################
# EC2 Instance
##############################
resource "aws_instance" "ops" {
  ami                         = data.aws_ssm_parameter.ops_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.ops_sg_id]
  iam_instance_profile        = var.iam_instance_profile
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/cloud-init/ops.sh.tpl", {
    domain         = var.domain
    admin_ui_ip    = var.admin_ui_ip
    wordpress_ip   = var.wordpress_ip
    node_app_ip    = var.node_app_ip
    aws_region     = var.aws_region
    aws_account_id = var.aws_account_id
  })

  tags = {
    Name = var.ec2_name
    Role = "ops"
  }
}

##############################
# Elastic IP
##############################
resource "aws_eip" "ops" {
  tags = { Name = "ops-eip" }
}

resource "aws_eip_association" "ops" {
  instance_id   = aws_instance.ops.id
  allocation_id = aws_eip.ops.id
}

##############################
# Route53 Record
##############################
data "aws_route53_zone" "main" {
  name         = var.root_domain
  private_zone = false
}


