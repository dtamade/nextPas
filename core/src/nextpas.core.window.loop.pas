unit nextpas.core.window.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.loop.base,
  nextpas.core.window.loop.intf,
  nextpas.core.window.loop.impl;

type
  TWindowLoopOptions = nextpas.core.window.loop.base.TWindowLoopOptions;
  TWindowLoopTickResult = nextpas.core.window.loop.base.TWindowLoopTickResult;
  EWindowLoopError = nextpas.core.window.loop.base.EWindowLoopError;
  EWindowLoopInvalidOptions = nextpas.core.window.loop.base.EWindowLoopInvalidOptions;
  IWindowLoop = nextpas.core.window.loop.intf.IWindowLoop;
  TWindowLoopTickHandler = nextpas.core.window.loop.intf.TWindowLoopTickHandler;
  TWindowLoopTickMethod = nextpas.core.window.loop.intf.TWindowLoopTickMethod;
  TWindowLoopTickProc = nextpas.core.window.loop.intf.TWindowLoopTickProc;

function DefaultWindowLoopOptions: TWindowLoopOptions; inline;
procedure CheckWindowLoopOptions(const AOptions: TWindowLoopOptions); inline;
function WindowLoopGrowCapacity(ACurrent: Integer): Integer; inline;

implementation

function DefaultWindowLoopOptions: TWindowLoopOptions; inline;
begin
  Result := nextpas.core.window.loop.base.DefaultWindowLoopOptions;
end;

procedure CheckWindowLoopOptions(const AOptions: TWindowLoopOptions); inline;
begin
  nextpas.core.window.loop.impl.CheckWindowLoopOptions(AOptions);
end;

function WindowLoopGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.window.loop.impl.WindowLoopGrowCapacity(ACurrent);
end;

end.
