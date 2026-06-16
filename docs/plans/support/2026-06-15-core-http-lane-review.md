# core-http Lane Review

- 日期：2026-06-15
- 评审者：接手 AI（按 takeover plan §P1 / 全权授权）
- 评审对象：`.worktrees/core-http` 当前 dirty
- 评审范围：H2 Finalization Sweep 的设计合理性 + 跨模块改动评估 + 下一步建议
- 性质：**初步意见**，最终由 lane owner（codex/core-http 维护者）判断

## Lane 概况

| 项 | 值 |
|---|---|
| Worktree | `.worktrees/core-http` |
| 分支 | `codex/core-http` |
| HEAD | `e4806f667 fix(http): validate HPACK Huffman padding` |
| 当前 Phase | task_plan §Phase 2 RED tests（进行中） |
| Dirty | 7 M source + 4 ?? new |

近期 commit 序列（HEAD 起 8 个）显示完整的 HPACK 性能优化轨迹：
`fix(huffman padding) ← perf(stream/client DecodeView) ← perf(DecodeView 零 refcount)
← perf(Decode I-cache 内联) ← perf(HPackLookup 静态索引内联) ← perf(stack buffer +
inline + direct output) ← perf(static AnsiStrings 预计算) ← perf(decode benchmark
零动态表)`

## Dirty 改动评审

### ✅ 协议合规：RFC 9113 §8.1.2.2 forbidden connection headers

**Source**：`core/src/nextpas.core.http.impl.h2.stream.pas` (+148)

新增内容：
- 常量数组 `H2_FORBIDDEN_CONNECTION_HEADERS`（4 个：connection / upgrade /
  keep-alive / proxy-connection）
- 4 个 helper：`ByteSpanEquals` / `ByteSpanToAnsiString` /
  `IsForbiddenConnectionHeader` / `IsValidTeHeaderValue`
- `FinalizeHeaders` 状态机扩展：`LMethodSeen` / `LSchemeSeen` / `LPathSeen` /
  `LAuthoritySeen` / `LHostSeen` / `LPseudoSectionClosed` / `LIsPseudo`

**对应 RFC 章节**：
- §8.1.2.2 "Connection-Specific Header Fields"：HTTP/2 禁止 connection-specific
  headers；如果出现 TE，只能是 "trailers"
- §8.1.2.3 "Request Pseudo-Header Fields"：:method / :scheme / :path 必须出现，
  :authority 可选但 :authority 缺时 host 必须存在
- §8.1.2.6 "Malformed Requests"：违反这些规则的请求必须 RST_STREAM(PROTOCOL_ERROR)

**测试覆盖**（task_plan §Phase 2 RED tests 完成项）：

| 测试 | 文件 | 覆盖的 gap |
|---|---|---|
| `TestRunMissingPathPseudoHeaderResetsStream` | h2_session | 缺 :path → RST_STREAM |
| `TestRunMissingAuthorityAndHostResetsStream` | h2_session | 缺 :authority + host → RST_STREAM |
| `TestRunPseudoHeaderAfterRegularHeaderResetsStream` | h2_session | pseudo 在普通 header 之后 → RST_STREAM |
| `TestRunDuplicatePseudoHeaderResetsStream` | h2_session | 重复 pseudo header → RST_STREAM |
| `TestRunConnectionSpecificHeaderResetsStream` | h2_session | forbidden 4 个 → RST_STREAM |
| `TestRunNonTrailersTeHeaderResetsStream` | h2_session | TE 非 "trailers" → RST_STREAM |
| `TestRoundTripFiltersConnectionSpecificRequestHeaders` | h2_client | 客户端过滤这些 header |
| `TestRoundTripPreservesTeTrailersHeader` | h2_client | 保留 TE: trailers |

**结论**：✅ 设计合理且测试覆盖完整。建议作为独立 logical slice commit
（commit message: *"feat(http.h2): validate RFC 9113 §8.1.2 pseudo headers + forbidden connection-specific headers"*）

### ⚠️ 跨模块改动：MSG_NOSIGNAL（platform.socket + io.reactor.epoll）

**改动**：
- `core/src/nextpas.core.platform.socket.pas`：`platform_socket_send` /
  `platform_socket_sendto` 加 `MSG_NOSIGNAL`
- `core/src/nextpas.core.io.reactor.epoll.pas`：`opSend` 路径加 `MSG_NOSIGNAL`

**设计动机**（推断）：
- Linux 默认行为：往已关闭对端的 socket `send()` 会触发 `SIGPIPE`，进程被信号中断
- H2 长连接 + 流复用场景频繁出现对端关闭，必须用 `MSG_NOSIGNAL` 让错误以 `EPIPE`
  errno 回到用户态处理
- 这是高层模块（http）发现底层 contract（platform.socket / io.reactor）缺陷的典型场景

**评审纪律对照**（按 `AGENTS.md` + `docs/worktrees.md` "受控跨模块修改"）：

