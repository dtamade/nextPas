program test_net_async_dial_public_he;

{$I nextpas.core.settings.inc}

{ Opt-in multi-host public DNS Happy Eyeballs statistical sample (Q21/Q23).
  Enable: NEXTPAS_PUBLIC_DNS_HE=1
  Rounds: NEXTPAS_PUBLIC_DNS_HE_ROUNDS (default 2, clamp 1..5)
  Optional second pass PreferIPv6First: NEXTPAS_PUBLIC_DNS_HE_V6PREF=1
  Default: skip (exit 0) — flaky / network dependent; not CI-gating.
  truth=public-dns-he-multihost-opt-in; sample-not-sla. }

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.cpu,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.loop, nextpas.core.os.env, nextpas.core.text.conv;

const
  PUBLIC_HE_HOST_COUNT = 3;
  PUBLIC_HE_DEFAULT_ROUNDS = 2;
  PUBLIC_HE_PORT = 443;
  PUBLIC_HE_DEADLINE_MS = 8000;

type
  TPublicHeHost = record
    Name: string;
  end;

  THostAgg = record
    Ok: Integer;
    Fail: Integer;
    MsSum: UInt64;
    AttemptsSum: Integer;
    AttemptV4Sum: Integer;
    AttemptV6Sum: Integer;
    WinnerV6: Integer;
  end;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  GAttemptCount: Integer;
  GAttemptV4: Integer;
  GAttemptV6: Integer;
  GWinnerIsV6: Boolean;
  GStartMs: UInt64;
  GSuccessMs: UInt64;
  GHosts: array[0..PUBLIC_HE_HOST_COUNT - 1] of TPublicHeHost;

procedure InitHosts;
begin
  GHosts[0].Name := 'one.one.one.one';
  GHosts[1].Name := 'dns.google';
  GHosts[2].Name := 'cloudflare.com';
end;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnAttemptStart(AIndex: Integer; const AAddr: TNetAddress; AContext: Pointer);
begin
  Inc(GAttemptCount);
  if AAddr.IsIPv6 then
    Inc(GAttemptV6)
  else
    Inc(GAttemptV4);
end;

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GStream := AStream;
  GError := AError;
  GSuccessMs := GetTickCount64;
  if (AError = 0) and (AStream <> nil) then
    GWinnerIsV6 := AStream.RemoteAddr.IsIPv6
  else
    GWinnerIsV6 := False;
  GDone := True;
  GLoop.Stop;
end;

function EnvEnabled: Boolean;
begin
  Result := GetEnvironmentVariable('NEXTPAS_PUBLIC_DNS_HE') = '1';
end;

function EnvV6Pref: Boolean;
begin
  Result := GetEnvironmentVariable('NEXTPAS_PUBLIC_DNS_HE_V6PREF') = '1';
end;

function EnvRounds: Integer;
var
  LS: string;
  LN: Integer;
begin
  LS := GetEnvironmentVariable('NEXTPAS_PUBLIC_DNS_HE_ROUNDS');
  if LS = '' then
    Exit(PUBLIC_HE_DEFAULT_ROUNDS);
  LN := StrToIntDef(LS, PUBLIC_HE_DEFAULT_ROUNDS);
  if LN < 1 then
    LN := 1;
  if LN > 5 then
    LN := 5;
  Result := LN;
end;

procedure ZeroAgg(var A: THostAgg);
begin
  A.Ok := 0;
  A.Fail := 0;
  A.MsSum := 0;
  A.AttemptsSum := 0;
  A.AttemptV4Sum := 0;
  A.AttemptV6Sum := 0;
  A.WinnerV6 := 0;
end;

procedure DialOne(const AHost: string; APreferV6: Boolean; var AAgg: THostAgg);
var
  LOpts: TAsyncTcpDialOptions;
  LElapsed: UInt64;
begin
  GLoop := TAsyncLoop.Create(64);
  try
    GDone := False;
    GError := -1;
    GStream := nil;
    GAttemptCount := 0;
    GAttemptV4 := 0;
    GAttemptV6 := 0;
    GWinnerIsV6 := False;
    GStartMs := GetTickCount64;
    GSuccessMs := GStartMs;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.OverallDeadline := TDeadline.After(
      TDuration.FromMilliseconds(PUBLIC_HE_DEADLINE_MS));
    LOpts.PreferIPv6First := APreferV6;
    LOpts.OnAttemptStart := @OnAttemptStart;
    LOpts.OnAttemptStartContext := nil;
    if not AsyncTcpDial(GLoop, AHost, PUBLIC_HE_PORT, LOpts, @OnDial, nil) then
    begin
      Inc(AAgg.Fail);
      Exit;
    end;
    GLoop.Schedule(
      TDuration.FromMilliseconds(PUBLIC_HE_DEADLINE_MS + 1000), @StopCb, nil);
    GLoop.Run;
    if GDone and (GError = 0) and (GStream <> nil) then
    begin
      Inc(AAgg.Ok);
      if GSuccessMs >= GStartMs then
        LElapsed := GSuccessMs - GStartMs
      else
        LElapsed := 0;
      AAgg.MsSum := AAgg.MsSum + LElapsed;
      AAgg.AttemptsSum := AAgg.AttemptsSum + GAttemptCount;
      AAgg.AttemptV4Sum := AAgg.AttemptV4Sum + GAttemptV4;
      AAgg.AttemptV6Sum := AAgg.AttemptV6Sum + GAttemptV6;
      if GWinnerIsV6 then
        Inc(AAgg.WinnerV6);
      GStream.Close;
      GStream := nil;
    end
    else
      Inc(AAgg.Fail);
  finally
    GLoop.Free;
    GLoop := nil;
  end;
