program bench_regex;
{$I nextpas.core.settings.inc}
uses SysUtils, nextpas.core.bench, nextpas.core.regex;

const
  INPUT_SIZE = 10000;

var
  B: TBenchRunner;
  GInput: string;
  GSink: Int64;
  i: Integer;

procedure BenchLiteralIsMatch(aIters: Int64);
var R: TRegex; it: Int64;
begin
  R := TRegex.Compile('hello');
  for it := 1 to aIters do
    if R.IsMatch(GInput) then Inc(GSink);
end;

procedure BenchDigitFind(aIters: Int64);
var R: TRegex; M: TMatch; it: Int64;
begin
  R := TRegex.Compile('\d+');
  for it := 1 to aIters do
  begin
    M := R.Find(GInput);
    if M.Found then Inc(GSink, M.Len);
  end;
end;

procedure BenchAlternation(aIters: Int64);
var R: TRegex; it: Int64;
begin
  R := TRegex.Compile('cat|dog|bird|fish');
  for it := 1 to aIters do
    if R.IsMatch(GInput) then Inc(GSink);
end;

procedure BenchCompile(aIters: Int64);
var R: TRegex; it: Int64;
begin
  for it := 1 to aIters do
    R := TRegex.Compile('(\d{4})-(\d{2})-(\d{2})');
end;

begin
  SetLength(GInput, INPUT_SIZE);
  for i := 1 to INPUT_SIZE do GInput[i] := Chr(Ord('a') + (i mod 26));
  // Insert some targets
  Move('hello world 2026-05-31 cat'[1], GInput[5000], 25);

  WriteLn('=== Regex Benchmark (input=', INPUT_SIZE, ' bytes) ===');
  WriteLn;
  B := TBenchRunner.Create;
  B.Run('Literal IsMatch', @BenchLiteralIsMatch);
  B.Run('Digit Find (\d+)', @BenchDigitFind);
  B.Run('Alternation (4 alts)', @BenchAlternation);
  B.Run('Compile (date pattern)', @BenchCompile);
  B.Free;
  if GSink < 0 then Write('');
end.
