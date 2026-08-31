# nextpas.core.audio 代码契约

**模块路径**：`core/src/nextpas.core.audio*.pas`（36 个源文件，当前 36，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收）
**层级**：L2（只依赖 L0–L1；`io`/`fs` 为 L2 显式允许依赖，`registry+resource` 与 `wav file helper (codec.wav)` 已在 `core/docs/core-module-registry.md` 登记为 `L0-L1 plus io/fs registry+resource, wav file helper`）
**Owner**：audio lane
**最后更新**：2026-09-02
**版本**：1.2（P12 promotion — `TAudioSpatialParams` 等 canonical 至 `audio.base`，`spatial.intf` alias 兼容；同步 36 files/16门 218 tests）

---

## 概要

L2 音频子系统（decode-first，接口化）：以 `TAudioBuffer`/`TBytes` 为统一货币，覆盖**容器编解码 / PCM / DSP / 设备 / 图 / SFX / 时间线**七域+扩展（`SFX` 为 canonical，`game` 仅作 deprecated 薄转发；`spatial/event/bank/resource` 为 P5 扩展，当前 36 files，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收），纯 Pascal 可替换，实时路径零分配。门面 `nextpas.core.audio` 仅做 `type` 别名与 `inline` 转发，零逻辑。

---

## 1. 源文件与职责

