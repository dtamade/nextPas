program test_os_env;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.os.env;

var
  T: TTestRunner;

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
end;

procedure Test_HasEnv_Exists;
begin
  Check(HasEnv('HOME'), 'HOME should exist');
end;

procedure Test_HasEnv_Missing;
begin
  Check(not HasEnv('NEXTPAS_TEST_NONEXISTENT_VAR_XYZ'), 'missing var should not exist');
end;

procedure Test_SetEnv_And_Get;
begin
  SetEnv('NEXTPAS_TEST_SET_VAR', 'hello_world');
  CheckEqual('hello_world', GetEnv('NEXTPAS_TEST_SET_VAR'), 'SetEnv then GetEnv');
end;

procedure Test_SetEnv_Overwrite;
begin
  SetEnv('NEXTPAS_TEST_OVERWRITE', 'first');
  SetEnv('NEXTPAS_TEST_OVERWRITE', 'second');
  CheckEqual('second', GetEnv('NEXTPAS_TEST_OVERWRITE'), 'SetEnv overwrites');
end;

procedure Test_SetEnv_Empty_Value;
begin
  SetEnv('NEXTPAS_TEST_EMPTY', '');
  Check(HasEnv('NEXTPAS_TEST_EMPTY'), 'empty value var should exist');
  CheckEqual('', GetEnv('NEXTPAS_TEST_EMPTY'), 'empty value returns empty');
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
  T.Summary;
end.
