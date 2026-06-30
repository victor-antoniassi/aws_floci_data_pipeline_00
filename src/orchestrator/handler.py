import json
import os

import boto3
from aws_lambda_powertools import Logger

logger = Logger()


def handler(event, context):
    logger.info("Received event", extra={"event": json.dumps(event, default=str)})

    ecs = boto3.client("ecs")

    cluster = os.environ["ECS_CLUSTER"]
    task_definition = os.environ["ECS_TASK_DEFINITION"]
    subnets = os.environ["ECS_SUBNETS"].split(",")
    security_groups = os.environ["ECS_SECURITY_GROUPS"].split(",")

    running = ecs.list_tasks(cluster=cluster, desiredStatus="RUNNING")

    if running.get("taskArns"):
        logger.warning("task already running", extra={"taskArns": running["taskArns"]})
        return {"status": "skipped", "reason": "task already running"}

    try:
        response = ecs.run_task(
            cluster=cluster,
            taskDefinition=task_definition,
            launchType="FARGATE",
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": subnets,
                    "securityGroups": security_groups,
                }
            },
            count=1,
        )

        task_arn = response["tasks"][0]["taskArn"]
        logger.info("Task started", extra={"taskArn": task_arn})
        return {"status": "started", "taskArn": task_arn}

    except Exception as exc:
        logger.exception("RunTask failed")
        raise
