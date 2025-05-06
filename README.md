# terraform-aws-eventbridge-rule

Terraform module to create flexible AWS EventBridge rules

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.this_with_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.this_without_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Optional description for the rule | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the rule is enabled | `bool` | `true` | no |
| <a name="input_event_bus_name"></a> [event\_bus\_name](#input\_event\_bus\_name) | Name of the EventBridge bus (default is 'default') | `string` | `"default"` | no |
| <a name="input_event_pattern"></a> [event\_pattern](#input\_event\_pattern) | Event pattern in JSON format (conflicts with schedule\_expression) | `string` | `null` | no |
| <a name="input_logging"></a> [logging](#input\_logging) | Optional CloudWatch logging configuration for EventBridge rule | <pre>object({<br/>    log_group_name  = string<br/>    iam_role_arn    = optional(string)<br/>    prevent_destroy = optional(bool, true)<br/>    retention_days  = optional(number, 30)<br/>  })</pre> | `null` | no |
| <a name="input_rule_name"></a> [rule\_name](#input\_rule\_name) | Name of the EventBridge rule | `string` | n/a | yes |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | rate(...) or cron(...) expression (conflicts with event\_pattern) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_targets"></a> [targets](#input\_targets) | List of EventBridge targets with optional IAM role config and per-target settings | <pre>list(object({<br/>    arn         = string<br/>    create_role = optional(bool, false)<br/>    role_arn    = optional(string)<br/>    input       = optional(string)<br/>    dlq_arn     = optional(string)<br/>    input_transformer = optional(object({<br/>      input_paths    = map(string)<br/>      input_template = string<br/>    }))<br/>    retry_policy = optional(object({<br/>      maximum_retry_attempts       = number<br/>      maximum_event_age_in_seconds = number<br/>    }))<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN of the CloudWatch Log Group (if created) |
| <a name="output_logging_role_arn"></a> [logging\_role\_arn](#output\_logging\_role\_arn) | IAM Role used for delivery logging (if created) |
| <a name="output_rule_arn"></a> [rule\_arn](#output\_rule\_arn) | ARN of the created EventBridge rule |
| <a name="output_target_ids"></a> [target\_ids](#output\_target\_ids) | List of target IDs |
<!-- END_TF_DOCS -->
