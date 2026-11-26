# S3 event → SQS → Lambda. The queue decouples them: retries, batching and a dead-letter queue
# for files that fail 3 times.
locals {
  # built, not read: a data source would fail on a fresh build before the bucket exists
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600 # 14 days to look at failed messages
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = 180 # 6 x the function timeout, as AWS recommends
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# only this bucket, in this account, may send
data "aws_iam_policy_document" "queue" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.bucket_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.queue.json
}

resource "aws_s3_bucket_notification" "data" {
  bucket = var.bucket_name

  queue {
    queue_arn     = aws_sqs_queue.this.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "smn/"
    filter_suffix = ".csv"
  }

  depends_on = [aws_sqs_queue_policy.this]
}

# the Lambda service polls the queue: the function itself never calls SQS (no endpoint needed)
resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn        = aws_sqs_queue.this.arn
  function_name           = aws_lambda_function.this.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}
