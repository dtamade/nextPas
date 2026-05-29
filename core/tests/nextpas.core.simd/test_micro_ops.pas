program test_micro_ops;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  SysUtils, Unix, BaseUnix,
  nextpas.core.simd.micro;

function GetTimeNs: Int64;
var LTs: TTimeVal;
begin
  fpgettimeofday(@LTs, nil);
  Result := Int64(LTs.tv_sec) * 1000000000 + Int64(LTs.tv_usec) * 1000;
end;

var
  LData: array[0..15] of Byte;
  LMask: TMask16;
  LI: Integer;
  LT0: Int64;
  LIters: Integer;
  LNsPerCall: Double;
begin
  WriteLn('=== Micro-ops Test ===');

  // Setup: data = [0..15], search for value 7
  for LI := 0 to 15 do LData[LI] := LI;

  // Correctness
  LMask := MicroCmpEqU8x16(@LData[0], 7);
  WriteLn('CmpEq(data, 7) mask = $', IntToHex(LMask, 4), ' (expect $0080)');
  if LMask <> $0080 then begin WriteLn('FAIL'); Halt(1); end;

  LMask := MicroCmpEqU8x16(@LData[0], 0);
  WriteLn('CmpEq(data, 0) mask = $', IntToHex(LMask, 4), ' (expect $0001)');
  if LMask <> $0001 then begin WriteLn('FAIL'); Halt(1); end;

  LMask := MicroCmpEqU8x16(@LData[0], 255);
  WriteLn('CmpEq(data, 255) mask = $', IntToHex(LMask, 4), ' (expect $0000)');
  if LMask <> $0000 then begin WriteLn('FAIL'); Halt(1); end;

  WriteLn('Ctz($0080) = ', MicroCtz16($0080), ' (expect 7)');
  if MicroCtz16($0080) <> 7 then begin WriteLn('FAIL'); Halt(1); end;

  WriteLn('Popcnt($F0F0) = ', MicroPopcnt16($F0F0), ' (expect 8)');
  if MicroPopcnt16($F0F0) <> 8 then begin WriteLn('FAIL'); Halt(1); end;

  WriteLn('ContainsByte(data, 7) = ', MicroContainsByte(@LData[0], 7), ' (expect TRUE)');
  if not MicroContainsByte(@LData[0], 7) then begin WriteLn('FAIL'); Halt(1); end;

  // Benchmark
  LIters := 10000000;
  LT0 := GetTimeNs;
  for LI := 0 to LIters - 1 do
    LMask := MicroCmpEqU8x16(@LData[0], Byte(LI and 15));
  LNsPerCall := (GetTimeNs - LT0) / LIters;
  WriteLn;
  WriteLn(Format('MicroCmpEqU8x16 (inline): %.1f ns/call (%d M calls)', [LNsPerCall, LIters div 1000000]));

  LT0 := GetTimeNs;
  for LI := 0 to LIters - 1 do
    LMask := MicroCmpEqU8x16_Asm(@LData[0], Byte(LI and 15));
  LNsPerCall := (GetTimeNs - LT0) / LIters;
  WriteLn(Format('MicroCmpEqU8x16_Asm:     %.1f ns/call (%d M calls)', [LNsPerCall, LIters div 1000000]));

  WriteLn;
  WriteLn('ALL PASS');
end.
