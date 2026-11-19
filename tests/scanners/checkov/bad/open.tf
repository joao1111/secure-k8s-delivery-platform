resource "aws_s3_bucket" "open" {
  bucket = "secure-delivery-example-open"
}

resource "aws_s3_bucket_public_access_block" "open" {
  bucket                  = aws_s3_bucket.open.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
