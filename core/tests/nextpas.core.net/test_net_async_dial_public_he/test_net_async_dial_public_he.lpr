program test_net_async_dial_public_he;

{$I nextpas.core.settings.inc}

{ Opt-in public DNS Happy Eyeballs statistical sample.
  Enable: NEXTPAS_PUBLIC_DNS_HE=1
  Default: skip (exit 0) — flaky / network dependent; not CI-gating.
  truth=public-dns-he-opt-in; not dual-stack lab matrix; not production SLA. }

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
  nextpas.core.async.loop;

const
  PUBLIC_HE_ROUNDS = 3;
  PUBLIC_HE_HOST = 'one.one.one.one';
  PUBLIC_HE_PORT = 443;
  PUBLIC_HE_DEADLINE_MS = 8000;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  GAttemptCount: Integer;
  GWinnerIsV6: Boolean;
  GStartMs: UInt64;
  GSuccessMs: UInt64;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnAttemptStart(AIndex: Integer; const AAddr: TNetAddress; AContext: Pointer);
begin
  Inc(GAttemptCount);
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

procedure TestPublicDnsHeStats;
var
  LOpts: TAsyncTcpDialOptions;
  LI: Integer;
  LOk, LFail, LAttemptsSum: Integer;
  LMsSum: UInt64;
  LWinnerV6: Integer;
  LElapsed: UInt64;
begin
  if not EnvEnabled then
  begin
    WriteLn('public-dns-he=skip reason=NEXTPAS_PUBLIC_DNS_HE!=1');
    WriteLn('truth=public-dns-he-opt-in; enable with NEXTPAS_PUBLIC_DNS_HE=1');
    Skip('set NEXTPAS_PUBLIC_DNS_HE=1 for public DNS HE stats (flaky)');
    Exit;
  end;

  LOk := 0;
  LFail := 0;
  LAttemptsSum := 0;
  LMsSum := 0;
  LWinnerV6 := 0;

  for LI := 1 to PUBLIC_HE_ROUNDS do
  begin
    GLoop := TAsyncLoop.Create(64);
    try
      GDone := False;
      GError := -1;
      GStream := nil;
      GAttemptCount := 0;
      GWinnerIsV6 := False;
      GStartMs := GetTickCount64;
      GSuccessMs := GStartMs;
      LOpts := DefaultAsyncTcpDialOptions;
      LOpts.OverallDeadline := TDeadline.After(
        TDuration.FromMilliseconds(PUBLIC_HE_DEADLINE_MS));
      LOpts.OnAttemptStart := @OnAttemptStart;
      LOpts.OnAttemptStartContext := nil;
      if not AsyncTcpDial(GLoop, PUBLIC_HE_HOST, PUBLIC_HE_PORT, LOpts, @OnDial, nil) then
      begin
        Inc(LFail);
        Continue;
      end;
      GLoop.Schedule(
        TDuration.FromMilliseconds(PUBLIC_HE_DEADLINE_MS + 1000), @StopCb, nil);
      GLoop.Run;
      if GDone and (GError = 0) and (GStream <> nil) then
      begin
        Inc(LOk);
        if GSuccessMs >= GStartMs then
          LElapsed := GSuccessMs - GStartMs
        else
          LElapsed := 0;
        LMsSum := LMsSum + LElapsed;
        LAttemptsSum := LAttemptsSum + GAttemptCount;
        if GWinnerIsV6 then
          Inc(LWinnerV6);
        GStream.Close;
        GStream := nil;
      end
      else
        Inc(LFail);
    finally
      GLoop.Free;
      GLoop := nil;
    end;
  end;

  WriteLn('metric=public_he_rounds value=', PUBLIC_HE_ROUNDS);
  WriteLn('metric=public_he_ok value=', LOk);
  WriteLn('metric=public_he_fail value=', LFail);
  WriteLn('metric=public_he_host value=', PUBLIC_HE_HOST, ':', PUBLIC_HE_PORT);
  if LOk > 0 then
  begin
    WriteLn('metric=public_he_mean_ms value=',
      FormatFloat('0.0', LMsSum / LOk));
    WriteLn('metric=public_he_attempts_mean value=',
      FormatFloat('0.00', LAttemptsSum / Double(LOk)));
    WriteLn('metric=public_he_winner_v6_ratio value=',
      FormatFloat('0.00', LWinnerV6 / Double(LOk)));
  end
  else
  begin
    WriteLn('metric=public_he_mean_ms value=0');
    WriteLn('metric=public_he_attempts_mean value=0');
    WriteLn('metric=public_he_winner_v6_ratio value=0');
  end;
  WriteLn('truth=public-dns-he-opt-in; flaky; not-ci-gating; sample-not-sla');

  { Soft success: at least one ok when network is available.
    All-fail still exits 0 with metrics so CI never gates on public DNS. }
  if LOk = 0 then
    WriteLn('public-dns-he=soft-fail all rounds failed (network?)')
  else
    WriteLn('public-dns-he=pass');
  Check(True, 'public HE stats collected');
end;

begin
  T := TTestSuite.Create('net_async_dial_public_he');
  T.Test('PublicDnsHeStats', @TestPublicDnsHeStats);
  if not T.Run then
    Halt(1);
end.
