# Changelog

All notable changes to this module are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
