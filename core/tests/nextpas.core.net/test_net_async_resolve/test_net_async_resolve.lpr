program test_net_async_resolve;

{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.resolve,
  nextpas.core.net.async.resolve,
  nextpas.core.async.base,
  nextpas.core.async.loop;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDnsDone: Boolean;
  GDnsResult: TDnsResult;
  GRefDone: Boolean;
  GRefResult: TDnsResult;
  GFailDone: Boolean;
  GFailResult: TDnsResult;
  GStreamEvents: Integer;
  GStreamAllDone: Boolean;
  GStreamAddrs: Integer;
  GStreamHasV4: Boolean;

procedure DnsCallback(const AResult: TDnsResult; AContext: Pointer);
begin
  GDnsResult := AResult;
  GDnsDone := True;
  GLoop.Stop;
end;

procedure DnsRefCallback(const AResult: TDnsResult; AContext: Pointer);
begin
  GRefResult := AResult;
  GRefDone := True;
  GLoop.Stop;
end;

procedure DnsFailCallback(const AResult: TDnsResult; AContext: Pointer);
begin
  GFailResult := AResult;
  GFailDone := True;
  GLoop.Stop;
end;

procedure StopCallback(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure StreamCb(const AEvent: TDnsStreamEvent; AContext: Pointer);
var
  LI: Integer;
begin
  Inc(GStreamEvents);
  GStreamAddrs := GStreamAddrs + Length(AEvent.Addresses);
  for LI := 0 to High(AEvent.Addresses) do
    if not AEvent.Addresses[LI].IsIPv6 then
      GStreamHasV4 := True;
  if AEvent.AllDone then
  begin
    GStreamAllDone := True;
    GLoop.Stop;
  end;
end;

procedure TestAsyncResolveLocalhost;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDnsDone := False;
    GDnsResult := Default(TDnsResult);
    AsyncResolve(GLoop, 'localhost', @DnsCallback, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
    GLoop.Run;
    Check(GDnsDone, 'DNS resolution should complete');
    Check(GDnsResult.Success, 'DNS resolution should succeed');
    Check(GDnsResult.FirstAddress.IP = '127.0.0.1', 'localhost should resolve to 127.0.0.1');
    Check(Length(GDnsResult.Addresses) >= 1, 'dual-stack list has at least one address');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveDualStackList;
var
  LI: Integer;
  LHasV4: Boolean;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDnsDone := False;
    GDnsResult := Default(TDnsResult);
    AsyncResolve(GLoop, 'localhost', @DnsCallback, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
    GLoop.Run;
    Check(GDnsDone, 'DNS resolution should complete');
    Check(GDnsResult.Success, 'DNS resolution should succeed');
    LHasV4 := False;
    for LI := 0 to High(GDnsResult.Addresses) do
      if not GDnsResult.Addresses[LI].IsIPv6 then
        LHasV4 := True;
    Check(LHasV4, 'localhost dual-stack list includes IPv4');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveIPLiteral;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDnsDone := False;
    GDnsResult := Default(TDnsResult);
    AsyncResolve(GLoop, '192.168.1.1', @DnsCallback, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
    GLoop.Run;
    Check(GDnsDone, 'DNS resolution should complete');
    Check(GDnsResult.Success, 'DNS resolution should succeed');
    Check(GDnsResult.FirstAddress.IP = '192.168.1.1', 'IP literal should be returned as-is');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveIPv6Literal;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDnsDone := False;
    GDnsResult := Default(TDnsResult);
    AsyncResolve(GLoop, '[::1]', @DnsCallback, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
    GLoop.Run;
    Check(GDnsDone, 'v6 literal complete');
    Check(GDnsResult.Success, 'v6 literal success');
    Check(GDnsResult.FirstAddress.IsIPv6, 'bracket v6 is IPv6');
    CheckEqual('::1', GDnsResult.FirstAddress.IP, 'bracket stripped');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestPreferredAddress;
var
  R: TDnsResult;
begin
  SetLength(R.Addresses, 2);
  R.Error := 0;
  R.Addresses[0] := TNetAddress.IPv6('::1', 0);
  R.Addresses[1] := TNetAddress.IPv4('127.0.0.1', 0);
  CheckEqual('127.0.0.1', R.PreferredAddress(True).IP, 'prefer v4');
  CheckEqual('::1', R.PreferredAddress(False).IP, 'prefer v6');
  CheckEqual(Int64(443), Int64(R.PreferredAddress(True).WithPort(443).Port),
    'WithPort after pick');
  SetLength(R.Addresses, 1);
  R.Addresses[0] := TNetAddress.IPv6('2001:db8::1', 0);
  CheckEqual('2001:db8::1', R.PreferredAddress(True).IP, 'v4-prefer falls back to v6');
end;

procedure TestAsyncResolveCallbackFires;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GFailDone := False;
    GFailResult := Default(TDnsResult);
    AsyncResolve(GLoop, 'nonexistent.example.invalid', @DnsFailCallback, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCallback, nil);
    GLoop.Run;
    Check(GFailDone, 'DNS callback should fire');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveRefCallback;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GRefDone := False;
    GRefResult := Default(TDnsResult);
    AsyncResolveRef(GLoop, 'localhost', @DnsRefCallback, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
    GLoop.Run;
    Check(GRefDone, 'DNS resolution should complete');
    Check(GRefResult.Success, 'DNS resolution should succeed');
    Check(GRefResult.FirstAddress.IP = '127.0.0.1', 'localhost should resolve to 127.0.0.1');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveExParallelLocalhost;
var
  LOpts: TDnsResolveOptions;
  LI: Integer;
  LHasV4: Boolean;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDnsDone := False;
    GDnsResult := Default(TDnsResult);
    LOpts := DefaultDnsResolveOptions;
    LOpts.ResolutionDelayMs := 0;
    Check(AsyncResolveEx(GLoop, 'localhost', LOpts, @DnsCallback, nil),
      'AsyncResolveEx submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCallback, nil);
    GLoop.Run;
    Check(GDnsDone, 'ResolveEx completes');
    Check(GDnsResult.Success, 'ResolveEx success');
    LHasV4 := False;
    for LI := 0 to High(GDnsResult.Addresses) do
      if not GDnsResult.Addresses[LI].IsIPv6 then
        LHasV4 := True;
    Check(LHasV4, 'ResolveEx includes IPv4 for localhost');
    CheckEqual(Int64(DNS_DEFAULT_RESOLUTION_DELAY_MS),
      Int64(DefaultDnsResolveOptions.ResolutionDelayMs),
      'default resolution delay 50ms');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveExIPLiteral;
var
  LOpts: TDnsResolveOptions;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDnsDone := False;
    GDnsResult := Default(TDnsResult);
    LOpts := DefaultDnsResolveOptions;
    LOpts.ResolutionDelayMs := 0;
    Check(AsyncResolveEx(GLoop, '10.0.0.1', LOpts, @DnsCallback, nil),
      'ResolveEx literal submit');
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
    GLoop.Run;
    Check(GDnsDone, 'literal complete');
    Check(GDnsResult.Success, 'literal success');
    Check(GDnsResult.FirstAddress.IP = '10.0.0.1', 'literal passthrough');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

procedure TestAsyncResolveStreamLocalhost;
var
  LOpts: TDnsResolveOptions;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GStreamEvents := 0;
    GStreamAllDone := False;
    GStreamAddrs := 0;
    GStreamHasV4 := False;
    LOpts := DefaultDnsResolveOptions;
    LOpts.ResolutionDelayMs := 0;
    Check(AsyncResolveStream(GLoop, 'localhost', LOpts, @StreamCb, nil),
      'stream submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCallback, nil);
    GLoop.Run;
    Check(GStreamAllDone, 'stream AllDone');
    Check(GStreamEvents >= 1, 'at least one stream event');
    Check(GStreamAddrs >= 1, 'stream delivered addresses');
    Check(GStreamHasV4, 'stream includes IPv4');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_async_resolve');
  T.Test('AsyncResolveLocalhost', @TestAsyncResolveLocalhost);
  T.Test('AsyncResolveDualStackList', @TestAsyncResolveDualStackList);
  T.Test('AsyncResolveIPLiteral', @TestAsyncResolveIPLiteral);
  T.Test('AsyncResolveIPv6Literal', @TestAsyncResolveIPv6Literal);
  T.Test('PreferredAddress', @TestPreferredAddress);
  T.Test('AsyncResolveCallbackFires', @TestAsyncResolveCallbackFires);
  T.Test('AsyncResolveRefCallback', @TestAsyncResolveRefCallback);
  T.Test('AsyncResolveExParallelLocalhost', @TestAsyncResolveExParallelLocalhost);
  T.Test('AsyncResolveExIPLiteral', @TestAsyncResolveExIPLiteral);
  T.Test('AsyncResolveStreamLocalhost', @TestAsyncResolveStreamLocalhost);
  if not T.Run then
    Halt(1);
end.
