# nextpas.core.http gating — 47 套件门禁域契约

**门禁**：`core/tests/nextpas.core.http/Makefile` PROJECTS=47  
**层级**：测试域（主题分组）  
**对应主契约**：`CONTRACT.md` §6

## 现状

- 主门禁 47 suites 已从单体 client/server 拆出 Era3 主题：client_redirect / body_helpers / server_expect / server_chunk 等
- 余下按 `h1/*` `h2/*` `client/*` `middleware/*` `security/*` 机械分组候选已落地文档

## 阈值

- 单 lpr >10k 或单 suite 调试周期显著上升即评估再分组
- 全丝 D: `make focused FOCUS=...` 保持；敏感套件每域独立 `heaptrc 0 unfreed`（pool/retry/defense/tail/timeout 各自 `PoolClear`/`Close`/`GOAWAY`/`ClearPending` 释放不丢，不经 umbrella 聚合门禁）；`git diff --check` + `make hygiene`

## 稳定性

- 分组时保持 focused 双绿、资源释放语义；不为分组删用例
- 每域独立门禁：`pool`（`impl.h1.pool.Clear`/`impl.h2.client.pool.Clear`）、`retry`（response 释放）、`defense`（GOAWAY+清待续）、`tail`（`TailClearPending`/`TH1TailBuffer.Clear`）、`timeout`（策略无资源，`PoolClear`/`Close` 不丢）各自 `heaptrc 0 unfreed`
