## 1. Project scaffold

- [ ] 1.1 Create project directory structure (`src/pipeline/`, `src/orchestrator/`, `docker/`, `infra/`)
- [ ] 1.2 Create root `pyproject.toml` with `[project]` metadata and `[project.optional-dependencies]` groups (`pipeline = ["dlt>=1.0"]`, `orchestrator = ["boto3", "aws-lambda-powertools"]`)
- [ ] 1.3 Run `uv lock` to generate `uv.lock`, then verify `uv sync --group pipeline` and `uv sync --group orchestrator` both resolve cleanly
- [ ] 1.4 Create `.dlt/secrets.toml` with `bucket_url = "s3://coingecko-raw"` and dummy credentials
- [ ] 1.5 Create `.dlt/config.toml` with retry config (`request_max_attempts = 5`, `request_backoff_factor = 1`, `request_max_retry_delay = 30`, `request_max_requests_per_second = 10`)

## 2. Data pipeline core

- [ ] 2.1 Create `src/pipeline/pipeline.py` with CoinGecko source function using dlt's `RESTClient.get()` (not paginate — endpoint returns single page with `per_page=250`)
- [ ] 2.2 Configure the source to hit `/coins/markets?vs_currency=usd&per_page=250&sparkline=false`
- [ ] 2.3 Create the dlt pipeline definition in `pipeline.py` (`pipeline_name="coingecko"`, `destination="filesystem"`, `dataset_name="crypto_markets"`)
- [ ] 2.4 Create `src/pipeline/main.py` as the container entrypoint that calls `pipeline.run(source)` and catches exceptions with `sys.exit(1)`
- [ ] 2.5 Add import for `os` and set `DLT_DATA_DIR` environment variable in `main.py` before pipeline execution

## 3. Lambda orchestrator

- [ ] 3.1 Create `src/orchestrator/handler.py` with Lambda entry point accepting `event` and `context`
- [ ] 3.2 Implement `ecs.list_tasks(cluster=..., desiredStatus='RUNNING')` before `run_task()` — skip if running tasks exist
- [ ] 3.3 Implement `ecs.run_task()` call with configurable cluster, task definition, subnets, security groups from env vars
- [ ] 3.4 Return `{"status": "started", "taskArn": "<arn>"}` immediately on success (fire-and-forget, no polling)
- [ ] 3.5 Add structured logging with `aws-lambda-powertools` — log received event, concurrency decision, and RunTask result
- [ ] 3.6 Add error handling: log exception and raise on RunTask failure

## 4. Docker images

- [ ] 4.1 Create `docker/Dockerfile.pipeline` with `COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/`, `uv sync --locked --no-dev --group pipeline`, and `CMD ["python", "-m", "pipeline.main"]`
- [ ] 4.2 Create `docker/Dockerfile.orchestrator` with `COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/`, `uv sync --locked --no-dev --group orchestrator`, and `CMD ["handler.handler"]`
- [ ] 4.3 Create `.dockerignore` excluding unnecessary files (`.venv`, `.dlt`, `.git`, etc.)
- [ ] 4.4 Build both images locally and verify entrypoints work: `docker run --rm coingecko-pipeline python -m pipeline.main --help` and `docker run --rm coingecko-orchestrator python -c "import handler"`

## 5. Terraform infrastructure

- [ ] 5.1 Create `infra/main.tf` with required providers block (aws)
- [ ] 5.2 Create `infra/provider.tf` with configurable `floci_endpoint` variable and conditional endpoint overrides
- [ ] 5.3 Create `infra/variables.tf` with `project_name`, `floci_endpoint`, `ecs_subnets`, `ecs_security_groups` variables
- [ ] 5.4 Create `infra/s3.tf` with `aws_s3_bucket.coingecko_raw` and `aws_s3_bucket_versioning.coingecko_raw_versioning`
- [ ] 5.5 Create `infra/ecr.tf` with two ECR repositories (`coingecko-pipeline`, `coingecko-orchestrator`)
- [ ] 5.6 Create `infra/iam.tf` with Lambda execution role (ecs:RunTask, iam:PassRole, ecr permissions + logs), ECS task execution role (ecr + logs), ECS task role (s3:PutObject), EventBridge scheduler role (lambda:InvokeFunction, trust scheduler.amazonaws.com)
- [ ] 5.7 Create `infra/ecs.tf` with `aws_ecs_cluster.coingecko` and `aws_ecs_task_definition.coingecko_pipeline` (with `execution_timeout_minutes = 10`)
- [ ] 5.8 Create `infra/lambda.tf` with `aws_lambda_function.orchestrator` using `package_type = "Image"` and `image_uri` (no `archive_file` or `filename`)
- [ ] 5.9 Create `infra/lambda.tf` with `aws_lambda_permission` using principal `scheduler.amazonaws.com`
- [ ] 5.10 Create `infra/scheduler.tf` with `aws_scheduler_schedule.coingecko_hourly` targeting Lambda ARN with `rate(1 hour)`
- [ ] 5.11 Create `infra/scheduler.tf` with `aws_cloudwatch_event_rule.ecs_task_state_change` capturing `aws.ecs` detail-type, routing to CloudWatch Logs
- [ ] 5.12 Create `infra/outputs.tf` with S3 bucket ARN, Lambda ARN, ECR URLs (map), ECS cluster name, task definition ARN
- [ ] 5.13 Create `infra/terraform.tfvars` with `floci_endpoint = "http://localhost:4566"` and placeholder subnets/security groups for Fargate
- [ ] 5.14 Create `infra/terraform.tfvars.example` (same as tfvars, documented for reference)

## 6. Local environment

- [ ] 6.1 Create `docker-compose.yml` with `floci/floci:latest`, docker.sock mount, `FLOCI_HOSTNAME=floci`, and `FLOCI_SERVICES_ECS_MOCK=false`
- [ ] 6.2 Create root `Makefile` with targets: `bootstrap`, `build-pipeline`, `build-orchestrator`, `push-all`, `invoke`, `status`, `logs`, `destroy`
- [ ] 6.3 The `bootstrap` target SHALL wait for Floci healthcheck (`curl --retry 30 --retry-connrefused http://localhost:4566/_floci/health`) before running Terraform

## 7. End-to-end verification

- [ ] 7.1 Run `docker compose up -d` and confirm Floci is healthy on `http://localhost:4566` via `curl /_floci/health`
- [ ] 7.2 Run `make bootstrap` and confirm Terraform creates all resources successfully (2 ECR repos, S3 bucket with versioning, ECS cluster, Lambda with image_uri, EventBridge schedule + ECS state change rule)
- [ ] 7.3 Run `make build-pipeline && make build-orchestrator && make push-all` and confirm both images appear in Floci ECR
- [ ] 7.4 Run `make invoke` and confirm: Lambda returns task ARN, ECS task executes container, Parquet appears in S3 bucket
- [ ] 7.5 Run `make status` and confirm: ECS task shows STOPPED with exitCode=0, S3 object count > 0
- [ ] 7.6 Verify Parquet files are readable with `pyarrow` or similar tool
- [ ] 7.7 Run `make logs` and confirm CloudWatch log groups contain Lambda invocation log and ECS task log
- [ ] 7.8 Run `make destroy` and confirm all resources are cleaned up
