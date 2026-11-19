terraform {
  backend "s3" {
    bucket       = "uptime-monitor-bucket-s3"
    key          = "uptime-monitor/prod/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}