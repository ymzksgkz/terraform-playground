terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.66.0"
    }
  }
  required_version = ">=1.9.5"
  backend "s3" {
    key             = "terraform/state.tfstate"
    encrypt         = true
    lock_table      = true
  }
}

provider "aws" {
  region = var.region
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
# ここにアップすると関数が実行されてほしい
resource "aws_s3_bucket" "target_bucket" {
  bucket        = "target-bucket-${var.project_id}"
  force_destroy = true
  tags          = var.common_tags
}

# lambda 用の IAM ロール
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam-s3-upload-function-${var.project_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid = ""
    }]
  })
}

# ログ出力用のポリシー
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ロググループ
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/s3-upload-function-${var.project_id}"
  retention_in_days = 7  # 7日間保持
}

# function
resource "aws_lambda_function" "function" {
  function_name = "s3-upload-function-${var.project_id}"
  filename      = "./lambda_function.zip"
  role          = aws_iam_role.iam_for_lambda.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  memory_size   = 128
  timeout       = 30
}

# Lambda実行権限
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.target_bucket.arn
}

# S3バケット通知リソース
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.target_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
