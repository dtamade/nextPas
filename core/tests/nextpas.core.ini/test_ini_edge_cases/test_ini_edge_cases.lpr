program test_ini_edge_cases;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.ini,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ===== BOM handling ===== }

procedure TestUTF8BOM;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(#$EF#$BB#$BF + '[section]' + #10 + 'key=value');
    Check(not Ini.SectionExists('section'), 'BOM: section not found (BOM not stripped)');
    { BOM is not stripped; it becomes part of the section name }
  finally
    Ini.Free;
  end;
end;

{ ===== Comment styles ===== }

procedure TestSemicolonComments;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(
      '; top comment' + #10 +
      '[section]' + #10 +
      '; section comment' + #10 +
      'key=value' + #10 +
      '; bottom comment');
    Check(Ini.SectionExists('section'), 'semicolon comments: section exists');
    CheckEqual('value', Ini.ReadString('section', 'key', ''), 'semicolon comments: value');
  finally
    Ini.Free;
  end;
end;

procedure TestHashComments;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(
      '# top comment' + #10 +
      '[server]' + #10 +
      '# inline' + #10 +
      'host=localhost');
    CheckEqual('localhost', Ini.ReadString('server', 'host', ''),
      'hash comments: value');
  finally
    Ini.Free;
  end;
end;

{ ===== Empty values ===== }

procedure TestEmptyValue;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[config]' + #10 + 'key=');
    CheckEqual('', Ini.ReadString('config', 'key', 'DEFAULT'),
      'empty value: returns empty, not default');
  finally
    Ini.Free;
  end;
end;

procedure TestSpacesAroundEquals;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[app]' + #10 + 'name = nextpas');
    CheckEqual('nextpas', Ini.ReadString('app', 'name', ''),
      'spaces around equals');
  finally
    Ini.Free;
  end;
end;

procedure TestValueWithEqualsSign;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[env]' + #10 + 'PATH=/usr/bin:/usr/local/bin');
    CheckEqual('/usr/bin:/usr/local/bin',
      Ini.ReadString('env', 'PATH', ''),
      'value with equals signs');
  finally
    Ini.Free;
  end;
end;

{ ===== Case sensitivity ===== }

procedure TestSectionCaseInsensitive;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[Server]' + #10 + 'host=localhost');
    CheckEqual('localhost', Ini.ReadString('server', 'host', ''),
      'section case insensitive: mixed case section');
    CheckEqual('localhost', Ini.ReadString('SERVER', 'host', ''),
      'section case insensitive: upper case section');
  finally
    Ini.Free;
  end;
end;

procedure TestKeyCaseInsensitive;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[app]' + #10 + 'Name=nextpas');
    CheckEqual('nextpas', Ini.ReadString('app', 'name', ''),
      'key case insensitive: mixed case key');
    CheckEqual('nextpas', Ini.ReadString('app', 'NAME', ''),
      'key case insensitive: upper case key');
  finally
    Ini.Free;
  end;
end;

{ ===== Whitespace handling ===== }

procedure TestTrailingSpacesPreserved;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[section]' + #10 + 'key=value   ');
    CheckEqual('value   ', Ini.ReadString('section', 'key', ''),
      'trailing spaces in value preserved');
  finally
    Ini.Free;
  end;
end;

procedure TestLeadingSpacesTrimmed;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[section]' + #10 + 'key=   value');
    CheckEqual('value', Ini.ReadString('section', 'key', ''),
      'leading spaces in value trimmed');
  finally
    Ini.Free;
  end;
end;

{ ===== Duplicate keys (last wins) ===== }

procedure TestDuplicateKeyLastWins;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[app]' + #10 + 'key=first' + #10 + 'key=second');
    CheckEqual('second', Ini.ReadString('app', 'key', ''),
      'duplicate key: last value wins');
  finally
    Ini.Free;
  end;
end;

{ ===== ReadBool with all recognized values ===== }

procedure TestReadBoolValues;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[flags]' + #10 +
      'a=true' + #10 +
      'b=false' + #10 +
      'c=1' + #10 +
      'd=0' + #10 +
      'e=yes' + #10 +
      'f=no' + #10 +
      'g=on' + #10 +
      'h=off' + #10 +
      'i=TRUE' + #10 +
      'j=FALSE');
    Check(Ini.ReadBool('flags', 'a', False), 'bool true');
    Check(not Ini.ReadBool('flags', 'b', True), 'bool false');
    Check(Ini.ReadBool('flags', 'c', False), 'bool 1');
    Check(not Ini.ReadBool('flags', 'd', True), 'bool 0');
    Check(Ini.ReadBool('flags', 'e', False), 'bool yes');
    Check(not Ini.ReadBool('flags', 'f', True), 'bool no');
    Check(Ini.ReadBool('flags', 'g', False), 'bool on');
    Check(not Ini.ReadBool('flags', 'h', True), 'bool off');
    Check(Ini.ReadBool('flags', 'i', False), 'bool TRUE');
    Check(not Ini.ReadBool('flags', 'j', True), 'bool FALSE');
  finally
    Ini.Free;
  end;
