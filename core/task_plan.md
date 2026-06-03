# Task Plan: http malformed transfer-coding focused expansion

## Goal

把 `nextpas.core.http` 在 malformed chunked request security 这条线上再收一格：

- 把 `Transfer-Encoding: chunked, gzip` 这条
  "`chunked` 不是 final coding" 契约补成 focused proof
- 同时把 parser / server / security 三层证据对齐
- 若当前 truth 已成立，则只补测试与文档，不做生产修复

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅 `docs/design-conventions.md`、HTTP 控制文件与当前 coverage 矩阵
- [x] 锁定当前最有价值的小缺口：
  - `Transfer-Encoding: chunked, gzip`
  - parser focused proof 缺位
  - server focused handler-not-called proof 缺位
- [x] 先补 focused tests：
  - `test_http_h1parser`
  - `test_http_server`
- [x] 跑 focused suites 与 heaptrc
- [x] 更新 `docs/http/API_COVERAGE.md`

## Scope

- 这轮只做 malformed transfer-coding focused coverage expansion。
- 不改 `nextpas.core.http` public API。
- 不切去 H1 poll-driven phase 2。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- parser 层直接锁定：
  - `gzip, chunked` -> unsupported transfer-coding
  - `chunked, gzip` -> malformed，因为 `chunked` 不是 final coding
- server 层直接锁定：
  - `chunked, gzip` -> `400`
  - handler 不落地
- 若当前实现已满足上述契约，则本轮作为纯回归扩面提交
