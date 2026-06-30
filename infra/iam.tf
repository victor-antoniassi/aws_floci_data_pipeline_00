data "aws_iam_policy_document" "lambda_exec_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eventbridge_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_exec_permissions" {
  statement {
    actions = [
      "ecs:RunTask",
      "iam:PassRole",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "ecs_exec_permissions" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.coingecko_raw.arn}/*"]
  }
}

data "aws_iam_policy_document" "eventbridge_permissions" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.orchestrator.arn]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_exec_trust.json
}

resource "aws_iam_role_policy" "lambda_exec" {
  role   = aws_iam_role.lambda_exec.name
  policy = data.aws_iam_policy_document.lambda_exec_permissions.json
}

resource "aws_iam_role" "ecs_exec" {
  name               = "${var.project_name}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust.json
}

resource "aws_iam_role_policy" "ecs_exec" {
  role   = aws_iam_role.ecs_exec.name
  policy = data.aws_iam_policy_document.ecs_exec_permissions.json
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust.json
}

resource "aws_iam_role_policy" "ecs_task" {
  role   = aws_iam_role.ecs_task.name
  policy = data.aws_iam_policy_document.ecs_task_permissions.json
}

resource "aws_iam_role" "eventbridge" {
  name               = "${var.project_name}-eventbridge-scheduler"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_trust.json
}

resource "aws_iam_role_policy" "eventbridge" {
  role   = aws_iam_role.eventbridge.name
  policy = data.aws_iam_policy_document.eventbridge_permissions.json
}
