program strconv_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

var
  GData: array[0..N-1] of string;
  GResults: array[0..N-1] of Integer;
  GSink: Integer;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GData[I] := IntToStr(I * 37 mod 10000000);
end;

{ --- Pascal: StrToIntDef (compiler builtin) --- }

procedure BenchConv_StrToIntDef(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GResults[I] := StrToIntDef(GData[I], 0);
  GSink := GResults[0];
  ACtx.SetBytes(N * 8);
end;

{ --- Pascal: manual unsigned parse --- }

function ParseUInt32(const S: string): UInt32;
var
  I, LLen: Integer;
  R: UInt32;
  C: Byte;
begin
  R := 0;
  LLen := Length(S);
  for I := 1 to LLen do
  begin
    C := Byte(S[I]) - Byte('0');
    if C > 9 then Break;
    R := R * 10 + C;
  end;
  Result := R;
end;

procedure BenchConv_ManualParse(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GResults[I] := Integer(ParseUInt32(GData[I]));
  GSink := GResults[0];
  ACtx.SetBytes(N * 8);
end;

{ --- Pascal: fast manual parse with multiply table --- }

procedure BenchConv_FastParse(const ACtx: IBenchContext);
const
  POW10: array[0..9] of UInt32 = (1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000);
var
  I, J, LLen: Integer;
  R: UInt32;
  S: string;
begin
  for I := 0 to N-1 do
  begin
    S := GData[I];
    LLen := Length(S);
    R := 0;
    for J := 1 to LLen do
      R := R * 10 + (UInt32(Byte(S[J])) - UInt32(Byte('0')));
    GResults[I] := Integer(R);
  end;
  GSink := GResults[0];
  ACtx.SetBytes(N * 8);
end;

{ --- Pascal: block parse (4 chars at a time) --- }

procedure BenchConv_BlockParse(const ACtx: IBenchContext);
var
  I, J, LLen, LRem: Integer;
  R: UInt32;
  S: string;
begin
  for I := 0 to N-1 do
  begin
    S := GData[I];
    LLen := Length(S);
    R := 0;
    J := 1;
    { process in blocks of 4 }
    while J + 3 <= LLen do
    begin
      R := R * 10000
         + (UInt32(Byte(S[J]))   - UInt32(Byte('0'))) * 1000
         + (UInt32(Byte(S[J+1])) - UInt32(Byte('0'))) * 100
         + (UInt32(Byte(S[J+2])) - UInt32(Byte('0'))) * 10
         + (UInt32(Byte(S[J+3])) - UInt32(Byte('0')));
      Inc(J, 4);
    end;
    while J <= LLen do
    begin
      R := R * 10 + (UInt32(Byte(S[J])) - UInt32(Byte('0')));
      Inc(J);
    end;
    GResults[I] := Integer(R);
  end;
  GSink := GResults[0];
  ACtx.SetBytes(N * 8);
end;

{ --- Pascal: StrToInt for comparison --- }

procedure BenchConv_StrToInt(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GResults[I] := StrToInt(GData[I]);
  GSink := GResults[0];
  ACtx.SetBytes(N * 8);
end;

{ --- Pascal: IntToStr (reverse direction) --- }

procedure BenchConv_IntToStr(const ACtx: IBenchContext);
var
  I: Integer;
  S: string;
begin
  for I := 0 to N-1 do
    S := IntToStr(GResults[I]);
  GSink := Length(S);
  ACtx.SetBytes(N * 8);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('strconv');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('StrToInt/100K', @BenchConv_StrToInt);
  LSuite.Add('StrToIntDef/100K', @BenchConv_StrToIntDef);
  LSuite.Add('ManualParse/100K', @BenchConv_ManualParse);
  LSuite.Add('FastParse/100K', @BenchConv_FastParse);
  LSuite.Add('BlockParse/100K', @BenchConv_BlockParse);
  LSuite.Add('IntToStr/100K', @BenchConv_IntToStr);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
