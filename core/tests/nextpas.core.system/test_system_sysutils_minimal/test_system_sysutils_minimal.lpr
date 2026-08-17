program test_system_sysutils_minimal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system.sysutils,
  nextpas.core.exception;

type
  IProbe = interface
    ['{A0B1C2D3-0001-4E5F-8A9B-0C0D0E0F0001}']
  end;

  IOther = interface
    ['{A0B1C2D3-0002-4E5F-8A9B-0C0D0E0F0002}']
  end;

  TProbe = class(TInterfacedObject, IProbe);

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

procedure TestSupportsInterfaceQuery;
var
  Probe: IProbe;
  Other: IProbe;
  NotImpl: IOther;
begin
  Probe := TProbe.Create;
  Check(nextpas.core.system.sysutils.Supports(Probe, IProbe, Other),
    'Supports should resolve implemented interface');
  Check(not nextpas.core.system.sysutils.Supports(Probe, IOther, NotImpl),
    'Supports should reject interface the object does not implement');
end;

procedure TestSplitStringSysUtilsSemantics;
var
  A: nextpas.core.system.sysutils.TStringArray;
begin
  A := nextpas.core.system.sysutils.SplitString('a,b,c', ',');
  Check((Length(A) = 3) and (A[0] = 'a') and (A[2] = 'c'),
    'SplitString should split on delimiter characters');
  A := nextpas.core.system.sysutils.SplitString('a,,b', ',');
  Check((Length(A) = 2) and (A[0] = 'a') and (A[1] = 'b'),
    'SplitString should drop empty segments from consecutive delimiters');
  A := nextpas.core.system.sysutils.SplitString('ab;cd', ';');
  Check((Length(A) = 2) and (A[1] = 'cd'),
    'SplitString should handle single trailing segment');
  A := nextpas.core.system.sysutils.SplitString('', ',');
  Check(Length(A) = 0, 'SplitString should return empty array for empty input');
  A := nextpas.core.system.sysutils.SplitString('x;y', ',;');
  Check((Length(A) = 2) and (A[0] = 'x') and (A[1] = 'y'),
    'SplitString should treat every delimiter character as a separator');
end;

{ StrUtils 语义：从 AFrom（1-based）起查找子串；空子串在有效范围命中 AFrom。 }
procedure TestPosExSysUtilsSemantics;
begin
  CheckEqual(7,
    nextpas.core.system.sysutils.PosEx('world', 'hello world', 1),
    'PosEx should find substring from start');
  CheckEqual(7,
    nextpas.core.system.sysutils.PosEx('world', 'hello world', 4),
    'PosEx should find substring when AFrom is before the match');
  CheckEqual(7,
    nextpas.core.system.sysutils.PosEx('world', 'hello world', 5),
    'PosEx should still match when AFrom is before the match');
  CheckEqual(2,
    nextpas.core.system.sysutils.PosEx('o', 'foo', 2),
    'PosEx should skip earlier occurrences');
  CheckEqual(0,
    nextpas.core.system.sysutils.PosEx('zz', 'abc', 1),
    'PosEx should return 0 on no match');
  CheckEqual(3,
    nextpas.core.system.sysutils.PosEx('', 'abc', 3),
    'empty substring should hit at AFrom within range');
  CheckEqual(4,
    nextpas.core.system.sysutils.PosEx('', 'abc', 4),
    'empty substring should hit at one-past-end');
  CheckEqual(0,
    nextpas.core.system.sysutils.PosEx('', 'abc', 5),
    'empty substring beyond range should miss');
  CheckEqual(0,
    nextpas.core.system.sysutils.PosEx('a', 'abc', 0),
    'AFrom below 1 should miss');
end;

{ AcquireExceptionObject：转移当前线程异常所有权（手动 Free，不泄漏）。 }
procedure TestAcquireExceptionObjectOwnership;
var
  LExc: Exception;
begin
  LExc := nil;
  try
    raise Exception.Create('ownership probe');
  except
    on E: Exception do
    begin
      LExc := Exception(nextpas.core.system.sysutils.AcquireExceptionObject);
      Check(LExc <> nil, 'AcquireExceptionObject should return the raised object');
      CheckEqual('ownership probe', LExc.Message,
        'transferred exception should keep its message');
    end;
  end;
  LExc.Free;
end;

{ RunProcessWait：参数数组逐项传递(空格安全),等退出返回退出码;
  stdin/stdout/stderr 接 /dev/null,不阻塞不残留。 }
procedure TestRunProcessWait;
begin
  CheckEqual(0, nextpas.core.system.sysutils.RunProcessWait('/bin/true', []),
    'true exits 0');
  CheckEqual(1, nextpas.core.system.sysutils.RunProcessWait('/bin/false', []),
    'false exits 1');
  { 空格安全的参数数组:sh -c 的整串必须作为单参数传递,拆开则语法错 }
  CheckEqual(7, nextpas.core.system.sysutils.RunProcessWait('/bin/sh',
    ['-c', 'exit 7']), 'args array keeps space-containing parameter intact');
  CheckEqual(-1, nextpas.core.system.sysutils.RunProcessWait(
    '/nonexistent-xyz-no-such', []), 'missing binary reports -1');
end;

