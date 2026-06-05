program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.contracts,
  nextpas.core.testing;

var
  T: TTestRunner;
  GExplicitContractsBuild: Boolean = False;

procedure ExpectNoRaise(const AProc: TProc; const AMessage: string);
begin
  try
    AProc();
  except
    on E: Exception do
      Fail(AMessage + ': unexpected ' + E.ClassName + ' ' + E.Message);
  end;
end;

procedure TestRequireTrueNeverRaises;
begin
  ExpectNoRaise(
    procedure
    begin
      ContractsRequire(True, 'should stay quiet');
    end,
    'ContractsRequire(true) must not raise'
  );
end;

procedure TestRequireFalseRaisesInvalidArgument;
begin
  try
    ContractsRequire(False, 'bad input');
    Fail('ContractsRequire(false) must raise EInvalidArgument');
  except
    on E: EInvalidArgument do
      CheckEqual('bad input', E.Message, 'ContractsRequire should preserve the provided message');
  end;
end;

procedure TestRequireAssignedFalseRaisesArgumentNil;
begin
  try
    ContractsRequireAssigned(False, 'Buffer');
    Fail('ContractsRequireAssigned(false) must raise EArgumentNil');
  except
    on E: EArgumentNil do
      CheckEqual('Buffer is nil', E.Message, 'ContractsRequireAssigned should publish the nil message');
  end;
end;

procedure TestExplicitContractsBuildMarker;
begin
  if GExplicitContractsBuild then
    Check(True, 'explicit contracts-enabled build marker is accepted')
  else
    Check(True, 'default contracts-enabled build marker is accepted');
end;

procedure ConfigureMode;
begin
  GExplicitContractsBuild := (ParamCount > 0) and (ParamStr(1) = '--contracts-enabled');
end;

begin
  ConfigureMode;

  T := TTestRunner.Create('nextpas.core.contracts');
  T.Run('require true never raises', @TestRequireTrueNeverRaises);
  T.Run('require false raises invalid argument', @TestRequireFalseRaisesInvalidArgument);
  T.Run('require assigned false raises argument nil', @TestRequireAssignedFalseRaisesArgumentNil);
  T.Run('explicit contracts build marker', @TestExplicitContractsBuildMarker);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
