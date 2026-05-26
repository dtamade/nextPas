program test_platform_posix_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';

var
  T: TTestRunner;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolvePosixFFISourcePath: string;
begin
  if FileExists(POSIX_FFI_SOURCE_PATH_FROM_TEST) then
    Exit(POSIX_FFI_SOURCE_PATH_FROM_TEST);
  if FileExists(POSIX_FFI_SOURCE_PATH_FROM_ROOT) then
    Exit(POSIX_FFI_SOURCE_PATH_FROM_ROOT);
  Result := POSIX_FFI_SOURCE_PATH_FROM_TEST;
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure TestPosixFFIExposesTargetMatrix;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolvePosixFFISourcePath);

  CheckTokenPresent(LSource, 'nextpas_android',
    'posix.ffi must carry an Android-specific pthread ABI branch');
  CheckTokenPresent(LSource, 'nextpas_freebsd',
    'posix.ffi must carry a FreeBSD-specific pthread ABI branch');
  CheckTokenPresent(LSource, 'nextpas_macos',
    'posix.ffi must carry a macOS-specific pthread ABI branch');

  CheckTokenPresent(LSource, 'pthread_rwlockattr_t',
    'posix.ffi must declare pthread rwlock attribute storage');
  CheckTokenPresent(LSource, 'array[0..199] of byte',
    'posix.ffi must preserve the macOS rwlock opaque size');
  CheckTokenPresent(LSource, 'pthread_mutex_t = pointer;',
    'posix.ffi must model FreeBSD pthread mutex handles as pointers');
  CheckTokenPresent(LSource, 'pthread_cond_t = pointer;',
    'posix.ffi must model FreeBSD pthread condvar handles as pointers');
  CheckTokenPresent(LSource, 'pthread_rwlock_t = pointer;',
    'posix.ffi must model FreeBSD pthread rwlock handles as pointers');
  CheckTokenPresent(LSource, 'pthread_mutexattr_t = ptrint;',
    'posix.ffi must model Android pthread mutex attributes as long-sized values');
  CheckTokenPresent(LSource, 'pthread_mutexattr_t = int32;',
    'posix.ffi must model Linux pthread mutex attributes as 32-bit values');
  CheckTokenPresent(LSource, 'pthread_mutex_errorcheck = 1;',
    'posix.ffi must preserve the FreeBSD mutex kind numbering');
  CheckTokenPresent(LSource, 'pthread_mutex_normal     = 3;',
    'posix.ffi must preserve the FreeBSD normal mutex numbering');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.posix_ffi_surface');
  T.Run('platform.posix.ffi exposes target matrix', @TestPosixFFIExposesTargetMatrix);
  T.Summary;
end.
