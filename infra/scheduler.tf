resource "aws_scheduler_schedule" "coingecko_hourly" {
  name                         = "${var.project_name}-hourly"
  schedule_expression          = "rate(1 hour)"
  schedule_expression_timezone = "UTC"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.orchestrator.arn
    role_arn = aws_iam_role.eventbridge.arn
  }
}

resource "aws_cloudwatch_event_rule" "ecs_task_state_change" {
  name        = "${var.project_name}-ecs-state-change"
  description = "Capture ECS Task State Change events"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      cluster = [aws_ecs_cluster.coingecko.arn]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_task_state_change" {
  rule      = aws_cloudwatch_event_rule.ecs_task_state_change.name
  arn       = aws_cloudwatch_log_group.ecs_events.arn
}

resource "aws_cloudwatch_log_group" "ecs_events" {
  name = "/aws/events/${var.project_name}-ecs-state-change"
}
