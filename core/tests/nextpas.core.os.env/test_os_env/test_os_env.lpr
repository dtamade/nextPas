program test_os_env;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.os.env;

var
  T: TTestRunner;

{ --- existing tests --- }

procedure Test_GetEnv_HOME;
var V: string;
begin
  V := GetEnv('HOME');
  Check(V <> '', 'HOME should not be empty');
  Check(V[1] = '/', 'HOME should start with /');
end;

procedure Test_GetEnv_Missing;
var V: string;
begin
  V := GetEnv('NEXTPAS_TEST_NONEXISTENT_VAR_XYZ');
  CheckEqual('', V, 'missing var returns empty string');
end;

procedure Test_GetEnvironmentVariable_Compat;
var V: string;
begin
  V := GetEnvironmentVariable('PATH');
  Check(V <> '', 'PATH should not be empty');
  Check(V[1] = '/', 'PATH should start with /');
end;

procedure Test_HasEnv_Exists;
begin
  Check(HasEnv('HOME'), 'HOME should exist');
  Check(HasEnv('PATH'), 'PATH should exist');
end;

procedure Test_HasEnv_Missing;
begin
  Check(not HasEnv('NEXTPAS_TEST_NONEXISTENT_VAR_XYZ'),
    'non-existent var should return false');
end;

procedure Test_SetEnv_And_Get;
begin
  SetEnv('NEXTPAS_TEST_SETENV', 'test_value');
  CheckEqual('test_value', GetEnv('NEXTPAS_TEST_SETENV'),
    'SetEnv stores and GetEnv retrieves');
  UnsetEnv('NEXTPAS_TEST_SETENV');
end;

procedure Test_SetEnv_Overwrite;
begin
  SetEnv('NEXTPAS_TEST_OVERWRITE', 'v1');
  CheckEqual('v1', GetEnv('NEXTPAS_TEST_OVERWRITE'));
  SetEnv('NEXTPAS_TEST_OVERWRITE', 'v2');
  CheckEqual('v2', GetEnv('NEXTPAS_TEST_OVERWRITE'));
  UnsetEnv('NEXTPAS_TEST_OVERWRITE');
end;

procedure Test_SetEnv_Empty_Value;
begin
  SetEnv('NEXTPAS_TEST_EMPTY', '');
  Check(HasEnv('NEXTPAS_TEST_EMPTY'), 'empty value var should exist');
  CheckEqual('', GetEnv('NEXTPAS_TEST_EMPTY'), 'empty value returns empty');
  UnsetEnv('NEXTPAS_TEST_EMPTY');
end;

procedure Test_UnsetEnv;
begin
  SetEnv('NEXTPAS_TEST_UNSET', 'to_remove');
  Check(HasEnv('NEXTPAS_TEST_UNSET'), 'var should exist before unset');
  UnsetEnv('NEXTPAS_TEST_UNSET');
  Check(not HasEnv('NEXTPAS_TEST_UNSET'), 'var should not exist after unset');
  CheckEqual('', GetEnv('NEXTPAS_TEST_UNSET'), 'unset var returns empty');
end;

procedure Test_UnsetEnv_NonExistent;
begin
  UnsetEnv('NEXTPAS_TEST_NEVER_SET_XYZ');
  Check(not HasEnv('NEXTPAS_TEST_NEVER_SET_XYZ'), 'unset nonexistent is safe');
end;

{ --- ExpandEnv tests --- }

procedure Test_ExpandEnv_Basic;
begin
  SetEnv('NEXTPAS_TEST_EXPAND', 'hello');
  CheckEqual('hello', ExpandEnv('${NEXTPAS_TEST_EXPAND}'),
    'ExpandEnv expands ${VAR}');
  UnsetEnv('NEXTPAS_TEST_EXPAND');
end;

procedure Test_ExpandEnv_NotFound;
begin
  { Unset the variable so it definitely does not exist }
  UnsetEnv('NEXTPAS_TEST_MISSING_XYZ');
  { Missing var expands to empty string: prefix + empty + suffix }
  CheckEqual('prefix::suffix', ExpandEnv('prefix:${NEXTPAS_TEST_MISSING_XYZ}:suffix'),
    'missing var becomes empty');
end;

procedure Test_ExpandEnv_Adjacent;
begin
  SetEnv('NEXTPAS_TEST_A', '1');
  SetEnv('NEXTPAS_TEST_B', '2');
  CheckEqual('1 and 2', ExpandEnv('${NEXTPAS_TEST_A} and ${NEXTPAS_TEST_B}'),
    'adjacent vars expand correctly');
  UnsetEnv('NEXTPAS_TEST_A');
  UnsetEnv('NEXTPAS_TEST_B');
end;

procedure Test_ExpandEnv_NoMarkers;
begin
  CheckEqual('plain text', ExpandEnv('plain text'),
    'no markers returns unchanged');
end;

procedure Test_ExpandEnv_Unterminated;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    ExpandEnv('bad ${NEXTPAS_TEST_EXPAND');
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'unterminated placeholder raises EArgumentError');
end;

procedure Test_ExpandEnv_InvalidName;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    ExpandEnv('${}');
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'empty var name raises EArgumentError');
end;

{ --- main --- }

begin
  T := TTestRunner.Create('nextpas.core.os.env');
  T.Run('GetEnv_HOME', @Test_GetEnv_HOME);
  T.Run('GetEnv_Missing', @Test_GetEnv_Missing);
  T.Run('GetEnvironmentVariable_Compat', @Test_GetEnvironmentVariable_Compat);
  T.Run('HasEnv_Exists', @Test_HasEnv_Exists);
  T.Run('HasEnv_Missing', @Test_HasEnv_Missing);
  T.Run('SetEnv_And_Get', @Test_SetEnv_And_Get);
  T.Run('SetEnv_Overwrite', @Test_SetEnv_Overwrite);
  T.Run('SetEnv_Empty_Value', @Test_SetEnv_Empty_Value);
  T.Run('UnsetEnv', @Test_UnsetEnv);
  T.Run('UnsetEnv_NonExistent', @Test_UnsetEnv_NonExistent);
  T.Run('ExpandEnv_Basic', @Test_ExpandEnv_Basic);
  T.Run('ExpandEnv_NotFound', @Test_ExpandEnv_NotFound);
  T.Run('ExpandEnv_Adjacent', @Test_ExpandEnv_Adjacent);
  T.Run('ExpandEnv_NoMarkers', @Test_ExpandEnv_NoMarkers);
  T.Run('ExpandEnv_Unterminated', @Test_ExpandEnv_Unterminated);
  T.Run('ExpandEnv_InvalidName', @Test_ExpandEnv_InvalidName);
  T.Summary;
end.