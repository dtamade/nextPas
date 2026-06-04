# Task Plan: expect interim-100 body-stall idle-timeout truth

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，完成一个更高价值的 request-side
runtime 缺口：
把 `Expect: 100-continue` 已发出 interim `100` 之后，request body
只到达一部分然后 stall 的语义锁清楚。

- 先在 `test_http_security` 写 threaded / epoll 两条 focused live proof
- 先 RED，确认 threaded 与 epoll 是否存在差异
- 如果 threaded 真实会误补 synthetic `500`，做最小生产修复
- 只跑 `test_http_security` focused gate，不回去跑全量 HTTP

要求：

- 只动 HTTP 相关路径
- 不扩散到 benchmark / server 基类设计 / 大面积 malformed parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 在 `test_http_security` 新增 `Expect + interim 100 + partial body stall`
  threaded / epoll focused live proof
- [x] focused gate 先 RED，确认只有 threaded 路径会误补 synthetic `500`
- [x] 锁定根因：blocking `TTcpStream.Read` 超时在 live threaded 路径上会落成
  `ENetworkError('tcp read failed (...)')`，而 whole-run `Run` outer except
  把 request-side ingress 读失败误当成内部错误写出 `500`
- [x] 在 `src/nextpas.core.http.impl.h1.pas` 做最小生产修复：
  `TH1ServerConnectionState.Run` 对 request-side read failure 直接安全关闭，
  不再补写 final `500`
- [x] focused gate 转绿并确认 heaptrc 无泄漏
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.http.impl.h1.pas`
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / server 基类重构 / 架构重设计

## Intended outcome

- `Expect: 100-continue` 已发出 interim `100` 之后：
  - partial fixed-length body stall 会安全关闭
  - partial chunked body stall 会安全关闭
  - threaded / epoll 两条 live path 都不会追加 synthetic `500`
  - handler 不会进入
- 证据要求：
  - 四条 `Expect + body stall idle-timeout` tests GREEN
  - `make -C tests/nextpas.core.http/test_http_security clean test` 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
