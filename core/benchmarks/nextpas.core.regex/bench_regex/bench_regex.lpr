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

procedure BenchIsFullMatch(aIters: Int64);
var R: TRegex; it: Int64;
begin
  R := TRegex.Compile('^[a-z]+$');
  for it := 1 to aIters do
    if R.IsFullMatch(GInput) then Inc(GSink);
end;

procedure BenchCaseInsensitive(aIters: Int64);
var R: TRegex; it: Int64;
begin
  R := TRegex.Compile('(?i)hello');
  for it := 1 to aIters do
    if R.IsMatch(GInput) then Inc(GSink);
end;

procedure BenchCaptureGroups(aIters: Int64);
var R: TRegex; M: TMatch; it: Int64;
begin
  R := TRegex.Compile('(\d{4})-(\d{2})-(\d{2})');
  for it := 1 to aIters do
  begin
    M := R.Find(GInput);
    if M.Found then Inc(GSink, Length(M.Groups));
  end;
end;

procedure BenchFindAll(aIters: Int64);
var R: TRegex; Matches: TMatchArray; it: Int64;
begin
  R := TRegex.Compile('\w+');
  for it := 1 to aIters do
  begin
    Matches := R.FindAll(GInput);
    Inc(GSink, Length(Matches));
  end;
end;

procedure BenchReplaceAll(aIters: Int64);
var R: TRegex; it: Int64; LResult: string;
begin
  R := TRegex.Compile('\d+');
  for it := 1 to aIters do
  begin
    LResult := R.ReplaceAll(GInput, 'NUM');
    Inc(GSink, Length(LResult));
  end;
end;

begin
  SetLength(GInput, INPUT_SIZE);
  for i := 1 to INPUT_SIZE do GInput[i] := Chr(Ord('a') + (i mod 26));
  // Insert some targets
  Move('hello world 2026-05-31 cat'[1], GInput[5000], 25);
  // Insert more numbers for ReplaceAll/FindAll benchmarks
  Move('item 42 cost 199 qty 7'[1], GInput[2000], 22);
  Move('id 12345 ref 9876'[1], GInput[8000], 18);

  WriteLn('=== Regex Benchmark (input=', INPUT_SIZE, ' bytes) ===');
  WriteLn;
  B := TBenchRunner.Create;
  B.Run('Literal IsMatch', @BenchLiteralIsMatch);
  B.Run('Digit Find (\d+)', @BenchDigitFind);
  B.Run('Alternation (4 alts)', @BenchAlternation);
  B.Run('Compile (date pattern)', @BenchCompile);
  B.Run('IsFullMatch (^[a-z]+$)', @BenchIsFullMatch);
  B.Run('Case-Insensitive (?i)', @BenchCaseInsensitive);
  B.Run('Capture Groups (date)', @BenchCaptureGroups);
  B.Run('FindAll (\\w+)', @BenchFindAll);
  B.Run('ReplaceAll (\\d+ -> NUM)', @BenchReplaceAll);
  B.Free;
  if GSink < 0 then Write('');
end.
