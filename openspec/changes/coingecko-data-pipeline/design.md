## Context

Greenfield project: a production-grade data pipeline for cryptocurrency market data, designed to be run and tested entirely locally via Floci while mirroring real AWS deployment patterns. The pipeline fetches data from CoinGecko `/coins/markets`, ingests it via dlt, and stores Parquet files in S3.

The architecture follows a professional separation of concerns: a lightweight Lambda function (container image) orchestrates execution by calling ECS RunTask, keeping the orchestrator stateless and the heavy data processing in a dedicated container with no timeout limitations. Both the Lambda and the ECS task are deployed as container images to ECR with uv dependency management.

## Goals / Non-Goals

**Goals:**
- Ingest top 250 coins by market cap from CoinGecko `/coins/markets` on a scheduled basis
- Store data as Parquet in an S3 bucket with dlt's inferred schema
- Trigger execution via both cron schedule (EventBridge Scheduler) and manual invocation
- Orchestrate via Lambda (container image) calling ECS RunTask (not executing the pipeline inside Lambda itself)
- Run the dlt pipeline in an ECS Fargate container with no time limit
- Define all AWS resources declaratively with Terraform
- Deploy both Lambda and ECS task as container images from ECR
- Build both images with a single uv-based workflow (optional-dependency groups)
- Simulate entirely locally using Floci with real Docker container execution
- Monitor pipeline outcomes via EventBridge ECS Task State Change → CloudWatch Logs
- Same Terraform code works against real AWS by removing the `endpoints` block

**Non-Goals:**
- Real AWS deployment (future project)
- CI/CD pipeline
- Monitoring dashboards and alerts
- Data quality checks and validation
- Multi-environment Terraform workspaces
- CoinGecko API key / paid tier integration
- Incremental or delta loads (full refresh only)
- Athena/Glue catalog integration

## Decisions

### 1. Lambda orchestrator instead of long-running Lambda

| Option | Rationale |
|--------|-----------|
| **Chosen: Lambda → ECS RunTask** | Lambda is stateless orchestrator; ECS has no 15-min timeout, handles long pipelines, production standard pattern |
| Lambda container with heavy processing | 15-min timeout limits scale; hard to debug; couples orchestration and processing |
| ECS-only (direct EventBridge → ECS) | Loses ability to add pre/post processing logic, retry logic, or conditional execution in the future |

### 2. dlt (Data Load Tool) as ingestion framework

| Option | Rationale |
|--------|-----------|
| **Chosen: dlt** | Auto-schema inference, built-in RESTClient, filesystem destination with Parquet, config via env vars/toml, retry/backoff built-in |
| Manual requests + pandas + boto3 | More boilerplate, no schema management, no built-in retry |
| Airbyte | Overkill for single endpoint; heavy container; not aligned with study goal |

Note: dlt's `RESTClient.get()` is used instead of `paginate()` because CoinGecko `/coins/markets` with `per_page=250` returns all data in a single page — no pagination needed.

### 3. ECS Fargate for container execution

| Option | Rationale |
|--------|-----------|
| **Chosen: ECS Fargate** | No EC2 management, Floci executes real Docker containers for ECS tasks, unlimited execution time, production standard |
| Lambda container | 15-min timeout (same as zip), not suitable for pipeline simulation at real scale |
| EC2 + systemd | Overkill for PoC; defeats serverless purpose |

### 4. Floci for local AWS simulation

| Option | Rationale |
|--------|-----------|
| **Chosen: Floci** | Free, open-source, runs real Docker containers for Lambda and ECS via docker.sock, supports all required services (S3, ECR, ECS, Lambda, EventBridge, IAM, CloudWatch) |
| LocalStack Pro | Paid for ECS container execution; features comparable to free Floci |
| moto | Python-only API mocking; Lambda and ECS container execution not supported |
| Real AWS sandbox | Costs money, requires internet, slower iteration |

### 5. Terraform over shell scripts

| Option | Rationale |
|--------|-----------|
| **Chosen: Terraform** | Declarative, idempotent, stateful diff, same config works with Floci or real AWS, industry standard for IaC |
| Shell scripts | Imperative, error-prone, hard to version, no drift detection |
| CloudFormation | Tied to AWS; harder to test locally; verbose |

