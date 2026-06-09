## ADDED Requirements

### Requirement: docker-compose for Floci

The system SHALL provide a `docker-compose.yml` that runs Floci with real Docker container execution support.

- The Floci image SHALL be `floci/floci:latest`
- The container SHALL expose port `4566`
- The container SHALL mount `/var/run/docker.sock` to enable real container execution for Lambda and ECS
- The `FLOCI_HOSTNAME` SHALL be set to `floci` so spawned containers resolve Floci by service name
- The `FLOCI_SERVICES_ECS_MOCK` SHALL be `false` (real containers, not mock)

#### Scenario: Start Floci

- **WHEN** `docker compose up -d` runs
- **THEN** Floci SHALL start on `http://localhost:4566`
- **THEN** ECS tasks triggered by the system SHALL run as real Docker containers

### Requirement: Makefile

The system SHALL provide a Makefile with the following targets:

- `bootstrap`: Start Floci, wait for healthcheck, run Terraform init and apply
- `build-pipeline`: Build the Docker image for the dlt pipeline
- `build-orchestrator`: Build the Docker image for the Lambda orchestrator
- `push-all`: Tag and push both images to ECR
- `invoke`: Invoke the Lambda orchestrator manually
- `status`: Check ECS task state and verify Parquet files exist in S3
- `logs`: Tail CloudWatch logs for the Lambda function and ECS task
- `destroy`: Destroy Terraform resources and stop Floci

#### Scenario: Bootstrap workflow

- **WHEN** `make bootstrap` runs
- **THEN** Floci SHALL start
- **THEN** the script SHALL wait for Floci to be healthy (`curl --retry 30 --retry-connrefused http://localhost:4566/_floci/health`)
- **THEN** Terraform SHALL init and apply
- **THEN** the user SHALL run `make build-pipeline && make build-orchestrator && make push-all` separately (configuration step)

#### Scenario: Full run cycle

- **WHEN** the user runs `make invoke`
- **THEN** the Lambda orchestrator SHALL be invoked
- **THEN** the ECS pipeline container SHALL execute
- **THEN** Parquet files SHALL appear in S3
- **WHEN** the user runs `make status`
- **THEN** the last ECS task state and S3 Parquet file count SHALL be displayed

### Requirement: dlt secrets.toml

The system SHALL provide a `.dlt/secrets.toml` file with the basic filesystem destination configuration.

- The SHALL define `bucket_url = "s3://coingecko-raw"`
- The SHALL include dummy AWS credentials (`test`/`test`) for local development
- The SHALL NOT hardcode `endpoint_url` — this SHALL come from environment variables

#### Scenario: dlt reads config

- **WHEN** the pipeline runs inside the ECS container
- **THEN** dlt SHALL read `bucket_url` from `secrets.toml`
- **THEN** dlt SHALL read `endpoint_url` from the `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL` env var (overriding secrets.toml)
