resource "aws_ecs_cluster" "coingecko" {
  name = var.project_name
}

resource "aws_ecs_task_definition" "coingecko_pipeline" {
  family                   = "${var.project_name}-pipeline"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "pipeline"
      image     = "localhost:5100/${aws_ecr_repository.coingecko_pipeline.name}:latest"
      essential = true

      environment = [
        {
          name  = "DLT_DATA_DIR"
          value = "/tmp/dlt_data"
        },
        {
          name  = "DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL"
          value = "http://floci:4566"
        },
        {
          name  = "COINGECKO_API_KEY"
          value = var.coingecko_api_key
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-pipeline"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "pipeline"
        }
      }
    },
  ])

  ephemeral_storage {
    size_in_gib = 21
  }
}
