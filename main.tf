terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "lambda_bucket" {
    prefix =  "lambda-bucket-"
    length = 4  
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket.id
}
  
resource "aws_s3_bucket_acl" "bucket_acl"{
    bucket = aws_s3_bucket.lambda_bucket.id
    acl = "private"
}

data "archive_file" "lambda_is_positive" {
  type        = "zip"
  source_file = "${path.module}/is-positive/is-positive.py"
  output_path = "${path.module}/is-positive.zip"
}

data "archive_file" "lambda_random" {
  type        = "zip"
  source_file = "${path.module}/random/random.py"
  output_path = "${path.module}/random.zip"
}
  
resource "aws_s3_object" "lambda_is_positive" {
  bucket = random_pet.lambda_bucket.id
  key    = "is-positive.zip"
  source = data.archive_file.lambda_is_positive.output_path
  etag   = filemd5(data.archive_file.lambda_is_positive.output_path)
}
  
resource "aws_s3_object" "lambda_random" {
  bucket = random_pet.lambda_bucket.id
  key    = "random.zip"
  source = data.archive_file.lambda_random.output_path
  etag   = filemd5(data.archive_file.lambda_random.output_path)
}
  
resource "aws_lambda_function" "is_positive" {
    function_name = "is-positive"
    s3_bucket = aws_s3_bucket.lambda_bucket.id
    s3_key = aws_s3_object.lambda_is_positive.key

    runtime = "python3.8"
    handler = "is-positive.lambda_handler"
    role = aws_iam_role.lambda_exec.arn

    source_code_hash = data.archive_file.lambda_is_positive.output_base64sha256
}

resource "aws_lambda_function" "random" {
    function_name = "random"
    s3_bucket = aws_s3_bucket.lambda_bucket.id
    s3_key = aws_s3_object.lambda_random.key

    runtime = "python3.8"
    handler = "random.lambda_handler"
    role = aws_iam_role.lambda_exec.arn

    source_code_hash = data.archive_file.lambda_random.output_base64sha256 
}

resource "aws_cloudwatch_log_group" "is_positive" {
  name = "/aws/lambda/${aws_lambda_function.is_positive.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "random" {
  name = "/aws/lambda/${aws_lambda_function.random.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}