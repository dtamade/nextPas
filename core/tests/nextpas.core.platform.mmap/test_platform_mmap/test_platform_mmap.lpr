program test_platform_mmap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.mmap,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

const
  TEST_PATH = '/tmp/nextpas_test_mmap.txt';
  TEST_DATA = 'Hello, mmap world! nextPas platform.mmap test data.';

procedure CreateTestFile;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  platform_file_open(TEST_PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten);
  platform_file_close(H);
end;

procedure TestMapFile;
var
  M: TPlatformMappedFile;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap_file');
  Check(M.Addr <> nil, 'addr not nil');
  Check(M.Size = PtrUInt(Length(TEST_DATA)), 'size matches');
  Check(PAnsiChar(M.Addr)[0] = 'H', 'data[0] = H');
  Check(PAnsiChar(M.Addr)[7] = 'm', 'data[7] = m');
  Check(platform_mmap_close(M) = 0, 'close');
  Check(M.Addr = nil, 'addr nil after close');
end;

procedure TestMapNonExistent;
var
  M: TPlatformMappedFile;
  R: Int32;
begin
  R := platform_mmap_file('/tmp/nextpas_nonexistent_mmap_xyz', M);
  Check(R <> 0, 'non-existent returns error');
  Check(R = 2, 'error is ENOENT (2)');
end;

procedure TestMapEmptyFile;
var
  M: TPlatformMappedFile;
  H: TPlatformFileHandle;
  R: Int32;
begin
  platform_file_open('/tmp/nextpas_test_mmap_empty.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_close(H);
  R := platform_mmap_file('/tmp/nextpas_test_mmap_empty.txt', M);
  Check(R <> 0, 'empty file returns error');
  platform_file_unlink('/tmp/nextpas_test_mmap_empty.txt');
end;

procedure TestDoubleClose;
var
  M: TPlatformMappedFile;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap');
  Check(platform_mmap_close(M) = 0, 'close first');
  Check(platform_mmap_close(M) <> 0, 'close second returns error');
end;

procedure TestLargeRead;
var
  M: TPlatformMappedFile;
  LLast: AnsiChar;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap');
  LLast := PAnsiChar(M.Addr)[M.Size - 1];
  Check(LLast = '.', 'last char is period');
  platform_mmap_close(M);
end;

procedure Cleanup;
begin
  platform_file_unlink(TEST_PATH);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.mmap');
  T.Run('map file + verify content', @TestMapFile);
  T.Run('map non-existent file', @TestMapNonExistent);
  T.Run('map empty file', @TestMapEmptyFile);
  T.Run('double close', @TestDoubleClose);
  T.Run('read last byte', @TestLargeRead);
  T.Summary;
  Cleanup;
end.
