unit nextpas.core.audio.codec.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  { ---- 编码选项（先于使用它的接口声明）---- }
  TAudioEncodeOptions = record
    SampleFormat: TAudioSampleFormat;  // WAV: sfS16/sfS24/sfF32 合法
    ApplyDither: Boolean;              // 降位深时的 TPDF dither
  end;

  IAudioDecoder = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000001}']
    { Probe 输入预算：≤4KB 文件前缀（业界通行量级）。
      一级容器嗅探与二级 codec 识别共用此入口：
      registry 用前缀判容器；命中 Ogg 类容器时 registry 把同一更大前缀
      再次交给该容器 decoder 的 Probe 做二级识别（registry 自身不带格式知识）。}
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

  IAudioEncoder = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000002}']
    { v1 唯一实现 = WAV（codec.wav）。有损编码后续版本扩展：
      per-format 工厂 + 扩展选项(BitRate/Quality)，注册表 encode 侧同步开放。 }
    procedure Encode(const ABuffer: TAudioBuffer; const ADest: IStream;
      const AOptions: TAudioEncodeOptions);
  end;

{ TryDecodeWhole 为便利层函数（非接口方法），声明于 codec.registry 单元的
  interface 函数段：

  function TryDecodeWhole(ADecoder: IAudioDecoder; const AStream: IStream;
    out ABuffer: TAudioBuffer): Boolean;

  需要分支的调用方专用；主路径抛 EAudioDecodeError。 }

implementation

end.
