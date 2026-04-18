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
aws.create-network-vpc-endpoint-step1-cfn: aws.define-network-vpc-endpoints-variables ## S3、ECR、DKR、ECR APIの経路になる VPCエンドポイントを作成
	@aws cloudformation create-stack --stack-name ${VPC_ENDPOINT_STACK_NAME} --template-body file://handson/cloudformations/network_vpc_endpoint_step1.yml \
		--parameters \
			ParameterKey=VpcId,ParameterValue=$(VPC_ID) \
			'ParameterKey=SubnetIds,ParameterValue="$(SUBNET_IDS)"' \
			ParameterKey=SecurityGroupIds,ParameterValue=$(SG_ID) \
			ParameterKey=RouteTableId,ParameterValue=$(ROUTE_TABLE_ID)

	@echo "${VPC_ENDPOINT_STACK_NAME}: 作成中です（約1.5分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${VPC_ENDPOINT_STACK_NAME}

.PHONY: aws.delete-network-vpc-endpoint-step1-cfn
aws.delete-network-vpc-endpoint-step1-cfn: ## S3、ECR、DKR、ECR APIの経路になる VPCエンドポイントを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(VPC_ENDPOINT_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(VPC_ENDPOINT_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-network-vpc-endpoint-step2-cfn
aws.create-network-vpc-endpoint-step2-cfn: aws.define-network-vpc-endpoints-variables ## S3、ECR、DKR、ECR API、CloudWatch Logsの経路になる VPCエンドポイントを作成（2つめ）
	@aws cloudformation create-stack --stack-name ${VPC_ENDPOINT_STACK_NAME} --template-body file://handson/cloudformations/network_vpc_endpoint_step2.yml \
		--parameters \
			ParameterKey=VpcId,ParameterValue=$(VPC_ID) \
			'ParameterKey=SubnetIds,ParameterValue="$(SUBNET_IDS)"' \
			ParameterKey=SecurityGroupIds,ParameterValue=$(SG_ID) \
			ParameterKey=RouteTableId,ParameterValue=$(ROUTE_TABLE_ID)

	@echo "${VPC_ENDPOINT_STACK_NAME}: 作成中です（約1.5分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${VPC_ENDPOINT_STACK_NAME}

.PHONY: aws.delete-network-vpc-endpoint-step2-cfn
aws.delete-network-vpc-endpoint-step2-cfn: ## S3、ECR、DKR、ECR API、CloudWatch Logsの経路になる VPCエンドポイントを削除（2つめ）
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name ${VPC_ENDPOINT_STACK_NAME}
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name ${VPC_ENDPOINT_STACK_NAME}
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-target-group-frontend-cfn
aws.create-target-group-frontend-cfn: aws.define-target-group-frontend-variables ## フロントエンドアプリのターゲットグループを作成
	@aws cloudformation create-stack --stack-name ${TARGET_GROUP_FRONTEND_STACK_NAME} --template-body file://handson/cloudformations/target_group_frontend.yml \
		--parameters \
			ParameterKey=VpcId,ParameterValue=$(VPC_ID)

	@echo "${TARGET_GROUP_FRONTEND_STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${TARGET_GROUP_FRONTEND_STACK_NAME}

.PHONY: aws.delete-target-group-frontend-cfn
aws.delete-target-group-frontend-cfn: ## フロントエンドアプリのターゲットグループを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(TARGET_GROUP_FRONTEND_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(TARGET_GROUP_FRONTEND_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-alb-frontend-cfn
aws.create-alb-frontend-cfn: aws.define-alb-frontend-variables ## フロントエンドアプリのALBを作成
	@aws cloudformation create-stack --stack-name ${ALB_FRONTEND_STACK_NAME} --template-body file://handson/cloudformations/alb_frontend.yml \
		--parameters \
			ParameterKey=SubnetIngressA,ParameterValue=$(SUBNET_INGRESS_A) \
			ParameterKey=SubnetIngressC,ParameterValue=$(SUBNET_INGRESS_C) \
			ParameterKey=SecurityGroupId,ParameterValue=$(SG_ID) \
			ParameterKey=TargetGroupBlueArn,ParameterValue=$(TG_BLUE_ARN) \
			ParameterKey=TargetGroupGreenArn,ParameterValue=$(TG_GREEN_ARN)

	@echo "${ALB_FRONTEND_STACK_NAME}: 作成中です（約3分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${ALB_FRONTEND_STACK_NAME}

