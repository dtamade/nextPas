# SECURITY：密钥处理、脱敏与 fail-closed 规则

> 本模块接触两类敏感资产：厂商 API key 与用户提示内容。
> 本文规则是验收项，不是建议。

## 1. API key 流转边界

| 位置 | 规则 |
|------|------|
| TProviderOptions.ApiKey / env | 唯一录入点；env 值读入后不回显 |
| wire 请求头 | 仅 transport 组装处使用 |
| EAgentError.Message / RawBodySnippet | **禁止出现**；错误路径只携带响应侧信息 |
| 日志 | 禁止记录请求头；如必须记 URL，剥 query |
| FromEnv 返回 nil | 缺 key 静默返 nil（CONSUMERS §3），绝不打印 env 值辅助排障 |

## 2. 脱敏等级表（log.intf 接入时生效）

| 级别 | 内容 | 示例 |
|------|------|------|
| debug | 方法/URL(无 query)/模型/耗时/状态码/重试次数 | `POST /v1/messages model=claude… 429 retry=1` |
| info | debug + 消息 id、finish reason、usage 数值 | — |
| warn | 可重试失败、怪癖容错触发（Q-O6 等）、截断发生 | — |
| error | 最终失败的 code+message（信封解析后）| — |

任何级别都不得输出：Authorization/x-api-key 头值、完整请求体、
RawBodySnippet 全文（摘要仅随异常对象走，日志只记 code 与长度）。

## 3. DoS / 恶意输入防线（全部 fail-closed）

| 面 | 上限/规则 | 超限行为 |
|----|----------|---------|
| SSE 单行长度 | 1 MiB | 抛 aecProtocol，终止流 |
| 单事件 data 总量 | 8 MiB | 同上 |
| 工具参数 JSON 大小 | 256 KiB（校验前预检） | 合成 error result 回喂（不算流错误）|
| 工具结果回喂 | TruncateLines/TruncateBytes（loop 默认 2000 行 / 64 KiB） | 截断 + Truncated=True |
| RawBodySnippet | 8 KiB UTF-8 安全截断 | — |
| Extra 无损捕获字段数 | 单消息/part 64 个未知键 | 超出丢弃并 warn（防病态响应膨胀内存）|

理由：这些上限防御的是**被攻破或恶意的"兼容网关"**——OpenAI-compatible 生态里
BaseUrl 可指向任意第三方，响应即不可信输入。

## 4. Fail-closed 规则清单（继承 code888 纪律）

- pkImage mime 白名单 png/jpeg/gif/webp，违者 aecConfig 不上送。
- 工具 schema 结构校验失败 → error result 回喂模型，**不是**静默跳过该调用。
- anthropic MaxTokens unset → aecConfig，绝不静默默认。
- decoder 帧序违例 → aecProtocol 终止，绝不容忍继续消费错位流
  （宽容仅限 WIRE-MAPPINGS 明列的怪癖条目）。
- 未知 Thinking/ParallelToolCalls 枚举值（前向兼容场景）→ 按 tsUnset 处理并 warn，
  不猜语义上送。

## 5. 供应链与依赖面

- 零第三方库：全部实现于 nextpas.core 自有底座（json/http/sse/async）之上；
  不动态加载任何本模块私有的原生库。
- 无代码执行面：工具执行永远发生在消费方注入的 IAgentTool 实现内，
  本模块不做任何字符串求值/shell 拼接。