| 单元 | 职责 | 四件套角色 |
|------|------|-----------|
| `audio.base` | `TAudioFormat/TAudioBuffer/TAudioClock/TAudioTags/TAudioDeviceInfo`，`ChannelMask` 真值源，`BlockAlign/ByteRate/FramesForMs/IsValid`，`TAudioProbeResult`，`TAudioVec3/TAudioListener/TAudioSpatialParams`（P12 canonical） | base |
| `audio.intf` | `IAudioSource(0010)/IRealtimeAudioSource(0011)/IAudioResampler(0020)/IAudioConverter(0021)/IAudioProcessor(0030)` | intf |
| `audio.codec.intf` | `IAudioDecoder(0001)/IAudioEncoder(0002)`，`TAudioEncodeOptions` | intf |
| `audio.codec.wav` | WAV 容器（8..32 位 + float + extensible 5.1/7.1 + fact/bext/rf64） | impl |
| `audio.codec.aiff` | AIFF/AIFC（80-bit Extended80 + ssnd offset） | impl |
| `audio.codec.meta` | ID3v2 / VorbisComment / RIFF INFO / `MergeTags` | impl |
| `audio.codec.registry` | `Probe≤4KB` 两级嗅探 + 可插拔 `AudioRegisterDecoder` | impl |
| `audio.pcm` | 纯函数 `U8/S16/S24/S32↔F32`、`Clamp`、`Interleave/Deinterleave`、`PcmConvert`、`TPDF` | impl |
| `audio.pcm_wav` | 兼容壳：`TPcmWavData/TryLoadPcmWav/WritePcmWav` 转发至 `codec.wav`（旧 Boolean 契约保留） | impl |
| `audio.resample` | 线性重采样 `AudioResampleLinear` | impl |
| `audio.resample.sinc` | Kaiser-sinc（Bessel I0），质量分级 `TResampleQuality` | impl |
| `audio.mix` | `MixInto/ApplyGain/ApplyGainRamp/NormalizePeak/NormalizeRMS`，pan law -3dB | impl |
| `audio.dsp.filters` | `TBiquad` TDF-II（Lowpass/Highpass/Bandpass 等） | impl |
| `audio.dsp.dynamics` | `TCompressor/TLimiter` | impl |
| `audio.dsp.fft` | `FFT/IFFT/WindowHann/IsPowerOfTwo` | impl |
| `audio.device.intf` | `IAudioDevice(0040)/IAudioDeviceProvider(0041)`，`TDeviceState/TDeviceEvent` | intf |
| `audio.device.null` | Null 后端：`FScratch` 复用 + `InterlockedExchangeAdd64` + MPSC `TDeviceEvent` + `Drive→FillRealtime` | impl |
| `audio.graph.intf` | `IAudioGraph(0042)/IAudioPlayer(0043)` | intf |
| `audio.graph` | 快照混音 `gain*volume+clamp`，单 scratch 双缓冲 `SwapBuf`，`snapshot mixing - lock free` | impl |
| `audio.player` | `IAudioPlayer` 控制面（`Play/Pause/Stop/Seek/Volume`） | impl |
| `audio.sfx.intf` | `ISfxAudio(0050)` canonical | intf |
| `audio.sfx` | SFX 池 `MaxVoices` 窃取 + `pitch/pan/loop` + `LoadFromFile→PcmConvert`，`EnsureSfxCapacity/EnsureVoiceCapacity` 几何扩容，`SFX lock -> Graph lock` 锁序，`PanLawGains0dB` 复用 | impl |
| `audio.game.intf` | `IGameAudio(0050)` deprecated 薄转发（`TGame* = TSfx*`） | intf |
| `audio.game` | SFX 池同 `sfx` 行为，薄转发 deprecated 兼容（test_game 15 为 deprecated 兼容门） | impl |
| `audio.timeline.intf` | `IAudioTimeline(0060)` | intf |
| `audio.timeline` | `Track/Clip` 排序混音 `solo/mute/loop`，快照化 `FillRealtime`，热点立体声展开，`two-phase snapshot + deep copy clip array + snapshot mixing - lock free` | impl |
| `audio.spatial.intf` | `IAudioSpatialSource(0051)`，`TAudio*` 均 `base` alias 兼容（P12 promotion），纯函数 `AudioSpatialize/AudioCompute*` 仍驻留 intf（to be moved to spatial.calc） | intf |
| `audio.spatial` | 3D panning：`two-phase snapshot + EnsureScratch + snapshot mixing - lock free`，`PcmConvert in FillRealtime is allowed but keep F32 — offline path preallocated, realtime path already F32 via EnsureF32` | impl |
| `audio.event.intf` | `IAudioEventSystem(0052)`，`TAudioSpatialParams` 已 canonical 至 `base`（P12），`spatial.intf` alias 兼容保留 | intf |
| `audio.event` | Event system：`two-phase snapshot + EnsureScratch/EnsureEventCapacity/EnsureInstanceCapacity + snapshot mixing - lock free` | impl |
| `audio.bank.intf` | `IAudioBank(0053)` | intf |
| `audio.bank` | SoundBank：`two-phase snapshot + EnsureScratch/EnsureBankCapacity + PanLawGains0dB + TRecursiveMutex + deep copy + snapshot mixing - lock free` | impl |
| `audio.resource.intf` | `IAudioResourceManager(0054)`，`AsyncLoad/ProbeFile` | intf |
| `audio.resource` | Resource manager：`AsyncLoad dedup+ProbeFile + TRecursiveMutex + EnsureCapacityLocked + ReleaseAll + Bank协同`，`fs` 为 `registry+resource, wav file helper` 豁免 | impl |
| `audio.errors` | `EAudioError(EIOError)→Decode/Encode/Device/Graph/Timeline` | base |
| `audio.pas` | 门面：别名 + inline 转发，零逻辑 | facade |

依赖方向：`base ← intf ← impl ← facade`；`ffi` 不存在（L2 禁止 foreign binding）。

---

## 2. 接口契约（公开 API）

### 2.1 统一货币

