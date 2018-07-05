# Place where the code and bootstrap script will be store
COG_EMR_S3_PREFIX := "s3://azavea-research-emr/cog-creator/spacenet"

# Vars related to spark run parameters
export DRIVER_MEMORY := 2000M
export DRIVER_CORES := 1
export EXECUTOR_MEMORY := 10000M
export EXECUTOR_CORES := 4
export YARN_OVERHEAD := 1500
