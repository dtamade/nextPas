unit nextpas.core.window.loop.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.loop.base,
  nextpas.core.window.loop.intf,
  nextpas.core.window.impl;

function WindowLoopGrowCapacity(ACurrent: Integer): Integer; inline;

procedure CheckWindowLoopOptions(const AOptions: TWindowLoopOptions); inline;

implementation

function WindowLoopGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source 0→32→2× via window.impl WindowGrowCapacity → bytes.ops inline 零拷贝 O(1)均摊, 8× identical inline 已收口至 window.impl 单源
  Result := WindowGrowCapacity(ACurrent);
end;

procedure CheckWindowLoopOptions(const AOptions: TWindowLoopOptions); inline;
begin
  if AOptions.TickIntervalMs < 0 then
    raise EWindowLoopInvalidOptions.CreateFmt('TickIntervalMs must be >=0 (got %d)', [AOptions.TickIntervalMs]);
  if AOptions.PumpBudget < 0 then
    raise EWindowLoopInvalidOptions.CreateFmt('PumpBudget must be >=0 (got %d)', [AOptions.PumpBudget]);
end;

end.
