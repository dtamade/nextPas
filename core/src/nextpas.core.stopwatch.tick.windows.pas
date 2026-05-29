unit nextpas.core.stopwatch.tick.windows;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.stopwatch.tick;

function CreateHDTick: ITick;

implementation

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ENDIF}

type
  TWindowsHDTick = class(TInterfacedObject, ITick)
  private
    FFrequency: UInt64;
  public
    constructor Create;
    function Tick: UInt64;
    function GetResolution: UInt64;
    function GetIsMonotonic: Boolean;
    function GetTickType: TTickType;
  end;

constructor TWindowsHDTick.Create;
{$IFDEF NEXTPAS_WINDOWS}
var
  LFreq: Int64;
{$ENDIF}
begin
  inherited Create;
{$IFDEF NEXTPAS_WINDOWS}
  QueryPerformanceFrequency(LFreq);
  FFrequency := UInt64(LFreq);
{$ELSE}
  FFrequency := 1000000000;
{$ENDIF}
end;

function TWindowsHDTick.Tick: UInt64;
{$IFDEF NEXTPAS_WINDOWS}
var
  LCount: Int64;
{$ENDIF}
begin
{$IFDEF NEXTPAS_WINDOWS}
  QueryPerformanceCounter(LCount);
  Result := UInt64(LCount);
{$ELSE}
  Result := 0;
{$ENDIF}
end;

function TWindowsHDTick.GetResolution: UInt64;
begin
  Result := FFrequency;
end;

function TWindowsHDTick.GetIsMonotonic: Boolean;
begin
  Result := True;
end;

function TWindowsHDTick.GetTickType: TTickType;
begin
  Result := ttHighPrecision;
end;

function CreateHDTick: ITick;
begin
  Result := TWindowsHDTick.Create;
end;

end.
