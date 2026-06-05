# Task Plan: HTTP adapter_no_url fast-gate optimization

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批 median snapshot 显示 `adapter_no_url` 是最清晰的 nextPas 内部 fast-gate 差分。
本轮先用 narrowed benchmark 证明旧路径存在 fast parse 后又 llhttp parse 的 double-parse
成本，再做最小生产优化：HTTP/1.1 显式 `Connection: keep-alive` 不再强制离开 H1 fast path。

本轮不改 public HTTP API，不手改 generated `src/nextpas.core.http.impl.h1.llhttp.pas`，
不写 `docs/nextpas.core.http.inbox.md`，不跑全量仓库测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] 派只读子代理并行定位 `adapter_no_url`、`url_path` 与 benchmark fairness。
- [x] RED：`bench_h1parser` filtered `adapter no-url` 当前没有 narrowed rows。
- [x] RED：`test_http_h1fast` 期望 connection-policy flags，编译失败证明字段缺失。
- [x] GREEN：`TFastParseResult` 增加 `ConnectionKeepAlive` / `ConnectionClose` /
  `ConnectionUnsupported`，fast parser 解析 trimmed exact connection token。
- [x] GREEN：H1 server fast gate 放行 HTTP/1.1 `Connection: keep-alive` no-body request，
  `close` / `upgrade` / unsupported token 仍回退 llhttp。
- [x] GREEN：`bench_h1parser` 增加 `adapter no-url` narrowed rows：
  metadata 3 headers、old fast-reject + llhttp、llhttp direct、fast parse only。
- [x] Focused gates：`test_http_h1fast`、`test_http_benchmarks`、`test_http_server`。
- [x] Live rows：`adapter_no_url --runs 3` 与 `no_url --runs 3`。
- [ ] 更新 docs/control files。
- [ ] Path-limited stage/commit。

## Scope

本轮允许修改：

- `src/nextpas.core.http.impl.h1.fast.pas`
- `src/nextpas.core.http.impl.h1.pas`
- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `tests/nextpas.core.http/test_http_h1fast/test_http_h1fast.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Narrowed benchmark confirms the old `adapter_no_url` route paid double parse:

| row | ns/op |
| --- | ---: |
| `adapter no-url: fast reject + llhttp` | 2084.3 |
| `adapter no-url: llhttp direct only` | 1494.0 |
| `adapter no-url: fast parse only` | 629.3 |
| `adapter no-url: metadata 3 headers` | 372.2 |

After the production fast-gate change, same-host server comparison:

| workload | nextPas median ns/op | nextPas median req/s | Rust median ns/op | Go median ns/op |
| --- | ---: | ---: | ---: | ---: |
| `adapter_no_url` | 11022 | 90720 | 8843 | 53076 |
| `no_url` | 10948 | 91335 | 8935 | 49245 |

`adapter_no_url` improved from earlier same-day `12280 ns/op` to `11022 ns/op`。
但子代理 fairness review 指出该 workload 不是跨语言 apples-to-apples；它应作为 nextPas
内部 fast-gate differential，而不是永久排名依据。

## Next target

继续 `6/6 benchmark/performance`。下一批建议先补 benchmark harness contract：
server comparison summary 应断言 `completed == requests`，并给 nextPas row 输出更明确的
request-path marker（例如 fast/adapter counter 或等价 trace），再转向 `url_path`
的 path-only URL materialization narrowed proof。