end;

procedure TestReadBoolDefault;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[section]' + #10 + 'flag=maybe');
    Check(Ini.ReadBool('section', 'flag', True), 'bool unknown uses default true');
    Check(not Ini.ReadBool('section', 'flag', False), 'bool unknown uses default false');
  finally
    Ini.Free;
  end;
end;

{ ===== ReadInteger edge cases ===== }

procedure TestReadIntegerBoundaries;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteInteger('limits', 'zero', 0);
    Ini.WriteInteger('limits', 'max', High(Int64));
    Ini.WriteInteger('limits', 'min', Low(Int64));
    CheckEqual(Int64(0), Ini.ReadInteger('limits', 'zero', -1), 'int zero');
    CheckEqual(High(Int64), Ini.ReadInteger('limits', 'max', -1), 'int max');
    CheckEqual(Low(Int64), Ini.ReadInteger('limits', 'min', -1), 'int min');
  finally
    Ini.Free;
  end;
end;

procedure TestReadIntegerInvalid;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[n]' + #10 + 'val=notanumber');
    CheckEqual(Int64(42), Ini.ReadInteger('n', 'val', 42),
      'int invalid returns default');
  finally
    Ini.Free;
  end;
end;

{ ===== Empty sections ===== }

procedure TestEmptySection;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[empty]' + #10 + '[next]' + #10 + 'key=value');
    Check(Ini.SectionExists('empty'), 'empty section exists');
    CheckEqual('value', Ini.ReadString('next', 'key', ''), 'empty section: next key');
    CheckEqual(Int64(0), Int64(Length(Ini.GetKeys('empty'))),
      'empty section has no keys');
  finally
    Ini.Free;
  end;
end;

{ ===== Malformed input ===== }

procedure TestMalformedSectionNoClose;
var
  Ini: TIniFile;
  LError: string;
