---
name: optimize-github-ci
description: Measure and optimize GitHub Actions CI. Use when asked to investigate slow jobs or runner queues, cut redundant CI, improve caching or parallelism, or verify CI speedups on a PR. 适用于排查 GitHub Actions 慢在哪里、优化 CI 耗时和实测优化效果。
---

# 优化 GitHub Actions CI

先测量，再按瓶颈修改。保留测试覆盖、必需检查和发版分支的完整验证。

## 1. 建立基线

确定目标仓库、workflow、触发事件和 runner。读取 workflow、复用的 action、被调用的脚本和 Dockerfile。检查分支保护或 ruleset，找出必需检查和 merge queue。

用 `gh` 取最近 50 次运行。用户指定了 workflow 时加 `--workflow`。对每个 run 使用列表返回的 `databaseId` 和 `attempt` 获取全部 job 及 step 时间。

```bash
gh run list --repo "$repo" --limit 50 \
  --json databaseId,attempt,workflowName,event,headBranch,headSha,status,conclusion,createdAt,startedAt,updatedAt,url
gh api --paginate "repos/$repo/actions/runs/$run_id/attempts/$attempt/jobs?per_page=100" --jq '.jobs[]'
```

对每个 job 记录三个阶段，按 workflow、事件、job、runner 和 matrix 维度比较。

| 阶段 | 计算方法 |
| --- | --- |
| 排队 | 用 job 的 `started_at - created_at` 估算。检查 runner 容量、并发组和审批等等待原因。缺少 job 时间戳时记为未知。workflow 创建到 job 启动的间隔可能含 `needs` 等待，只能标为启动前等待。 |
| 准备 | 累计 runner 初始化、checkout、工具链、缓存恢复、依赖安装、服务启动和测试前构建等步骤。 |
| 执行 | 累计实际测试步骤。lint 或构建 job 记录其主要任务耗时。 |

按脚本实际做的工作划分步骤。job 同时交付构建和测试时，在执行阶段分别记录。准备和测试合在一个 step 时查日志。日志无法拆分时标记为混合耗时。明显的缓存保存、报告上传、清理或计时空档单列在备注中。

