# Task Plan: H1 fast parser lazy headers

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮针对用户提出的 llhttp Pascal 翻译性能疑虑先做证据拆分：Pascal translated
llhttp 相比 C llhttp 确实有本机 raw gap，但当前 full parser / server hot path 更大的
成本仍在 adapter/materialization。基于这个判断，本轮做一个窄生产优化：fast parser
成功路径不再 eager 构造完整 `THttpHeaders`，普通 server fast-path request 如果 handler
不读 headers，就避免 header 容器物化。

本轮不改公开 HTTP facade API，不改 wire contract，不写
`docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核设计规范、HTTP coverage/benchmark/control 文件、git status。
- [x] 用子代理只读审查 Pascal translated llhttp 性能疑点。
- [x] 本地复跑 `bench_h1parser` 与 C llhttp comparator，确认 raw gap 与 adapter gap。
- [x] 新增 focused RED：fast parser 对 invalid header name/value 应 fallback，而不是因 eager header materialization 抛异常。
- [x] `FastParseRequest` 改成 scan-time header validation + lazy `IHttpHeaders`。
- [x] server fast snapshot 路径使用已知 policy facts，避免 `HeaderPolicyErrorStatus` / keep-alive / Host 检查触发 header materialization。
- [x] 跑 `test_http_h1fast` focused gate + heaptrc。
- [x] 跑 `test_http_server` focused gate + heaptrc。
- [x] 跑 `bench_h1parser` / `bench_server` sanity。
- [x] 跑 `git diff --check`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.fast.pas`
- `src/nextpas.core.http.impl.h1.pas`
- `tests/nextpas.core.http/test_http_h1fast/test_http_h1fast.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Pascal translated llhttp 本体有真实优化空间，但现在不应手改大状态机。当前最佳小步是继续削
adapter/materialization：lazy headers 已把 fast parser 代表性 microbench 大幅压低，并保持
server 274-case contract gate 绿色。

## Intended outcome

- 保持 server fast path 的严格入口策略。
- fast parser 成功时延迟 header 容器构造。
- invalid fast header name/value 干净 fallback 到 llhttp/server validation。
- 为后续更可信 benchmark runner 和更深 adapter materialization 优化铺路。