```pascal
TAudioSampleFormat = (sfU8, sfS16, sfS24, sfS32, sfF32);
TAudioChannelLayout = (clMono, clStereo, clQuad, clSurround51, clSurround71);
TAudioFormat = record
  SampleRate: Integer;      // [8000..192000]
  Channels: Integer;        // [1..8]
  SampleFormat: TAudioSampleFormat;
  ChannelMask: UInt32;      // WAVEFORMATEXTENSIBLE 真值源
  ChannelLayout: TAudioChannelLayout; // 由 Mask 推导的便捷提示
  function BlockAlign: Integer;       // Channels * BytesPerSample
  function BytesPerSample: Integer;
  function ByteRate: Int64;           // Int64(SampleRate) * BlockAlign
  function FramesForMs(AMs: Integer): Integer;
  function IsValid: Boolean;
  function Equals(const AOther: TAudioFormat): Boolean;
end;
TAudioBuffer = record
  Format: TAudioFormat;
  FrameCount: Integer;
  Data: TBytes; // Length = FrameCount * BlockAlign，交织 PCM；sfF32 为混音 canonical
end;
TAudioClock = record Frame: UInt64; SampleRate: Integer; function ToDurationNs: Int64; end;
TAudioTags = record Title, Artist, Album, Date: string; TrackNo: Integer; Extra: array of TAudioTagPair; end;
TAudioProbeResult = (prUnknown, prWav, prAiff, prFlac, prMp3, prOggVorbis, prOggOpus);
```

- `ChannelMask` 为唯一真值源；`AudioChannelMaskForLayout/AudioChannelLayoutForMask` 仅做提示互转。
- `BlockAlign = Channels * BytesPerSample`；`sfS24 = 3` 字节紧排小端。
- `ByteRate` 恒为 `Int64` 防溢出；`FramesForMs(AMs≤0)=0`。
- `AudioFormatCreate` 对 `SampleRate/Channels/SampleFormat` 越界抛 `EInvalidArgument`。

### 2.2 流式拉取面

```pascal
IAudioSource = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000010}']
  function GetFormat: TAudioFormat;
  function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  function SeekTo(AFrame: UInt64): Boolean;
end;
IRealtimeAudioSource = interface(IAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000011}']
  function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
end;
```

- **两级分离**：`IAudioSource.Fill` 允许分配/锁/IO（离线）；`IRealtimeAudioSource.FillRealtime` 承诺不 GetMem/不加锁/不做 IO/不抛异常。
- **实时纪律注释**「实时路径仅调 FillRealtime」在 `audio.intf` 冻结，gate 强校验。
- **预分配不变量**：调用方保证 `Length(ABuffer.Data) ≥ AFrames*BlockAlign`；离线违例抛 `EArgumentError`，实时违例 clamp + `InterlockedExchangeAdd64(FViolations)`。
- **返回值**：`≥0 实际填充帧`；`0 仅 EOF`；失败不以返回值表达（离线抛异常，实时零填静音 + 原子计数）。
- **欠料语义**：实时欠料内部补静音照常返回 `AFrames`，经 `UnderrunCount` 上报，连续 `≥5` 发 `devUnderrun`。

### 2.3 转换与 DSP

```pascal
IAudioResampler = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000020}']
  function Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
end;
IAudioConverter = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000021}']
  function Convert(const AInput: TAudioBuffer; const ATarget: TAudioFormat): TAudioBuffer;
end;
IAudioProcessor = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000030}']
  function LatencyFrames: Integer;
  procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
  procedure Reset;
end;
```

- 纯函数：`PcmU8/S16/S24/S32↔F32`、`PcmClamp*`、`PcmRead/WriteS24LE`、`PcmConvert`（经 F32 中间）、`PcmInterleave/Deinterleave`、`PcmTpdfNoise`；`F32` 混音 canonical。
- `AudioResampleLinear` / `CreateSincResampler(rsGood)`；Sinc 内部 `16MB` 上限。
- `MixInto/ApplyGain/NormalizePeak+RMS`；`Pan=(TrackPan+ClipPan)/2 → L/R=cos/sin`，`clamp ±1.0`。
- `TBiquad(TDF-II)` / `TCompressor/TLimiter` / `FFT/IFFT/Hann/IsPowerOfTwo`。

### 2.4 容器编解码

```pascal
IAudioDecoder = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000001}']
  function Probe(const APrefix: TBytes): TAudioProbeResult;
  function DecodeWhole(const AStream: IStream): TAudioBuffer;
  function OpenStreaming(const AStream: IStream): IAudioSource;
  function Tags: TAudioTags;
end;
IAudioEncoder = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000002}']
  procedure Encode(const ABuffer: TAudioBuffer; const ADest: IStream; const AOptions: TAudioEncodeOptions);
end;
TAudioEncodeOptions = record SampleFormat: TAudioSampleFormat; ApplyDither: Boolean; end;
```

