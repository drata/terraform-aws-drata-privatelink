output "service_name" {
  description = "The endpoint service name (com.amazonaws.vpce.<region>.vpce-svc-xxxx). Hand this to the consumer to create their interface endpoint."
  value       = aws_vpc_endpoint_service.this.service_name
}

output "service_id" {
  description = "The VPC endpoint service ID (vpce-svc-xxxx)."
  value       = aws_vpc_endpoint_service.this.id
}

output "service_state" {
  description = "Lifecycle state of the endpoint service (e.g. Available)."
  value       = aws_vpc_endpoint_service.this.state
}

output "service_availability_zones" {
  description = "AZs the endpoint service is available in. The consumer's subnets must overlap these."
  value       = aws_vpc_endpoint_service.this.availability_zones
}

output "private_dns_verification_name" {
  description = "Name label of the domain ownership verification TXT record, null when private_dns_name is not set. Publish it as <name>.<domain>, where <domain> is private_dns_name or any parent of it — verifying example.com also covers gitlab.example.com."
  value       = try(aws_vpc_endpoint_service.this.private_dns_name_configuration[0].name, null)
}

output "private_dns_verification_type" {
  description = "Record type of the ownership verification record. Always TXT."
  value       = try(aws_vpc_endpoint_service.this.private_dns_name_configuration[0].type, null)
}

output "private_dns_verification_value" {
  description = "Value of the ownership verification TXT record."
  value       = try(aws_vpc_endpoint_service.this.private_dns_name_configuration[0].value, null)
}

output "private_dns_verification_state" {
  description = "Verification state as of the last read: pendingVerification, verified or failed. Consumers cannot enable private DNS until this reads verified. Note the lag — the value is captured before verification runs, so the apply that actually verifies the domain still prints pendingVerification. Re-run plan or refresh to see it settle."
  value       = try(aws_vpc_endpoint_service.this.private_dns_name_configuration[0].state, null)
}

output "nlb_arn" {
  description = "ARN of the internal network load balancer."
  value       = aws_lb.this.arn
}

output "nlb_dns_name" {
  description = "Internal DNS name of the NLB (for provider-side validation only)."
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group."
  value       = aws_lb_target_group.this.arn
}

output "nlb_security_group_id" {
  description = "Security group ID attached to the NLB. The target instance's SG must allow ingress from this SG on the target port."
  value       = aws_security_group.nlb.id
}
