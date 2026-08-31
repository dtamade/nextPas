# nextpas.core.audio 设计文档（Draft v3.2 — SFX canonical + spatial/event/bank/resource 七域+扩展）

> 权威来源：本文档为 `nextpas.core.audio` 设计真值源；`check_source_contract.sh` 为 gate 真值源（当前 36 files，理想态 45）。`README.md` 为入口概览。

## 1. 目标与非目标

- **目标**：以纯 Pascal 提供可替换的音频管线，覆盖容器编解码 / PCM / DSP / 设备 / 图 / SFX / 时间线七域（`SFX` 为 canonical，`game` 仅作 deprecated 薄转发）；以 `TAudioBuffer` 为统一货币，实时路径零分配零锁。
- **非目标**：硬件后端（ALSA/CoreAudio/WASAPI）、FLAC/MP3/Opus 有损编解码、自动设备热迁移（`music888` 与后续 slice 接管）。

## 2. 分层与依赖

```
L2 nextpas.core.audio (仅依赖 L0-L1；io/fs 为显式允许 — 同层豁免)
  base (L0 only) → intf → impl → facade
```

- `base` 不依赖同模块任何文件；`intf` 依赖 `base`；`impl` 依赖 `intf+base`；`facade` 聚合 re-export。
- L2 理论仅依赖 L0-L1；`io` 为 L1 流抽象（IStream 缝），`fs` 为 L2 文件系统。`codec.registry`/`resource` 直引 `nextpas.core.fs` 属同层 `L2→L2` 豁免债务，已在 `core/docs/core-module-registry.md` 显式登记为 `L0-L1 plus io/fs (container I/O seam via IStream, registry+resource, wav file helper)`，gate 允许通过。替代方案（interface 注入文件打开）已评估，当前选择直引以保持 API 极简，后续可迁至 `IFileSystem` 注入而不改契约。
- L2 禁止 `*.ffi/vendor/miniaudio/mpg123/opusfile`（gate `grep -qi "\.ffi|vendor"`）。
- 债务：`SyncObjs/Classes/SysUtils` 直引 8 文件（`device.null/graph/sfx/timeline/spatial/event/bank/resource`，`game` 为薄转发）→ 目标 `nextpas.core.sync`。

## 3. 统一货币

- `TAudioFormat.IsValid` ⇔ `8000..192000Hz × 1..8ch × sfU8..sfF32`；`BlockAlign=Ch*BPS`，`sfS24=3`；`ByteRate=Int64(SR*BlockAlign)`；`FramesForMs(≤0)=0`。
- `TAudioBuffer.Data:TBytes` 长度 `FrameCount*BlockAlign`，交织 PCM，混音 canonical `sfF32`。
- `ChannelMask`（`WAVEFORMATEXTENSIBLE` 位）为真值源；`ChannelLayout` 仅提示，互转经 `AudioChannelMaskForLayout/AudioChannelLayoutForMask`。
- `TAudioClock.ToDurationNs` 仅调度面使用（`Frame*1e9/SR`）。

## 4. 双平面线程模型与实时纪律

```
控制面（UI/逻辑）：AddTrack/AddClip/SetGain/MasterGain/Load — 可分配可锁
实时面（Audio Thread）：FillRealtime — 禁 GetMem/锁/IO/异常
```

- `IAudioSource.Fill` 为离线便利转发（允许分配/锁/IO，违例抛异常）。
- `IRealtimeAudioSource.FillRealtime` 追加实时承诺；设备/图/时间线/SFX Graph 仅调此面。
- 契约注释「实时路径仅调 FillRealtime」在 `audio.intf` 冻结；gate 全量校验 `device.null/graph/timeline` 含 `FillRealtime`。
- 预分配不变量：调用方保证容量；实时违例 `clamp + InterlockedExchangeAdd64(FViolations)`，成功路径不分配。
- 返回值：`≥0` 填充帧，`0` 仅 EOF，失败以异常（离线）或静音+计数（实时）表达。
- 欠料：实时补静音返回 `AFrames`，`UnderrunCount` 原子上报，连续 `≥5` 发 `devUnderrun`。

### 4.1 快照化混音（无锁）

- **Timeline**：两阶段快照（锁内拷 `Position/Loop/Duration` + 存活轨计数 → 锁外分配 → 锁内深拷贝 `Clips`），`solo` 覆盖 `mute`，`Pan=(TrackPan+ClipPan)/2 → L/R=cos/sin*1.414`，`clamp`，`Loop` 跨 `SnapDur` 分段 `MixSegment`，`FPosition` 以快照基点确定性推进（`mod Dur`）。注释 `two-phase snapshot` / `deep copy clip array` / `snapshot mixing - lock free` 为门禁真值。
- **Graph**：锁内拷存活节点/处理器快照，单 `scratch` 复用每节点零分配，处理器链双缓冲 `SwapBuf` 交换，`gain*volume+clamp`。`EnsureScratch` 零分配，禁锁内 `SetLength(NodesSnap)`。
- **Device.Null**：`FScratch` 复用，`Drive→FillRealtime`，异常 `devDeviceError` 并零填，`FPosition:UInt64` 贯穿。
- **SFX**：复用 `Graph` 快照路径，`EnsureSfxCapacity/EnsureVoiceCapacity` 2×倍增 + 死槽复用，`SFX lock -> Graph lock` 锁序，`PanLawGains0dB`/`CAudioSqrt2` 共用。

