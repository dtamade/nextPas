unit nextpas.core.stopwatch.tick.unix;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.stopwatch.tick;

function CreateHDTick: ITick;

implementation

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

type
  TUnixHDTick = class(TInterfacedObject, ITick)
  public
    function Tick: UInt64;
    function GetResolution: UInt64;
    function GetIsMonotonic: Boolean;
    function GetTickType: TTickType;
  end;

function TUnixHDTick.Tick: UInt64;
var
  LTs: timespec;
begin
  if clock_gettime(1{CLOCK_MONOTONIC}, @LTs) = 0 then
    Result := UInt64(LTs.tv_sec) * 1000000000 + UInt64(LTs.tv_nsec)
  else
    Result := 0;
end;

function TUnixHDTick.GetResolution: UInt64;
begin
  Result := 1000000000;
end;

function TUnixHDTick.GetIsMonotonic: Boolean;
begin
  Result := True;
end;

function TUnixHDTick.GetTickType: TTickType;
begin
  Result := ttHighPrecision;
end;

function CreateHDTick: ITick;
begin
  Result := TUnixHDTick.Create;
end;

end.
