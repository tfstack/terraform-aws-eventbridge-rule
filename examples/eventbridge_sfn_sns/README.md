# terraform-aws-eventbridge-rule

This is a usage-focused example of the `terraform-aws-eventbridge-rule` module, demonstrating how to wire up **Step Functions** and **SNS** as EventBridge targets in response to ECS AMI updates.

---

## 📌 Module Focus

This module focuses on:

* Creating an EventBridge rule based on schedule or event pattern
* Supporting multiple AWS targets (SNS, Step Functions, Lambda, etc.)
* Optionally creating IAM roles for targets based on the service type
* Optional logging to CloudWatch

---

## ✅ Example Usage: Step Function + SNS Targets

```hcl
provider "aws" {
  region = "ap-southeast-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# SNS Topic
resource "aws_sns_topic" "ami_updates" {
  name = "ecs-ami-updates-${random_string.suffix.result}"
}

resource "aws_sns_topic_policy" "ami_updates" {
  arn = aws_sns_topic.ami_updates.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action = "sns:Publish",
      Resource = aws_sns_topic.ami_updates.arn
    }]
  })
}

# Step Function
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

# IAM Role for Step Function
resource "aws_iam_role" "step_fn_exec" {
  name = "ami-stepfn-exec-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "states.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "step_fn_exec_policy" {
  name = "stepfn-exec-policy"
  role = aws_iam_role.step_fn_exec.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

# 👇 EventBridge Rule using the module
module "ami_update_rule" {
  source    = "../../"
  rule_name = "ecs-ami-update-monitor-${random_string.suffix.result}"
  description = "Trigger on ECS Optimized AMI Parameter Store update"

  event_pattern = jsonencode({
    source       = ["aws.ssm"],
    "detail-type" = ["Parameter Store Change"],
    detail = {
      name      = ["/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"],
      operation = ["Update"]
    }
  })

  logging = {
    log_group_name = "/aws/events/ecs-ami-updates-${random_string.suffix.result}"
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
      service = "sns"
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
      service     = "stepfunctions"
      create_role = true
    }
  ]
}
```

---

## 🛠️ Supported Target Types

This module supports the following AWS services as `targets`:

* `sns`
* `sqs`
* `lambda`
* `stepfunctions`
* `kinesis`
* `eventbridge` (bus-to-bus forwarding)
* `ecs`
* `codebuild`
* `ssm`
* `apigateway`
* `appflow`

Each target can either reuse an existing IAM role (`role_arn`) or create a minimal one automatically (`create_role = true`).

---

## 🧐 Notes

* EventBridge invokes all targets **in parallel**
* Input transformation lets you format messages per target
* This module is responsible for wiring only — target services must already exist

---

## 📄 Inputs & Outputs

See [variables.tf](./variables.tf) and [outputs.tf](./outputs.tf) for detailed variable definitions.
