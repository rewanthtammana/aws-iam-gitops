provider "aws" {
  region = "us-east-1"
}

variable "GITHUB_USERNAME" {
  description = "GitHub username"
  type        = string
}

variable "GITHUB_REPO" {
  description = "GitHub repository name"
  type        = string
}

variable "GITHUB_TOKEN" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "ECR_REPO_NAME" {
  description = "ECR Repository Name"
  type        = string
}

variable "RANDOM_SUFFIX" {
  description = "Random Suffix for Resource Names"
  type        = string
}

variable "ECR_REPO_TAG" {
  description = "ECR Repository Tag"
  type        = string
}

variable "AWS_PAGER" {
  description = "AWS Pager Environment Variable"
  type        = string
  default     = ""
}

variable "ACCOUNT_ID" {
  description = "AWS Account ID"
  type        = string
}

variable "REGION" {
  description = "AWS Region"
  type        = string
}

variable "ROLE_NAME" {
  description = "IAM Role Name"
  type        = string
}

variable "IMAGE" {
  description = "Docker Image URI"
  type        = string
}

variable "LAMBDA_FUNCTION_NAME" {
  description = "Lambda Function Name"
  type        = string
}

variable "POLICY_NAME" {
  description = "IAM Policy Name"
  type        = string
}

variable "LAMBDA_TIMEOUT" {
  description = "Lambda Function Timeout"
  type        = number
  default     = 120
}

variable "EVENTBRIDGE_NAME" {
  description = "EventBridge name"
  type        = string
}

variable "S3_BUCKET_NAME" {
  description = "S3 Bucket"
  type        = string
}

variable "CLOUDTRAIL_NAME" {
  description = "Cloudtrail name"
  type        = string
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = var.REGION
  ecr_repo_name = var.ECR_REPO_NAME
  ecr_repo_tag = var.ECR_REPO_TAG
  github_username = var.GITHUB_USERNAME
  github_repo = var.GITHUB_REPO
  github_token = var.GITHUB_TOKEN
  role_name = var.ROLE_NAME
  lambda_function_name = var.LAMBDA_FUNCTION_NAME
  policy_name = var.POLICY_NAME
  lambda_timeout = var.LAMBDA_TIMEOUT
  eventbridge_name = var.EVENTBRIDGE_NAME
  s3_bucket_name = var.S3_BUCKET_NAME
  cloudtrail_name = var.CLOUDTRAIL_NAME
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_role" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = local.policy_name
  description = "Policy for Lambda function"

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
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_name}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:ListPolicies",
          "iam:ListRoles",
          "organizations:ListPolicies"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "kms:Decrypt",
        Resource = "arn:aws:kms:${local.region}:${local.account_id}:key/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "lambda_function" {
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.ecr_repo_name}:${local.ecr_repo_tag}"
  architectures = ["arm64"]
  timeout       = local.lambda_timeout
}

# Create S3 bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = local.s3_bucket_name
  force_destroy = true
}

# Add bucket policy
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_bucket.arn}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# Create CloudTrail
resource "aws_cloudtrail" "cloudtrail" {
  name                          = local.cloudtrail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  enable_logging                = true
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}

# Create EventBridge Rule
resource "aws_cloudwatch_event_rule" "iam_and_orgs_rule" {
  name        = local.eventbridge_name
  description = "Capture events from IAM and Organizations"

  event_pattern = jsonencode({
    "source" : ["aws.iam", "aws.organizations"]
  })
}

# Add permissions for EventBridge to invoke Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.iam_and_orgs_rule.arn
}

# Set Lambda function as the target for the EventBridge rule
resource "aws_cloudwatch_event_target" "event_target" {
  rule      = aws_cloudwatch_event_rule.iam_and_orgs_rule.name
  target_id = "LambdaFunction"
  arn       = aws_lambda_function.lambda_function.arn
}
