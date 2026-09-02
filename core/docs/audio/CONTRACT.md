# nextpas.core.audio 代码契约

**模块路径**：`core/src/nextpas.core.audio*.pas`（核心 26 冻结 + 扩展 52 候选，共 78 个源文件 provisional；核心 26（`base/intf/codec.intf/wav/aiff/meta/registry/pcm/pcm_wav/resample/sinc/mix/dsp.filters/dynamics/fft/device.intf/null/graph.intf/graph/player/sfx.intf/sfx/game.intf/game/timeline.intf/timeline/errors/pas`）为 `nextpas.core.audio` 唯一 Owner 真值源，守 L0–L3 与四件套 `base←intf←impl←facade` 独立演进不变量；扩展 52 = 22 四件套按需补齐（`bank.base/impl/resource.base/impl/event.base/impl/spatial.base/impl/playlist.base/intf/impl/studio.base/studio.pas` + `codec.flac/mp3/vorbis` 各 `base/intf/impl` 9 文件）+ 30 候选域实现（`codec.*.decoder/.sse` 6 + `spatial/bus/simd/pcm.simd/bank/resource/playlist/event/studio.*` 余量），当前 provisional 全量堆叠于 audio 内、臃肿失高级感，违反 L2 Owner 边界，待抽独立 L2 模块：`nextpas.core.audio.codec.flac` / `mp3` / `vorbis`（各 `base/intf/impl/pas` 四件套）、`nextpas.core.audio.spatial`、`nextpas.core.audio.bus`、`nextpas.core.audio.bank`/`resource`/`playlist`/`event`/`studio`、`nextpas.core.simd`（`audio.simd/pcm.simd` 薄封装复用）；抽离后 audio 仅保留 26 核心，`L2→L2` 禁依赖，受控 seam 需 `module-registry` 登记 + gate；78 实盘 provisional = 56 冻结 + 22 按需补齐，unique 76+2 bus facade，禁止继续在 audio 内堆叠新域，缺能力先反哺 owner `bytes.ops/text/simd/mem`）
**层级**：L2（只依赖 L0–L1；`io`/`fs` 为 L2 显式允许依赖；`bytes.ops` 为字节操作单源，禁止各 codec 自写重复 Move/SetLength；`inline/零拷贝`：热点 `inline` + `bytes.ops.Move/BytesEnsureCapacity` 零拷贝，`FillRealtime` 路径 `EnsureScratch/FSnap` 预分配稳态零堆增长；`稳定性`：`Clear/Destroy` 必 `SetLength(Data,0)+FreeAndNil/WaitFor`，`HEAPTRC` 零泄漏）
**Owner**：audio lane（仅 26 核心；52 候选 Owner 待迁移至新模块 lane，audio 仅 provisional 托管）
**最后更新**：2026-09-02
**版本**：1.5.1（codec 四件套完整 69→78 +23 GUID 不变；78 provisional = 26 core 冻结 + 52 ext 候选待抽独立 L2，四件套按需补齐 22 文件收敛；52 寄生已标注 provisional，违反 L2 Owner 边界待抽 `codec.flac/mp3/vorbis`/`spatial`/`bus`/`bank`/`resource`/`playlist`/`event`/`studio`/`simd` 独立模块，抽离后 audio 回归 26 核心高级感）

---

## 概要

L2 音频子系统（decode-first，接口化）：以 `TAudioBuffer`/`TBytes` 为统一货币，覆盖**容器编解码 / PCM / DSP / 设备 / 图 / 游戏 / 时间线**七域，纯 Pascal 可替换，实时路径零分配。门面 `nextpas.core.audio` 仅做 `type` 别名与 `inline` 转发，零逻辑。

---

## 1. 源文件与职责

