program bench_platform_thread_lifecycle;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.platform.thread;
var GSink: PtrUInt = 0;
function EmptyThread(AArg: Pointer): Pointer; cdecl; begin Result := AArg; end;
procedure BenchTlsSetGet(const ACtx: IBenchContext);
var LKey: TPlatformTLSKey; LI: Int32;
begin
  if platform_tls_create(LKey) <> 0 then
  begin
    ACtx.Skip('platform_tls_create failed');
    Exit;
  end;
  for LI := 1 to 100 do
  begin
    platform_tls_set(LKey, Pointer(PtrUInt(LI)));
    GSink := GSink xor PtrUInt(platform_tls_get(LKey));
  end;
  platform_tls_destroy(LKey);
end;
procedure BenchYield(const ACtx: IBenchContext);
begin platform_thread_yield; end;
procedure BenchCreateJoin(const ACtx: IBenchContext);
var LH: TPlatformThreadHandle; LR: Pointer;
begin platform_thread_create(LH, @EmptyThread, nil); platform_thread_join(LH, LR); end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('platform-thread');
  LSuite.Add('Tls/SetGet', @BenchTlsSetGet).Add('Yield', @BenchYield).Add('CreateJoin', @BenchCreateJoin);
  WriteLn(LSuite.Run.PrintToConsole);
end.
