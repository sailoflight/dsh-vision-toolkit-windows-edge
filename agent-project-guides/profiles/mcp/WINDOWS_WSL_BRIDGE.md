# WIN-WSL 桥接 MCP 架构子类型规范

> 子类型 ID：`windows-wsl-bridge`。复制并规范化自通用 `bridge/ARCHITECTURE.md`。主类型为 `mcp` 且有 WSL/Linux client + Windows native/persistent Engine 证据时才读取；普通或单端 MCP 不适用。

本文件独占该拓扑的通用职责、提示投递和不变量。具体项目只在自己的 `bridge/ARCHITECTURE.md` 填写实例映射，不重写这些规则。

## 1. 适用场景

```text
agent/client in WSL
  -> client adapter
  -> WSL MCP Facade
  -> local-only bridge transport
  -> Windows MCP Engine
  -> native resources and handlers
```

Windows-only 资源包括 GUI、browser、driver、registry、SDK/service、credential store 或 persistent session。WSL 保持薄且无原生依赖；Windows 拥有实际运行态。

## 2. 角色与职责（核心契约）

| 组件 | Owns | Must not own |
|---|---|---|
| WSL Facade | 标准 MCP facade；完整转发 requests、responses、capabilities、instructions、tools、results、errors、notifications | 工具业务、Windows 依赖、凭据、持久状态、提示改写 |
| Windows Engine | initialize、canonical runtime prompt、tools/handlers、Windows 资源和持久运行态 | 开发仓库演化、公开暴露内层服务、依赖 WSL 根指令提供生产提示 |
| Client adapter | MCP connection、tool registration、受信提示的模型投递 | 丢弃 required instructions、用简介/tool description 代替角色提示 |
| Operator integration | 安装、prompt compatibility、health、restart、recovery、rollback | 产品业务和 cloud mutation authority |

**WSL 保证完整 MCP，Windows 保证工具与提示属于真实部署版本，client 保证模型实际收到提示。**

## 3. 数据方案（自由选择，双端协商）

外层固定为 MCP。内层可用 loopback TCP、Named Pipe、本地 HTTP/WebSocket 或其他 local transport，但必须仅本机可达、可重连，并在需要时握手/认证。不得丢失、截断或解释 initialize response，尤其是 capabilities 和 instructions。

## 4. 双生产角色运行时提示（强制）

Engine 提供有界、无秘密、带 revision 的 runtime prompt，同时包含：

1. **Role router**：公共能力/业务结果 -> `Production / User`；安装、配置、可用性恢复、观察、备份/恢复、回滚 -> `Production / Operator`；实质歧义先结构化询问。
2. **User contract**：只用 public capabilities/runtime schemas；优先最低成本、read-only、dry-run；mutation 满足 confirmation；不自行获得凭据、真实数据、额度、费用或破坏权限；runtime/deployment failure 转 Operator，不读源码/客户端配置自行扩权。
3. **Operator contract**：先取 read-only health evidence；只用匹配环境的 runbook；生产动作明确环境、身份、影响、backup/rollback、stop conditions 和 approval；不执行产品业务或直接改源码。
4. **Transition/authority**：角色名不授予凭据、真实数据、生产写入、restart、费用或不可逆权限；转换显式且不合并权限。

这是模型操作提示，**不是 MCP 产品简介、README、工具清单、开发 AGENTS 或部署广告**。动态工具、参数、版本、端口和环境状态继续由 tools/schema/state/generated authorities 提供。

## 5. 运行时提示的权威和投递路径

Windows Engine 拥有与 deployed handlers 同 revision 的 canonical prompt，通过 MCP initialization（通常 `initialize.instructions`）提供；WSL Facade 原样转发，不保存第二份手写提示。

```text
initialize
  -> receive dual-role prompt
  -> register/atomically replace namespaced model-prompt section
  -> expose tools/schema
  -> first model task/tool decision
```

`tools/list -> register tools` 不合格；tool description 不能承担角色边界。不能消费 runtime instructions 的 client，安装时必须使用从同一 source/revision 生成的 companion prompt。compatibility matrix 逐 client 记录 `native instructions | generated companion` 并实测模型可见。

## 6. 提示信任、隔离和生命周期

- 只有显式 trusted MCP installation 可把 instructions 提升为 system/context prompt；未知远程 MCP 默认不可信。
- prompt namespaced 且 capability-scoped，不覆盖其他 server/persona，不控制无关任务。
- reconnect/reinitialize 原子替换，不累积 revision；dispose 删除对应 section。
- last-known-good tools 与 prompt 的保留/失效策略必须一致，不能跨 generation 错配。
- diagnostics 只报告 server/prompt revision 和 delivery mode，不输出 secrets。

## 7. 硬约束（不变量）

1. WSL 是合法 MCP facade，内层传输对 client 透明。
2. User/Operator prompt 不依赖 repository `AGENTS.md`；外部 project、空 cwd、纯 chat 都能收到。
3. WSL 零/最小依赖，不持有 Windows objects、credentials、profiles、logs 或 runtime state。
4. Windows 拥有 native/persistent state 和 canonical prompt；client reconnect 不破坏它们。
5. 持久资源默认 single owner；内层 channel local-only；Engine heavy dependencies lazy-load。
6. protocol stdout 只有 MCP，diagnostics 到 stderr/Engine log。
7. development 在 WSL，deployment/runtime 在 Windows；sync 保留 ignored runtime data。
8. prompt/schema/handler 属于同一可验证 generation，deploy/reconnect/rollback 不静默错配。

## 8. 项目实例映射（必填）

项目 `bridge/ARCHITECTURE.md` 填写：

| 规范角色 | 项目实体 |
|---|---|
| WSL Facade | entrypoint、dependency boundary |
| Internal transport | address/name、local-only enforcement |
| Windows Engine | entrypoint、deployment location |
| Tools/native resources | registry/handler authority、resource owner |
| Canonical prompt | single authored source、revision、initialize implementation |
| Client adapters | client -> native/companion -> prompt section |
| Operator/runbook | health、restart、recovery authority |
| Verification | offline、protocol、bridge、external-client tests |

项目 ports、paths、selectors、SDK 和恢复命令只放该映射或 runbook。

## 9. 验收检查清单（通用）

- [ ] initialize/tools/list/tools/call 端到端正常，Facade 完整转发 prompt。
- [ ] Engine 返回当前 dual-role revision；每个 client 在首次工具判断前投递。
- [ ] tools 可见但 prompt 缺失会失败 compatibility validation。
- [ ] 无项目 `AGENTS.md` 的外部 cwd/聊天环境仍收到 User/Operator contracts。
- [ ] User availability success 后停止源码/配置调查；failure 转 Operator。
- [ ] Operator recovery 不获得 product mutation authority。
- [ ] reconnect 不重复 prompt；rollback 后 prompt/schema/handler 一致。
- [ ] WSL 无 Windows 重依赖、credentials、profiles、logs/state；channel 不暴露公网。

任一 supported client 看不到 runtime production-role prompt 时，本子类型不得标记完成。

## 10. 维护规则

- Facade change：验证完整 initialize relay 和 local smoke。
- Engine/tool/prompt change：offline tests -> sync Windows -> one restart -> generation check。
- Adapter change：验证 tool/prompt 同步 register、replace、dispose。
- Transport/prompt envelope change：同步 architecture、compatibility matrix、install config、runbook。
- 具体 selector/session/product workflow 留在项目模块或经验文档。
