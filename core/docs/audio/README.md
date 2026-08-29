# nextpas.core.audio

L2 音频子系统（decode-first，接口化）：以 `TAudioBuffer/TAudioSource` 为统一货币，覆盖**容器编解码 / PCM / DSP / 设备 / 图 / 游戏 / 时间线**七域，纯 Pascal 可替换，实时路径零分配。

> 设计权威：[`DESIGN.md`](./DESIGN.md)（Draft v3）—— 分层、双平面线程模型、域级 `intf` 冻结、PR Plan 与线程纪律见该文档。
> 运行时契约：`core/tests/nextpas.core.audio/test_base/check_source_contract.sh` 为 gate 真值源。

## 模块定位与分层

| 域 | 单元 | 职责 | 依赖 |
|---|---|---|---|
| **base** | `audio.base` | 统一货币 `TAudioFormat/TAudioBuffer` + `AudioBytesForFrames/AudioIsValidBuffer/AudioValidateBuffer` 校验 DRY + `AudioSilentFill/AudioFillMemoryRealtime` 实时真值 | L0 only |
| **intf** | `audio.intf` | 共享面 `IAudioSource(0010)/IRealtimeAudioSource(0011)/IAudioResampler(0020)/IAudioConverter(0021)/IAudioProcessor(0030)` | base |
| **simd** | `audio.simd` | `SimdAdd/Mul/Peak/SumSquares/ClampF32` 全 4-wide 真 SSE2（x86_64 `ASMMODE INTEL` 硬件、`cpuid` 诚实、`aarch64 NEON`），`AudioSimdCaps` | base |
| **codec** | `codec.intf/codec.wav/codec.aiff/codec.meta/codec.registry` | `IAudioDecoder(0001)/IAudioEncoder(0002)`，Probe ≤4KB，`DecodeWhole/Streaming`，ID3v2/Vorbis/RIFF INFO 归一，registry 可插拔（已预留 FLAC/MP3 由 `music888` 吸收） | base+intf |
| **pcm** | `audio.pcm` | 纯函数 `U8/S16/S24/S32↔F32`、`Clamp`、`Interleave/Deinterleave`，`TBytes` 货币，`TPDF` 抖动 | base |
| **resample/mix/dsp** | `resample/resample.sinc/mix/dsp.filters/dsp.dynamics/dsp.fft` | 线性重采样、Kaiser-sinc（Bessel I0 预计算窗口缓存 + 溢出守卫）、`MixInto/ApplyGain/Normalize`、Biquad(TDF-II)/Compressor/Limiter、FFT/Hann | base+intf |
| **device** | `device.intf/device.null` | `IAudioDevice(0040)/IAudioDeviceProvider(0041)`，`dsClosed/Opened/Started`，MPSC `TDeviceEvent`，`InterlockedExchangeAdd64` 计数 `Underrun/Violation`，`Drive` 调 `FillRealtime` | base+intf |
| **graph/player** | `graph.intf/graph/player` | `IAudioGraph(0042)/IAudioPlayer(0043)`，快照混音 `gain*volume` + clamp，处理器链双缓冲 ping-pong | device |
| **game** | `game.intf/game` | `IGameAudio(0050)`，`Load/Play/StopVoice/MasterGain`，音色池 `MaxVoices` 窃取，pitch/pan/loop，`LoadFromFile` 经 `PcmConvert` | graph+device |
| **timeline** | `timeline.intf/timeline` | `IAudioTimeline(0060)`，`Track/Clip` 排序混音，`solo/mute/loop`，快照化 `FillRealtime` | base+intf |
| **errors** | `audio.errors` | `EAudioError(EIOError)→Decode/Encode/Device/Graph/Timeline` | errors |
| **门面** | `audio.pas` | 仅 `type` 别名 + `inline` 转发，零逻辑 | 聚合以上 |

> L2 约束：只依赖 `L0-L1`，禁止 `ffi/vendor/miniaudio`（由 source-contract 冻结）。

## 实时纪律（双平面线程模型）

```pascal
// 实时线程（Audio Thread）—— 仅调 FillRealtime，禁止分配/锁/IO/异常
function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;

// 控制面（UI/逻辑线程）—— AddTrack/AddClip/SetGain 等可分配可锁
```

