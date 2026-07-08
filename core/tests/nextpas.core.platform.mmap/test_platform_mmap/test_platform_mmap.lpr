program test_platform_mmap;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.mmap,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.test;

var
  T: TTestSuite;

const
  TEST_PATH = '/tmp/nextpas_test_mmap.txt';
  TEST_DATA = 'Hello, mmap world! nextPas platform.mmap test data.';

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := LowerCase(FsReadFileText(LSourcePath));
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

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

procedure TestAnonymousMap;
var
  M: TPlatformMappedFile;
begin
  Check(platform_mmap_create_anonymous(4096, pmaReadWrite, [pmfPrivate], M) = 0,
    'anonymous map');
  Check(M.Addr <> nil, 'anonymous addr');
  PByte(M.Addr)^ := $5A;
  Check(PByte(M.Addr)^ = $5A, 'anonymous write/read');
  Check(platform_mmap_close(M) = 0, 'anonymous close');
end;

procedure TestReadWriteFileMap;
var
  H: TPlatformFileHandle;
  M: TPlatformMappedFile;
  R: TPlatformMappedFile;
  LWritten: PtrUInt;
  LData: array[0..15] of Byte;
begin
  FillChar(LData, SizeOf(LData), 0);
  platform_file_open('/tmp/nextpas_test_mmap_rw.dat', fomReadWrite, fcmCreateAlways, H);
  platform_file_write(H, @LData[0], SizeOf(LData), LWritten);
  platform_file_close(H);

  Check(platform_mmap_open_file('/tmp/nextpas_test_mmap_rw.dat', pmaReadWrite,
    [pmfShared], SizeOf(LData), 0, M) = 0, 'rw map');
  PByte(M.Addr)^ := $7C;
  Check(platform_mmap_flush(M, 0, 1) = 0, 'rw flush');
  Check(platform_mmap_close(M) = 0, 'rw close');

  Check(platform_mmap_file('/tmp/nextpas_test_mmap_rw.dat', R) = 0, 'rw remap');
  Check(PByte(R.Addr)^ = $7C, 'rw persisted byte');
  platform_mmap_close(R);
  platform_file_unlink('/tmp/nextpas_test_mmap_rw.dat');
end;

procedure TestSharedMemoryCreateOpen;
var
  A: TPlatformMappedFile;
  B: TPlatformMappedFile;
  LName: string;
begin
  LName := 'nextpas_test_platform_mmap_shm_' + IntToStr(PtrUInt(@A));
  Check(platform_shm_create(PAnsiChar(LName), 4096, pmaReadWrite, A) = 0,
    'shared create');
  Check(A.IsCreator, 'shared creator');
  PByte(A.Addr)^ := $33;

  Check(platform_shm_open(PAnsiChar(LName), pmaReadWrite, B) = 0, 'shared open');
  Check(PByte(B.Addr)^ = $33, 'shared visible byte');
  PByte(B.Addr)^ := $44;
  Check(PByte(A.Addr)^ = $44, 'shared write visible');

  Check(platform_shm_close(B) = 0, 'shared close opener');
  Check(platform_shm_close(A) = 0, 'shared close creator');
end;

procedure TestUnixPageSizeSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.platform.mmap.pas');
  CheckContains(LSource, 'sysconf(_SC_PAGESIZE)',
    'Unix mmap page size must query the host runtime page size');
  CheckContains(LSource, 'Result := 4096',
    'Unix mmap page size keeps a conservative sysconf fallback');

  CheckContains(LoadSourceText('src/nextpas.core.platform.linux.base.pas'),
    '_SC_PAGESIZE', 'Linux base must expose sysconf page-size selector');
  CheckContains(LoadSourceText('src/nextpas.core.platform.android.base.pas'),
    '_SC_PAGESIZE', 'Android base must expose sysconf page-size selector');
  CheckContains(LoadSourceText('src/nextpas.core.platform.darwin.base.pas'),
    '_SC_PAGESIZE', 'Darwin base must expose sysconf page-size selector');
  CheckContains(LoadSourceText('src/nextpas.core.platform.freebsd.base.pas'),
    '_SC_PAGESIZE', 'FreeBSD base must expose sysconf page-size selector');
  CheckContains(LoadSourceText('src/nextpas.core.platform.unix.base.pas'),
    '_SC_PAGESIZE', 'generic Unix base must expose sysconf page-size selector');
