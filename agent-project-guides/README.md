# Agent 项目开发治理包

> 根入口只保留短路由和状态；JSONL 精确命中一个角色、一个主项目类型和必要的条件子类型，再按需读取对应权威文件。README 只做人类索引，不自动加载。

## 1. 运行模型

DeepSeek Harness 从 `.git` 根到 cwd 自动加载精确命名的 `AGENTS.md`、`CLAUDE.md` 和 local overlay。嵌套 README、registry、role、profile、procedure 和 template 不会自动加载。合并后的根入口上限为 16,384 bytes；每步重复的 permanent routing 必须保持最小。

普通任务路由：

1. active adapter trigger 只由当前已注入根上下文中的 exact `adapter-trigger:start/end` markers 决定；routing/state、`pending/stale` 和 bootstrap template 都不是 trigger。
2. 用户或 parent 已指定 plane/role/mode 时，在任何仓库发现前 exact content-grep quoted `id` 或 literal alias，直接使用唯一记录；禁止模糊 regex、全 registry 读取和重新分类。未精确命中的标签保持 unresolved，结构化询问而不做语义猜测。
3. 未指定时只读 `routing/planes.jsonl`；不明确则用结构化问答并等待。
4. 确定 plane 后只搜索对应 role registry，只读命中的 `guide` 和当前 mode 的 `procedure_by_mode`。
5. 阻塞问题使用稳定 ID、2–4 个互斥选项和一行影响；无问答工具时才直接提问。

所有 registry 路径都相对治理包根目录解析，失败是包完整性错误，不能用 glob 猜路径。

## 2. Registry 和角色

```text
routing/planes.jsonl
routing/production.roles.jsonl
routing/development.roles.jsonl
routing/project-types.jsonl
routing/mcp-subtypes.jsonl
```

每行是一个完整 JSON object。`scripts/validate-routing.mjs` 校验 JSON、唯一 ID/alias、闭合 role/type/subtype 集合、mode、profile/spec/procedure 和安全包根路径。

| Plane | Role | Modes | Guide |
|---|---|---|---|
| Production | User | end-user、api-sdk、cli、mcp | `roles/production/USER.md` |
| Production | Operator | deploy/configure、observe、incident、backup/recovery、rollback | `roles/production/OPERATOR.md` |
| Development | Developer | feature、initialize | `roles/development/DEVELOPER.md` |
| Development | Maintainer | code、readapt | `roles/development/MAINTAINER.md` |
| Development | Reviewer | static、sandbox-dynamic | `roles/development/REVIEWER.md` |
| Development | Field Evaluator | scenario-validation、exploratory-evaluation | `roles/development/FIELD_EVALUATOR.md` |

包适配不是顶级角色：新/实际上为空的项目使用 Developer/`initialize`，已有项目使用 Maintainer/`readapt`，两者额外读取 `procedures/PACKAGE_ADAPTATION.md`。普通 feature/code 任务不读适配流程。角色名称不授予生产凭据、真实数据、费用或破坏性权限。

子 agent 任务先按 `templates/SUBAGENT_ASSIGNMENT.md` 显式传递 plane、role/mode、scope、读写路径、环境/数据、网络/费用、破坏性权限、验证和 escalation；未传递的权限不继承。

## 3. 安装和状态

治理包必须 vendored 在目标项目内部；移除内层 `.git`。安装器按 existing `AGENTS.md` > 可容纳的 sole `CLAUDE.md` 选择根入口；过大的 sole `CLAUDE.md` 保持不变并新建短 `AGENTS.md`。managed routing 从所选文件 byte 0 开始，原项目内容 byte-identical 地保留为 suffix；旧尾部 block 会在下一次 merge 时迁移。local overlay 和未选根默认不变。

```bash
./agent-project-guides/scripts/install.sh merge         # permanent routing/state only
./agent-project-guides/scripts/install.sh trigger       # permanent block + one temporary trigger
./agent-project-guides/scripts/install.sh merge --sync-claude-scope  # optional AGENTS + CLAUDE role gate
./agent-project-guides/scripts/install.sh check
./agent-project-guides/scripts/install.sh check-update
./agent-project-guides/scripts/install.sh set-state --status adapted --verified-at <UTC> --scope <scope> --reason none
./agent-project-guides/scripts/install.sh remove-trigger
./agent-project-guides/scripts/install.sh unmerge
```

脚本不调用 LLM。重复 merge/trigger 幂等；`--sync-claude-scope` 仅在 `AGENTS.md` 被选中且 sibling `CLAUDE.md` 存在时，为后者前置一个独立 managed scope block。双文件 sync/unmerge 使用短暂 transaction marker；中断后任何 check 都失败，重跑同一命令恢复。unmerge 同时移除可选 block 并恢复两份原内容。重复 routing、symlink、非 UTF-8、无 Git root、包位于项目外或超过大小上限时拒绝。

状态 ownership：

- installer：`pending/stale`；版本变化把已有结果标为 `stale`，不会自动加 trigger。
- initialize/readapt：`partial/adapted/blocked`。
- `adapted`：当前 revision、UTC、实际 scope、`reason=none`。
- `partial/blocked`：闭环/阻塞 scope 和非敏感 reason。

当前初始行：

```text
Package adaptation: status=pending; package_revision=1.4.3; verified_at=never; scope=repo; reason=not_adapted
```

