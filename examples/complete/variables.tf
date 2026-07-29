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
  description = "CIDRs allowed inbound to the NLB listener. Must admit the Drata CIDR for your tenant's region; defaults to Drata prod us-west-2."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enforce_security_group_inbound_rules_on_private_link_traffic" {
  description = "\"on\" (default) filters PrivateLink traffic through the NLB security group. Set \"off\" if the Drata CIDR overlaps your VPC. See the note in main.tf."
  type        = string
  default     = "on"
}

variable "supported_ip_address_types" {
  type    = list(string)
  default = ["ipv4"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
