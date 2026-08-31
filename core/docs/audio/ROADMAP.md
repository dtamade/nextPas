# nextpas.core.audio 路线图 — 子模块一个一个彻底完成

> 目标：按 `DESIGN.md` 与 `CONTRACT.md` 一个域一个域闭环，绿了才进下一域。当前 truth level `focused-runtime`，禁止冒充 `ci-matrix`。

## 执行纪律

- 一域一 lane 文件分组（按 `file` 去重，禁止跨域写）；`git diff --check 0` + `make hygiene` 绿。
- 每域门禁：`本域 focused gate + HEAPTRC OK + check_source_contract.sh + hygiene`；全量 `223 tests (16门，含 deprecated test_game 兼容门，当前 36 files，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收)` 在 Final 再跑。
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
| **S7 game** | `game.intf/game` | SFX 池（deprecated 薄转发，`test_game` 15 为 deprecated 兼容门，迁移至 `sfx` canonical 0050） | `Unload` 不杀 Voice；`PcmConvert AV` 防御；`MaxVoices` 窃取；`SyncObjs` 迁移 | F-22/35 |
| **S8 timeline** | `timeline.intf/timeline` | 排序混音 | `Loop` 二次混音；双时钟；`solo/mute`；声像 -3dB；`Device` 联动；深拷贝快照；`snapshot mixing - lock free` | F-24/38 |
| **S9 门面+bench+文档** | `audio.pas` + bench + docs | 聚合 | `type` 别名 + `inline` 全量；`bench_pcm_wav` 扩至 `Graph/Timeline/Device/Bank/Resource` `ns/op+MB/s -O2` 10 项；`README` 8 示例对齐；`contract 36文件 16门 223 tests（理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收）` 接入 CI | F-15/16/43/44 |
| **S10 spatial/event/bank/resource** | `spatial/event/bank/resource` | P5 扩展 | `two-phase snapshot + EnsureScratch/EnsureCapacity + snapshot mixing - lock free`；`PanLawGains0dB` 复用；`Bank协同` | F-40/41 |

## 依赖

`S0→S1→S2→S3→S4→S5→S6→S7→S8→S9` 串行；`S5` 为最痛域（4 △ 聚集），允许与 `S4` 并行审计但修复串行。

## 里程碑

- **M1 S0–S4**：容器与数值闭环（`contract` 数值不变量绿）
- **M2 S5–S8**：实时与生命周期闭环（零分配 + 原子 `FPosition` + MPSC 有界）
- **M3 S9**：门面与基准闭环（可 `Landed`）

## 门禁清单（每域打勾）

- [ ] `make -C core/tests/nextpas.core.audio/test_<domain> clean test` 绿 + `HEAPTRC OK`
- [ ] `bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh` 绿（36 文件无 ffi/vendor（当前 36，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收） + 17 GUID (unique; 15 realtime domain) + 实时纪律 + two-phase/EnsureScratch/snapshot mixing - lock free/PanLawGains）
- [ ] `make hygiene && git diff --check` 绿
- [ ] `FINDINGS` 对应行号回归用例绿

## 当前基线

`223 tests (16门，含 deprecated test_game 兼容门)` 全量绿（`HEAPTRC OK`，36 files + 17 GUID + 实时纪律 + two-phase/snapshot mixing - lock free）已具备 `S0` 起点条件；`bench 10项 -O2` 完整；理想态 45 — 9 files 预留 `flac/mp3/vorbis/studio/playlist` 等由 `music888` 以 `Probe≤4KB` 可插拔吸收（与 DESIGN §9 同词）。