### 6. Configuration layering

dlt reads config in cascade: **environment variables > secrets.toml > config.toml**. This allows the same code and Docker image to work in both Floci (env vars with `endpoint_url`) and real AWS (env vars without).

The `.dlt/secrets.toml` file commits the `bucket_url` structure but NOT `endpoint_url` — the endpoint comes from env vars injected by the ECS task definition. This keeps the image portable.

`pyproject.toml` uses `[project.optional-dependencies]` groups (`pipeline` and `orchestrator`) so each Dockerfile installs only its required dependencies with `uv sync --group <name>`.

### 7. Data format and partitioning

dlt's filesystem destination with Parquet format. Default layout uses load_id for partitioning. No custom partitioning strategy for MVP — avoids premature optimization.

### 8. Lambda container image instead of zip

| Option | Rationale |
|--------|-----------|
| **Chosen: Container image (ECR)** | Same uv-based build workflow as ECS task; Floci supports Lambda container images natively; no archive_file complexity; consistent dependency management |
| Zip deployment | Requires `uv pip install --target` or separate requirements.txt; dual build workflow; archive_file Terraform data source needed |

### 9. Optional-dependencies groups in pyproject.toml

| Option | Rationale |
|--------|-----------|
| **Chosen: `[project.optional-dependencies]` groups** | Single pyproject.toml, each Dockerfile syncs only its group (`pipeline` or `orchestrator`), no duplicated lockfiles, consistent version pinning |
| Separate pyproject.toml per service | Duplicated tooling config, harder to maintain for a small project |
| Single set of deps | Pulls dlt into the Lambda zip for no reason; wastes cold start time |

### 10. Fire-and-forget Lambda (no polling)

| Option | Rationale |
|--------|-----------|
| **Chosen: Fire-and-forget + EventBridge monitoring** | Lambda returns immediately with task ARN; ECS state change events are captured by EventBridge → CloudWatch for asynchronous observability; decoupled and professional |
| Lambda polls ECS until task completes | Lambda runs for the entire pipeline duration; wastes Lambda execution time; risk of hitting 15-min timeout |
| Step Functions orchestration | Adds another AWS service to learn; overkill for a single-step pipeline |

### 11. ECS task concurrency control

| Option | Rationale |
|--------|-----------|
| **Chosen: `ecs.list_tasks()` check in Lambda** | Prevents duplicate pipeline runs when the previous run exceeds the 1-hour schedule interval; simple, no additional infrastructure |
| No concurrency control | Risk of overlapping pipeline runs; potential duplicate data and API rate limit issues |
| SQS-based queue with deduplication | Overengineered for a PoC; adds latency and complexity |

## Architecture

