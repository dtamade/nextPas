program test_net_async_dial;

{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.cpu,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  GCallCount: Integer;
  GAttemptCount: Integer;
  GAttemptTicks: array[0..7] of UInt64;
  GAttemptPorts: array[0..7] of UInt16;
  GAttemptIsV6: array[0..7] of Boolean;
  GFeed: IAsyncTcpDialDnsFeed;
  GLateFeedPosted: Boolean;
  GAttemptBeforeLate: Boolean;
  GAllowDialDone: Boolean;
  GDialDoneTooEarly: Boolean;
  GFeedListenerPort: UInt16;
  GControlCalls: Integer;
  GControlRejectLeft: Integer;
  GResolvePort: UInt16;
  GResolveCalls: Integer;
  GResultCalls: Integer;
  GResultOk: Integer;
  GResultFail: Integer;

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  Inc(GCallCount);
  GStream := AStream;
  GError := AError;
  GDone := True;
  if not GAllowDialDone then
    GDialDoneTooEarly := True;
  GLoop.Stop;
end;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnAttemptStart(AIndex: Integer; const AAddr: TNetAddress; AContext: Pointer);
begin
  if GAttemptCount > High(GAttemptTicks) then
    Exit;
  GAttemptTicks[GAttemptCount] := GetTickCount64;
  GAttemptPorts[GAttemptCount] := AAddr.Port;
  GAttemptIsV6[GAttemptCount] := AAddr.IsIPv6;
  Inc(GAttemptCount);
  if not GLateFeedPosted then
    GAttemptBeforeLate := True;
end;

procedure ResetAttemptObs;
var
  LI: Integer;
begin
  GAttemptCount := 0;
  for LI := 0 to High(GAttemptTicks) do
  begin
    GAttemptTicks[LI] := 0;
    GAttemptPorts[LI] := 0;
    GAttemptIsV6[LI] := False;
  end;
end;

procedure TestDialLocalhostSuccess;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 50;
    LOpts.MaxInFlight := 2;
    Check(AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil), 'dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'dial callback');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream <> nil, 'stream non-nil');
    CheckEqual(Int64(0), Int64(GError), 'error 0');
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialRefused;
var
  LOpts: TAsyncTcpDialOptions;
  LAddrs: array[0..0] of TNetAddress;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := 0;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 0);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 20;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 1, LOpts, @OnDial, nil), 'dial refused submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'dial callback on refuse');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream = nil, 'stream nil on refuse');
    Check(GError <> 0, 'error non-zero');
  finally
    GLoop.Free;
  end;
end;

procedure TestDialTokenCancel;
var
  LOpts: TAsyncTcpDialOptions;
  LToken: IAsyncCancellationToken;
  LAddrs: array[0..0] of TNetAddress;
begin
  GLoop := TAsyncLoop.Create(32);
  LToken := CreateCancellationToken;
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := 0;
    { Blackhole-ish: connect to TEST-NET that may hang or fail; cancel quickly }
    LAddrs[0] := TNetAddress.IPv4('172.16.0.1', 0);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.Token := LToken;
    LOpts.ConnectionAttemptDelayMs := 500;
    LOpts.OverallDeadline := TDeadline.After(TDuration.FromMilliseconds(3000));
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 9, LOpts, @OnDial, nil), 'dial cancel submit');
    LToken.Cancel;
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'cancel completes');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream = nil, 'nil stream');
    CheckEqual(Int64(-125), Int64(GError), 'ECANCELED');
  finally
    LToken := nil;
    GLoop.Free;
  end;
end;

procedure TestDialMultiAddrFirstFailsSecondWins;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
  LAddrs: array[0..1] of TNetAddress;
begin
  { Concurrent HE: refused port then real listener — second wins, single callback. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1); { refused }
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 10;
    LOpts.MaxInFlight := 2;
    LOpts.InterleaveFamilies := False;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil),
      'multi-addr dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'multi-addr dial completes');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream <> nil, 'second address wins');
    CheckEqual(Int64(0), Int64(GError), 'success');
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialRfcTimerDefaultsAndFirstFamilyCount;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
  LAddrs: array[0..3] of TNetAddress;
