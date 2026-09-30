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
          "aws:SourceArn" = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:crawler/nyc-yellow-2019-01"
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
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.data_lake_bucket.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "raw/yellow",
              "raw/yellow/*"
            ]
          }
        }
      }
    ]
  })
}
