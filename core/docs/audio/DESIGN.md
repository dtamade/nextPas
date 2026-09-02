# nextpas.core.audio 设计文档（Draft v3）

> 权威来源：本文档为 `nextpas.core.audio` 设计真值源；`CONTRACT.md` 为验收真值源，`check_source_contract.sh` 为 gate 真值源。`README.md` 为入口概览。

## 1. 目标与非目标

- **目标**：以纯 Pascal 提供可替换的音频管线，覆盖容器编解码 / PCM / DSP / 设备 / 图 / 游戏 / 时间线七域；以 `TAudioBuffer` 为统一货币，实时路径零分配零锁。
- **非目标**：硬件后端（ALSA/CoreAudio/WASAPI）、FLAC/MP3/Opus 有损编解码、自动设备热迁移（`music888` 与后续 slice 接管）。

## 2. 分层与依赖

```
L2 nextpas.core.audio (仅依赖 L0-L1；io/fs 为显式允许)
  base (L0 only) → intf → impl → facade
```

- `base` 不依赖同模块任何文件；`intf` 依赖 `base`；`impl` 依赖 `intf+base`；`facade` 聚合 re-export。
- L2 禁止 `*.ffi/vendor/miniaudio/mpg123/opusfile`（gate `grep -qi "\.ffi|vendor"`）。
- 债务已收敛：`device.null/graph/timeline` 已迁移至 `nextpas.core.sync.mutex` + `nextpas.core.bytes.ops`（`SyncObjs/Classes/SysUtils` 直引已移除，`game` 经 `sfx` 兼容层收敛）；新增代码禁止直引宿主单元（gate `grep -R "uses.*SyncObjs|Classes|SysUtils"`）。

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
- `IRealtimeAudioSource.FillRealtime` 追加实时承诺；设备/图/时间线仅调此面。
- 契约注释「实时路径仅调 FillRealtime」在 `audio.intf` 冻结；gate 全量校验 `device.null/graph/timeline` 含 `FillRealtime`。
- 预分配不变量：调用方保证容量；实时违例 `clamp + InterlockedExchangeAdd64(FViolations)`，成功路径不分配。
- 返回值：`≥0` 填充帧，`0` 仅 EOF，失败以异常（离线）或静音+计数（实时）表达。
- 欠料：实时补静音返回 `AFrames`，`UnderrunCount` 原子上报，连续 `≥5` 发 `devUnderrun`。

### 4.1 快照化混音（无锁）

- **Timeline**：两阶段快照（锁内拷 `Position/Loop/Duration` + 存活轨计数 → 锁外分配 → 锁内深拷贝 `Clips`），`solo` 覆盖 `mute`，`Pan=(TrackPan+ClipPan)/2 → L/R=cos/sin`，`clamp`，`Loop` 跨 `SnapDur` 分段 `MixSegment`，`FPosition` 以快照基点确定性推进（`mod Dur`）。
- **Graph**：锁内拷存活节点/处理器快照，单 `scratch` 复用每节点零分配，处理器链双缓冲 `SwapBuf` 交换，`gain*volume+clamp`。
- **Device.Null**：`FScratch` 复用，`Drive→FillRealtime`，异常 `devDeviceError` 并零填，`FPosition:UInt64` 贯穿。

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
| 游戏 | `IGameAudio`（deprecated 别名在 `sfx.intf` → `ISfxAudio(0050)`，game 无独立 intf 按需存在） | `…00000050` |
| 空间 | `IAudioSpatialSource:IRealtimeAudioSource` | `…00000051` |
| 事件 | `IAudioEventSystem:IRealtimeAudioSource` | `…00000052` |
| 银行 | `IAudioBank:IRealtimeAudioSource` | `…00000053` |
| 资源 | `IAudioResourceManager` | `…00000054` |
| 播放列表 | `IAudioPlaylist` | `…00000080` |
| 工程 | `IAudioStudio` | `…00000070` |
| 工程 | `IStudioProject` | `…00000071` |
| 音序器 | `IAudioSequencer:IRealtimeAudioSource` | `…00000072` |
| 总线 | `IAudioBus` | `B…C00000000001`（B 前缀异形） |
| 总线混音 | `IAudioBusMixer` | `B…C00000000002`（B 前缀异形） |
| 时间线 | `IAudioTimeline:IRealtimeAudioSource` | `…00000060` |