.PHONY: aws.delete-alb-frontend-cfn
aws.delete-alb-frontend-cfn: ## フロントエンドアプリのALBを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(ALB_FRONTEND_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(ALB_FRONTEND_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-iam-role-ecs-bluegreen-cfn
aws.create-iam-role-ecs-bluegreen-cfn: ## Blue/Green デプロイメント用のIAMロールを作成
	@aws cloudformation create-stack --stack-name ${IAM_ROLE_ECS_BLUEGREEN_STACK_NAME} \
		--template-body file://handson/cloudformations/iam_role_ecs_bluegreen.yml \
		--capabilities CAPABILITY_NAMED_IAM
	@echo "${IAM_ROLE_ECS_BLUEGREEN_STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${IAM_ROLE_ECS_BLUEGREEN_STACK_NAME}

.PHONY: aws.delete-iam-role-ecs-bluegreen-cfn
aws.delete-iam-role-ecs-bluegreen-cfn: ## Blue/Green デプロイメント用のIAMロールを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(IAM_ROLE_ECS_BLUEGREEN_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(IAM_ROLE_ECS_BLUEGREEN_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-task-definition-frontend-app-cfn
aws.create-task-definition-frontend-app-cfn: aws.define-task-definition-frontend-app-variables ## フロントエンドアプリのECSタスク定義を作成
	@aws cloudformation create-stack --stack-name ${TASK_DEF_FRONTEND_APP_STACK_NAME} \
		--template-body file://handson/cloudformations/task_definition_frontend_app.yml \
		--parameters \
			ParameterKey=AccountId,ParameterValue=$(AWS_ACCOUNT_ID)
	@echo "${TASK_DEF_FRONTEND_APP_STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${TASK_DEF_FRONTEND_APP_STACK_NAME}

.PHONY: aws.delete-task-definition-frontend-app-cfn
aws.delete-task-definition-frontend-app-cfn: ## フロントエンドアプリのECSタスク定義を削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(TASK_DEF_FRONTEND_APP_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(TASK_DEF_FRONTEND_APP_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-ecs-cluster-cfn
aws.create-ecs-cluster-cfn: ## ECSクラスターを作成
	@aws cloudformation create-stack --stack-name ${ECS_CLUSTER_STACK_NAME} --template-body file://handson/cloudformations/ecs_cluster.yml
	@echo "${ECS_CLUSTER_STACK_NAME}: 作成中です（約1分かかる）"
	@time aws cloudformation wait stack-create-complete --stack-name ${ECS_CLUSTER_STACK_NAME}

.PHONY: aws.delete-ecs-cluster-cfn
aws.delete-ecs-cluster-cfn: ## ECSクラスターを削除
	@echo 'Before status'
	@make aws.status
	@aws cloudformation delete-stack --stack-name $(ECS_CLUSTER_STACK_NAME)
	@echo '削除中です'
	@time aws cloudformation wait stack-delete-complete --stack-name $(ECS_CLUSTER_STACK_NAME)
	@echo 'After status'
	@make aws.status

.PHONY: aws.create-all-cfns
aws.create-all-cfns: ## cfnを作成する
	@make aws.create-base-cfn
	@make aws.create-pseudo-cloud9-cfn
	@make aws.create-registry-cfn
	@make aws.create-network-vpc-endpoint-step2-cfn
	@make aws.create-target-group-frontend-cfn
	@make aws.create-alb-frontend-cfn
	@make aws.create-iam-role-ecs-bluegreen-cfn
	@make aws.create-task-definition-frontend-app-cfn
	@make aws.create-ecs-cluster-cfn

