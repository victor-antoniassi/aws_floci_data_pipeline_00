resource "aws_ecr_repository" "coingecko_pipeline" {
  name                 = "coingecko-pipeline"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "coingecko_orchestrator" {
  name                 = "coingecko-orchestrator"
  image_tag_mutability = "MUTABLE"
}