begin
  { Defaults + FirstAddressFamilyCount=2 with dual-stack-ish list still dials. }
  CheckEqual(Int64(HE_DEFAULT_CONNECTION_ATTEMPT_DELAY_MS), Int64(250),
    'conn delay const');
  CheckEqual(Int64(HE_DEFAULT_RESOLUTION_DELAY_MS), Int64(50), 'res delay const');
  CheckEqual(Int64(HE_DEFAULT_MAX_IN_FLIGHT), Int64(2), 'max in flight const');
  CheckEqual(Int64(HE_DEFAULT_FIRST_ADDRESS_FAMILY_COUNT), Int64(1),
    'first family count const');
  LOpts := DefaultAsyncTcpDialOptions;
  CheckEqual(Int64(LOpts.FirstAddressFamilyCount), Int64(1), 'default first family');
  CheckEqual(Int64(LOpts.ResolutionDelayMs), Int64(50), 'default res delay');

  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    { Two v4 then two pseudo-v6 literals (may fail connect) — lead 2 v4. }
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', LPort);
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', 1);
    LAddrs[2] := TNetAddress.IPv6('::1', 1);
    LAddrs[3] := TNetAddress.IPv6('::1', 2);
    LOpts.ConnectionAttemptDelayMs := 10;
    LOpts.MaxInFlight := 2;
    LOpts.InterleaveFamilies := False;
    LOpts.FirstAddressFamilyCount := 2;
    LOpts.PreferIPv6First := False;
    LOpts.ResolutionDelayMs := 0;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil),
      'first-family dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'first-family dial completes');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream <> nil, 'lead v4 listener wins');
    CheckEqual(Int64(0), Int64(GError), 'success');
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestStrictCadDoesNotBurstStart;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
  LAddrs: array[0..3] of TNetAddress;
  LI: Integer;
  LDelta: UInt64;
begin
  { MaxInFlight=2 must not burst-start two SYNs in the same tick when CAD>0. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    ResetAttemptObs;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1);
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', 2);
    LAddrs[2] := TNetAddress.IPv4('127.0.0.1', 3);
    LAddrs[3] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 60;
    LOpts.MaxInFlight := 2;
    LOpts.InterleaveFamilies := False;
    LOpts.OnAttemptStart := @OnAttemptStart;
    LOpts.OnAttemptStartContext := nil;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil), 'strict CAD submit');
    GLoop.Schedule(TDuration.FromMilliseconds(5000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'strict CAD completes');
    Check(GStream <> nil, 'listener wins');
    Check(GAttemptCount >= 2, 'at least two attempts observed');
    for LI := 1 to GAttemptCount - 1 do
    begin
      LDelta := GAttemptTicks[LI] - GAttemptTicks[LI - 1];
      Check(LDelta >= 40, 'CAD gap >= 40ms between starts');
    end;
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestCadZeroAllowsImmediateRefill;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
  LAddrs: array[0..2] of TNetAddress;
  LStart, LElapsed: UInt64;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    ResetAttemptObs;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1);
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', 2);
    LAddrs[2] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 2;
    LOpts.InterleaveFamilies := False;
    LOpts.OnAttemptStart := @OnAttemptStart;
    LStart := GetTickCount64;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil), 'CAD0 submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    LElapsed := GetTickCount64 - LStart;
    Check(GDone, 'CAD0 completes');
    Check(GStream <> nil, 'CAD0 stream');
    Check(GAttemptCount >= 2, 'CAD0 multiple attempts');
    Check(LElapsed < 1500, 'CAD0 finishes without long stagger stack');
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestFirstFamilyAttemptOrder;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
  LAddrs: array[0..3] of TNetAddress;
