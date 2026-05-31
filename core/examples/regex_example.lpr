program regex_example;

{$I nextpas.core.settings.inc}

uses
  SysUtils, nextpas.core.regex, nextpas.core.regex.base;

procedure DemoBasicMatch;
var
  R: TRegex;
begin
  WriteLn('--- Basic Matching ---');
  R := TRegex.Compile('\d+');

  if R.IsMatch('There are 42 items') then
    WriteLn('  IsMatch: found digits in input');

  if not R.IsMatch('no digits here') then
    WriteLn('  IsMatch: no digits found');

  WriteLn;
end;

procedure DemoIsFullMatch;
var
  R: TRegex;
begin
  WriteLn('--- Full Match ---');
  R := TRegex.Compile('[a-z]+');

  if R.IsFullMatch('hello') then
    WriteLn('  "hello" is all lowercase letters');

  if not R.IsFullMatch('Hello') then
    WriteLn('  "Hello" is NOT all lowercase (capital H)');

  WriteLn;
end;

procedure DemoFind;
var
  R: TRegex;
  M: TMatch;
  Input: string;
begin
  WriteLn('--- Find First Match ---');
  Input := 'Order #12345 placed on 2026-05-31';
  R := TRegex.Compile('\d+');
  M := R.Find(Input);
  if M.Found then
    WriteLn('  First number: "', M.Value(Input), '" at position ', M.Start);
  WriteLn;
end;

procedure DemoFindAt;
var
  R: TRegex;
  M: TMatch;
  Input: string;
begin
  WriteLn('--- FindAt (resume search) ---');
  Input := 'aaa 111 bbb 222 ccc 333';
  R := TRegex.Compile('\d+');
  M := R.Find(Input);
  if M.Found then
  begin
    WriteLn('  First: "', M.Value(Input), '"');
    // Continue searching after first match
    M := R.FindAt(Input, SizeUInt(M.Start + M.Len));
    if M.Found then
      WriteLn('  Second: "', M.Value(Input), '"');
  end;
  WriteLn;
end;

procedure DemoFindAll;
var
  R: TRegex;
  Matches: TMatchArray;
  Input: string;
  i: Integer;
begin
  WriteLn('--- FindAll ---');
  Input := 'Prices: $10, $25, $99, $150';
  R := TRegex.Compile('\d+');
  Matches := R.FindAll(Input);
  Write('  Found ', Length(Matches), ' numbers:');
  for i := 0 to High(Matches) do
    Write(' ', Matches[i].Value(Input));
  WriteLn;
  WriteLn;
end;

procedure DemoCaptureGroups;
var
  R: TRegex;
  M: TMatch;
  Input: string;
begin
  WriteLn('--- Capture Groups ---');
  Input := 'Date: 2026-05-31';
  R := TRegex.Compile('(\d{4})-(\d{2})-(\d{2})');
  M := R.Find(Input);
  if M.Found then
  begin
    WriteLn('  Full match: ', M.Value(Input));
    WriteLn('  Year:  ', M.Groups[0].Value(Input));
    WriteLn('  Month: ', M.Groups[1].Value(Input));
    WriteLn('  Day:   ', M.Groups[2].Value(Input));
  end;
  WriteLn;
end;
procedure DemoNamedGroups;
var
  R: TRegex;
  M: TMatch;
  G: TGroup;
  Input: string;
begin
  WriteLn('--- Named Capture Groups ---');
  Input := 'John Smith, age 30';
  R := TRegex.Compile('(?P<first>\w+)\s+(?P<last>\w+),\s+age\s+(?P<age>\d+)');
  M := R.Find(Input);
  if M.Found then
  begin
    G := R.GroupByName(M, 'first');
    WriteLn('  First name: ', G.Value(Input));
    G := R.GroupByName(M, 'last');
    WriteLn('  Last name:  ', G.Value(Input));
    G := R.GroupByName(M, 'age');
    WriteLn('  Age:        ', G.Value(Input));
  end;
  WriteLn;
end;

procedure DemoCaseInsensitive;
var
  R: TRegex;
  M: TMatch;
  Input: string;