```
                              ┌──────────────────────────────────┐
                              │         docker-compose           │
                              │                                  │
                              │  ┌────────────────────────────┐  │
                              │  │         Floci              │  │
                              │  │    (http://floci:4566)     │  │
                              │  │                            │  │
                              │  │  ┌──────────────────────┐  │  │
              ┌──────────────────  │  │  EventBridge        │  │  │
              │                │  │  │  Scheduler          │  │  │
              │                │  │  │  rate(1 hour)       │  │  │
              ▼                │  │  └─────────┬────────────┘  │  │
┌────────────────────┐       │  │            │                │  │
│   Manual invoke     │       │  │            ▼                │  │
│   aws lambda invoke │───────┼──│  ┌──────────────────────┐  │  │
└────────────────────┘       │  │  │  Lambda orchestrator  │  │  │
                           │  │  │  (container image)     │  │  │
                           │  │  │  handler.handler       │  │  │
                           │  │  │  list_tasks + run_task │  │  │
                           │  │  └──────┬───────────┬─────┘  │  │
                           │  │         │           │        │  │
                           │  │         │           │        │  │
                           │  │         ▼           │        │  │
                           │  │  ┌──────────────────────┐   │  │
                           │  │  │  ECS Fargate         │   │  │
                           │  │  │  coingecko-pipeline  │   │  │
                           │  │  │                      │   │  │
                           │  │  │  ┌────────────────┐  │   │  │
                           │  │  │  │ Container      │  │   │  │
                           │  │  │  │                │  │   │  │
         HTTPS                     │  │  dlt.run()    │  │   │  │
    ┌─────────────────┐    │  │  │  │    │          │  │   │  │
    │  CoinGecko API  │◀───┼──┼──┼──│    ├─────────│──┼───┼──┼── Internet
    │  /coins/markets │    │  │  │  │    │          │  │   │  │
    └─────────────────┘    │  │  │  │    ▼          │  │   │  │
                           │  │  │  │  S3 (Floci)   │  │   │  │
                           │  │  │  │  parquet      │──┼───┼──┼──▶ S3 bucket
                           │  │  │  └────────────────┘  │   │  │
                           │  │  └──────────────────────┘   │  │
                           │  │                             │  │
                           │  │  ┌──────────────────────┐   │  │
                           │  │  │  ECR                  │   │  │
                           │  │  │  ┌────────────────┐   │   │  │
                           │  │  │  │ pipeline       │───┼───┼──┼── docker build
                           │  │  │  ├────────────────┤   │   │  │  (uv sync)
                           │  │  │  │ orchestrator   │───┼───┼──┼── docker build
                           │  │  │  └────────────────┘   │   │  │  (uv sync)
                           │  │  └──────────────────────┘   │  │  │
                           │  │                             │  │  │
                           │  │  ┌──────────────────────┐   │  │  │
                           │  │  │  IAM (emulado)       │   │  │  │
                           │  │  └──────────────────────┘   │  │  │
                           │  │                             │  │  │
                           │  │  ┌──────────────────────┐   │  │  │
                           │  │  │  CloudWatch Logs     │◀──┼──┼──┼── ECS state
                           │  │  │  (Lambda + ECS + EB) │   │  │  │  change events
                           │  │  └──────────────────────┘   │  │  │
                           │  └────────────────────────────┘  │  │
                           │                                  │  │
                           │  volumes:                         │  │
                           │    /var/run/docker.sock           │  │
                           │  environment:                     │  │
                           │    FLOCI_HOSTNAME=floci           │  │
                           └──────────────────────────────────┘  │
```

## Data Flow

```
1. EventBridge sends "scheduled-event" to Lambda OR user invokes manually

2. Lambda handler receives event, checks for running tasks:
     running = ecs.list_tasks(cluster="coingecko", desiredStatus="RUNNING")
     if running: log "already running", return skip response

3. Lambda calls (if no running tasks):
     ecs.run_task(
       cluster="coingecko",
       taskDefinition="coingecko-pipeline:latest",
       launchType="FARGATE",
       networkConfiguration={ awsvpcConfiguration={ subnets, securityGroups } }
     )

4. Lambda returns immediately with {"status": "started", "taskArn": "<arn>"}

5. Floci ECS pulls image from Floci ECR, spawns Docker container

6. Container runs main.py:
     dlt.pipeline(
       pipeline_name="coingecko",
       destination="filesystem",
       dataset_name="crypto_markets",
     ).run(coingecko_source())
       │
       ├── GET /coins/markets?vs_currency=usd&per_page=250&sparkline=false
       │     → CoinGecko API (HTTPS public internet)
       │     → returns JSON array
       │
       ├── dlt normalizes data, infers schema
       │
       └── dlt filesystem destination writes Parquet to:
             s3://coingecko-raw/crypto_markets/{load_id}.parquet
             (via Floci endpoint http://floci:4566)

7. Container exits. ECS task transitions to STOPPED with exit code:
     exitCode=0  → success
     exitCode!=0 → failure (dlt exception)

8. EventBridge receives ECS Task State Change event from the cluster
     → Routes to CloudWatch Logs for observability

9. Lambda already returned — no waiting involved
```

## Terraform Resource Map

