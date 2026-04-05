################################################################################
# 一覧
################################################################################
.PHONY: aws.status
aws.status: ## AWSのインスタンス状態とCFnスタック一覧
	@aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[].{Name:StackName,Created:CreationTime}' --output table

################################################################################
# CFnスタック作成と削除
################################################################################
.PHONY: aws.create-cfn
aws.create-cfn: ## AWSのCFnスタックを作成
	@aws cloudformation create-stack --stack-name ${STACK_NAME} --template-body file://handson/cloudformations/network.yml
	@echo "${STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME}

.PHONY: aws.delete-cfn
aws.delete-cfn: ## AWSのCFnスタック削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME)
	@echo 'After status'
	@make aws.status

