# Findings: http server expect list-membership semantics

## Scope

- 本轮转回 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只收一个真实生产缺口：
  `Expect` 的 `100-continue` 判定不该是 exact-equals，而应是 list-membership。

## Confirmed truths

### 1. 当前实现确实把合法的 `Expect` list value 漏判了

- 旧实现的 [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里，`RequestExpectsContinue` 用的是：
  - `LowerCase(Trim(...)) = '100-continue'`
- 这只接受 header value 精确等于 `100-continue`。
- 但 `RequestHasUnsupportedExpectations` 已经按 comma-separated list token 化了，
  说明 `Expect` 本身就被当作 list 处理；continue 判定继续用 exact-equals 不一致。

### 2. TDD 已证明这不是文档问题，而是真生产缺口

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  先加了 duplicate member focused tests：
  - threaded `Expect: 100-continue, 100-continue`
  - epoll `Expect: 100-continue, 100-continue`
- 首轮 RED 明确落在新 case：
  - `interim 100 continue returned`
- 这证明 server 确实没有把合法 list value 识别成 `100-continue` expectation。

### 3. 最小修复只需要收紧 `RequestExpectsContinue`

- 本轮没有动 parser error / body / write-timeout 等其他路径。
- 只把 `RequestExpectsContinue` 改为和 unsupported-member 判定一致的
  comma-separated token 扫描：
  - 只要任一 token 等于 `100-continue`，就返回 `True`
- 现有 `RequestHasUnsupportedExpectations` 继续负责：
  - 一旦同时出现 unsupported member，仍然直接走 `417`

### 4. 修复后 `Expect` request-side live contract 更完整

- duplicate `100-continue` 现在在 threaded / epoll 两条路径上都直接锁住：
  - 先返回单条 interim `100 Continue`
  - handler 仍只在 body 送达后才被调用
  - 最终 `200` 和 body echo 契约不变
- 这轮因此是小而真实的生产修复，不只是覆盖扩充。

## Verification evidence

- focused:
  - RED:
    - `make -C tests/nextpas.core.http/test_http_server test`
    - 新增 epoll duplicate-member case 首轮失败，报错
      `interim 100 continue returned`
  - GREEN:
    - `make -C tests/nextpas.core.http/test_http_server test`
    - `194/194 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮只锁了 duplicate `100-continue`，还没系统铺开：
  - bodyless `Expect: 100-continue`
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
