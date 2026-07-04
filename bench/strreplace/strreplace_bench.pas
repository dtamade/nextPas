{ StringReplace benchmark — FPC pointer-based vs Go allocation-heavy }
program strreplace_bench;
uses nextpas.core.base, nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text.conv;
const
  N = 500;
  ITERS = 100;
var
  GShortHay: array[0..N-1] of string;
  GLongHay:  array[0..N-1] of string;
  GResult:   string;
  GSink: Int64;

{ ReplaceShortNoMatch: needle not in haystack — pure scan }
procedure ReplaceShortNoMatch(const ACtx: IBenchContext);
var I, Iter: Integer; LResult: string;
begin
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LResult := StringReplace(GShortHay[I], 'ZZZZ', 'YY', True);
      GSink := GSink + Length(LResult);
    end;
end;

{ ReplaceShortAll: 'ab' → 'XY' in strings containing many 'ab' }
procedure ReplaceShortAll(const ACtx: IBenchContext);
var I, Iter: Integer; LResult: string;
begin
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LResult := StringReplace(GShortHay[I], 'ab', 'XY', True);
      GSink := GSink + Length(LResult);
    end;
end;

{ ReplaceLongAll: 'the' → 'THE' in longer strings }
procedure ReplaceLongAll(const ACtx: IBenchContext);
var I, Iter: Integer; LResult: string;
begin
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LResult := StringReplace(GLongHay[I], 'the', 'THE', True);
      GSink := GSink + Length(LResult);
    end;
end;

{ ReplaceCharAll: single char 'a' → 'Z' — very frequent matches }
procedure ReplaceCharAll(const ACtx: IBenchContext);
var I, Iter: Integer; LResult: string;
begin
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LResult := StringReplace(GShortHay[I], 'a', 'Z', True);
      GSink := GSink + Length(LResult);
    end;
end;

{ ReplaceWord: replace whole word boundary }
procedure ReplaceWord(const ACtx: IBenchContext);
var I, Iter: Integer; LResult: string;
begin
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LResult := StringReplace(GLongHay[I], 'quick', 'SLOW', True);
      GSink := GSink + Length(LResult);
    end;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
  LS: string;
begin
  { Initialize test data — short strings with many 'ab' patterns }
  for I := 0 to N-1 do begin
    LS := '';
    while Length(LS) < 50 do LS := LS + 'ab cd ef gh ';
    GShortHay[I] := LS;
  end;

  { Initialize test data — longer strings with 'the' and 'quick' }
  for I := 0 to N-1 do
    GLongHay[I] := 'the quick brown fox jumps over the lazy dog and the fox is quick again and the end';

  LSuite := TBenchSuite.Create('strreplace');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('ReplaceNoMatch',  @ReplaceShortNoMatch);
  LSuite.Add('ReplaceShortAll', @ReplaceShortAll);
  LSuite.Add('ReplaceLongAll',  @ReplaceLongAll);
  LSuite.Add('ReplaceCharAll',  @ReplaceCharAll);
  LSuite.Add('ReplaceWord',     @ReplaceWord);

  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
