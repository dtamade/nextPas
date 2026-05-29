program test_fpc_sysutils;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fpc.sysutils,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestIntToStr;
begin
  Check(IntToStr(0) = '0', '0');
  Check(IntToStr(42) = '42', '42');
  Check(IntToStr(-1) = '-1', '-1');
  Check(IntToStr(Int64(9223372036854775807)) = '9223372036854775807', 'max');
end;

procedure TestStrToInt;
var LI: Longint;
begin
  Check(StrToInt('42') = 42, '42');
  Check(StrToInt('-100') = -100, '-100');
  Check(TryStrToInt('abc', LI) = False, 'invalid');
  Check(StrToIntDef('bad', 99) = 99, 'default');
end;

procedure TestIntToHex;
begin
  Check(IntToHex(255, 2) = 'FF', 'FF');
  Check(IntToHex(255, 4) = '00FF', '00FF');
  Check(IntToHex(Int64($DEADBEEF), 8) = 'DEADBEEF', 'DEADBEEF');
end;

procedure TestSameText;
begin
  Check(SameText('Hello', 'hello'), 'hello');
  Check(SameText('TObject', 'TOBJECT'), 'TObject');
  Check(not SameText('foo', 'bar'), 'foo<>bar');
  Check(SameText('', ''), 'empty');
end;

procedure TestCompareStr;
begin
  Check(CompareStr('abc', 'abc') = 0, 'equal');
  Check(CompareStr('abc', 'abd') < 0, 'less');
  Check(CompareStr('abd', 'abc') > 0, 'greater');
  Check(CompareStr('ab', 'abc') < 0, 'shorter');
end;

procedure TestTrim;
begin
  Check(Trim('  hello  ') = 'hello', 'both');
  Check(TrimLeft('  hi') = 'hi', 'left');
  Check(TrimRight('hi  ') = 'hi', 'right');
  Check(Trim('') = '', 'empty');
end;

procedure TestCase;
begin
  Check(UpperCase('hello') = 'HELLO', 'upper');
  Check(LowerCase('HELLO') = 'hello', 'lower');
  Check(UpperCase('123') = '123', 'digits unchanged');
end;

procedure TestExtractFilePath;
begin
  Check(ExtractFilePath('/usr/bin/fpc') = '/usr/bin/', 'path');
  Check(ExtractFileDir('/usr/bin/fpc') = '/usr/bin', 'dir');
  Check(ExtractFileName('/usr/bin/fpc') = 'fpc', 'name');
  Check(ExtractFileExt('/home/test.pas') = '.pas', 'ext');
end;

procedure TestChangeFileExt;
begin
  Check(ChangeFileExt('test.pas', '.ppu') = 'test.ppu', 'change');
  Check(ChangeFileExt('noext', '.o') = 'noext.o', 'add');
end;

procedure TestExpandFileName;
begin
  Check(ExpandFileName('/tmp') = '/tmp', 'absolute unchanged');
  Check(Length(ExpandFileName('.')) > 1, 'relative expands');
end;

procedure TestPathDelimiters;
begin
  Check(IncludeTrailingPathDelimiter('/usr') = '/usr/', 'include');
  Check(IncludeTrailingPathDelimiter('/usr/') = '/usr/', 'already');
  Check(ExcludeTrailingPathDelimiter('/usr/') = '/usr', 'exclude');
  Check(ExcludeTrailingPathDelimiter('/usr') = '/usr', 'no change');
end;

procedure TestConcatPaths;
begin
  Check(ConcatPaths(['build', 'units', 'system.ppu']) = 'build/units/system.ppu', 'concat3');
  Check(ConcatPaths(['/opt', 'fpc']) = '/opt/fpc', 'concat2');
end;

procedure TestFileOps;
begin
  Check(DirectoryExists('/tmp'), '/tmp exists');
  Check(not FileExists('/nonexistent_xyz_999'), 'not exists');
  Check(ForceDirectories('/tmp/nextpas_fpc_test_dir/sub'), 'mkdir_p');
  Check(DirectoryExists('/tmp/nextpas_fpc_test_dir/sub'), 'created');
end;

procedure TestEnvAndTemp;
var S: string;
begin
  S := GetEnvironmentVariable('PATH');
  Check(Length(S) > 0, 'PATH not empty');
  S := GetTempDir;
  Check(Length(S) > 0, 'tempdir not empty');
  Check(S[Length(S)] = '/', 'tempdir trailing /');
end;

