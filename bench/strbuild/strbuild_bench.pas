program strbuild_bench;
{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv,
  nextpas.core.text.builder;

const
  N = 100000;

var
  GParts: array[0..N-1] of string;
  I: Integer;

procedure InitData;
begin
  for I := 0 to N - 1 do
    GParts[I] := 'item_' + IntToStr(I);
end;

procedure BenchBuilderAppend(const ACtx: IBenchContext);
var
  B: TBufStringBuilder;
  J: Integer;
begin
  B.Init(N * 16);
  for J := 0 to N - 1 do
  begin
    B.AppendStr(GParts[J]);
    B.AppendChar(',');
  end;
  ACtx.SetBytes(B.Len);
  B.Done;
end;

procedure BenchBuilderIntAppend(const ACtx: IBenchContext);
var
  B: TBufStringBuilder;
  J: Integer;
begin
  B.Init(N * 16);
  for J := 0 to N - 1 do
  begin
    B.AppendInt(J);
    B.AppendChar(',');
  end;
  ACtx.SetBytes(B.Len);
  B.Done;
end;

procedure BenchConcat(const ACtx: IBenchContext);
var
  S: string;
  J: Integer;
begin
  S := '';
  for J := 0 to N - 1 do
    S := S + GParts[J] + ',';
  ACtx.SetBytes(Length(S));
  if S = '' then WriteLn('');
end;

procedure BenchBuilderLarge(const ACtx: IBenchContext);
var
  B: TBufStringBuilder;
  J: Integer;
begin
  B.Init(N * 32);
  for J := 0 to N - 1 do
  begin
    B.AppendStr('line_');
    B.AppendInt(J);
    B.AppendStr(': value=');
    B.AppendFloat(J * 3.14);
    B.AppendChar(#10);
  end;
  ACtx.SetBytes(B.Len);
  B.Done;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas String Builder Benchmark ===');
  WriteLn('N=', N, ' parts');
  WriteLn;

  LSuite := TBenchSuite.Create('StrBuild')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Builder/Append/100k', @BenchBuilderAppend);
  LSuite.Add('Builder/IntAppend/100k', @BenchBuilderIntAppend);
  LSuite.Add('Concat/100k', @BenchConcat);
  LSuite.Add('Builder/Large/100k', @BenchBuilderLarge);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
