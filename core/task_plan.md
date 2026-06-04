# Task Plan: http server options demo smoke

## Goal

给 `examples/nextpas.core.http/http_server_options_demo` 补一个 focused
example smoke，证明这个示例不只是“能编译”，而是：

- 可从测试里自动构建
- 可作为外部进程启动并进入 ready 状态
- `/health`、`/hello/:name`、`/echo` 这三条文档路径可用
- `MaxBodySize=64` 的 oversize ingress 会被直接拒绝为 `413`

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关路径
- [x] 读 `docs/design-conventions.md`、HTTP 控制文件与覆盖矩阵
- [x] 对照 `test_config_examples` / `test_http_smoke`，确定外部 example smoke 模式
- [x] 新增 `tests/nextpas.core.http/test_http_examples`
- [x] 让 smoke 负责：
  - `make build` 构建 example
  - 启动独立 server 进程并探测 ready marker
  - 用 `IHttpClient` 验证 `/health`、`/hello/world`、`POST /echo`
  - 验证 oversize body 返回 `413` 且不是 handler 正常回包
- [x] 更新必要控制文件与覆盖矩阵
- [x] 跑 focused `test_http_examples`
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_examples/`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改 HTTP 生产实现
- 不跑全量测试

## Intended outcome

- `http_server_options_demo` 从“文档示例”提升为“带 focused smoke 证据的可运行契约”
- 后续若再扩这个 example 的公开演示面，可以直接在同一 smoke 上继续加窄断言