- `TAudioEncodeOptions` 必须声明早于 `IAudioDecoder`（gate 顺序校验）。
- `IAudioGraph/IAudioTimeline/IAudioSpatialSource/IAudioBank/IAudioSequencer` 继承 `IRealtimeAudioSource` 以直连 `Device`。
- `B` 前缀 `C00000000001/02` 为 bus 异形 GUID，与 `A…` 核心域前缀区分，gate 单独校验（`B1A2B3C4-D5E6-7890-ABCD-C00000000001/02`）。

## 6. 容器与注册

- `Probe ≤4KB`：registry 一级容器嗅探 + 二级 codec 识别共用 `IAudioDecoder.Probe`；`AudioDetectProbeFromStream` 保持 `Position` 不变。
- `registry` 工厂前插，`AudioRegisterDecoder(nil)` 抛 `EInvalidArgument`，快照 `Copy(GFactories)` 无锁读。
- `TryDecodeWhole/File` 仅吞 `EAudioDecodeError`；`AudioOpenFileStreaming` 失败抛 `EAudioDecodeError`。
- 编码 `TAudioEncodeOptions.SampleFormat∈[sfS16,sfS24,sfF32] + ApplyDither`，v1 仅 WAV 实现。

## 7. 错误模型

`EAudioError(EIOError)` → `Decode/Encode/Device/Graph/Timeline` 五分支（`audio.errors` 唯一真值源），直线代码抛异常，边界统一捕获，`Try*` 仅分支时提供。

## 8. 数值与容器不变量

- `Frame*BlockAlign` / `Frame*Channels` / `Offset*Channels` 均 `Int64` 中间防 `Int32` 窄化与 `Round` 溢出；`16MB` 为 `Sinc` 输入上限（`FINDINGS F-06`）。
- WAV：`8..32位 + float + WAVEFORMATEXTENSIBLE 5.1/7.1 + fact/bext/rf64`；AIFF：`Extended80`；PCM：`S24` 紧排 3 字节 LE；`MixInto` 处理重叠别名（`F-36`）与 `Int64` 校验。

## 9. PR 切分（历史）与演进

`PR1 base → PR2 wav → PR3 aiff/meta/registry → PR5 resample/mix/dsp → PR6 device → PR7 graph/player → PR8 game → PR9 timeline`；`PR4 flac/mp3` 推迟由 `music888` 以 `Probe≤4KB` 可插拔吸收。`Graph` 复用快照路径，`Game/Timeline` 复用 `IAudioBuffer` 货币。

## 10. 验证

`268 tests HEAPTRC OK` + `84文件无ffi/vendor`（核心 29+扩展 55 四件套完整，unique 82+2 bus 门面，codec.flac/mp3/vorbis/opus 各 `base/intf/impl/pas` 四件套 1.5.2，wav四件套L2化）+ `23 GUID`（11 核心+12 扩展含 B 前缀 bus 异形）+ `实时纪律` + `hygiene` + `test_automation` 为 `focused-runtime` 必要条件（见 `CONTRACT.md §6/§8` 与 `README.md` 测试矩阵）。

## 11. 独立族演进（S10 预研）

`84 provisional = 26 core 冻结 + 58 ext 待抽`：`codec.flac/mp3/vorbis/opus` → `nextpas.core.audio.codec.*` 独立 L2（各 `base/intf/impl/pas` 四件套，`base` L0 only + `bytes.ops` 单源 + `Probe≤4KB`）；`spatial/bus/bank/resource/playlist/event/studio` → `nextpas.core.audio.*` 独立；`audio.simd/pcm.simd` → `nextpas.core.simd` 统一。抽离后 `audio` 仅保留 26 core，`L2→L2` 禁依赖，受控 seam 经 `module-registry` 登记 + gate，白名单前禁止在 `audio` 内继续堆叠。

