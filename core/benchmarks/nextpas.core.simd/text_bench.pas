program text_bench;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text.utf8, nextpas.core.text.conv, nextpas.core.simd.dispatch;
const N = 1024 * 1024;
var GAscii: TBytes; GCjk: TBytes; GDummy: Boolean;
procedure InitData;
var LI: Integer;
begin
  SetLength(GAscii, N);
  for LI := 0 to N - 1 do GAscii[LI] := Byte(65 + (LI mod 26));
  SetLength(GCjk, N * 3);
  for LI := 0 to N - 1 do begin GCjk[LI * 3] := $E4; GCjk[LI * 3 + 1] := $B8; GCjk[LI * 3 + 2] := $80; end;
end;
procedure BenchUtf8ValidateAsciiScalar(const ACtx: IBenchContext);
begin GDummy := Utf8Validate(@GAscii[0], N); ACtx.SetBytes(N); end;
procedure BenchUtf8ValidateAsciiSSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; GDummy := Utf8Validate(@GAscii[0], N); ACtx.SetBytes(N); end;
procedure BenchUtf8ValidateCjkScalar(const ACtx: IBenchContext);
begin GDummy := Utf8Validate(@GCjk[0], Length(GCjk)); ACtx.SetBytes(Length(GCjk)); end;
procedure BenchUtf8ValidateCjkSSE2(const ACtx: IBenchContext);
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; GDummy := Utf8Validate(@GCjk[0], Length(GCjk)); ACtx.SetBytes(Length(GCjk)); end;
procedure BenchMemCopyScalar(const ACtx: IBenchContext);
var LDst: TBytes;
begin SetLength(LDst, N); Move(GAscii[0], LDst[0], N); ACtx.SetBytes(N); end;
procedure BenchMemCopySSE2(const ACtx: IBenchContext);
var LDst: TBytes;
begin if not CpuHasSSE2 then begin ACtx.Skip; Exit; end; SetLength(LDst, N); Move(GAscii[0], LDst[0], N); ACtx.SetBytes(N); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('text');
  LSuite.Add('Utf8Validate/ASCII/Scalar', @BenchUtf8ValidateAsciiScalar).Add('Utf8Validate/ASCII/SSE2', @BenchUtf8ValidateAsciiSSE2)
    .Add('Utf8Validate/CJK/Scalar', @BenchUtf8ValidateCjkScalar).Add('Utf8Validate/CJK/SSE2', @BenchUtf8ValidateCjkSSE2)
    .Add('MemCopy/Scalar', @BenchMemCopyScalar).Add('MemCopy/SSE2', @BenchMemCopySSE2);
  WriteLn(LSuite.Run.PrintToConsole);
end.
