# S10 Phase2 — codec 族四件套独立化 + 剩余扩展收敛

## Goal
87=31+56 → 将 56 扩展剩余 7 族抽独立 L2，使 audio 真回 26 冻结。Phase2 聚焦 `codec.flac/mp3/vorbis/opus` 四族（各 base←intf←impl←pas，Probe≤4KB 单源，STUB 白名单）+ `spatial` + `simd` Owner 纯化。

## DAG
- s10-4: `codec.flac/mp3/vorbis/opus` 四件套硬化 — base L0 only, intf 仅别名 GUID 0001复用, impl bytes.ops单源+Probe≤4KB, facade inline+自注册，补 12 文件枚举与 STUB gate
- s10-5: `audio.spatial` + `audio.simd` Owner 纯化 — spatial 四件套 + simd thin Owner 去 audio 寄生分派，复用 nextpas.core.simd cpuinfo
- s10-6: 门禁 — hygiene + source-contract 87→87独立族计数 + focused 23门 + bench 基线补齐

依赖：s10-4 → s10-5 → s10-6
