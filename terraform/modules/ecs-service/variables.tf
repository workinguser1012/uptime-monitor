variable "project" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "environment" {
  type    = map(string)
  default = {}
}

# Plain true/false so Terraform knows it at plan time (the IDs below are not known until apply)
variable "attach_to_alb" {
  type    = bool
  default = true
}

variable "alb_sg_id" {
  type    = string
  default = null
}

variable "target_group_arn" {
  type    = string
  default = null
}