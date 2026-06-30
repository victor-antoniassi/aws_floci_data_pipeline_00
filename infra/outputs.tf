output "s3_bucket_arn" {
  description = "ARN of the coingecko-raw bucket"
  value       = aws_s3_bucket.coingecko_raw.arn
}

output "lambda_function_arn" {
  description = "ARN of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.arn
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    pipeline     = aws_ecr_repository.coingecko_pipeline.repository_url
    orchestrator = aws_ecr_repository.coingecko_orchestrator.repository_url
  }
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.coingecko.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the pipeline task definition"
  value       = aws_ecs_task_definition.coingecko_pipeline.arn
}

output "schedule_status" {
  description = "Whether the EventBridge Scheduler is active and its schedule expression"
  value = {
    active    = var.enable_schedule
    schedule  = var.enable_schedule ? var.schedule_expression : "disabled"
  }
}
