unit nextpas.core.simd.linalg.gemm.parallel;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

procedure GemmParallelF32(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt; ANumThreads: SizeUInt = 0);

implementation

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd.linalg.gemm;

type
  TGemmThreadArg = record
    AA, AB, AC: PSingle;
    AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt;
    MStart, MEnd: SizeUInt;
  end;
  PGemmThreadArg = ^TGemmThreadArg;

function GemmThreadFunc(AArg: Pointer): PtrInt;
var
  LArg: PGemmThreadArg;
  LM: SizeUInt;
begin
  LArg := PGemmThreadArg(AArg);
  LM := LArg^.MEnd - LArg^.MStart;
  if LM > 0 then
    GemmBlockedF32(
      @LArg^.AA[LArg^.MStart * LArg^.ALdA],
      LArg^.AB,
      @LArg^.AC[LArg^.MStart * LArg^.ALdC],
      LM, LArg^.AN, LArg^.AK,
      LArg^.ALdA, LArg^.ALdB, LArg^.ALdC);
  Result := 0;
end;

procedure GemmParallelF32(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt; ANumThreads: SizeUInt);
var
  LArgs: array[0..15] of TGemmThreadArg;
  LThreads: array[0..15] of TThreadID;
  LI, LChunk, LStart: SizeUInt;
begin
  if ANumThreads = 0 then
    ANumThreads := GetCPUCount;
  if ANumThreads > 16 then ANumThreads := 16;
  if ANumThreads <= 1 then
  begin
    GemmBlockedF32(AA, AB, AC, AM, AN, AK, ALdA, ALdB, ALdC);
    Exit;
  end;
  if AM < ANumThreads * GEMM_MR then
  begin
    GemmBlockedF32(AA, AB, AC, AM, AN, AK, ALdA, ALdB, ALdC);
    Exit;
  end;

  LChunk := (AM + ANumThreads - 1) div ANumThreads;
  // Round up to MR boundary
  LChunk := ((LChunk + GEMM_MR - 1) div GEMM_MR) * GEMM_MR;

  LStart := 0;
  for LI := 0 to ANumThreads - 1 do
  begin
    LArgs[LI].AA := AA;
    LArgs[LI].AB := AB;
    LArgs[LI].AC := AC;
    LArgs[LI].AM := AM;
    LArgs[LI].AN := AN;
    LArgs[LI].AK := AK;
    LArgs[LI].ALdA := ALdA;
    LArgs[LI].ALdB := ALdB;
    LArgs[LI].ALdC := ALdC;
    LArgs[LI].MStart := LStart;
    if LStart + LChunk > AM then
      LArgs[LI].MEnd := AM
    else
      LArgs[LI].MEnd := LStart + LChunk;
    LStart := LArgs[LI].MEnd;
  end;

  // Launch threads (skip last, run on current thread)
  for LI := 0 to ANumThreads - 2 do
    BeginThread(@GemmThreadFunc, @LArgs[LI], LThreads[LI]);

  // Run last chunk on current thread
  GemmThreadFunc(@LArgs[ANumThreads - 1]);

  // Wait for all threads
  for LI := 0 to ANumThreads - 2 do
    WaitForThreadTerminate(LThreads[LI], 0);
end;

function GetCPUCount: SizeUInt;
{$IFDEF UNIX}
var
  LCount: SizeUInt;
begin
  LCount := 0;
  // Simple: count lines in /proc/cpuinfo with "processor"
  // For now, default to 4
  Result := 4;
end;
{$ELSE}
begin
  Result := 4;
end;
{$ENDIF}

end.
