variable "region" {
  type    = string
  default = "us-west-2"
}

variable "name" {
  type    = string
  default = "privatelink-example"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_instance_id" {
  type = string
}

variable "target_port" {
  type    = number
  default = 443
}

variable "acceptance_required" {
  type    = bool
  default = true
}

variable "allowed_principals" {
  type    = list(string)
  default = ["arn:aws:iam::269135526815:root"]
}

variable "health_check_protocol" {
  type    = string
  default = "HTTPS"
}

variable "health_check_path" {
  type    = string
  default = "/-/health"
}

variable "listener_port" {
  type    = number
  default = 443
}

variable "enable_cross_zone_load_balancing" {
  type    = bool
  default = true
}

variable "nlb_ingress_cidrs" {
  type    = list(string)
  default = []
}

variable "supported_ip_address_types" {
  type    = list(string)
  default = ["ipv4"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
