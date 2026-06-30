PROJECT_NAME   ?= coingecko
AWS_REGION     ?= us-east-1
ENDPOINT_URL ?= http://localhost:4566

PIPELINE_REPO     ?= $(PROJECT_NAME)-pipeline
ORCHESTRATOR_REPO ?= $(PROJECT_NAME)-orchestrator
REGISTRY          ?= localhost:5100

.PHONY: bootstrap build-pipeline build-orchestrator push-all invoke status logs destroy

bootstrap:
	@echo "Waiting for Floci to be healthy..."
	@curl --retry 30 --retry-connrefused --silent \
		$(ENDPOINT_URL)/_floci/health > /dev/null || \
		(echo "Floci healthcheck failed" && exit 1)
	@echo "Floci is healthy. Initializing Terraform..."
	cd infra && terraform init && terraform apply -auto-approve

build-pipeline:
	docker build -f docker/Dockerfile.pipeline \
		-t $(PIPELINE_REPO) . && \
	docker run --rm $(PIPELINE_REPO) \
		python -c "from pipeline.pipeline import pipeline; print('Pipeline entrypoint OK')"

build-orchestrator:
	docker build -f docker/Dockerfile.orchestrator \
		-t $(ORCHESTRATOR_REPO) . && \
	docker run --rm --entrypoint python $(ORCHESTRATOR_REPO) \
		-c "from handler import handler; print('Orchestrator entrypoint OK')"

push-all:
	aws --endpoint-url $(ENDPOINT_URL) ecr get-login-password \
		--region $(AWS_REGION) | \
		docker login --password-stdin --username AWS $(REGISTRY) && \
	docker tag $(PIPELINE_REPO) $(REGISTRY)/$(PIPELINE_REPO):latest && \
	docker tag $(ORCHESTRATOR_REPO) $(REGISTRY)/$(ORCHESTRATOR_REPO):latest && \
	docker push $(REGISTRY)/$(PIPELINE_REPO):latest && \
	docker push $(REGISTRY)/$(ORCHESTRATOR_REPO):latest

invoke:
	aws --endpoint-url $(ENDPOINT_URL) --region $(AWS_REGION) lambda invoke \
		--function-name $(PROJECT_NAME)-orchestrator \
		--payload '{}' \
		response.json && cat response.json && rm -f response.json

status:
	@echo "=== ECS Tasks ==="
	aws --endpoint-url $(ENDPOINT_URL) --region $(AWS_REGION) ecs list-tasks \
		--cluster $(PROJECT_NAME) \
		--desired-status STOPPED \
		--query 'taskArns' --output json
	@echo ""
	@echo "=== S3 Objects ==="
	aws --endpoint-url $(ENDPOINT_URL) --region $(AWS_REGION) s3api list-objects-v2 \
		--bucket $(PROJECT_NAME)-raw \
		--query 'Contents[*].Key' --output json 2>/dev/null || \
		echo "(no objects yet)"

logs:
	@echo "=== Lambda Log Streams ==="
	aws --endpoint-url $(ENDPOINT_URL) --region $(AWS_REGION) logs describe-log-streams \
		--log-group-name /aws/lambda/$(PROJECT_NAME)-orchestrator \
		--query 'logStreams[*].logStreamName' --output json 2>/dev/null || \
		echo "(no Lambda logs yet)"
	@echo ""
	@echo "=== ECS Log Streams ==="
	aws --endpoint-url $(ENDPOINT_URL) --region $(AWS_REGION) logs describe-log-streams \
		--log-group-name /ecs/$(PROJECT_NAME)-pipeline \
		--query 'logStreams[*].logStreamName' --output json 2>/dev/null || \
		echo "(no ECS logs yet)"

destroy:
	cd infra && terraform destroy -auto-approve; \
	docker compose down
