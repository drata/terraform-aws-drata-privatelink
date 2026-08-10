terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "privatelink" {
  source = "../../"

  name       = var.name
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  target_instance_id = var.target_instance_id
  target_port        = var.target_port

  health_check_protocol = var.health_check_protocol
  health_check_path     = var.health_check_path

  listener_port                    = var.listener_port
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  # Must admit the Drata CIDR. Set "off" if Drata CIDR overlaps your VPC.
  nlb_ingress_cidrs                                            = var.nlb_ingress_cidrs
  enforce_security_group_inbound_rules_on_private_link_traffic = var.enforce_security_group_inbound_rules_on_private_link_traffic

  acceptance_required        = var.acceptance_required
  allowed_principals         = var.allowed_principals
  supported_ip_address_types = var.supported_ip_address_types

  # Optional. Lets the consumer keep using your existing hostname.
  # AWS verifies ownership via a TXT record in the domain's PUBLIC zone.
  private_dns_name               = var.private_dns_name
  private_dns_validation_zone_id = var.private_dns_validation_zone_id
  verify_private_dns_name        = var.verify_private_dns_name

  tags = var.tags
}
