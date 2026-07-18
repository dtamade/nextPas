# nextpas.core.http Inbox

最近更新：2026-07-16

## 控制面状态

- Owner lane：`.worktrees/http` / 分支 `http`
- 当前阶段：**non-H3 stage-complete**；H3 honesty closed-as-blocked on QUIC
- 权威文档：
  - 完成度与切片队列 → `GOAL_TREE.md`
  - 稳定架构事实 → `ARCHITECTURE.md`
  - 公开契约 → `CONTRACT.md`（含 INV-12 keep-alive request-tail）
  - API 证据矩阵 → `API_COVERAGE.md`

## 已完成

### Slice 0 — 控制面 + 门禁

- 主 Makefile 34 focused suites
- 文档对齐真实 IHttp* / builder / H2
- router RFC 7807 测试 + group 泄漏修复

### P1 — keep-alive request-tail 契约定稿

- **Decision**: final public contract（不是 transport current truth）
- **INV-12** 写入 `CONTRACT.md` §3.1
- 策略摘要：
  - framing 完成 → 交付首请求；tail 进 `FPending`
  - partial follow-up 不早拒；可补全成合法第二请求
  - conclusively malformed / EOF 截断 follow-up → follow-up `400`
  - `Connection: close` + extra bytes → 同请求 `400`、不进 handler
- 证据：`test_http_h1parser` / `test_http_server` / `test_http_security`
- 不做：因 keep-alive 垃圾尾巴把已完成首请求改成同请求 `400`

### P2 — H2 facade 端到端证明

- 新增 `test_http_h2_facade`：live `NewHttpClient` / `NewHttpServer` +
  `Options.WithVersion(hvHttp2)` cleartext prior-knowledge
- 覆盖：GET 200、POST body round-trip、sequential GET、router 404
- 修复 `TH2ServerSession.Run`：`ExecuteReadyStreams` 后 `DrainWriteBuffer`，
  避免 keep-alive 客户端等 headers / 服务端阻塞 read 的死锁
- `ArmReadDeadline` 在 `ReadTimeout=0` 时回退 `IdleTimeout`，避免 join hang
- 证据：`test_http_h2_facade` → 4 passed / 0 failed / 0 unfreed
- 明确不做：h2c Upgrade、server push、WS-over-H2、TLS-ALPN facade E2E（已有
  下层 transport 覆盖）

### P3 — API surface 审计（默认停扩面）

- 推荐入口：`THttpRequestBuilder`；仅保留
  `NewRequest(Method, TUrl)` + `NewGetRequest` 为非 deprecated 工厂
- 修复 facade 6 处遗漏 `deprecated`（与 `message.pas` 对齐）
- source-contract：`test_http_contract` 锁住 facade/message deprecation parity
- 文档：`CONTRACT.md` / `README.md` builder-first；不新增第二套 API 族
- 刻意不扩面：builder 不加 `ContentLength()`；`Body(IReader)` 仍 CL=0
- 证据：`test_http_contract` → 31 passed / 0 unfreed

### P4 — runtime/socket 成本隔离

- 成本阶梯写入 `BENCHMARKS.md`：L0 `net/bench_tcp` → L1 micros →
  L2 fullchain Direct → L3 Router/Middleware → L4 server comparison
- 修复 SysUtils 清理后编译回归：`bench_fullchain` / `bench_server` /
  `bench_h1parser`（env/Exception + 缺逗号）
- `bench_fullchain` 接线 `SetFilter`/`SetMaxIterations`，输出 isolation markers
- 负载门禁：`test_http_stress` 3/0，0 unfreed
- 不做：跨语言排名断言、HTTP 内复制 net.server runtime

### P5 — H3 honesty（blocked on QUIC）

- **状态**：closed-as-blocked（诚实阻塞，不是伪完成）
- 仅有：`hvHttp3` 枚举 + registry seam + `HttpVersionToStr`
- 无：`impl.h3`、内建 client/server factory、空 facade
- 证据：`test_http_registry` 锁住 builtins 不注册 H3；未注册 resolve → `EHttpError`
- custom `Register*Transport(hvHttp3, ...)` 仍可作为 future-version positive proof
- **解阻条件**：独立 QUIC 模块（连接/流/TLS）落地后，再开 H3 frame/QPACK 实现 lane
- 不做：空 H3 public API、在 HTTP 内手写 QUIC

## 当前队列

1. ~~P1 keep-alive request-tail~~ ✅
2. ~~P2 H2 facade 端到端证明~~ ✅
3. ~~P3 API surface 审计~~ ✅
4. ~~P4 runtime/socket 成本隔离~~ ✅
5. ~~P5 H3 honesty~~ ✅ blocked on QUIC（无伪面）

### 可用性修复队列（2026-07-16 评估后）

规划见会话 plan；里程碑 M0–M7。默认：builder ContentLength+fail-fast；
`EHttpError.Kind`；context 请求内生+owned values；response Close；IMutex；
deprecated 本轮保留。

1. ~~M0 控制面文档~~ ✅
2. ~~M1 Builder body-kind / ContentLength / fail-fast~~ ✅
3. ~~M2 EHttpError Kind 骨架 + 关键路径~~ ✅
4. ~~M3 Context v2（附着 / SetOwnedValue / Has）~~ ✅
5. ~~M4 IHttpResponse.Close~~ ✅
6. ~~M5 TRTLCriticalSection → IMutex~~ ✅
7. ~~M6 Kind 广覆盖~~ ✅
8. ~~M7 全门禁 + 文档收口~~ ✅

H3 实现不在本 lane 开；需 QUIC 落地后新开 lane。
deprecated 物理删除为 optional M8（需单独确认）。

## Stage-complete 证据（2026-07-16）

- 可用性修复波次收口：`make -C core/tests/nextpas.core.http clean test` →
  **35 suites / 1723 passed / 0 failed**；`make hygiene` → pass
- 先前基线：35 suites / 1719 passed（同日 stage-complete gate repair）

## 明确不做

- public API 改成 async / callback-first
- HTTP 内复制 `net.server` runtime
- 空 H3 facade
- 临时 `task_plan` / `findings` / `progress` 进主线
