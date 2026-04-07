## 用語集

### Amazon VPC（Amazon Virtual Private Cloud）

論理的に隔離された仮想ネットワーク
リージョン単位でつくる

CidrBlock 表記で IP アドレスの範囲を指定する。
`10.0.0.0/16`で`10.0.0.0`から`10.0.255.255`の範囲を利用でき、IP 数は`65536`（`256*256`）になる。

CloudFormation の Type `AWS::EC2::VPC`

```yaml
Resources:
  # VPCの設定
  Vpc:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      # VPC 内のEC2 などに DNS ホスト名をつけられるようにする
      EnableDnsHostnames: true
      # VPC内で DNS 解決をつかえるようにする。これが有効だと、インスタンスからドメイン名を名前解決できる。通常は true にする
      EnableDnsSupport: true
      # この VPC 上で起動するインスタンスのテナンシー設定。default は他ユーザーと物理ホストを共有する通常の実行形態。専有ホスト前提ではない一般的な設定
      InstanceTenancy: default
      Tags:
        - Key: Name
          Value: sbcntr-main
```

### サブネット

VPC 内の論理的なネットワーク領域
AZ 単位で作る

CloudFormation の Type `AWS::EC2::Subnet`

```yaml
Resources:
  SubnetPrivateAppA:
    Type: AWS::EC2::Subnet
    Properties:
      CidrBlock: 10.0.8.0/24
      VpcId:
        Ref: Vpc
      AvailabilityZone:
        #
        Fn::Select:
          - 0 # ↓の配列の 0 番目を返す
          - Fn::GetAZs: "" # 現在のリージョンの Availability Zone 一覧を返す
      MapPublicIpOnLaunch: false # そのサブネット内で新しく起動する EC2 インスタンスや ENI に対して、自動でパブリック IPv4 を付与するかを決める設定
      Tags:
        - Key: Name
          Value: sbcntr-private-app-a
        - Key: Type
          Value: Isolated
```

### ルートテーブル（Route table）

VPC 内のネットワークトラフィックをどこに向けるか決定するもの。
VPC を作成する t、自動的にメインテーブルが 1 つ作成される。
これとは別に、ユーザーが追加で作成するルートテーブルをカスタムルートテーブルと呼ぶ。

CloudFormation の Type
ルートテーブル `AWS::EC2::RouteTable`
サブネットをルートテーブルに紐付け `AWS::EC2::SubnetRouteTableAssociation`
ルートテーブルに行を追加する `AwS::EC2::Route`

```yaml
Resources:
  ## コンテナアプリ用のルートテーブル
  RouteApp:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId:
        Ref: Vpc
      Tags:
        - Key: Name
          Value: sbcntr-app
  ## コンテナサブネットへルート紐付け
  RouteAppAssociationA:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId:
        Ref: RouteApp
      SubnetId:
        Ref: SubnetPrivateAppA
  RouteAppAssociationC:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId:
        Ref: RouteApp
      SubnetId:
        Ref: SubnetPrivateAppC
```

### インターネットゲートウェイ（IGW）

VPC とインターネットをつなぐ高可用コンポーネント。
IGW に面しているのがパブリックサブネット、面していないのがプライベートサブネット

サブネットのルートテーブルでインターネット向けの通信（0.0.0.0/0）のターゲットを IGW に設定して、初めてそのサブネットが『パブリックサブネット』として機能する。

```yaml
Resources:
  ## Ingress用ルートテーブルのデフォルトルート
  RouteIngressDefault:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId:
        Ref: RouteIngress
      # 宛先
      DestinationCidrBlock: 0.0.0.0/0
      # 転送先
      GatewayId:
        Ref: Igw
    DependsOn:
      - sbcntrVpcgwAttachment
  # インターネットへ通信するためのゲートウェイの作成
  Igw:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: sbcntr-main
  sbcntrVpcgwAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId:
        Ref: Vpc
      InternetGatewayId:
        Ref: Igw
```

### セキュリティグループ

EC2 インスタンス等にアタッチする「仮想ファイアウォール」。
リソースへの通信を「許可」するルールを定義する。
ルールはステートフル（状態保持型）であり、一度許可された通信に対する戻りの通信は、反対方向のルールがなくても自動で許可される。

```yaml
Resources:
  SgIngress:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for ingress
      GroupName: ingress
      SecurityGroupEgress: # アウトバウンドルール
        - CidrIp: 0.0.0.0/0
          Description: Allow all outbound traffic by default
          IpProtocol: "-1"
      SecurityGroupIngress: # インバウンドルール
        - CidrIp: 0.0.0.0/0
          Description: from 0.0.0.0/0:80
          FromPort: 80
          IpProtocol: tcp
          ToPort: 80
        - CidrIpv6: ::/0
          Description: from ::/0:80
          FromPort: 80
          IpProtocol: tcp
          ToPort: 80
      Tags:
        - Key: Name
          Value: sbcntr-ingress
      VpcId:
        Ref: Vpc
```

```yaml
Resources:
  # ルール紐付け
  ## Internet LB -> Frontend app
  SgFrontendAppFromsSgIngressTcp:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      IpProtocol: tcp
      Description: HTTP for Ingress
      FromPort: 8080
      GroupId: # 送信先
        Fn::GetAtt:
          - SgFrontendApp # 送信先の
          - GroupId # GroupId
      SourceSecurityGroupId: # 送信元
        Fn::GetAtt:
          - SgIngress # 送信先の
          - GroupId # GroupId
      ToPort: 8080
```
