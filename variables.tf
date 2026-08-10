variable "name" {
  description = "Base name used to prefix all resources. Keep short: it seeds NLB/target-group names (32-char AWS limit)."
  type        = string
  default     = "drata-privatelink"

  validation {
    condition     = length(var.name) <= 24
    error_message = "name must be <= 24 chars so derived resource names stay under the 32-char AWS limit."
  }
}

variable "vpc_id" {
  description = "ID of the VPC that hosts the target service and where the internal NLB is provisioned."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs (one per AZ) the internal NLB attaches to, and the source of the Availability Zones the endpoint service advertises. Provide at least two, in different AZs: a single zone is a single point of failure for the consumer and is rejected outright for cross-Region access. The second subnet needs no registered target — enable_cross_zone_load_balancing covers that."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "Provide at least one subnet ID for the NLB."
  }
}

# ---------------------------------------------------------------------------
# Target: the privately-hosted service to expose (any internal HTTP/TCP service)
# ---------------------------------------------------------------------------
variable "target_instance_id" {
  description = "EC2 instance ID of the privately-hosted service to register as the NLB target."
  type        = string
}

variable "target_port" {
  description = "Port the target service listens on. The NLB forwards TCP to this port on the instance."
  type        = number
  default     = 443
}

# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
variable "health_check_protocol" {
  description = "Health check protocol for the target group. TCP is the safe default; use HTTP/HTTPS to probe an application health path."
  type        = string
  default     = "TCP"

  validation {
    condition     = contains(["TCP", "HTTP", "HTTPS"], var.health_check_protocol)
    error_message = "health_check_protocol must be one of TCP, HTTP, HTTPS."
  }
}

variable "health_check_path" {
  description = "Health check path, only used when health_check_protocol is HTTP/HTTPS (e.g. /healthz)."
  type        = string
  default     = "/"
}

# ---------------------------------------------------------------------------
# Network load balancer
# ---------------------------------------------------------------------------
variable "listener_port" {
  description = "TCP port the NLB listens on. Consumers reach the service on this port via the interface endpoint."
  type        = number
  default     = 443
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing on the NLB. Recommended when the target instance is in a single AZ."
  type        = bool
  default     = true
}

variable "nlb_ingress_cidrs" {
  description = "CIDR blocks allowed inbound to the NLB listener. Must admit the Drata CIDR for the region serving your tenant, since with enforcement on the security group matches the connecting client's private IP: us-west-2 10.0.0.0/16 (default), eu-central-1 10.2.0.0/16, ap-southeast-2 10.10.0.0/16. Confirm which applies with Drata. Append your own CIDRs if anything in your VPC reaches the listener directly."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enforce_security_group_inbound_rules_on_private_link_traffic" {
  description = "Whether the NLB security group's inbound rules are evaluated against traffic arriving over PrivateLink (\"on\", the AWS default and the default here) or bypassed for it (\"off\"). Set this to \"off\" if the Drata CIDR in nlb_ingress_cidrs overlaps your VPC, or if you cannot allow that range: security group rules match addresses rather than identities, so an overlapping range cannot distinguish Drata's traffic from your own hosts, and AWS warns PrivateLink traffic \"can originate from overlapping IP addresses\". With \"off\", PrivateLink access is gated solely by allowed_principals plus acceptance_required, and the security group governs only direct in-VPC traffic."
  type        = string
  default     = "on"

  validation {
    condition     = contains(["on", "off"], var.enforce_security_group_inbound_rules_on_private_link_traffic)
    error_message = "enforce_security_group_inbound_rules_on_private_link_traffic must be \"on\" or \"off\"."
  }
}

# ---------------------------------------------------------------------------
# VPC Endpoint Service (PrivateLink provider side)
# ---------------------------------------------------------------------------
variable "acceptance_required" {
  description = "Require manual acceptance of endpoint connection requests. Keep true so you explicitly approve each consumer."
  type        = bool
  default     = true
}

variable "allowed_principals" {
  description = "IAM principal ARNs allowed to discover the endpoint service and create an interface endpoint to it. Set to the connecting account root, e.g. Drata prod: arn:aws:iam::269135526815:root. This gates connection creation only, not the data path — each connection is still gated by acceptance_required."
  type        = list(string)
  default     = ["arn:aws:iam::269135526815:root"]
}

variable "supported_regions" {
  description = "Regions this endpoint service is available in, beyond the Region hosting it, for consumers using cross-Region access. Leave empty for the normal same-Region case. Setting this requires the vpce:AllowMultiRegion IAM permission, and the service must be enabled in at least two cross-Region-eligible Availability Zones or AWS rejects the change. The host Region is always supported and cannot be removed."
  type        = list(string)
  default     = []
}

variable "supported_ip_address_types" {
  description = "IP address types the endpoint service supports."
  type        = list(string)
  default     = ["ipv4"]
}

# ---------------------------------------------------------------------------
# Private DNS name (optional)
# ---------------------------------------------------------------------------
variable "private_dns_name" {
  description = "Hostname consumers already use to reach this service, e.g. gitlab.example.com. Associating it with the endpoint service lets the consumer enable private DNS, after which the name resolves to the endpoint inside their VPC and their existing TLS certificate keeps matching — without it they can only use the endpoint's generated name, which no certificate covers. AWS will not serve the name until you have proved you own the domain. Leave null to skip private DNS entirely."
  type        = string
  default     = null
}

variable "private_dns_validation_zone_id" {
  description = "Route53 zone ID of the PUBLIC hosted zone authoritative for private_dns_name, when that zone is in this AWS account. The module then creates the ownership-verification TXT record for you. AWS resolves that record over the public internet, so a private hosted zone cannot satisfy it. Leave null if your DNS is hosted anywhere else — publish the record yourself from the private_dns_verification_* outputs."
  type        = string
  default     = null

  validation {
    condition     = var.private_dns_validation_zone_id == null || var.private_dns_name != null
    error_message = "private_dns_name must be set when private_dns_validation_zone_id is provided."
  }
}

variable "verify_private_dns_name" {
  description = "Whether to have AWS verify domain ownership during apply. Defaults to true when private_dns_validation_zone_id is set, since the TXT record is then created here. If your DNS is hosted elsewhere, leave this null for the first apply, publish the record from the outputs, then set it to true — verification fails while the record is not publicly resolvable."
  type        = bool
  default     = null
}

variable "private_dns_verification_timeout" {
  description = "How long to wait for AWS to observe the verification TXT record before failing the apply. Public DNS usually propagates in well under a minute, but some providers are slower."
  type        = string
  default     = "10m"
}

variable "tags" {
  description = "Tags applied to all created resources."
  type        = map(string)
  default     = {}
}
