program test_platform_env_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.env;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. platform_env_get: reading an existing variable (PATH) succeeds }
procedure TestEnvGetExisting;
var
  LBuf: array[0..4095] of AnsiChar;
  ALen: Int32;
  LResult: Int32;
begin
  LResult := platform_env_get('PATH', @LBuf[0], SizeOf(LBuf), ALen);
  Check(LResult = 0, 'platform_env_get(PATH) should return 0, got ' + IntToStr(LResult));
  Check(ALen > 0, 'PATH length should be > 0');
end;

{ 2. platform_env_get: reading a nonexistent variable returns error }
procedure TestEnvGetNonexistent;
var
  LBuf: array[0..255] of AnsiChar;
  ALen: Int32;
  LResult: Int32;
begin
  ALen := -1;
  LResult := platform_env_get('NON_EXISTENT_VAR_9999', @LBuf[0], SizeOf(LBuf), ALen);
  Check(LResult <> 0, 'platform_env_get(nonexistent) should return non-zero error, got ' + IntToStr(LResult));
  Check(ALen = 0, 'length should be 0 for nonexistent var');
end;

{ 3. platform_env_set then platform_env_get: round-trip verification }
procedure TestEnvSetThenGet;
var
  LBuf: array[0..255] of AnsiChar;
  ALen: Int32;
  LResult: Int32;
begin
  LResult := platform_env_set('WINE_TEST_VAR', 'hello_from_wine');
  Check(LResult = 0, 'platform_env_set should return 0, got ' + IntToStr(LResult));

  LResult := platform_env_get('WINE_TEST_VAR', @LBuf[0], SizeOf(LBuf), ALen);
  Check(LResult = 0, 'platform_env_get(WINE_TEST_VAR) should return 0, got ' + IntToStr(LResult));
  Check(ALen = 15, 'WINE_TEST_VAR length should be 15, got ' + IntToStr(ALen));
  Check(string(LBuf) = 'hello_from_wine', 'WINE_TEST_VAR value mismatch: got "' + string(LBuf) + '"');

  { Cleanup }
  platform_env_unset('WINE_TEST_VAR');
end;

{ 4. platform_env_unset: confirm variable no longer exists }
procedure TestEnvUnset;
var
  LResult: Int32;
begin
  { First ensure it exists by setting it }
  platform_env_set('WINE_UNSET_TEST', 'to_be_removed');

  LResult := platform_env_unset('WINE_UNSET_TEST');
  Check(LResult = 0, 'platform_env_unset should return 0, got ' + IntToStr(LResult));
  Check(not platform_env_exists('WINE_UNSET_TEST'), 'WINE_UNSET_TEST should not exist after unset');
end;

{ 5. platform_env_exists: PATH exists, fake does not }
procedure TestEnvExists;
begin
  Check(platform_env_exists('PATH'), 'PATH should exist');
  Check(not platform_env_exists('FAKE_VAR_9999'), 'FAKE_VAR_9999 should not exist');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.env.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('env_get existing variable (PATH)', @TestEnvGetExisting);
  T.Run('env_get nonexistent variable returns ENOENT', @TestEnvGetNonexistent);
  T.Run('env_set then env_get round-trip', @TestEnvSetThenGet);
  T.Run('env_unset removes variable', @TestEnvUnset);
  T.Run('env_exists for PATH and fake var', @TestEnvExists);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.