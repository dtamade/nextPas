# Task Plan: HTTP full-chain benchmark client read correction

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批完成 H1 writer narrowed rows 优化后，本轮先重新定位端到端瓶颈，避免继续盲目拆
writer 微优化。实测发现 multi-client server comparison 已经接近/超过 Rust std-only
baseline，但 `bench_fullchain` 明显偏低；本轮修正 benchmark harness 的客户端读法，让
full-chain row 不再被 byte-at-a-time client parser 主导。

本轮不改 public HTTP API，不改生产 server/client 代码，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] 跑当前 live rows：`bench_fullchain plaintext` 与 `run_server_comparison --workload no_url`。
- [x] 读取 `bench_fullchain` / `bench_server` / HTTP server/session 关键路径，定位差距来源。
- [x] RED：`test_http_benchmarks` 要求 `bench_fullchain` 输出 `client_read_mode=buffered`。
- [x] 验证 RED：fullchain smoke 缺 marker，`26 total, 25 passed, 1 failed`，heaptrc `0 unfreed memory blocks`。
- [x] GREEN：`bench_fullchain.ReadResponse` 从逐字节 read/string concat 改为 buffered chunk read。
- [x] 跑 focused benchmark gate，确认 benchmark contract 与 heaptrc。
- [x] 跑 fresh `bench_fullchain plaintext` live row，判断收益。
- [x] 更新 API coverage / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_fullchain/bench_fullchain.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

`bench_fullchain` buffered client read correction 保留。

Fresh live evidence:

- Before harness correction, RED smoke captured `plaintext`: `112063.8 ns/op`, `8923 req/s`.
- After buffered read, `plaintext`: `42132.4 ns/op`, `23735 req/s`.
- Same-turn server comparison `no_url`: nextPas `9345 ns/op`, `107002 req/s`; Rust std-only `9576 ns/op`, `104418 req/s`; Go `47251 ns/op`, `21163 req/s`.

这说明 multi-client server comparison 当前已经很强，fullchain 旧 row 主要受客户端逐字节读法影响。
修正后 fullchain 仍是单连接同步 ping-pong row，不能直接替代 server comparison。

## Next target

继续 `6/6 benchmark/performance`。下一批建议不要继续改 fullchain harness 本身，而是补一个
更正式的 multi-client comparison snapshot：加入 `--runs 3` 稳定 median，并优先确认
`adapter_no_url`、`url_path`、`response_1k` 三个 workload 是否仍有明显输给 Rust std-only
的路径。
