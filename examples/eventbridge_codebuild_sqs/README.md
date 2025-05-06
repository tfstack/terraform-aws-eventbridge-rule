# terraform-aws-eventbridge-rule

A reusable Terraform module for defining an AWS EventBridge rule with multiple targets. This example demonstrates how to use the module to route ECS AMI updates to both **CodeBuild** and **SQS** using minimal configuration.

---

## 📌 Module Focus

This module is focused on:

* Creating a single EventBridge rule with optional schedule or pattern
* Supporting **multiple target types** (SNS, SQS, Lambda, Step Functions, CodeBuild, etc.)
* Automatically managing IAM roles for each target (if needed)
* Optional logging to CloudWatch

---

## ✅ Example Usage: CodeBuild + SQS Targets

```hcl
provider "aws" {
  region = "ap-southeast-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# SQS queue to receive notifications
resource "aws_sqs_queue" "ami_update_queue" {
  name = "ami-update-queue-${random_string.suffix.result}"
}

# CodeBuild project to react to AMI change events
resource "aws_codebuild_project" "ami_update_job" {
  name         = "ami-update-job-${random_string.suffix.result}"
  service_role = aws_iam_role.codebuild_service.arn
  ...
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_service" {
  name               = "ami-codebuild-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({ ... })
}

resource "aws_iam_role_policy" "codebuild_service_policy" {
  role   = aws_iam_role.codebuild_service.name
  policy = jsonencode({ ... })
}

# 👇 EventBridge Rule with multiple targets
module "ami_update_rule" {
  source      = "../../"
  rule_name   = "ami-codebuild-sqs-${random_string.suffix.result}"
  description = "Trigger CodeBuild and SQS on AMI updates"

  event_pattern = jsonencode({
    source       = ["aws.ssm"],
    "detail-type" = ["Parameter Store Change"],
    detail = {
      name      = ["/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"],
      operation = ["Update"]
    }
  })

  logging = {
    log_group_name  = "/aws/events/ami-codebuild-sqs-${random_string.suffix.result}"
    retention_days  = 7
    prevent_destroy = false
  }

  targets = [
    {
      arn         = aws_codebuild_project.ami_update_job.arn
      service     = "codebuild"
      create_role = true
    },
    {
      arn         = aws_sqs_queue.ami_update_queue.arn
      service     = "sqs"
      create_role = true
    }
  ]

  tags = {
    Application = "ami-monitor"
    Env         = "dev"
  }
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
* Use `input_transformer` in the `targets` block to customize event payload
* This module does **not** create the target services (like CodeBuild/SQS) — only the rule and connections

---

## 📄 Inputs & Outputs

See [variables.tf](./variables.tf) and [outputs.tf](./outputs.tf) for detailed variable definitions.
