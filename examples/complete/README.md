# Complete example

Stands up the full provider-side PrivateLink stack (target group → internal NLB
→ endpoint service) against an **existing** EC2 instance you supply. The
instance itself is not created here — the module only references it by id.

This example exercises the optional knobs (health check, listener port, cross-zone
balancing, NLB ingress CIDRs, supported IP address types, private DNS name) in addition
to the required inputs.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: vpc_id, subnet_ids, target_instance_id, ...
terraform init
terraform apply
```

## Private DNS

Optional, and left off by default. Setting `private_dns_name` lets the consumer keep using
your existing hostname, so your TLS certificate still matches — see
[Private DNS name](../../README.md#private-dns-name) for why that matters.

AWS verifies you own the domain with a TXT record it resolves over the **public** internet.

If the domain's public zone is in this account, set `private_dns_validation_zone_id` and the
module handles the record and the verification in one apply.

If your DNS is hosted anywhere else, it takes two applies:

```bash
# 1. apply with private_dns_name set and no zone id
terraform output private_dns_verification_name    # -> _abc123
terraform output private_dns_verification_value   # -> vpce:XXXXXXXX

# 2. publish _abc123.example.com TXT "vpce:XXXXXXXX" with your DNS provider,
#    then set verify_private_dns_name = true and apply again
```

`private_dns_verification_timeout` (default `30m`) bounds how long the second apply waits
for AWS to see the record.

The target instance's security group must allow ingress on `target_port` from
the SG exposed by the `nlb_security_group_id` output — the module does not
modify the target's SG.
