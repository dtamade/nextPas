program bench_compare;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.path,
  nextpas.core.platform.fs,
  nextpas.core.platform.mmap,
  nextpas.core.platform.random,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

const
  PATH_ITERS = 500000;
  FS_ITERS   = 200000;
  MMAP_ITERS = 10000;
  RAND_ITERS = 200000;
  WARMUP     = 1000;
  TEST_FILE  = '/tmp/bench_exists_test.txt';
  MMAP_FILE  = '/tmp/bench_mmap_1mb.dat';

procedure Emit(const AOp, AImpl: PAnsiChar; AIters: Int32; ANsPerOp: UInt64);
begin
  WriteLn(AOp, #9, AImpl, #9, AIters, #9, ANsPerOp);
end;

procedure Setup;
var
  H: TPlatformFileHandle;
  Buf: array[0..4095] of Byte;
  W: PtrUInt;
  I: Int32;
begin
  platform_file_open(TEST_FILE, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, W);
  platform_file_close(H);
  FillChar(Buf, 4096, $AA);
  platform_file_open(MMAP_FILE, fomWriteOnly, fcmCreateAlways, H);
  for I := 1 to 256 do
    platform_file_write(H, @Buf[0], 4096, W);
  platform_file_close(H);
end;

procedure Teardown;
begin
  platform_file_unlink(TEST_FILE);
  platform_file_unlink(MMAP_FILE);
end;

procedure BenchPathJoin;
var
  Buf: array[0..255] of AnsiChar;
  T0, T1: UInt64;
  I: Int32;
begin
  for I := 1 to WARMUP do
    platform_path_join('/home/user/projects', 'nextpas/core/src/file.pas', @Buf[0], 256);
  T0 := platform_monotonic_ns;
  for I := 1 to PATH_ITERS do
    platform_path_join('/home/user/projects', 'nextpas/core/src/file.pas', @Buf[0], 256);
  T1 := platform_monotonic_ns;
  Emit('path_join', 'nextpas', PATH_ITERS, (T1 - T0) div PATH_ITERS);
end;

procedure BenchPathBasename;
var
  Buf: array[0..255] of AnsiChar;
  T0, T1: UInt64;
  I: Int32;
begin
  for I := 1 to WARMUP do
    platform_path_basename('/home/user/projects/nextpas/core/src/file.pas', @Buf[0], 256);
  T0 := platform_monotonic_ns;
  for I := 1 to PATH_ITERS do
    platform_path_basename('/home/user/projects/nextpas/core/src/file.pas', @Buf[0], 256);
  T1 := platform_monotonic_ns;
  Emit('path_basename', 'nextpas', PATH_ITERS, (T1 - T0) div PATH_ITERS);
end;

procedure BenchFileExists;
var
  T0, T1: UInt64;
  I: Int32;
begin
  for I := 1 to WARMUP do
    platform_fs_exists(TEST_FILE);
  T0 := platform_monotonic_ns;
  for I := 1 to FS_ITERS do
    platform_fs_exists(TEST_FILE);
  T1 := platform_monotonic_ns;
  Emit('file_exists', 'nextpas', FS_ITERS, (T1 - T0) div FS_ITERS);
end;

procedure BenchMmap;
var
  M: TPlatformMappedFile;
  T0, T1: UInt64;
  I: Int32;
begin
  for I := 1 to WARMUP do
  begin
    platform_mmap_file(MMAP_FILE, M);
    platform_mmap_close(M);
  end;
  T0 := platform_monotonic_ns;
  for I := 1 to MMAP_ITERS do
  begin
    platform_mmap_file(MMAP_FILE, M);
    platform_mmap_close(M);
  end;
  T1 := platform_monotonic_ns;
  Emit('mmap_open_close', 'nextpas', MMAP_ITERS, (T1 - T0) div MMAP_ITERS);
end;

procedure BenchRandom32;
var
  Buf: array[0..31] of Byte;
  T0, T1: UInt64;
  I: Int32;
begin
  for I := 1 to WARMUP do
    platform_random_bytes(@Buf[0], 32);
  T0 := platform_monotonic_ns;
  for I := 1 to RAND_ITERS do
    platform_random_bytes(@Buf[0], 32);
  T1 := platform_monotonic_ns;
  Emit('random_32B', 'nextpas', RAND_ITERS, (T1 - T0) div RAND_ITERS);
end;

begin
  WriteLn('operation', #9, 'impl', #9, 'iterations', #9, 'ns_per_op');
  Setup;
  BenchPathJoin;
  BenchPathBasename;
  BenchFileExists;
  BenchMmap;
  BenchRandom32;
end.
