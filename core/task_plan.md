# Task Plan: HTTP headers allocation fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark/performance 阶段。用户指出 Pascal
llhttp 翻译可能存在 hot-path 性能问题；本轮不直接假设状态机本体有问题，而是先优化
已有证据指向的 `TH1Parser` adapter / `THttpHeaders` 分配路径。

本轮目标是把 `THttpHeaders` 从每次追加/删除都调整动态数组，改成 count + capacity
模型，减少 llhttp adapter 逐 header `Add` 时的分配抖动，同时保持公开 API 语义不变。

要求：

- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 headers/parser/fast/benchmark focused gates。
- 先证明 correctness 和 heaptrc，再记录性能结果；不使用脆弱的耗时阈值单测。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP docs、coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 增加 `Add 15 headers` benchmark，覆盖 llhttp adapter 常用追加路径。
- [x] 增加 headers compaction focused 语义护栏测试。
- [x] 将 `THttpHeaders` 改成 `FCount + EnsureCapacity`，删除/Set 去重仅清理可见尾部。
- [x] 运行 headers / H1 parser / H1 fast focused 验证与 heaptrc。
- [x] 运行 `bench_headers` before/after 对照。
- [x] 更新控制文件与 HTTP benchmark 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.headers.pas`
- `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- `benchmarks/nextpas.core.http/bench_headers/bench_headers.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- `THttpHeaders.Add` 不再每个 header 触发动态数组重新分配。
- 删除/Set 去重后保留容量，但 `Count`、`GetAll`、`ForEach`、`Clone` 只暴露有效条目。
- 为后续继续优化 `TH1Parser` span/string 分配、headers-complete 缓存 Host/Expect/Content-Length
  判定提供更稳的基础。
