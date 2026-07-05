program test_platform_fs_copy_bench;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.fs,
  nextpas.core.platform.time,
  nextpas.core.test;

const
  FILE_SIZE = 1024 * 1024;  { 1MB }
  ITERATIONS = 100;

var
  T: TTestSuite;

procedure TestCopyFileBench;
var
  LSrcPath, LDstPath: PAnsiChar;
  LBuf: array[0..FILE_SIZE - 1] of Byte;
  LHandle: TPlatformFileHandle;
  LWritten: PtrUInt;
  LI: Int32;
  LStart, LEnd, LElapsed: Int64;
  LMin, LMax, LTotal: Int64;
  LR: Int32;
begin
  LSrcPath := '/tmp/nextpas_copy_bench_src.bin';
  LDstPath := '/tmp/nextpas_copy_bench_dst.bin';

  { Create source file with random-ish data }
  FillChar(LBuf, SizeOf(LBuf), $AA);
  LR := platform_file_open(LSrcPath, fomWriteOnly, fcmCreateAlways, LHandle);
  Check(LR = 0, 'open src for write');
  LR := platform_file_write(LHandle, @LBuf[0], FILE_SIZE, LWritten);
  Check(LR = 0, 'write src');
  Check(LWritten = FILE_SIZE, 'full write');
  platform_file_close(LHandle);

  { Warm up }
  for LI := 0 to 4 do
  begin
    platform_fs_copy_file(LSrcPath, LDstPath);
    platform_file_unlink(LDstPath);
  end;

  { Benchmark }
  LMin := High(Int64);
  LMax := 0;
  LTotal := 0;
  for LI := 0 to ITERATIONS - 1 do
  begin
    LStart := platform_monotonic_ns;
    LR := platform_fs_copy_file(LSrcPath, LDstPath);
    LEnd := platform_monotonic_ns;
    Check(LR = 0, 'copy_file succeeds');
    platform_file_unlink(LDstPath);

    LElapsed := LEnd - LStart;
    if LElapsed < LMin then LMin := LElapsed;
    if LElapsed > LMax then LMax := LElapsed;
    Inc(LTotal, LElapsed);
  end;

  { Cleanup }
  platform_file_unlink(LSrcPath);

  { Report }
  Check(LMin > 0, 'min > 0');
  Check(LTotal > 0, 'total > 0');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.fs.copy_bench');
  T.Test('copy_file 1MB benchmark', @TestCopyFileBench);
  if not T.Run then Halt(1);
end.
