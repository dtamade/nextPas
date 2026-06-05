# Task Plan: HTTP H1 writer header-line coalescing

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经把常见 `HTTP_STATUS_OK` status-line 改成单次 fixed write；本轮继续在
`TH1ResponseWriter.WriteAllHeaders` 上隔离 response serialization 成本，在不改变
public API / wire contract 的前提下降低常见 full-progress writer 路径的小写入次数。

本轮不改 public HTTP API，不改 server/client 架构，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] RED：`test_http_h1writer` 新增 header-line exact wire bytes / full-progress write-call contract。
- [x] 验证 RED：当前实现每个 header 拆成 name / separator / value / CRLF 多段写入，测试失败为 `expected 4, got 10`，heaptrc `0 unfreed memory blocks`。
- [x] GREEN candidate 1：简单字符串拼接合并 header line。
- [x] benchmark 复盘：简单拼接版减少 write calls 但 live rows 退化，因此不保留。
- [x] GREEN candidate 2：常见 header line 用 512-byte 栈缓冲物化，长 header line fallback 到 heap string。
- [x] 跑 focused writer gate，确认 wire contract / call-count contract 与 heaptrc。
- [x] 跑 focused benchmark gate，确认 benchmark contract 与 heaptrc。
- [x] 跑 fresh `bench_h1writer` filtered rows，判断收益并决定保留。
- [x] 更新 API coverage / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `src/nextpas.core.http.impl.h1.writer.pas`
- `tests/nextpas.core.http/test_http_h1writer/test_http_h1writer.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

`TH1ResponseWriter.WriteAllHeaders` header-line stack-buffer coalescing 保留。

Fresh local `bench_h1writer` rows after the kept implementation:

- `headers only 200`: `100000` iterations, `1247.1 ns/op`, `801852 ops/s`
- `fixed 200 13B`: `100000` iterations, `1250.5 ns/op`, `799680 ops/s`

Compared with the previous committed local rows after the `HTTP_STATUS_OK`
status-line fast path:

- `headers only 200`: `1284.0 -> 1247.1 ns/op`
- `fixed 200 13B`: `1261.1 -> 1250.5 ns/op`

这条优化不改 `IHttpHeaders.ForEach` public surface、header order、lowercase
normalization、repeated headers、short-writer retry、chunked default、
no-body statuses 或 HEAD suppression。

## Next target

继续 `6/6 benchmark/performance`。下一批建议评估 response writer 更大粒度的 header
block / outbound buffer seam：不要继续无证据地堆微优化，优先确认 full-chain server
瓶颈是否仍在 response serialization、router dispatch、request construction，还是已经转移到
TCP/session 调度。
