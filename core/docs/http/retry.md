# nextpas.core.http.retry — 重试/退避/幂等域契约

**模块**：`nextpas.core.http.retry.{base,intf,pas}` 薄门面（不经 umbrella；`client.decorator:TRetryClient` + `client.redirect` 各自 owner-local，直连 `retry.base/intf`）
**层级**：L3 http（依赖 L0–L2）
**四件套**：`retry.base` ← `retry.intf` ← `retry` 薄门面；实现侧 `client.decorator`/`client.redirect` 直连 `retry.base/intf` 不经 umbrella 转口
**门禁**：本域独立 `heaptrc 0 unfreed`（response 释放不丢），不依赖 umbrella 聚合门禁
**对应主契约**：`CONTRACT.md` §1.1 重试行 + §2.1 WithRetry/Retry-After/幂等门闩

## 职责

- 仅对 429 / 5xx / `HttpErrorIsRetryable`（hekTimeout/hekConnect/裸 Timeout/Network）重试，最多 N 次
- 非 4xx 其他不重试；指数退避 100ms base cap 5s；Retry-After 优先（delta-seconds / HTTP-date，cap 60s，过去→0）
- 切片 ~100ms 可取消（cancel token）；幂等门闩 `HttpIsRetrySafeRequest`（GET/HEAD/OPTIONS/TRACE 或 Idempotency-Key）

## 性能

- 退避计算 inline（`HttpRetryBackoffMs`），无分配
- 幂等判断 inline 薄转发单源 `http.message.HttpIsRetrySafeRequest`，header 查找 `bytes.ops` 零拷贝视图

## 稳定性

- body 可回放时 rewind（IStream），不可回放非空 body 不重试
- 资源：每次尝试后 response 释放，不泄漏；本域独立 `heaptrc 0 unfreed` 门禁（不再经 umbrella 聚合）

## Owner 边界

- 与 `async.retry` 语义收敛时先反哺 owner，不在 http 复制退避算法
