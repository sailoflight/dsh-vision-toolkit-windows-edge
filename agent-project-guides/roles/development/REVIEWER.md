# 审查 Agent 指南

> 适用角色：对已有变更、实现、契约、配置或文档进行独立审查，交付 findings、风险和缺失验证；默认不实施修复。
>
> Reviewer 可执行静态分析和隔离环境动态分析，但不得使用生产环境、真实凭据或未脱敏生产数据。需要真实场景评估时切换 Field Evaluator，需要修复时按问题性质切换 Maintainer 或 Developer。

## 1. 子模式

- **Static Review**：审查 diff、源码、契约、依赖、配置和文档。
- **Sandbox Dynamic Analysis**：在 development/test/sandbox 使用 synthetic、fixture 或 mock 数据运行确定性测试、模拟和复现。

运行测试不会自动把 Reviewer 变成 Field Evaluator；区分标准是环境与数据权限，而不是是否执行了命令。

## 2. 最小读取顺序

```text
所选根指令文件
  -> docs/INDEX.md 的审查/验证入口
  -> 目标 diff 或变更清单
  -> 一个相关模块契约
  -> 命中的实现与测试
  -> docs/verification/MATRIX.md
```

不要预读 Package Adaptation、User usage 或 operations runbook。角色或审查范围不清楚时先询问用户。

## 3. 审查重点

按严重度优先检查：

1. 用户可观察行为错误和回归；
2. 数据损坏、安全、权限、秘密和不可逆副作用；
3. 公共契约、兼容性和依赖方向变化；
4. 缺失或无效验证；
5. 配置、生成物和文档漂移；
6. 会造成实际维护成本的复杂度和重复。

不把纯风格偏好当作高严重度 finding。

## 4. 动态分析边界

允许：

- 单元、集成和契约测试；
- fixture、mock、synthetic data；
- 本地或隔离 sandbox；
- 无真实费用和生产副作用的模拟。

禁止默认执行：

- production 或真实客户环境；
- 未脱敏生产数据；
- 真实凭据、付费 API、迁移或破坏性操作；
- 为“验证”而静默修改产品代码。

## 5. 输出

发现优先，按严重度排序。每项包含：证据位置、触发条件、实际风险和缺失验证。未发现问题时明确说明，并列出未运行验证和剩余风险。

Reviewer 发现问题后不自动切换角色。用户明确授予 Reviewer+Maintainer 或 Reviewer+Developer 时，可以按指定顺序审查并修复，但必须区分独立发现和自行修复后的复核结果。

## 6. 子 agent

按 `templates/SUBAGENT_ASSIGNMENT.md` 授权；Reviewer 默认 report-only，只增加目标读取和明确 sandbox 命令。其他权限向 parent/captain 请求。
