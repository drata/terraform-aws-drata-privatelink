output "service_name" {
  description = "Endpoint service name to hand to the consumer."
  value       = module.privatelink.service_name
}

output "nlb_security_group_id" {
  description = "The target instance's SG must allow ingress from this SG on target_port."
  value       = module.privatelink.nlb_security_group_id
}

output "target_group_arn" {
  value = module.privatelink.target_group_arn
}

output "private_dns_verification_name" {
  description = "Publish as <name>.<domain> when your DNS is not in this account. Null if private_dns_name is unset."
  value       = module.privatelink.private_dns_verification_name
}

output "private_dns_verification_value" {
  description = "TXT value to publish alongside private_dns_verification_name."
  value       = module.privatelink.private_dns_verification_value
}

output "private_dns_verification_state" {
  description = "The consumer cannot enable private DNS until this reads verified."
  value       = module.privatelink.private_dns_verification_state
}
