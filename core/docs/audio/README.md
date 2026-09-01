# nextpas.core.audio

L2 音频子系统（decode-first，接口化）：以 `TAudioBuffer/TAudioSource` 为统一货币，覆盖**容器编解码 / PCM / DSP / 设备 / 图 / SFX / 时间线**七域（`SFX` 为 canonical，`game` 仅 `game.pas` deprecated 薄转发，无独立 `game.intf` 按需存在），纯 Pascal 可替换，实时路径零分配。

> 设计权威：[`DESIGN.md`](./DESIGN.md)（Draft v3）—— 分层、双平面线程模型、域级 `intf` 冻结、PR Plan 与线程纪律见该文档。
> 运行时契约：`core/tests/nextpas.core.audio/test_base/check_source_contract.sh` 为 gate 真值源。

## 模块定位与分层

| 域 | 单元 | 职责 | 依赖 |
|---|---|---|---|
| **base** | `audio.base` | 统一货币 `TAudioFormat/TAudioBuffer/TAudioClock/TAudioTags/TAudioDeviceInfo`，`ChannelMask` 为真值源，`BlockAlign/ByteRate/FramesForMs` | L0 only |
| **intf** | `audio.intf` | 共享面 `IAudioSource(0010)/IRealtimeAudioSource(0011)/IAudioResampler(0020)/IAudioConverter(0021)/IAudioProcessor(0030)` | base |
| **codec** | `codec.intf/codec.wav/codec.aiff/codec.meta/codec.registry` | `IAudioDecoder(0001)/IAudioEncoder(0002)`，Probe ≤4KB，`DecodeWhole/Streaming`，ID3v2/Vorbis/RIFF INFO 归一，registry 可插拔（已预留 FLAC/MP3 由 `music888` 吸收） | base+intf |
| **pcm** | `audio.pcm` | 纯函数 `U8/S16/S24/S32↔F32`、`Clamp`、`Interleave/Deinterleave`，`TBytes` 货币，`TPDF` 抖动 | base |
| **resample/mix/dsp** | `resample/resample.sinc/mix/dsp.filters/dsp.dynamics/dsp.fft` | 线性重采样、Kaiser-sinc（Bessel I0）、`MixInto/ApplyGain/Normalize`、Biquad(TDF-II)/Compressor/Limiter、FFT/Hann | base+intf |
| **device** | `device.intf/device.null` | `IAudioDevice(0040)/IAudioDeviceProvider(0041)`，`dsClosed/Opened/Started`，MPSC `TDeviceEvent`，`InterlockedExchangeAdd64` 计数 `Underrun/Violation`，`Drive` 调 `FillRealtime` | base+intf |
| **graph/player** | `graph.intf/graph/player` | `IAudioGraph(0042)/IAudioPlayer(0043)`，快照混音 `gain*volume` + clamp，处理器链双缓冲 ping-pong | device |
| **sfx** | `sfx.intf/sfx` | `ISfxAudio(0050)` canonical，`Load/Play/StopVoice/MasterGain`，音色池 `MaxVoices` 窃取，pitch/pan/loop，`LoadFromFile` 经 `PcmConvert` | graph+device |
| **game** | `game` | `IGameAudio(0050)` deprecated 薄转发（`TGameSfxId=TSfxId` 等别名在 `sfx.intf`，game 无独立 intf 按需存在）→ `sfx` | sfx wrapper |
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

// 7. SFX 音频（音色池，pitch/pan/loop，窃取策略；game 为 deprecated 薄转发）
var SfxMgr: ISfxAudio; Sfx: TSfxId; Voice: TVoiceId;
SfxMgr := CreateSfxAudioForFormat(Prov, AudioFormatCreate(48000,2,sfF32), 32);
Sfx := SfxMgr.Load(Buf); Voice := SfxMgr.Play(Sfx, 1.0, 0, 1.0, False);
// deprecated 兼容：IGameAudio/CreateGameAudio* 仍可用，但请迁移至 ISfxAudio/CreateSfxAudio*

// 8. 时间线（排序混音，solo/mute/loop，Device 联动）
var TL: IAudioTimeline; Tr: TTimelineTrackId;
TL := CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
Tr := TL.AddTrack(1.0); TL.AddClip(Tr, Buf, 0); TL.Loop := True;
Dev.SetSource(TL as IRealtimeAudioSource); // Timeline 即 IRealtimeAudioSource
```

## 测试与门禁

23 门合计 **260 tests**，全量 `HEAPTRC OK`（`sfx` 为 canonical 0050，`game` 为 deprecated 兼容；扩展 10 门含 bus/spatial/bank/resource/playlist/event/studio/automation + flac/mp3/vorbis）：

```bash
for g in test_base test_pcm_wav test_wav test_aiff test_meta test_registry \
         test_resample test_mix test_dsp test_device test_graph test_sfx test_game test_timeline \
         test_flac test_mp3 test_vorbis test_spatial test_bus test_bank test_resource test_playlist test_event test_studio test_automation; do
  make -C core/tests/nextpas.core.audio/$g clean test
done
bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh # 69 文件（核心26+扩展43 四件套完整）无 ffi/vendor + 23 GUID(11+12 B前缀bus异形) + 实时纪律 + test_automation
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
| test_sfx 15 | SFX 池与窃取（canonical 0050） |
| test_game 15 | SFX 池与窃取（deprecated 兼容，薄转发） |
| test_timeline 16 | 排序/增益声像/solo/mute/loop/Device 联动 |
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

## 基准

```bash
make -C core/benchmarks/nextpas.core.audio/bench_pcm_wav clean bench # 输出 ns/op 与 MB/s -O2, HEAPTRC 关
```

`bench_pcm_wav` 8 项：`Parse/64KB 13µs / Parse/1MB 1.7ms / Write/1MB 997µs CV9% / Graph/1K 19µs / Graph/4K 77µs / Timeline/1K 8µs / TimelineLoop/1K 12µs / Device.Drive/1K 13µs`（`GWrite*` 预分配，`Graph/Timeline` 零分配快照）。

## 演进与复用

- **已完成**：PR1 base → PR2 wav → PR3 aiff/meta/registry → PR5 resample/mix/dsp → PR6 device → PR7 graph/player → PR8 sfx（`game` 保留为 deprecated 薄转发）→ PR9 timeline
- **已推迟**：PR4 flac/mp3 纯 Pascal（`music888` 已有实现，后续吸收进 `codec.registry`，保持 `Probe≤4KB` 与可插拔）
- **复用度**：`codec.registry` 可插拔、`IAudioTimeline` 即 `IRealtimeAudioSource` 可直连 `Device`/`Graph`，`SFX` 复用 `Graph` 快照路径（`PanLawGains`/`CAudioSqrt2` 共用）
- **稳定性**：`EAudioError` 统一、`HEAPTRC` 零泄漏、`InterlockedExchangeAdd64` 计数、`FillRealtime` 零分配与异常静音

## 参见

- `core/src/nextpas.core.audio.*` — 实现
- `core/tests/nextpas.core.audio/test_base/check_source_contract.sh` — 冻结门禁
- `core/benchmarks/nextpas.core.audio/bench_pcm_wav` — 基准示例