- `Probe` 预算 `≤4KB`；registry 一级容器嗅探 + 二级 codec 识别共用此入口。
- `TryDecodeWhole`/`TryDecodeWholeFile` 仅吞 `EAudioDecodeError`，其他异常透传。
- `AudioDetectProbe/FromStream` 重置流位置；`AudioRegisterDecoder` 工厂前插，`nil` 抛 `EInvalidArgument`。
- v1 唯一编码实现为 WAV；`WavProbe/AiffProbe` 与 `CreateWav/AiffDecoder` 为便利别名。

### 2.5 设备

```pascal
IAudioDevice = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000040}']
  function GetInfo: TAudioDeviceInfo; function GetFormat: TAudioFormat;
  function GetState: TDeviceState; function GetPosition: TAudioClock;
  function GetUnderrunCount: UInt64; function GetContractViolationCount: UInt64;
  function PollEvent(out AEvent: TDeviceEvent): Boolean;
  procedure SetSource(const ASource: IRealtimeAudioSource);
  function Start: Boolean; function Stop: Boolean;
  function Drive(AFrames: Integer): Integer;
end;
IAudioDeviceProvider = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000041}']
  function Enumerate: TAudioDeviceInfoArray; function GetDefault: TAudioDeviceInfo;
  function CreateDevice(const AID: string; const AFormat: TAudioFormat): IAudioDevice;
  function CreateDefaultDevice(const AFormat: TAudioFormat): IAudioDevice;
end;
TDeviceState = (dsClosed, dsOpened, dsStarted);
TDeviceEventKind = (devStarted, devStopped, devUnderrun, devDeviceError, devDeviceLost);
```

- 状态机 `dsClosed→Opened→Started`；`SetSource` 在 `Started` 抛 `EAudioDeviceError`；`Start` 校验 `Source.Format` 采样率/声道匹配。
- `Drive` 调 `FillRealtime`：异常则 `devDeviceError` + 静音 + `FViolations`；`LRet=0` 视为 EOF 转 `dsOpened` + `devStopped`；`LRet<AFrames` 递增 `FUnderruns` + `FViolations`，连续 `≥5` 发 `devUnderrun`。
- 计数器以 `InterlockedExchangeAdd64` 原子累加，`GetPosition` 返回 `FPosition:UInt64 + SampleRate`。

### 2.6 图与播放器

```pascal
IAudioGraph = interface(IRealtimeAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000042}']
  function GetState: TGraphState; function NodeCount: Integer;
  function AddSource(const ASource: IRealtimeAudioSource; AGain: Single): Integer;
  function RemoveSource(AId: Integer): Boolean; function SetGain(AId: Integer; AGain: Single): Boolean;
  function AddProcessor(const AProcessor: IAudioProcessor): Integer;
  function RemoveProcessor(AId: Integer): Boolean; procedure Clear;
end;
IAudioPlayer = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000043}']
  function GetGraph: IAudioGraph; function GetDevice: IAudioDevice;
  function GetState: TGraphState; function GetPosition: TAudioClock;
  function Play: Boolean; function Pause: Boolean; function Stop: Boolean;
  function Seek(AFrame: UInt64): Boolean; function SetVolume(AVolume: Single): Boolean;
end;
```

- `Graph` 格式必为 `sfF32` 且 `IsValid`，否则 `EAudioGraphError`；`AddSource` 校验采样率/声道一致，`NaN/Inf` gain 归一为 `1.0`。
- `FillRealtime` 锁内仅拷贝存活节点/处理器快照（固定容量思想），混音无锁；单 `FScratch` 复用每节点零分配，处理器链双缓冲 `SwapBuf` 交换；`SeekTo` 广播至存活源。

### 2.7 SFX / 游戏（deprecated 兼容）与时间线 / 空间 / 事件 / Bank / Resource

