program test_net_async_resolve;

{$I nextpas.core.settings.inc}

uses
  cthreads,
  Classes,
  SysUtils,
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

{ 测试异步 DNS 解析 localhost }

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

{ dual-stack: IPv4 literal still succeeds; IPv6 optional if platform returns it for hostnames }

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
    { IPv6 (::1) may or may not be present depending on host; do not hard-fail. }
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

{ 测试异步 DNS 解析 IP 字面量 }

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

{ 测试异步 DNS 解析回调触发 }

procedure TestAsyncResolveCallbackFires;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GFailDone := False;
    GFailResult := Default(TDnsResult);

    { 使用一个可能失败也可能成功的主机名，只验证回调被触发 }
    AsyncResolve(GLoop, 'nonexistent.example.invalid', @DnsFailCallback, nil);

    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCallback, nil);
    GLoop.Run;

    Check(GFailDone, 'DNS callback should fire');
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

{ 测试异步 DNS 解析 Ref 回调 }

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

begin
  T := TTestSuite.Create('net_async_resolve');
  T.Test('AsyncResolveLocalhost', @TestAsyncResolveLocalhost);
  T.Test('AsyncResolveDualStackList', @TestAsyncResolveDualStackList);
  T.Test('AsyncResolveIPLiteral', @TestAsyncResolveIPLiteral);
  T.Test('AsyncResolveCallbackFires', @TestAsyncResolveCallbackFires);
  T.Test('AsyncResolveRefCallback', @TestAsyncResolveRefCallback);
  T.Run;
end.
