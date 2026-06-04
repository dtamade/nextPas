# Findings: http multiple trailer declaration contract

## Scope

- 本轮不碰生产逻辑，只继续收口 `nextpas.core.http` 公共契约。
- 目标是确认 chunked request trailer contract 不只对单个 trailer 声明成立，
  对多个声明名同样保持“不泄漏真实 trailer fields”的接口语义。

## Confirmed truths

### 1. 之前的 trailer 公共契约 proof 还只锁到了单个声明形态

- 现有 focused proof 已经说明：
  - handler 可读到解码后的 chunked body
  - `Trailer` 声明头会保留
  - 实际 trailer field 不会污染普通 header 查询
- 但之前只直接覆盖了单个声明名的输入形态。

如果不补 multiple declaration case，就还不能说这一公共契约对常见声明组合形式已经锁稳。

### 2. 当前实现对 multiple declaration 形态也满足同一条公共契约

- `test_http_contract` 新增 focused proof：
  - `Chunked request multiple trailer declaration contract`
- 新 case 直接锁定：
  - `Body = 'hello'`
  - `Headers.Get('Trailer') = 'X-Trace, X-Auth-Context'`
  - `Headers.GetAll('Trailer')` 只保留一条原始声明文本
  - `X-Trace` / `X-Auth-Context` 不会通过 `Get`、`GetAll`、`Has` 泄漏出来

新测试直接通过，说明 runtime 当前已把 single / multiple declaration 都收敛到同一公共契约。

### 3. 本轮仍是 coverage-expansion，不需要生产修复

- 没有新增实现改动。
- 新测试直接通过，说明已有运行时行为已经满足我们要冻结的公开接口语义。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_contract test`
    - `29/29 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- trailer 这一条公开契约现在已经从单声明扩到多声明，但它不应该再无限横向复制同型 case。
- 下一步更值的方向仍应二选一：
  - 回到真正还没分类完的 malformed/runtime/security 边角
  - 或开始审视 `3/6 H1 正确性加固` 的阶段收口条件，避免继续低价值补洞
