program test_net_async_dial;

{$I nextpas.core.settings.inc}

uses
  cthreads,
  SysUtils,
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

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  Inc(GCallCount);
  GStream := AStream;
  GError := AError;
  GDone := True;
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

begin
  T := TTestSuite.Create('net_async_dial');
  T.Test('DialLocalhostSuccess', @TestDialLocalhostSuccess);
  T.Test('DialRefused', @TestDialRefused);
  T.Test('DialTokenCancel', @TestDialTokenCancel);
  T.Test('DialMultiAddrFirstFailsSecondWins', @TestDialMultiAddrFirstFailsSecondWins);
  T.Test('DialRfcTimerDefaultsAndFirstFamilyCount',
    @TestDialRfcTimerDefaultsAndFirstFamilyCount);
  T.Test('StrictCadDoesNotBurstStart', @TestStrictCadDoesNotBurstStart);
  T.Test('CadZeroAllowsImmediateRefill', @TestCadZeroAllowsImmediateRefill);
  T.Test('FirstFamilyAttemptOrder', @TestFirstFamilyAttemptOrder);
  if not T.Run then
    Halt(1);
end.
