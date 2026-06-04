# Task Plan: Header name normalization fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 `6/6 benchmark/performance` 阶段。上一批
`bench_h1parser` 诊断已经把瓶颈继续指向 adapter materialization，而不是 Pascal translated
llhttp callback dispatch。本轮落一个窄优化：降低 `THttpHeaders.Add` / `Set_` 在 lowercase hot path
上的 header-name validation + normalization 成本。

parser callback 已经把 header field 以 lowercase 形式写入 `THttpHeaders`；旧实现仍会先
`ValidateName` 扫描一次，再 `Normalize` 扫描/复制一次。目标是把 validation 和 uppercase 检测合并，
lowercase valid name 直接复用原字符串，只有 uppercase public input 才进入 Normalize。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 检查 `THttpHeaders.Add` / `Set_` 当前实现与 tests。
- [x] 跑 `bench_headers` baseline。
- [x] 增加 validation guard：非法 name/value 仍由 Add/Set 抛 `EHttpError`。
- [x] 实现 combined validate + needs-normalize fast path。
- [x] 运行 `test_http_headers` focused gate + heaptrc。
- [x] 运行 `test_http_h1parser` parser gate + heaptrc。
- [x] 运行 `bench_headers` after + confirmation。
- [x] 运行 `bench_h1parser` projection。
- [x] 更新 benchmark/control 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.headers.pas`
- `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- lowercase parser/server hot path 少一次 name scan/copy。
- public uppercase/mixed-case input 仍保持 case-insensitive lookup 与 canonical lowercase storage。
- invalid header name/value validation 不退化。
