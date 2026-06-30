resource "aws_lambda_function" "orchestrator" {
  function_name = "${var.project_name}-orchestrator"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  image_uri     = "localhost:5100/${aws_ecr_repository.coingecko_orchestrator.name}:latest"
  timeout       = 60
  memory_size   = 128

  environment {
    variables = {
      ECS_CLUSTER           = aws_ecs_cluster.coingecko.name
      ECS_TASK_DEFINITION   = aws_ecs_task_definition.coingecko_pipeline.arn
      ECS_SUBNETS           = join(",", var.ecs_subnets)
      ECS_SECURITY_GROUPS   = join(",", var.ecs_security_groups)
    }
  }
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = try(aws_scheduler_schedule.coingecko_hourly[0].arn, "")
}
