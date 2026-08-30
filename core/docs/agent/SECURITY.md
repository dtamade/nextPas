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

> 权威默认值总表在 `API.md §10`，本表为安全视角的引用；数值与单位以 API 表为准，三表一致性由 `test_security` 锚定（F-L07 G6 2026-08-29）。

| 面 | 上限/规则 | 权威常量（单一真源 `nextpas.core.agent.base`） | 追踪 | 超限行为 |
|----|----------|--------------------------------|------|---------|
| SSE 单行长度 | 1 MiB | `CSSEMaxLineBytes`（`sse` 单元，值同 `CAgentMax*` 族） | — | 抛 aecProtocol，终止流 |
| 单事件 data 总量 | 8 MiB | `CSSEMaxEventDataBytes` | — | 同上 |
| 工具参数 JSON 大小 | 256 KiB（校验前预检） | `CAgentMaxToolArgsBytes`（`tools CTOOL_ARGS_MAX_BYTES` 为 alias） | — | 合成 error result 回喂（不算流错误）|
| 工具结果回喂 | TruncateLines/TruncateBytes（loop 默认 2000 行 / 64 KiB） | `TAgentLoopOptions.TruncateLines/TruncateBytes` | — | 截断 + Truncated=True |
| wire 单头大小 | 8 KiB（名+值） | `CAgentMaxWireHeaderValueBytes`（`provider.common` 为兼容 alias） | SEC-04 | 抛 aecProtocol，请求不上送（兼容网关畸形头）|
| wire 总头大小 | 64 KiB（累计） | `CAgentMaxWireTotalHeaderBytes`（`provider.common` 为兼容 alias） | SEC-08 | 同上 |
| 成功体累积上限 | 8 MiB | `CAgentMaxSuccessBodyBytes`（`transport.http CMaxSuccessBodyBytes`/`provider.common` 为兼容 alias） | — | 抛 aecProtocol，截断体以 RawBodySnippet 保真 |
| RawBodySnippet | 8 KiB UTF-8 安全截断 | `CAgentMaxRawBodySnippetBytes`（`provider.common CMaxRawBodySnippetBytes` 为兼容 alias） | — | — |
| Extra 无损捕获字段数 | 单消息/part 64 个未知键 | `CAgentMaxExtraKeys`（`provider.common CMaxExtraKeys` 为兼容 alias） | — | 超出丢弃并 warn（防病态响应膨胀内存）|
| 工具槽位总数/索引 | 256 | `CAgentMaxSlotMap` | — | 超限抛 aecProtocol |

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

## 6. 会话存储安全（W5，设计权威 SESSION.md）

- **路径穿越防线**：ThreadId 强制 `[A-Za-z0-9._-]`、非点首、≤128 字符；
  违者抛 EAgentMisuse 且不回显原值（防日志注入与探测）。存储路径恒为
  `<RootDir>/<ThreadId>.jsonl` 直接拼接，无其他文件入口。
- **完整性 fail-closed**：崩溃残尾（文件末字节非换行）按恢复规则丢弃；
  完整行损坏或未知 schema 版本/kind → ETranscriptCorrupt（aecProtocol）
  含物理行号——绝不静默吞掉伪装成短历史。
- **机密面**：转录文件含完整对话明文；默认权限由 fs 层决定（0644/0755）。
  敏感场景消费方须将 RootDir 置于自身权限边界内并自行收紧或加密
  （v1 不做透明加密）。API key 不入转录——§1 头部边界天然保证：
  鉴权头属 transport 层，消息词表不含任何连接凭据。
- **并发边界如实声明**：同一线程 id 单写者假设；越界并发交错无锁保护，
  不作承诺（SESSION.md §7）。
