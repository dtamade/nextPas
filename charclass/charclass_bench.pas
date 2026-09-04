{$mode ObjFPC}{$H+}
program charclass_bench;
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.char;

const
  N1M = 10000;
  BUF_SIZE = 256;

var
  GBuf: array[0..BUF_SIZE-1] of Byte;
  GResult: Integer;

procedure IsDigit_1M(const ACtx: IBenchContext);
var I, J: Integer; C: Integer;
begin
  C := 0;
  for I := 1 to N1M do
    for J := 0 to BUF_SIZE - 1 do
      if IsDigit(GBuf[J]) then Inc(C);
  GResult := C;
end;

procedure IsAlpha_1M(const ACtx: IBenchContext);
var I, J: Integer; C: Integer;
begin
  C := 0;
  for I := 1 to N1M do
    for J := 0 to BUF_SIZE - 1 do
      if IsAlpha(GBuf[J]) then Inc(C);
  GResult := C;
end;

procedure IsWhitespace_1M(const ACtx: IBenchContext);
var I, J: Integer; C: Integer;
begin
  C := 0;
  for I := 1 to N1M do
    for J := 0 to BUF_SIZE - 1 do
      if IsWhitespace(GBuf[J]) then Inc(C);
  GResult := C;
end;

procedure IsHexDigit_1M(const ACtx: IBenchContext);
var I, J: Integer; C: Integer;
begin
  C := 0;
  for I := 1 to N1M do
    for J := 0 to BUF_SIZE - 1 do
      if IsHexDigit(GBuf[J]) then Inc(C);
  GResult := C;
end;

var LSuite: IBenchSuite;
    LResults: IBenchResults;
    I: Integer;
begin
  for I := 0 to BUF_SIZE - 1 do
    GBuf[I] := Byte(I);

  LSuite := TBenchSuite.Create('CharClass');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('IsDigit/1M', @IsDigit_1M);
  LSuite.Add('IsAlpha/1M', @IsAlpha_1M);
  LSuite.Add('IsWhitespace/1M', @IsWhitespace_1M);
  LSuite.Add('IsHexDigit/1M', @IsHexDigit_1M);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
