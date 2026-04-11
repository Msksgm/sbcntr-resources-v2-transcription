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

setup_frontend_app() {
  ssh -F "$SSH_CONFIG_FILE" -o BatchMode=yes pseudo_cloud9 <<'EOF'
set -euo pipefail

if [ -d sbcntr-frontend/.git ]; then
  echo 'sbcntr-frontend は既にクローン済み。スキップします'
  cd sbcntr-frontend
else
  git clone https://github.com/uma-arai/sbcntr-frontend.git
  cd sbcntr-frontend
  
  git fetch
  git switch v2
fi

sudo npm install -g pnpm
pnpm -v

cp .npmrc.sample .npmrc
pnpm check-node

pnpm install --frozen-lockfile --prod
EOF
}

setup_backend_app() {
  ssh -F "$SSH_CONFIG_FILE" -o BatchMode=yes pseudo_cloud9 <<'EOF'
set -euo pipefail

if [ -d sbcntr-backend/.git ]; then
  echo 'sbcntr-backend は既にクローン済み。スキップします'
  exit 0
fi


git clone https://github.com/uma-arai/sbcntr-backend.git
cd sbcntr-backend

git fetch
git switch v2
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
setup_backend_app

end_timer "$@"
