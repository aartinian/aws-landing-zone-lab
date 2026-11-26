output "function_name" {
  description = "Name of the parse Lambda."
  value       = aws_lambda_function.this.function_name
}

output "queue_url" {
  description = "Queue between the bucket and the Lambda."
  value       = aws_sqs_queue.this.id
}

output "dlq_url" {
  description = "Dead-letter queue: messages that failed 3 times."
  value       = aws_sqs_queue.dlq.id
}
