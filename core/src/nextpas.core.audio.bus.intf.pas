unit nextpas.core.audio.bus.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.bus.base;

type
  IAudioBus = interface
    ['{B1A2B3C4-D5E6-7890-ABCD-C00000000001}']
    function GetId: TAudioBusId;
    function GetGain: Single;
    procedure SetGain(AGain: Single);
    function GetFormat: TAudioFormat;
    function GetSource: IRealtimeAudioSource;
    property Id: TAudioBusId read GetId;
    property Gain: Single read GetGain write SetGain;
    property Format: TAudioFormat read GetFormat;
  end;

  IAudioBusMixer = interface
    ['{B1A2B3C4-D5E6-7890-ABCD-C00000000002}']
    function CreateBus(const AFormat: TAudioFormat): IAudioBus;
    function GetBus(AId: TAudioBusId): IAudioBus;
    function BusCount: Integer;
    function MixRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

implementation

end.
