# nextpas.core.audio 路线图 — 子模块一个一个彻底完成

> 目标：按 `DESIGN.md` 与 `CONTRACT.md` 一个域一个域闭环，绿了才进下一域。当前 truth level `focused-runtime`，禁止冒充 `ci-matrix`。

## 执行纪律

- 一域一 lane 文件分组（按 `file` 去重，禁止跨域写）；`git diff --check 0` + `make hygiene` 绿。
- 每域门禁：`本域 focused gate + HEAPTRC OK + check_source_contract.sh + hygiene`；全量 `180/180` 在 Final 再跑。
- 四步：`只读审计 → 对抗验证（去伪） → 分组修复 → 门禁收敛`。

## 阶段

| 阶段 | 域 | 输入 | 输出/验收 | FINDINGS |
|------|----|------|-----------|----------|
| **S0 base** | `audio.base` | `IsValid/BlockAlign/ByteRate/FramesForMs/ToDurationNs` | 格式边界用例固化；7ch `SideRight` 回归；`Int64` 单源复核 | F-03/04/05/08 |
| **S1 pcm** | `audio.pcm(+pcm_wav)` | 纯函数 | `S24` 有界 + `Interleave` 空洞/nil + `PcmConvert` 越界抛；兼容壳八拒四正 | F-10/11/12 |
| **S2 codec.wav** | `codec.wav+intf` | decode-first | extensible 5.1/7.1 + RF64 QWord + 尾缀回归；`ByteRate Int64` | F-01/02/07/09 |
| **S3 codec.aiff/meta/registry** | `codec.aiff/meta/registry` | Probe≤4KB | `Extended80 192k` 补齐；`Try*` 仅吞 `EAudioDecodeError`；可插拔注销可观测性 | F-13/18/39/40 |
| **S4 resample/mix/dsp** | `resample/sinc/mix/filters/dynamics/fft` | `16MB` 上限 | `Frame*BlockAlign Int64` + `Round` 溢出守卫；`MixInto` 重叠别名；`Biquad TDF-II/FFT` 精度 | F-05/06/36 |
| **S5 device** | `device.intf/null` | Null 后端 | `SyncObjs→sync` 迁移；MPSC `64` 有界环形；`FScratch` 零增长；`dsClosed`；`FormatMismatch` | F-17/26/27/33/34/37/42 |
| **S6 graph/player** | `graph.intf/graph/player` | 快照混音 | 固定容量快照；单 scratch 双缓冲；`tombstone compact`；`Clear` 真删除 | F-25/28 |
| **S7 game** | `game`（无独立 intf，按需存在；deprecated 别名在 `sfx.intf`） | SFX 池 | `Unload` 不杀 Voice；`PcmConvert AV` 防御；`MaxVoices` 窃取；`SyncObjs` 迁移 | F-22/35 |
| **S8 timeline** | `timeline.intf/timeline` | 排序混音 | `Loop` 二次混音；双时钟；`solo/mute`；声像 -3dB；`Device` 联动；深拷贝快照 | F-24/38 |
| **S9 门面+bench+文档** | `audio.pas` + bench + docs | 聚合 | `type` 别名 + `inline` 全量；`bench_pcm_wav` 扩至 `Graph/Timeline/Device Drive` `ns/op+MB/s -O2`；`README` 8 示例对齐；`contract 78文件(26+52)→84(29+55) +23GUID` 接入 CI（codec.flac/mp3/vorbis/opus 四件套 1.5.2，wav四件套L2化） | F-15/16/43/44 |
| **S10 独立族拆分** | `audio 84→26+58`  provisional→独立 L2 | 模块化 | `codec.flac/mp3/vorbis/opus` 各独立 `nextpas.core.audio.codec.*`（四件套）+ `spatial/bus/simd/bank/resource/playlist/event/studio` 各独立 `nextpas.core.audio.*`/`nextpas.core.simd`，`L2→L2` 禁依赖，受控 seam 经 `module-registry` 登记；audio 仅留 26 core 冻结 | F-45 |

## 依赖

`S0→S1→S2→S3→S4→S5→S6→S7→S8→S9` 串行；`S5` 为最痛域（4 △ 聚集），允许与 `S4` 并行审计但修复串行。

## 里程碑

- **M1 S0–S4**：容器与数值闭环（`contract` 数值不变量绿）
- **M2 S5–S8**：实时与生命周期闭环（零分配 + 原子 `FPosition` + MPSC 有界）
- **M3 S9**：门面与基准闭环（可 `Landed`）

## 门禁清单（每域打勾）

- [ ] `make -C core/tests/nextpas.core.audio/test_<domain> clean test` 绿 + `HEAPTRC OK`
- [ ] `bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh` 绿（84 文件无 ffi/vendor + 23 GUID(11+12 B前缀bus异形) + 实时纪律 + test_automation）
- [ ] `make hygiene && git diff --check` 绿
- [ ] `FINDINGS` 对应行号回归用例绿

## 当前基线

`268/268 绿`（24 门：核心 13 + 扩展 11 含 bus+automation+opus）已具备 `S0` 起点条件；`bench` 已含 `Graph/Timeline/Device`（`bench_pcm_wav` S9 已扩），`S10` 独立族拆分待抽。

## 里程碑 S9 验收（1.5.2 实盘对齐）

- **文件**：85 文件 = 核心 29（+wav四件套 3）+ 扩展 56（含 `audio.bank/resource/event/spatial/playlist/bus` 各四件套 + `codec.flac/mp3/vorbis/opus` 各 `base/intf/impl/pas` 四件套 12 文件 + `codec.*.decoder/.sse` 6 + `studio.*(4)/simd/pcm.simd` + `studio.base/studio.pas`，unique 83+2 bus facade），`26+59` 独立族待抽后 audio 仅留 26 core 冻结
- **GUID**：23 枚 = 11 核心 + 12 扩展（B 前缀 bus 异形 C00001/02），opus 复用 0001/02 无新增 GUID，gate 单独校验
- **测试**：268 tests / 24 门，含 `test_automation`（8）+ `test_bus`（8）+ `opus` 占位，全量 `HEAPTRC OK` + `hygiene` 绿为晋升 `focused-runtime` 必要条件
- **Bench**：`bench_pcm_wav` 已扩 `Graph/1K/4K Timeline/1K Loop Device.Drive/1K` 五项 `ns/op+MB/s -O2`

## 里程碑 S10 预研（独立族拆分）

- **目标**：`nextpas.core.audio 85 provisional` → `26 core 冻结` + `59 ext` 抽独立 L2：`nextpas.core.audio.codec.flac/mp3/vorbis/opus`（各四件套，L0 only base + Probe≤4KB + bytes.ops 单源）、`nextpas.core.audio.spatial`/`bus`/`bank`/`resource`/`playlist`/`event`/`studio`、`nextpas.core.simd`（audio.simd/pcm.simd 薄封装复用）
- **约束**：`L2→L2` 禁依赖，受控 seam 需 `module-registry` 登记 + gate，白名单后 `audio` 内禁止继续堆叠新域

