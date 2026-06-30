variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "coingecko"
}

variable "floci_endpoint" {
  description = "Floci endpoint URL for local AWS simulation (empty for real AWS)"
  type        = string
  default     = ""
}

variable "ecs_subnets" {
  description = "Subnets for ECS Fargate tasks"
  type        = list(string)
  default     = ["subnet-00000000000000000"]
}

variable "ecs_security_groups" {
  description = "Security groups for ECS Fargate tasks"
  type        = list(string)
  default     = ["sg-00000000000000000"]
}