.PHONY: aws.delete-all-cfns
aws.delete-all-cfns: ## cfnを削除する
	@make aws.delete-ecs-cluster-cfn
	@make aws.delete-task-definition-frontend-app-cfn
	@make aws.delete-iam-role-ecs-bluegreen-cfn
	@make aws.delete-alb-frontend-cfn
	@make aws.delete-target-group-frontend-cfn
	@make aws.delete-network-vpc-endpoint-step2-cfn
	@make aws.delete-registry-cfn
	@make aws.delete-pseudo-cloud9-cfn
	@make aws.delete-base-cfn

.PHONY: aws.show-defined-pseudo-cloud9-variables
aws.show-defined-pseudo-cloud9-variables: aws.define-pseudo-cloud9-variables ## 擬似 cloud9 CFnスタック作成に必要な環境変数を定義
	@echo "VPC_ID:     $(VPC_ID)"
	@echo "SG_ID:      $(SG_ID)"
	@echo "SUBNET_ID:  $(SUBNET_ID)"

.PHONY: aws.show-defined-alb-frontend-variables
aws.show-defined-alb-frontend-variables: aws.define-alb-frontend-variables ## ALB CFnスタック作成に必要な環境変数を表示
	@echo "VPC_ID:               $(VPC_ID)"
	@echo "SUBNET_INGRESS_A:     $(SUBNET_INGRESS_A)"
	@echo "SUBNET_INGRESS_C:     $(SUBNET_INGRESS_C)"
	@echo "SG_ID:                $(SG_ID)"
	@echo "TG_BLUE_ARN:          $(TG_BLUE_ARN)"
	@echo "TG_GREEN_ARN:         $(TG_GREEN_ARN)"

.PHONY: aws.show-defined-task-definition-frontend-app-variables
aws.show-defined-task-definition-frontend-app-variables: aws.define-task-definition-frontend-app-variables ## フロントエンドアプリのECSタスク定義作成に必要な環境変数を表示
	@echo "AWS_ACCOUNT_ID:       $(AWS_ACCOUNT_ID)"

.PHONY: aws.show-defined-network-vpc-endpoints-variables
aws.show-defined-network-vpc-endpoints-variables: aws.define-network-vpc-endpoints-variables ## ECRへのネットワーク経路となる、VPCエンドポイントを作成するための環境変数
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

aws.define-target-group-frontend-variables:
	$(eval VPC_ID     := $(shell aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sbcntr-main" --query "Vpcs[0].VpcId" --output text))

aws.define-alb-frontend-variables:
	$(eval VPC_ID               := $(shell aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sbcntr-main" --query "Vpcs[0].VpcId" --output text))
	$(eval SUBNET_INGRESS_A     := $(shell aws ec2 describe-subnets --filters "Name=tag:Name,Values=sbcntr-public-ingress-a" --query "Subnets[0].SubnetId" --output text))
	$(eval SUBNET_INGRESS_C     := $(shell aws ec2 describe-subnets --filters "Name=tag:Name,Values=sbcntr-public-ingress-c" --query "Subnets[0].SubnetId" --output text))
	$(eval SG_ID                := $(shell aws ec2 describe-security-groups --filters "Name=group-name,Values=ingress" "Name=vpc-id,Values=${VPC_ID}" --query "SecurityGroups[0].GroupId" --output text))
	$(eval TG_BLUE_ARN          := $(shell aws elbv2 describe-target-groups --names sbcntr-frontapp-blue --query "TargetGroups[0].TargetGroupArn" --output text))
	$(eval TG_GREEN_ARN         := $(shell aws elbv2 describe-target-groups --names sbcntr-frontapp-green --query "TargetGroups[0].TargetGroupArn" --output text))

aws.define-task-definition-frontend-app-variables:
	$(eval AWS_ACCOUNT_ID := $(shell aws configure get sso_account_id --profile $(AWS_SSO_PROFILE)))

aws.define-network-vpc-endpoints-variables:
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
