import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(sys.argv, ["JOB_NAME"])

spark_context = SparkContext.getOrCreate()
glue_context = GlueContext(spark_context)
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

source = glue_context.create_dynamic_frame.from_catalog(
    database="aws-terraform-ny-taxi-dataset",
    table_name="yellow",
)

source.printSchema()

glue_context.write_dynamic_frame.from_options(
    frame=source,
    connection_type="s3",
    connection_options={
        "path": "s3://aws-terraform-ny-taxi-raw-data-12345/processed/yellow/run-001/"
    },
    format="parquet",
    format_options={"compression": "snappy"},
)

job.commit()