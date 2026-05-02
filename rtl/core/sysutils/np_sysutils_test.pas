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

begin
  WriteLn('Running SysUtils unit tests...');
  WriteLn;

  TestTrim;
  TestLowerCase;
  TestUpperCase;
  TestExtractFileName;
  TestExtractFileDir;
  TestIncludeTrailingPathDelimiter;
  TestExcludeTrailingPathDelimiter;
  TestIntToStr;
  TestStrToInt;
  TestStrToIntDef;

  WriteLn;
  WriteLn('Tests passed: ', TestsPassed);
  WriteLn('Tests failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
