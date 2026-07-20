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
var
  LExpected: Int32;
{$IFDEF CPUAARCH64}
  LFreq: UInt32;
{$ENDIF}
begin
  if atomic_load(GInitDone, mo_acquire) <> 0 then
    Exit;
  LExpected := 0;
  if not atomic_compare_exchange_strong(GInitDone, LExpected, 1, mo_acq_rel, mo_acquire) then
  begin
    while atomic_load(GInitDone, mo_acquire) = 1 do
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
  atomic_store(GInitDone, 2, mo_release);
end;

function IsAvailable: Boolean;
begin
{$IF defined(CPUAARCH64) and defined(NEXTPAS_USE_ARCH_TIMER)}
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