{ CompareText：ASCII 不区分大小写比较，返回序数（FPC SysUtils 语义）。 }
procedure TestCompareText;
begin
  CheckEqual(0, nextpas.core.system.sysutils.CompareText('ABC', 'abc'),
    'CompareText should be case-insensitive equal');
  Check(nextpas.core.system.sysutils.CompareText('a', 'b') < 0,
    'CompareText should order ascending');
  Check(nextpas.core.system.sysutils.CompareText('b', 'a') > 0,
    'CompareText should report descending order');
end;

{ UnixToDateTime：Unix 秒(UTC) → 本地 TDateTime；0 = 1970-01-01（任一时区日期不变）。 }
procedure TestUnixToDateTime;
begin
  CheckEqual('1970-01-01',
    nextpas.core.system.sysutils.FormatDateTime('yyyy-mm-dd',
      nextpas.core.system.sysutils.UnixToDateTime(0)),
    'UnixToDateTime(0) should be the Unix epoch date');
end;

{ FreeAndNil：释放并置 nil（FPC SysUtils 语义，无类型 var）。 }
procedure TestFreeAndNil;
var
  LObj: TObject;
begin
  LObj := TObject.Create;
  nextpas.core.system.sysutils.FreeAndNil(LObj);
  Check(LObj = nil, 'FreeAndNil should nil the variable');
end;
procedure TestEncodeDateMatchesRtlEpoch;
begin
  Check(nextpas.core.system.sysutils.EncodeDate(1899, 12, 30) = 0,
    'EncodeDate should pin the RTL epoch 1899-12-30 to 0.0');
  Check(nextpas.core.system.sysutils.EncodeDate(1900, 1, 1) = 2,
    'EncodeDate should count days from epoch');
  Check(nextpas.core.system.sysutils.EncodeDate(2026, 8, 17) = 46251,
    'EncodeDate should match RTL value for modern ISO dates');
  Check(nextpas.core.system.sysutils.EncodeDate(2024, 2, 29) = 45351,
    'EncodeDate should handle leap days');
  Check(nextpas.core.system.sysutils.EncodeDate(9999, 12, 31) = 2958465,
    'EncodeDate should cover the full Word year range');
end;

procedure TestEncodeDateInvalidRaises;
begin
  try
    nextpas.core.system.sysutils.EncodeDate(2026, 2, 30);
    Check(False, 'EncodeDate should reject 2026-02-30');
  except
    on E: nextpas.core.exception.EConvertError do Check(True, 'EncodeDate raises EConvertError for bad day');
  end;
  try
    nextpas.core.system.sysutils.EncodeDate(2026, 13, 1);
    Check(False, 'EncodeDate should reject month 13');
  except
    on E: nextpas.core.exception.EConvertError do Check(True, 'EncodeDate raises EConvertError for bad month');
  end;
end;

procedure TestEncodeDateWholeDayDifference;
begin
  Check(Trunc(nextpas.core.system.sysutils.EncodeDate(2026, 8, 17) -
              nextpas.core.system.sysutils.EncodeDate(2026, 8, 17)) = 0,
    'whole-day difference should be 0 for same date');
  Check(Trunc(nextpas.core.system.sysutils.EncodeDate(2026, 8, 17) -
              nextpas.core.system.sysutils.EncodeDate(2026, 8, 16)) = 1,
    'whole-day difference should span yesterday');
  Check(Trunc(nextpas.core.system.sysutils.EncodeDate(2026, 8, 17) -
              nextpas.core.system.sysutils.EncodeDate(2026, 8, 18)) = -1,
    'whole-day difference should be negative for tomorrow');
  Check(Trunc(nextpas.core.system.sysutils.EncodeDate(2024, 3, 1) -
              nextpas.core.system.sysutils.EncodeDate(2024, 2, 28)) = 2,
    'whole-day difference should span leap years');
end;

{ DecodeDate/UnixDateDelta:日期分解与合成往返(SysUtils 语义)。
  EncodeDate 由 core 反哺(core TDate),此处验证门面组合一致。 }
procedure TestDecodeEncodeDate;
var
  Y, M, D: Word;
begin
  DecodeDate(nextpas.core.system.sysutils.EncodeDate(2026, 8, 17), Y, M, D);
  Check((Y = 2026) and (M = 8) and (D = 17),
    'EncodeDate/DecodeDate should roundtrip the civil date');
  Check(nextpas.core.system.sysutils.UnixDateDelta = 25569.0,
    'UnixDateDelta should be the TDateTime offset of the Unix epoch');
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
  T.Test('Supports queries interfaces', @TestSupportsInterfaceQuery);
  T.Test('SplitString follows SysUtils semantics', @TestSplitStringSysUtilsSemantics);
  T.Test('PosEx follows StrUtils semantics', @TestPosExSysUtilsSemantics);
  T.Test('AcquireExceptionObject transfers ownership', @TestAcquireExceptionObjectOwnership);
  T.Test('RunProcessWait execs with args array', @TestRunProcessWait);
  T.Test('CompareText is case-insensitive', @TestCompareText);
  T.Test('UnixToDateTime converts epoch', @TestUnixToDateTime);
  T.Test('FreeAndNil nils after free', @TestFreeAndNil);
  T.Test('DecodeDate/UnixDateDelta roundtrip', @TestDecodeEncodeDate);
  T.Test('EncodeDate matches RTL epoch values', @TestEncodeDateMatchesRtlEpoch);
  T.Test('EncodeDate rejects invalid dates', @TestEncodeDateInvalidRaises);
  T.Test('EncodeDate spans whole days', @TestEncodeDateWholeDayDifference);
  if not T.Run then Halt(1);
end.
