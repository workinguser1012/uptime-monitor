output "site_url" {
  value = "https://${var.domain_name}"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}