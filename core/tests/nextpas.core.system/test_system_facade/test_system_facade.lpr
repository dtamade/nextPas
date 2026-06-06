program test_system_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.base,
  nextpas.core.system,
  nextpas.core.exception,
  nextpas.core.errors;

var
  T: TTestRunner;

procedure TestBaseAndSystemByteAliasesCoexist;
var
  LSystemBytes: nextpas.core.system.TBytes;
  LBaseBytes: nextpas.core.base.TBytes;
begin
  SetLength(LSystemBytes, 3);
  LSystemBytes[0] := 7;
  LSystemBytes[1] := 8;
  LSystemBytes[2] := 9;

  LBaseBytes := LSystemBytes;
  CheckEqual(Int64(3), Int64(Length(LBaseBytes)), 'system TBytes must be assignable to base TBytes');

  nextpas.core.system.ZeroMem(@LSystemBytes[0], Length(LSystemBytes));
  CheckEqual(Int64(0), Int64(LSystemBytes[0]), 'ZeroMem clears first byte');
  CheckEqual(Int64(0), Int64(LSystemBytes[1]), 'ZeroMem clears middle byte');
  CheckEqual(Int64(0), Int64(LSystemBytes[2]), 'ZeroMem clears last byte');
end;

procedure TestSystemMemoryGuardsDelegateToBaseContract;
var
  LCaught: Boolean;
begin
  nextpas.core.system.ZeroMem(nil, 0);

  LCaught := False;
  try
    nextpas.core.system.ZeroMem(nil, 1);
  except
    on E: nextpas.core.base.EArgumentNil do
      LCaught := E is nextpas.core.exception.ENextPasError;
  end;

  Check(LCaught, 'system ZeroMem must preserve base EArgumentNil guard');
end;

procedure TestCopyAndCompareFacadeDelegatesToBaseUtils;
var
  LSource: array[0..2] of Byte = (1, 2, 3);
  LTarget: array[0..2] of Byte = (0, 0, 0);
begin
  nextpas.core.system.CopyMem(@LTarget[0], @LSource[0], SizeOf(LSource));
  Check(nextpas.core.system.CompareMem(@LTarget[0], @LSource[0], SizeOf(LSource)),
    'system CopyMem/CompareMem should share base utils semantics');
end;

procedure TestSystemExceptionRootIsCanonical;
var
  LError: nextpas.core.system.ENextPasError;
begin
  LError := nextpas.core.system.ENextPasError.Create('system error');
  try
    Check(LError is nextpas.core.exception.ENextPasError,
      'system ENextPasError must be the canonical framework root');
    Check(LError.ClassType = nextpas.core.exception.ENextPasError,
      'system ENextPasError must not introduce a shadow subclass');
  finally
    LError.Free;
  end;
end;

procedure TestErrorsFacadeStillCatchesThroughSystemRoot;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise nextpas.core.errors.ETimeoutError.Create('timeout');
  except
    on E: nextpas.core.system.ENextPasError do
      LCaught := E.Category = nextpas.core.exception.ecTimeout;
  end;

  Check(LCaught, 'errors facade exceptions must catch through system root alias');
end;

begin
  T := TTestRunner.Create('nextpas.core.system facade');
  T.Run('base and system byte aliases coexist', @TestBaseAndSystemByteAliasesCoexist);
  T.Run('system memory guards delegate to base contract', @TestSystemMemoryGuardsDelegateToBaseContract);
  T.Run('copy and compare facade delegates to base utils', @TestCopyAndCompareFacadeDelegatesToBaseUtils);
  T.Run('system exception root is canonical', @TestSystemExceptionRootIsCanonical);
  T.Run('errors facade catches through system root', @TestErrorsFacadeStillCatchesThroughSystemRoot);
  T.Summary;
end.
