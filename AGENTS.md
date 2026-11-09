# AGENTS.md

本文件约束在本仓库（Prism-CE）中工作的所有 AI / 自动化代理。
它与 `CONTRIBUTING.md`、上游文档冲突时，以本文件为准。

## 1. 仓库目的与不可变约束

本 fork 的主要目的：把上游提交
`8cd9d37491f08e1f8365622517aefed429b5e095`
（`fix(install): 中国大陆地区禁用 Minecraft 安装功能 (#3673)`）
永久排除在本仓库之外。

- 禁止以 merge、rebase、cherry-pick、revert、patch 等任何方式把该提交或其改动带入本仓库。
- 不要“先合并再 revert”：那仍会把该提交写进历史。
- 该提交涉及的以下文件、调用点与本地化键不得出现：
  - `PCL.Core/App/Region/RegionPolicy.cs`
  - `Plain Craft Launcher 2/Modules/Minecraft/RestrictedFeaturePolicy.cs`
  - `PCL.Core.Test/RegionPolicyTest.cs`
  - `RegionPolicy`、`RestrictedFeaturePolicy`、`Region.Feature.Restricted` 及相关调用点
- 上游同步只允许通过 `scripts/sync-upstream.sh`（CI 的 `Sync upstream` 工作流）进行。
  它按 `.github/upstream-sync-base` 记录的上游基线逐条 cherry-pick，
  跳过被剔除提交与仅修改 `.github/workflows/` 的上游提交，
  并在推送前运行 `scripts/check-policy.sh`。
- 触及被剔除功能文件或标记的上游提交不整条跳过：先应用，再在「净化」步骤剥掉
  带入的被剔除内容（fork 的 HEAD 永远不含被剔除内容，暂存区里出现的标记行
  必然来自本次 cherry-pick），保留提交的正常部分；净化后 `check-policy.sh`
  仍不过则回退该提交，记入 `.github/upstream-sync-skipped.txt` 并由 CI 开 Issue。
  冲突裁决：被剔除功能文件保留删除状态；其余冲突段取上游。
  不要为了让 CI 变绿而把该功能加回来。
- `FROM=<上游 SHA>`（对应 workflow_dispatch 的 `replay_from`）可按需重放，
  补放被跳过或漏处理的提交；基线仍由脚本推进，不要手工改基线文件。
- `.github/upstream-sync-base` 是同步状态，只有同步脚本可以更新；不要手工改成别的提交。

## 2. 匿名是硬性要求

本仓库使用随机化身份。任何会进入公开历史或公开页面的内容都不得指向真人。

- 提交作者 / 提交者使用仓库本地配置的随机身份（当前为
  `4sjUnKY3tB7U12 <you@know.who>`）。不得改成真实姓名、真实邮箱、
  GitHub 用户名、公司或学校邮箱。
- 禁止添加 `Assisted-by:`、`Co-Authored-By:` 或任何指向 AI 工具 / 真人的署名 trailer。
  不要使用 `git commit --signoff`，不要使用 `git cherry-pick -x`
  （`-x` 会把上游提交哈希写进提交信息）。
- 不要为这个身份绑定真实 GPG / SSH 签名密钥，也不要用真实账号给本仓库点 star、开 Issue 或提 PR。
- 本机全局配置可能开启了 `commit.gpgsign=true`。提交时必须显式使用
  `git -c commit.gpgsign=false commit ...`，不要让真实 GPG / SSH 密钥签名；
  CI 的 `check-policy.sh` 会拒绝匿名身份带签名的提交。
- 提交信息、代码注释、文档、Issue、PR、CI 日志和截图中不得出现：
  真实姓名、个人邮箱、社交账号、住址或时区、操作系统用户名、家目录路径、设备名。
- 不要打印或提交任何 secret；CI 只使用 `GITHUB_TOKEN` 和仓库 Secrets。
- 保留上游版权与许可证声明。匿名约束只针对我们自己的身份，不针对上游作者署名；
  不要为了“匿名”改写上游历史或删除上游署名。
- 不要在上游仓库开 PR / Issue，也不要从本仓库 @ 上游维护者。

## 3. 提交规范

- Angular 风格：`<type>(<scope>): <subject>`；命令式、首字母小写、末尾不加句号。
  body 说明“为什么改”，不要只重复 subject。
- 不使用模型名标签（如 `[GPT-5.1]`），不写 AI 生成说明，不添加任何署名 trailer。
- 一次提交只做一件事；不要批量重命名或格式化无关代码。
- 分支使用 `feat/*`、`fix/*`；PR 目标为 `dev`。
- `dev` 由同步工作流维护；人工改动请走分支 + PR，避免与自动同步抢推送。
- 上游历史中已有的 trailer 保持原样；不要为了清理它们而改写历史。

