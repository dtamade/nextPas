unit nextpas.core.stopwatch.tick;

{$I nextpas.core.settings.inc}

interface

type
  TTickType = (ttStandard, ttHighPrecision, ttHardware);

  ITick = interface
    ['{B8F5A2E1-4C3D-4F2A-9B1E-8D7C6A5F4E3D}']
    function Tick: UInt64;
    function GetResolution: UInt64;
    function GetIsMonotonic: Boolean;
    function GetTickType: TTickType;
  end;

function MakeBestTick: ITick;
function MakeHDTick: ITick;
function HasHardwareTick: Boolean;

implementation

uses
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.stopwatch.tick.unix
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.stopwatch.tick.windows
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.stopwatch.tick.darwin
{$ENDIF}
{$IFDEF CPUX86_64}
  , nextpas.core.stopwatch.tick.x86_64
{$ENDIF}
  ;

function HasHardwareTick: Boolean;
begin
{$IFDEF CPUX86_64}
  Result := nextpas.core.stopwatch.tick.x86_64.IsAvailable;
{$ELSE}
  Result := False;
{$ENDIF}
end;

function MakeHDTick: ITick;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := nextpas.core.stopwatch.tick.windows.CreateHDTick;
{$ELSEIF defined(NEXTPAS_MACOS)}
  Result := nextpas.core.stopwatch.tick.darwin.CreateHDTick;
{$ELSE}
  Result := nextpas.core.stopwatch.tick.unix.CreateHDTick;
{$ENDIF}
end;

function MakeBestTick: ITick;
begin
{$IFDEF CPUX86_64}
  if nextpas.core.stopwatch.tick.x86_64.IsAvailable then
    Exit(nextpas.core.stopwatch.tick.x86_64.CreateHWTick);
{$ENDIF}
  Result := MakeHDTick;
end;

end.
