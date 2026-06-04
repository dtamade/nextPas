# Task Plan: http server expect-continue chunked ingress coverage

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续 request-side protocol
completeness，补齐 `Expect: 100-continue` 和 chunked ingress 的 live 契约：

- chunked request body 也应先收到单条 interim `100 Continue`
- handler 应读到解码后的 chunked body
- 如果 chunked ingress 在收到 `100` 之后跨 chunk 越过 `MaxBodySize`，
  最终仍应返回 `413`

要求：

- 优先复用现有 `Expect` helper 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_server` focused gate
- 不扩成大面积 `Expect` / chunked 组合矩阵

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `Expect + chunked` live contract
- [x] 在 `test_http_server` 补 chunked body readable / chunked MaxBodySize after-interim focused tests
- [x] 首轮 failed case 追到测试体自身 chunk-size literal 错误，而不是生产缺口
- [x] 把 oversize case 改成动态构造真实 700-byte chunks
- [x] 校正后 focused gate 直接 GREEN，本轮无需生产修复
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 security 大矩阵 / benchmark / server 基类重构

## Intended outcome

- `Expect: 100-continue` + chunked ingress 不再只靠推断，而是有 direct live proof
- threaded / epoll 两条 live 路径都锁住：
  - 先返回单条 `HTTP/1.1 100 Continue`
  - chunked body 仍能被正常解码交给 handler
  - chunked ingress 跨 chunk 越过 `MaxBodySize` 后最终返回 `413`
- 证据要求：
  - 新增 `Expect + chunked` tests GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
