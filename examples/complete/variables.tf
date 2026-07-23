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
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