- `IAudioSource.Fill` 为便利转发，内部直调 `FillRealtime`
- `Timeline.FillRealtime`：快照化（锁内仅拷 `Position/Loop/Duration` 与存活轨，混音无锁），立体声/单声道热点展开，`Pan=(TrackPan+ClipPan)/2` → `L/R=cos/sin*1.414`，`clamp`
- `Graph.FillRealtime`：快照节点/处理器，单 `scratch` 复用（每节点零分配），处理器链双缓冲 `SwapBuf` 交换
- `Device.Null.Drive`：`FScratch` 复用，稳态零堆增长；`FillRealtime` 异常则 `devDeviceError` 并静音，连续 5 次欠载报 `devUnderrun`
- 契约注释 `实时路径仅调 FillRealtime` 在 `audio.intf` 冻结，gate 强校验

## 统一货币

```pascal
TAudioFormat.IsValid  // [8000..192000]Hz, [1..8]ch, sfU8..sfF32
TAudioFormat.BlockAlign // Channels * BytesPerSample
TAudioFormat.ByteRate   // Int64(SampleRate)*BlockAlign
TAudioBuffer // Data: TBytes, Length = FrameCount*BlockAlign, sfF32 为混音 canonical
TAudioClock.ToDurationNs // 调度面唯一时间换算
```

`ChannelMask` 为真值源（`WAVEFORMATEXTENSIBLE` 位），`ChannelLayout` 仅为便捷提示，可经 `AudioChannelMaskForLayout/AudioChannelLayoutForMask` 互转。

## 错误模型

```pascal
EAudioError(EIOError)
├─ EAudioDecodeError  // 容器解析 / 格式不支持
├─ EAudioEncodeError
├─ EAudioDeviceError  // Start/FormatMismatch/unknown id
├─ EAudioGraphError   // AddSource nil / format mismatch
└─ EAudioTimelineError// invalid buffer / format mismatch / unknown track
```

直线代码默认抛异常，边界统一捕获；`TryXxx` 仅在需分支时提供。

## 快速开始

```pascal
uses nextpas.core.audio; // 门面：别名 + inline 转发，零逻辑

// 1. 格式与缓冲
var Fmt: TAudioFormat; Buf: TAudioBuffer;
begin
  Fmt := AudioFormatCreate(48000, 2, sfF32);
  Assert(Fmt.IsValid);
  // BlockAlign=8, ByteRate=384000, FramesForMs(1000)=48000
end;

// 2. PCM 互转（纯函数，无状态）
PcmF32ToS16(0.5);  // → SmallInt
PcmS16ToF32(16384);

// 3. 容器编解码（Probe≤4KB，自动注册 wav+aiff）
var Tags: TAudioTags; DecBuf: TAudioBuffer;
if TryDecodeWholeFile('/tmp/a.wav', DecBuf, Tags) then
  AudioEncodeWav(DecBuf, '/tmp/b.wav');
if AudioDetectProbe(Prefix) = prWav then ...

// 4. DSP / 重采样 / 混音
var OutBuf := AudioResampleLinear(InBuf, 44100);
MixInto(Dst, Src, 0.5, 0); ApplyGain(Buf, 0.8);
var Q := TBiquad.CreateLowpass(48000, 1000, 0.707); Q.Process(...);
FFT(Re, Im); // IsPowerOfTwo 校验

// 5. 设备（Null 后端，MPSC 事件，Drive 驱动 FillRealtime）
var Prov: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource;
Prov := CreateNullAudioProvider;
Dev := Prov.CreateDefaultDevice(AudioFormatCreate(48000, 2, sfF32));
Dev.SetSource(Src); Dev.Start; Dev.Drive(512); Dev.PollEvent(Evt);

// 6. 图与播放器（快照混音，处理器链）
var Graph: IAudioGraph; Player: IAudioPlayer;
Graph := CreateAudioGraph(AudioFormatCreate(48000, 2, sfF32));
Graph.AddSource(Src, 1.0); Graph.AddProcessor(MyFX);
Player := CreateAudioPlayer(Dev, Graph); Player.Play; Player.Volume := 0.5;

// 7. 游戏音频（SFX 池，pitch/pan/loop，窃取策略）
var Game: IGameAudio; Sfx: TGameSfxId; Voice: TGameVoiceId;
Game := CreateGameAudioForFormat(Prov, AudioFormatCreate(48000,2,sfF32), 32);
Sfx := Game.Load(Buf); Voice := Game.Play(Sfx, 1.0, 0, 1.0, False);

// 8. 时间线（排序混音，solo/mute/loop，Device 联动）
var TL: IAudioTimeline; Tr: TTimelineTrackId;
TL := CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
Tr := TL.AddTrack(1.0); TL.AddClip(Tr, Buf, 0); TL.Loop := True;
Dev.SetSource(TL as IRealtimeAudioSource); // Timeline 即 IRealtimeAudioSource
```

## 测试与门禁

20 门合计 **230+ tests**，全量 `HEAPTRC OK`：

