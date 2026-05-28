program bench_platform_mmap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.mmap,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

const
  ITERATIONS = 10000;
  TEST_PATH = '/tmp/nextpas_bench_mmap.dat';

procedure ReportMetric(const AName: string; const AElapsedNs: UInt64);
begin
  WriteLn(AName, '-iterations=', ITERATIONS);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if ITERATIONS > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div ITERATIONS);
end;

procedure CreateTestFile;
var
  H: TPlatformFileHandle;
  Buf: array[0..4095] of Byte;
  W: PtrUInt;
  I: Int32;
begin
  FillChar(Buf, SizeOf(Buf), $AA);
  platform_file_open(TEST_PATH, fomWriteOnly, fcmCreateAlways, H);
  for I := 1 to 256 do
    platform_file_write(H, @Buf[0], 4096, W);
  platform_file_close(H);
end;

procedure BenchMmapOpenClose;
var
  M: TPlatformMappedFile;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
  begin
    platform_mmap_file(TEST_PATH, M);
    platform_mmap_close(M);
  end;
  LFinish := platform_monotonic_ns;
  ReportMetric('mmap-open-close-1MB', LFinish - LStart);
end;

procedure BenchMmapRead;
var
  M: TPlatformMappedFile;
  LStart, LFinish: UInt64;
  LSink: Byte;
  I: PtrUInt;
begin
  platform_mmap_file(TEST_PATH, M);
  LSink := 0;
  LStart := platform_monotonic_ns;
  for I := 0 to M.Size - 1 do
    LSink := LSink xor PByte(PtrUInt(M.Addr) + I)^;
  LFinish := platform_monotonic_ns;
  WriteLn('mmap-sequential-read-1MB-ns=', LFinish - LStart);
  WriteLn('mmap-sequential-read-MB-per-sec=', (Int64(M.Size) * 1000) div Int64(LFinish - LStart));
  platform_mmap_close(M);
  if LSink = 255 then; // prevent optimization
end;

begin
  CreateTestFile;
  BenchMmapOpenClose;
  BenchMmapRead;
  platform_file_unlink(TEST_PATH);
end.
