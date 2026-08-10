########################################################################
# Private DNS name
#
# Without one, the consumer can only address the service through the
# endpoint's generated regional name. PrivateLink does not terminate TLS,
# so the certificate on that connection is yours and its SAN does not list
# that name — any client validating certificates fails.
#
# Associating your real hostname with the endpoint service fixes it: once
# AWS has verified you own the domain, the consumer enables private DNS and
# AWS maps the hostname onto the endpoint inside their VPC. Neither side
# reconfigures its application.
#
# Verification is a TXT record AWS resolves over the public internet, so it
# belongs in the domain's public zone. A private hosted zone cannot satisfy it.
########################################################################

locals {
  private_dns_name_set = var.private_dns_name != null

  manage_private_dns_validation_record = local.private_dns_name_set && var.private_dns_validation_zone_id != null

  verify_private_dns_name = local.private_dns_name_set && coalesce(
    var.verify_private_dns_name,
    local.manage_private_dns_validation_record
  )
}

resource "aws_route53_record" "private_dns_validation" {
  count = local.manage_private_dns_validation_record ? 1 : 0

  zone_id = var.private_dns_validation_zone_id
  name    = aws_vpc_endpoint_service.this.private_dns_name_configuration[0].name
  type    = aws_vpc_endpoint_service.this.private_dns_name_configuration[0].type
  ttl     = 300
  records = [aws_vpc_endpoint_service.this.private_dns_name_configuration[0].value]
}

resource "aws_vpc_endpoint_service_private_dns_verification" "this" {
  count = local.verify_private_dns_name ? 1 : 0

  service_id            = aws_vpc_endpoint_service.this.id
  wait_for_verification = true

  timeouts {
    create = var.private_dns_verification_timeout
  }

  depends_on = [aws_route53_record.private_dns_validation]
}
