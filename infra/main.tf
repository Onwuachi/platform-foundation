module "shared" {
  source         = "./shared"
  key_name       = var.key_name
  aws_account_id = var.aws_account_id
  admin_ip       = var.admin_ip
}

module "security" {
  source   = "./security"
  vpc_id   = module.shared.vpc_id
  admin_ip = var.admin_ip
}

module "web" {
  count  = var.enable_web ? 1 : 0
  source = "./web"

  vpc_id               = module.shared.vpc_id
  subnet_id            = element(module.shared.public_subnets, 0)
  iam_instance_profile = module.shared.iam_instance_profile
  key_name             = var.key_name
  aws_account_id       = var.aws_account_id
  aws_region           = var.aws_region
  ecr_repo_node        = var.ecr_repo_node
  ecr_repo_go          = var.ecr_repo_go
  ecr_repo_wordpress   = var.ecr_repo_wordpress
  mongo_uri            = var.mongo_uri # ✅ This will get updated when aws secrets is enabled for now save $$$
  web_sg_id            = module.security.web_sg_id
}

module "ops" {
  source = "./ops"

  subnet_id            = element(module.shared.public_subnets, 1)
  ops_sg_id            = module.security.ops_sg_id
  iam_instance_profile = module.shared.iam_instance_profile
  key_name             = var.key_name
  ec2_name             = "ops-01"
  instance_type        = "t3.micro"


  #admin_ui_ip  = module.admin_ui.admin_ui_public_ip
  #wordpress_ip = module.wordpress.wordpress_public_ip
  #node_app_ip  = module.app.app_public_ip
  admin_ui_ip  = var.enable_admin_ui ? module.admin_ui[0].admin_ui_public_ip : null
  wordpress_ip = var.enable_wordpress ? module.wordpress[0].wordpress_public_ip : null
  node_app_ip  = var.enable_node_api ? module.app[0].app_public_ip : null

  domain      = "ops.onwuachi.com"
  root_domain = "onwuachi.com"
  environment = var.environment

  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id
  image_tag      = var.image_tag

  depends_on = [
    #aws_ssm_parameter.node_api_url,
    aws_ssm_parameter.admin_ui_url,
    aws_ssm_parameter.hugo_url
  ]
}



data "aws_route53_zone" "onwuachi" {
  name         = "onwuachi.com."
  private_zone = false
}

resource "aws_route53_record" "ops" {
  zone_id = data.aws_route53_zone.onwuachi.zone_id
  name    = "ops.onwuachi.com"
  type    = "A"
  ttl     = 60
  records = [module.ops.ops_public_ip] # Correct once ops module outputs EIP
}


module "wordpress" {
  count  = var.enable_wordpress ? 1 : 0
  source = "./wordpress"

  vpc_id             = module.shared.vpc_id
  subnet_id          = element(module.shared.public_subnets, 0)
  key_name           = var.key_name
  ssm_profile_name   = module.shared.iam_instance_profile
  ec2_name           = "wordpress-01"
  admin_ip           = var.admin_ip
  aws_account_id     = var.aws_account_id
  aws_region         = var.aws_region
  ecr_repo_node      = var.ecr_repo_node
  ecr_repo_go        = "hello-docker-go"
  ecr_repo_wordpress = "wordpress"
  wordpress_sg_id    = module.security.wordpress_sg_id # if you expose it revert #aws_security_group.wordpress_sg.id
}

module "app" {
  count  = var.enable_node_api ? 1 : 0
  source = "./app"

  vpc_id               = module.shared.vpc_id
  subnet_id            = element(module.shared.public_subnets, 0)
  key_name             = var.key_name
  aws_account_id       = var.aws_account_id
  iam_instance_profile = module.shared.iam_instance_profile
  aws_region           = var.aws_region
  ec2_name             = "Node-app-01"
  ecr_repo_node        = var.ecr_repo_node
  image_tag            = var.image_tag
  admin_ip             = var.admin_ip
  mongo_uri            = var.mongo_uri
  ops_sg_id            = module.security.ops_sg_id
  enable_ssm           = true
}

module "admin_ui" {
  count  = var.enable_admin_ui ? 1 : 0
  source = "./admin-ui-instance"

  subnet_id            = element(module.shared.public_subnets, 1)
  sg_id                = module.security.ops_sg_id
  key_name             = var.key_name
  iam_instance_profile = module.shared.iam_instance_profile

  aws_region  = var.aws_region
  ec2_name    = "admin-ui-01"
  environment = "dev"
}