| 单元 | 职责 | 四件套角色 |
|------|------|-----------|
| `audio.base` | `TAudioFormat/TAudioBuffer/TAudioClock/TAudioTags/TAudioDeviceInfo`，`ChannelMask` 真值源，`BlockAlign/ByteRate/FramesForMs/IsValid`，`TAudioProbeResult` | base |
| `audio.intf` | `IAudioSource(0010)/IRealtimeAudioSource(0011)/IAudioResampler(0020)/IAudioConverter(0021)/IAudioProcessor(0030)` | intf |
| `audio.codec.intf` | `IAudioDecoder(0001)/IAudioEncoder(0002)`，`TAudioEncodeOptions` | intf |
| `audio.codec.wav.base` | `CWavProbeLimit=4096` + `WAVE_FORMAT_*` + `MAX_WAV_PAYLOAD_BYTES` 常量，L0 only | base |
| `audio.codec.wav.intf` | `IWavDecoder/IWavEncoder = IAudioDecoder/Encoder` 别名，复用 `codec.intf` GUID 0001/0002，无新增 GUID | intf |
| `audio.codec.wav.impl` | WAV 容器实现：`WavProbe≤4KB` `prWav` + `DecodeWhole/Encode/OpenStreaming` + `TMemoryWavSource`，`bytes.ops` 单源，不引 `ffi/vendor`，`inline` 零拷贝 | impl |
| `audio.codec.wav` | WAV facade：`type` 别名 + `inline` 转发 `WavProbe/CreateWavDecoder/CreateWavEncoder/AudioEncodeWav` + 文件便利（`fs`），零逻辑，四件套聚合 | facade |
| `audio.codec.aiff` | AIFF/AIFC（80-bit Extended80 + ssnd offset） | impl |
| `audio.codec.meta` | ID3v2 / VorbisComment / RIFF INFO / `MergeTags` | impl |
| `audio.codec.registry` | `Probe≤4KB` 两级嗅探 + 可插拔 `AudioRegisterDecoder` | impl |
| `audio.pcm` | 纯函数 `U8/S16/S24/S32↔F32`、`Clamp`、`Interleave/Deinterleave`、`PcmConvert`、`TPDF`；热点 `inline` + `bytes.ops.Move` 单源零拷贝 | impl |
| `audio.pcm.simd` | 批量 `S16/S32↔F32` 四路展开 `inline`，复用 `bytes.ops` 单源，不自写重复 Move | impl（候选抽离 → `audio.simd` 统一） |
| `audio.pcm_wav` | 兼容壳：`TPcmWavData/TryLoadPcmWav/WritePcmWav` 转发至 `codec.wav`（旧 Boolean 契约保留） | impl |
| `audio.resample` | 线性重采样 `AudioResampleLinear` | impl |
| `audio.resample.sinc` | Kaiser-sinc（Bessel I0），质量分级 `TResampleQuality` | impl |
| `audio.mix` | `MixInto/ApplyGain/ApplyGainRamp/NormalizePeak/NormalizeRMS`，pan law -3dB；`SimdAddF32` 零分配 | impl |
| `audio.dsp.filters` | `TBiquad` TDF-II（Lowpass/Highpass/Bandpass 等） | impl |
| `audio.dsp.dynamics` | `TCompressor/TLimiter` | impl |
| `audio.dsp.fft` | `FFT/IFFT/WindowHann/IsPowerOfTwo` | impl |
| `audio.device.intf` | `IAudioDevice(0040)/IAudioDeviceProvider(0041)`，`TDeviceState/TDeviceEvent` | intf |
| `audio.device.null` | Null 后端：`FScratch` 复用 + `InterlockedExchangeAdd64` + MPSC `TDeviceEvent` + `Drive→FillRealtime` | impl |
| `audio.graph.intf` | `IAudioGraph(0042)/IAudioPlayer(0043)` | intf |
| `audio.graph` | 快照混音 `gain*volume+clamp`，单 scratch 双缓冲 `SwapBuf`；两阶段快照零分配 | impl |
| `audio.player` | `IAudioPlayer` 控制面（`Play/Pause/Stop/Seek/Volume`） | impl |
| `audio.sfx.intf` | `ISfxAudio(0050)` canonical，`TSfxPlayParams` + `IGameAudio/TGameSfxId` 等 deprecated 别名 | intf |
| `audio.sfx` | SFX 池实现 `MaxVoices` 窃取 + `pitch/pan/loop` | impl |
| `audio.game` | deprecated 兼容层：转发至 `sfx`（保留一版，无独立 intf 按需存在） | impl |
| `audio.timeline.intf` | `IAudioTimeline(0060)` | intf |
| `audio.timeline` | `Track/Clip` 排序混音 `solo/mute/loop`，快照化 `FillRealtime`，热点立体声展开 | impl |
| `audio.errors` | `EAudioError(EIOError)→Decode/Encode/Device/Graph/Timeline` | base |
| `audio.pas` | 门面：别名 + inline 转发，零逻辑（仅聚合 26 核心，守 `base←intf←impl←facade`） | facade |
| _— 扩展（52，实盘 78-26，provisional 寄生待抽独立 L2，L2 臃肿失高级感·禁止继续堆叠）—_ | — | — |
| `audio.codec.flac.base` | `CFlacProbeLimit=4096` + `CFlacMagic` + `CFlacMaxDecodeBytes` 常量，L0 only | base |
| `audio.codec.flac.intf` | `IFlacDecoder = IAudioDecoder` 别名，复用 `codec.intf` GUID 0001，无新增 GUID | intf |
| `audio.codec.flac.impl` | FLAC 解码实现：`FlacProbe/FlacDecodeWholeViaCursor`，Probe≤4KB `prFlac`，`bytes.cursor` + `bytes.ops` 单源，不引 `ffi/vendor`，`STUB: OpenStreaming` 桩 | impl |
| `audio.codec.flac` / `.decoder` / `.sse` | FLAC facade `type` 别名 + `inline` 转发 + 纯 Pascal 解码/加速，Probe≤4KB | facade/impl（候选 → `nextpas.core.audio.codec.flac` 独立模块，四件套 `base←intf←impl←facade`） |
| `audio.codec.mp3.base` | `CMp3ProbeLimit=4096` + `CMp3MaxStreamBytes` 常量，L0 only | base |
| `audio.codec.mp3.intf` | `IMp3Decoder = IAudioDecoder` 别名，复用 0001 | intf |
| `audio.codec.mp3.impl` | MP3 解码实现：`Mp3Probe/Mp3DecodeWholeViaStream`，Probe≤4KB `prMp3` | impl |
| `audio.codec.mp3` / `.decoder` / `.sse` | MP3 facade + 解码/加速 | facade/impl（四件套完整） |
| `audio.codec.vorbis.base` | `CVorbisProbeLimit=4096` + `CVorbisMaxDecodeBytes` 常量，L0 only | base |
| `audio.codec.vorbis.intf` | `IVorbisDecoder = IAudioDecoder` 别名 | intf |
| `audio.codec.vorbis.impl` | Vorbis 解码实现：`VorbisProbe/VorbisDecodeWholeViaStream`，`prOggVorbis` 归一 `codec.meta` | impl |
| `audio.codec.vorbis` / `.decoder` / `.sse` | Vorbis facade + 解码/加速 | facade/impl（四件套完整） |
| `audio.spatial.base` | `TAudioDistanceModel` + `CAudioSpatialDefault*` 常量，L0 only | base |
| `audio.spatial.intf` | `IAudioSpatialSource(0051)` 3D 衰减/声像，GUID 0051 冻结，`inline` 辅助 | intf |
| `audio.spatial.impl` | 3D 衰减/声像实现 `AudioComputeAttenuation/Pan/Doppler` 纯函数 `inline` + `EnsureScratch` 零分配 | impl |
| `audio.spatial` | 门面：`type` 别名 + `inline CreateSpatialSource` 转发，零逻辑，四件套聚合（spatial.base+spatial.intf+spatial.impl+spatial.pas 共 4 文件） | facade |
| `audio.bus.base` | `TAudioBusId` + `CAudioBusMax*` 常量，L0 only | base |
| `audio.bus.intf` | `IAudioBus(B…C00000000001)/IAudioBusMixer(B…C00000000002)` GUID 冻结（B 前缀 bus 异形，与 A 前缀核心域区分）+ `GetId/Gain/Format/Source` 契约 | intf |
| `audio.bus.impl` | `TAudioBus/TAudioBusMixer` 实现：`IMutex` owner 隔离（`nextpas.core.sync`）、`BytesEnsureCapacity` 单源、`EnsureScratch inline` 预分配零分配、快照 `FillRealtime` 零拷贝 `SimdAddF32`、`try..finally` 释放不丢 | impl |
| `audio.bus` | 门面：`type` 别名 + `inline CreateAudioBusMixer` 转发，零逻辑，四件套聚合（bus.base+bus.intf+bus.impl+bus.pas 共 4 文件） | facade |
| `audio.simd` | `SimdAdd/Mul/Peak/SumSquares/Clamp` 运行时分派 SSE2→AVX2/NEON，标量回退 | impl（候选 → `nextpas.core.simd` 复用，audio 仅薄封装） |
| `audio.bank.base` | `TAudioBankId/TBankVoiceId/TBankPlayParams` + `CAudioBankIdInvalid` 常量，L0 only | base |
| `audio.bank.intf` | `IAudioBank(0053)` SoundBank 预加载，GUID 0053 冻结 | intf |
| `audio.bank.impl` | SoundBank 实现：`Copy` 深拷贝 + `EnsureScratch inline` 预分配零分配、引用计数、`SetLength(Data,0)` 资源释放不丢 | impl |
| `audio.bank` | 门面：`type` 别名 + `inline CreateAudioBank` 转发，零逻辑，四件套聚合（bank.base+bank.intf+bank.impl+bank.pas 共 4 文件） | facade |
| `audio.resource.base` | `TAudioResourceState/TAudioResourceId` + `CAudioResourceIdInvalid`，L0 only | base |
| `audio.resource.intf` | `IAudioResourceManager(0054)` 异步引用计数 + `ProbeFile≤4KB`，GUID 0054 冻结 | intf |
| `audio.resource.impl` | 异步实现：`TRecursiveMutex` + `ProbeFile≤4KB` + `WaitFor` 线程安全 | impl |
| `audio.resource` | 门面：`type` 别名 + `inline CreateAudioResourceManager` 转发，零逻辑，四件套聚合（resource.base+resource.intf+resource.impl+resource.pas 共 4 文件） | facade |
| `audio.playlist.base` | `TPlaylistItem/TPlaylistState` + `CAudioPlaylist*`，依赖 `audio.base` | base |
| `audio.playlist.intf` | `IAudioPlaylist(0080)` 队列接口，依赖 `playlist.base` | intf |
| `audio.playlist.impl` | `TAudioPlaylist` 实现：`TRecursiveMutex` + `AudioEnsureCapacity` + `SimdAddF32` 快照零分配 | impl |
| `audio.playlist` | 门面：`type` 别名 + `inline CreateAudioPlaylist` 转发，零逻辑 | facade（已拆 `base←intf←impl←facade` 完整，兼容旧 `uses playlist`） |
| `audio.event.base` | `TAudioEventId/TAudioEventInstanceId/TAudioEventParamId` + `CAudioMaxEventParams`，L0 only | base |
| `audio.event.intf` | `IAudioEventSystem(0052)` + RTPC `SetInstanceParam`，GUID 0052 冻结 | intf |
| `audio.event.impl` | 事件实现：`MaxVoices` 窃取 + 空间化 + `EnsureScratch inline` 零分配 | impl |
| `audio.event` | 门面：`type` 别名 + `inline CreateAudioEventSystem` 转发，零逻辑，四件套聚合（event.base+event.intf+event.impl+event.pas 共 4 文件） | facade |
| `audio.studio.base` | `CAudioStudioDefaultBpm/Min/Max` + `TStudioTimeUnit`，L0 only | base（新增） |
| `audio.studio.intf`(0070) / `.automation` / `.project`(0071) / `.sequencer`(0072) | Studio 工程/自动化曲线 Hermite 插值 + 音序器 2048 点正弦表 `inline`，`FillRealtime` 快照；0070/0071/0072 三 GUID 冻结 | intf/impl（候选 → `nextpas.core.audio.studio`） |
| `audio.studio` | 聚合门面：`type` 别名 + `inline CreateStudioProject/CreateAudioSequencer/StudioBpmToFramesPerBeat` 转发，聚合 `automation/sequencer/project` | facade（新增，`studio.base←intf←automation/project/sequencer←facade`） |