end;

procedure TestFlushReadWriteMap;
const
  PATH = '/tmp/nextpas_mmap_flush_test.dat';
  DATA = 'flush test data 1234567890';
var
  LMap: TPlatformMappedFile;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LRet: Int32;
begin
  { Create a file with enough data }
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar(DATA), 26, LWritten);
  platform_file_close(H);

  { Map the file }
  LRet := platform_mmap_file(PATH, LMap);
  Check(LRet = 0, 'mmap file for flush test');

  { Flush should succeed (use actual mapped size) }
  LRet := platform_mmap_flush(LMap, 0, LMap.Size);
  Check(LRet = 0, 'flush succeeds');

  platform_mmap_close(LMap);
  platform_file_unlink(PATH);
end;

procedure TestLockUnlockReadWriteMap;
const
  PATH = '/tmp/nextpas_mmap_lock_test.dat';
  DATA = 'lock test data';
var
  LMap: TPlatformMappedFile;
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LRet: Int32;
begin
  { Create a file and write data }
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar(DATA), 15, LWritten);
  platform_file_close(H);

  { Map the file }
  LRet := platform_mmap_file(PATH, LMap);
  Check(LRet = 0, 'mmap file for lock test');

  { Lock should succeed }
  LRet := platform_mmap_lock(LMap, 0, LMap.Size);
  Check(LRet = 0, 'lock succeeds');

  { Unlock should succeed }
  LRet := platform_mmap_unlock(LMap, 0, LMap.Size);
  Check(LRet = 0, 'unlock succeeds');

  platform_mmap_close(LMap);
  platform_file_unlink(PATH);
end;

{ Error path tests }
procedure TestDoubleCloseReturnsError;
var
  M: TPlatformMappedFile;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap');
  Check(platform_mmap_close(M) = 0, 'close first');
  Check(platform_mmap_close(M) <> 0, 'close second returns error');
  platform_file_unlink(TEST_PATH);
end;

procedure TestFlushAfterClose;
var
  M: TPlatformMappedFile;
  LRet: Int32;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap');
  Check(platform_mmap_close(M) = 0, 'close');

  { Flush after close should return error }
  LRet := platform_mmap_flush(M, 0, 1);
  Check(LRet <> 0, 'flush after close returns error');

  platform_file_unlink(TEST_PATH);
end;

procedure TestLockAfterClose;
var
  M: TPlatformMappedFile;
  LRet: Int32;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap');
  Check(platform_mmap_close(M) = 0, 'close');

  { Lock after close should return error }
  LRet := platform_mmap_lock(M, 0, 1);
  Check(LRet <> 0, 'lock after close returns error');

  platform_file_unlink(TEST_PATH);
end;

procedure TestUnlockAfterClose;
var
  M: TPlatformMappedFile;
  LRet: Int32;
begin
  CreateTestFile;
  Check(platform_mmap_file(TEST_PATH, M) = 0, 'mmap');
  Check(platform_mmap_close(M) = 0, 'close');

  { Unlock after close should return error }
  LRet := platform_mmap_unlock(M, 0, 1);
  Check(LRet <> 0, 'unlock after close returns error');

  platform_file_unlink(TEST_PATH);
end;

procedure TestShmOpenNonExistent;
var
  B: TPlatformMappedFile;
  LRet: Int32;
begin
  LRet := platform_shm_open('/nextpas_nonexistent_shm_xyz_999', pmaReadWrite, B);
  Check(LRet <> 0, 'open non-existent shared memory returns error');
end;

procedure TestAnonymousMapReadWrite;
var
  M: TPlatformMappedFile;
  LIndex: Integer;
begin
  Check(platform_mmap_create_anonymous(4096, pmaReadWrite, [pmfPrivate], M) = 0,
    'anonymous map');
  Check(M.Addr <> nil, 'anonymous addr');

  { Write pattern }
  for LIndex := 0 to 255 do
    PByte(PtrUInt(M.Addr) + PtrUInt(LIndex))^ := Byte(LIndex);

  { Read pattern }
  for LIndex := 0 to 255 do
    Check(PByte(PtrUInt(M.Addr) + PtrUInt(LIndex))^ = Byte(LIndex),
      'anonymous byte ' + IntToStr(LIndex));

  Check(platform_mmap_close(M) = 0, 'anonymous close');
