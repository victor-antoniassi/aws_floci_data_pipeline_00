## ADDED Requirements

### Requirement: Terraform provider configuration

The system SHALL define an AWS Terraform provider that works with both Floci (local) and real AWS (production) by toggling endpoint configuration.

- The provider SHALL be configured with `region = "us-east-1"`
- The provider SHALL accept a variable `floci_endpoint` for the local endpoint URL
- When `floci_endpoint` is non-empty, the provider SHALL configure all service endpoints with that URL
- When `floci_endpoint` is empty, the provider SHALL use default AWS endpoints
- The provider SHALL set `skip_credentials_validation`, `skip_requesting_account_id`, `skip_metadata_api_check`, and `s3_use_path_style` when `floci_endpoint` is set

#### Scenario: Local Floci configuration

- **WHEN** `floci_endpoint = "http://localhost:4566"` in terraform.tfvars
- **THEN** the provider SHALL configure endpoints for all services to `http://localhost:4566`
- **THEN** `skip_credentials_validation` SHALL be `true`

#### Scenario: Real AWS configuration

- **WHEN** `floci_endpoint` is empty
- **THEN** the provider SHALL use default AWS endpoints
- **THEN** `skip_credentials_validation` SHALL be `false`

### Requirement: S3 bucket

The system SHALL create an S3 bucket for storing pipeline output.

- The bucket name SHALL be `coingecko-raw`
- The bucket SHALL be private (no public access)
- The bucket SHALL have versioning enabled via `aws_s3_bucket_versioning` with `versioning_configuration { status = "Enabled" }`
- The bucket SHALL be created via Terraform

#### Scenario: Create bucket

- **WHEN** Terraform applies `aws_s3_bucket.coingecko_raw`
- **THEN** the bucket SHALL exist and SHALL be accessible only by the ECS task role
- **THEN** versioning SHALL be enabled

### Requirement: IAM roles and policies

The system SHALL create the following IAM roles with least-privilege policies:

- **Lambda execution role**: trust `lambda.amazonaws.com`, permissions for `ecs:RunTask`, `iam:PassRole`, `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`, `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
- **ECS task execution role**: trust `ecs-tasks.amazonaws.com`, permissions for `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`, `logs:CreateLogStream`, `logs:PutLogEvents`
- **ECS task role**: trust `ecs-tasks.amazonaws.com`, permissions for `s3:PutObject` on `coingecko-raw` bucket
- **EventBridge scheduler role**: trust `scheduler.amazonaws.com`, permission for `lambda:InvokeFunction` on orchestrator Lambda ARN

#### Scenario: Create IAM roles

- **WHEN** Terraform applies the IAM module
- **THEN** all four IAM roles SHALL exist with their respective trust and permissions policies

### Requirement: Lambda function resource

The system SHALL create the orchestrator Lambda function as a container image deployment.

- The function name SHALL be `coingecko-orchestrator`
- The Lambda SHALL use `package_type = "Image"` with `image_uri` pointing to the orchestrator ECR repository
- The handler SHALL be set to `handler.handler` (for the Lambda runtime interface inside the container)
- The runtime parameter SHALL be omitted (container image handles runtime)
- The timeout SHALL be 60 seconds (the Lambda only calls ECS API, does not process data)
- The memory size SHALL be 128 MB
- The function SHALL receive environment variables for ECS configuration: `ECS_CLUSTER`, `ECS_TASK_DEFINITION`, `ECS_SUBNETS`, `ECS_SECURITY_GROUPS`

#### Scenario: Terraform apply

- **WHEN** Terraform applies the Lambda module
- **THEN** `aws_lambda_function` SHALL be created with `package_type = "Image"`
- **THEN** `image_uri` SHALL reference the ECR repository URI
- **THEN** Terraform SHALL NOT use `archive_file` or `filename`

### Requirement: Lambda resource policy for EventBridge Scheduler

The system SHALL grant the EventBridge Scheduler service permission to invoke the Lambda function.

- The `aws_lambda_permission` resource SHALL use principal `scheduler.amazonaws.com`
- The action SHALL be `lambda:InvokeFunction`

#### Scenario: Lambda permission

- **WHEN** Terraform applies the Lambda module
- **THEN** the Lambda resource policy SHALL allow `scheduler.amazonaws.com` to invoke the function

### Requirement: Terraform state management

Terraform state SHALL be stored locally for the PoC.

- The backend SHALL be `local` (default)
- The state file SHALL be `.terraform/terraform.tfstate`

#### Scenario: Terraform init

- **WHEN** `terraform init` runs
- **THEN** the local backend SHALL initialize

### Requirement: Outputs

Terraform SHALL export the following outputs:

- `s3_bucket_arn`: ARN of the coingecko-raw bucket
- `lambda_function_arn`: ARN of the orchestrator Lambda
- `ecr_repository_urls`: Map of ECR repository URLs (pipeline and orchestrator)
- `ecs_cluster_name`: Name of the ECS cluster
- `ecs_task_definition_arn`: ARN of the pipeline task definition

#### Scenario: Terraform apply

- **WHEN** Terraform applies successfully
- **THEN** all outputs SHALL be displayed with their values
