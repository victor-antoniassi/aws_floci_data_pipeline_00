## ADDED Requirements

### Requirement: Pipeline Docker image

The system SHALL provide a `Dockerfile.pipeline` that builds a container image for the dlt ingestion ECS task.

- The base image SHALL be `python:3.12-slim`
- The Dockerfile SHALL copy the `uv` binary from `ghcr.io/astral-sh/uv:latest` (e.g., `COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/`)
- The Dockerfile SHALL run `uv sync --locked --no-dev --group pipeline` to install only pipeline dependencies from `pyproject.toml`
- The Dockerfile SHALL copy the `src/pipeline/` directory into the image
- The Dockerfile SHALL copy the `.dlt/` directory into the image for dlt configuration
- The container entry point SHALL run `python -m pipeline.main`
- The image SHALL be published to the `coingecko-pipeline` ECR repository

#### Scenario: Build pipeline image

- **WHEN** `docker build -f docker/Dockerfile.pipeline -t coingecko-pipeline .` runs
- **THEN** the image SHALL contain Python 3.12, dlt (via uv sync), the pipeline source code, and entrypoint
- **THEN** `uv` SHALL NOT be present in the final image if using multi-stage build

### Requirement: Orchestrator Docker image

The system SHALL provide a `Dockerfile.orchestrator` that builds a container image for the Lambda orchestrator.

- The base image SHALL be `python:3.12-slim`
- The Dockerfile SHALL copy the `uv` binary from `ghcr.io/astral-sh/uv:latest`
- The Dockerfile SHALL run `uv sync --locked --no-dev --group orchestrator` to install only orchestrator dependencies
- The Dockerfile SHALL copy `src/orchestrator/handler.py` into `/var/task/`
- The container entry point SHALL run `handler.handler`
- The image SHALL be published to the `coingecko-orchestrator` ECR repository

#### Scenario: Build orchestrator image

- **WHEN** `docker build -f docker/Dockerfile.orchestrator -t coingecko-orchestrator .` runs
- **THEN** the image SHALL contain Python 3.12, boto3 and aws-lambda-powertools (via uv sync), and handler.py

### Requirement: ECS task definition

The system SHALL register an ECS Fargate task definition for the pipeline container.

- The task family SHALL be `coingecko-pipeline`
- The launch type SHALL be FARGATE
- The network mode SHALL be `awsvpc`
- CPU SHALL be 256 units
- Memory SHALL be 512 MB
- The container SHALL be marked as essential
- The image SHALL be sourced from the `coingecko-pipeline` ECR repository
- The task SHALL have `execution_timeout_minutes = 10` to prevent runaway tasks
- The container SHALL receive `DLT_DATA_DIR=/tmp/dlt_data` as an environment variable
- The container SHALL receive `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL` as an environment variable
- The container SHALL receive LogConfiguration for CloudWatch logs

#### Scenario: Register task definition

- **WHEN** Terraform applies `aws_ecs_task_definition`
- **THEN** the task definition SHALL be registered with the family `coingecko-pipeline`
- **THEN** the container definition SHALL specify the ECR image URI from the pipeline repository
- **THEN** the container SHALL include environment variables for `DLT_DATA_DIR` and `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL`
- **THEN** the task SHALL stop automatically after 10 minutes if not completed

### Requirement: Pipeline ECR repository

The system SHALL create an ECR repository for the pipeline container image.

- The repository name SHALL be `coingecko-pipeline`
- The image tag mutability SHALL be `MUTABLE`
- The repository SHALL be created via Terraform

#### Scenario: Push pipeline image

- **WHEN** the Docker image is built and tagged with the ECR URI
- **THEN** the image SHALL be pushed to the `coingecko-pipeline` ECR repository via `docker push`

### Requirement: Orchestrator ECR repository

The system SHALL create an ECR repository for the Lambda orchestrator container image.

- The repository name SHALL be `coingecko-orchestrator`
- The image tag mutability SHALL be `MUTABLE`
- The repository SHALL be created via Terraform

#### Scenario: Push orchestrator image

- **WHEN** the Docker image is built and tagged with the ECR URI
- **THEN** the image SHALL be pushed to the `coingecko-orchestrator` ECR repository via `docker push`

### Requirement: ECS cluster

The system SHALL create an ECS cluster named `coingecko` to host the pipeline tasks.

- The cluster name SHALL be `coingecko`
- The cluster SHALL be configured with Fargate capacity providers
- The cluster SHALL be created via Terraform

#### Scenario: Create cluster

- **WHEN** Terraform applies `aws_ecs_cluster`
- **THEN** a cluster named `coingecko` SHALL exist
- **THEN** tasks SHALL be launchable with `FARGATE` launch type
