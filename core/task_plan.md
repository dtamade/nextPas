# Task Plan: HTTP H1 writer 200 OK status-line fast path

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经把 `TH1ResponseWriter` 的 header-only 与小 body rows 拆开，本轮在不改变
public API / wire contract 的前提下，对最常见的 `HTTP_STATUS_OK` status-line 做极小
fast path，减少小响应 header serialization 成本。

本轮不改 public HTTP API，不改 server/client 架构，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] 复核 `test_http_h1writer` 的 200/404/1xx/101/204/304/HEAD/short-writer/chunked 精确 wire contract。
- [x] 跑 `test_http_h1writer` baseline，确认当前 writer contract 与 heaptrc。
- [x] GREEN candidate：`TH1ResponseWriter.WriteStatusLine` 对 `HTTP_STATUS_OK` 写固定 `HTTP/1.1 200 OK\r\n`，其他 status 保持旧泛化路径。
- [x] 跑 focused writer gate，确认 wire contract 与 heaptrc。
- [x] 跑 focused benchmark gate，确认 benchmark contract 与 heaptrc。
- [x] 跑 fresh `bench_h1writer` filtered rows，判断收益并决定保留。
- [x] 更新 API coverage / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `src/nextpas.core.http.impl.h1.writer.pas`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

`HTTP_STATUS_OK` fixed status-line fast path 保留。

Fresh local `bench_h1writer` rows after the change:

- `headers only 200`: `100000` iterations, `1284.0 ns/op`, `778840 ops/s`
- `fixed 200 13B`: `100000` iterations, `1261.1 ns/op`, `792973 ops/s`

Compared with the previous committed local rows:

- `headers only 200`: `1414.6 -> 1284.0 ns/op`
- `fixed 200 13B`: `1389.1 -> 1261.1 ns/op`

这条 fast path 不改 header order、header normalization、chunked default、
no-body statuses、HEAD suppression 或非 200 status-line serialization。

## Next target

继续 `6/6 benchmark/performance`。下一批建议继续在 `TH1ResponseWriter` 内拆
header materialization：优先评估 `WriteAllHeaders` 多段小写入是否可以在不改变
`IHttpHeaders.ForEach` public surface 和 header order 的前提下合并输出。必须先用
`test_http_h1writer` 保护 precise wire bytes，再用 `bench_h1writer` filtered rows 判断是否保留。
