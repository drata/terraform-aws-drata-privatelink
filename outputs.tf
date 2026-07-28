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
