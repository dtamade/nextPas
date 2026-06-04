# Task Plan: http trailer public contract proof

## Goal

继续留在 `3/6 H1 正确性加固` 主线，但不再机械扩 malformed parity；这一批改为把当前 chunked trailer 的公共契约直接固化到 `test_http_contract`：

- 先复核矩阵，确认 malformed raw-wire 大块 proof 已基本饱和
- 把“`Trailer` 声明头保留，但 trailer field 不进入普通 headers”从 server/security 间接 truth 升格为 focused public contract
- 用真实 `THttpServer` + raw chunked request 做外部可见语义证明
- 如果直接 GREEN，则保持测试/文档批次，不改生产代码

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 审核 `test_http_contract` / `test_http_message`，确认缺的是 trailer focused public contract
- [x] 在 `test_http_contract` 补 raw-wire helper 与 trailer contract test
- [x] 跑 focused `make -C tests/nextpas.core.http/test_http_contract clean test`
- [x] 判断是否需要生产修复：本轮不需要
- [x] 更新 coverage 文档与控制文件
- [ ] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_contract/test_http_contract.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改生产代码
- 不跑全量测试

## Intended outcome

- 直接锁定当前 public contract：
  - chunked body 会被正常解码给 handler
  - `Trailer` 声明头保留可读
  - trailer fields 不会泄漏为普通请求头
- 给后续“是否需要真正 public trailer API”留出明确边界