## 4. 云端新鲜度

`PACKAGE_REMOTE.json` 固定受信 repository、Contents API path 和 version URL。授权实际适配后自动运行只读 `check-update`，不先询问是否跳过；仅在 `remote_differs/unavailable` 时结构化询问同步/重试、明确使用报告的本地版本或停止。文档确认-only 请求完成确认后停止，把该检查留作获准开工后的第一步。

- `current`：本地等于云端。
- `remote_differs`：版本不同，不静默继续或更新。
- `unavailable`：网络、HTTP 或元数据失败，不伪装为 current。

private GitHub 依次使用 `GH_TOKEN/GITHUB_TOKEN`、authenticated `gh api`、anonymous raw fallback；命令不修改包、根入口或状态。

## 5. 内容权威和按需读取

| 文件族 | 唯一职责 |
|---|---|
| `bootstrap/` | permanent routing、一次性 trigger 和可选 CLAUDE scope 模板 |
| `routing/` | 精确选择记录和 package-root-relative 路径 |
| `roles/` | 一个角色的日常行为、权限和 mode 边界 |
| `procedures/` | 跨角色复用的执行算法；当前只有适配流程 |
| `profiles/` | 一个主项目类型的产物决策和验收差异 |
| `profiles/<type>/` | 只有命中时读取的条件架构子类型规范 |
| `templates/` | 一个目标产物的字段结构，不是覆盖命令 |
| `README.md` | 人类入口、命令和 ownership 总览 |

同一动态事实只保留一个 executable/schema authority；其他位置链接或给该上下文必需的一行结论。允许重复的只有：独立加载所需的安全红线、角色权限边界和权威入口。禁止复制完整工具/API/schema/参数/版本/package/command 清单，禁止 profile 复述 subtype 章节，禁止 README 复述 procedure 算法。

适配时只在即将处理一个产物前读取它的一个 exact template；完成合并和验证后再考虑下一个。不得枚举 templates、预读多个 profiles/subtypes 或为空目录创建文档。

## 6. 主项目类型和 MCP 子类型

闭合主类型：

```text
mcp
library
cli
service
application-ui
data-automation
monorepo
```

按当前适配 scope 的主要交付契约选择，不按语言、框架或目录名。monorepo 只用于根组合治理；package-scoped pass 再选择该 package 的非 monorepo 类型。不可拆混合或未定义类型通过结构化问答选择最近类型、拆分 scope、更新定义或判定不适用。

每个 profile 只拥有 selection boundary、artifact preset、evidence map、类型契约、verification preset 和 cold-start acceptance。Artifact decision 闭合为 `required/conditional/omit/existing-authority`。

MCP 条件子类型当前只有：

```text
windows-wsl-bridge -> profiles/mcp/WINDOWS_WSL_BRIDGE.md
```

仅在主类型为 `mcp` 且 WSL/Linux client + Windows native/persistent Engine 拓扑有证据时读取。MCP profile 规定所有 MCP 必须向受支持客户端投递可执行的 Production User/Operator runtime prompt；该 subtype 独占 Facade/Engine/client 的具体转发、注入、信任、生命周期和外部环境验收规则。产品简介、tool description、README 或仓库 `AGENTS.md` 都不能替代 runtime prompt。

## 7. Templates

| Template | 目标产物职责 |
|---|---|
| `ROOT_AGENTS.md` | 自动加载前必须成立的项目硬约束和最小入口 |
| `DOC_INDEX.md` | role/task 到一个权威入口 |
| `DEVELOPMENT_START.md` | 可执行开发环境、命令和生成入口 |
| `ARCHITECTURE_OVERVIEW.md` | 当前系统、模块、依赖、信任和数据边界 |
| `MODULE_CONTRACT.md` | 高价值模块的 ownership、invariants 和 effects |
| `VERIFICATION_MATRIX.md` | 变更范围到检查、风险门和证据 |
| `USER_USAGE.md` | 外部消费者工作流和稳定契约 |
| `OPERATOR_RUNBOOK.md` | 运行态变更、观测、恢复和回滚 |
| `FIELD_EVALUATION.md` | 带版本/scope 的非生产场景证据 |
| `ADR.md` | 历史决策原因和逆转条件 |
| `SUBAGENT_ASSIGNMENT.md` | parent 显式传递角色、scope 和权限 |

## 8. 验证和预算

```bash
node scripts/validate-routing.mjs
./scripts/test-install.sh
```

完整 suite 覆盖 managed-prefix ordering、旧 block 迁移、双根 opt-in scope 与中断恢复、原内容 round-trip、exact routing/aliases、path safety、profiles/subtypes、cloud freshness、state lifecycle、UTF-8、symlink、size 和 invalid metadata。

| 每步/路由文件 | 上限 |
|---|---:|
| permanent routing | 2,000 bytes |
| temporary trigger | 3,000 bytes |
| optional CLAUDE scope | 500 bytes |
| plane + role JSONL | 2,200 bytes |
| project type JSONL | 1,200 bytes |
| MCP subtype JSONL | 400 bytes |
| Developer guide | 4,000 bytes |
| adaptation procedure | 9,500 bytes |
| MCP profile | 5,500 bytes |
| Windows-WSL subtype spec | 8,500 bytes |
| README | 11,000 bytes |

README 不自动加载；预算用于阻止职责回流和重复增长，不以牺牲正确性为代价。
