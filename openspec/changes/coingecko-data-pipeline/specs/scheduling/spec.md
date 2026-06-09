## ADDED Requirements

### Requirement: EventBridge Scheduler rule

The system SHALL create an EventBridge Scheduler that triggers the Lambda orchestrator on a recurring schedule.

- The schedule name SHALL be `coingecko-hourly`
- The schedule expression SHALL be `rate(1 hour)`
- The flexible time window mode SHALL be `OFF` (exact execution time)
- The target SHALL be the Lambda orchestrator function ARN
- The schedule SHALL have an IAM role with permission to invoke the Lambda function

#### Scenario: Schedule triggers Lambda

- **WHEN** the schedule fires at the configured interval
- **THEN** EventBridge SHALL invoke the Lambda orchestrator
- **THEN** the Lambda SHALL execute `ecs.run_task()` as normal

#### Scenario: Manual invocation bypasses schedule

- **WHEN** a user calls `aws lambda invoke --function-name coingecko-orchestrator`
- **THEN** the Lambda SHALL execute the same `ecs.run_task()` flow
- **THEN** the schedule SHALL remain unchanged and continue firing

### Requirement: IAM role for EventBridge Scheduler

The system SHALL create an IAM role that grants EventBridge Scheduler permission to invoke the Lambda function.

- The trust policy SHALL allow `scheduler.amazonaws.com` to assume the role
- The permissions policy SHALL allow `lambda:InvokeFunction` on the orchestrator Lambda ARN
- The role SHALL be created via Terraform

#### Scenario: Create EventBridge role

- **WHEN** Terraform applies the IAM module
- **THEN** an IAM role for EventBridge SHALL exist with the correct trust and permissions policies

### Requirement: Lambda resource policy for EventBridge Scheduler

The system SHALL grant the EventBridge Scheduler service permission to invoke the Lambda function via a resource-based policy.

- The statement ID SHALL be `AllowExecutionFromEventBridgeScheduler`
- The principal SHALL be `scheduler.amazonaws.com`
- The action SHALL be `lambda:InvokeFunction`

#### Scenario: Lambda permission

- **WHEN** Terraform applies the Lambda module
- **THEN** the `aws_lambda_permission` resource SHALL allow `scheduler.amazonaws.com` to invoke the function

### Requirement: ECS Task State Change monitoring

The system SHALL capture ECS task state changes for observability of pipeline execution outcomes.

- An EventBridge rule SHALL match `ECS Task State Change` events from the `coingecko` ECS cluster
- The rule SHALL route events to CloudWatch Logs
- The rule SHALL capture both `RUNNING` and `STOPPED` state transitions
- STOPPED events SHALL include the container exit code, enabling verification of pipeline success or failure

#### Scenario: Pipeline task stops

- **WHEN** an ECS pipeline task transitions to `STOPPED`
- **THEN** EventBridge SHALL capture the state change event
- **THEN** the event SHALL be logged to CloudWatch
- **THEN** the logs SHALL contain the container exit code (0 for success, non-zero for failure)
