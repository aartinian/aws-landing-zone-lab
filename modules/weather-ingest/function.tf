# the zip only holds the package (no tests, no venv). Timestamps are fixed by the provider and
# the file mode is pinned, so the hash changes only with the code (same zip locally and in CI).
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
  description        = "Runs the ${var.name} Lambda: writes logs and ingested files."
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# least privilege: own log group, write-only into the smn/ prefix
data "aws_iam_policy_document" "function" {
  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.function.arn}:*"]
  }

  # X-Ray does not support resource-level permissions
  statement {
    sid       = "WriteTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  statement {
    sid       = "StoreFiles"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.data.arn}/smn/*"]
  }
}

resource "aws_iam_role_policy" "function" {
  name   = "ingest"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.function.json
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  description      = "Ingests MeteoSwiss SwissMetNet open data into S3."
  role             = aws_iam_role.function.arn
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  handler          = "weather_ingest.handler.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 60

  environment {
    variables = {
      BUCKET   = aws_s3_bucket.data.id
      STATIONS = join(",", var.stations)
    }
  }

  # traces show the time spent in the STAC API vs. S3 (free tier: 100k traces/month)
  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.function.name
  }

  depends_on = [aws_iam_role_policy.function]
}
