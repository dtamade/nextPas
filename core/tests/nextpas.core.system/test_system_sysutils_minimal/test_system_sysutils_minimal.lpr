program test_system_sysutils_minimal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system.sysutils,
  nextpas.core.exception;

var
  T: TTestSuite;

procedure TestFormatDelegatesToTextContract;
begin
  CheckEqual('value=42 text=nextpas',
    nextpas.core.system.sysutils.Format('value=%d text=%s', [42, 'nextpas']),
    'Format should cover compiler CreateFmt pressure');
end;

procedure TestExceptionFormattingAliasesCanonicalRoot;
var
  LExceptionClass: nextpas.core.system.sysutils.ExceptClass;
  LError: nextpas.core.system.sysutils.Exception;
begin
  LExceptionClass := nextpas.core.system.sysutils.EAssertionFailed;
  LError := LExceptionClass.CreateFmt('value=%d text=%s', [42, 'nextpas']);
  try
    Check(LError is nextpas.core.exception.EAssertionFailed,
      'EAssertionFailed should remain the canonical exception alias');
    CheckEqual('value=42 text=nextpas', LError.Message,
      'CreateFmt should preserve formatted exception messages');
  finally
    LError.Free;
  end;
end;

procedure TestConvertErrorAliasCanonicalRoot;
var
  LError: nextpas.core.system.sysutils.Exception;
begin
  LError := nextpas.core.system.sysutils.EConvertError.Create('conversion failed');
  try
    Check(LError is nextpas.core.exception.EConvertError,
      'EConvertError should remain the canonical conversion alias');
    CheckEqual('conversion failed', LError.Message,
      'EConvertError alias should preserve exception messages');
  finally
    LError.Free;
  end;
end;

procedure TestSameTextDelegatesToTextConvOwner;
begin
  Check(nextpas.core.system.sysutils.SameText('CompilerProc', 'compilerproc'),
    'SameText should satisfy compiler case-insensitive symbol pressure');
  Check(nextpas.core.system.sysutils.SameText('Runtime-ABI', 'runtime-abi'),
    'SameText should compare ASCII letters without changing punctuation');
  Check(nextpas.core.system.sysutils.SameText('', ''),
    'SameText should accept two empty strings');
  Check(not nextpas.core.system.sysutils.SameText('compiler', 'compiler-runtime'),
    'SameText should reject different lengths');
  Check(not nextpas.core.system.sysutils.SameText('compiler', 'runtime'),
    'SameText should reject different text');
end;

procedure TestIntToStrDelegatesToTextConvOwner;
begin
  CheckEqual('0', nextpas.core.system.sysutils.IntToStr(0),
    'IntToStr should cover zero labels and counters');
  CheckEqual('42', nextpas.core.system.sysutils.IntToStr(42),
    'IntToStr should cover compiler/runtime positive counter pressure');
  CheckEqual('-17', nextpas.core.system.sysutils.IntToStr(-17),
    'IntToStr should cover diagnostic negative values');
end;

