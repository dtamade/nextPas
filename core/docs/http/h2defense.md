# nextpas.core.http.impl.h2.defense — H2 DoS 防御域契约

**模块**：`nextpas.core.http.impl.h2.defense.{base,intf,pas}`  
**层级**：L3 http.impl.h2  
**四件套**：`defense.base` ← `defense.intf` ← `defense` 门面  
**对应主契约**：`CONTRACT.md` §1.1 DoS 行 + §6 h2 DoS 防御 stance 表

## 职责

- CVE-2023-44487 rapid-reset: FRapidResetCount → GOAWAY ENHANCE_YOUR_CALM（100，请求完成清零）
- CVE-2019-9512/9515 PING/SETTINGS flood: FControlFrameFloodCount → GOAWAY（100/batch，完成清零）
- CVE-2024-27316 CONTINUATION flood: 压缩 64KB / 512 片 / 64 空 阈值 → RST + EscalateHeaderBlockFlood → GOAWAY+关闭+清待续
- HPACK 放大（RFC 7541 §10.5）硬 backstop 1MB + 软 limit min；Wire 16MB 硬上限

## 性能

- 计数器热点 inline（`ResetOnRequestComplete` / `H2DefenseShouldGoAway`），无锁快路径
- 零拷贝：header-list size 累计走 TByteSpan 视图，不物化多余缓冲；bytes.ops 单源

## 稳定性

- 完成-清零不变式；致命 GOAWAY 后关连接并清 FPendingContinuationStreamID，不悬垂
- heaptrc 0 unfreed；攻击/不误伤双测（198 穿插 1 完成等）

## Owner 边界

- 阈值跨 session/client 共享需求出现时评估提升为共享 defense 服务，当前 L3 内聚
