unit nextpas.core.audio.bank.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TAudioBankId = Integer;
  TBankVoiceId = Integer;

  TBankPlayParams = record
    Gain: Single;
    Pan: Single;
    Pitch: Single;
    Loop: Boolean;
    class function Default: TBankPlayParams; static;
  end;

  { IAudioBank - SoundBank 预加载容器，预加载多个 TAudioBuffer（deep copy），
    引用计数管理，支持按名称/Id 查询，与 sfx/event 共享 FillRealtime discipline，
    继承 IRealtimeAudioSource 以直连 Device/Graph. GUID 0053 分配。 }
  IAudioBank = interface(IRealtimeAudioSource)
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000053}']
    function GetFormat: TAudioFormat;
    function GetCount: Integer;
    function FindByName(const AName: string): TAudioBankId;
    function TryGetBuffer(AId: TAudioBankId; out ABuffer: TAudioBuffer): Boolean;
    function GetRefCount(AId: TAudioBankId): Integer;
    function Add(const AName: string; const ABuffer: TAudioBuffer): TAudioBankId;
    function AcquireRef(AId: TAudioBankId): Integer;
    function ReleaseRef(AId: TAudioBankId): Integer;
    function Remove(AId: TAudioBankId): Boolean;
    procedure Clear;
    function Play(AId: TAudioBankId): TBankVoiceId; overload;
    function Play(AId: TAudioBankId; AGain: Single; APan: Single = 0; APitch: Single = 1.0; ALoop: Boolean = False): TBankVoiceId; overload;
    function Play(AId: TAudioBankId; const AParams: TBankPlayParams): TBankVoiceId; overload;
    function StopVoice(AVoice: TBankVoiceId): Boolean;
    procedure StopAll;
    function VoiceCount: Integer;
  end;

implementation

class function TBankPlayParams.Default: TBankPlayParams;
begin
  Result.Gain := 1.0;
  Result.Pan := 0.0;
  Result.Pitch := 1.0;
  Result.Loop := False;
end;

end.
