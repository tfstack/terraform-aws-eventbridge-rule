############################################
# Variables
############################################

variable "description" {
  description = "Optional description for the rule"
  type        = string
  default     = null
}

variable "enabled" {
  description = "Whether the rule is enabled"
  type        = bool
  default     = true
}

variable "event_bus_name" {
  description = "Name of the EventBridge bus (default is 'default')"
  type        = string
  default     = "default"
}

variable "event_pattern" {
  description = "Event pattern in JSON format (conflicts with schedule_expression)"
  type        = string
  default     = null
}

variable "logging" {
  description = "Optional CloudWatch logging configuration for EventBridge rule"
  type = object({
    log_group_name  = string
    iam_role_arn    = optional(string)
    prevent_destroy = optional(bool, true)
    retention_days  = optional(number, 30)
  })
  default = null
}

variable "rule_name" {
  description = "Name of the EventBridge rule"
  type        = string
}

variable "schedule_expression" {
  description = "rate(...) or cron(...) expression (conflicts with event_pattern)"
  type        = string
  default     = null

  validation {
    condition     = !(var.schedule_expression != null && var.event_pattern != null)
    error_message = "Only one of 'schedule_expression' or 'event_pattern' can be specified."
  }
}

variable "targets" {
  description = "List of EventBridge targets with optional IAM role config and per-target settings"
  type = list(object({
    arn         = string
    create_role = optional(bool, false)
    role_arn    = optional(string)
    input       = optional(string)
    dlq_arn     = optional(string)
    input_transformer = optional(object({
      input_paths    = map(string)
      input_template = string
    }))
    retry_policy = optional(object({
      maximum_retry_attempts       = number
      maximum_event_age_in_seconds = number
    }))
  }))

  validation {
    condition = alltrue([
      for t in var.targets :
      can(regex("^arn:aws:(sns|sqs|states|kinesis|events|ecs|codebuild|ssm|execute-api|appflow):", t.arn))
    ])
    error_message = "Each target ARN must be one of the supported services: sns, sqs, states, kinesis, events, ecs, codebuild, ssm, execute-api, appflow."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
