program test_platform_resource;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.resource,
  nextpas.core.platform.resource.base;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure TestGetOpenFilesLimit;
var
  LLimit: TPlatformResourceLimit;
  LError: Int32;
begin
  FillChar(LLimit, SizeOf(LLimit), 0);
  LError := platform_resource_get_limit(prlkOpenFiles, LLimit);

  {$IFDEF NEXTPAS_WINDOWS}
  Check(LError = PLATFORM_RESOURCE_ERROR_UNSUPPORTED,
    'Windows must return the stable unsupported code for rlimit');
  Check(LLimit.Current = 0, 'unsupported get must clear current limit');
  Check(LLimit.Maximum = 0, 'unsupported get must clear maximum limit');
  {$ELSEIF defined(NEXTPAS_LINUX)}
  Check(LError = 0, 'Linux must get RLIMIT_NOFILE');
  Check(LLimit.Current > 0, 'open-file soft limit must be positive');
  Check(LLimit.Maximum >= LLimit.Current,
    'open-file hard limit must be at least the soft limit');
  {$ELSE}
  Check(LError = PLATFORM_RESOURCE_ERROR_UNSUPPORTED,
    'unpromoted hosts must return unsupported until their rlimit ABI is proven');
  {$ENDIF}
end;

procedure TestSetOpenFilesLimitToSameValue;
var
  LLimit: TPlatformResourceLimit;
  LAfter: TPlatformResourceLimit;
  LError: Int32;
begin
  FillChar(LLimit, SizeOf(LLimit), 0);
  FillChar(LAfter, SizeOf(LAfter), 0);
  LError := platform_resource_get_limit(prlkOpenFiles, LLimit);

  {$IFDEF NEXTPAS_LINUX}
  Check(LError = 0, 'Linux must get open-file limit before set');
  LError := platform_resource_set_limit(prlkOpenFiles, LLimit);
  Check(LError = 0, 'setting the existing open-file limit must succeed');
  LError := platform_resource_get_limit(prlkOpenFiles, LAfter);
  Check(LError = 0, 'Linux must get open-file limit after set');
  Check(LAfter.Current = LLimit.Current,
    'setting the same soft limit must preserve current value');
  Check(LAfter.Maximum = LLimit.Maximum,
    'setting the same hard limit must preserve maximum value');
  {$ELSE}
  Check(LError = PLATFORM_RESOURCE_ERROR_UNSUPPORTED,
    'unpromoted hosts must not pretend setrlimit exists');
  LError := platform_resource_set_limit(prlkOpenFiles, LLimit);
  Check(LError = PLATFORM_RESOURCE_ERROR_UNSUPPORTED,
    'unpromoted hosts must return unsupported for setrlimit');
  {$ENDIF}
end;

procedure TestInvalidLimitKind;
var
  LLimit: TPlatformResourceLimit;
  LError: Int32;
  LInvalidKind: TPlatformResourceLimitKind;
  LInvalidOrd: Int32;
begin
  FillChar(LLimit, SizeOf(LLimit), 0);
  LInvalidOrd := Ord(High(TPlatformResourceLimitKind)) + 1;
  LInvalidKind := TPlatformResourceLimitKind(LInvalidOrd);

  LError := platform_resource_get_limit(
    LInvalidKind, LLimit);
  Check(LError = PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT,
    'invalid limit kind must return the stable invalid-argument code');

  LError := platform_resource_set_limit(
    LInvalidKind, LLimit);
  Check(LError = PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT,
    'invalid set limit kind must return the stable invalid-argument code');
end;

procedure TestInvalidLimitValues;
var
  LLimit: TPlatformResourceLimit;
  LError: Int32;
begin
  LLimit.Current := 2;
  LLimit.Maximum := 1;

  LError := platform_resource_set_limit(prlkOpenFiles, LLimit);
  Check(LError = PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT,
    'current limit greater than maximum must return invalid argument before host dispatch');
end;

procedure TestAndroidResourceSourceContract;
var
  LResource: string;
  LAndroidBase: string;
  LPosixFfi: string;
begin
  LResource := LoadSourceText('src/nextpas.core.platform.resource.pas');
  LAndroidBase := LoadSourceText('src/nextpas.core.platform.android.base.pas');
  LPosixFfi := LoadSourceText('src/nextpas.core.platform.posix' + '.ffi.pas');

  CheckContains(LAndroidBase, 'tplatformandroidrlimit = record',
    'Android base owner must carry rlimit layout');
  CheckContains(LAndroidBase, 'rlimit_nofile = 7',
    'Android base owner must carry NDK RLIMIT_NOFILE value');
  CheckContains(LAndroidBase, 'rlimit_as = 9',
    'Android base owner must carry NDK RLIMIT_AS value');
  CheckContains(LPosixFfi, 'function getrlimit',
    'shared POSIX FFI must own raw getrlimit');
  CheckContains(LPosixFfi, 'function setrlimit',
    'shared POSIX FFI must own raw setrlimit');
  CheckContains(LResource, '{$if defined(nextpas_linux) or defined(nextpas_android)}',
    'platform.resource must promote Android into the rlimit implementation branch');
  CheckContains(LResource, 'nextpas.core.platform.android.base',
    'platform.resource Android branch must consume Android host base owner');
  CheckContains(LResource, 'tplatformandroidrlimit',
    'platform.resource Android branch must use Android rlimit layout');
  CheckContains(LResource, 'getrlimit(lresource',
    'platform.resource Android branch must call shared POSIX getrlimit');
  CheckContains(LResource, 'setrlimit(lresource',
    'platform.resource Android branch must call shared POSIX setrlimit');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.resource');
  T.Run('gets open-file resource limit', @TestGetOpenFilesLimit);
  T.Run('sets open-file resource limit to the existing value', @TestSetOpenFilesLimitToSameValue);
  T.Run('rejects invalid resource limit kind', @TestInvalidLimitKind);
  T.Run('rejects invalid resource limit values', @TestInvalidLimitValues);
  T.Run('Android resource source contract', @TestAndroidResourceSourceContract);
  T.Summary;
end.
