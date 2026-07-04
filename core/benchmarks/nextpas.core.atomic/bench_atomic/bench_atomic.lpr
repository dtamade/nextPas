program bench_atomic;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.atomic;
var GSink32: Int32 = 0; GSinkUInt32: UInt32 = 0;
procedure BenchPlainIncrement(const ACtx: IBenchContext);
begin Inc(GSink32); end;
procedure BenchAtomicLoadStore32(const ACtx: IBenchContext);
var V: Int32;
begin AtomicLoad(V, GSink32); AtomicStore(GSink32, V + 1); end;
procedure BenchFetchAdd32(const ACtx: IBenchContext);
begin AtomicFetchAdd(GSink32, 1); end;
procedure BenchCompareExchange32(const ACtx: IBenchContext);
var LOld: Int32;
begin LOld := GSink32; AtomicCompareExchange(GSink32, LOld + 1, LOld); end;
procedure BenchAtomicUInt32(const ACtx: IBenchContext);
var LCounter: TAtomicUInt32;
begin LCounter.Init; LCounter.Increment; LCounter.Free; end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('atomic');
  LSuite.Add('PlainIncrement', @BenchPlainIncrement).Add('AtomicLoadStore32', @BenchAtomicLoadStore32)
    .Add('FetchAdd32', @BenchFetchAdd32).Add('CompareExchange32', @BenchCompareExchange32).Add('TAtomicUInt32', @BenchAtomicUInt32);
  WriteLn(LSuite.Run.PrintToConsole);
end.
