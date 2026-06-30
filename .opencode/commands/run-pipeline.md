---
description: Execute the data pipeline end-to-end (Floci → Terraform → Build → Push → Invoke → Verify)
agent: build
---

Execute the CoinGecko data pipeline: extract from CoinGecko API via dlt, load as Parquet to S3 (local Floci).

## Routing — read this before any steps

Check the value of `$ARGUMENTS` and jump directly to the corresponding section below.

| `$ARGUMENTS` | Go to section |
|---|---|---|
| *(empty or not provided)* | [Smart mode](#smart-mode) |
| `full` | [Full mode](#full-mode) |
| `bootstrap` | [Bootstrap mode](#bootstrap-mode) |
| `build` | [Build mode](#build-mode) |
| `invoke` | [Invoke mode](#invoke-mode) |
| `status` | [Status mode](#status-mode) |
| starts with `schedule` | [Schedule mode](#schedule-mode) — extract the rest as expression |
| `destroy` | [Destroy mode](#destroy-mode) |
| *anything else* | Stop and report: "Unknown mode: `$ARGUMENTS`. Valid modes: full, bootstrap, build, invoke, status, schedule, destroy." |

---

## Prerequisites (all modes)

Export dummy AWS credentials if not already set (Floci accepts any creds):

!`echo -n "${AWS_ACCESS_KEY_ID:-unset}"`

If unset: `export AWS_ACCESS_KEY_ID=test && export AWS_SECRET_ACCESS_KEY=test`

---

## Pipeline steps (reference)

These steps are referenced by the modes below. Each mode explicitly lists which steps to execute.

### Step 1 — Floci health
Check: !`curl -s -o /dev/null -w "%{http_code}" http://localhost:4566/_floci/health`

If not 200: `docker compose up -d`, then poll health endpoint every 5s until 200 (up to 60s).
If unhealthy after 60s: report error and stop.

### Step 2 — Terraform state
Check: !`terraform -chdir=infra state list 2>/dev/null | wc -l`

If 0 resources: run `make bootstrap` with AWS env vars set. Wait for apply to complete. If it fails, report and stop.
If resources exist: skip.

### Step 3 — Code changes / build images
Check: !`git diff --name-only HEAD -- src/ docker/`

If any files changed, or if Docker images `coingecko-pipeline` or `coingecko-orchestrator` don't exist locally:
`make build-pipeline && make build-orchestrator`
If clean and images exist: skip.

### Step 4 — Push images to ECR
Check: !`curl -s -o /dev/null -w "%{http_code}" http://localhost:5100/v2/coingecko-pipeline/manifests/latest`

If not 200: `make push-all` with AWS env vars set.
If 200 already: skip.

### Step 5 — Invoke Lambda
`make invoke` with AWS env vars set.

Capture the response JSON (status + taskArn).
If status is `"skipped"` (task already running), log and stop.

### Step 6 — Wait for ECS task
Poll ECS task every 5s until lastStatus becomes `STOPPED`:

!`aws --endpoint-url http://localhost:4566 --region us-east-1 ecs describe-tasks --cluster coingecko --tasks <TASK_ARN> --query 'tasks[0].lastStatus' --output text`

If exitCode != 0: report the error and stop.

### Step 7 — Verify
`make status` with AWS env vars set.
`make logs` with AWS env vars set.

Show: task exitCode, S3 object count, any log warnings or errors.

---

## Smart mode

Execute steps 1-7 with auto-detection (skip what's already done):

1. **Floci** — Check health. If 200, skip to step 2. If unhealthy, start Floci and wait.
2. **Terraform** — Check state resource count. If 0, bootstrap. If >0, skip.
3. **Build** — Check git diff and local images. If dirty or missing images, rebuild. If clean, skip.
4. **Push** — Check ECR registry. If missing, push. If present, skip.
5. **Invoke** — Invoke Lambda always. If skipped (task running), stop.
6. **Wait** — Poll ECS task until STOPPED. On failure, report and stop.
7. **Verify** — Run `make status` and `make logs`.

## Full mode

Execute all 7 steps unconditionally (no detection, execute every phase):

1. Start Floci: `docker compose up -d`, wait healthy.
2. Terraform: `make bootstrap` always.
3. Build: `make build-pipeline && make build-orchestrator` always.
4. Push: `make push-all` always.
5. Invoke Lambda.
6. Wait for ECS task completion.
7. Verify.

## Bootstrap mode

Execute steps 1-2 only:

1. Start Floci: `docker compose up -d`, wait healthy.
2. Terraform: `make bootstrap`.

The schedule is **disabled by default** (`enable_schedule = false`). No automatic pipeline executions will occur.

To enable scheduling after bootstrap: `/run-pipeline schedule "rate(1 hour)"`.

Stop here.

## Build mode

Execute steps 3-7 only (assumes Floci + terraform already ready):

1. Build images: `make build-pipeline && make build-orchestrator`.
2. Push to ECR: `make push-all`.
3. Invoke Lambda.
4. Wait for ECS task completion.
5. Verify.

Stop here.

## Invoke mode

Execute steps 5-7 only (assumes infra + images ready):

1. Invoke Lambda.
2. Wait for ECS task completion.
3. Verify.

Stop here.

## Status mode

Execute step 7 only — show current state without running pipeline:

1. `make status` with AWS env vars set.
2. `make logs` with AWS env vars set.
3. Print a readable summary of ECS tasks and S3 objects.

## Schedule mode

Configure the pipeline scheduling. The schedule is **disabled by default** — the pipeline only runs on manual `make invoke`. Enable it to simulate production behavior.

**Usage:** `/run-pipeline schedule "cron(0 8 * * ? *)"`

Argument handling:
- `$ARGUMENTS` starts with `schedule` — extract everything after the space as the expression
- Strip surrounding quotes if present
- Example: `$ARGUMENTS` = `schedule "cron(0 8 * * ? *)"` → expression = `cron(0 8 * * ? *)`

Steps:
1. **Floci health** — Same as Step 1 above. If unhealthy, start and poll.
2. **Terraform state** — Same as Step 2 above. If 0 resources, bootstrap first.
3. **Apply schedule** — `make enable-schedule EXPR="<expression>"` with AWS env vars set.
4. **Verify** — Run `make status` and check the schedule_status output.

To disable the schedule later: `make disable-schedule`.

**Important:** Toggling the schedule on/off does NOT destroy other infrastructure. The IAM roles, Lambda function, ECS resources, and S3 bucket remain intact. Use `make destroy` to tear down everything.

---

## Destroy mode

Tear down all infrastructure:

1. Export AWS credentials if unset.
2. `make destroy` with AWS env vars set.
3. Report: "Pipeline infrastructure destroyed."

---

## Notes

- All `make` targets inherit from the project Makefile (`PROJECT_NAME=coingecko`, `ENDPOINT_URL=http://localhost:4566`).
- The ECS container runs on `floci_network` and resolves `http://floci:4566` internally to reach S3.
- If CoinGecko returns errors, check `coingecko_api_key` in `infra/terraform.tfvars` (gitignored).
- The EventBridge Scheduler is **disabled by default**. Enable it with `make enable-schedule EXPR="rate(1 hour)"` to simulate production. Disable with `make disable-schedule`.
- This command does NOT modify source code or commit anything.

---

## Output format

Print a summary at the end:

| Step       | Status                                        |
|------------|-----------------------------------------------|
| Floci      | healthy / started                             |
| Terraform  | N resources / skipped                         |
| Build      | rebuilt / skipped (clean)                     |
| Push       | pushed / skipped (up to date)                 |
| Lambda     | 200 OK / skipped                              |
| ECS task   | STOPPED (exitCode 0) / RUNNING / FAILED       |
| S3 objects | N created (including *.parquet)               |