```bash
for g in pcm_wav wav aiff meta base registry flac mp3 vorbis resample mix dsp \
         device graph game timeline playlist spatial studio automation; do
  make -C core/tests/nextpas.core.audio/test_$g clean test
done
bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh # 44 文件无 ffi/vendor + GUID + 实时纪律
make hygiene && git diff --check
```

| Gate | 用例 | 要点 |
|---|---|---|
| test_base 20 | 格式算术/掩码/时钟/Buffer/PCM/Errors/门面 |
| test_pcm_wav 12 | 兼容壳回归（八拒四正） |
| test_wav 16 | wav 8..32 位 + float + extensible 5.1/7.1 + fact/bext/rf64 |
| test_aiff 11 | aiff/aifc + 80-bit Extended80 + ssnd offset |
| test_meta 11 | ID3v2/Vorbis/RIFF INFO/MergeTags |
| test_registry 9 | Probe 探测与可插拔注册 |
| test_resample 14 | 线性/sinc 零分配与质量分级 |
| test_mix 11 | MixInto/增益/归一/pan law |
| test_dsp 14 | Biquad(TDF-II)/Compressor/Limiter/FFT |
| test_device 15 | Null MPSC 与 Drive/Underrun |
| test_graph 16 | 快照混音与处理器链双缓冲 |
| test_game 15 | SFX 池与窃取 |
| test_timeline 16 | 排序/增益声像/solo/mute/loop/Device 联动 |

## 基准

```bash
make -C core/benchmarks/nextpas.core.audio/bench_pcm_wav clean bench # ns/op + MB/s
```

`bench_pcm_wav / bench_mix / bench_graph / bench_timeline` 均基于 `IBenchContext`，覆盖编解码与混音 `FillRealtime` 热路径（`-O2`，HEAPTRC 关），已升级为 **真 SSE2 硬件路径**（`SimdAdd/Mul/Peak/SumSquares/Clamp` 全 4-wide，x86_64 `ASMMODE INTEL` / `movups/mulps/addps/maxps/minps`，`AudioSimdCaps` 经 `cpuid leaf1/7` 诚实探测，`aarch64 NEON True`），标量尾循环兜底，bench 验证与 gate 同源。

## 演进与复用

- **已完成**：PR1 base → PR2 wav → PR3 aiff/meta/registry → PR5 resample/mix/dsp → PR6 device → PR7 graph/player → PR8 game → PR9 timeline
- **已推迟**：PR4 flac/mp3 纯 Pascal（`music888` 已有实现，后续吸收进 `codec.registry`，保持 `Probe≤4KB` 与可插拔）
- **复用度**：`codec.registry` 可插拔、`IAudioTimeline` 即 `IRealtimeAudioSource` 可直连 `Device`/`Graph`，`Game` 复用 `Graph` 快照路径
- **稳定性**：`EAudioError` 统一、`HEAPTRC` 零泄漏、`InterlockedExchangeAdd64` 计数、`FillRealtime` 零分配（`device.null` 预分配 1M、`bus/graph` 双缓冲）/溢出守卫 `AudioBytesForFrames>High(Integer)` 全链路/异常静音 `AudioSilentFill`
- **复用与性能**：`pcm.simd` 块转换 4-wide 展开（`PcmConvertBlockS16/S32↔F32`），`pcm.PcmConvert` 热点 `S16/S32↔F32` 4-wide 快 path 零分支（`PSingle` 直访），`SimdAdd/Mul/Peak/SumSquares/Clamp` 硬件化复用于 `mix/timeline/graph/bus/playlist`，`mix.ApplyGainRamp` 增量步进替代每样本除法，`spatial/timeline` 立体声 4-wide `LL/LR` 展开对齐，`dsp.filters` Biquad `LBiquads/LBase` 缓存化消除 `High()/Length()` 热路径开销，`bus` `FillRealtime/MixRealtime` `FScratch` 按需 `SetLength` 自适应（稳态零分配，异常才扩容），`resample` 线性增量 `PSingle` 直访 + `sinc` Kaiser 窗预计算，`bank` 单次 `SetLength` 打包 + `WriteLE32/LE32` 对称复用，`sequencer` 音符 `Inc/Vel` 零分配缓存，`mix.PanLawGains` 复用 `AudioPanLawGains` 单点声像律（`CAudioPanLawUnity`）消除重复，`base` 校验/填充单真相

## 参见

- `core/src/nextpas.core.audio.*` — 实现
- `core/tests/nextpas.core.audio/test_base/check_source_contract.sh` — 冻结门禁
- `core/benchmarks/nextpas.core.audio/bench_pcm_wav` — 基准示例
