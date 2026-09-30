terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#S3 Bucket to store data equivalent to GCS Bucket in GCP
resource "aws_s3_bucket" "data_lake_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

#Bucket verisioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.data_lake_bucket.id # Reference the S3 bucket created above

  versioning_configuration {
    status = "Enabled" # Enable versioning
  }
}

# "Uniform bucket level access" ~ control prin policy/ACL; recomandat: block public access
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.data_lake_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: delete objects older than 30 days (echivalent lifecycle_rule age=30)
# resource "aws_s3_bucket_lifecycle_configuration" "lifecycle_rules" {
#   bucket = aws_s3_bucket.data_lake_bucket.id

#   rule {
#     id     = "Delete_old_older_than_30_days"
#     status = "Enabled"

#     expiration {
#       days = 30
#     }
#     filter {
#       prefix = "" # Apply to all objects in the bucket
#     }
#   }
# }

resource "aws_glue_catalog_database" "dataset" {
  name = var.dataset_name
}

resource "aws_glue_crawler" "yellow_tripdata" {
  name          = "nyc-yellow-2019-01"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.dataset.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake_bucket.bucket}/raw/yellow/"
  }
}

resource "aws_glue_job" "yellow_tripdata_spark" {
  name              = "nyc-yellow-tripdata-parquet"
  role_arn          = aws_iam_role.glue_job.arn
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  max_retries       = 0
  timeout           = 10

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.data_lake_bucket.bucket}/scripts/yellow_tripdata_to_parquet.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}

resource "aws_glue_crawler" "yellow_parquet" {
  name          = "nyc-yellow-parquet"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.dataset.name
  table_prefix  = "parquet_"

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake_bucket.bucket}/processed/yellow/"
  }
}