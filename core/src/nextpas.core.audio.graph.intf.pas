unit nextpas.core.audio.graph.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf;

type
  TGraphState = (gsStopped, gsPlaying, gsPaused);

  IAudioGraph = interface(IRealtimeAudioSource)
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000042}']
    function GetState: TGraphState;
    function GetFormat: TAudioFormat;
    function NodeCount: Integer;
    function AddSource(const ASource: IRealtimeAudioSource; AGain: Single = 1.0): Integer;
    function RemoveSource(AId: Integer): Boolean;
    function SetGain(AId: Integer; AGain: Single): Boolean;
    function AddProcessor(const AProcessor: IAudioProcessor): Integer;
    function RemoveProcessor(AId: Integer): Boolean;
    procedure Clear;
    property State: TGraphState read GetState;
  end;

  IAudioPlayer = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000043}']
    function GetGraph: IAudioGraph;
    function GetDevice: IAudioDevice;
    function GetState: TGraphState;
    function GetPosition: TAudioClock;
    function Play: Boolean;
    function Pause: Boolean;
    function Stop: Boolean;
    function Seek(AFrame: UInt64): Boolean;
    function SetVolume(AVolume: Single): Boolean;
    function GetVolume: Single;
    function PollEvent(out AEvent: TDeviceEvent): Boolean;
    property Graph: IAudioGraph read GetGraph;
    property Device: IAudioDevice read GetDevice;
    property State: TGraphState read GetState;
  end;

implementation

end.
