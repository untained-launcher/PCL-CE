#!/usr/bin/env bash
# 校验当前 HEAD 是否违反本 fork 的硬约束：
#   1) 不含被剔除提交引入的区域检测实现；
#   2) 地区功能限制为恒放行桩，不实际判定地区；
#   3) 匿名身份提交的 commit 不含署名 trailer，也不得带签名。
#
# 只读，不修改工作区。构建与同步流程都会调用它。
set -euo pipefail

FORBIDDEN_COMMIT="${FORBIDDEN_COMMIT:-8cd9d37491f08e1f8365622517aefed429b5e095}"
ANON_EMAIL="${ANON_EMAIL:-${SYNC_GIT_EMAIL:-you@know.who}}"
POLICY_FILE="Plain Craft Launcher 2/Modules/Minecraft/RestrictedFeaturePolicy.cs"
fail=0

err() {
  printf '::error::%s\n' "$*" >&2
  fail=1
}

# 说明：本 fork 完整跟随上游历史，被剔除提交 8cd9d374 会以原 SHA 存在于祖先链中，
# 因此这里不再校验历史，只校验工作树里没有它引入的实现（下面第 1、2 项）。

# 1) 区域检测实现与测试不得存在。
for path in \
  "PCL.Core/App/Region/RegionPolicy.cs" \
  "PCL.Core.Test/RegionPolicyTest.cs"; do
  if git cat-file -e "HEAD:${path}" 2>/dev/null; then
    err "HEAD 含被剔除的文件：$path"
  fi
done

# 2) 策略桩必须存在、恒放行，且不得引用区域检测实现。
if ! git cat-file -e "HEAD:${POLICY_FILE}" 2>/dev/null; then
  err "缺少恒放行桩：$POLICY_FILE"
else
  policy="$(git show "HEAD:${POLICY_FILE}")"
  if grep -qE 'RegionPolicy|ReadWindowsSignals' <<<"$policy"; then
    err "$POLICY_FILE 引用了区域检测实现"
  fi
  if ! grep -q 'IsRestricted => false' <<<"$policy"; then
    err "$POLICY_FILE 未恒放行（IsRestricted 应为 false）"
  fi
  if ! grep -q 'Check(string feature, bool showHint = true) => true' <<<"$policy"; then
    err "$POLICY_FILE 的 Check 未恒返回 true"
  fi
fi

# 3) 源码里不得出现区域检测与提示文案。
# 扫描所有源码顶层目录：上游重构会新增目录（如 WPF/Core 拆分产生的
# PCL.Core.Wpf），硬编码目录列表会漏扫。排除 .github / scripts / docs，
# 它们合法地引用被剔除提交的哈希与文件名，会造成误报。
grep_paths=()
while IFS= read -r path; do
  case "$path" in
    .github|scripts|docs) continue ;;
  esac
  grep_paths+=("$path")
done < <(git ls-tree -d --name-only HEAD)

if ((${#grep_paths[@]} > 0)); then
  hits="$(git grep -l -E \
    'RegionClassification|RegionAssessment|RegionSignals|ReadWindowsSignals|china-time-zone-and-locale|Region\.Feature\.Restricted|Minecraft 下载、补全与整合包安装功能在你所在的国家或地区不可用' \
    HEAD -- "${grep_paths[@]}" 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits" | sed 's/^HEAD://' >&2
    err "源码中出现被剔除功能的关键标记（文件见上）"
  fi
fi

# 4) 匿名身份提交的 commit 不得含 AI / 真人署名 trailer，也不得带签名。
# 只看 author email，避免误伤上游提交；上游历史中已有的 trailer / 签名保持原样。
while read -r sha author_email; do
  [[ -z "${sha:-}" ]] && continue
  [[ "$author_email" == "$ANON_EMAIL" ]] || continue
  if git show -s --format=%B "$sha" \
    | grep -qiE '^[[:space:]]*(Assisted-by|Co-Authored-By)[[:space:]]*:'; then
    err "提交 $sha 含禁用 trailer（Assisted-by / Co-Authored-By）"
  fi
  if git cat-file -p "$sha" | sed -n '1,/^$/p' | grep -q '^gpgsig'; then
    err "提交 $sha 带签名；匿名提交不应绑定真实 GPG / SSH 密钥"
  fi
done < <(git log --format='%H %ae' HEAD)

exit "$fail"