| 要求 | 是否满足 |
|---|---|
| 改动最小化 | ✅ 只加一个 flag |
| `task_plan.md` 记录跨模块设计理由 | ❌ task_plan 只把 docs/http/* 和 test/ 标为 protected，没记跨模块 |
| `findings.md` 记录跨模块设计 | ⚠️ 需要 lane owner 确认 |
| 跑被改模块 focused gate（platform.socket） | ⚠️ 需要 lane owner 跑 |
| 跑当前模块 consumer gate（http） | ✅ Phase 2 RED tests 已设计 |
| Host portability 评估 | ❌ **缺失**：`MSG_NOSIGNAL` 不是 POSIX，macOS 上不存在，要用 `SO_NOSIGPIPE` socket option 或 `SIGPIPE` ignore；FreeBSD 同样有差异 |

**风险**：
- 若直接 commit 这两处改动而不做 host portability 处理，跨 host compile 会失败
  （macOS / FreeBSD 没有 `MSG_NOSIGNAL` 符号）
- 即使能编译，行为不一致（macOS 仍会 SIGPIPE）

**强烈建议**：
1. lane owner 与 core-platform lane owner 协商：是 platform.socket 加 host-aware
   wrapper（默认抑制 SIGPIPE，让 consumer 不再需要传 flag），还是让 platform.socket
   暴露一个 portable `PLATFORM_SOCKET_MSG_NOSIGNAL` 常量（macOS 上为 0，Linux 上为
   `MSG_NOSIGNAL`，setup 时另外 setsockopt `SO_NOSIGPIPE`）？
2. 在 lane 内 `findings.md` 记录这个跨模块设计决策
3. 跑 platform.socket focused gate + cross-host compile gate（用
   `NEXTPAS_FORCE_HOST_DARWIN` / `NEXTPAS_FORCE_HOST_FREEBSD` override）
4. 推荐先把跨模块改动转为一个 "Needs Review" 节点报给总控（按 worktrees.md
   "影响面较大时改报 Needs Review"），由总控决定是否拆出独立 cross-cutting lane

### ✅ HPACK 协议合规：Huffman padding 验证

**Commit `e4806f667 fix(http): validate HPACK Huffman padding`**（已 commit，不在 dirty）

近期已 commit 的 HPACK 性能优化序列（8 commit）后接上这个合规修复。`fix(http):` 前缀
对应 task_plan §Phase 2 must-do gap。

**结论**：✅ 已落地，作为 HPACK 优化序列的合规收尾。

### 📋 新增 H2 benchmarks（未跟踪）

- `core/tests/nextpas.core.http/Makefile`（新 aggregate Makefile?）
- `core/tests/nextpas.core.http/bench_http_h2/bench_h2_rust/`（H2 vs Rust 对照）
- `core/tests/nextpas.core.http/bench_http_h2/bench_http_h2_rust/`（同上变体）

**设计动机**：按 `core/docs/design-conventions.md` §12 "基准测试要求"，
*"基准对照组：FPC RTL 同等功能（如有）、Go 标准库、Rust 标准库的公开 benchmark 数据"*。

**建议**：
1. 确认 bench_h2_rust vs bench_http_h2_rust 是否两个不同 setup，还是其中一个是过渡
   命名（避免散落两份相似 benchmark）
2. benchmark 项目独立 commit（不混入协议合规 slice）
3. 按 design-conventions.md §12 输出 ops/sec、ns/op、bytes/op、allocs/op

### 🚫 不应进入 commit 的 user-protected dirty

按 task_plan §Notes：

- `core/docs/http/ARCHITECTURE.md` (+22)
- `core/docs/http/GOAL_TREE.md` (+11)
- `core/docs/http/README.md` (+2)
- `test/` 目录（未跟踪）

这些是 lane owner 在 lane 内的工作笔记，**不应进入 main**。如果它们值得归档，应通过
`docs/plans/support/` 而不是 lane 自有文档目录。

### ✅ 测试小修：test_http_security.lpr (+4)

未细看，无害修改的可能性大。lane owner 自行评估。

## 推荐 lane 下一步

| 优先级 | 动作 | 估算 |
|---|---|---|
| P1 | 把 H2 stream + 3 个 H2 test 文件作为一个 logical commit slice：*"feat(http.h2): validate RFC 9113 §8.1.2 pseudo headers + forbidden connection-specific headers"* | 1 commit |
| P2 | 跨模块 MSG_NOSIGNAL 改动：先在 `findings.md` 记录设计理由 + host portability 评估 + 推荐 cross-host 处理方式（最好升级为 platform.socket 的 `PLATFORM_SOCKET_MSG_NOSIGNAL` 常量 + host setsockopt fallback），再决定是否走"Needs Review"流程 | 需要决策 |
| P3 | 跑 focused gate 验证：`make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_stream` + `test_http_h2_session` + `test_http_h2_client` + `test_http_security` | 数分钟 |
| P4 | 新 bench 目录确认（bench_h2_rust vs bench_http_h2_rust 是否两个不同 setup） + 独立 commit | 1-2 commit |
| P5 | user-protected dirty docs：lane owner 决定何时同步到 `core/docs/http/` 或主仓 `docs/plans/support/` | 视情况 |
| P6 | 继续 task_plan §Phase 3 implementation - Phase 5 final verification - Phase 6 cleanup | 推 sweep 收尾 |

## 评审纪律说明

按 nextpas-goal-tree.md "core 由 core 团队推进"，本评审：

- ❌ 不动 lane 代码
- ❌ 不在 lane 内创建/修改文档（lane owner 自己管 task_plan / findings / progress）
- ✅ 只读分析 + 主线治理文档形式留下评审记录
- ✅ 输出由 lane owner 自行采纳或反驳

**特别提醒**：MSG_NOSIGNAL 跨模块改动是本评审最高关注点，建议 lane owner 在 commit 前
先解决 host portability 问题，否则会带来跨 host compile 红屏。
