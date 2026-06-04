# Findings: http server repeated expect header aggregation

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只收一个真实生产缺口：
  repeated `Expect` header-line 的判定不能只看第一条 header value。

## Confirmed truths

### 1. 当前实现确实只看了第一条 `Expect` header value

- parser 在 [src/nextpas.core.http.impl.h1.parser.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.parser.pas)
  里会对重复 header-line 调 `FHeaders.Add(...)`。
- 但旧实现的 [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里，`RequestExpectsContinue` 和 `RequestHasUnsupportedExpectations`
  都是基于：
  - `AParser.GetHeaders.Get('expect')`
- 而 [src/nextpas.core.http.headers.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.headers.pas)
  的 `Get()` 只返回第一条 matching value。
- 这意味着后续 `Expect:` 行会被完全忽略。

### 2. TDD 已证明这不是文档问题，而是真生产缺口

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 repeated header focused tests：
  - 第一条 `Expect: 100-continue`
  - 第二条 `Expect: fancy`
- 首轮 RED 明确落在新 case：
  - `repeated expect headers with unsupported member reject with final 417`
- 这直接证明 server 因为只看第一条 `Expect`，没有把后续 unsupported member
  正确提升成 final `417`。

### 3. 最小修复只需要把 `Expect` 扫描切到 `GetAll('expect')`

- 本轮没有动 parser error / body / write-timeout 等其他路径。
- 只把 `RequestExpectsContinue` / `RequestHasUnsupportedExpectations`
  从单值 `Get('expect')` 改为多值 `GetAll('expect')` 后逐条 token 扫描。
- 这样：
  - 任一 header-line / 任一 comma-separated member 里的 `100-continue`
    都能被看到
  - 任一后续 header-line / member 里的 unsupported expectation 也能被看到

### 4. 修复后 repeated `Expect` 聚合语义更完整

- 当第一条 `Expect` 是 `100-continue`、后续再出现 unsupported member 时，
  threaded / epoll 两条 live 路径现在都直接锁住：
  - 返回 final `417 Expectation Failed`
  - 不误发 interim `100 Continue`
  - 不进入 handler
- 这轮因此也是小而真实的生产修复。

## Verification evidence

- focused:
  - RED:
    - `make -C tests/nextpas.core.http/test_http_server test`
    - 新增 epoll repeated-header case 首轮失败，报错
      `repeated expect headers with unsupported member reject with final 417`
  - GREEN:
    - `make -C tests/nextpas.core.http/test_http_server test`
    - `196/196 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮只锁了 repeated-header + unsupported-member 这一种重复 header 组合，
  还没系统铺开：
  - bodyless `Expect: 100-continue`
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
