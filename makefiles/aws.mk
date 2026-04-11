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
	$(eval MY_IP := $(shell curl -fsS https://checkip.amazonaws.com))
	@aws cloudformation create-stack --stack-name ${BASE_STACK_NAME} --template-body file://handson/cloudformations/network.yml --parameters \
		ParameterKey=MyIp,ParameterValue=$(MY_IP)
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
			ParameterKey=ManagementSubnetId,ParameterValue=$(SUBNET_ID) \
			ParameterKey=GitHubUserName,ParameterValue=$(GITHUB_USERNAME)

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

.PHONY: aws.create-registry-cfn
aws.create-registry-cfn: ## AWSのRegistryスタックを作成
	@aws cloudformation create-stack --stack-name ${REGISTRY_STACK_NAME} --template-body file://handson/cloudformations/registry.yml
	@echo "${REGISTRY_STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${REGISTRY_STACK_NAME}

.PHONY: aws.delete-registry-cfn
aws.delete-registry-cfn: ## AWSのRegistryスタックを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(REGISTRY_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(REGISTRY_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-network-vpc-endpoint-step1-cfn
aws.create-network-vpc-endpoint-step1-cfn: aws.define-network-vpc-endpoints-step1-variables ## ECRへのネットワーク経路となる、VPCエンドポイントを作成
	@aws cloudformation create-stack --stack-name ${NETWORK_VPC_ENDPOINT_STEP1_STACK_NAME} --template-body file://handson/cloudformations/network_vpc_endpoint_step1.yml \
		--parameters \
			ParameterKey=VpcId,ParameterValue=$(VPC_ID) \
			'ParameterKey=SubnetIds,ParameterValue="$(SUBNET_IDS)"' \
			ParameterKey=SecurityGroupIds,ParameterValue=$(SG_ID) \
			ParameterKey=RouteTableId,ParameterValue=$(ROUTE_TABLE_ID)

	@echo "${NETWORK_VPC_ENDPOINT_STEP1_STACK_NAME}: 作成中です（約1.5分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${NETWORK_VPC_ENDPOINT_STEP1_STACK_NAME}

.PHONY: aws.delete-network-vpc-endpoint-step1-cfn
aws.delete-network-vpc-endpoint-step1-cfn: ## ECRへのネットワーク経路となる、VPCエンドポイントを作成
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(NETWORK_VPC_ENDPOINT_STEP1_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(NETWORK_VPC_ENDPOINT_STEP1_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.show-defined-pseudo-cloud9-variables
aws.show-defined-pseudo-cloud9-variables: aws.define-pseudo-cloud9-variables ## 擬似 cloud9 CFnスタック作成に必要な環境変数を定義
	@echo "VPC_ID:     $(VPC_ID)"
	@echo "SG_ID:      $(SG_ID)"
	@echo "SUBNET_ID:  $(SUBNET_ID)"

.PHONY: aws.show-defined-network-vpc-endpoints-step1-variables
aws.show-defined-network-vpc-endpoints-step1-variables: aws.define-network-vpc-endpoints-step1-variables ## ECRへのネットワーク経路となる、VPCエンドポイントを作成するための環境変数
	@echo "VPC_ID:               $(VPC_ID)"
	@echo "SG_ID:                $(SG_ID)"
	@echo "SUBNET_IDS:           $(SUBNET_IDS)"
	@echo "ROUTE_TABLE_ID:       $(ROUTE_TABLE_ID)"

###############################################################################
# SSHの設定
################################################################################
.PHONY: aws.setup-ssh-config
aws.setup-ssh-config: validate-ssh-private-key ## SSH設定をセットアップ
	$(eval PSEUDO_CLOUD9_STACK_ID := $(shell aws cloudformation describe-stacks --stack-name $(PSEUDO_CLOUD9_STACK_NAME) --query 'Stacks[0].StackId' --output text))
	$(eval PSEUDO_CLOUD9_HOST_IP := $(shell aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-id,Values=$(PSEUDO_CLOUD9_STACK_ID)" 'Name=tag:Name,Values=sbcntr-pseudo-cloud9' --query 'Reservations[0].Instances[0].PublicIpAddress' --output text))
	@sed \
		-e "s|{{SSH_PRIVATE_KEY_PATH}}|${SSH_PRIVATE_KEY_PATH}|g" \
		-e "s|{{PSEUDO_CLOUD9_HOST_IP}}|$(PSEUDO_CLOUD9_HOST_IP)|g" \
		.ssh/ssh_config.tmpl > .ssh/config

aws.define-pseudo-cloud9-variables:
	$(eval VPC_ID     := $(shell aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sbcntr-main" --query "Vpcs[0].VpcId" --output text))
	$(eval SG_ID      := $(shell aws ec2 describe-security-groups --filters "Name=group-name,Values=management" "Name=vpc-id,Values=${VPC_ID}" --query "SecurityGroups[0].GroupId" --output text))
	$(eval SUBNET_ID  := $(shell aws ec2 describe-subnets --filters "Name=tag:Name,Values=sbcntr-public-management-a" --query "Subnets[0].SubnetId" --output text))

aws.define-network-vpc-endpoints-step1-variables:
	$(eval VPC_ID               := $(shell aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sbcntr-main" --query "Vpcs[0].VpcId" --output text))
	$(eval SUBNET_IDS           := $(shell aws ec2 describe-subnets --filters "Name=tag:Name,Values=sbcntr-private-egress-*" --query "Subnets[].SubnetId" --output text | tr '\t' ','))
	$(eval SG_ID                := $(shell aws ec2 describe-security-groups --filters "Name=group-name,Values=egress" "Name=vpc-id,Values=${VPC_ID}" --query "SecurityGroups[0].GroupId" --output text))
	$(eval ROUTE_TABLE_ID       := $(shell aws ec2 describe-route-tables --filters "Name=tag:Name,Values=sbcntr-app" --query "RouteTables[0].RouteTableId" --output text))

# SSH秘密鍵の検証
# SSH_PRIVATE_KEY_PATHが指す秘密鍵の公開鍵がGitHubアカウントに登録されているか確認
# 理由: EC2に登録する公開鍵は https://github.com/${GITHUB_USERNAME}.keys を利用しているため
# GITHUB_USERNAMEは.envrc.overrideに記載
validate-ssh-private-key:
	$(eval PUBLIC_KEY := $(shell ssh-keygen -y -f ${SSH_PRIVATE_KEY_PATH} | cut -d ' ' -f1,2))
	@test -n "$${GITHUB_USERNAME:-}" || { \
		echo '----[ERROR]----' >&2; \
		echo 'GITHUB_USERNAMEが設定されていません' >&2; \
		echo 'cp .envrc.override.sample .envrc.overrideを実施し、' >&2; \
		echo 'GitHubアカウント名(GITHUB_USERNAME)を.envrc.overrideに設定してdirenv allowをしてください' >&2; \
		exit 1; \
	}
	@curl -fsS "https://github.com/${GITHUB_USERNAME}.keys" | grep -q "$(PUBLIC_KEY)" || ( \
		echo '----[ERROR]----' >&2; \
		echo "秘密鍵=${SSH_PRIVATE_KEY_PATH} に対応する公開鍵が https://github.com/${GITHUB_USERNAME}.keys にありません" >&2; \
		echo '登録済みの公開鍵に対応する秘密鍵のパスを.envrc.overrideに設定してください' >&2; \
		echo 'もしくはGitHubアカウント名(GITHUB_USERNAME)を.envrc.overrideに設定してください' >&2; \
		exit 1)
