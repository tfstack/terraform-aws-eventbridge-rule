provider "aws" {
  region = "ap-southeast-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# SQS Queue for decoupled processing
resource "aws_sqs_queue" "ami_update_queue" {
  name = "ami-update-queue-${random_string.suffix.result}"
}

# CodeBuild project to react to AMI changes
resource "aws_codebuild_project" "ami_update_job" {
  name         = "ami-update-job-${random_string.suffix.result}"
  service_role = aws_iam_role.codebuild_service.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-EOT
      version: 0.2
      phases:
        build:
          commands:
            - echo "AMI update received"
    EOT
  }

  tags = {
    Application = "ami-monitor"
    Component   = "codebuild"
  }
}

resource "aws_iam_role" "codebuild_service" {
  name = "ami-codebuild-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_service_policy" {
  name = "ami-codebuild-policy"
  role = aws_iam_role.codebuild_service.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:*",
        "s3:*"
      ],
      Resource = "*"
    }]
  })
}

module "ami_update_rule" {
  source      = "../../"
  rule_name   = "ami-codebuild-sqs-${random_string.suffix.result}"
  description = "Trigger CodeBuild and SQS on AMI updates"

  event_pattern = jsonencode({
    source        = ["aws.ssm"],
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
      create_role = true
    },
    {
      arn         = aws_sqs_queue.ami_update_queue.arn
      create_role = true
    }
  ]

  tags = {
    Application = "ami-monitor"
    Env         = "dev"
  }
}
