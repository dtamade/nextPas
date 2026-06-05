# Task Plan: HTTP H1 writer header-only benchmark split

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经把 `bench_fullchain` 整理成 normalized output，本轮继续拆
`TH1ResponseWriter` 成本，把 header/status serialization 与小 body write 分离，
为下一批生产优化定位提供更稳的基线。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] 开 sidecar 子代理只读审计 H1 writer/header materialization seam，主线不等待。
- [x] RED：扩展 `bench_h1writer response serialization smoke`，要求真实
  `headers only 200` benchmark run row，而不是误匹配 `bench_filter`。
- [x] GREEN：新增 `BenchHeadersOnly200`，输出 `headers only 200` row。
- [x] 跑 focused benchmark gate，锁住 `bench_h1writer` 新 row 与 heaptrc 无泄漏。
- [x] 跑 fresh `headers only 200` live row，并同批刷新 `fixed 200 13B` 对照 row。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_h1writer/bench_h1writer.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh local `bench_h1writer` rows:

- `headers only 200`: `100000` iterations, `1414.6 ns/op`, `706917 ops/s`
- `fixed 200 13B`: `100000` iterations, `1389.1 ns/op`, `719869 ops/s`

这两条 row 都测 `TH1ResponseWriter` construction、headers mutation、status/header
serialization 和 in-memory sink。`headers only 200` 使用 `Content-Length: 0`，
不写 body；`fixed 200 13B` 额外写 13-byte body。

当前证据显示小 body write 不是主要差异，下一批生产优化应优先看 status-line /
header materialization，而不是 body copy 或 outbound buffer。

## Next target

继续 `6/6 benchmark/performance`。下一批建议先做一个极小生产优化候选：
`TH1ResponseWriter.WriteStatusLine` 对 `HTTP_STATUS_OK` 的 fixed status-line fast
path。必须先用 `test_http_h1writer` 锁住 wire bytes，再跑 `test_http_benchmarks`
和 `bench_h1writer` live rows；不要碰 `IHttpHeaders.ForEach`、header order、
chunked/no-body/HEAD contract。
