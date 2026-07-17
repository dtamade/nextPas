program test_platform_docs_live_patterns;

{ Live API smoke matching BEST-PRACTICES / QUICKSTART open-read-close patterns.
  Compiles and runs real platform.files + platform.error calls (not markdown parse). }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.error,
  nextpas.core.platform.fs,
  nextpas.core.test;

var
  T: TTestSuite;

const
  TEST_PATH = '/tmp/nextpas_platform_docs_live_patterns.tmp';

procedure TestOpenReadClosePattern;
var
  LHandle: TPlatformFileHandle;
  LBuf: array[0..63] of Byte;
  LMsg: array[0..127] of AnsiChar;
  LRead, LWritten: PtrUInt;
  LErr: Int32;
  LPayload: array[0..4] of AnsiChar;
begin
  LPayload[0] := 'h';
  LPayload[1] := 'e';
  LPayload[2] := 'l';
  LPayload[3] := 'l';
  LPayload[4] := 'o';

  platform_file_unlink(TEST_PATH);

  LErr := platform_file_open(TEST_PATH, fomWriteOnly, fcmCreateAlways, LHandle);
  Check(LErr = 0, 'open write: error-code 0');
  LErr := platform_file_write(LHandle, @LPayload[0], 5, LWritten);
  Check(LErr = 0, 'write: error-code 0');
  Check(LWritten = 5, 'wrote 5 bytes');
  Check(platform_file_close(LHandle) = 0, 'close write handle');

  LErr := platform_file_open(TEST_PATH, fomReadOnly, fcmOpenExisting, LHandle);
  Check(LErr = 0, 'open read: error-code 0');
  FillChar(LBuf, SizeOf(LBuf), 0);
  LErr := platform_file_read(LHandle, @LBuf[0], SizeOf(LBuf), LRead);
  Check(LErr = 0, 'read: error-code 0');
  Check(LRead = 5, 'read 5 bytes');
  Check(LBuf[0] = Ord('h'), 'payload starts with h');
  Check(platform_file_close(LHandle) = 0, 'close read handle');

  LErr := platform_file_open('/no/such/path/nextpas_docs_live', fomReadOnly,
    fcmOpenExisting, LHandle);
  Check(LErr <> 0, 'missing path fails');
  Check(LErr = PLATFORM_ERR_NOENT, 'missing path is PLATFORM_ERR_NOENT');
  Check(platform_error_message(LErr, @LMsg[0], SizeOf(LMsg)) > 0,
    'error_message length > 0 for live failure');
  Check(LMsg[0] <> #0, 'error_message non-empty');

  platform_file_unlink(TEST_PATH);
end;

procedure TestFsExistsPattern;
begin
  Check(platform_fs_exists('/tmp') or platform_fs_exists('/'),
    'fs_exists sees a common root path');
end;

procedure TestLastErrorApisCallable;
var
  LMapped, LOs: Int32;
begin
  LMapped := platform_get_last_error;
  LOs := platform_get_last_os_error;
  Check(LMapped >= -8, 'get_last_error in portable/host range');
  Check(LOs >= 0, 'get_last_os_error non-negative host code on Linux');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.docs_live_patterns');
  T.Test('open/read/close + error_message live pattern', @TestOpenReadClosePattern);
  T.Test('fs_exists live pattern', @TestFsExistsPattern);
  T.Test('last_error / last_os_error callable', @TestLastErrorApisCallable);
  if not T.Run then Halt(1);
end.
