terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      # 5.100.0 is the version supported_regions was verified against.
      source  = "hashicorp/aws"
      version = ">= 5.100.0"
    }
  }
}
