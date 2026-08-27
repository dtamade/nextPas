# nextpas.core.audio

L2 音频子系统（decode-first，接口化）：以 `TAudioBuffer/TAudioSource` 为统一货币，覆盖容器编解码 / DSP / 设备 / 图 / 时间线五域。

> 设计权威：[`DESIGN.md`](./DESIGN.md)（Draft v3）—— 分层、双平面线程模型、域级 intf 冻结、纯 Pascal 可替换性、PR Plan 见该文档。

## 模块定位

- **base**：统一货币 `TAudioFormat/TAudioBuffer/TAudioClock/TAudioTags` 等值类型，`ChannelMask` 为真值源
- **intf**：跨域共享面 `IAudioSource/IRealtimeAudioSource/IAudioResampler/IAudioConverter/IAudioProcessor`
- **codec**：编解码域 `IAudioDecoder/IAudioEncoder`（Probe ≤4KB、DecodeWhole/Streaming、Tags）
- **pcm**：纯函数 sample 格式互转（U8/S16/S24/S32↔F32，TPDF dither）、交织/平面、Clamp
- **errors**：`EAudioError(EIOError)` 异常树
- **门面**：`nextpas.core.audio` 仅 type 别名 + inline 转发 + 空注册表占位，零逻辑

PR1 仅交付上述 base 层；`device/graph/timeline` 域 intf 分别在 PR6/PR7/PR9 落位。

## 现有兼容层

`nextpas.core.audio.pcm_wav.pas` 为旧 WAV 函数的兼容壳（PR2 才重构为 `codec.wav`，当前保持八拒四正十二用例不变）。

## 入口速览（PR1 后）

```pascal
uses
  nextpas.core.audio,        // 门面：别名 + inline 转发
  nextpas.core.audio.base,   // 值类型
  nextpas.core.audio.intf,   // 共享接口
  nextpas.core.audio.codec.intf; // Codec 域

var
  LFmt: TAudioFormat;
  LBuf: TAudioBuffer;
begin
  LFmt := AudioFormatCreate(44100, 2, sfS16);
  Check(LFmt.IsValid);
  // BlockAlign = 4, ByteRate = 176400, FramesForMs(1000) = 44100
end;
```

## 测试

```bash
make -C core/tests/nextpas.core.audio/test_base clean test   # PR1 基座：格式算术/掩码/时钟
make -C core/tests/nextpas.core.audio/test_pcm_wav clean test # 十二用例（八拒四正）回归
bash core/tests/nextpas.core.audio/test_base/check_source_contract.sh # source-contract gate
```

## PR Plan

见 `DESIGN.md §10`：PR1 base-foundation → PR2 wav-rework → PR3 aiff/meta/registry → PR4 flac-pure → PR5 resample/mix/dsp → PR6 device → PR7 graph/player → PR8 game → PR9 timeline → PR10 editor → PR11 FFI codecs。
