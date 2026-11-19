resource "aws_s3_bucket" "suppressed" {
  bucket = "secure-delivery-example-suppressed"
}

resource "aws_s3_bucket_public_access_block" "suppressed" {
  bucket                  = aws_s3_bucket.suppressed.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
