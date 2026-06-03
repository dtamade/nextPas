# Findings: HTTP server lifecycle contract surfacing batch 7

## Root causes

- `THttpServer` 实际已经提供了 `IsRunning`，测试辅助代码也在直接消费它，
  但 `IHttpServer` public contract 之前没有这条生命周期状态访问器。
- 结果是同一个 HTTP server 生命周期语义只能通过具体类消费，不能通过公开接口消费。
- 这会让 interface-first 使用方式与真实实现能力脱节，也让 `IHttpServer` /
  `THttpServer` 这条公开契约在文档和测试层面不够自洽。

## Fixed design truth

- `IHttpServer` 现在公开拥有 `IsRunning: Boolean`。
- 因此调用方可以只依赖 `IHttpServer`，直接读取 pre-listen / post-shutdown 的
  生命周期状态，而不必向下转成 `THttpServer`。
- `LocalAddr` 的 pre-listen placeholder 语义与 `Shutdown` 的 pre-listen
  安全语义也已通过同一条 focused contract test 一起锁定。

## Why this is the right fix

- 这让 `IHttpServer` 与 `THttpServer` 的生命周期公开面重新对齐，避免 public contract
  和实现真相分叉。
- `IsRunning` 已经是现有实现的稳定语义，补到 interface 不需要改运行时逻辑，
  只是把已存在能力正式纳入 API contract。
- 先用 focused test 锁住 lifecycle shape，后续 evented backend 演进时也能保持
  HTTP facade 的公开语义稳定。
