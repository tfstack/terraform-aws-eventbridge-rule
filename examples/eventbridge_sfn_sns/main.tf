provider "aws" {
  region = "ap-southeast-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# SNS Topic for notification
resource "aws_sns_topic" "ami_updates" {
  name = "ecs-ami-updates-${random_string.suffix.result}"
}

resource "aws_sns_topic_policy" "ami_updates" {
  arn = aws_sns_topic.ami_updates.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sns:Publish",
        Resource  = aws_sns_topic.ami_updates.arn
      }
    ]
  })
}

# Step Function definition
resource "aws_sfn_state_machine" "ami_update_flow" {
  name     = "amiUpdateFlow-${random_string.suffix.result}"
  role_arn = aws_iam_role.step_fn_exec.arn
  definition = jsonencode({
    Comment = "Dummy Step Function for AMI update",
    StartAt = "Log",
    States = {
      Log = {
        Type   = "Pass",
        Result = "AMI updated",
        End    = true
      }
    }
  })
}

# Step Function Execution Role
resource "aws_iam_role" "step_fn_exec" {
  name = "ami-stepfn-exec-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_fn_exec_policy" {
  name = "stepfn-exec-policy"
  role = aws_iam_role.step_fn_exec.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# EventBridge Rule
module "ami_update_rule" {
  source      = "../../" # Your module path
  rule_name   = "ecs-ami-update-monitor-${random_string.suffix.result}"
  description = "Trigger on ECS Optimized AMI Parameter Store update"

  event_pattern = jsonencode({
    source        = ["aws.ssm"],
    "detail-type" = ["Parameter Store Change"],
    detail = {
      name      = ["/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"],
      operation = ["Update"]
    }
  })

  logging = {
    log_group_name  = "/aws/events/ecs-ami-updates-${random_string.suffix.result}"
    prevent_destroy = false
  }

  tags = {
    Environment = "development"
    Service     = "ecs"
    Purpose     = "ami-monitoring"
  }

  targets = [
    {
      arn = aws_sns_topic.ami_updates.arn
      input_transformer = {
        input_paths = {
          parameter = "$.detail.name"
          value     = "$.detail.value"
          time      = "$.time"
        }
        input_template = <<EOT
{
  "message": "AMI Updated: <parameter> = <value> at <time>"
}
EOT
      }
    },
    {
      arn         = aws_sfn_state_machine.ami_update_flow.arn
      create_role = true
    }
  ]
}

output "sns_topic_arn" {
  value = aws_sns_topic.ami_updates.arn
}

output "step_function_arn" {
  value = aws_sfn_state_machine.ami_update_flow.arn
}
