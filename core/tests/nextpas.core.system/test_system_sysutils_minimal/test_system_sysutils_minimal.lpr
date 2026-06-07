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

begin
  T := TTestRunner.Create('nextpas.core.system.sysutils minimal');
  T.Run('Format delegates to text contract', @TestFormatDelegatesToTextContract);
  T.Run('exception formatting aliases canonical root', @TestExceptionFormattingAliasesCanonicalRoot);
  T.Summary;
end.
