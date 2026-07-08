program escape_bench;

{$mode objfpc}{$H+}

uses nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 10000;

var
  GData: array[0..N-1] of string;
  GSink: Integer;

procedure InitData;
const
  SAMPLES: array[0..9] of string = (
    'Hello World',
    'line1'#$A'line2'#$A'line3',
    'C:\Users\test\file.txt',
    '<script>alert("xss")</script>',
    'a=b&c=d&e=f',
    'no escaping needed here',
    #1#2#3#0'text after null',
    'tabs'#$9'and'#$9'more'#$9'tabs',
    'quote "inside" and ''single''',
    'mix: <>&"''=end'
  );
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GData[I] := SAMPLES[I mod 10];
end;

{ --- Pascal: set of Byte for char class, manual build --- }

procedure BenchEscape_SetBuild(const ACtx: IBenchContext);
const
  ESCAPE_SET = ['"', '\', #0..#31, #127];
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';
var
  I, J, LLen, LCap: Integer;
  S: string;
  LOut: string;
  C: Char;
begin
  for I := 0 to N-1 do
  begin
    S := GData[I];
    LLen := Length(S);
    LCap := LLen + LLen shr 2 + 16;
    SetLength(LOut, LCap);
    J := 0;
    for LLen := 1 to Length(S) do
    begin
      C := S[LLen];
      if C in ESCAPE_SET then
      begin
        if J + 4 > LCap then begin LCap := LCap * 2; SetLength(LOut, LCap); end;
        Inc(J); LOut[J] := '\';
        case C of
          '"':  begin Inc(J); LOut[J] := '"'; end;
          '\':  begin Inc(J); LOut[J] := '\'; end;
          #10:  begin Inc(J); LOut[J] := 'n'; end;
          #13:  begin Inc(J); LOut[J] := 'r'; end;
          #9:   begin Inc(J); LOut[J] := 't'; end;
          else begin
            Inc(J); LOut[J] := 'x';
            Inc(J); LOut[J] := HEX_DIGITS[Byte(C) shr 4];
            Inc(J); LOut[J] := HEX_DIGITS[Byte(C) and $F];
          end;
        end;
      end
      else
      begin
        if J + 1 > LCap then begin LCap := LCap * 2; SetLength(LOut, LCap); end;
        Inc(J); LOut[J] := C;
      end;
    end;
    SetLength(LOut, J);
  end;
  GSink := Length(LOut);
  ACtx.SetBytes(N * 40);
end;

{ --- Pascal: scan count then alloc exact (two-pass) --- }

procedure BenchEscape_TwoPass(const ACtx: IBenchContext);
const
  ESCAPE_SET = ['"', '\', #0..#31, #127];
var
  I, J, LExtra, LLen: Integer;
  S, LOut: string;
  C: Char;
begin
  for I := 0 to N-1 do
  begin
    S := GData[I];
    LExtra := 0;
    for LLen := 1 to Length(S) do
    begin
      C := S[LLen];
      if C in ESCAPE_SET then
        if C in [#10, #13, #9, '"', '\'] then Inc(LExtra)
        else Inc(LExtra, 3);
    end;
    SetLength(LOut, Length(S) + LExtra);
    J := 0;
    for LLen := 1 to Length(S) do
    begin
      C := S[LLen];
      if not (C in ESCAPE_SET) then
      begin
        Inc(J); LOut[J] := C;
      end
      else
      begin
        Inc(J); LOut[J] := '\';
        case C of
          '"':  begin Inc(J); LOut[J] := '"'; end;
          '\':  begin Inc(J); LOut[J] := '\'; end;
          #10:  begin Inc(J); LOut[J] := 'n'; end;
          #13:  begin Inc(J); LOut[J] := 'r'; end;
          #9:   begin Inc(J); LOut[J] := 't'; end;
          else begin
            Inc(J); LOut[J] := 'x';
            Inc(J); LOut[J] := '0';
            Inc(J); LOut[J] := Char(Byte('0') + Byte(C) shr 4);
          end;
        end;
      end;
    end;
  end;
  GSink := Length(LOut);
  ACtx.SetBytes(N * 40);
end;

{ --- count special chars (baseline for set of Char speed) --- }

procedure BenchEscape_CountSet(const ACtx: IBenchContext);
const
  ESCAPE_SET = ['"', '\', #0..#31, #127];
var
  I, LLen, LCount: Integer;
  S: string;
begin
  LCount := 0;
  for I := 0 to N-1 do
  begin
    S := GData[I];
    for LLen := 1 to Length(S) do
      if S[LLen] in ESCAPE_SET then
        Inc(LCount);
  end;
  GSink := LCount;
  ACtx.SetBytes(N * 40);
end;

procedure BenchEscape_CountBranch(const ACtx: IBenchContext);
var
  I, LLen, LCount: Integer;
  S: string;
  C: Char;
begin
  LCount := 0;
  for I := 0 to N-1 do
  begin
    S := GData[I];
    for LLen := 1 to Length(S) do
    begin
      C := S[LLen];
      if (C = '"') or (C = '\') or (C < #32) or (C = #127) then
        Inc(LCount);
    end;
  end;
  GSink := LCount;
  ACtx.SetBytes(N * 40);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('escape');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('Escape/SetBuild/10K', @BenchEscape_SetBuild);
  LSuite.Add('Escape/TwoPass/10K', @BenchEscape_TwoPass);
  LSuite.Add('Escape/CountSet/10K', @BenchEscape_CountSet);
  LSuite.Add('Escape/CountBranch/10K', @BenchEscape_CountBranch);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
