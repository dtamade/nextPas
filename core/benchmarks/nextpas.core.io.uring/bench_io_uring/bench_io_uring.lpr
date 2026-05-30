program bench_io_uring;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils, BaseUnix,
  nextpas.core.time.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.uring;

procedure BenchNopLatency;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LStart: TInstant;
  LElapsed: Double;
  LI: Int32;
  LNsPerOp: Double;
const
  N = 5000;
begin
  LRing := TIoUring.Create(16);
  if not LRing.IsValid then begin WriteLn('  not available'); Exit; end;

  LStart := TInstant.Now;
  for LI := 1 to N do
  begin
    LSqe := LRing.GetSqe;
    IoUringPrepNop(LSqe);
    LRing.SubmitAndWait(1);
    LRing.PeekCqe(LCqe);
    LRing.CqeSeen(LCqe);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  LNsPerOp := (LElapsed * 1e9) / N;
  WriteLn(Format('  NOP latency (1-by-1):  %8.0f ns/op', [LNsPerOp]));
  LRing.Close;
end;

procedure BenchNopBatch;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LStart: TInstant;
  LElapsed: Double;
  LI, LJ, LRet: Int32;
  LOpsPerSec: Double;
  LTotal: Int32;
const
  BATCH = 32;
  ROUNDS = 200;
begin
  LRing := TIoUring.Create(64);
  if not LRing.IsValid then begin WriteLn('  not available'); Exit; end;

  LTotal := 0;
  LStart := TInstant.Now;
  for LI := 1 to ROUNDS do
  begin
    for LJ := 1 to BATCH do
    begin
      LSqe := LRing.GetSqe;
      if LSqe = nil then Break;
      IoUringPrepNop(LSqe);
    end;
    LRet := LRing.SubmitAndWait(BATCH);
    if LRet < 0 then Break;
    while LRing.PeekCqe(LCqe) do
    begin
      LRing.CqeSeen(LCqe);
      Inc(LTotal);
    end;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  LOpsPerSec := LTotal / LElapsed;
  WriteLn(Format('  NOP batch (%d/round): %8.0f ops/sec  (%d total)', [BATCH, LOpsPerSec, LTotal]));
  LRing.Close;
end;

procedure BenchReadLatency;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LFd: Int32;
  LBuf: array[0..4095] of Byte;
  LStart: TInstant;
  LElapsed: Double;
  LI: Int32;
  LNsPerOp: Double;
const
  N = 2000;
begin
  LRing := TIoUring.Create(16);
  if not LRing.IsValid then begin WriteLn('  not available'); Exit; end;

  LFd := memfd_create('bench', MFD_CLOEXEC);
  FillChar(LBuf, 4096, $AA);
  FpWrite(LFd, @LBuf[0], 4096);

  LStart := TInstant.Now;
  for LI := 1 to N do
  begin
    LSqe := LRing.GetSqe;
    IoUringPrepRead(LSqe, LFd, @LBuf[0], 4096, 0);
    LRing.SubmitAndWait(1);
    LRing.PeekCqe(LCqe);
    LRing.CqeSeen(LCqe);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  LNsPerOp := (LElapsed * 1e9) / N;
  WriteLn(Format('  Read 4KB latency:  %8.0f ns/op', [LNsPerOp]));

  FpClose(LFd);
  LRing.Close;
end;

begin
  WriteLn('=== nextpas.core.io.uring benchmarks ===');
  WriteLn;
  BenchNopLatency;
  BenchNopBatch;
  WriteLn;
  BenchReadLatency;
  WriteLn;
  WriteLn('--- Reference (liburing C) ---');
  WriteLn('  NOP latency: ~500-1500 ns/op');
  WriteLn('  NOP batch:   ~5-20M ops/sec');
  WriteLn;
  WriteLn('done.');
end.
