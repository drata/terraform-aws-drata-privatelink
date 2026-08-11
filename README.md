# terraform-aws-drata-privatelink

Terraform module that exposes a **privately-hosted service** — any internal
HTTP/TCP endpoint reachable on an EC2 instance — to a consumer over **AWS
PrivateLink**, with no public network path. This is the **provider (service)
side** of a PrivateLink connection, and is agnostic to what the target service
actually is.

```
target EC2 ──▶ Target Group ──▶ NLB (internal) ──▶ VPC Endpoint Service
  (:443)         (TCP :443)       (TCP :443)         allowed_principals = [consumer ARN]
                                                     └▶ output: service_name (vpce-svc-…)
```

The consumer (e.g. Drata Autopilot) takes the `service_name` output and creates
an **interface VPC endpoint** on their side; with `acceptance_required = true`
you approve each connection request explicitly.

> The module is deliberately target-agnostic — it references the target only by
> instance id and port, so it works for any service you need to reach privately.

## Region

Deploy in the Region serving your Drata tenant, and allow that Region's CIDR in
`nlb_ingress_cidrs`. Ask Drata which applies:

| Drata Region | Drata CIDR |
| --- | --- |
| `us-west-2` | `10.0.0.0/16` (default) |
| `eu-central-1` | `10.2.0.0/16` |
| `ap-southeast-2` | `10.10.0.0/16` |

If your service must stay in a different Region, set `supported_regions = ["<drata-region>"]`
to enable cross-Region access. That needs the `vpce:AllowMultiRegion` IAM permission and at
least two Availability Zones.

## Availability Zones

Pass at least two `subnet_ids`, in different AZs. The second needs no target —
`enable_cross_zone_load_balancing` (default `true`) reaches the instance in the other zone.
One zone is rejected for cross-Region access, and the module warns at plan time.

## Usage

```hcl
module "privatelink" {
  source = "github.com/drata/terraform-aws-drata-privatelink"

  name   = "myservice-privatelink"
  vpc_id = "vpc-0123456789abcdef0"

  # At least two subnets, each in a different AZ. The second needs no target.
  subnet_ids = ["subnet-aaaa", "subnet-bbbb"]

  target_instance_id = "i-0123456789abcdef0"
  target_port        = 443

  # Drata's connecting account root — who may create the interface endpoint.
  # Defaults to this if omitted; acceptance_required still gates each connection.
  allowed_principals = ["arn:aws:iam::269135526815:root"]

  tags = { Project = "privatelink" }
}

output "privatelink_service_name" {
  value = module.privatelink.service_name
}
```

A runnable example lives in [`examples/complete`](./examples/complete).

## Handoff flow

