unit nextpas.core.audio.device.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TDeviceState = (dsClosed, dsOpened, dsStarted);

  TDeviceEvent = record
    Kind: TDeviceEventKind;
    DeviceID: string;
    Message: string;
    Position: TAudioClock;
  end;

  TAudioDeviceInfoArray = array of TAudioDeviceInfo;
  TDeviceEventArray = array of TDeviceEvent;

  IAudioDevice = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000040}']
    function GetInfo: TAudioDeviceInfo;
    function GetFormat: TAudioFormat;
    function GetState: TDeviceState;
    function GetPosition: TAudioClock;
    function GetUnderrunCount: UInt64;
    function GetContractViolationCount: UInt64;
    function PollEvent(out AEvent: TDeviceEvent): Boolean;
    procedure SetSource(const ASource: IRealtimeAudioSource);
    function Start: Boolean;
    function Stop: Boolean;
    function Drive(AFrames: Integer): Integer;
    property Info: TAudioDeviceInfo read GetInfo;
    property Format: TAudioFormat read GetFormat;
    property State: TDeviceState read GetState;
  end;

  IAudioDeviceProvider = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000041}']
    function Enumerate: TAudioDeviceInfoArray;
    function GetDefault: TAudioDeviceInfo;
    function CreateDevice(const AID: string; const AFormat: TAudioFormat): IAudioDevice;
    function CreateDefaultDevice(const AFormat: TAudioFormat): IAudioDevice;
  end;

implementation

end.
