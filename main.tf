########################################################################
# terraform-aws-drata-privatelink
#
# Exposes a privately-hosted service (any internal HTTP/TCP endpoint on an EC2
# instance) over AWS PrivateLink so a consumer (e.g. Drata Autopilot) can reach
# it without any public network path:
#
#   target EC2 ──▶ Target Group ──▶ NLB (internal) ──▶ VPC Endpoint Service
#
# The endpoint service name (output: service_name) is handed to the consumer,
# who creates the interface VPC endpoint on their side.
########################################################################

locals {
  common_tags = merge({
    ManagedBy = "terraform"
    Module    = "terraform-aws-drata-privatelink"
  }, var.tags)
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# ---------------------------------------------------------------------------
# Security group for the internal NLB
# ---------------------------------------------------------------------------
resource "aws_security_group" "nlb" {
  name        = "${var.name}-nlb-sg"
  description = "Ingress to the PrivateLink NLB listener; egress to the target instance."
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-nlb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "nlb_listener" {
  for_each = toset(var.nlb_ingress_cidrs)

  security_group_id = aws_security_group.nlb.id
  description       = "Allow client traffic to the NLB listener"
  cidr_ipv4         = each.value
  from_port         = var.listener_port
  to_port           = var.listener_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_target" {
  security_group_id = aws_security_group.nlb.id
  description       = "Allow the NLB to reach the target instance"
  cidr_ipv4         = data.aws_vpc.this.cidr_block
  from_port         = var.target_port
  to_port           = var.target_port
  ip_protocol       = "tcp"
}

# ---------------------------------------------------------------------------
# Target group: the privately-hosted service instance
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = var.health_check_protocol
    port                = "traffic-port"
    path                = contains(["HTTP", "HTTPS"], var.health_check_protocol) ? var.health_check_path : null
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(local.common_tags, { Name = "${var.name}-tg" })
}

resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_id
  port             = var.target_port
}

# ---------------------------------------------------------------------------
# Internal network load balancer
# ---------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "${var.name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  enforce_security_group_inbound_rules_on_private_link_traffic = var.enforce_security_group_inbound_rules_on_private_link_traffic

  tags = merge(local.common_tags, { Name = "${var.name}-nlb" })

  lifecycle {
    precondition {
      condition     = var.enforce_security_group_inbound_rules_on_private_link_traffic == "off" || length(var.nlb_ingress_cidrs) > 0
      error_message = "enforce_security_group_inbound_rules_on_private_link_traffic = \"on\" with an empty nlb_ingress_cidrs drops all PrivateLink traffic. List the Drata CIDR (see the variable description), or set enforcement to \"off\"."
    }
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# VPC endpoint service (PrivateLink provider side)
# ---------------------------------------------------------------------------
resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = var.acceptance_required
  network_load_balancer_arns = [aws_lb.this.arn]
  allowed_principals         = var.allowed_principals
  supported_ip_address_types = var.supported_ip_address_types
  supported_regions          = length(var.supported_regions) > 0 ? var.supported_regions : null

  tags = merge(local.common_tags, { Name = "${var.name}-endpoint-service" })
}

# Warning, not an error: one Availability Zone is a single point of failure for the
# consumer, and cross-Region access is rejected outright below two.
check "availability_zones" {
  assert {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids covers a single Availability Zone. Add a subnet in another AZ — it needs no registered target, since enable_cross_zone_load_balancing routes to the existing one. Required for cross-Region access, recommended otherwise."
  }
}