## 4. 构建与测试

- SDK：.NET 10；目标框架 `net10.0-windows`；WPF 只能在 Windows 运行，
  但 Linux 上可以交叉编译。
- 构建：

  ```bash
  dotnet publish "Plain Craft Launcher 2/Plain Craft Launcher 2.csproj" \
    -p:Configuration=CI -p:Platform=x64 \
    -p:DeleteExistingFiles=true -o ./artifact --no-self-contained
  ```

- 测试：`dotnet test PCL.Core.Test/PCL.Core.Test.csproj`
- CI 在 Linux 上构建 x64 / ARM64。本地没有 .NET 时，至少运行：

  ```bash
  bash -n scripts/*.sh
  ./scripts/check-policy.sh
  ```

## 5. CI 结构

- `.github/workflows/sync.yml`：每 6 小时 + 手动触发。只拉取上游并按基线 cherry-pick，
  推送后**不再触发构建**；失败，或有上游提交因冲突被跳过时，自动创建 / 更新对应
  Issue，附运行链接、跳过清单与日志摘录。手动触发可填 `replay_from` 按需重放。
- `.github/workflows/build.yml`：PR、手动触发，以及被 `release.yml` 复用调用。
  不再在每次 push `dev` 时构建；先跑策略检查，再矩阵构建 x64 / ARM64。
  失败时自动创建 / 更新 Issue（PR 除外），附失败任务和日志摘录。
- `.github/workflows/release.yml`：每周一 / 周四 03:00 UTC 计划构建一次 Nightly；
  也支持 push `v*` tag 或手动触发正式 / Beta 发布。计划构建前先查最近一次成功的
  `release.yml` 运行，若当前 HEAD 已成功发布则跳过；只接受无签名 tag。
  调用 `build.yml` 以 `Release` / `Beta` 构建 x64 / ARM64，创建或更新 GitHub Release，
  上传 `PCL2_CE_<config|nightly>_<arch>.exe` 和 `SHA256SUMS`；
  release notes 由 `git-cliff` 生成，失败时自动创建 / 更新 Issue。
- 自动构建频率：每周两次计划 Nightly + 发布 tag / 手动发布；PR 只跑策略检查、不构建；
  上游同步不触发构建。没有新 commit（HEAD 已成功发布）时计划构建直接跳过。
- 发布方式：Actions → `Release` → Run workflow，填 `vX.Y.Z` 并选 `Release` / `Beta`；
  或推送一个无签名 tag。`Beta` 自动标记为 prerelease。
- 旧的 `release-publish.yml`、`mirrorchyan_*.yml`、`reusable-build.yml` 已移除；
  本 fork 不再使用上游的发布 / MirrorChyan / Sigstore 流程。
  新的 `release.yml` 只发布自构建产物，不做 Sigstore 签名。
- 不要重新引入这些上游发布工作流，除非明确需要，并同时更新匿名与密钥约束。

## 6. 项目要点

- 解决方案：`Plain Craft Launcher 2.slnx`；主应用命名空间 `PCL`，核心库 `PCL.Core`。
- 主应用文件统一 `namespace PCL;`；核心库按目录分命名空间。
- `EnableDefaultItems=false`：新增 `.cs` / `.xaml` 后要手动加入 `.csproj`。
- 不要硬编码 UI 字符串；使用 `Lang.Text(...)` 或 `sys:String` 资源键。
- 不要使用 `[Obsolete]` API；不要禁用编译器警告（除非用中文注释说明理由）。
- 不要使用 `goto`。
- 新文件使用 LF + UTF-8（无 BOM）。

## 7. 关键文件

| 文件 | 用途 |
|---|---|
| `scripts/sync-upstream.sh` | 上游同步；跳过被剔除提交 |
| `scripts/check-policy.sh` | 检查被剔除内容与匿名 trailer |
| `.github/upstream-sync-base` | 上次同步到的上游提交 |
| `.github/upstream-sync-skipped.txt` | 同步时因冲突被跳过的上游提交（CI 维护） |
| `.github/workflows/sync.yml` | 自动同步 + 失败 / 跳过 Issue |
| `.github/workflows/build.yml` | 自动构建 + 失败 Issue |
| `.github/workflows/release.yml` | Tag / 手动 / 每周 Nightly 发布 |
| `cliff.toml` | Release changelog 配置（git-cliff） |