依赖方向：`base ← intf ← impl ← facade`；`ffi` 不存在（L2 禁止 foreign binding）；扩展 52 仍守 `L0-L3` 与 `bytes.ops` 单源、`inline/零拷贝`（热点 `inline` + `BytesEnsureCapacity/SpanCopySlice/Move` 单源，`FillRealtime` 路径 `EnsureScratch/FSnap` 预分配稳态零堆增长）与 `稳定性`（`Clear/Destroy` 必 `SetLength(Data,0)+FreeAndNil/WaitFor`，`HEAPTRC` 零泄漏），业务以本契约为准、缺能力先反哺 owner（`bytes/text/simd/mem`）再在 audio 内 provisional 实现；52 候选当前 provisional 寄生违反 L2 Owner 边界，禁止继续膨胀，待抽独立 L2 模块后 audio 仅保留 26 核心（高级感回归），四件套 `base←intf←impl←facade` 独立演进不变量在新模块中延续。

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

### 2.7 游戏与时间线

```pascal
IGameAudio = interface ['{F1A2B3C4-D5E6-7890-ABCD-A00000000050}']
  function Load(const ABuffer: TAudioBuffer): TGameSfxId;
  function Play(ASfx: TGameSfxId; ...): TGameVoiceId; // gain/pan/pitch/loop
end;
IAudioTimeline = interface(IRealtimeAudioSource) ['{F1A2B3C4-D5E6-7890-ABCD-A00000000060}']
  function AddTrack(AGain: Single): TTimelineTrackId;
  function AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; ...): TTimelineClipId;
  function SetTrackGain/Pan/Mute/Solo(...): Boolean; procedure Clear;
  property Loop: Boolean; property Position/Duration: UInt64;
end;
TTimelineClip = record Id: TTimelineClipId; Buffer: TAudioBuffer; StartFrame: UInt64; Gain, Pan: Single; Alive: Boolean; end;
TTimelineTrack = record Id: TTimelineTrackId; Clips: array of TTimelineClip; Gain, Pan: Single; Muted, Solo: Boolean; Alive: Boolean; end;
```

