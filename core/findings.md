# Findings: http malformed transfer-coding focused expansion

## Scope

- 这轮继续留在 malformed chunked request correctness / security 主线。
- 不做生产修复预设，先用 focused tests 看 `chunked, gzip` 是否真有契约缺口。

## Confirmed truths

### 1. `chunked, gzip` 的 raw-wire security proof 早已有了，但 focused parser/server 证明不完整

- `test_http_security` 已经锁定：
  - `Transfer-Encoding: chunked, gzip` -> explicit `400`
- 但在这轮之前：
  - `test_http_h1parser` 没有直接锁这条 parser 语义
  - `test_http_server` 也没有直接锁 handler-not-called 语义

### 2. 当前实现已经满足契约，这轮不需要生产修复

- 新增 parser focused proof 后，`test_http_h1parser` 直接通过：
  - `Transfer-Encoding: chunked, gzip`
  - `HasError = true`
  - `IsComplete = false`
  - `ErrorKind = pekMalformed`
- 新增 server focused proof 后，`test_http_server` 直接通过：
  - raw-wire 返回 explicit `400`
  - handler 不会被调用

### 3. 这轮新增的是“契约可见性”，不是行为变更

- `gzip, chunked` 与 `chunked, gzip` 现在在测试矩阵里的语义边界更清楚：
  - 前者是 unsupported transfer-coding
  - 后者是 malformed transfer-coding，因为 `chunked` 不是 final coding
- 生产代码未改，当前 truth 只是被补成更窄的 focused proof。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `83/83 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `113/113 passed`
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- malformed chunk/trailer EOF 子类的 correctness 主线已经很密，后续再扩时要继续防止“重复加已存在证明”的低效动作。
- 下一批更值得做的是：
  - 再找 parser/server/security 三层之间真正不对称的边角 case
  - 或者回到 keep-alive request-tail 契约决策
  - 而不是继续机械复制相邻 EOF 用例
