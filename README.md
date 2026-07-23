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

> Origin: Drata OCTO-1793 ("TF | Network Level Private Endpoint"). The module is
> deliberately target-agnostic — it references the target only by instance id and
> port, so it works for any service you need to reach privately.

## Usage

```hcl
module "privatelink" {
  source = "github.com/drata/terraform-aws-drata-privatelink"

  name       = "myservice-privatelink"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-aaaa", "subnet-bbbb"] # one per AZ, must reach the target

  target_instance_id = "i-0123456789abcdef0"
  target_port        = 443

  # Fill in once the consumer provides their principal ARN.
  allowed_principals = ["arn:aws:iam::<consumer-account-id>:role/<autopilot-role>"]

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
5. Consumer reads the generated private DNS record and connects.

## Prerequisites & notes

- **Target instance security group** must allow ingress on `target_port` from
  the module's NLB security group (`nlb_security_group_id` output). The module
  does not modify the target instance's SG.
- **Subnets** should be one per AZ and able to route to the target;
  `enable_cross_zone_load_balancing = true` (default) covers a single-AZ target.
- **`allowed_principals`** may start empty — provision the service first, then
  add the consumer ARN and re-apply.
- Health check defaults to **TCP** on the traffic port. Switch to `HTTP`/`HTTPS`
  with `health_check_path` for an application-level probe.
- Every `destroy`/re-`apply` mints a **new `service_name`** — treat the endpoint
  service as long-lived once shared.

<!-- BEGIN inputs/outputs — keep in sync (or generate with terraform-docs) -->

## Inputs (key)

| Name                  | Description                               | Default             |
| --------------------- | ----------------------------------------- | ------------------- |
| `vpc_id`              | VPC hosting the target + NLB              | — (required)        |
| `subnet_ids`          | Subnets (one per AZ) for the internal NLB | — (required)        |
| `target_instance_id`  | EC2 instance ID of the service to expose  | — (required)        |
| `target_port`         | Port the service listens on               | `443`               |
| `listener_port`       | NLB listener port consumers connect to    | `443`               |
| `acceptance_required` | Require manual approval of connections    | `true`              |
| `allowed_principals`  | Consumer IAM principal ARNs               | `[]`                |
| `name`                | Resource name prefix (≤24 chars)          | `drata-privatelink` |

## Outputs (key)

| Name                           | Description                                    |
| ------------------------------ | ---------------------------------------------- |
| `service_name`                 | Endpoint service name to hand to the consumer  |
| `service_id`                   | `vpce-svc-…` id                                |
| `nlb_security_group_id`        | SG the target instance must allow ingress from |
| `target_group_arn` / `nlb_arn` | Provider-side ARNs                             |

<!-- END inputs/outputs -->

## License

Apache-2.0 (see [LICENSE](./LICENSE)).
