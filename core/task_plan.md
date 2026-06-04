# Task Plan: http multiple trailer declaration contract

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀只补 chunked trailer
公共契约的窄缺口：

- 不扩散到新的 malformed/runtime 家族
- 只把已有单个 trailer 声明契约扩成 single / multiple declaration 都有直接 proof
- 锁定“保留 `Trailer` 声明头，但真实 trailer fields 不泄漏到普通 headers”
- 如果只是既有 truth 缺测试，本轮保持 coverage-expansion，不改生产代码

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 trailer multiple declaration contract
- [x] 在 `test_http_contract` 新增多 trailer 声明 focused proof
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_contract test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_contract/test_http_contract.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改生产代码
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- chunked trailer 公共契约不只覆盖：
  - 单个 trailer 声明
- 还要直接覆盖：
  - 多个 trailer 声明放在同一个 `Trailer` header value
- 证据要求：
  - handler 仍可读到解码后的 body
  - `Trailer` 声明头原文保留
  - trailer field 不出现在普通 header 查询面
  - heaptrc `0 unfreed memory blocks`
