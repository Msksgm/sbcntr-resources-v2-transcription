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
  - フロントエンドAppを更新する
EOF
  exit 2
}

setup_frontend_app() {
  ssh -F "$SSH_CONFIG_FILE" -o BatchMode=yes pseudo_cloud9 <<'EOF'
set -euo pipefail

cd sbcntr-frontend
pwd

cat ./app/routes/home.tsx | grep アライとウマのお店 || true

sed -i -e "s/アライとウマのお店/msksgm/g" ./app/routes/home.tsx
  
cat ./app/routes/home.tsx | grep msksgm || true

docker buildx build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-frontend-app:v1.0.1 .
aws ecr --region ${AWS_REGION} get-login-password | docker login --username AWS --password-stdin https://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-frontend-app
docker image push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sbcntr-frontend-app:v1.0.1


EOF
}

start_timer "$@"
(($# == 0)) || (echo '引数は不要です' >&2 && usage)
readonly TARGET_HOST=pseudo_cloud9
ssh -F "$SSH_CONFIG_FILE" "$TARGET_HOST" "touch ~/.hushlogin" 2>&1 || {
  echo "ssh失敗: $TARGET_HOST"
  exit 0
}

setup_frontend_app

end_timer "$@"
