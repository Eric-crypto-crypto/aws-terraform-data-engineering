data "aws_caller_identity" "current" {}

resource "aws_iam_role" "glue_crawler" {
  name_prefix = "glue-crawler-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = [
            "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:crawler/nyc-yellow-2019-01",
            "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:crawler/nyc-yellow-parquet"
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler_s3_read" {
  name = "read-yellow-tripdata-prefix"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.data_lake_bucket.arn}/raw/yellow/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.data_lake_bucket.arn}/processed/yellow/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.data_lake_bucket.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "raw/yellow",
              "raw/yellow/*",
              "processed/yellow",
              "processed/yellow/*"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "glue_job" {
  name = "glue-ny-yellow-spark-job"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_job_service_role" {
  role       = aws_iam_role.glue_job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_job_s3" {
  name = "yellow-tripdata-s3-access"
  role = aws_iam_role.glue_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadRawYellow"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data_lake_bucket.arn}/raw/yellow/*"
      },
      {
        Sid      = "ReadGlueJobScript"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data_lake_bucket.arn}/scripts/yellow_tripdata_to_parquet.py"
      },
      {
        Sid    = "WriteProcessedYellow"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.data_lake_bucket.arn}/processed/yellow/*"
      },
      {
        Sid    = "ListRequiredPrefixes"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = aws_s3_bucket.data_lake_bucket.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "raw/yellow",
              "raw/yellow/*",
              "processed/yellow",
              "processed/yellow/*"
            ]
          }
        }
      },
      {
        Sid      = "GetBucketLocation"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation"]
        Resource = aws_s3_bucket.data_lake_bucket.arn
      }
    ]
  })
}