## 5. 域级 intf 冻结（GUID 真值源）

| 面 | 接口 | GUID |
|----|------|------|
| 流式 | `IAudioSource` | `…00000010` |
| 实时 | `IRealtimeAudioSource:IAudioSource` | `…00000011` |
| 转换 | `IAudioResampler` | `…00000020` |
| 转换 | `IAudioConverter` | `…00000021` |
| DSP | `IAudioProcessor` | `…00000030` |
| 容器 | `IAudioDecoder` | `…00000001` |
| 容器 | `IAudioEncoder` | `…00000002` |
| 设备 | `IAudioDevice` | `…00000040` |
| 设备 | `IAudioDeviceProvider` | `…00000041` |
| 图 | `IAudioGraph:IRealtimeAudioSource` | `…00000042` |
| 播放 | `IAudioPlayer` | `…00000043` |
| SFX | `ISfxAudio` | `…00000050` canonical |
| 游戏 | `IGameAudio` | `…00000050` deprecated 薄转发（`TGame* = TSfx*`） |
| 时间线 | `IAudioTimeline:IRealtimeAudioSource` | `…00000060` |
| 空间 | `IAudioSpatialSource` | `…00000051` |
| 事件 | `IAudioEventSystem` | `…00000052` |
| Bank | `IAudioBank` | `…00000053` |
| 资源 | `IAudioResourceManager` | `…00000054` |

- `TAudioEncodeOptions` 必须声明早于 `IAudioDecoder`（gate 顺序校验）。
- `IAudioGraph/IAudioTimeline` 继承 `IRealtimeAudioSource` 以直连 `Device`。
- `ISfxAudio` 为 0050 canonical，`IGameAudio` 保留同 GUID 薄转发，门禁同时校验 `sfx.intf` 含 `ISfxAudio 0050` 与 `game.intf` 含 `IGameAudio`；`spatial 0051 / event 0052 / bank 0053 / resource 0054` 为 P5 扩展，15 GUID 冻结。

## 6. 容器与注册

- `Probe ≤4KB`：registry 一级容器嗅探 + 二级 codec 识别共用 `IAudioDecoder.Probe`；`AudioDetectProbeFromStream` 保持 `Position` 不变。
- `registry` 工厂前插，`AudioRegisterDecoder(nil)` 抛 `EInvalidArgument`，快照 `Copy(GFactories)` 无锁读。
- `TryDecodeWhole/File` 仅吞 `EAudioDecodeError`；`AudioOpenFileStreaming` 失败抛 `EAudioDecodeError`。
- 编码 `TAudioEncodeOptions.SampleFormat∈[sfS16,sfS24,sfF32] + ApplyDither`，v1 仅 WAV 实现。
- FLAC/MP3 后续以 `Probe≤4KB` 可插拔吸收（`music888` 已有实现，保持 `AudioRegisterDecoder` 扩展点）。

## 7. 错误模型

`EAudioError(EIOError)` → `Decode/Encode/Device/Graph/Timeline` 五分支（`audio.errors` 唯一真值源），直线代码抛异常，边界统一捕获，`Try*` 仅分支时提供。

## 8. 数值与容器不变量

- `Frame*BlockAlign` / `Frame*Channels` / `Offset*Channels` 均 `Int64` 中间防 `Int32` 窄化与 `Round` 溢出；`16MB` 为 `Sinc` 输入上限。
- WAV：`8..32位 + float + WAVEFORMATEXTENSIBLE 5.1/7.1 + fact/bext/rf64`；AIFF：`Extended80`；PCM：`S24` 紧排 3 字节 LE；`MixInto` 处理重叠别名与 `Int64` 校验；`PanLawGains0dB` 等功率 `-3dB`。

## 9. PR 切分（历史）与演进

`PR1 base → PR2 wav → PR3 aiff/meta/registry → PR5 resample/mix/dsp → PR6 device → PR7 graph/player → PR8 sfx（game 薄转发 deprecated 兼容）→ PR9 timeline`；`PR4 flac/mp3` 推迟由 `music888` 以 `Probe≤4KB` 可插拔吸收。`Graph` 复用快照路径，`SFX`/`Timeline` 复用 `IAudioBuffer` 货币与 `PanLawGains`。

## 10. 验证

`223 tests HEAPTRC OK (16门，sfx canonical + bank/resource)` + `36文件无ffi/vendor（当前 36，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收）` + `17 GUID frozen (unique; 15 realtime domain + sfx 0050 canonical + spatial 0051 + event 0052 + bank 0053 + resource 0054)` + `实时纪律 + two-phase/EnsureScratch/PanLawGains` + `bench 8项` + `hygiene` 为 `focused-runtime` 必要条件（见 `README.md` 测试矩阵与 `check_source_contract.sh`）。

```
bench_pcm_wav 8 项：Parse/64KB, Parse/1MB, Write/1MB, Graph/1K, Graph/4K, Timeline/1K, TimelineLoop/1K, Device.Drive/1K
Graph/Timeline/Device 零分配快照，GWrite 预分配，输出 ns/op + MB/s -O2
```