end;

procedure EmitHostMetrics(const AHost: string; const ATag: string;
  const A: THostAgg);
var
  LMeanMs, LAttMean, LAttV6Ratio, LWinV6: Double;
  LAttTotal: Integer;
begin
  if A.Ok > 0 then
  begin
    LMeanMs := A.MsSum / A.Ok;
    LAttMean := A.AttemptsSum / Double(A.Ok);
    LWinV6 := A.WinnerV6 / Double(A.Ok);
  end
  else
  begin
    LMeanMs := 0;
    LAttMean := 0;
    LWinV6 := 0;
  end;
  LAttTotal := A.AttemptV4Sum + A.AttemptV6Sum;
  if LAttTotal > 0 then
    LAttV6Ratio := A.AttemptV6Sum / Double(LAttTotal)
  else
    LAttV6Ratio := 0;
  WriteLn('metric=public_he_host host=', AHost,
    ' tag=', ATag,
    ' ok=', A.Ok,
    ' fail=', A.Fail,
    ' mean_ms=', FormatFloat('0.0', LMeanMs),
    ' attempts_mean=', FormatFloat('0.00', LAttMean),
    ' attempt_v6_ratio=', FormatFloat('0.00', LAttV6Ratio),
    ' winner_v6_ratio=', FormatFloat('0.00', LWinV6));
end;

procedure RunMatrix(APreferV6: Boolean; const ATag: string;
  ARounds: Integer; var ATotalOk, ATotalFail: Integer);
var
  LI, LR: Integer;
  LAgg: THostAgg;
begin
  for LI := 0 to PUBLIC_HE_HOST_COUNT - 1 do
  begin
    ZeroAgg(LAgg);
    for LR := 1 to ARounds do
      DialOne(GHosts[LI].Name, APreferV6, LAgg);
    EmitHostMetrics(GHosts[LI].Name, ATag, LAgg);
    ATotalOk := ATotalOk + LAgg.Ok;
    ATotalFail := ATotalFail + LAgg.Fail;
  end;
end;

procedure TestPublicDnsHeStats;
var
  LRounds: Integer;
  LTotalOk, LTotalFail: Integer;
begin
  InitHosts;
  if not EnvEnabled then
  begin
    WriteLn('public-dns-he=skip reason=NEXTPAS_PUBLIC_DNS_HE!=1');
    WriteLn('truth=public-dns-he-multihost-opt-in; enable with NEXTPAS_PUBLIC_DNS_HE=1');
    Skip('set NEXTPAS_PUBLIC_DNS_HE=1 for public DNS HE multihost stats (flaky)');
    Exit;
  end;

  LRounds := EnvRounds;
  LTotalOk := 0;
  LTotalFail := 0;

  WriteLn('metric=public_he_rounds value=', LRounds);
  WriteLn('metric=public_he_host_count value=', PUBLIC_HE_HOST_COUNT);
  WriteLn('metric=public_he_port value=', PUBLIC_HE_PORT);

  RunMatrix(False, 'default', LRounds, LTotalOk, LTotalFail);
  if EnvV6Pref then
    RunMatrix(True, 'prefer_v6', LRounds, LTotalOk, LTotalFail);

  WriteLn('metric=public_he_aggregate ok=', LTotalOk,
    ' fail=', LTotalFail,
    ' hosts=', PUBLIC_HE_HOST_COUNT);
  WriteLn('truth=public-dns-he-multihost-opt-in; flaky; not-ci-gating; sample-not-sla');

  if LTotalOk = 0 then
    WriteLn('public-dns-he=soft-fail all rounds failed (network?)')
  else
    WriteLn('public-dns-he=pass');
  Check(True, 'public HE multihost stats collected');
end;

begin
  T := TTestSuite.Create('net_async_dial_public_he');
  T.Test('PublicDnsHeStats', @TestPublicDnsHeStats);
  if not T.Run then
    Halt(1);
end.
