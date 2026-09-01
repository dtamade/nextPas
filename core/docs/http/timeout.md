# nextpas.core.http.timeout — 超时策略薄域契约

**模块**：`nextpas.core.http.timeout.{base,intf,pas}` 薄门面聚合 `http.base` 超时字段  
**层级**：L3 http（依赖 L0–L2，复用 `http.base` 单源，不复制 `bytes.ops`）  
**四件套**：`timeout.base` ← `timeout.intf` ← `timeout` 门面  
**对应主契约**：`CONTRACT.md` §1.1 超时行 + §2.1/§2.2 Timeout/IdleTTL/IdleTimeout/ReadTimeout/WriteTimeout 对照

## 职责

- 统一 **Client/Server 超时策略**单源视图：`Timeout` / `ConnectTimeout` / `IdleTTL` / `ReadTimeout` / `WriteTimeout` / `IdleTimeout`
- `EffectiveConnectTimeout` 单源：`ConnectTimeout>0 ? ConnectTimeout : Timeout`（与 `THttpClientOptions.EffectiveConnectTimeout` 同源 inline）
- `IdleTTL` 墙钟淘汰（默认 90000ms，0=关闭墙钟，借出/归还 `IdleAtMs` 检查） vs `IdleTimeout` 请求间隙（默认 30000ms，0=不因 idle 关连接）
- `ReadTimeout`/`WriteTimeout` 单次 IO 有界（默认 30000ms，0=无界仅长轮询/SSE），`IdleTimeout` 不是 mid-request stall 时钟

## 对照（从 CONTRACT §282 精简抽取，权威仍以 CONTRACT 为准）

| 旋钮 | 所有者 | 默认 | 作用 | 0 含义 | 不是 |
|------|--------|------|------|--------|------|
| **Server `IdleTimeout`** | `THttpServerOptions` | 30000 | keep-alive 请求间隙等待下一请求；`ReadTimeout=0` 时作读 deadline 回退 | 不因 idle 主动关连接 | 不是 mid-request stall（用 `ReadTimeout`）；不是池淘汰 |
| **Client `IdleTTL`** | `THttpClientOptions` | 90000 | 池空闲连接墙钟淘汰（`IdleAtMs`） | 关闭墙钟淘汰 | 不是 server keep-alive；不是 per-request Timeout |
| **Server `ReadTimeout`/`WriteTimeout`** | `THttpServerOptions` | 30000 | 单次读/写 IO 有界；mid-request stall 用 Read | 无界（长轮询/SSE 才显式 0） | 替代不了 IdleTimeout |
| **Client `Timeout`** | `THttpClientOptions` | 30000 | request 读/写 budget | 无界（测试/工具） | 替代不了 IdleTTL |

要点与生产 checklist 详 `CONTRACT.md` §2.2（本域仅提供可复用策略薄抽象，不复制业务表）。

## 性能

- 全部判定 `inline`（`EffectiveConnectTimeout` / `IsExpired` / `ShouldCloseIdle`），无分配、分支最小
- 零拷贝：TTL 检查为纯整数墙钟比较（`IdleAtMs` / `NowMs`），不物化字符串；`bytes.ops` 单源保持（key 归一仍由 `pool` 域 `bytes.ops` 负责）

## 稳定性

- 策略对象不持有资源；`PoolClear`/`CloseIdle`/`Server Close` 释放路径不受策略抽取影响，heaptrc 0 unfreed 保持
- 0 值语义冻结：`IdleTTL=0` 仅关闭墙钟（仍可 `MaxPoolSize`/`CloseIdle`）；`ReadTimeout=0` 仅显式无界；与既有 `test_http_client` / `test_http_security` 行为一致

## Owner 边界

- 超时数值单源仍在 `nextpas.core.http.base`（`THttpClientOptions`/`THttpServerOptions`）；本薄模块仅 `inline` 视图转发，不新增可调阈值源
- 缺能力先反哺 `net`（dial 超时）、`async.timeout`（调度）、`errors`，不在 http 复制调度算法
