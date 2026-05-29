unit nextpas.core.stopwatch.tick.x86_64;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.stopwatch.tick;

function IsAvailable: Boolean;
function CreateHWTick: ITick;
function CpuHasRDTSCP: Boolean;
function CpuHasInvariantTSC: Boolean;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.thread
{$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base
  , nextpas.core.platform.posix.ffi
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.ffi
{$ENDIF}
  ;

var
  GHasRDTSCP: Int32 = -1;
  GHasInvariantTSC: Int32 = -1;
  GCalibrated: Int32 = 0;
  GResolutionHz: UInt64 = 0;

function ReadTSC_RDTSCP: UInt64; assembler; nostackframe;
asm
  rdtscp
  shlq $32, %rdx
  orq  %rdx, %rax
  lfence
end;

function ReadTSC_LFENCE: UInt64; assembler; nostackframe;
asm
  lfence
  rdtsc
  shlq $32, %rdx
  orq  %rdx, %rax
  lfence
end;

procedure DetectCpuFeatures;
var
  LEdx: UInt32;
begin
  if AtomicLoad32(GHasRDTSCP, moAcquire) >= 0 then
    Exit;
  asm
    movl $0x80000001, %eax
    cpuid
    movl %edx, LEdx
  end ['eax','ebx','ecx','edx'];
  if (LEdx and (1 shl 27)) <> 0 then
    AtomicStore32(GHasRDTSCP, 1, moRelease)
  else
    AtomicStore32(GHasRDTSCP, 0, moRelease);
  asm
    movl $0x80000007, %eax
    cpuid
    movl %edx, LEdx
  end ['eax','ebx','ecx','edx'];
  if (LEdx and (1 shl 8)) <> 0 then
    AtomicStore32(GHasInvariantTSC, 1, moRelease)
  else
    AtomicStore32(GHasInvariantTSC, 0, moRelease);
end;

function CpuHasRDTSCP: Boolean;
begin
  DetectCpuFeatures;
  Result := AtomicLoad32(GHasRDTSCP, moAcquire) = 1;
end;

function CpuHasInvariantTSC: Boolean;
begin
  DetectCpuFeatures;
  Result := AtomicLoad32(GHasInvariantTSC, moAcquire) = 1;
end;

function ReadTSC: UInt64; inline;
begin
  if CpuHasRDTSCP then
    Result := ReadTSC_RDTSCP
  else
    Result := ReadTSC_LFENCE;
end;

procedure CalibrateResolution;
var
  LStart, LEnd: UInt64;
  LRefStart, LRefEnd: UInt64;
{$IFDEF NEXTPAS_UNIX}
  LTs: timespec;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  LCounter: Int64;
  LFreq: Int64;
{$ENDIF}
  LOld: Int32;

  function GetRefNs: UInt64;
  begin
  {$IFDEF NEXTPAS_WINDOWS}
    QueryPerformanceCounter(LCounter);
    Result := UInt64((LCounter * 1000000000) div LFreq);
  {$ELSE}
    clock_gettime(1{CLOCK_MONOTONIC}, @LTs);
    Result := UInt64(LTs.tv_sec) * 1000000000 + UInt64(LTs.tv_nsec);
  {$ENDIF}
  end;

begin
  LOld := AtomicCompareExchange32(GCalibrated, 0, 1, moAcqRel);
  if LOld <> 0 then
  begin
    while AtomicLoad32(GCalibrated, moAcquire) = 1 do
      CpuPause;
    Exit;
  end;
{$IFDEF NEXTPAS_WINDOWS}
  QueryPerformanceFrequency(LFreq);
{$ENDIF}
  LRefStart := GetRefNs;
  LStart := ReadTSC;
  platform_thread_sleep_ns(10000000);
  LEnd := ReadTSC;
  LRefEnd := GetRefNs;
  if (LRefEnd > LRefStart) and (LEnd > LStart) then
    GResolutionHz := ((LEnd - LStart) * 1000000000) div (LRefEnd - LRefStart)
  else
    GResolutionHz := 1000000000;
  AtomicStore32(GCalibrated, 2, moRelease);
end;

function IsAvailable: Boolean;
begin
  Result := CpuHasInvariantTSC;
end;

type
  TX86_64HWTick = class(TInterfacedObject, ITick)
  public
    constructor Create;
    function Tick: UInt64;
    function GetResolution: UInt64;
    function GetIsMonotonic: Boolean;
    function GetTickType: TTickType;
  end;

constructor TX86_64HWTick.Create;
begin
  inherited Create;
  CalibrateResolution;
end;

function TX86_64HWTick.Tick: UInt64;
begin
  Result := ReadTSC;
end;

function TX86_64HWTick.GetResolution: UInt64;
begin
  Result := GResolutionHz;
end;

function TX86_64HWTick.GetIsMonotonic: Boolean;
begin
  Result := CpuHasInvariantTSC;
end;

function TX86_64HWTick.GetTickType: TTickType;
begin
  Result := ttHardware;
end;

function CreateHWTick: ITick;
begin
  Result := TX86_64HWTick.Create;
end;

end.
