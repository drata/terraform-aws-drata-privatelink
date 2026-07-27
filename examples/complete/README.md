# Complete example

Stands up the full provider-side PrivateLink stack (target group → internal NLB
→ endpoint service) against an **existing** EC2 instance you supply. The
instance itself is not created here — the module only references it by id.

This example exercises every optional knob (health check, listener port,
cross-zone balancing, NLB ingress CIDRs, supported IP address types) in addition
to the required inputs.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: vpc_id, subnet_ids, target_instance_id, ...
terraform init
terraform apply
```

The target instance's security group must allow ingress on `target_port` from
the SG exposed by the `nlb_security_group_id` output — the module does not
modify the target's SG.
