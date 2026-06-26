program bench_regex;
{$I nextpas.core.settings.inc}
uses SysUtils, nextpas.core.bench, nextpas.core.regex, nextpas.core.text.base;

const
  INPUT_SIZE = 10000;

var
  LResults: IBenchResults;
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

procedure BenchSplit(aIters: Int64);
var R: TRegex; it: Int64; LParts: TStringArray;
begin
  R := TRegex.Compile('\s+');
  for it := 1 to aIters do
  begin
    LParts := R.Split(GInput);
    Inc(GSink, Length(LParts));
  end;
end;

procedure BenchFindIter(aIters: Int64);
var R: TRegex; it: Int64; LIter: TRegexIter; LM: TMatch; LCount: Int64;
begin
  R := TRegex.Compile('\w+');
  for it := 1 to aIters do
  begin
    LIter := R.FindIter(GInput);
    LCount := 0;
    while LIter.Next(LM) do Inc(LCount);
    Inc(GSink, LCount);
  end;
end;

procedure BenchLargeInput(aIters: Int64);
var R: TRegex; it: Int64; LBig: string; LI: Integer;
begin
  SetLength(LBig, 100000);
  for LI := 1 to 100000 do LBig[LI] := Chr(Ord('a') + (LI mod 26));
  Move('needle'[1], LBig[99990], 6);
  R := TRegex.Compile('needle');
  for it := 1 to aIters do
    if R.IsMatch(LBig) then Inc(GSink);
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
  LResults := TBenchSuite.Create('Literal IsMatch')
    .AddLoop('Literal IsMatch', @BenchLiteralIsMatch)
    .AddLoop('Digit Find (\d+)', @BenchDigitFind)
    .AddLoop('Alternation (4 alts)', @BenchAlternation)
    .AddLoop('Compile (date pattern)', @BenchCompile)
    .AddLoop('IsFullMatch (^[a-z]+$)', @BenchIsFullMatch)
    .AddLoop('Case-Insensitive (?i)', @BenchCaseInsensitive)
    .AddLoop('Capture Groups (date)', @BenchCaptureGroups)
    .AddLoop('FindAll (\\w+)', @BenchFindAll)
    .AddLoop('ReplaceAll (\\d+ -> NUM)', @BenchReplaceAll)
    .AddLoop('Split (\\s+)', @BenchSplit)
    .AddLoop('FindIter (\\w+)', @BenchFindIter)
    .AddLoop('Large 100KB literal', @BenchLargeInput)
    .Run;
  WriteLn(LResults.PrintToConsole);
  if GSink < 0 then Write('');
end.
