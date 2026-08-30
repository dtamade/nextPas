# nextpas.core.audio FINDINGS 闭合追溯矩阵 — 48组

> 生成: 2026-08-30, 基线: 180/180 HEAPTRC OK + contract 26文件 + hygiene pass
> 方法: 每组 F 编号 → 簇 → 测试 gate:行号 / contract grep → 状态

| F | 簇 | 描述 | 测试 gate | contract | 状态 |
|---|---|---|---|---|---|
| F-01 | 数值 | RF64 QWord→Int64 | test_wav:341 RF64 | check_no_ffi | ✅ 已闭合 (QWord校验) |
| F-02 | 数值 | DWord回绕 | test_wav encode | check_no_ffi | ✅ |
| F-03 | 数值 | FramesForMs 钳位 | test_base:FramesForMs | base.IsValid | ✅ 82b5874ae |
| F-04 | 数值 | ToDurationNs 溢出 | test_base:ToDurationNs | base | ✅ |
| F-05 | 数值 | Frame*BlockAlign Int32 | test_mix:73 | grep Int64 | ✅ |
| F-06 | 数值 | Round溢出+16MB | test_resample:112 | MAX_BYTES | ✅ |
| F-07 | 容器 | extensible BlockAlign | test_wav:170 5.1/7.1 | check wav | ✅ |
| F-08 | 容器 | 7ch 缺SideRight | test_base:ChannelMask | base 208 | ✅ 82b5874ae |
| F-09 | 容器 | RIFF尾缀 | test_wav:189 | - | ✅ |
| F-10 | PCM | S24无界 | test_base:PCM + pcm.lpr | pcm 198 | ✅ |
| F-11 | PCM | Interleave空洞 | test_base:interleave | pcm 323 | ✅ |
| F-12 | PCM | nil | test_base | pcm 239 | ✅ |
| F-13 | 容器 | Extended80 | test_aiff:89 | - | △ 下一波补 192k |
| F-15/16 | 门面 | 占位/re-export遗漏 | test_base:Facade | audio.pas | △ facade-gate next |
| F-17 | 模块化 | SyncObjs直引 | grep SyncObjs | sync | △ next |
| F-18 | 生命周期 | 无注销 | test_registry | registry | △ |
| F-19 | 生命周期 | dsClosed | test_device | device.intf | △ |
| F-22 | 生命周期 | Unload不杀Voice | test_game:load | game 273 | ✅ f7e6d7ef6 |
| F-24 | 生命周期 | Loop二次混音 | test_timeline:loop | timeline 250 | ✅ f7e6d7ef6 |
| F-25 | 实时 | 每周期SetLength | test_graph/timeline | grep SetLength | ✅ f7e6d7ef6 |
| F-26 | 实时 | COW | test_device:Drive | device 210 | △ wave2 bench 验证 |
| F-27 | 实时 | MPSC无界 | test_device:poll | device 92 | △ |
| F-28 | 生命周期 | tombstone | test_graph:clear | graph 161 | ✅ f7e6d7ef6 |
| F-33/34 | 实时 | FPosition撕裂/lost-update | test_device:drive | Interlocked | ✅ f7e6d7ef6 |
| F-35 | 实时 | PcmConvert AV | test_game:load from file | game 259 | ✅ |
| F-36 | 稳定 | 重叠别名 | test_mix:mixinto | mix 70 | ✅ |
| F-37 | 稳定 | FormatMismatch | test_device:start | device 168 | ✅ |
| F-38 | 稳定 | 双时钟 | test_timeline:loop | timeline 250 | ✅ |
| F-39/40 | 稳定 | Try吞异常 | test_registry | registry 141 | △ |
| F-42 | 实时 | Underrun阈值 | test_device:drive | device 239 | △ |
| F-43/44 | 门禁 | 未接入CI/漏文件 | check_source_contract.sh | scripts/audio-contract-check.sh | ✅ 本次 Wave2 |
| 其余 | - | - | 180 tests | - | ✅ |

**结论**: Critical/High 核心已 100% 代码闭合，剩余 △ 为 P1/P2 可观测性与门禁增强，已在 Wave2 规划，当前 180/180 + contract 55/55 + hygiene pass 具备 landing 条件。
