program test_toml_defensive;
{ Defensive tests: error recovery, extreme values, hash consistency,
  datetime boundaries, FindByPath edge cases, and large string handling.
  Designed to expose latent bugs that normal happy-path tests miss. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.default,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.toml.value,
  nextpas.core.toml.writer,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === 1. Error Recovery === }

procedure TestParseErrorThenDone;
var
  LDoc: TTomlDocument;
begin
  LDoc.Init(DefaultAllocator);
  Check(not LDoc.Parse(TStringView.FromStr('= invalid')), 'parse fails');
  Check(LDoc.HasError, 'has error');
  LDoc.Done;
  Check(True, 'Done after error no crash');
end;

procedure TestParseErrorThenReparse;
var
  LDoc: TTomlDocument;
begin
  LDoc.Init(DefaultAllocator);
  Check(not LDoc.Parse(TStringView.FromStr('= bad')), 'first parse fails');
  Check(LDoc.Parse(TStringView.FromStr('x = 1')), 'second parse succeeds');
  Check(not LDoc.HasError, 'no error after reparse');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 key');
  LDoc.Done;
end;

procedure TestInterfaceParseError;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[[');
  Check(LDoc.HasError, 'has error');
  Check(LDoc.Error.Line > 0, 'error has line');
  // Root is still valid (empty table created before parse fails) — this is by design
  Check(LDoc.Root.TableLen = 0, 'root empty on error');
  LDoc := nil;
  Check(True, 'release after error no crash');
end;

{ === 2. Extreme String Lengths === }

procedure TestLargeStringValue;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 's = "';
  for LI := 1 to 100000 do
    LInput := LInput + 'x';
  LInput := LInput + '"';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '100KB string ok');
  CheckEqual(Int64(100000), Int64(LDoc.Root.Get('s').AsStr.Len), '100KB len');
end;

procedure TestLargeMultiLineString;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 's = """';
  for LI := 1 to 1000 do
    LInput := LInput + 'line ' + IntToStr(LI) + #10;
  LInput := LInput + '"""';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '1000-line multi-line string ok');
  Check(LDoc.Root.Get('s').AsStr.Len > 5000, 'large multi-line content');
end;

{ === 3. Hash Index Multi-Table Switching === }

procedure TestHashIndexMultiTableSwitch;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + 'root_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LInput := LInput + '[sub]' + #10;
  for LI := 1 to 500 do
    LInput := LInput + 'sub_' + IntToStr(LI) + ' = ' + IntToStr(LI * 10) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, 'multi-table parse ok');
  CheckEqual(Int64(250), LDoc.Root.Get('root_250').AsInt, 'root key');
  CheckEqual(Int64(2500), LDoc.Root.Get('sub').Get('sub_250').AsInt, 'sub key');
  CheckEqual(Int64(500), LDoc.Root.Get('root_500').AsInt, 'last root key');
  CheckEqual(Int64(5000), LDoc.Root.Get('sub').Get('sub_500').AsInt, 'last sub key');
end;

procedure TestHashIndexDuplicateAcrossTables;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 300 do
    LInput := LInput + 'k_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LInput := LInput + '[section]' + #10;
  for LI := 1 to 300 do
    LInput := LInput + 'k_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, 'same keys in different tables ok');
  CheckEqual(Int64(150), LDoc.Root.Get('k_150').AsInt, 'root k_150');
  CheckEqual(Int64(150), LDoc.Root.Get('section').Get('k_150').AsInt, 'section k_150');
end;

{ === 4. DateTime Boundary Values === }

procedure TestDateTimeBoundaries;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = 2024-02-29T00:00:00Z');
  Check(not LDoc.HasError, 'leap year Feb 29 ok');

  LDoc := TomlParse('b = 2023-02-28T23:59:59Z');
  Check(not LDoc.HasError, 'non-leap Feb 28 ok');

  LDoc := TomlParse('c = 2024-12-31T23:59:60Z');
  Check(not LDoc.HasError, 'leap second ok');

  LDoc := TomlParse('d = 2024-01-01T00:00:00Z');
  Check(not LDoc.HasError, 'midnight ok');

  LDoc := TomlParse('e = 2024-06-30T00:00:00Z');
  Check(not LDoc.HasError, 'Jun 30 ok');

  LDoc := TomlParse('f = 2024-06-31T00:00:00Z');
  Check(LDoc.HasError, 'Jun 31 rejected');

  LDoc := TomlParse('g = 2023-02-29T00:00:00Z');
  Check(LDoc.HasError, 'non-leap Feb 29 rejected');

  LDoc := TomlParse('h = 2100-02-29T00:00:00Z');
  Check(LDoc.HasError, 'century non-leap Feb 29 rejected');

  LDoc := TomlParse('i = 2000-02-29T00:00:00Z');
  Check(not LDoc.HasError, '400-year leap Feb 29 ok');
end;

{ === 5. FindByPath Edge Cases === }