```pascal
ISfxAudio = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000050}'] // canonical 0050
  function Load(const ABuffer: TAudioBuffer): TSfxId;
  function Play(ASfx: TSfxId; ...): TVoiceId; // gain/pan/pitch/loop
end;
IGameAudio = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000050}'] // deprecated 薄转发，TGame* = TSfx*
  function Load(const ABuffer: TAudioBuffer): TGameSfxId;
  function Play(ASfx: TGameSfxId; ...): TGameVoiceId;
end;
IAudioTimeline = interface(IRealtimeAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000060}']
  function AddTrack(AGain: Single): TTimelineTrackId;
  function AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; ...): TTimelineClipId;
  function SetTrackGain/Pan/Mute/Solo(...): Boolean; procedure Clear;
  property Loop: Boolean; property Position/Duration: UInt64;
end;
TTimelineClip = record Id: TTimelineClipId; Buffer: TAudioBuffer; StartFrame: UInt64; Gain, Pan: Single; Alive: Boolean; end;
TTimelineTrack = record Id: TTimelineTrackId; Clips: array of TTimelineTrack; Gain, Pan: Single; Muted, Solo: Boolean; Alive: Boolean; end;
IAudioSpatialSource = interface(IRealtimeAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000051}'] // 3D panning
IAudioEventSystem = interface(IRealtimeAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000052}'] // event → spatial → bank
IAudioBank = interface(IRealtimeAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000053}'] // SoundBank preload+refcount
IAudioResourceManager = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000054}'] // AsyncLoad dedup+ProbeFile, Bank协同
```

- `Sfx` 音色池 `MaxVoices` 窃取，`Load/Play/StopVoice/MasterGain`，`LoadFromFile` 经 `PcmConvert`，`SFX lock -> Graph lock` 锁序，`PanLawGains0dB` 共用；`Game` 为 deprecated 薄转发（`test_game` 15 为 deprecated 兼容门，统一按 `ISfxAudio` 0050 校验）。
- `Timeline` 即 `IRealtimeAudioSource` 可直连 `Device/Graph`；`FillRealtime` 快照化（拷 `Position/Loop/Duration` + 存活轨），排序混音，`solo` 覆盖 `mute`，`Pan` 热点展开同 `Mix`，`snapshot mixing - lock free`，`deep copy clip array`。
- `Spatial` 3D panning：`TAudio*` 均 `base` canonical（P12），纯函数仍驻留 `spatial.intf`（to be moved to spatial.calc），`spatial.pas` 实时路径 `PcmConvert in FillRealtime is allowed but keep F32 — offline path preallocated, realtime path already F32 via EnsureF32`。
- `Event` 已 canonical 至 `base`（P12），`two-phase snapshot + EnsureScratch/EnsureEventCapacity/EnsureInstanceCapacity + snapshot mixing - lock free`。
- `Bank/Resource`：`Bank` 复用 `PanLawGains0dB`、`TRecursiveMutex`、`EnsureBankCapacity` 几何扩容、深拷贝隔离、`snapshot mixing - lock free`；`Resource` 为 `AsyncLoad dedup+ProbeFile`、`TRecursiveMutex`、`EnsureCapacityLocked` 几何扩容、`ReleaseAll`、`Bank协同`，`fs` 豁免登记为 `registry+resource, wav file helper`。
- 理想态 45 — 9 files 预留 `flac/mp3/vorbis/studio/playlist` 等由 `music888` 以 `Probe≤4KB` 可插拔吸收（与 DESIGN §9 同词）。

### 2.8 门面

`nextpas.core.audio` 仅 `type` 别名 + `inline` 转发，零逻辑，聚合以上 36 单元（当前 36，理想态 45 — 9 files 预留）；消费方多数场景只 `uses nextpas.core.audio`。

---

## 3. 错误与失败契约

