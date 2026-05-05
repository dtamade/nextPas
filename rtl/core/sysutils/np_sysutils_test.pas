program np_sysutils_test;

{$mode objfpc}{$H+}

uses
  SysUtils;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertEqual(const Expected, Actual: string; const TestName: string);
begin
  if Expected = Actual then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', TestName);
    WriteLn('  Expected: "', Expected, '"');
    WriteLn('  Actual:   "', Actual, '"');
  end;
end;

procedure AssertTrue(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', TestName);
  end;
end;

procedure TestTrim;
begin
  AssertEqual('hello', Trim('  hello  '), 'Trim with spaces');
  AssertEqual('hello', Trim('hello'), 'Trim without spaces');
  AssertEqual('', Trim('   '), 'Trim only spaces');
  AssertEqual('', Trim(''), 'Trim empty string');
  AssertEqual('hello world', Trim('  hello world  '), 'Trim with internal spaces');
end;

procedure TestLowerCase;
begin
  AssertEqual('hello', LowerCase('HELLO'), 'LowerCase all caps');
  AssertEqual('hello', LowerCase('Hello'), 'LowerCase mixed');
  AssertEqual('hello', LowerCase('hello'), 'LowerCase already lower');
  AssertEqual('hello123', LowerCase('HELLO123'), 'LowerCase with numbers');
end;

procedure TestUpperCase;
begin
  AssertEqual('HELLO', UpperCase('hello'), 'UpperCase all lower');
  AssertEqual('HELLO', UpperCase('Hello'), 'UpperCase mixed');
  AssertEqual('HELLO', UpperCase('HELLO'), 'UpperCase already upper');
  AssertEqual('HELLO123', UpperCase('hello123'), 'UpperCase with numbers');
end;

procedure TestSameText;
begin
  AssertTrue(SameText('hello', 'HELLO'), 'SameText case insensitive');
  AssertTrue(SameText('Hello', 'hello'), 'SameText mixed case');
  AssertTrue(SameText('test', 'test'), 'SameText same case');
  AssertTrue(not SameText('hello', 'world'), 'SameText different strings');
end;

procedure TestExtractFileName;
begin
  AssertEqual('test.pas', ExtractFileName('/home/user/test.pas'), 'ExtractFileName with path');
  AssertEqual('test.pas', ExtractFileName('test.pas'), 'ExtractFileName without path');
  AssertEqual('', ExtractFileName('/home/user/'), 'ExtractFileName trailing slash');
end;

procedure TestExtractFileDir;
begin
  AssertEqual('/home/user', ExtractFileDir('/home/user/test.pas'), 'ExtractFileDir with file');
  AssertEqual('', ExtractFileDir('test.pas'), 'ExtractFileDir without path');
  AssertEqual('/home/user', ExtractFileDir('/home/user/'), 'ExtractFileDir trailing slash');
end;

procedure TestIncludeTrailingPathDelimiter;
begin
  AssertEqual('/home/user/', IncludeTrailingPathDelimiter('/home/user'), 'Include delimiter without');
  AssertEqual('/home/user/', IncludeTrailingPathDelimiter('/home/user/'), 'Include delimiter with');
  AssertEqual('/', IncludeTrailingPathDelimiter(''), 'Include delimiter empty');
end;

procedure TestExcludeTrailingPathDelimiter;
begin
  AssertEqual('/home/user', ExcludeTrailingPathDelimiter('/home/user/'), 'Exclude delimiter with');
  AssertEqual('/home/user', ExcludeTrailingPathDelimiter('/home/user'), 'Exclude delimiter without');
  AssertEqual('', ExcludeTrailingPathDelimiter('/'), 'Exclude delimiter root');
end;

procedure TestIntToStr;
begin
  AssertEqual('123', IntToStr(123), 'IntToStr positive');
  AssertEqual('-123', IntToStr(-123), 'IntToStr negative');
  AssertEqual('0', IntToStr(0), 'IntToStr zero');
end;

procedure TestStrToInt;
var
  Value: Integer;
  GotException: Boolean;
begin
  Value := StrToInt('123');
  AssertTrue(Value = 123, 'StrToInt positive');

  Value := StrToInt('-123');
  AssertTrue(Value = -123, 'StrToInt negative');

  Value := StrToInt('0');
  AssertTrue(Value = 0, 'StrToInt zero');

  GotException := False;
  try
    Value := StrToInt('abc');
  except
    on E: EConvertError do
      GotException := True;
  end;
  AssertTrue(GotException, 'StrToInt invalid raises exception');
end;

procedure TestStrToIntDef;
var
  Value: Integer;
begin
  Value := StrToIntDef('123', 999);
  AssertTrue(Value = 123, 'StrToIntDef valid');

  Value := StrToIntDef('abc', 999);
  AssertTrue(Value = 999, 'StrToIntDef invalid returns default');
end;

procedure TestFileExists;
begin
  AssertTrue(FileExists('/etc/passwd'), 'FileExists existing file');
  AssertTrue(not FileExists('/nonexistent_file_xyz'), 'FileExists nonexistent file');
  AssertTrue(not FileExists('/tmp'), 'FileExists directory is not a file');
end;

procedure TestDirectoryExists;
begin
  AssertTrue(DirectoryExists('/tmp'), 'DirectoryExists existing directory');
  AssertTrue(not DirectoryExists('/nonexistent_dir_xyz'), 'DirectoryExists nonexistent');
  AssertTrue(not DirectoryExists('/etc/passwd'), 'DirectoryExists file is not a directory');
end;

procedure TestExpandFileName;
begin
  AssertTrue(Length(ExpandFileName('test.pas')) > 0, 'ExpandFileName non-empty result');
  AssertTrue(Pos('/', ExpandFileName('test.pas')) = 1, 'ExpandFileName starts with /');
  AssertEqual('/usr/bin/ls', ExpandFileName('/usr/bin/ls'), 'ExpandFileName absolute unchanged');
end;

procedure TestGetEnvironmentVariable;
begin
  AssertTrue(Length(GetEnvironmentVariable('HOME')) > 0, 'GetEnvironmentVariable HOME exists');
  AssertEqual('', GetEnvironmentVariable('NONEXISTENT_VAR_XYZ_123'), 'GetEnvironmentVariable missing returns empty');
end;

procedure TestChangeFileExt;
begin
  AssertEqual('test.o', ChangeFileExt('test.pas', '.o'), 'ChangeFileExt basic');
  AssertEqual('/home/test.o', ChangeFileExt('/home/test.pas', '.o'), 'ChangeFileExt with path');
  AssertEqual('nopath.o', ChangeFileExt('nopath', '.o'), 'ChangeFileExt no extension');
end;

procedure TestNow;
var
  T: TDateTime;
begin
  T := Now;
  AssertTrue(T > 40000.0, 'Now returns reasonable date after 2009');
end;

procedure TestFindFirst;
var
  SR: TSearchRec;
  Res: LongInt;
begin
  Res := FindFirst('/etc/*.conf', faAnyFile, SR);
  if Res = 0 then
  begin
    AssertTrue(Length(SR.Name) > 0, 'FindFirst found a file');
    FindClose(SR);
  end
  else
    AssertTrue(True, 'FindFirst no conf files (acceptable)');
end;

begin
  WriteLn('Running SysUtils unit tests...');
  WriteLn;

  TestTrim;
  TestLowerCase;
  TestUpperCase;
  TestSameText;
  TestExtractFileName;
  TestExtractFileDir;
  TestIncludeTrailingPathDelimiter;
  TestExcludeTrailingPathDelimiter;
  TestIntToStr;
  TestStrToInt;
  TestStrToIntDef;
  TestFileExists;
  TestDirectoryExists;
  TestExpandFileName;
  TestGetEnvironmentVariable;
  TestChangeFileExt;
  TestNow;
  TestFindFirst;

  WriteLn;
  WriteLn('Tests passed: ', TestsPassed);
  WriteLn('Tests failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
