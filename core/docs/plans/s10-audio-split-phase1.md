# S10 Phase1 — audio 56扩展抽独立L2（首抽 simd + bus）

## Goal
87=31+56 (pcm_wav四件套已闭环) → 抽独立L2使 audio 回归 26 冻结，高级感与 Owner 边界收敛。首批抽 `nextpas.core.simd` 与 `nextpas.core.audio.bus`（含 bus.impl 的 Simd 复用），验证四件套与 L0-L3 后再滚 codec 族。

## DAG
- s10-1: `nextpas.core.simd` 独立族雏形 — 薄封装 `audio.simd/pcm.simd` → Owner `nextpas.core.simd`（cpuinfo 单源），`audio` 侧仅 inline 转发
- s10-2: `nextpas.core.audio.bus` 独立化 — bus.base/intf/impl/pas 已四件套，补 module-registry 登记 + gate，audio 侧去 L2→L2 直引
- s10-3: 门禁 — hygiene + source-contract 85→87→独立族计数 + focused 23门 + bench

依赖：s10-1 → s10-2 → s10-3

## DoD
- `core/src/nextpas.core.simd.*` 四件套存在，`audio.simd` 仅薄转发，`pcm.simd` 走 Owner
- `core/src/nextpas.core.audio.bus.*` 通过独立 gate，module-registry 登记 L2 seam
- `make hygiene && bash check_source_contract.sh` 绿，`test_bus` 8/8, `test_base` 21/21
- docs CONTRACT 1.5.8→1.6.0 反映 87=31+56 已抽 2 族
