#!/usr/bin/env bash
# 把上游 linguo2625469/workbuddy2api-panel 的最新提交同步到本 fork，并保留「socks5 代理池」这一个补丁。
#
# 用法：
#   ./sync-upstream.sh            # 拉上游 → rebase → 构建/测试 → 推送
#   ./sync-upstream.sh --no-push  # 只同步到本地，自己看 diff
#
# 冲突怎么办（大概率只出现在这几个文件：internal/panel/app.js、panel/index.html、
# panel/panel.go、cmd/server/main.go、internal/upstream/client.go、README.md）：
#   1) 手工解完后  git add <文件> && git rebase --continue
#   2) 想放弃本次同步  git rebase --abort
# 上游改的是面板/配置这些我们也在改的文件，所以「作者不做代理」不代表不会冲突——
# 冲突来源是同一批文件的并行修改，跟功能是否重叠无关。
set -euo pipefail
cd "$(dirname "$0")"

NO_PUSH=0
[[ "${1:-}" == "--no-push" ]] && NO_PUSH=1

git rev-parse --verify upstream >/dev/null 2>&1 || {
  git remote add upstream https://github.com/linguo2625469/workbuddy2api-panel
}
git fetch upstream --prune --tags

if [[ -n "$(git status --porcelain)" ]]; then
  echo "工作区不干净，先 commit 或 stash" >&2
  exit 1
fi

before=$(git rev-parse --short HEAD)
echo "==> rebase 到 upstream/main"
git rebase upstream/main

echo "==> 构建 + 测试"
go build ./...
go test ./...

echo "==> 本地 HEAD: $before -> $(git rev-parse --short HEAD)"
git log --oneline upstream/main..HEAD

if [[ $NO_PUSH -eq 1 ]]; then
  echo "==> 已跳过推送。确认无误后： git push --force-with-lease origin main"
  exit 0
fi

# 只有上面的 build/test 全绿才会走到这里
git push --force-with-lease origin main
echo "==> 已同步并推送（GitHub Actions 会重跑构建，产出 ghcr.io/binaryu/workbuddy2api:latest）"
