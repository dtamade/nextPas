program test_text;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text;

var
  T: TTestRunner;

procedure TestTrim;
begin
  CheckEqual('hello', TextTrim('  hello  '), 'both sides');
  CheckEqual('hello', TextTrim('hello'), 'no whitespace');
  CheckEqual('', TextTrim('   '), 'all whitespace');
  CheckEqual('', TextTrim(''), 'empty');
end;

procedure TestTrimLeft;
begin
  CheckEqual('hello  ', TextTrimLeft('  hello  '), 'left only');
  CheckEqual('', TextTrimLeft(''), 'empty');
end;

procedure TestTrimRight;
begin
  CheckEqual('  hello', TextTrimRight('  hello  '), 'right only');
  CheckEqual('', TextTrimRight(''), 'empty');
end;

procedure TestStartsWith;
begin
  Check(TextStartsWith('hello world', 'hello'), 'prefix match');
  Check(not TextStartsWith('hello world', 'world'), 'no prefix');
  Check(TextStartsWith('hello', ''), 'empty prefix');
  Check(not TextStartsWith('', 'x'), 'empty value');
end;

procedure TestEndsWith;
begin
  Check(TextEndsWith('hello world', 'world'), 'suffix match');
  Check(not TextEndsWith('hello world', 'hello'), 'no suffix');
  Check(TextEndsWith('hello', ''), 'empty suffix');
end;

{ PLACEHOLDER_TEST_PART2 }

begin
  T := TTestRunner.Create('nextpas.core.text');
  T.Run('Trim', @TestTrim);
  T.Run('TrimLeft', @TestTrimLeft);
  T.Run('TrimRight', @TestTrimRight);
  T.Run('StartsWith', @TestStartsWith);
  T.Run('EndsWith', @TestEndsWith);
  T.Run('Contains', @TestContains);
  T.Run('Split', @TestSplit);
  T.Run('Join', @TestJoin);
  T.Run('Replace', @TestReplace);
  T.Run('ReplaceAll', @TestReplaceAll);
  T.Run('ToUpper', @TestToUpper);
  T.Run('ToLower', @TestToLower);
  T.Run('PadLeft', @TestPadLeft);
  T.Run('PadRight', @TestPadRight);
  T.Run('Repeat', @TestRepeat);
  T.Run('IndexOf', @TestIndexOf);
  T.Run('LastIndexOf', @TestLastIndexOf);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('IsBlank', @TestIsBlank);
  T.Run('UTF8Length', @TestUTF8Length);
  T.Run('UTF8CodePointAt', @TestUTF8CodePointAt);
  T.Summary;
end.
