## 用語集

### IAM

IAMロール。
Cfn の Type は `AWS::IAM::Role`。

```yaml
################# Resources ###############
Resources:
  # 開発用EC2のIAMロール
  PseudoCloud9IamRole:
    Type: AWS::IAM::Role
    Properties:
      # 「誰がこのロールを使ってよいか」を定義する
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              # EC2 サービスが
              Service: ec2.amazonaws.com
            # EC2 が STS を使ってこのロールを利用する
            Action: sts:AssumeRole
      # AWS 管理ポリシー
      ManagedPolicyArns:
        # System Manager の管理対象インスタンスとしてどうだするための基本県気
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        # ECR への push /pull やリポジトリ参照など強めの ECR 操作権限
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
      # インラインポリシー
      Policies:
        - PolicyName: ECSServiceUpdatePolicy # 独自権限の名前
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ecs:UpdateService # ECS サービスの設定更新
                  - ecs:DescribeServices # 状態確認
                  - ecs:DescribeClusters # 状態確認
                  - ecs:ListServices # 一覧取得章
                  - ecs:ListClusters # 一覧取得章
                  - ecs:ListTasks # 一覧取得章
                  - ecs:DescribeTasks # 状態確認
                  - ecs:ExecuteCommand # ECS Exec を使ってコンテナ内に入るための権限
                Resource: '*'
              - Effect: Allow
                Action:
                  - ssm:StartSession # SSM セッションを開始する権限
                Resource:
                  # ECS Exec で使う SSM ドキュメント
                  - !Sub 'arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:document/AmazonECS-ExecuteInteractiveCommand'
                  # 対象の ECS タスク
                  - !Sub 'arn:aws:ecs:${AWS::Region}:${AWS::AccountId}:task/*'
              - Effect: Allow
                Action:
                  # IAM ロールを AWS サービスに引き渡す権限
                  - iam:PassRole
                Resource: '*'
                Condition:
                  StringEquals:
                    iam:PassedToService: ecs-tasks.amazonaws.com

```

IAMインスタンスプロファイル

- IAM Role
  - 権限の本体
- InstanceProfile
  - そのロールを EC2 に付与するための器
- EC2 Instance
  - そのインスタンスプロファイルを参照して、一時クレデンシャルを取得する

```yaml
################# Resources ###############
Resources:
  # IAMインスタンスプロファイル →　EC2 に IAM ロールを渡すための入れ物
  InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref PseudoCloud9IamRole
```

### EC2

```yaml
################# Resources ###############
Resources:
  # EC2インスタンスの作成
  EC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t4g.small # 2025.02時点では0.0216USD/h
      SubnetId: !Ref ManagementSubnetId
      SecurityGroupIds:
        - !Ref SecurityGroupId
      IamInstanceProfile: !Ref InstanceProfile
      ImageId: ami-0976ced58148ef3eb  # uma-arai-pseudo-cloud9_2025-06-11T14-37-02.135Z2025-06-11T14-37-02.135Z
      BlockDeviceMappings:
        - DeviceName: /dev/xvda
          Ebs:
            VolumeSize: 30
            VolumeType: gp3
            DeleteOnTermination: true
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          
          # k6スクリプトを作成
          cat > /home/ec2-user/load-test.js << 'EOF'
          import http from 'k6/http';
          import { check } from 'k6';

          const TARGET_URL = __ENV.TARGET_URL || 'http://backend-app.sbcntr.local:8081/';
          const VUS = __ENV.VUS ? parseInt(__ENV.VUS) : 100;
          const ITERATIONS = __ENV.ITERATIONS ? parseInt(__ENV.ITERATIONS) : 1000000;

          export const options = ITERATIONS ? {
            // 固定回数実行の設定
            vus: VUS,
            iterations: ITERATIONS,
          } : {
            // 時間ベース実行の設定
            vus: VUS,
            duration: __ENV.DURATION || '10m',
          };

          export default function () {
            const response = http.get(TARGET_URL);

            check(response, {
              'ステータスコードが200': (r) => r.status === 200,
              'レスポンスタイムが3秒以内': (r) => r.timings.duration < 3000,
            });
          }
          EOF
          
          # ファイルの所有者を設定
          chown ec2-user:ec2-user /home/ec2-user/load-test.js
      Tags:
        - Key: Name
          Value: sbcntr-pseudo-cloud9

```

