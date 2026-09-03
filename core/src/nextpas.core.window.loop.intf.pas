unit nextpas.core.window.loop.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.loop.base;

type
  IWindowLoop = interface
    ['{A1B2C3D4-1001-4F60-9A8B-C0D1E2F3A100}']
    function Tick: TWindowLoopTickResult;
    function IsRunning: Boolean;
    procedure RequestExit;
    function GetOptions: TWindowLoopOptions;
    procedure SetOptions(const AOptions: TWindowLoopOptions);
    property Options: TWindowLoopOptions read GetOptions write SetOptions;
  end;

  TWindowLoopTickHandler = reference to procedure(const AResult: TWindowLoopTickResult);
  TWindowLoopTickMethod = procedure(const AResult: TWindowLoopTickResult) of object;
  TWindowLoopTickProc = procedure(const AResult: TWindowLoopTickResult);

implementation

end.