procedure TestFindByPathEdges;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a.b.c]' + #10 + 'x = 42');
  Check(not LDoc.HasError, 'parse ok');

  CheckEqual(Int64(42), LDoc.Root.FindByPath('a.b.c.x').AsInt, 'normal path');
  Check(not LDoc.Root.FindByPath('a.b.c.y').IsValid, 'missing leaf');
  Check(not LDoc.Root.FindByPath('z.z.z.z.z').IsValid, 'totally missing');
  Check(LDoc.Root.FindByPath('a').IsTable, 'partial path');
  Check(LDoc.Root.FindByPath('').IsTable, 'empty path = self');

  Check(not LDoc.Root.FindByPath('a.b.c.x.deeper').IsValid, 'path through scalar');
end;

procedure TestFindByPathLongPath;
var
  LDoc: ITomlDocument;
  LInput, LPath: string;
  LI: Integer;
begin
  LInput := '';
  LPath := '';
  for LI := 1 to 20 do
  begin
    if LI > 1 then LPath := LPath + '.';
    LPath := LPath + 'level' + IntToStr(LI);
  end;
  LInput := '[' + LPath + ']' + #10 + 'val = 99';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '20-level path parse ok');
  CheckEqual(Int64(99), LDoc.Root.FindByPath(LPath + '.val').AsInt, '20-level FindByPath');
end;

{ === 6. Writer Edge Cases === }

procedure TestWriterNestedArrayInInlineTable;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LDoc: ITomlDocument;
begin
  B.Init(128); W.Init(B);
  W.Key('t');
  W.BeginInlineTable;
  W.Key('arr');
  W.BeginArray;
  W.BeginArray; W.Int(1); W.Int(2); W.EndArray;
  W.BeginArray; W.Int(3); W.Int(4); W.EndArray;
  W.EndArray;
  W.EndInlineTable;
  LDoc := TomlParse(B.ToString);
  Check(not LDoc.HasError, 'nested array in inline table round-trips');
  CheckEqual(Int64(2), LDoc.Root.Get('t').Get('arr').ArrayLen, 'arr has 2 sub-arrays');
  B.Done;
end;

procedure TestWriterManyTables;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LDoc: ITomlDocument;
  LI: Integer;
begin
  B.Init(4096); W.Init(B);
  for LI := 1 to 50 do
  begin
    W.BeginTable('section_' + IntToStr(LI));
    W.Key('id'); W.Int(LI);
  end;
  LDoc := TomlParse(B.ToString);
  Check(not LDoc.HasError, '50 tables round-trip ok');
  CheckEqual(Int64(25), LDoc.Root.Get('section_25').Get('id').AsInt, 'section_25.id');
  B.Done;
end;

{ === 7. Stringify Edge Cases === }

procedure TestStringifySpecialKeys;
var
  LDoc: ITomlDocument;
  LStr: string;
begin
  LDoc := TomlParse('"" = "empty key"' + #10 + '"a b" = "space key"');
  Check(not LDoc.HasError, 'parse ok');
  LStr := LDoc.Stringify;
  Check(Pos('""', LStr) > 0, 'empty key preserved in stringify');
  Check(Pos('"a b"', LStr) > 0, 'space key preserved in stringify');
end;

procedure TestStringifyNanInf;
var
  LDoc: ITomlDocument;
  LStr: string;
begin
  LDoc := TomlParse('a = inf' + #10 + 'b = -inf' + #10 + 'c = nan');
  Check(not LDoc.HasError, 'parse ok');
  LStr := LDoc.Stringify;
  Check(Pos('inf', LStr) > 0, 'inf in stringify');
  Check(Pos('-inf', LStr) > 0, '-inf in stringify');
  Check(Pos('nan', LStr) > 0, 'nan in stringify');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml defensive');
  { Error Recovery }
  T.Run('parse error then Done', @TestParseErrorThenDone);
  T.Run('parse error then reparse', @TestParseErrorThenReparse);
  T.Run('interface parse error', @TestInterfaceParseError);
  { Extreme Strings }
  T.Run('100KB string value', @TestLargeStringValue);
  T.Run('1000-line multi-line string', @TestLargeMultiLineString);
  { Hash Index }
  T.Run('hash index multi-table switch', @TestHashIndexMultiTableSwitch);
  T.Run('same keys different tables', @TestHashIndexDuplicateAcrossTables);
  { DateTime Boundaries }
  T.Run('datetime boundaries', @TestDateTimeBoundaries);
  { FindByPath }
  T.Run('FindByPath edge cases', @TestFindByPathEdges);
  T.Run('FindByPath 20-level', @TestFindByPathLongPath);
  { Writer }
  T.Run('writer nested array in inline', @TestWriterNestedArrayInInlineTable);
  T.Run('writer 50 tables', @TestWriterManyTables);
  { Stringify }
  T.Run('stringify special keys', @TestStringifySpecialKeys);
  T.Run('stringify nan/inf', @TestStringifyNanInf);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
