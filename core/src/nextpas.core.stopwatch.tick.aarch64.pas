unit nextpas.core.stopwatch.tick.aarch64;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.stopwatch.tick;

function IsAvailable: Boolean;
function CreateHWTick: ITick;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.thread;

{$IFDEF CPUAARCH64}
function ReadCNTVCT: UInt64; assembler; nostackframe;
asm
  isb
  mrs x0, cntvct_el0
end;

function ReadCNTFRQ: UInt32; assembler; nostackframe;
asm
  mrs x0, cntfrq_el0
end;
{$ENDIF}

var
  GFrequency: UInt64 = 0;
  GInitDone: Int32 = 0;

procedure InitFrequency;
{$IFDEF CPUAARCH64}
var
  LFreq: UInt32;
{$ENDIF}
begin
  if AtomicLoad32(GInitDone, moAcquire) <> 0 then
    Exit;
  if AtomicCompareExchange32(GInitDone, 0, 1, moAcqRel) <> 0 then
  begin
    while AtomicLoad32(GInitDone, moAcquire) = 1 do
      CpuPause;
    Exit;
  end;
{$IFDEF CPUAARCH64}
  LFreq := ReadCNTFRQ;
  if LFreq > 0 then
    GFrequency := UInt64(LFreq)
  else
    GFrequency := 1000000000;
{$ELSE}
  GFrequency := 1000000000;
{$ENDIF}
  AtomicStore32(GInitDone, 2, moRelease);
end;

function IsAvailable: Boolean;
begin
{$IFDEF CPUAARCH64}
  Result := True;
{$ELSE}
  Result := False;
{$ENDIF}
end;

type
  TAArch64HWTick = class(TInterfacedObject, ITick)
  public
    constructor Create;
    function Tick: UInt64;
    function GetResolution: UInt64;
    function GetIsMonotonic: Boolean;
    function GetTickType: TTickType;
  end;

constructor TAArch64HWTick.Create;
begin
  inherited Create;
  InitFrequency;
end;

function TAArch64HWTick.Tick: UInt64;
begin
{$IFDEF CPUAARCH64}
  Result := ReadCNTVCT;
{$ELSE}
  Result := 0;
{$ENDIF}
end;

function TAArch64HWTick.GetResolution: UInt64;
begin
  Result := GFrequency;
end;

function TAArch64HWTick.GetIsMonotonic: Boolean;
begin
  Result := True;
end;

function TAArch64HWTick.GetTickType: TTickType;
begin
  Result := ttHardware;
end;

function CreateHWTick: ITick;
begin
  Result := TAArch64HWTick.Create;
end;

end.