procedure TestTrimDelegatesToTextConvOwner;
begin
  CheckEqual('compiler<T>', nextpas.core.system.sysutils.Trim('  compiler<T>  '),
    'Trim should cover compiler token normalization pressure');
  CheckEqual('runtime', nextpas.core.system.sysutils.Trim(#9'runtime'#10),
    'Trim should remove surrounding ASCII whitespace only');
  CheckEqual('', nextpas.core.system.sysutils.Trim('   '),
    'Trim should collapse all-whitespace input to empty text');
end;

procedure TestTryStrToIntDelegatesToTextConvOwner;
var
  VI: Integer;
  V64: Int64;
begin
  Check(nextpas.core.system.sysutils.TryStrToInt('42', VI)
    and (VI = 42), 'TryStrToInt should parse positive decimal');
  Check(nextpas.core.system.sysutils.TryStrToInt('-7', VI)
    and (VI = -7), 'TryStrToInt should parse negative decimal');
  Check(not nextpas.core.system.sysutils.TryStrToInt('abc', VI),
    'TryStrToInt should reject non-numeric input');
  Check(not nextpas.core.system.sysutils.TryStrToInt('', VI),
    'TryStrToInt should reject empty input');
  Check(nextpas.core.system.sysutils.TryStrToInt('123', VI)
    and (VI = 123), 'TryStrToInt should keep working after failures');
  Check(nextpas.core.system.sysutils.TryStrToInt64('9007199254740993', V64)
    and (V64 = 9007199254740993), 'TryStrToInt64 should span Int64 range');
  Check(not nextpas.core.system.sysutils.TryStrToInt64('not-a-number', V64),
    'TryStrToInt64 should reject non-numeric input');
  Check(not nextpas.core.system.sysutils.TryStrToInt64('99999999999999999999999', V64),
    'TryStrToInt64 should reject out-of-range input');
end;

procedure TestBoolToStrSysUtilsSemantics;
begin
  CheckEqual('True', nextpas.core.system.sysutils.BoolToStr(True, True),
    'BoolToStr with UseBoolStrs=True should emit True for true');
  CheckEqual('False', nextpas.core.system.sysutils.BoolToStr(False, True),
    'BoolToStr with UseBoolStrs=True should emit False for false');
  CheckEqual('1', nextpas.core.system.sysutils.BoolToStr(True),
    'BoolToStr default should emit 1 for true');
  CheckEqual('0', nextpas.core.system.sysutils.BoolToStr(False),
    'BoolToStr default should emit 0 for false');
end;

procedure TestCompareStrCaseSensitive;
begin
  Check(nextpas.core.system.sysutils.CompareStr('abc', 'abc') = 0,
    'CompareStr should return 0 for identical strings');
  Check(nextpas.core.system.sysutils.CompareStr('abc', 'abd') < 0,
    'CompareStr should order by byte value');
  Check(nextpas.core.system.sysutils.CompareStr('B', 'a') < 0,
    'CompareStr should be case-sensitive (uppercase before lowercase)');
  Check(nextpas.core.system.sysutils.CompareStr('z', 'a') > 0,
    'CompareStr should report greater for later characters');
  Check(nextpas.core.system.sysutils.CompareStr('ab', 'abc') < 0,
    'CompareStr should treat prefix as smaller');
end;

procedure TestTStringArrayAliasUsable;
var
  A: nextpas.core.system.sysutils.TStringArray;
begin
  SetLength(A, 2);
  A[0] := 'a';
  A[1] := 'b';
  Check((Length(A) = 2) and (A[1] = 'b'),
    'TStringArray should alias core dynamic string array');
end;

begin
  T := TTestSuite.Create('nextpas.core.system.sysutils minimal');
  T.Test('Format delegates to text contract', @TestFormatDelegatesToTextContract);
  T.Test('exception formatting aliases canonical root', @TestExceptionFormattingAliasesCanonicalRoot);
  T.Test('convert error alias canonical root', @TestConvertErrorAliasCanonicalRoot);
  T.Test('SameText delegates to text conversion owner', @TestSameTextDelegatesToTextConvOwner);
  T.Test('IntToStr delegates to text conversion owner', @TestIntToStrDelegatesToTextConvOwner);
  T.Test('Trim delegates to text conversion owner', @TestTrimDelegatesToTextConvOwner);
  T.Test('TryStrToInt/TryStrToInt64 delegate to conversion owner',
    @TestTryStrToIntDelegatesToTextConvOwner);
  T.Test('BoolToStr follows SysUtils semantics', @TestBoolToStrSysUtilsSemantics);
  T.Test('CompareStr is case-sensitive', @TestCompareStrCaseSensitive);
  T.Test('TStringArray alias is usable', @TestTStringArrayAliasUsable);
  if not T.Run then Halt(1);
end.
