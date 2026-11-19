data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

module "vpc" {
  source   = "./modules/vpc"
  name     = var.project
  cidr     = var.cidr
  az_count = var.az_count
}

module "acm" {
  source      = "./modules/acm"
  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.main.zone_id
}

module "alb" {
  source            = "./modules/alb"
  name              = var.project
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"
  name   = var.project
}

module "frontend" {
  source = "./modules/ecs-service"

  project            = var.project
  name               = "frontend"
  region             = var.region
  cluster_id         = module.ecs_cluster.cluster_id
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  image              = var.frontend_image
  container_port     = 80
  cpu                = 256
  memory             = 512

  attach_to_alb    = true
  alb_sg_id        = module.alb.alb_sg_id
  target_group_arn = module.alb.target_group_arn
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}