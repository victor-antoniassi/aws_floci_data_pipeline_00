## Why

Build a production-grade data pipeline that ingests cryptocurrency market data from the CoinGecko API and stores it as Parquet in S3, using professional AWS patterns (Lambda orchestration, ECS Fargate execution, Terraform IaC) — all simulated locally via Floci for zero-cost study and iteration.

## What Changes

- Introduces a dlt-based data pipeline that fetches `/coins/markets` from CoinGecko and writes Parquet files to an S3 bucket
- Adds a Lambda orchestrator that triggers ECS RunTask on schedule or manual invocation
- Adds an ECS Fargate task definition and Docker image for the pipeline container (uv-based build with optional-dependencies groups)
- Adds a separate Docker image for the Lambda orchestrator (container image from ECR, replacing zip deployment)
- Adds EventBridge Scheduler with a cron expression to invoke the Lambda on a recurring schedule
- Adds Terraform IaC to declaratively manage all AWS resources (S3, ECR, ECS, Lambda, IAM roles, EventBridge)
- Adds docker-compose and Makefile for local Floci-based development and testing

## Capabilities

### New Capabilities

- `data-pipeline`: dlt pipeline that extracts data from CoinGecko REST API and loads it as Parquet into an S3 filesystem destination, with configurable retry and schema inference
- `lambda-orchestrator`: AWS Lambda function (container image from ECR) that receives events, checks for concurrent tasks, and calls `ecs.run_task()` to launch the pipeline container
- `ecs-task`: Two Docker container images (pipeline + orchestrator) built with uv dependency groups, the ECS task definition for Fargate execution, and two ECR repositories
- `scheduling`: EventBridge Scheduler rule with cron/rate expression targeting the Lambda orchestrator, plus IAM role for invocation permissions
- `infrastructure`: Terraform configuration defining all AWS resources — S3 bucket with versioning, two ECR repositories, ECS cluster and task definition with execution timeout, Lambda function (container image), IAM roles and policies, EventBridge Scheduler, and ECS Task State Change monitoring rule
- `observability`: EventBridge rule captures ECS task state changes to CloudWatch Logs for pipeline outcome tracking
- `local-env`: docker-compose with Floci (docker.sock mounted for real container execution), Makefile with bootstrap/build-pipeline/build-orchestrator/push-all/invoke/status/logs/destroy targets, and dlt secrets.toml for local endpoint configuration

### Modified Capabilities

<!-- None — no existing specs to modify -->

## Impact

- New project structure: `src/pipeline/`, `src/orchestrator/`, `docker/`, `infra/`
- Dependencies: Python 3.12, dlt, boto3, aws-lambda-powertools, uv (package management, single pyproject.toml with optional-dependencies groups)
- Infrastructure: Floci (local AWS emulator), Docker, Terraform
- External API: CoinGecko public endpoint (no API key required for PoC)
- No existing code affected — greenfield project