1. Consumer provides their principal ARN → set `allowed_principals`.
2. `terraform apply` → produces `service_name`.
3. Give `service_name` to the consumer; they create their interface endpoint.
4. Approve the pending endpoint connection (Console/CLI) unless `acceptance_required = false`.
5. Consumer connects — on the endpoint's generated name, or on your own hostname if you
   set up a [private DNS name](#private-dns-name).

## Private DNS name

Optional, and worth doing.

Without it, the consumer's only address is the endpoint's generated regional name:

```
vpce-0123456789abcdef0-a1b2c3d4.vpce-svc-0123456789abcdef0.eu-west-1.vpce.amazonaws.com
```

PrivateLink does not terminate TLS. The certificate served on that connection is yours, and
its SAN lists your real hostname, not the `vpce` name — so any client doing normal certificate
validation fails, and the connection only works with verification disabled.

Setting `private_dns_name` to the hostname consumers already use removes that. Once AWS has
verified you own the domain, the consumer enables private DNS on their endpoint and AWS maps
the hostname to it inside their VPC. Your certificate matches, and neither side changes any
application configuration.

**Verification is public.** AWS proves ownership by resolving a TXT record on the public
internet. A private hosted zone cannot satisfy it.

**The name must match your certificate.** AWS verifies that you own the *domain*. It never
looks at your TLS certificate, and nothing reconciles the two. This module gives the NLB a TCP
listener, so the certificate the consumer validates is the one your own service presents.
(Swap that for a TLS listener later and it becomes the load balancer's ACM certificate instead.)

So `private_dns_name` must be listed in that certificate's subject alternative names, and must
be the exact hostname the consumer's client is configured to dial. If they differ, verification
still succeeds and the name still resolves — and every handshake then fails on a name mismatch,
at connect time rather than at apply time. Check before you set it, from a host that can reach
the service — inside your VPC if it has no public endpoint — on whatever port it serves TLS:

```console
$ openssl s_client -connect <your-service>:<port> -servername <private_dns_name> </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -text | grep -A1 "Subject Alternative Name"
```

If your certificate is issued by a private CA, the consumer additionally needs that CA in the
trust store of whatever calls you — tell them, since nothing in this module can.

**Public zone in this account** — pass its ID and the module does the rest:

```hcl
private_dns_name               = "gitlab.example.com"
private_dns_validation_zone_id = "Z0123456789ABCDEFGHIJ"
```

The module writes the TXT record and waits for AWS to verify it before the apply completes.

**DNS hosted anywhere else** — apply once with only `private_dns_name`, then publish the
record with your provider:

```console
$ terraform output private_dns_verification_name
"_6e86v84tqgqubxbwii1m"
$ terraform output private_dns_verification_value
"vpce:l6p0ERxlTt45jevFwOCp"
```

| Name | Type | Value |
|---|---|---|
| `_6e86v84tqgqubxbwii1m.example.com` | TXT | `vpce:l6p0ERxlTt45jevFwOCp` |

`<domain>` is `private_dns_name` or any parent of it — verifying `example.com` also covers
`gitlab.example.com`. Once it resolves publicly, set `verify_private_dns_name = true` and
apply again.

Notes:

- An endpoint service carries only one private DNS name.
- `private_dns_verification_state` is read before verification runs, so the apply that
  verifies the domain still prints `pendingVerification`. Re-run `terraform plan` (or
  `terraform refresh`) to see it settle to `verified`.
- `private_dns_name` must be lowercase. AWS normalises it, and a mixed-case value would
  show up as a permanent diff.
- Changing `private_dns_name` later re-runs verification for the new name — expect the
  apply to wait again. If that apply times out, re-apply: the record may need a refresh
  before AWS will accept it.
- If the verification record already exists in the zone — because you published it by hand
  first, or another copy of this module shares the domain — the record creation fails.
  Remove the hand-made record before setting `private_dns_validation_zone_id`, or keep
  both values on one TXT record and leave the zone id unset.
- Beyond the usual EC2 and ELB permissions, this needs
  `ec2:ModifyVpcEndpointServiceConfiguration` and
  `ec2:StartVpcEndpointServicePrivateDnsVerification`, plus — only when
  `private_dns_validation_zone_id` is set — `route53:GetHostedZone`,
  `route53:ListTagsForResource`, `route53:ListResourceRecordSets`,
  `route53:ChangeResourceRecordSets` and `route53:GetChange`. The zone must be in this
  same account.
- The zone passed as `private_dns_validation_zone_id` is read back and checked: a private
  hosted zone, or one not authoritative for `private_dns_name`, fails at plan time rather
  than timing out half an hour into the apply.
- If verification later lapses, existing connections survive but new ones are refused.
- Some providers lowercase TXT values or append the domain to the record name; both break
  verification. If your provider rejects underscores in record names, omit the
  `_6e86v84tqgqubxbwii1m` label and put the value on the bare domain instead.

## Prerequisites & notes

- **Target instance security group** must allow ingress on `target_port` from
  the module's NLB security group (`nlb_security_group_id` output). The module
  does not modify the target instance's SG.
- **`nlb_ingress_cidrs` must admit the Drata CIDR** — with enforcement `"on"` (the
  default) the security group matches the *client's* private IP, not the endpoint
  interface, so the range that matters is Drata's, not yours. See [Region](#region).
- **Set `enforce_security_group_inbound_rules_on_private_link_traffic = "off"`** if that
  CIDR overlaps your VPC, or you cannot allow it. PrivateLink is then gated by
  `allowed_principals` + `acceptance_required`, and the security group governs only
  direct in-VPC traffic.
- **If a consumer cannot connect while enforcement is `"on"`**, check the NLB's
  `SecurityGroupBlockedFlowCount_Inbound` metric first — a security group drop looks
  identical to a data-plane fault from the consumer's side ([docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-security-groups.html)).
- **Subnets** — one per AZ, at least two, each able to route to the target. See
  [Availability Zones](#availability-zones).
- **`allowed_principals`** may start empty — provision the service first, then
  add the consumer ARN and re-apply.
- Health check defaults to **TCP** on the traffic port. Switch to `HTTP`/`HTTPS`
  with `health_check_path` for an application-level probe.
- Every `destroy`/re-`apply` mints a **new `service_name`** — treat the endpoint
  service as long-lived once shared.

## Inputs & outputs

<!-- The block below is generated by terraform-docs and kept in sync by the
     documentation-generator workflow. Do not edit by hand. -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.5.0 |
| aws | >= 5.100.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_route53_record.private_dns_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service) | resource |
| [aws_vpc_endpoint_service_private_dns_verification.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service_private_dns_verification) | resource |
| [aws_vpc_security_group_egress_rule.nlb_to_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_route53_zone.private_dns_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| subnet\_ids | Subnet IDs (one per AZ) the internal NLB attaches to, and the source of the Availability Zones the endpoint service advertises. Provide at least two, in different AZs: a single zone is a single point of failure for the consumer and is rejected outright for cross-Region access. The second subnet needs no registered target — enable\_cross\_zone\_load\_balancing covers that. | `list(string)` | n/a | yes |
| target\_instance\_id | EC2 instance ID of the privately-hosted service to register as the NLB target. | `string` | n/a | yes |
| vpc\_id | ID of the VPC that hosts the target service and where the internal NLB is provisioned. | `string` | n/a | yes |
| acceptance\_required | Require manual acceptance of endpoint connection requests. Keep true so you explicitly approve each consumer. | `bool` | `true` | no |
| allowed\_principals | IAM principal ARNs allowed to discover the endpoint service and create an interface endpoint to it. Set to the connecting account root, e.g. Drata prod: arn:aws:iam::269135526815:root. This gates connection creation only, not the data path — each connection is still gated by acceptance\_required. | `list(string)` | <pre>[<br/>  "arn:aws:iam::269135526815:root"<br/>]</pre> | no |
| enable\_cross\_zone\_load\_balancing | Enable cross-zone load balancing on the NLB. Recommended when the target instance is in a single AZ. | `bool` | `true` | no |
| enforce\_security\_group\_inbound\_rules\_on\_private\_link\_traffic | Whether the NLB security group's inbound rules are evaluated against traffic arriving over PrivateLink ("on", the AWS default and the default here) or bypassed for it ("off"). Set this to "off" if the Drata CIDR in nlb\_ingress\_cidrs overlaps your VPC, or if you cannot allow that range: security group rules match addresses rather than identities, so an overlapping range cannot distinguish Drata's traffic from your own hosts, and AWS warns PrivateLink traffic "can originate from overlapping IP addresses". With "off", PrivateLink access is gated solely by allowed\_principals plus acceptance\_required, and the security group governs only direct in-VPC traffic. | `string` | `"on"` | no |
| health\_check\_path | Health check path, only used when health\_check\_protocol is HTTP/HTTPS (e.g. /healthz). | `string` | `"/"` | no |
| health\_check\_protocol | Health check protocol for the target group. TCP is the safe default; use HTTP/HTTPS to probe an application health path. | `string` | `"TCP"` | no |
| listener\_port | TCP port the NLB listens on. Consumers reach the service on this port via the interface endpoint. | `number` | `443` | no |
| name | Base name used to prefix all resources. Keep short: it seeds NLB/target-group names (32-char AWS limit). | `string` | `"drata-privatelink"` | no |
| nlb\_ingress\_cidrs | CIDR blocks allowed inbound to the NLB listener. Must admit the Drata CIDR for the region serving your tenant, since with enforcement on the security group matches the connecting client's private IP: us-west-2 10.0.0.0/16 (default), eu-central-1 10.2.0.0/16, ap-southeast-2 10.10.0.0/16. Confirm which applies with Drata. Append your own CIDRs if anything in your VPC reaches the listener directly. | `list(string)` | <pre>[<br/>  "10.0.0.0/16"<br/>]</pre> | no |
| private\_dns\_name | Hostname consumers already use to reach this service, e.g. gitlab.example.com. Associating it with the endpoint service lets the consumer enable private DNS, after which the name resolves to the endpoint inside their VPC and their existing TLS certificate keeps matching — without it they can only use the endpoint's generated name, which no certificate covers. AWS will not serve the name until you have proved you own the domain. It proves ownership of the domain only, and never checks your certificate: this name must also appear in the subject alternative names of whatever terminates TLS behind your NLB, and must be the exact hostname the consumer dials, or every handshake fails on a name mismatch long after the apply succeeds. Leave null to skip private DNS entirely. | `string` | `null` | no |
| private\_dns\_validation\_zone\_id | Route53 zone ID of the PUBLIC hosted zone authoritative for private\_dns\_name, when that zone is in this AWS account. The module then creates the ownership-verification TXT record for you. AWS resolves that record over the public internet, so a private hosted zone cannot satisfy it. Leave null if your DNS is hosted anywhere else — publish the record yourself from the private\_dns\_verification\_* outputs. | `string` | `null` | no |
| private\_dns\_verification\_timeout | How long to wait for AWS to detect the verification TXT record before failing the apply. AWS may take up to 48 hours to pick a record up, though in practice it is minutes. Matches the provider default. | `string` | `"30m"` | no |
| supported\_ip\_address\_types | IP address types the endpoint service supports. | `list(string)` | <pre>[<br/>  "ipv4"<br/>]</pre> | no |
| supported\_regions | Regions this endpoint service is available in, beyond the Region hosting it, for consumers using cross-Region access. Leave empty for the normal same-Region case. Setting this requires the vpce:AllowMultiRegion IAM permission, and the service must be enabled in at least two cross-Region-eligible Availability Zones or AWS rejects the change. The host Region is always supported and cannot be removed. | `list(string)` | `[]` | no |
| tags | Tags applied to all created resources. | `map(string)` | `{}` | no |
| target\_port | Port the target service listens on. The NLB forwards TCP to this port on the instance. | `number` | `443` | no |
| verify\_private\_dns\_name | Whether to have AWS verify domain ownership during apply. Defaults to true when private\_dns\_validation\_zone\_id is set, since the TXT record is then created here. If your DNS is hosted elsewhere, leave this null for the first apply, publish the record from the outputs, then set it to true — verification fails while the record is not publicly resolvable. | `bool` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| nlb\_arn | ARN of the internal network load balancer. |
| nlb\_dns\_name | Internal DNS name of the NLB (for provider-side validation only). |
| nlb\_security\_group\_id | Security group ID attached to the NLB. The target instance's SG must allow ingress from this SG on the target port. |
| private\_dns\_verification\_name | Name label of the domain ownership verification TXT record, null when private\_dns\_name is not set. Publish it as <name>.<domain>, where <domain> is private\_dns\_name or any parent of it — verifying example.com also covers gitlab.example.com. |
| private\_dns\_verification\_state | Verification state as of the last read: pendingVerification, verified or failed. Consumers cannot enable private DNS until this reads verified. Note the lag — the value is captured before verification runs, so the apply that actually verifies the domain still prints pendingVerification. Re-run plan or refresh to see it settle. |
| private\_dns\_verification\_type | Record type of the ownership verification record. Always TXT. |
| private\_dns\_verification\_value | Value of the ownership verification TXT record. |
| service\_availability\_zones | AZs the endpoint service is available in. The consumer's subnets must overlap these. |
| service\_id | The VPC endpoint service ID (vpce-svc-xxxx). |
| service\_name | The endpoint service name (com.amazonaws.vpce.<region>.vpce-svc-xxxx). Hand this to the consumer to create their interface endpoint. |
| service\_state | Lifecycle state of the endpoint service (e.g. Available). |
| target\_group\_arn | ARN of the target group. |
<!-- END_TF_DOCS -->

## License

Apache-2.0 (see [LICENSE](./LICENSE)).
