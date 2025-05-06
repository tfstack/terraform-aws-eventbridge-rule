############################################
# Outputs
############################################

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group (if created)"
  value = var.logging != null ? coalesce(
    try(aws_cloudwatch_log_group.this_with_prevent_destroy[0].arn, null),
    try(aws_cloudwatch_log_group.this_without_prevent_destroy[0].arn, null)
  ) : null
}

output "logging_role_arn" {
  description = "IAM Role used for delivery logging (if created)"
  value = (
    var.logging != null && var.logging.iam_role_arn == null
    ? try(aws_iam_role.logging[0].arn, null)
    : var.logging != null ? var.logging.iam_role_arn : null
  )
}

output "rule_arn" {
  description = "ARN of the created EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.arn
}

output "target_ids" {
  description = "List of target IDs"
  value       = aws_cloudwatch_event_target.this[*].target_id
}
