# 包适配共享流程

> 仅由 Developer/`initialize`（新/空项目）或 Maintainer/`readapt`（已有项目）执行。角色日常规则在 guide，类型差异在 profile/subtype；本文件只拥有适配算法。

## 0. 激活、新鲜度和状态

仅在用户明确适配、active trigger、用户确认处理非 `adapted` 状态或有治理漂移证据时运行。文档确认-only 或用户禁止动作时，确认后停止，把以下检查留作获准开工后的第一步，不提前提问。

授权执行后验证本地关键文件并自动运行只读 `scripts/install.sh check-update`，不得先询问是否跳过。`current` 继续；`remote_differs/unavailable` 用结构化问答选择同步/重试、明确使用报告的本地版本或停止。

- installer 写 `pending/stale`。
- adaptation 写 `partial/adapted/blocked`。
- `adapted`：当前 revision、UTC、实际 scope、`reason=none`。
- `partial`：已闭环 scope 和剩余范围 reason。
- `blocked`：安全停止 scope 和非敏感 reason；trigger 保留。

## 1. 已解析角色和包路径

进入前必须已精确解析 Developer/`initialize` 或 Maintainer/`readapt`；不重新读 plane registry、发现角色或同时读两个 guide。未分配 trigger 只用有界证据判断新/已有；显式 role/mode/literal alias 在仓库发现前胜出。

记录的 `guide`、`procedure_by_mode`、`profile`、`spec` 全部相对治理包根目录解析。精确读取失败是包完整性错误，禁止用 glob 猜路径。

## 2. 任务卡和事实

```text
目标：要消除的冷启动、路由或治理问题
scope：repo/workspace/package/module；initialize/readapt
范围/非目标：允许规整和不改变的行为、模块、架构
主类型：mcp/library/cli/service/application-ui/data-automation/monorepo
现有证据：根入口、runtime/public entry、build/test/CI、docs index
风险：production/data/secrets/migration/network/cost/release/destructive
验收：角色路由、authority、模块定位、验证和 cold start
未知：需负责人决定的产品、架构、scope 或权限
```

事实只标 `verified/inferred/unknown`。README、roadmap、名称或旧文档不能覆盖当前实现、schema、build config 和 tests；影响行为、安全、公共契约、类型或 scope 的冲突必须询问。

确认和完成报告必须与工具轨迹一致，列出实际读取、搜索和失败路径；不得隐藏已读 registry/profile 或把失败后发现式搜索包装成首次精确命中。

## 3. 有界证据

1. 保留已加载根规则，不重读未变化的 injected root。
2. 一次有界根清单识别 scope、build、runtime/public entry、test/CI、docs index。
3. 定点读取足以判断主交付、authority 和 verification 的文件；不重复枚举、整仓全文读取或为填模板收集无关事实。
4. 保留 dirty worktree 和并行修改；无法安全区分则停止，不 reset/overwrite。

## 4. 主类型和条件子类型

按当前 scope 的主要消费者契约和运行形态，从 `routing/project-types.jsonl` exact grep 一个 quoted `id`，只读命中 profile；不得预读多个 profile 比较。不要按语言、框架或目录名分类。monorepo 根选 `monorepo`，package pass 再选该 package 的非 monorepo 类型。

没有精确类型或不可拆 scope 实质匹配多个类型时，以 `project_type` 结构化询问最近类型、拆分 scope、更新定义或不适用，并等待。

只有命中 `mcp` 且 profile 指示、拓扑证据精确匹配时，才 exact grep `routing/mcp-subtypes.jsonl` 的一个 ID 并读取 `spec`；不匹配不读 subtype。项目架构只填写通用 spec 的实体映射，不复制冲突规范。

## 5. Artifact plan 和 template

Artifact decision 闭合为：

- `required`：链接已验证 authority 或 merge/create。
- `conditional`：条件有证据才处理，否则 omit。
- `omit`：当前 scope 不新建；不删除已有 authority。
- `existing-authority`：只修索引/链接，不复制内容。

先写：`artifact -> decision -> authority/evidence -> action -> verification`。通用 template map：

| Artifact | Exact template |
|---|---|
| Root constraints | `templates/ROOT_AGENTS.md` |
| Role/task index | `templates/DOC_INDEX.md` |
| Development entry | `templates/DEVELOPMENT_START.md` |
| Current architecture/data flow | `templates/ARCHITECTURE_OVERVIEW.md` |
| High-value module/local overlay | `templates/MODULE_CONTRACT.md` |
| Change verification | `templates/VERIFICATION_MATRIX.md` |
| User surface | `templates/USER_USAGE.md` |
| Operator runbook | `templates/OPERATOR_RUNBOOK.md` |
| Field evidence | `templates/FIELD_EVALUATION.md` |
| Historical decision | `templates/ADR.md` |
| Subagent assignment | `templates/SUBAGENT_ASSIGNMENT.md` |

只在即将处理一个 artifact 前读取一个 exact template，完成 merge/link/verification 后再继续；禁止批量预读模板、枚举 `templates/`、覆盖更具体的现有内容或创建空文档。

## 6. Authority 和去重

```text
root instructions -> pre-read hard constraints + minimal project routes + managed state
INDEX             -> role/task -> one authority
Development       -> executable setup/build/test/generate entry
Architecture      -> current system/module/dependency/trust boundary
Module contract   -> one module's ownership/invariants/effects
Verification      -> change scope -> checks/risk gate/evidence
Usage             -> public consumer workflow/contract
Operations        -> runtime change/observe/recover/rollback
ADR               -> historical reason
Evidence          -> versioned observation
Roadmap           -> unimplemented plan
Generated         -> derived reference
```

同一动态事实只有一个 executable/schema authority；其他位置链接或给独立上下文必需的一行摘要。允许重复的只有安全红线、角色权限边界和权威入口。根项目内容不复制 managed routing；local `AGENTS.md` 只放进入子树前必须生效的差异并链接 contract。各角色完整视图保持分离。

## 7. 验证和 cold start

至少验证 JSONL/path/ID uniqueness、root marker/state/UTF-8/size、重复 managed candidates、links/commands/generated drift/secrets、artifact decisions、subtype conformance、公共/高风险 contract、architecture truth、并行修改保留，以及 trigger 最终移除。

无历史上下文 agent 应能：

1. 得到唯一 plane/role/mode；
2. 从 INDEX 命中一个 task authority，不枚举 docs；
3. 找到一个真实功能的 implementation/evidence/tests/verification；
4. 说明 authority、permission、effects 和 documentation trigger；
5. monorepo 先选 package，Production 只读其 delivery surface；
6. 不明确时在扩读或副作用前结构化询问。

记录 reads/token/searches/wrong assumptions/clarifications/rework；正确性不能让位于 token 指标。

## 8. 完成和停止

`partial` scope 也必须形成 `root/index -> authority -> implementation/evidence -> verification` 闭环，并列出剩余顺序。完整完成：

```text
scripts/install.sh set-state --status adapted --verified-at <UTC> --scope <scope> --reason none
scripts/install.sh remove-trigger   # trigger only
```

无法判断公共行为、authority 冲突、需要改变产品/架构/安全边界、需要 production/real data/irreversible action，或并行修改无法安全合并时，写 `blocked` 并请求负责人决定。

禁止把 inferred/unknown 写成事实、删除有效 authority、用文档数量代替 cold-start acceptance、把所有角色塞入 root，或在日常任务中重复整套适配。
