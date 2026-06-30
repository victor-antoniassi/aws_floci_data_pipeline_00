resource "aws_s3_bucket" "coingecko_raw" {
  bucket        = "coingecko-raw"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "coingecko_raw_versioning" {
  bucket = aws_s3_bucket.coingecko_raw.id
  versioning_configuration {
    status = "Enabled"
  }
}
