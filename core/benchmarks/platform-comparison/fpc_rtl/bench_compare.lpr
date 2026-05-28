program bench_compare;

{$mode objfpc}{$H+}

uses
  SysUtils, Linux, UnixType;

const
  PATH_ITERS = 500000;
  FS_ITERS   = 200000;
  MMAP_ITERS = 10000;
  RAND_ITERS = 200000;
  WARMUP     = 1000;
  TEST_FILE  = '/tmp/bench_exists_test.txt';
  MMAP_FILE  = '/tmp/bench_mmap_1mb.dat';

function MonoNs: UInt64;
var
  ts: TimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @ts);
  Result := UInt64(ts.tv_sec) * 1000000000 + UInt64(ts.tv_nsec);
end;

procedure Emit(const AOp, AImpl: string; AIters: Int32; ANsPerOp: UInt64);
begin
  WriteLn(AOp, #9, AImpl, #9, AIters, #9, ANsPerOp);
end;

procedure BenchPathJoin;
var
  T0, T1: UInt64;
  I: Int32;
  S: string;
begin
  for I := 1 to WARMUP do
    S := ConcatPaths(['/home/user/projects', 'nextpas/core/src/file.pas']);
  T0 := MonoNs;
  for I := 1 to PATH_ITERS do
    S := ConcatPaths(['/home/user/projects', 'nextpas/core/src/file.pas']);
  T1 := MonoNs;
  if S = '' then;
  Emit('path_join', 'fpc_rtl', PATH_ITERS, (T1 - T0) div PATH_ITERS);
end;

procedure BenchPathBasename;
var
  T0, T1: UInt64;
  I: Int32;
  S: string;
begin
  for I := 1 to WARMUP do
    S := ExtractFileName('/home/user/projects/nextpas/core/src/file.pas');
  T0 := MonoNs;
  for I := 1 to PATH_ITERS do
    S := ExtractFileName('/home/user/projects/nextpas/core/src/file.pas');
  T1 := MonoNs;
  if S = '' then;
  Emit('path_basename', 'fpc_rtl', PATH_ITERS, (T1 - T0) div PATH_ITERS);
end;

procedure BenchFileExists;
var
  T0, T1: UInt64;
  I: Int32;
begin
  for I := 1 to WARMUP do
    FileExists(TEST_FILE);
  T0 := MonoNs;
  for I := 1 to FS_ITERS do
    FileExists(TEST_FILE);
  T1 := MonoNs;
  Emit('file_exists', 'fpc_rtl', FS_ITERS, (T1 - T0) div FS_ITERS);
end;

begin
  WriteLn('operation', #9, 'impl', #9, 'iterations', #9, 'ns_per_op');
  BenchPathJoin;
  BenchPathBasename;
  BenchFileExists;
  Emit('mmap_open_close', 'fpc_rtl', 0, 0);
  Emit('random_32B', 'fpc_rtl', 0, 0);
end.
