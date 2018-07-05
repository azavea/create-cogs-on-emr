ifndef AWS_PROFILE
$(error AWS_PROFILE is not set)
endif

include options.mk

CLUSTER_ID ?= $(shell cd terraform && terraform output | grep emr-id | awk '{print $$NF}')
MASTER_IP ?= $(shell cd terraform && terraform output | grep emr-master | awk '{print $$NF}')
KEY_NAME ?= $(shell cd terraform && terraform output | grep key-name | awk '{print $$NF}')
KEY_PATH ?= "~/.ssh/${KEY_NAME}.pem"

COG_EMR_S3_PREFIX := "s3://azavea-research-emr/cog-creator/spacenet"

terraform-init:
	cd terraform; terraform init

terraform-plan: terraform-init
	cd terraform; $(AWS_ENV_VARS) terraform plan \
		-var-file="../tfvars" \
		-var "aws_profile=${AWS_PROFILE}" \
		-var "bootstrap_script=${COG_EMR_S3_PREFIX}/bootstrap.sh" \
		-out="cluster-tfplan"

create-cluster: terraform-plan
	cd terraform; $(AWS_ENV_VARS) terraform apply "cluster-tfplan"

validate-cluster:
	cd terraform; $(AWS_ENV_VARS) terraform validate \
		--var-file="../tfvars" \
		-var "bootstrap_script=${COG_EMR_S3_PREFIX}/bootstrap.sh" \
		-var "aws_profile=${AWS_PROFILE}"

upload-code:
	aws s3 cp src/create_cogs.py ${COG_EMR_S3_PREFIX}/create_cogs.py

	aws s3 cp terraform/conf/bootstrap.sh ${COG_EMR_S3_PREFIX}/bootstrap.sh

run:
	aws emr add-steps --cluster-id ${CLUSTER_ID} \
	--steps Type=Spark,Name="COG Creation - ${USER}",\
	ActionOnFailure=CONTINUE,\
	Args=[--master,yarn,--deploy-mode,cluster,\
--driver-memory,${DRIVER_MEMORY},\
--driver-cores,${DRIVER_CORES},\
--executor-memory,${EXECUTOR_MEMORY},\
--executor-cores,${EXECUTOR_CORES},\
--conf,spark.driver.maxResultSize=3g,\
--conf,spark.dynamicAllocation.enabled=true,\
--conf,spark.yarn.executor.memoryOverhead=${YARN_OVERHEAD},\
--conf,spark.yarn.driver.memoryOverhead=${YARN_OVERHEAD},\
${COG_EMR_S3_PREFIX}/create_cogs.py,\
] | cut -f2 | tee last-step-id.txt

terminate-cluster:
	cd terraform; $(AWS_ENV_VARS) terraform destroy \
		-var-file="../tfvars" \
		-var "aws_profile=${AWS_PROFILE}" \
		-var "bootstrap_script=${COG_EMR_S3_PREFIX}/bootstrap.sh"

ssh:
	$(AWS_ENV_VARS) aws emr ssh \
		--cluster-id ${CLUSTER_ID} \
		--key-pair-file ${KEY_PATH}

proxy:
	ssh -i ${KEY_PATH} -ND 8157 hadoop@${MASTER_IP}

print-vars:
	echo aws_profile: ${AWS_PROFILE}
	echo cluster_id: ${CLUSTER_ID}
	echo key_name: ${KEY_NAME}
	echo key_path: ${KEY_PATH}
	echo master_ip: ${MASTER_IP}
	echo env_vars: ${AWS_ENV_VARS}
