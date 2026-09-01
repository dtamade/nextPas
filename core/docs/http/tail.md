# nextpas.core.http.impl.h1.framing.tail — Keep-Alive Request-Tail 域契约

**模块**：`nextpas.core.http.impl.h1.framing.tail.{base,intf,pas}` 薄门面（`impl.h1.conn.FPending` 尾巴语义独立化，不经 umbrella）
**层级**：L3 http.impl.h1（依赖 bytes.ops 单源 + impl.h1.parser）
**四件套**：`tail.base` ← `tail.intf` ← `tail` 薄门面；实现侧 `impl.h1.conn` 直连 `tail.base/intf` 不经 umbrella 转口
**门禁**：本域独立 `heaptrc 0 unfreed`（`TailClearPending`/`TH1TailBuffer.Clear` 释放不丢），不依赖 umbrella 聚合门禁
**对应主契约**：`CONTRACT.md` §3.1 INV-12 + §1.1 Tail 行

## 职责

- request isolation + deferred follow-up parse：framing 完成即交付，extra bytes 入 FPending pending buffer，不污染当前 method/url/headers/body
- Connection: close 尾巴同请求 400；keep-alive 尾巴隔离，合法 pipeline 按序 200→200，partial 不早拒，结论性 malformed / peer half-close 才对 follow-up 400
- Garbage tail：首 200 保序 follow-up 400

## 性能

- 零拷贝：FPending 以 TByteSpan 视图隔离尾巴，不复制；inline helpers（AsSpan/IsEmpty/Clear via bytes.ops）
- deferred parse 有序 200→400，不额外分配

## 稳定性

- 连接 Close 时 `Clear` 释放 pending，无 leak；fail-fast 413/431 在 handle 前；本域独立 `heaptrc 0 unfreed`（不经 umbrella 聚合）
- parser/server/security 三层证据锁行为

## Owner 边界

- framing 再扩 trailer/Expect 时在 tail 域内演进，不泄漏为 public async API
