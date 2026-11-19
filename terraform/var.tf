variable "project" {
  type    = string
  default = "uptime-monitor"
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "domain_name" {
  type    = string
  default = "uptimedashboard.store"
}

variable "frontend_image" {
  type        = string
  description = "Full ECR image URI ending in the git SHA tag"
}