unit nextpas.core.stopwatch.tick.darwin;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.stopwatch.tick;

function CreateHDTick: ITick;

implementation

{$IFDEF NEXTPAS_MACOS}
type
  TMachTimebaseInfo = record
    numer: UInt32;
    denom: UInt32;
  end;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
procedure mach_timebase_info(var info: TMachTimebaseInfo); cdecl; external 'c' name 'mach_timebase_info';
{$ENDIF}

type
  TDarwinHDTick = class(TInterfacedObject, ITick)
  private
    FResolution: UInt64;
  public
    constructor Create;
    function Tick: UInt64;
    function GetResolution: UInt64;
    function GetIsMonotonic: Boolean;
    function GetTickType: TTickType;
  end;

constructor TDarwinHDTick.Create;
{$IFDEF NEXTPAS_MACOS}
var
  LInfo: TMachTimebaseInfo;
{$ENDIF}
begin
  inherited Create;
{$IFDEF NEXTPAS_MACOS}
  mach_timebase_info(LInfo);
  if LInfo.numer > 0 then
    FResolution := (UInt64(1000000000) * LInfo.denom) div LInfo.numer
  else
    FResolution := 1000000000;
{$ELSE}
  FResolution := 1000000000;
{$ENDIF}
end;

function TDarwinHDTick.Tick: UInt64;
begin
{$IFDEF NEXTPAS_MACOS}
  Result := mach_absolute_time;
{$ELSE}
  Result := 0;
{$ENDIF}
end;

function TDarwinHDTick.GetResolution: UInt64;
begin
  Result := FResolution;
end;

function TDarwinHDTick.GetIsMonotonic: Boolean;
begin
  Result := True;
end;

function TDarwinHDTick.GetTickType: TTickType;
begin
  Result := ttHighPrecision;
end;

function CreateHDTick: ITick;
begin
  Result := TDarwinHDTick.Create;
end;

end.
