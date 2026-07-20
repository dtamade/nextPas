program bench_io_uring;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.platform.posix.base, nextpas.core.platform.linux.modern, nextpas.core.io.uring;
var GSink: UInt64;
procedure BenchNopLatency(const ACtx: IBenchContext);
var LRing: TIoUring; LSqe: PIoUringSqe; LCqe: PIoUringCqe;
begin
  LRing := TIoUring.Create(16);
  if not LRing.IsValid then begin ACtx.Skip('io_uring unavailable'); LRing.Close; Exit; end;
  LSqe := LRing.GetSqe; IoUringPrepNop(LSqe); LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe); LRing.CqeSeen(LCqe);
  LRing.Close;
end;
procedure BenchNopBatch32(const ACtx: IBenchContext);
var LRing: TIoUring; LSqe: PIoUringSqe; LCqe: PIoUringCqe; LJ, LRet: Int32;
begin
  LRing := TIoUring.Create(64);
  if not LRing.IsValid then begin ACtx.Skip('io_uring unavailable'); LRing.Close; Exit; end;
  for LJ := 1 to 32 do begin LSqe := LRing.GetSqe; if LSqe = nil then Break; IoUringPrepNop(LSqe); end;
  LRet := LRing.SubmitAndWait(32);
  while LRing.PeekCqe(LCqe) do begin LRing.CqeSeen(LCqe); Inc(GSink); end;
  LRing.Close;
end;
var LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('io-uring');
  LSuite.Add('Nop/Latency', @BenchNopLatency).Add('Nop/Batch32', @BenchNopBatch32);
  WriteLn(LSuite.Run.PrintToConsole);
end.
