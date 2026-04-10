################################################################################
# 一覧
################################################################################
.PHONY: aws.status
aws.status: ## AWSのインスタンス状態とCFnスタック一覧
	@aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[].{Name:StackName,Created:CreationTime}' --output table

################################################################################
# CFnスタック作成と削除
################################################################################
.PHONY: aws.create-base-cfn
aws.create-base-cfn: ## AWSのbase CFnスタックを作成
	@aws cloudformation create-stack --stack-name ${BASE_STACK_NAME} --template-body file://handson/cloudformations/network.yml
	@echo "${BASE_STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${BASE_STACK_NAME}

.PHONY: aws.delete-base-cfn
aws.delete-base-cfn: ## AWSの base CFnスタック削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(BASE_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(BASE_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-pseudo-cloud9-cfn
aws.create-pseudo-cloud9-cfn: aws.define-pseudo-cloud9-variables ## AWSの擬似 cloud9 CFnスタックを作成
	@aws cloudformation create-stack --stack-name ${PSEUDO_CLOUD9_STACK_NAME} --template-body file://handson/cloudformations/pseudo-cloud9.yml \
		--capabilities CAPABILITY_IAM \
		--parameters \
			ParameterKey=VpcId,ParameterValue=$(VPC_ID) \
			ParameterKey=SecurityGroupId,ParameterValue=$(SG_ID) \
			ParameterKey=ManagementSubnetId,ParameterValue=$(SUBNET_ID)
	@echo "${PSEUDO_CLOUD9_STACK_NAME}: 作成中です（約3分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${PSEUDO_CLOUD9_STACK_NAME}

.PHONY: aws.delete-pseudo-cloud9-cfn
aws.delete-pseudo-cloud9-cfn: ## AWSの擬似 cloud9 CFnスタックを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(PSEUDO_CLOUD9_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(PSEUDO_CLOUD9_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.show-defined-pseudo-cloud9-variables
aws.show-defined-pseudo-cloud9-variables: aws.define-pseudo-cloud9-variables ## 擬似 cloud9 CFnスタック作成に必要な環境変数を定義
	@echo "VPC_ID:     $(VPC_ID)"
	@echo "SG_ID:      $(SG_ID)"
	@echo "SUBNET_ID:  $(SUBNET_ID)"

aws.define-pseudo-cloud9-variables:
	$(eval VPC_ID     := $(shell aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sbcntr-main" --query "Vpcs[0].VpcId" --output text))
	$(eval SG_ID      := $(shell aws ec2 describe-security-groups --filters "Name=group-name,Values=management" "Name=vpc-id,Values=${VPC_ID}" --query "SecurityGroups[0].GroupId" --output text))
	$(eval SUBNET_ID  := $(shell aws ec2 describe-subnets --filters "Name=tag:Name,Values=sbcntr-public-management-a" --query "Subnets[0].SubnetId" --output text))