| 域 | 异常 | 触发 |
|----|------|------|
| base | `EInvalidArgument` | `AudioFormatCreate` 越界 |
| decode | `EAudioDecodeError(EAudioError)` | 容器损坏/不支持形态/`Probe` 未命中后调用 |
| encode | `EAudioEncodeError` | 编码失败 |
| device | `EAudioDeviceError` | 无源 `Start`/格式失配/unknown id/`dsClosed`/`Started` 时 `SetSource` |
| graph | `EAudioGraphError` | `AddSource(nil)`/`AddProcessor(nil)`/格式非 `sfF32`/失配 |
| timeline | `EAudioTimelineError` | `invalid buffer/format mismatch/unknown track` |

- 直线代码默认抛异常，边界统一捕获；`Try*` 仅在需分支时提供（`TryDecodeWhole/TryDecodeWholeFile` 仅吞 `EAudioDecodeError` 家族）。
- 实时路径不抛：异常内捕 → 静音 + `FViolations` + `devDeviceError`，外层不泄。

---

## 4. 不变量

- **[INV-1]** `TAudioFormat.IsValid` ⇔ `SampleRate∈[8000..192000]` ∧ `Channels∈[1..8]` ∧ `SampleFormat∈[sfU8..sfF32]`；`BlockAlign>0` ∧ `ByteRate>0`。
- **[INV-2]** `ChannelMask` 为真值源；`ChannelLayout` 仅提示，`8ch≠0x63F` 时以 Mask 为准。
- **[INV-3]** `TAudioBuffer.Data.Length = FrameCount*BlockAlign`；`sfF32` 为混音 canonical，`SampleCount=FrameCount*Channels`。
- **[INV-4]** `Probe` 前缀 `≤4096` 字节；`FromStream` 进入/退出保持 `Position` 不变。
- **[INV-5]** `Fill` 预分配不变量：实时违例不抛，`clamp + FViolations`；离线违例抛。
- **[INV-6]** `Drive`/`Graph/Timeline.FillRealtime` 每周期不 `SetLength` 到输出缓冲（`FScratch`/快照复用），稳态零堆增长。
- **[INV-7]** `TAudioClock.ToDurationNs = Frame*1e9 / SampleRate`（`SampleRate≤0 → 0`），仅调度面使用。
- **[INV-8]** 所有 `Length(ABytes) div BlockAlign` 换算以 `Int64` 为中间类型，`Frame*BlockAlign` 禁 `Int32` 窄化。

---

## 5. 依赖边界

- 允许：`base/exception/errors`（L0），`bytes/text/encoding/collections/sync/platform/mem/io/fs` 等 L0-L1；`io/fs` 为 L2 容器 IO 必要依赖（显式允许，`registry+resource` 与 `wav file helper (codec.wav)` 已登记为 `L0-L1 plus io/fs registry+resource, wav file helper`）。
- 禁止：任何 `*.ffi/vendor/miniaudio/mpg123/opusfile`（gate `grep -qi "\.ffi|vendor"` 强校验）；`Classes/SysUtils` 债务收敛至 5 文件（`sfx/timeline/event/bank/resource`，`device.null/graph/spatial` 已去冗余，`P11/P12`），最终目标 `nextpas.core.sync/platform`（`FINDINGS F-17`）。
- 同层 `L2→L2` 仅允许 `io/fs/compress` 等已登记豁免（`registry+resource, wav file helper` 显式登记），不引入 `crypto/compress` 越层。

---

## 6. 测试入口

```bash
bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh # 36 文件无 ffi/vendor（当前 36，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收） + 17 GUID (unique; 15 realtime domain) + 实时纪律
for g in test_base test_pcm_wav test_wav test_aiff test_meta test_registry \
         test_resample test_mix test_dsp test_device test_graph test_sfx test_game test_timeline test_event test_bank test_resource; do
  make -C core/tests/nextpas.core.audio/$g clean test
done
# 注：test_game 15 为 deprecated 兼容门（IGameAudio → ISfxAudio 薄转发），16门统计含 deprecated，理想态 45 Gate 同步。
make -C core/benchmarks/nextpas.core.audio/bench_pcm_wav clean bench  # -O2, 输出 ns/op + MB/s
make hygiene && git diff --check
```

