# the zip only holds the package (no tests, no venv), same as weather-ingest
data "archive_file" "package" {
  type             = "zip"
  source_dir       = var.source_dir
  output_path      = "${path.root}/${var.name}.zip"
  output_file_mode = "0644"
  excludes         = ["**/__pycache__/**"]
}

resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "function" {
  name               = "${var.name}-function"
  description        = "Runs the ${var.name} Lambda: reads ingested files, writes summaries."
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# ENIs in the VPC (create, describe, delete): AWS managed, no resource-level permissions possible
resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# least privilege: own log group, own queue, read smn/, write summary/
data "aws_iam_policy_document" "function" {
  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.function.arn}:*"]
  }

  statement {
    sid       = "ConsumeQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.this.arn]
  }

  statement {
    sid       = "ReadFiles"
    actions   = ["s3:GetObject"]
    resources = ["${local.bucket_arn}/smn/*"]
  }

  statement {
    sid       = "WriteSummaries"
    actions   = ["s3:PutObject"]
    resources = ["${local.bucket_arn}/summary/*"]
  }
}

resource "aws_iam_role_policy" "function" {
  name   = "parse"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.function.json
}

# owned by this account, in the shared VPC: only HTTPS to S3 (through the gateway endpoint)
resource "aws_security_group" "function" {
  name        = var.name
  description = "Lambda ${var.name}: HTTPS to S3 only"
  vpc_id      = var.vpc_id

  egress {
    description     = "HTTPS to S3 via the gateway endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [var.s3_prefix_list_id]
  }
}

resource "aws_lambda_function" "this" {
  # checkov:skip=CKV_AWS_50: no X-Ray in the VPC: it would need an interface endpoint (cost)
  function_name    = var.name
  description      = "Summarizes ingested SwissMetNet files, runs in the shared VPC."
  role             = aws_iam_role.function.arn
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  handler          = "weather_parse.handler.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 30

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.function.id]
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.function.name
  }

  depends_on = [aws_iam_role_policy.function, aws_iam_role_policy_attachment.vpc]
}