- `Game` 音色池 `MaxVoices` 窃取，`Load/Play/StopVoice/MasterGain`，`LoadFromFile` 经 `PcmConvert`。
- `Timeline` 即 `IRealtimeAudioSource` 可直连 `Device/Graph`；`FillRealtime` 快照化（拷 `Position/Loop/Duration` + 存活轨），排序混音，`solo` 覆盖 `mute`，`Pan` 热点展开同 `Mix`。

### 2.8 门面

`nextpas.core.audio` 仅 `type` 别名 + `inline` 转发，零逻辑，聚合以上 26 单元；消费方多数场景只 `uses nextpas.core.audio`。

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
- **[INV-6]** `Drive`/`Graph/Timeline/Bank/Event.FillRealtime` 每周期不 `SetLength` 到输出缓冲（`FScratch/FSnap` 复用 + `EnsureScratch` 几何扩容预分配），稳态零堆增长；热点 `inline` 零拷贝 `Move` 单源为 `bytes.ops`。
- **[INV-7]** `TAudioClock.ToDurationNs = Frame*1e9 / SampleRate`（`SampleRate≤0 → 0`），仅调度面使用。
- **[INV-8]** 所有 `Length(ABytes) div BlockAlign` 换算以 `Int64` 为中间类型，`Frame*BlockAlign` 禁 `Int32` 窄化。
- **[INV-9]** `bytes.ops` 单源：`pcm/codec.*` 等字节拼接/复制/填充均经 `BytesEnsureCapacity/SpanCopySlice/Move` 单源，禁止各文件自写重复 `SetLength+Move`；`Probe≤4KB` 前缀零分配。
- **[INV-10]** 资源释放不丢：`Bank/Resource/Event/Playlist/Studio` 的 `Clear/Release/Destroy` 必须 `SetLength(Data,0)` + `FreeAndNil` + `WaitFor`，`HEAPTRC` 零泄漏为晋升必要条件。

