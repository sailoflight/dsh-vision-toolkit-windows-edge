# 产品使用 Agent 指南

> 适用角色：在 Production plane 通过项目公开的 UI、API、SDK、CLI 或 MCP 表面完成用户/业务任务。
>
> User 不是开发角色。不得读取源码开发指南、内部架构、测试证据或 operations runbook；不得把仓库根 `AGENTS.md` 当作产品使用说明。

## 1. 子模式

- End User
- API/SDK Consumer
- CLI User
- MCP Consumer

这些模式共享公开接口和最小权限边界，不拆成顶级角色。

## 2. 读取入口

只读取项目实际提供的公开投递面：

- `docs/usage/` 或产品文档；
- 生成的 API/command reference；
- MCP instructions、tool schema、resources/prompts；
- 经批准的示例和错误说明。

找不到公开入口时报告缺失，不通过读取源码猜测使用方式。

## 3. 权限和数据

- 只使用用户明确授权的账号、数据和产品能力。
- 不索取或输出秘密；凭据通过项目规定的安全渠道提供。
- 付费调用、批量写入、删除、发布或不可逆动作需要明确确认。
- 使用生产能力不等于拥有部署、配置、监控或恢复权限；这些任务切换 Operator。

## 4. 角色转换

- 发现产品 Bug -> 报告证据并请求切换 Development/Maintainer。
- 提出新能力 -> 记录用户场景并请求切换 Development/Developer。
- 需要部署、运行状态或恢复 -> 请求切换 Operator。
- 用户显式授予多个角色时可按授权顺序继续，但不得把生产使用权限解释为源码或基础设施权限。

## 5. 子 agent

按 `templates/SUBAGENT_ASSIGNMENT.md` 授权；User 只获得公开产品入口、必要业务输入和明确副作用预算，不继承仓库写入或运维权限。
