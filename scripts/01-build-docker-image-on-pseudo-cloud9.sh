#!/usr/bin/env bash
set -Eeuo pipefail
#set -x
# -E: 関数やサブシェルでエラーが起きた時トラップ発動
# -e: エラーが発生した時点でスクリプトを終了
# -u: 未定義の変数を使用した場合にエラーを発生
# -x: スクリプトの実行内容を表示(debugで利用)
# -o pipefail: パイプライン内のエラーを検出

source "$(dirname "$0")/99-util.sh"

usage() {
  cat >&2 <<EOF
$0
概要:
  - pseudo_cloud9に対してsetupする
EOF
  exit 2
}

build_and_push_backend_app() {
  ssh -F "$SSH_CONFIG_FILE" -o BatchMode=yes pseudo_cloud9 <<'EOF'
cd sbcntr-backend
docker buildx build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-backend-app:v1 .
aws ecr --region ${AWS_REGION} get-login-password | docker login --username AWS --password-stdin https://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-backend-app
docker image push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-backend-app:v1
EOF
}

build_and_push_frontend_app() {
  ssh -F "$SSH_CONFIG_FILE" -o BatchMode=yes pseudo_cloud9 <<'EOF'
cd sbcntr-frontend
docker buildx build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-frontend-app:v1 .
aws ecr --region ${AWS_REGION} get-login-password | docker login --username AWS --password-stdin https://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-frontend-app
docker image push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-frontend-app:v1
EOF
}

start_timer "$@"
(($# == 0)) || (echo '引数は不要です' >&2 && usage)
readonly TARGET_HOST=pseudo_cloud9
ssh -F "$SSH_CONFIG_FILE" "$TARGET_HOST" "touch ~/.hushlogin" 2>&1 || {
  echo "ssh失敗: $TARGET_HOST"
  exit 0
}

build_and_push_backend_app
build_and_push_frontend_app

end_timer "$@"
