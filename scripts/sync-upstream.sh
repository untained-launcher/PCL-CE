#!/usr/bin/env bash
# 按 merge 方式跟随上游：本 fork 的历史 = 上游历史 + 本 fork 的提交。
#
# 这样上游提交以原 SHA 进入历史，`git log upstream/dev ^HEAD` 不再堆积
# 重放提交；同步只需合并一次。冲突只允许出现在本 fork 有意改写的文件上，
# 其余冲突一律中止并交人工处理，避免悄悄丢上游改动。
#
# 环境变量：
#   UPSTREAM_REPO    上游仓库（默认 PCL-Community/PCL-CE）
#   UPSTREAM_BRANCH  上游分支（默认 dev）
#   SYNC_GIT_NAME / SYNC_GIT_EMAIL  提交身份
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-PCL-Community/PCL-CE}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/${UPSTREAM_REPO}}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-dev}"
TARGET_BRANCH="${TARGET_BRANCH:-dev}"

# 本 fork 主动删除的上游文件：上游改动它们时保持删除状态。
REMOVED_FILES=(
  "PCL.Core/App/Region/RegionPolicy.cs"
  "PCL.Core.Test/RegionPolicyTest.cs"
  ".github/workflows/build-test.yml"
  ".github/workflows/mirrorchyan_release_note.yml"
  ".github/workflows/mirrorchyan_uploading.yml"
  ".github/workflows/release-publish.yml"
  ".github/workflows/reusable-build.yml"
)

# 本 fork 改写的文件：冲突时保留本 fork 版本。
OWNED_FILES=(
  "Plain Craft Launcher 2/Modules/Minecraft/RestrictedFeaturePolicy.cs"
  "cliff.toml"
)

# 本 fork 删过内容、合并时保留删除的文件。
PRUNED_FILES=(
  "PCL.Core.Wpf/App/Localization/Languages/en-US.xaml"
  "PCL.Core.Wpf/App/Localization/Languages/zh-CN.xaml"
)
PRUNED_PATTERN='x:Key="Region.Feature.Restricted"'

contains() {
  local needle="$1"
  shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

git config user.name "${SYNC_GIT_NAME:-PCL-CE Sync}"
git config user.email "${SYNC_GIT_EMAIL:-you@know.who}"
git config commit.gpgsign false

git remote add upstream "$UPSTREAM_URL" 2>/dev/null || true
git remote set-url upstream "$UPSTREAM_URL"
git fetch --no-tags upstream "$UPSTREAM_BRANCH"

UPSTREAM_REF="upstream/${UPSTREAM_BRANCH}"
UPSTREAM_SHA="$(git rev-parse "$UPSTREAM_REF")"

if git merge-base --is-ancestor "$UPSTREAM_SHA" HEAD; then
  echo "[sync] 上游无新提交（${UPSTREAM_SHA:0:10}）"
  echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

BEHIND="$(git rev-list --count "HEAD..${UPSTREAM_SHA}")"
echo "[sync] 合并上游 ${UPSTREAM_SHA:0:10}（${BEHIND} 个提交）"

if ! git merge --no-edit "$UPSTREAM_REF"; then
  mapfile -t conflicts < <(git diff --name-only --diff-filter=U)
  echo "[sync] 冲突 ${#conflicts[@]} 个，按本 fork 约束裁决"

  unresolved=()
  for f in "${conflicts[@]}"; do
    if [[ "$f" == .github/workflows/* ]]; then
      # 本 fork 自有 workflow 与已删除的上游 workflow。
      if git cat-file -e "HEAD:${f}" 2>/dev/null; then
        git checkout --ours -- "$f" && git add "$f"
        echo "  保留本 fork 版本：$f"
      else
        git rm -q --force -- "$f"
        echo "  保持删除：$f"
      fi
    elif contains "$f" "${REMOVED_FILES[@]}"; then
      git rm -q --force -- "$f"
      echo "  保持删除：$f"
    elif contains "$f" "${OWNED_FILES[@]}"; then
      git checkout --ours -- "$f" && git add "$f"
      echo "  保留本 fork 版本：$f"
    elif contains "$f" "${PRUNED_FILES[@]}"; then
      git checkout --theirs -- "$f"
      sed -i "/${PRUNED_PATTERN}/d" "$f"
      git add "$f"
      echo "  取上游并删除受限提示：$f"
    else
      unresolved+=("$f")
    fi
  done

  if ((${#unresolved[@]} > 0)); then
    echo "[sync] 以下冲突无法按既定策略裁决，中止合并，交人工处理："
    printf '  %s\n' "${unresolved[@]}"
    git merge --abort || true
    exit 1
  fi

  git -c commit.gpgsign=false commit --no-edit
fi

# 合并后必须仍然满足本 fork 的硬约束。
if [[ -x scripts/check-policy.sh ]]; then
  scripts/check-policy.sh
fi

if [[ "${DRY_RUN:-}" == "true" ]]; then
  echo "[sync] DRY_RUN：已合并到本地，跳过推送（HEAD $(git rev-parse --short HEAD)）"
  exit 0
fi

git push origin "HEAD:${TARGET_BRANCH}"
echo "[sync] 完成：HEAD $(git rev-parse --short HEAD)"
echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/null}"
