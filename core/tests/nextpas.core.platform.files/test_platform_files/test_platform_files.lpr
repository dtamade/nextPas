program test_platform_files;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

const
  TEST_PATH = '/tmp/nextpas_test_platform_file.tmp';
  TEST_DATA = 'Hello, nextPas platform.files!';

procedure TestOpenCreateClose;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open create');
  Check(H.Value >= 0, 'handle valid');
  Check(platform_file_close(H) = 0, 'close');
  Check(H.Value < 0, 'handle invalidated after close');
end;

procedure TestWriteReadBack;
var
  H: TPlatformFileHandle;
  LBuf: array[0..127] of AnsiChar;
  LWritten, LRead: PtrUInt;
  LPos: Int64;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LWritten), 'bytes written');
  Check(platform_file_seek(H, 0, fsoBegin, LPos) = 0, 'seek begin');
  CheckEqual(Int64(0), LPos, 'position after seek');
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_file_read(H, @LBuf, Length(TEST_DATA), LRead) = 0, 'read');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LRead), 'bytes read');
  Check(CompareMem(@LBuf, @TEST_DATA[1], Length(TEST_DATA)), 'data matches');
  Check(platform_file_close(H) = 0, 'close');
end;

procedure TestTruncate;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LPos: Int64;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  Check(platform_file_truncate(H, 5) = 0, 'truncate to 5');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek end');
  CheckEqual(Int64(5), LPos, 'size after truncate');
  Check(platform_file_close(H) = 0, 'close');
end;

procedure TestSync;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  Check(platform_file_sync(H) = 0, 'sync');
  Check(platform_file_close(H) = 0, 'close');
end;

procedure TestOpenNonExistent;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open('/tmp/nextpas_nonexistent_xyz_abc', fomReadOnly, fcmOpenExisting, H) <> 0, 'open non-existent returns error');
end;

procedure Cleanup;
begin
  DeleteFile(TEST_PATH);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.files');
  T.Run('open/create/close', @TestOpenCreateClose);
  T.Run('write + read back', @TestWriteReadBack);
  T.Run('truncate', @TestTruncate);
  T.Run('sync', @TestSync);
  T.Run('open non-existent', @TestOpenNonExistent);
  T.Summary;
end.