procedure TestFormat;
begin
  Check(Format('hello %s', ['world']) = 'hello world', 'string');
  Check(Format('line %d col %d', [42, 7]) = 'line 42 col 7', 'ints');
  Check(Format('%x', [255]) = 'FF', 'hex');
  Check(Format('empty', []) = 'empty', 'no args');
end;

procedure TestStringReplace;
begin
  Check(StringReplace('hello world', 'world', 'pascal', []) = 'hello pascal', 'basic');
  Check(StringReplace('aaa', 'a', 'bb', [rfReplaceAll]) = 'bbbbbb', 'replace all');
  Check(StringReplace('Hello', 'hello', 'HI', [rfIgnoreCase]) = 'HI', 'ignore case');
  Check(StringReplace('abc', 'x', 'y', []) = 'abc', 'no match');
end;

procedure TestBoolToStr;
begin
  Check(BoolToStr(True, True) = 'True', 'true');
  Check(BoolToStr(False, True) = 'False', 'false');
  Check(BoolToStr(True) = '-1', 'true numeric');
  Check(BoolToStr(False) = '0', 'false numeric');
end;

procedure TestIsValidIdent;
begin
  Check(IsValidIdent('MyVar'), 'MyVar');
  Check(IsValidIdent('_private'), '_private');
  Check(not IsValidIdent('123abc'), 'starts with digit');
  Check(not IsValidIdent(''), 'empty');
  Check(IsValidIdent('unit.name', True), 'dotted');
  Check(not IsValidIdent('unit.name', False), 'no dots');
end;

procedure TestQuotedStr;
begin
  Check(QuotedStr('hello') = '''hello''', 'basic');
  Check(QuotedStr('it''s') = '''it''''s''', 'escape');
  Check(QuotedStr('') = '''''', 'empty');
end;

procedure TestFindFirst;
var
  SR: TSearchRec;
  LCount: Integer;
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  ForceDirectories('/tmp/nextpas_find_test');
  platform_file_open('/tmp/nextpas_find_test/a.pas', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, W);
  platform_file_close(H);
  platform_file_open('/tmp/nextpas_find_test/b.pas', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('y'), 1, W);
  platform_file_close(H);
  platform_file_open('/tmp/nextpas_find_test/c.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('z'), 1, W);
  platform_file_close(H);

  LCount := 0;
  if FindFirst('/tmp/nextpas_find_test/*.pas', faAnyFile, SR) = 0 then
  begin
    repeat
      Inc(LCount);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  Check(LCount = 2, 'found 2 .pas files');

  platform_file_unlink('/tmp/nextpas_find_test/a.pas');
  platform_file_unlink('/tmp/nextpas_find_test/b.pas');
  platform_file_unlink('/tmp/nextpas_find_test/c.txt');
  platform_file_rmdir('/tmp/nextpas_find_test');
end;

procedure TestDateTime;
var
  DT: TDateTime;
  S: string;
begin
  DT := Now;
  Check(DT > 45000, 'Now > 2023');
  S := FormatDateTime('yyyymmddhhnnsszzz', DT);
  Check(Length(S) = 17, 'format length = 17');
  Check(S[1] = '2', 'starts with 2 (year 2xxx)');
  Check(S[2] = '0', 'year 20xx');
end;

begin
  T := TTestRunner.Create('nextpas.core.fpc.sysutils');
  T.Run('IntToStr', @TestIntToStr);
  T.Run('StrToInt', @TestStrToInt);
  T.Run('IntToHex', @TestIntToHex);
  T.Run('SameText', @TestSameText);
  T.Run('CompareStr', @TestCompareStr);
  T.Run('Trim', @TestTrim);
  T.Run('UpperCase/LowerCase', @TestCase);
  T.Run('ExtractFilePath/Dir/Name/Ext', @TestExtractFilePath);
  T.Run('ChangeFileExt', @TestChangeFileExt);
  T.Run('ExpandFileName', @TestExpandFileName);
  T.Run('PathDelimiters', @TestPathDelimiters);
  T.Run('ConcatPaths', @TestConcatPaths);
  T.Run('FileOps', @TestFileOps);
  T.Run('Env+Temp', @TestEnvAndTemp);
  T.Run('Format', @TestFormat);
  T.Run('StringReplace', @TestStringReplace);
  T.Run('BoolToStr', @TestBoolToStr);
  T.Run('IsValidIdent', @TestIsValidIdent);
  T.Run('QuotedStr', @TestQuotedStr);
  T.Run('FindFirst/Next/Close', @TestFindFirst);
  T.Run('Now/FormatDateTime', @TestDateTime);
  T.Summary;
end.