begin
  { PreferIPv6First=False, FirstAddressFamilyCount=2, no interleave:
    first two attempts must be IPv4. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GAllowDialDone := True;
    GDialDoneTooEarly := False;
    ResetAttemptObs;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv6('::1', 1);
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', 1);
    LAddrs[2] := TNetAddress.IPv4('127.0.0.1', LPort);
    LAddrs[3] := TNetAddress.IPv6('::1', 2);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 5;
    LOpts.MaxInFlight := 1;
    LOpts.InterleaveFamilies := False;
    LOpts.FirstAddressFamilyCount := 2;
    LOpts.PreferIPv6First := False;
    LOpts.OnAttemptStart := @OnAttemptStart;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil),
      'family order submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'family order completes');
    Check(GStream <> nil, 'family order stream');
    Check(GAttemptCount >= 1, 'at least one attempt');
    Check(not GAttemptIsV6[0], 'first attempt IPv4 (lead family)');
    if GAttemptCount >= 2 then
      Check(not GAttemptIsV6[1], 'second attempt still IPv4 lead');
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure RaceFeedEarlyWithListener(AContext: Pointer);
var
  LAddrs: array[0..1] of TNetAddress;
begin
  if GFeed = nil then
    Exit;
  LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1);
  LAddrs[1] := TNetAddress.IPv4('127.0.0.1', GFeedListenerPort);
  GFeed.FeedAddresses(LAddrs);
end;

procedure RaceFeedLateFamily(AContext: Pointer);
var
  LAddrs: array[0..0] of TNetAddress;
begin
  if GFeed = nil then
    Exit;
  GLateFeedPosted := True;
  LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 2);
  GFeed.FeedAddresses(LAddrs);
  GFeed.SignalDnsDone(0);
end;

