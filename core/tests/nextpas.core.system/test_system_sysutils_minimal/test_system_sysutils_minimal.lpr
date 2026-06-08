program test_system_sysutils_minimal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.system.sysutils,
  nextpas.core.exception;

var
  T: TTestRunner;

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

procedure TestSameTextDelegatesToTextCompareOwner;
begin
  Check(nextpas.core.system.sysutils.SameText('CompilerProc', 'compilerproc'),
    'SameText should satisfy compiler case-insensitive symbol pressure');
  Check(nextpas.core.system.sysutils.SameText('Runtime-ABI', 'runtime-abi'),
    'SameText should compare ASCII letters without changing punctuation');
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

begin
  T := TTestRunner.Create('nextpas.core.system.sysutils minimal');
  T.Run('Format delegates to text contract', @TestFormatDelegatesToTextContract);
  T.Run('exception formatting aliases canonical root', @TestExceptionFormattingAliasesCanonicalRoot);
  T.Run('convert error alias canonical root', @TestConvertErrorAliasCanonicalRoot);
  T.Run('SameText delegates to text compare owner', @TestSameTextDelegatesToTextCompareOwner);
  T.Run('IntToStr delegates to text conversion owner', @TestIntToStrDelegatesToTextConvOwner);
  T.Summary;
end.
