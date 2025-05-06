############################################
# CloudWatch Event Rule
############################################

resource "aws_cloudwatch_event_rule" "this" {
  name                = var.rule_name
  description         = var.description
  event_bus_name      = var.event_bus_name
  event_pattern       = var.event_pattern
  schedule_expression = var.schedule_expression
  state               = var.enabled ? "ENABLED" : "DISABLED"

  tags = var.tags
}

############################################
# Target Service Detection (ARN prefix)
############################################

locals {
  target_service_actions = {
    sns         = "sns:Publish"
    sqs         = "sqs:SendMessage"
    states      = "states:StartExecution"
    kinesis     = "kinesis:PutRecord"
    events      = "events:PutEvents"
    ecs         = "ecs:RunTask"
    codebuild   = "codebuild:StartBuild"
    ssm         = "ssm:SendCommand"
    execute-api = "execute-api:Invoke"
    appflow     = "appflow:StartFlow"
  }

  target_services = {
    for idx, t in var.targets :
    idx => try(regex("^arn:aws:([^:]+):", t.arn)[0], null)
  }

  target_actions = {
    for idx, svc in local.target_services :
    idx => lookup(local.target_service_actions, svc, null)
  }
}

############################################
# IAM Roles for Targets
############################################

resource "aws_iam_role" "target" {
  for_each = {
    for idx, t in var.targets :
    tostring(idx) => t if try(t.create_role, false)
  }

  name = "${var.rule_name}-target-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "events.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "target" {
  for_each = aws_iam_role.target

  name = "${var.rule_name}-target-${each.key}-policy"
  role = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = local.target_actions[each.key]
        Resource = var.targets[tonumber(each.key)].arn
      }
    ]
  })
}

############################################
# CloudWatch Event Targets
############################################

resource "aws_cloudwatch_event_target" "this" {
  count = length(var.targets)

  arn            = var.targets[count.index].arn
  event_bus_name = var.event_bus_name
  input          = lookup(var.targets[count.index], "input", null)
  rule           = aws_cloudwatch_event_rule.this.name
  target_id      = "target-${count.index}"
  role_arn = (
    contains(keys(aws_iam_role.target), tostring(count.index))
    ? aws_iam_role.target[tostring(count.index)].arn
    : lookup(var.targets[count.index], "role_arn", null)
  )

  dead_letter_config {
    arn = lookup(var.targets[count.index], "dlq_arn", null)
  }

  dynamic "input_transformer" {
    for_each = lookup(var.targets[count.index], "input_transformer", null) != null ? [1] : []
    content {
      input_paths    = var.targets[count.index].input_transformer.input_paths
      input_template = var.targets[count.index].input_transformer.input_template
    }
  }

  dynamic "retry_policy" {
    for_each = lookup(var.targets[count.index], "retry_policy", null) != null ? [1] : []
    content {
      maximum_event_age_in_seconds = var.targets[count.index].retry_policy.maximum_event_age_in_seconds
      maximum_retry_attempts       = var.targets[count.index].retry_policy.maximum_retry_attempts
    }
  }
}

############################################
# CloudWatch Log Group
############################################

resource "aws_cloudwatch_log_group" "this_with_prevent_destroy" {
  count = var.logging != null && try(var.logging.prevent_destroy, true) ? 1 : 0

  name              = var.logging.log_group_name
  retention_in_days = try(var.logging.retention_days, 30)

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this_without_prevent_destroy" {
  count = var.logging != null && !try(var.logging.prevent_destroy, true) ? 1 : 0

  name              = var.logging.log_group_name
  retention_in_days = try(var.logging.retention_days, 30)

  lifecycle {
    prevent_destroy = false
  }

  tags = var.tags
}

############################################
# IAM Role for Logging
############################################

resource "aws_iam_role" "logging" {
  count = var.logging != null && var.logging.iam_role_arn == null ? 1 : 0

  name = "${var.rule_name}-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "logging" {
  count = var.logging != null && var.logging.iam_role_arn == null ? 1 : 0

  name = "${var.rule_name}-logging-policy"
  role = aws_iam_role.logging[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow",
        Resource = "${coalesce(
          try(aws_cloudwatch_log_group.this_with_prevent_destroy[0].arn, null),
          try(aws_cloudwatch_log_group.this_without_prevent_destroy[0].arn, null)
        )}:*"
      }
    ]
  })
}