首跑用已结束 run 的 `updatedAt - createdAt` 近似端到端耗时。重跑单列，用 `gh api "repos/$repo/actions/runs/$run_id/attempts/$attempt"` 返回的 `updated_at - run_started_at` 近似该次执行耗时，并注明该次实际运行的 job 范围。参考 [gh run list](https://cli.github.com/manual/gh_run_list)、[按 attempt 获取 jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run-attempt) 和 [attempt 元数据](https://docs.github.com/en/rest/actions/workflow-runs#get-a-workflow-run-attempt)。

用成功、可比的样本计算各阶段和 workflow 端到端耗时的中位数，样本充足时加 P90。注明样本数。记录失败、取消、跳过和仍在运行的数量。结合 `needs` 和实际运行时间找出决定 PR 等待时间的 job。并行 job 的运行耗时相加可估算 runner 用量，workflow 总耗时取实际经过时间。

## 2. 按瓶颈修改

### 触发和取消

- 同一个 PR 快速推送时，用 `concurrency` 的 `cancel-in-progress` 取消旧运行。按 workflow 和 PR 编号分组。下面的 `ci-tests` 是仓库内该 workflow 的独有前缀。非 PR 事件使用独立组，保护 `main` 和发版运行。仅把 `cancel-in-progress` 设为 `false` 时，共用同组的 pending run 默认仍可能被替换。参考 [GitHub Actions 并发规则](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)。

  ```yaml
  concurrency:
    group: ci-tests-${{ github.event_name == 'pull_request' && format('pr-{0}', github.event.pull_request.number) || format('run-{0}', github.run_id) }}
    cancel-in-progress: ${{ github.event_name == 'pull_request' }}
  ```

- 保留 `main` 的完整验证和发布流程依赖的互斥约束。一次 push 含多个提交时，普通 `push` workflow 对该次推送的新分支头运行。检查仓库是否按每个待验证 SHA 触发。存在覆盖缺口时，使用授权范围内的逐 SHA 验证机制，或在结果中指出缺口。参考 [push 事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push)。
- 非必需 workflow 可用 `paths` 或 `paths-ignore` 跳过只改 README 和文档的 PR。确认这些文件没有参与构建或测试。整条 workflow 被路径过滤时，关联的必需检查会一直 Pending。保留必需检查的触发和名称，用 job 条件只对纯文档 PR 跳过耗时任务。按本次运行的 base 和 head SHA 获取完整 diff，检查重命名前后的路径。文件列表不完整时执行检查。若已有汇总 job，确保它在依赖失败或跳过时也能执行，并且只接受成功或明确允许的跳过。仓库使用 merge queue 时，保留必需 workflow 的 `merge_group` 触发。参考 [必需检查与跳过行为](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks#handling-skipped-but-required-checks)。

### 准备和重复工作

- 优先使用 setup action 自带的缓存。按项目的包管理器为 `setup-node` 启用 `cache`。`setup-go` 默认开启缓存，按所用 action 版本核对默认行为和依赖路径。Rust 优先用 `Swatinem/rust-cache`。只缓存当前 job 使用的依赖和有复用收益的产物。用 `gh cache list` 和运行日志核对体积、命中率及恢复、保存耗时。GitHub Actions 的默认缓存额度为每仓库 10 GB，可配置。参考 [setup-node](https://github.com/actions/setup-node#caching-global-packages-data)、[setup-go](https://github.com/actions/setup-go#caching-dependency-files-and-build-outputs)、[rust-cache](https://github.com/Swatinem/rust-cache) 和 [缓存额度](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#usage-limits-and-eviction-policy)。
- 同一本地工作目录用相同命令连跑两次构建，中间不改文件。记录首次和第二次耗时。支持增量的构建在第二次应接近空跑。定位重复安装或重建，检查 Dockerfile 是否在安装依赖前就复制整个仓库，以及构建脚本是否依赖不存在的文件。修复后按相同方式复测。
- 用兼容的预编译包替换 CI 中现场编译工具的 `go install` 和 `cargo install`。从可信的发布源下载固定版本，匹配 runner 的 OS 和架构，并按项目约定校验。
- 检查跨 job 的重复工作。保留一处等价检查，确认它覆盖同一输入、平台和触发条件，且失败仍能阻止合并。只构建前端的 job 只加载前端所需缓存。多个 job 使用同一构建产物时，比较复用和传输成本。

### 并行和 runner

- 让独立 job 并行。删除只用于排序且无依赖的 `needs`。检查 outputs、artifacts、共享资源和汇总检查是否依赖该顺序。
- 将关键路径上最长的测试套件按耗时均衡拆到多个 runner。核对分片合起来覆盖全套用例，任一分片失败都能使必需检查失败。用实际排队和每片准备成本决定并行度。
- 将不依赖 macOS 的格式化、lint 和依赖审计移到 Ubuntu。GitHub Free 的标准 GitHub-hosted macOS runner 同时最多跑 5 个 job。并发额度由多个 workflow 共用。以目标仓库所在账户或组织的实际额度为准。参考 [GitHub-hosted runner 并发上限](https://docs.github.com/en/actions/reference/limits#job-concurrency-limits-for-github-hosted-runners)。

## 3. 推送、复测和交付

1. 本地验证改动和相关检查。获准推送验证时，提交本次改动并推到目标 PR 或测试分支。推送前检查该分支会触发哪些 workflow。只读诊断请求完成基线和建议即可。
2. 用 `gh run list --repo "$repo" --commit "$sha"` 和 `gh pr checks "$pr" --repo "$repo"` 找到此次提交的预期运行。以 run ID 和 attempt 跟踪至结束，并核对 PR 当前提交和必需检查。按改动验证文档 PR 能通过必需检查、代码 PR 仍跑全套、同一 PR 连续推送时旧运行取消，以及 `main` 的触发与并发设置能保留全部发版验证。远端未触发或无法验证时记录具体原因。
3. 按基线口径重测。尽量匹配事件、runner、测试范围和缓存状态。用首轮结果找剩余瓶颈。还有证据充分且在范围内的改进时再优化一轮，并验证新提交。遇到无法修复的阻塞，或本轮没有可证实的改进时结束。
4. 给出优化前后对比表。至少列 workflow 端到端耗时、关键 job 的排队／准备／执行、样本数及耗时变化。涉及取消、跳过或拆分时补充运行数量或总 runner 耗时的变化。附前后 run 链接、SHA、缓存状态和必需检查结果。样本少或条件不匹配时说明证据的限制。缺失数据标为未测量。