begin
  WriteLn('--- Case-Insensitive Matching ---');
  Input := 'Hello WORLD from FreePascal';

  // Using inline flag
  R := TRegex.Compile('(?i)hello');
  M := R.Find(Input);
  if M.Found then
    WriteLn('  (?i)hello matched: "', M.Value(Input), '"');

  // Using compile flag
  R := TRegex.Compile('world', [rfCaseInsensitive]);
  M := R.Find(Input);
  if M.Found then
    WriteLn('  rfCaseInsensitive matched: "', M.Value(Input), '"');

  WriteLn;
end;

procedure DemoReplace;
var
  R: TRegex;
  Input, Output: string;
begin
  WriteLn('--- Replace ---');
  Input := 'foo 123 bar 456 baz 789';

  R := TRegex.Compile('\d+');
  Output := R.ReplaceFirst(Input, 'NUM');
  WriteLn('  ReplaceFirst: ', Output);

  Output := R.ReplaceAll(Input, 'NUM');
  WriteLn('  ReplaceAll:   ', Output);

  WriteLn;
end;
procedure DemoReplaceExpand;
var
  R: TRegex;
  Input, Output: string;
begin
  WriteLn('--- ReplaceAllExpand (template) ---');
  Input := '2026-05-31 and 2026-06-01';
  R := TRegex.Compile('(\d{4})-(\d{2})-(\d{2})');
  Output := R.ReplaceAllExpand(Input, '$2/$3/$1');
  WriteLn('  YYYY-MM-DD -> MM/DD/YYYY: ', Output);
  WriteLn;
end;

procedure DemoSplit;
var
  R: TRegex;
  Parts: TStringArray;
  Input: string;
  i: Integer;
begin
  WriteLn('--- Split ---');
  Input := 'one, two;  three ,four';
  R := TRegex.Compile('[,;]\s*');
  Parts := R.Split(Input);
  Write('  Split result:');
  for i := 0 to High(Parts) do
    Write(' [', Parts[i], ']');
  WriteLn;

  // With max splits
  Parts := R.Split(Input, 2);
  Write('  Split(max=2):');
  for i := 0 to High(Parts) do
    Write(' [', Parts[i], ']');
  WriteLn;
  WriteLn;
end;

procedure DemoQuoteMeta;
var
  Escaped: string;
begin
  WriteLn('--- QuoteMeta ---');
  Escaped := RegexQuoteMeta('price is $10.00 (USD)');
  WriteLn('  Escaped: ', Escaped);
  WriteLn;
end;

procedure DemoErrorHandling;
var
  R: TRegex;
  Err: string;
begin
  WriteLn('--- Error Handling ---');

  // TryCompile (no exception)
  if not TRegex.TryCompile('[unclosed', R, Err) then
    WriteLn('  TryCompile failed: ', Err);

  // Exception-based
  try
    R := TRegex.Compile('(missing paren');
  except
    on E: ERegexCompileError do
      WriteLn('  Exception at pos ', E.Position, ': ', E.Message);
  end;

  WriteLn;
end;

procedure DemoConvenienceFunctions;
var
  Matches: TMatchArray;
  Parts: TStringArray;
  i: Integer;
begin
  WriteLn('--- Convenience Functions ---');

  if RegexIsMatch('\d+', 'abc 123') then
    WriteLn('  RegexIsMatch: found');

  Matches := RegexFindAll('\w+', 'hello world');
  Write('  RegexFindAll:');
  for i := 0 to High(Matches) do
    Write(' ', Matches[i].Value('hello world'));
  WriteLn;

  WriteLn('  RegexReplaceAll: ', RegexReplaceAll('\s+', 'a  b   c', ' '));

  Parts := RegexSplit('[,]\s*', 'a, b, c');
  Write('  RegexSplit:');
  for i := 0 to High(Parts) do
    Write(' [', Parts[i], ']');
  WriteLn;
  WriteLn;
end;

begin
  WriteLn('=== nextpas.core.regex Examples ===');
  WriteLn;
  DemoBasicMatch;
  DemoIsFullMatch;
  DemoFind;
  DemoFindAt;
  DemoFindAll;
  DemoCaptureGroups;
  DemoNamedGroups;
  DemoCaseInsensitive;
  DemoReplace;
  DemoReplaceExpand;
  DemoSplit;
  DemoQuoteMeta;
  DemoErrorHandling;
  DemoConvenienceFunctions;
  WriteLn('Done.');
end.
