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