procedure TestDnsRaceStartsBeforeLateFamily;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
begin
  { Lab matrix: first DNS batch must start HE before a late batch arrives. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GAllowDialDone := True;
    GDialDoneTooEarly := False;
    GLateFeedPosted := False;
    GAttemptBeforeLate := False;
    GFeed := nil;
    ResetAttemptObs;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    GFeedListenerPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 30;
    LOpts.MaxInFlight := 2;
    LOpts.InterleaveFamilies := False;
    LOpts.OnAttemptStart := @OnAttemptStart;
    Check(AsyncTcpDialWithDnsFeed(GLoop, 0, LOpts, @OnDial, nil, GFeed),
      'dns feed submit');
    Check(GFeed <> nil, 'feed non-nil');
    GLoop.Schedule(TDuration.FromMilliseconds(0), @RaceFeedEarlyWithListener, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(80), @RaceFeedLateFamily, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(5000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'dns race completes');
    Check(GStream <> nil, 'listener wins via early batch');
    Check(GAttemptBeforeLate, 'attempt started before late DNS family');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    GStream := nil;
    LListener := nil;
    GFeed := nil;
  finally
    GFeed := nil;
    GLoop.Free;
  end;
end;

procedure RaceFeedEarlyRefuseOnly(AContext: Pointer);
var
  LAddrs: array[0..0] of TNetAddress;
begin
  if GFeed = nil then
    Exit;
  LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1);
  GFeed.FeedAddresses(LAddrs);
end;

procedure RaceFeedLateListener(AContext: Pointer);
var
  LAddrs: array[0..0] of TNetAddress;
begin
  if GFeed = nil then
    Exit;
  GLateFeedPosted := True;
  LAddrs[0] := TNetAddress.IPv4('127.0.0.1', GFeedListenerPort);
  GFeed.FeedAddresses(LAddrs);
  GFeed.SignalDnsDone(0);
end;

procedure TestDnsRaceLateFamilyInterleaves;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LI: Integer;
  LSawListener: Boolean;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GAllowDialDone := True;
    GDialDoneTooEarly := False;
    GLateFeedPosted := False;
    GAttemptBeforeLate := False;
    GFeed := nil;
    ResetAttemptObs;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    GFeedListenerPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 2;
    LOpts.InterleaveFamilies := True;
    LOpts.OnAttemptStart := @OnAttemptStart;
    Check(AsyncTcpDialWithDnsFeed(GLoop, 0, LOpts, @OnDial, nil, GFeed),
      'late family feed submit');
    GLoop.Schedule(TDuration.FromMilliseconds(0), @RaceFeedEarlyRefuseOnly, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(40), @RaceFeedLateListener, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(5000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'late family dial completes');
    Check(GStream <> nil, 'late listener wins');
    CheckEqual(Int64(0), Int64(GError), 'success');
    LSawListener := False;
    for LI := 0 to GAttemptCount - 1 do
      if GAttemptPorts[LI] = GFeedListenerPort then
        LSawListener := True;
    Check(LSawListener, 'OnAttemptStart saw late listener port');
    GStream := nil;
    LListener := nil;
    GFeed := nil;
  finally
    GFeed := nil;
    GLoop.Free;
  end;
end;

procedure RaceSignalDoneOnly(AContext: Pointer);
begin
  if GFeed = nil then
    Exit;
  GAllowDialDone := True;
  GFeed.SignalDnsDone(111);
end;

procedure TestDnsRaceEmptyUntilDoneFails;
var
  LOpts: TAsyncTcpDialOptions;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := 0;
    GAllowDialDone := False;
    GDialDoneTooEarly := False;
    GFeed := nil;
    ResetAttemptObs;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    Check(AsyncTcpDialWithDnsFeed(GLoop, 0, LOpts, @OnDial, nil, GFeed),
      'empty dns feed submit');
    GLoop.Schedule(TDuration.FromMilliseconds(0), @RaceSignalDoneOnly, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'empty dns completes');
    Check(GStream = nil, 'nil stream');
    Check(GError <> 0, 'error non-zero');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    GFeed := nil;
  finally
    GFeed := nil;
    GLoop.Free;
  end;
end;

procedure RaceFeedRefuseHoldDns(AContext: Pointer);
var
  LAddrs: array[0..0] of TNetAddress;
begin
  if GFeed = nil then
    Exit;
  LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1);
  GFeed.FeedAddresses(LAddrs);
end;

procedure RaceSignalAllDoneLater(AContext: Pointer);
begin
  if GFeed = nil then
    Exit;
  GAllowDialDone := True;
  GFeed.SignalDnsDone(0);
end;

procedure TestDnsRaceWaitsAllDoneWhenAddrsExhausted;
var
  LOpts: TAsyncTcpDialOptions;
begin
  { Refuse-only batch must not finish until AllDone (FDnsAllDone). }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := 0;
    GAllowDialDone := False;
    GDialDoneTooEarly := False;
    GFeed := nil;
    ResetAttemptObs;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 2;
    LOpts.OnAttemptStart := @OnAttemptStart;
    Check(AsyncTcpDialWithDnsFeed(GLoop, 0, LOpts, @OnDial, nil, GFeed),
      'wait all-done submit');
    GLoop.Schedule(TDuration.FromMilliseconds(0), @RaceFeedRefuseHoldDns, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(60), @RaceSignalAllDoneLater, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'wait all-done completes');
    Check(not GDialDoneTooEarly, 'did not complete before AllDone');
    Check(GStream = nil, 'fail after AllDone');
    Check(GError <> 0, 'error after exhaust');
    GFeed := nil;
  finally
    GFeed := nil;
    GLoop.Free;
  end;
end;

procedure TestDialLocalAddrBind;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
  LLocal: TNetAddress;
begin
  { Bind-before-connect: LocalAddr 127.0.0.1:0 → connected stream local is loopback. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 1;
    LOpts.LocalAddr := TNetAddress.IPv4('127.0.0.1', 0);
    Check(AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil),
      'localaddr dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'localaddr dial callback');
    CheckEqual(Int64(0), Int64(GError), 'localaddr error 0');
    Check(GStream <> nil, 'localaddr stream');
    LLocal := GStream.LocalAddr;
    Check(not LLocal.IsIPv6, 'local is IPv4');
    CheckEqual(LLocal.IP, '127.0.0.1', 'local IP loopback');
    GStream.Close;
    GStream := nil;
    LListener.Close;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialNoDelayKeepAliveOptions;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
begin
  { NoDelay/KeepAlive apply to winning stream before callback (smoke: dial still ok). }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.NoDelay := True;
    LOpts.KeepAlive := True;
    Check(AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil),
      'nodelay/keepalive dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'nodelay/keepalive callback');
    CheckEqual(Int64(0), Int64(GError), 'nodelay/keepalive error 0');
    Check(GStream <> nil, 'nodelay/keepalive stream');
    { Re-apply to prove APIs remain live on adopted stream. }
    GStream.SetNoDelay(True);
    GStream.SetKeepAlive(True);
    GStream.Close;
    GStream := nil;
    LListener.Close;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure OnControlOk(AFd: PtrUInt; const ARemote: TNetAddress; AContext: Pointer;
  var AError: Int32);
begin
  Inc(GControlCalls);
  Check(AFd <> 0, 'control fd non-zero');
  Check(ARemote.Port <> 0, 'control remote port');
  AError := 0;
end;

procedure OnControlRejectFirst(AFd: PtrUInt; const ARemote: TNetAddress;
  AContext: Pointer; var AError: Int32);
begin
  Inc(GControlCalls);
  if GControlRejectLeft > 0 then
  begin
    Dec(GControlRejectLeft);
    AError := 111; { ECONNREFUSED-ish; fail this attempt }
  end
  else
    AError := 0;
end;

procedure OnResolveLocal(const AHost: string; APort: UInt16;
  const AFeed: IAsyncTcpDialDnsFeed; AContext: Pointer);
var
  LAddrs: array[0..0] of TNetAddress;
begin
  Inc(GResolveCalls);
  Check(AFeed <> nil, 'resolve feed non-nil');
  CheckEqual(AHost, 'custom.example', 'resolve host passthrough');
  LAddrs[0] := TNetAddress.IPv4('127.0.0.1', GResolvePort);
  AFeed.FeedAddresses(LAddrs);
  AFeed.SignalDnsDone(0);
end;

procedure TestDialControlOk;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GControlCalls := 0;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.OnControl := @OnControlOk;
    Check(AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil),
      'control dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'control dial done');
    CheckEqual(Int64(0), Int64(GError), 'control dial ok');
    Check(GControlCalls >= 1, 'control invoked');
    Check(GStream <> nil, 'control stream');
    GStream.Close;
    GStream := nil;
    LListener.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialControlRejectsFirstAttempt;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LAddrs: array[0..1] of TNetAddress;
  LPort: UInt16;
begin
  { First addr Control-fails; second connects. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GControlCalls := 0;
    GControlRejectLeft := 1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1); { will be rejected by Control }
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 1;
    LOpts.OnControl := @OnControlRejectFirst;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil),
      'control reject submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'control reject dial done');
    CheckEqual(Int64(0), Int64(GError), 'second attempt wins');
    Check(GControlCalls >= 2, 'control on both attempts');
    Check(GStream <> nil, 'stream after reject-first');
    GStream.Close;
    GStream := nil;
    LListener.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialOnResolveInjectsAddrs;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GResolveCalls := 0;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    GResolvePort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.OnResolve := @OnResolveLocal;
    Check(AsyncTcpDial(GLoop, 'custom.example', GResolvePort, LOpts, @OnDial, nil),
      'onresolve dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'onresolve dial done');
    CheckEqual(Int64(1), Int64(GResolveCalls), 'onresolve once');
    CheckEqual(Int64(0), Int64(GError), 'onresolve dial ok');
    Check(GStream <> nil, 'onresolve stream');
    GStream.Close;
    GStream := nil;
    LListener.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialAddressFamilyIPv4Only;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LAddrs: array[0..1] of TNetAddress;
  LPort: UInt16;
begin
  { v6-looking entry filtered out; only IPv4 attempted. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    ResetAttemptObs;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv6('::1', LPort); { filtered }
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.AddressFamily := dafIPv4;
    LOpts.OnAttemptStart := @OnAttemptStart;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil), 'v4only submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'v4only done');
    CheckEqual(Int64(0), Int64(GError), 'v4only ok');
    Check(GStream <> nil, 'v4only stream');
    CheckEqual(Int64(1), Int64(GAttemptCount), 'only one attempt');
    Check(not GAttemptIsV6[0], 'attempt was v4');
    GStream.Close;
    GStream := nil;
    LListener.Close;
  finally
    GLoop.Free;
  end;
end;

procedure OnAttemptResultObs(AIndex: Integer; const AAddr: TNetAddress;
  AError: Int32; AContext: Pointer);
begin
  Inc(GResultCalls);
  if AError = 0 then
    Inc(GResultOk)
  else
    Inc(GResultFail);
  Check(AAddr.Port <> 0, 'result addr port');
end;

procedure TestDialAttemptResultHook;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LAddrs: array[0..1] of TNetAddress;
  LPort: UInt16;
begin
  { First addr refused port → fail result; second succeeds → ok result. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    GResultCalls := 0;
    GResultOk := 0;
    GResultFail := 0;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 1);
    LAddrs[1] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 1;
    LOpts.OnAttemptResult := @OnAttemptResultObs;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDial, nil),
      'attempt result submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'attempt result dial done');
    CheckEqual(Int64(0), Int64(GError), 'winner ok');
    Check(GResultFail >= 1, 'saw fail result');
    Check(GResultOk >= 1, 'saw ok result');
    Check(GResultCalls >= 2, 'at least two results');
    GStream.Close;
    GStream := nil;
    LListener.Close;
  finally
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_async_dial');
  GAllowDialDone := True;
  GDialDoneTooEarly := False;
  T.Test('DialLocalhostSuccess', @TestDialLocalhostSuccess);
  T.Test('DialRefused', @TestDialRefused);
  T.Test('DialTokenCancel', @TestDialTokenCancel);
  T.Test('DialMultiAddrFirstFailsSecondWins', @TestDialMultiAddrFirstFailsSecondWins);
  T.Test('DialRfcTimerDefaultsAndFirstFamilyCount',
    @TestDialRfcTimerDefaultsAndFirstFamilyCount);
  T.Test('StrictCadDoesNotBurstStart', @TestStrictCadDoesNotBurstStart);
  T.Test('CadZeroAllowsImmediateRefill', @TestCadZeroAllowsImmediateRefill);
  T.Test('FirstFamilyAttemptOrder', @TestFirstFamilyAttemptOrder);
  T.Test('DnsRaceStartsBeforeLateFamily', @TestDnsRaceStartsBeforeLateFamily);
  T.Test('DnsRaceLateFamilyInterleaves', @TestDnsRaceLateFamilyInterleaves);
  T.Test('DnsRaceEmptyUntilDoneFails', @TestDnsRaceEmptyUntilDoneFails);
  T.Test('DnsRaceWaitsAllDoneWhenAddrsExhausted',
    @TestDnsRaceWaitsAllDoneWhenAddrsExhausted);
  T.Test('DialLocalAddrBind', @TestDialLocalAddrBind);
  T.Test('DialNoDelayKeepAliveOptions', @TestDialNoDelayKeepAliveOptions);
  T.Test('DialControlOk', @TestDialControlOk);
  T.Test('DialControlRejectsFirstAttempt', @TestDialControlRejectsFirstAttempt);
  T.Test('DialOnResolveInjectsAddrs', @TestDialOnResolveInjectsAddrs);
  T.Test('DialAddressFamilyIPv4Only', @TestDialAddressFamilyIPv4Only);
  T.Test('DialAttemptResultHook', @TestDialAttemptResultHook);
  if not T.Run then
    Halt(1);
end.
