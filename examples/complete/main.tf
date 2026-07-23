# Complete example for terraform-aws-drata-privatelink.
#
# Stands up the provider-side PrivateLink stack (target group -> internal NLB ->
# endpoint service) against an EXISTING instance you supply. The instance is not
# created here — the module only references it.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30.0"
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

  # Set to true + a specific principal ARN for real consumers.
  acceptance_required = var.acceptance_required
  allowed_principals  = var.allowed_principals

  tags = var.tags
}
