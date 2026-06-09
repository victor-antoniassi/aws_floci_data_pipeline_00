## ADDED Requirements

### Requirement: Lambda function entry point

The system SHALL provide an AWS Lambda function (Python 3.12, container image deployment) that orchestrates pipeline execution by calling ECS RunTask.

- The handler SHALL be defined at `handler.handler` in the `src/orchestrator/` directory
- The handler SHALL accept `event` and `context` parameters per the AWS Lambda runtime interface
- The function SHALL log the received event and the RunTask result to CloudWatch
- The Lambda SHALL have a timeout of at least 60 seconds (it only calls ECS API, does not process data)

#### Scenario: Lambda invoked by EventBridge

- **WHEN** the Lambda receives an event from EventBridge Scheduler
- **THEN** the handler SHALL extract the event context and call `ecs.run_task()`

#### Scenario: Lambda invoked manually

- **WHEN** a user invokes the Lambda via `aws lambda invoke`
- **THEN** the handler SHALL execute the same `ecs.run_task()` flow

### Requirement: ECS RunTask invocation

The Lambda SHALL call the ECS API to run a Fargate task with the pipeline container.

- The Lambda SHALL use `ecs.run_task()` with a configured cluster name, task definition, and Fargate launch type
- The Lambda SHALL pass `networkConfiguration` including subnets and security groups
- The Lambda SHALL set `count=1` for a single task instance
- The cluster name SHALL be configurable via environment variable `ECS_CLUSTER`
- The task definition SHALL be configurable via environment variable `ECS_TASK_DEFINITION`
- The subnets SHALL be configurable via environment variable `ECS_SUBNETS`
- The security groups SHALL be configurable via environment variable `ECS_SECURITY_GROUPS`

#### Scenario: Successful RunTask

- **WHEN** `ecs.run_task()` succeeds
- **THEN** the Lambda SHALL log the task ARN and return `{"status": "started", "taskArn": "<task_arn>"}`
- **THEN** the Lambda SHALL NOT wait for the ECS task to complete (fire-and-forget)

#### Scenario: RunTask failure

- **WHEN** `ecs.run_task()` throws an exception
- **THEN** the Lambda SHALL log the error and raise the exception
- **THEN** CloudWatch SHALL capture the failure

### Requirement: Concurrent task prevention

The Lambda SHALL check for running tasks in the ECS cluster before launching a new one, to prevent concurrent pipeline executions.

- The Lambda SHALL call `ecs.list_tasks(cluster=cluster, desiredStatus='RUNNING')` before `run_task()`
- When running tasks exist for the pipeline task family, the Lambda SHALL log "task already running" and skip execution
- The skipped invocation SHALL be logged to CloudWatch

#### Scenario: Task already running

- **WHEN** a Lambda invocation occurs and a pipeline task is already running
- **THEN** the Lambda SHALL NOT call `ecs.run_task()`
- **THEN** the Lambda SHALL log a warning and return `{"status": "skipped", "reason": "task already running"}`

### Requirement: Container image deployment

The Lambda function SHALL be deployed as a container image from ECR, not as a zip archive.

- The image SHALL be built using a `Dockerfile.orchestrator` with `uv sync --group orchestrator`
- The image SHALL be published to an ECR repository (separate from the pipeline ECR repo)
- Terraform SHALL create the Lambda with `package_type = "Image"` and `image_uri` pointing to the ECR repository

#### Scenario: Deployment

- **WHEN** Terraform applies the Lambda module
- **THEN** `aws_lambda_function` SHALL reference the ECR image with `package_type = "Image"`
- **THEN** Terraform SHALL NOT use `archive_file` or `filename`