```
main.tf
├── s3.tf               # aws_s3_bucket.coingecko_raw (with versioning)
├── ecr.tf              # aws_ecr_repository.coingecko_pipeline
│                       # aws_ecr_repository.coingecko_orchestrator
├── iam.tf              # aws_iam_role.lambda_exec, ecs_task, ecs_exec, eventbridge
│                       # aws_iam_policy for each role
├── ecs.tf              # aws_ecs_cluster.coingecko
│                       # aws_ecs_task_definition.pipeline (with execution_timeout)
├── lambda.tf           # aws_lambda_function.orchestrator (package_type = "Image")
│                       # aws_lambda_permission.eventbridge (principal=scheduler)
├── scheduler.tf        # aws_scheduler_schedule.coingecko_hourly
│                       # aws_cloudwatch_event_rule.ecs_state_change
│                       # aws_cloudwatch_event_target.ecs_state_change
├── provider.tf         # AWS provider with Floci endpoints
└── outputs.tf          # bucket ARN, Lambda ARN, ECR URIs, cluster name, task def ARN
```

## Network Topology (Floci)

When Floci runs with `docker.sock` mounted:
1. Lambda containers are auto-attached to the docker-compose network
2. Floci injects `AWS_ENDPOINT_URL=http://floci:4566` into Lambda containers automatically
3. ECS task containers are launched on `FLOCI_SERVICES_ECS_DOCKER_NETWORK`
4. Both Lambda and ECS containers resolve `floci` via Docker DNS to reach the Floci API
5. ECS container accesses CoinGecko API via outbound internet (Docker's default bridge)

Connection matrix:

| From | To | Address | How |
|------|----|---------|-----|
| Lambda | Floci (ECS API) | http://floci:4566 | Auto-injected by Floci |
| ECS task | Floci (S3 API) | http://floci:4566 | `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL` env var |
| ECS task | CoinGecko API | api.coingecko.com | HTTPS via Docker NAT |
| Lambda | ECR | http://floci:4566 | Auto-injected by Floci |
| ECS task | ECR | http://floci:4566 | Implicit via Floci |

## Docker image build workflow

Both images are built with the same uv-based pattern:

```
pyproject.toml
  [project.optional-dependencies]
  pipeline = ["dlt>=1.0"]
  orchestrator = ["boto3", "aws-lambda-powertools"]

docker/Dockerfile.pipeline:
  FROM python:3.12-slim
  COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/
  COPY pyproject.toml uv.lock ./
  RUN uv sync --locked --no-dev --group pipeline
  COPY src/pipeline/ /app/
  ENV PATH="/app/.venv/bin:$PATH"
  CMD ["python", "-m", "pipeline.main"]

docker/Dockerfile.orchestrator:
  FROM python:3.12-slim
  COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/
  COPY pyproject.toml uv.lock ./
  RUN uv sync --locked --no-dev --group orchestrator
  COPY src/orchestrator/handler.py /var/task/
  ENV PATH="/var/task/.venv/bin:$PATH"
  CMD ["handler.handler"]
```

## DLT_DATA_DIR

The ECS container writes temporary dlt data to `/tmp/dlt_data` via `DLT_DATA_DIR` env var. The Lambda's `/tmp` is not involved — the pipeline runs in the ECS container with its own ephemeral storage.

## Monitoring pipeline outcomes

Pipeline execution outcomes are observed through two complementary mechanisms:

1. **Container exit code (synchronous per task)**: dlt raises an exception on failure → container `sys.exit(1)` → ECS reports `exitCode=1` in task state → `make status` shows last task result
2. **EventBridge ECS Task State Change → CloudWatch (asynchronous)**: Every task state transition emits an event to EventBridge, captured by a rule that routes to CloudWatch Logs. The Lambda result itself can be checked via `make logs` or `make invoke` output.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| CoinGecko rate limiting (429) | Top 250 coins fetched in 1 page (`per_page=250`). `request_max_requests_per_second` configured. Retry/backoff for resilience. |
| Concurrent pipeline runs (next tick before previous finishes) | Lambda checks `ecs.list_tasks()` before launching new run |
| Floci ECS container execution fails without docker.sock | Documented requirement: mount `/var/run/docker.sock` |
| Floci and real AWS behavior may diverge | Keep Terraform provider endpoints configurable via variable; test patterns not behavior |
| dlt schema changes across versions | Pin dlt version in pyproject.toml; reviewed at upgrade |
| No data quality validation in MVP | Accepted trade-off; schema coersion via dlt's type inference provides basic safety |
| Pipeline runs indefinitely if API hangs | `execution_timeout_minutes = 10` in ECS task definition |
