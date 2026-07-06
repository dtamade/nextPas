program bench_lockfree;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.thread.init,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.atomic, nextpas.core.lockfree,
  nextpas.core.lockfree.ebr, nextpas.core.lockfree.spsc, nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.channel, nextpas.core.lockfree.channel.spsc,
  nextpas.core.thread.channel, nextpas.core.platform.thread, nextpas.core.platform.info;
type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntSegQueue = specialize TSegQueue<Integer>;
  TIntSpmc = specialize TSpmcQueue<Integer>;
  TIntChannel = specialize TLockFreeChannel<Integer>;
  TIntChannelSpsc = specialize TLockFreeChannelSpsc<Integer>;
var GSpsc: TIntSpsc; GMpmc: TIntMpmc; GSeg: TIntSegQueue; GSpmc: TIntSpmc;
  GChannel: TIntChannel; GChannelSpsc: TIntChannelSpsc; GBenchSink: Int64;
  GEbrDomain: TEbrDomain;
procedure SimpleReclaim(const AData: Pointer; const AUserData: Pointer);
begin FreeMem(AData); end;
procedure BenchSpscTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GSpsc.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchMpmcTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GMpmc.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchSegTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GSeg.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchSpmcTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GSpmc.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchEbrRetire(const ACtx: IBenchContext);
var LP: Pointer;
begin GetMem(LP, 64); GEbrDomain.Retire(LP, @SimpleReclaim); end;
procedure BenchChannelTrySendReceive(const ACtx: IBenchContext);
var LV: Integer;
begin if GChannel.TrySend(42) then if GChannel.TryReceive(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchChannelSpscTrySendReceive(const ACtx: IBenchContext);
var LV: Integer;
begin if GChannelSpsc.TrySend(42) then if GChannelSpsc.TryReceive(LV) then GBenchSink := GBenchSink + LV; end;
var LSuite: IBenchSuite;
begin
  WriteLn('Platform: ', OSName, '/', CPUName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T');
  WriteLn('Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)');
  GSpsc := TIntSpsc.Create(1024); GMpmc := TIntMpmc.Create(1024);
  GSeg := TIntSegQueue.Create; GSpmc := TIntSpmc.Create(1024);
  GChannel := TIntChannel.Create(1024); GChannelSpsc := TIntChannelSpsc.Create(1024);
  GEbrDomain := TEbrDomain.Create;
  GBenchSink := 0;
  LSuite := TBenchSuite.Create('lockfree');
  LSuite.Add('SPSC/TryDequeue', @BenchSpscTryDequeue).Add('MPMC/TryDequeue', @BenchMpmcTryDequeue)
    .Add('SegQueue/TryDequeue', @BenchSegTryDequeue).Add('SPMC/TryDequeue', @BenchSpmcTryDequeue).Add('EBR/Retire', @BenchEbrRetire)
    .Add('Channel/TrySendReceive', @BenchChannelTrySendReceive)
    .Add('ChannelSpsc/TrySendReceive', @BenchChannelSpscTrySendReceive);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('Sink: ', GBenchSink);
  GEbrDomain.Free; GSpsc.Free; GMpmc.Free; GSeg.Free; GSpmc.Free;
  GChannel.Free; GChannelSpsc.Free;
end.