end;

procedure TestMapLargeFileIntegrity;
const
  PATH = '/tmp/nextpas_mmap_large_integrity.dat';
  SIZE = 1024 * 1024; { 1MB }
var
  H: TPlatformFileHandle;
  M: TPlatformMappedFile;
  LWritten: PtrUInt;
  LIndex: Integer;
  LBuf: array[0..4095] of Byte;
begin
  { Create 1MB file with pattern }
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  for LIndex := 0 to 255 do
  begin
    FillChar(LBuf, 4096, Byte(LIndex));
    platform_file_write(H, @LBuf[0], 4096, LWritten);
  end;
  platform_file_close(H);

  { Map and verify }
  Check(platform_mmap_file(PATH, M) = 0, 'mmap 1MB');
  Check(M.Size = SIZE, 'size = 1MB');

  { Verify first and last bytes }
  Check(PByte(M.Addr)^ = 0, 'first byte');
  Check(PByte(PtrUInt(M.Addr) + M.Size - 1)^ = 255, 'last byte');

  platform_mmap_close(M);
  platform_file_unlink(PATH);
end;

procedure TestPageSize;
var
  LSize: UInt64;
begin
  LSize := platform_mmap_page_size;
  Check(LSize >= 4096, 'page size >= 4096');
  Check(LSize <= 65536, 'page size <= 65536');
  { Must be power of 2 }
  Check((LSize and (LSize - 1)) = 0, 'page size is power of 2');
end;

procedure TestAnonymousMapZeroSize;
var
  M: TPlatformMappedFile;
  R: Int32;
begin
  R := platform_mmap_create_anonymous(0, pmaReadWrite, [pmfPrivate], M);
  Check(R <> 0, 'zero-size anonymous map returns error');
end;

procedure TestMapNilPath;
var
  M: TPlatformMappedFile;
  R: Int32;
begin
  R := platform_mmap_file(nil, M);
  Check(R <> 0, 'nil path returns error');
end;

procedure TestFlushNilMap;
var
  M: TPlatformMappedFile;
begin
  FillChar(M, SizeOf(M), 0);
  M.IsOpen := False;
  Check(platform_mmap_flush(M, 0, 1) <> 0, 'flush on closed map returns error');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.mmap');
  T.Test('map file + verify content', @TestMapFile);
  T.Test('map non-existent file', @TestMapNonExistent);
  T.Test('map empty file', @TestMapEmptyFile);
  T.Test('double close', @TestDoubleClose);
  T.Test('read last byte', @TestLargeRead);
  T.Test('large file (256KB)', @TestLargeFile);
  T.Test('content integrity (256 bytes)', @TestContentIntegrity);
  T.Test('anonymous map', @TestAnonymousMap);
  T.Test('read-write file map', @TestReadWriteFileMap);
  T.Test('shared memory create/open', @TestSharedMemoryCreateOpen);
  T.Test('Unix mmap page-size source contract', @TestUnixPageSizeSourceContract);
  T.Test('flush read-write map', @TestFlushReadWriteMap);
  T.Test('lock + unlock read-write map', @TestLockUnlockReadWriteMap);
  T.Test('double close returns error', @TestDoubleCloseReturnsError);
  T.Test('flush after close', @TestFlushAfterClose);
  T.Test('lock after close', @TestLockAfterClose);
  T.Test('unlock after close', @TestUnlockAfterClose);
  T.Test('open non-existent shared memory', @TestShmOpenNonExistent);
  T.Test('anonymous map read/write', @TestAnonymousMapReadWrite);
  T.Test('large file integrity', @TestMapLargeFileIntegrity);
  T.Test('page size is valid power of 2', @TestPageSize);
  T.Test('anonymous map zero size', @TestAnonymousMapZeroSize);
  T.Test('map nil path', @TestMapNilPath);
  T.Test('flush on closed map', @TestFlushNilMap);
  if not T.Run then Halt(1);
  Cleanup;
end.
