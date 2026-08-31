unit nextpas.core.audio.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.audio.base;

type
  { ---- 流式拉取面 ----
    两级契约分离实时能力（FPC 单继承，一级派生）：
    - IAudioSource：离线可用，Fill 允许分配/锁/IO（文件流式源、网络流）
    - IRealtimeAudioSource：追加实时纪律，设备只能接这个。
      【调用纪律】实时执行路径（图执行器/设备回调）只准调用 FillRealtime，
      绝不允许触达继承来的 Fill；该纪律写入本注释与本单元的 source-contract gate。
      实时路径仅调 FillRealtime。
    Fill 预分配不变量（两级共同遵守）：
      调用方保证 Length(ABuffer.Data) >= AFrames * ABuffer.Format.BlockAlign；
      违反时离线路径抛 EArgumentError；实时路径 clamp 到容量并递增独立的
      ContractViolationCount（不与 underrun 计数混用，遥测分离）。
    返回值语义（冻结）：>=0 实际填充帧数；0 仅表示源干净耗尽(EOF)；
      失败不在返回值表达——离线抛异常，实时侧零填静音+原子计数。
  }
  IAudioSource = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000010}']
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    property Format: TAudioFormat read GetFormat;
  end;

  IRealtimeAudioSource = interface(IAudioSource)
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000011}']
    { 实现承诺：FillRealtime 不 GetMem/不加锁/不做 IO/不抛异常。
      欠料返回语义（冻结）：内部补静音、照常返回 AFrames；
      只有源干净耗尽后才可能返回 0。欠料事实经原子 UnderrunCount 上报，
      连续越限再发 devUnderrun 事件。}
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

  { ---- 转换面 ---- }
  IAudioResampler = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000020}']
    function Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
  end;

  IAudioConverter = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000021}']
    function Convert(const AInput: TAudioBuffer;
      const ATarget: TAudioFormat): TAudioBuffer;
  end;

  { ---- DSP 处理面 ---- }
  IAudioProcessor = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000030}']
    function LatencyFrames: Integer;
    procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
    procedure Reset;
  end;

implementation

end.