| Gate | 用例 | 要点 |
|---|---|---|
| test_base 20 | 格式/掩码/时钟/Buffer/PCM/Errors/门面 |
| test_pcm_wav 12 | 兼容壳八拒四正 |
| test_wav 16 | wav 全形态 + extensible 5.1/7.1 + fact/bext/rf64 |
| test_aiff 11 | aiff/aifc + Extended80 |
| test_meta 11 | ID3v2/Vorbis/RIFF INFO/MergeTags |
| test_registry 9 | Probe 与可插拔 |
| test_resample 14 | 线性/sinc 零分配与质量分级 |
| test_mix 11 | MixInto/增益/归一/pan law |
| test_dsp 14 | Biquad/Compressor/Limiter/FFT |
| test_device 15 | Null MPSC 与 Drive/Underrun |
| test_graph 16 | 快照混音与双缓冲，`snapshot mixing - lock free` |
| test_sfx 15 | SFX 池与窃取（canonical 0050） |
| test_game 15 | SFX 池与窃取（deprecated 兼容，薄转发 `IGameAudio` 0050） |
| test_timeline 16 | 排序/声像/solo/mute/loop/Device 联动，`snapshot mixing - lock free` |
| test_event 10 | 事件注册/空间衰减/参数/窃取，`snapshot mixing - lock free` |
| test_bank 15 | Bank 预加载/引用计数/混音/pan/pitch/loop，`snapshot mixing - lock free` |
| test_resource 13 | Resource 异步加载/去重/Probe/Release，`Bank协同` |

全量 `218 tests` (16门，含 deprecated test_game 兼容门) 且 `HEAPTRC OK` 为晋升 `focused-runtime` 必要条件（当前 36 files，理想态 45 — 9 files 预留）。

---

## 7. Out of scope / Future

**当前不存在（禁止写成已实现）：**
- FLAC/MP3/Opus 纯 Pascal 解码（`PR4` 已推迟，`music888` 已有实现，后续以 `Probe≤4KB` 可插拔吸收进 `registry`）
- 真实硬件后端（仅 `Null` 后端；`ALSA/CoreAudio/WASAPI` 后续）
- `IAudioDevice` 热迁移/自动重选

**Future（需独立 slice + consumer）：** FLAC/MP3 registry 吸收、Sinc 质量扩展、硬件后端、Timeline 自动化曲线。

---

## 8. 门禁与晋升

- `source-contract`：`check_source_contract.sh` 36 文件 `无ffi/vendor`（当前 36，理想态 45 — 9 files 预留 flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收） + `17 GUID frozen (unique; 15 realtime domain)` + `TAudioEncodeOptions before IAudioDecoder` + `实时纪律 + two-phase/EnsureScratch/snapshot mixing - lock free/PanLawGains` + 9 域文件存在性（含 sfx canonical + spatial/event/bank/resource）
- `focused-runtime`：`16门 218 tests` 全绿（含 deprecated test_game 兼容门） + `HEAPTRC` 零泄漏 + `hygiene` 绿（当前 truth level，`bench 10项 -O2`）
- 禁止以 `focused-runtime` 冒充 `ci-matrix`；跨 host 未证明前不晋升。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首次冻结：对齐 26 单元 + 11 GUID + 双平面纪律 + Probe≤4KB + 180 用例门禁 |
| 2026-08-31 | 1.1 | 同步 36 files/16门 218 tests；test_game 为 deprecated 兼容门；ideal 45 9 files 预留与 DESIGN §9 同词（flac/mp3/vorbis/studio/playlist 等由 music888 以 Probe≤4KB 可插拔吸收）；17 GUID (unique; 15 realtime domain) |
| 2026-09-02 | 1.2 | P12 promotion — `TAudioSpatialParams` 等 canonical 至 `base`，`spatial.intf` alias 兼容；`device.null/graph/bank` 死依赖收敛（P11）；`resource` TThread 债务标注 |