---

## 5. 依赖边界

- 允许：`base/exception/errors`（L0），`bytes/text/encoding/collections/sync/platform/mem/io/fs` 等 L0-L1；`io/fs` 为 L2 容器 IO 必要依赖（显式允许）；`bytes.ops` / `bytes.cursor` / `bytes.builder` 为字节操作唯一真值源（`pcm/codec.*` 等禁止自写 `Move/SetLength` 重复实现，复用 `BytesEnsureCapacity/AudioEnsure*`）。
- 禁止：任何 `*.ffi/vendor/miniaudio/mpg123/opusfile`（gate `grep -qi "\.ffi|vendor"` 强校验，78 文件全量）；`SyncObjs/Classes/SysUtils` 直引已收敛至 `nextpas.core.sync`/`nextpas.core.bytes.ops`（`device.null/graph/timeline` 已迁移，`game` 经 `sfx` 兼容层；新增代码禁止直引宿主单元，gate `grep -R "uses.*SyncObjs|Classes|SysUtils"`）；`math/trig/scalar` 允许但仅纯函数 `inline` 调用，不引入运行时分配。
- 同层 `L2→L2` 仅允许 `io/fs/compress` 等已登记豁免，不引入 `crypto/compress` 越层；扩展 52（`codec.flac/mp3/vorbis`、`spatial/bus`、`bank/resource/playlist/event/studio`、`simd/pcm.simd`）当前 provisional 全量堆叠于 audio 内、L2 臃肿失高级感，已违反 L2 Owner 边界与四件套独立演进不变量，禁止继续膨胀，待抽独立 L2 模块：`nextpas.core.audio.codec.flac` / `mp3` / `vorbis`、`nextpas.core.audio.spatial`、`nextpas.core.audio.bus`、`nextpas.core.audio.bank`/`resource`/`playlist`/`event`/`studio`、`nextpas.core.simd`（`audio.simd/pcm.simd` 薄封装复用），抽离后 `audio` 仅保留 26 核心（高级感回归），`nextpas.core.audio.*` 候选将升为 `nextpas.core.<new>.*` 独立 L2，`L2→L2` 禁依赖，受控 seam 需 `module-registry` 登记 + gate。
- 四件套纪律：`*.base` 仅类型/常量/`inline` 函数，`*.intf` 仅接口 + GUID，`*.impl` 含实现，`*.pas` 仅 `type` 别名 + `inline` 转发零逻辑；`ffi` 禁止（L2 零 FFI）；候选域已守 `base←intf←impl←facade` 独立演进，具备抽离就绪条件（`bank/resource/event/spatial` 四件套 + `playlist` 四件套 + `codec.flac/mp3/vorbis` 四件套 + `bus` 四件套 + `studio.base/studio.pas`）。

