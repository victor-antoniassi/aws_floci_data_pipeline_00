# Project: data_pipeline_floci_openspec_test

## What
AWS data pipeline: CoinGecko API → dlt → S3 (Parquet).
Local simulation via Floci (Lambda + ECS Fargate + S3).

## Workflow
Changes managed via OpenSpec (see openspec/specs/). Use openspec-*
skills to propose, implement, and archive changes.

## Build & run
make bootstrap       # start Floci + terraform apply
make build-pipeline  # build pipeline Docker image
make build-orchestrator
make push-all        # push images to local ECR
make invoke          # trigger Lambda → ECS
make status          # check ECS tasks + S3 objects
make logs            # tail logs
make destroy         # terraform destroy + docker compose down

## Skills (global)
- `find-docs` — ~/.agents/skills/find-docs/ (outside repo, in home dir)

## Key facts
- Floci endpoint: http://localhost:4566 (needs healthcheck before use)
- Python via uv (see .opencode/rules/tooling.md)
- dlt secrets: .dlt/secrets.toml (gitignored)
- Terraform vars: infra/terraform.tfvars (gitignored, see terraform.tfvars.example)

## Hard rules
1. Code, docs, and commits in English; conversations in pt-br
2. Never commit real credentials, .env, or secrets files
