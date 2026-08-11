# Changelog

All notable changes to this module are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.2

### Added

- `private_dns_name` — associate the hostname consumers already use with the endpoint
  service. Without it the consumer can only address the endpoint's generated name, which
  no TLS certificate covers, so certificate validation has to be disabled to connect.
- `private_dns_validation_zone_id` — when the domain's **public** Route53 zone is in this
  account, the module creates the ownership-verification TXT record itself. AWS resolves
  that record over the public internet, so a private hosted zone cannot satisfy it.
- `verify_private_dns_name` — triggers AWS's domain ownership check during apply and waits
  for it, instead of leaving the service in `pendingVerification` until someone notices.
  Defaults to true when `private_dns_validation_zone_id` is set; set it explicitly once the
  record has been published by hand when DNS is hosted elsewhere.
- `private_dns_verification_timeout` — how long to wait for that check. Defaults to `30m`,
  matching the provider.
- `private_dns_verification_name`, `private_dns_verification_type`,
  `private_dns_verification_value` and `private_dns_verification_state` outputs, so the
  record can be published with any DNS provider and the result checked without the console.
- README section on adding a private DNS name to an endpoint service that already exists, which
  takes two applies. AWS mints no verification token until the name is on the service, and the
  provider reports the attribute as an empty list rather than as unknown, so the first plan fails
  on an empty lookup (hashicorp/terraform-provider-aws#24044). Setting the name at creation is
  unaffected and still applies in one go.
- README section covering the certificate problem private DNS solves, the public-zone
  requirement, both the Route53 and external-DNS paths, and the fact that ownership
  verification checks the domain and never the certificate — so `private_dns_name` must also
  appear in the SAN of whatever terminates TLS behind the NLB, and be the exact hostname the
  consumer dials. A mismatch verifies and resolves cleanly, then fails every handshake.

## 1.0.1

### Fixed

- The NLB security group no longer drops PrivateLink traffic by default.
  `nlb_ingress_cidrs` used to fall back to the provider's own VPC CIDR, which never matches:
  when inbound rules are enforced on PrivateLink traffic, the source evaluated is the
  private IP of the **consumer's client**, not the endpoint interface. The symptom was a
  black hole — endpoint `available`, connection accepted, target healthy, every connect
  timing out. `nlb_ingress_cidrs` now defaults to the Drata client CIDR
  (`10.0.0.0/16`, Drata prod `us-west-2`).

### Added

- `enforce_security_group_inbound_rules_on_private_link_traffic` — set to `"off"` when the
  Drata CIDR overlaps your own VPC, or when policy prevents allowing it. PrivateLink access
  then relies on `allowed_principals` + `acceptance_required`, which gate by identity rather
  than by address.
- `supported_regions` — makes the endpoint service available to consumers in other Regions.
  Requires the `vpce:AllowMultiRegion` IAM permission and at least two cross-Region-eligible
  Availability Zones.
- A plan-time warning when `subnet_ids` covers fewer than two Availability Zones.
- README guidance on choosing the Region that matches your Drata tenant, on enabling at
  least two Availability Zones, and on what cross-Region access actually requires.
- A precondition rejecting `enforce_security_group_inbound_rules_on_private_link_traffic =
  "on"` with an empty `nlb_ingress_cidrs`, which would otherwise drop every consumer at
  runtime rather than failing at plan time.

### Changed

- Minimum `aws` provider raised to `>= 5.100.0`, the version `supported_regions` was
  verified against.
- `nlb_security_group_id`, `nlb_ingress_cidrs` and the security group's ingress rule
  descriptions now say what they actually govern: traffic reaching the listener, not
  "PrivateLink consumer traffic".

## 1.0.0

- Initial provider-side PrivateLink module: target group, internal NLB and VPC endpoint
  service, referencing the target by instance ID and port.