---

## 6. 测试入口

```bash
bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh  # 78 文件：核心 26 冻结 + 扩展 52 四件套完整校验（含 codec.flac/mp3/vorbis 各 base/intf/impl 9 文件 + bank/resource/event/spatial.impl + playlist 四件套 + bus 四件套 + codec 3×3），无 ffi/vendor + 23 GUID(11+12,B前缀bus异形) + Probe≤4KB + 实时纪律 + test_automation
for g in test_base test_pcm_wav test_wav test_aiff test_meta test_registry \
         test_resample test_mix test_dsp test_device test_graph test_sfx test_game test_timeline \
         test_flac test_mp3 test_vorbis test_spatial test_bus test_bank test_resource test_playlist test_event test_studio test_automation; do
  make -C core/tests/nextpas.core.audio/$g clean test
done
make -C core/benchmarks/nextpas.core.audio/bench_pcm_wav clean bench  # -O2, 输出 ns/op + MB/s，GWrite 预分配 + Graph/Timeline/Bank 零分配快照
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
| test_graph 16 | 快照混音与双缓冲 |
| test_sfx 15 | SFX 池与窃取（canonical 0050） |
| test_game 15 | SFX 池与窃取（deprecated 兼容） |
| test_timeline 16 | 排序/声像/solo/mute/loop/Device 联动 |
| test_flac 12 | FLAC Probe≤4KB + 8/16/24-bit 全声道 + 零分配 |
| test_mp3 10 | MP3 Probe≤4KB + CBR 帧 + 异常不泄漏 |
| test_vorbis 9 | Vorbis Ogg Probe + VorbisComment 归一 |
| test_spatial 8 | 衰减/pan/doppler `inline` + 零分配 |
| test_bank 10 | Bank 深拷贝 + RefCount + 资源释放不丢 |
| test_resource 9 | AsyncLoad 去重 + ProbeFile≤4KB + Release 释放 |
| test_playlist 7 | Playlist 队列 + crossfade 占位 |
| test_event 11 | Event RTPC + MaxVoices 窃取 + 空间化 |
| test_studio 9 | Automation Hermite + Sequencer 正弦表 2048 |
| test_bus 8 | Bus/Mixer 零分配 + 快照 + SimdAddF32（B前缀 GUID 异形） |
| test_automation 8 | Automation Hermite 曲线 + FillRealtimeValues 零分配 |

全量 `~260 tests`（23 门：核心 13 + 扩展 10 含 bus+automation）且 `HEAPTRC OK` 为晋升 `focused-runtime` 必要条件；扩展候选门单独跑通即视为候选模块可抽离就绪。

---

## 7. Out of scope / Future

**已实现但标注为“扩展候选”（provisional 寄生，违反 L2 Owner 边界与四件套独立演进不变量，禁止在核心 26 内写成已冻结，L2 臃肿失高级感·必须抽独立 L2 模块）：**
- `codec.flac/mp3/vorbis` 纯 Pascal 解码已上线（`prFlac/prMp3/prOggVorbis` + `Probe≤4KB` + `registry` 可插拔，守 `bytes.ops` 单源 + `inline` 热点 + `Probe≤4KB` 零分配，`STUB: OpenStreaming` 已白名单），归 `L2 impl` 但当前 provisional 寄生于 audio，待抽为 `nextpas.core.audio.codec.flac` / `mp3` / `vorbis` 独立 L2 模块（各 `base/intf/impl/pas` 四件套，`base` L0 only + `intf` 仅别名 + `impl` 含 `Probe/DecodeWhole` + `facade` 仅 `type` 别名 + `inline` 转发）
- `spatial/bus/simd/pcm.simd`、`bank/resource/playlist`、`event`、`studio.*` 已实现，分别为 3D/总线、资源管理、事件、工程域，当前 provisional 全量堆叠于 audio 内已超出原 26 冻结，待抽独立 L2 模块：`nextpas.core.audio.spatial`（`spatial.base/intf/impl/pas` 四件套）、`nextpas.core.audio.bus`（`bus.base/intf/impl/pas` 四件套，B 前缀 GUID）、`nextpas.core.audio.bank`/`resource`/`playlist`/`event`/`studio`（各四件套）、`nextpas.core.simd`（`audio.simd/pcm.simd` 薄封装复用 owner `simd`，`bytes.ops` 单源 + `EnsureScratch inline` 零拷贝 + `SimdAddF32` 快照），`L2→L2` 禁依赖，抽离后 audio 仅保留 26 核心（高级感回归），四件套独立演进不变量在新模块延续

**当前仍 Out of scope（禁止写成已实现）：**
- 真实硬件后端（仅 `Null` 后端；`ALSA/CoreAudio/WASAPI` 后续）
- `IAudioDevice` 热迁移/自动重选
- Opus 单独编解码（当前 `prOggOpus` 仅占位）

**Future（需独立 slice + consumer，候选模块先行，缺能力先反哺 owner）：** 硬件后端、Sinc 质量扩展、Opus、Timeline 自动化曲线与 52 候选的正式拆分落地（`core/src/nextpas.core.audio.*` → `core/src/nextpas.core.<new>.*`：`audio.codec.flac/mp3/vorbis`、`audio.spatial/bus`、`audio.bank/resource/playlist/event/studio`、`simd`），拆分前 78 provisional 禁止继续膨胀，新域直接以独立 L2 模块立项。

---

## 8. 门禁与晋升

- `source-contract`：`check_source_contract.sh` 78 文件 provisional（核心 26 冻结 + 扩展 52 候选四件套完整，含 `codec.flac/mp3/vorbis` 各 `base/intf/impl` 9 文件 + `bank/resource/event/spatial` 四件套 + `playlist` 四件套 + `bus` 四件套 + `codec` 3×3 decoder/sse）`无ffi/vendor` + `23 GUID`（11 核心：0001/0002/0010/0011/0020/0021/0030/0040/0041/0042/0043/0050/0060 实 13 枚按域计 + 12 扩展：0051 spatial/0052 event/0053 bank/0054 resource/0070 studio/0071 project/0072 sequencer/0080 playlist/C00001 bus/C00002 mixer + 2 预留；B 前缀 bus 为异形与 A 前缀区分）+ `TAudioEncodeOptions before IAudioDecoder` + `实时纪律（FillRealtime）` + `Probe≤4KB` + 域文件存在性 + `test_automation` gate 存活；实盘 78 provisional（56 冻结 + 22 四件套完整：`bank.base/impl/resource.base/impl/event.base/impl/spatial.base/impl/playlist.base/intf/impl/studio.base/studio.pas` + `codec.flac/mp3/vorbis` 各 3 件套均守 `base←intf←impl←facade`）；52 候选 provisional 寄生违反 L2 Owner 边界与高级感，待抽独立 L2 后门禁将按 26 核心重计，当前扩展候选缺失按审计阈值 FAIL（WARN 仅限 bus.base/impl 豁免注释标注的过渡桩已收敛，抽离后移除）
- `focused-runtime`：`23 门 260 tests`（核心 13 + 扩展 10 含 test_bus/test_automation）全绿 + `HEAPTRC` 零泄漏 + `hygiene` 绿（当前 truth level provisional；扩展门单独统计，候选拆分前视为 provisional，拆分后核心 13 门为 truth）
- `bytes.ops 单源`：新增 codec/spatial/bus/simd 均复用 `bytes.ops/bytes.cursor/simd.dispatch`，禁止自写 `Move/SetLength` 重复实现（gate `grep -R "SetLength.*Data"` 需经 `AudioEnsure*`/`BytesEnsureCapacity` 封装）；`Probe≤4KB` 前缀零分配
- `inline/零拷贝`：`AudioBytesForFrames/AudioSilentFill/PanLawGains/FlacProbe/ComputeAttenuation/Doppler` 等热点 `inline`，`FillRealtime` 路径 `EnsureScratch/FSnap` 预分配 + `SimdAddF32` 零拷贝 `Move` 单源为 `bytes.ops` + `两阶段快照` + `snapshot mixing - lock free`，稳态 `SetLength` 零增长（gate 校验 `EnsureScratch` + `two-phase snapshot` + `snapshot mixing - lock free` + `inline;`）
- `稳定性`：所有 `Create` 配 `Destroy/FreeAndNil`，`Bank/Resource/Event/Playlist/Studio` 等 `Clear/Release` 必须 `SetLength(Data,0)` + 线程 `WaitFor/Free` 不泄漏，`try..finally` 释放不丢（`HEAPTRC` 校验；`device.null` `FScratch` 复用 + `InterlockedExchangeAdd64` + `bus` `IMutex` owner 隔离）
- `桩标注`：`codec.flac/mp3/vorbis OpenStreaming not implemented` 为已标注过渡桩，gate 以 `STUB: OpenStreaming` 注释白名单放行（抽离后随新模块迁移）；`sfx resample todo` 已收敛为显式错误分支（`EAudioGraphError`），禁止裸 `todo` 残留
- 禁止以 `focused-runtime` 冒充 `ci-matrix`；跨 host 未证明前不晋升。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首次冻结：对齐 26 单元 + 11 GUID + 双平面纪律 + Probe≤4KB + 180 用例门禁 |
| 2026-09-02 | 1.1 | 增量冻结：核心 26 不变，扩展 28 标注为可抽新模块候选（codec.flac/mp3/vorbis/spatial/bank/resource/playlist/event/studio/bus/simd/pcm.simd），source-contract 扩展至 54 文件，业务以 CONTRACT 为准、缺能力先反哺 owner |
| 2026-09-02 | 1.2 | 实盘对齐：56 文件（核心 26+扩展 30，含 bus.base/impl + codec 3×3），23 GUID（11 核心+12 扩展，B 前缀 bus 异形），260 tests（23 门含 test_automation），OpenStreaming 桩显式标注 + sfx resample todo 收敛 |
| 2026-09-02 | 1.3 | 四件套按需补齐：56→65 文件（新增 `bank.base/resource.base/event.base/spatial.base` + `playlist.base/intf/impl` 四件套 + `studio.base/studio.pas` 聚合门面），`bank/resource/event/spatial` `intf` 已纯化为别名、`playlist` 已 `base←intf←impl←facade` 完整拆分、`studio.pas` 聚合 `automation/sequencer/project`，`source-contract` 仍以 56 为冻结阈值，新增按需存在豁免；23 GUID 不变 |
| 2026-09-02 | 1.4 | 四件套完整：65→69 文件（新增 `bank.impl/resource.impl/event.impl/spatial.impl` 闭环四件套），`bank/resource/event/spatial` 均 `base←intf←impl←facade` 完整，`check_source_contract.sh` 枚举同步 69 文件（26+43），B 前缀 bus 异形 + 23 GUID 不变，门禁与文档同步收敛 |
| 2026-09-02 | 1.5 | codec 四件套完整：69→78 文件（新增 `codec.flac/mp3/vorbis` 各 `base/intf/impl` 9 文件），三 codec 均 `base←intf←impl←facade` 完整（`base` L0 only 仅常量 + `intf` 仅 `IAudioDecoder` 别名 + `impl` 含 `Probe/DecodeWhole/OpenStreaming STUB` + `facade` 仅 `type` 别名 + `inline` 转发），`registry` 薄封装仅依赖 `codec.intf` 工厂（不在 `registry.impl` 硬 `uses` 各 codec.impl），实盘 78 = 26 core + 52 ext（unique 76+2 bus facade），23 GUID 不变 |
| 2026-09-02 | 1.5.1 | 匠心修复：52 扩展候选仍寄生 audio、L2 臃肿失高级感，违反 Owner 边界与四件套独立演进不变量；头图重写为 26 冻结 + 52 候选 provisional，78 全量堆叠标注待抽独立 L2 模块（`audio.codec.flac/mp3/vorbis` / `spatial` / `bus` / `bank`/`resource`/`playlist`/`event`/`studio` / `simd`），抽离后 audio 回归 26 核心；补 `bytes.ops` 单源 + `inline/零拷贝`（`EnsureScratch/FSnap/SimdAddF32`）+ `稳定性`（`SetLength+FreeAndNil/WaitFor/try..finally`）证据，业务以 CONTRACT 为准、缺能力先反哺 owner；门禁 78 provisional 标注，无新增堆叠 |