begin
  Ini := TIniFile.Create;
  try
    Check(not Ini.TryLoadFromString('[unclosed' + #10 + 'key=value', LError),
      'unclosed section: parse fails');
    Check(Pos('missing closing', LError) > 0, 'unclosed section: error message');
  finally
    Ini.Free;
  end;
end;

procedure TestMalformedRecovers;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    { Unclosed section is ignored; subsequent content still parses }
    Ini.LoadFromString('[unclosed' + #10 + '[valid]' + #10 + 'key=value');
    Check(Ini.SectionExists('valid'), 'malformed: valid section still parsed');
    CheckEqual('value', Ini.ReadString('valid', 'key', ''),
      'malformed: valid key parsed');
  finally
    Ini.Free;
  end;
end;

{ ===== Stress test: many entries ===== }

procedure TestManySections;
var
  Ini: TIniFile;
  LI: Integer;
  LContent: string;
begin
  LContent := '';
  for LI := 0 to 49 do
    LContent := LContent + '[section' + IntToStr(LI) + ']' + #10 +
      'key=val' + IntToStr(LI) + #10;
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(LContent);
    CheckEqual(Int64(50), Int64(Length(Ini.GetSections)),
      '50 sections created');
    CheckEqual('val25', Ini.ReadString('section25', 'key', ''),
      'section25 value correct');
  finally
    Ini.Free;
  end;
end;

procedure TestManyKeys;
var
  Ini: TIniFile;
  LI: Integer;
  LContent: string;
begin
  LContent := '[data]' + #10;
  for LI := 0 to 99 do
    LContent := LContent + 'k' + IntToStr(LI) + '=v' + IntToStr(LI) + #10;
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString(LContent);
    CheckEqual(Int64(100), Int64(Length(Ini.GetKeys('data'))),
      '100 keys in section');
    CheckEqual('v99', Ini.ReadString('data', 'k99', ''), 'last key correct');
  finally
    Ini.Free;
  end;
end;

{ ===== TryLoadFromString success/failure ===== }

procedure TestTryLoadFromStringSuccess;
var
  Ini: TIniFile;
  LError: string;
begin
  Ini := TIniFile.Create;
  try
    Check(Ini.TryLoadFromString('[a]' + #10 + 'x=1', LError),
      'TryLoadFromString succeeds');
    CheckEqual('', LError, 'TryLoadFromString no error');
    CheckEqual('1', Ini.ReadString('a', 'x', ''), 'TryLoadFromString value');
  finally
    Ini.Free;
  end;
end;

procedure TestTryLoadFromStringFailure;
var
  Ini: TIniFile;
  LError: string;
begin
  Ini := TIniFile.Create;
  try
    Check(not Ini.TryLoadFromString('[bad', LError),
      'TryLoadFromString fails on malformed');
    Check(LError <> '', 'TryLoadFromString has error message');
  finally
    Ini.Free;
  end;
end;

{ ===== IniStringify function ===== }

procedure TestIniStringifyFunction;
var
  Ini: TIniFile;
  LOut: string;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('app', 'name', 'test');
    LOut := IniStringify(Ini);
    Check(Pos('[app]', LOut) > 0, 'IniStringify: section');
    Check(Pos('name=test', LOut) > 0, 'IniStringify: key=value');
  finally
    Ini.Free;
  end;
end;

{ ===== IniParse function ===== }

procedure TestIniParseConvenience;
var
  Ini: TIniFile;
begin
  Ini := IniParse('[db]' + #10 + 'host=localhost' + #10 + 'port=5432');
  try
    CheckEqual('localhost', Ini.ReadString('db', 'host', ''),
      'IniParse: host');
    CheckEqual(Int64(5432), Ini.ReadInteger('db', 'port', 0),
      'IniParse: port');
  finally
    Ini.Free;
  end;
end;

{ ===== Write → Delete → Verify ===== }

procedure TestWriteDeleteCycle;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.WriteString('s1', 'k1', 'v1');
    Ini.WriteString('s1', 'k2', 'v2');
    Ini.WriteString('s2', 'k3', 'v3');
    Check(Ini.KeyExists('s1', 'k1'), 'pre delete: k1 exists');
    Ini.DeleteKey('s1', 'k1');
    Check(not Ini.KeyExists('s1', 'k1'), 'post delete: k1 gone');
    Check(Ini.KeyExists('s1', 'k2'), 'post delete: k2 still there');
    Ini.DeleteSection('s1');
    Check(not Ini.SectionExists('s1'), 'post delete section: s1 gone');
    Check(Ini.SectionExists('s2'), 'post delete section: s2 still there');
  finally
    Ini.Free;
  end;
end;

begin
  T := TTestRunner.Create('ini edge cases');
  { BOM }
  T.Run('UTF-8 BOM', @TestUTF8BOM);
  { Comments }
  T.Run('semicolon comments', @TestSemicolonComments);
  T.Run('hash comments', @TestHashComments);
  { Empty values }
  T.Run('empty value', @TestEmptyValue);
  T.Run('spaces around equals', @TestSpacesAroundEquals);
  T.Run('value with equals sign', @TestValueWithEqualsSign);
  { Case sensitivity }
  T.Run('section case insensitive', @TestSectionCaseInsensitive);
  T.Run('key case insensitive', @TestKeyCaseInsensitive);
  { Whitespace }
  T.Run('trailing spaces preserved', @TestTrailingSpacesPreserved);
  T.Run('leading spaces trimmed', @TestLeadingSpacesTrimmed);
  { Duplicate keys }
  T.Run('duplicate key last wins', @TestDuplicateKeyLastWins);
  { ReadBool }
  T.Run('ReadBool all values', @TestReadBoolValues);
  T.Run('ReadBool default', @TestReadBoolDefault);
  { ReadInteger }
  T.Run('ReadInteger boundaries', @TestReadIntegerBoundaries);
  T.Run('ReadInteger invalid', @TestReadIntegerInvalid);
  { Empty section }
  T.Run('empty section', @TestEmptySection);
  { Malformed }
  T.Run('unclosed section bracket', @TestMalformedSectionNoClose);
  T.Run('malformed recovers', @TestMalformedRecovers);
  { Stress }
  T.Run('50 sections', @TestManySections);
  T.Run('100 keys', @TestManyKeys);
  { TryLoad }
  T.Run('TryLoadFromString success', @TestTryLoadFromStringSuccess);
  T.Run('TryLoadFromString failure', @TestTryLoadFromStringFailure);
  { IniStringify }
  T.Run('IniStringify function', @TestIniStringifyFunction);
  { IniParse }
  T.Run('IniParse convenience', @TestIniParseConvenience);
  { Write/Delete cycle }
  T.Run('write delete cycle', @TestWriteDeleteCycle);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
