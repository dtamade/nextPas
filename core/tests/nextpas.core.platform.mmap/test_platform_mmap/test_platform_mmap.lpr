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

procedure TestLargeFile;
var
  H: TPlatformFileHandle;
  M: TPlatformMappedFile;
  LBuf: array[0..4095] of Byte;
  LWritten: PtrUInt;
  I: Int32;
begin
  FillChar(LBuf, 4096, $CD);
  platform_file_open('/tmp/nextpas_test_mmap_large.dat', fomWriteOnly, fcmCreateAlways, H);
  for I := 1 to 64 do
    platform_file_write(H, @LBuf[0], 4096, LWritten);
  platform_file_close(H);
  Check(platform_mmap_file('/tmp/nextpas_test_mmap_large.dat', M) = 0, 'mmap 256KB');
  Check(M.Size = 64 * 4096, 'size = 256KB');
  Check(PByte(M.Addr)^ = $CD, 'first byte');
  Check(PByte(PtrUInt(M.Addr) + M.Size - 1)^ = $CD, 'last byte');
  platform_mmap_close(M);
  platform_file_unlink('/tmp/nextpas_test_mmap_large.dat');
end;

procedure TestContentIntegrity;
var
  H: TPlatformFileHandle;
  M: TPlatformMappedFile;
  LWritten: PtrUInt;
  I: Int32;
  LData: array[0..255] of Byte;
begin
  for I := 0 to 255 do
    LData[I] := Byte(I);
  platform_file_open('/tmp/nextpas_test_mmap_integrity.dat', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, @LData[0], 256, LWritten);
  platform_file_close(H);
  Check(platform_mmap_file('/tmp/nextpas_test_mmap_integrity.dat', M) = 0, 'mmap');
  Check(M.Size = 256, 'size 256');
  for I := 0 to 255 do
    if PByte(PtrUInt(M.Addr) + PtrUInt(I))^ <> Byte(I) then
    begin
      Check(False, 'byte mismatch');
      Break;
    end;
  Check(True, 'all 256 bytes match');
  platform_mmap_close(M);
  platform_file_unlink('/tmp/nextpas_test_mmap_integrity.dat');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.mmap');
  T.Run('map file + verify content', @TestMapFile);
  T.Run('map non-existent file', @TestMapNonExistent);
  T.Run('map empty file', @TestMapEmptyFile);
  T.Run('double close', @TestDoubleClose);
  T.Run('read last byte', @TestLargeRead);
  T.Run('large file (256KB)', @TestLargeFile);
  T.Run('content integrity (256 bytes)', @TestContentIntegrity);
  T.Summary;
  Cleanup;
end.
