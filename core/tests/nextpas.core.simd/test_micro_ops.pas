program test_micro_ops;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  SysUtils, Unix, BaseUnix,
  nextpas.core.simd.vec16;

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
  WriteLn('=== Vec16 Primitives Test ===');

  for LI := 0 to 15 do LData[LI] := LI;

  // Vec16CmpEq
  LMask := Vec16CmpEq(@LData[0], 7);
  WriteLn('CmpEq(data, 7) mask = $', IntToHex(LMask, 4), ' (expect $0080)');
  if LMask <> $0080 then begin WriteLn('FAIL'); Halt(1); end;

  LMask := Vec16CmpEq(@LData[0], 0);
  WriteLn('CmpEq(data, 0) mask = $', IntToHex(LMask, 4), ' (expect $0001)');
  if LMask <> $0001 then begin WriteLn('FAIL'); Halt(1); end;

  LMask := Vec16CmpEq(@LData[0], 255);
  WriteLn('CmpEq(data, 255) mask = $', IntToHex(LMask, 4), ' (expect $0000)');
  if LMask <> $0000 then begin WriteLn('FAIL'); Halt(1); end;

  // Vec16Ctz
  WriteLn('Ctz($0080) = ', Vec16Ctz($0080), ' (expect 7)');
  if Vec16Ctz($0080) <> 7 then begin WriteLn('FAIL'); Halt(1); end;

  WriteLn('Ctz($0000) = ', Vec16Ctz($0000), ' (expect -1)');
  if Vec16Ctz($0000) <> -1 then begin WriteLn('FAIL'); Halt(1); end;

  // Vec16Popcnt
  WriteLn('Popcnt($F0F0) = ', Vec16Popcnt($F0F0), ' (expect 8)');
  if Vec16Popcnt($F0F0) <> 8 then begin WriteLn('FAIL'); Halt(1); end;

  // Vec16CmpLtU
  LMask := Vec16CmpLtU(@LData[0], 5);
  WriteLn('CmpLtU(data, 5) mask = $', IntToHex(LMask, 4), ' (expect $001F)');
  if LMask <> $001F then begin WriteLn('FAIL'); Halt(1); end;

  // Vec16CmpGtU
  LMask := Vec16CmpGtU(@LData[0], 12);
  WriteLn('CmpGtU(data, 12) mask = $', IntToHex(LMask, 4), ' (expect $E000)');
  if LMask <> $E000 then begin WriteLn('FAIL'); Halt(1); end;

  // Vec16CmpRange
  LMask := Vec16CmpRange(@LData[0], 3, 7);
  WriteLn('CmpRange(data, 3, 7) mask = $', IntToHex(LMask, 4), ' (expect $00F8)');
  if LMask <> $00F8 then begin WriteLn('FAIL'); Halt(1); end;

  // Benchmark
  LIters := 10000000;
  LT0 := GetTimeNs;
  for LI := 0 to LIters - 1 do
    LMask := Vec16CmpEq(@LData[0], Byte(LI and 15));
  LNsPerCall := (GetTimeNs - LT0) / LIters;
  WriteLn;
  WriteLn(Format('Vec16CmpEq: %.1f ns/call (%d M calls)', [LNsPerCall, LIters div 1000000]));

  WriteLn;
  WriteLn('ALL PASS');
end.
