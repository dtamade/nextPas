unit nextpas.core.net.async.dial;
{**
 * Concurrent Happy Eyeballs (RFC8305 subset) over TAsyncLoop.
 * Recommended async dial path (Go Dialer-like). Prefer AsyncTcpDial over
 * AsyncTcpConnect (HE-lite sequential legacy).
 * Staggered multi-A / dual-stack dial: MaxInFlight caps concurrent SYNs;
 * ConnectionAttemptDelayMs is the start-to-start gap (strict CAD; not a burst
 * fill of MaxInFlight). CAD=0 allows immediate refill after failure / next start.
 * DNS uses AsyncResolveStream (parallel A/AAAA + Resolution Delay gate),
 * then dials as families arrive (DNS-race-while-dialing subset).
 * AsyncTcpDialWithDnsFeed injects stream events for lab timing tests.
 * AsyncTcpConnect remains HE-lite (sequential sync). Use AsyncTcpDial for race.
 * Dial error codes: ClassifyNetError(AError) (nextpas.core.net.errors).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.tcp;

const
  HE_DEFAULT_CONNECTION_ATTEMPT_DELAY_MS = 250;
  HE_DEFAULT_RESOLUTION_DELAY_MS = 50;
  HE_DEFAULT_MAX_IN_FLIGHT = 2;
  HE_DEFAULT_FIRST_ADDRESS_FAMILY_COUNT = 1;

type
  { Observability hook (tests): fired on loop thread after AsyncConnect submit. }
  TAsyncTcpDialAttemptStart = procedure(AIndex: Integer; const AAddr: TNetAddress;
    AContext: Pointer);

  TAsyncTcpDialOptions = record
    ConnectionAttemptDelayMs: UInt32; { default 250; 0 = no delay between starts }
    MaxInFlight: UInt32;              { default 2; 0 => default }
    OverallDeadline: TDeadline;       { Infinite = no overall timer }
    Token: IAsyncCancellationToken;   { optional }
    PreferIPv6First: Boolean;         { first family in interleaved order }
    InterleaveFamilies: Boolean;      { default True: vX[0],vY[0],vX[1]... }
    FirstAddressFamilyCount: UInt32;  { default 1: lead N of preferred family }
    ResolutionDelayMs: UInt32;        { DNS Resolution Delay; default 50 }
    OnAttemptStart: TAsyncTcpDialAttemptStart; { optional; default nil }
    OnAttemptStartContext: Pointer;
    { Optional local bind before connect (Go Dialer.LocalAddr subset).
      Empty IP = unset. Family must match remote attempt or bind is skipped. }
    LocalAddr: TNetAddress;
    { Applied to the winning stream before user callback (best-effort). }
    NoDelay: Boolean;   { TCP_NODELAY; default False }
    KeepAlive: Boolean; { SO_KEEPALIVE; default False }
  end;

  TAsyncTcpDialCallback = procedure(AStream: IAsyncTcpStream; AError: Int32;
    AContext: Pointer);

  { Lab / advanced: inject DNS stream events without real getaddrinfo.
    FeedAddresses / SignalDnsDone are posted onto the loop thread. }
  IAsyncTcpDialDnsFeed = interface
    ['{A7C3E91D-4B2F-4E8A-9D1C-6F0B5A8E3D27}']
    procedure FeedAddresses(const AAddrs: array of TNetAddress);
    procedure SignalDnsDone(AError: Int32);
  end;

function DefaultAsyncTcpDialOptions: TAsyncTcpDialOptions;

{ Async resolve + concurrent dial. Callback once on loop thread. }
function AsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer = nil): Boolean;

{ Dial pre-resolved addresses (tests / advanced). }
function AsyncTcpDialAddrs(const ALoop: TAsyncLoop;
  const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer = nil): Boolean;

{ Concurrent dial with caller-fed DNS stream events (lab timing matrix). }
function AsyncTcpDialWithDnsFeed(const ALoop: TAsyncLoop; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer; out AFeed: IAsyncTcpDialDnsFeed): Boolean;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.platform.socket,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.async.resolve;

const
  ECANCELED_LINUX = 125;
  ETIMEDOUT_LINUX = 110;
  ECONNREFUSED_LINUX = 111;

type
  TAsyncTcpDialer = class;
  TAsyncTcpDialDnsFeed = class;

  PDialAttempt = ^TDialAttempt;
  TDialAttempt = record
    Dialer: TAsyncTcpDialer;
    Index: Integer;
    Fd: TPlatformSocket;
    Sa: TPlatformSockAddr;
    Active: Boolean;
  end;

  PDnsFeedPost = ^TDnsFeedPost;
  TDnsFeedPost = record
    Feed: TAsyncTcpDialDnsFeed;
    Event: TDnsStreamEvent;
  end;

  TAsyncTcpDialDnsFeed = class(TInterfacedObject, IAsyncTcpDialDnsFeed)
  private
    FLoop: TAsyncLoop;
    FDialer: TAsyncTcpDialer;
    procedure DetachDialer;
    procedure PostEvent(const AEvent: TDnsStreamEvent);
  public
    constructor Create(const ALoop: TAsyncLoop; ADialer: TAsyncTcpDialer);
    destructor Destroy; override;
    procedure FeedAddresses(const AAddrs: array of TNetAddress);
    procedure SignalDnsDone(AError: Int32);
  end;

  TAsyncTcpDialer = class
  private
    FLoop: TAsyncLoop;
    FPort: UInt16;
    FOptions: TAsyncTcpDialOptions;
    FUserCb: TAsyncTcpDialCallback;
    FUserCtx: Pointer;
    FAddrs: array of TNetAddress;
    FNextIndex: Integer;
    FInFlight: Integer;
    FFinished: Int32;
    FLastError: Int32;
    FStaggerTimer: TAsyncTimerHandle;
    FOverallTimer: TAsyncTimerHandle;
    FAttempts: array of PDialAttempt;
    FTokenBound: Boolean;
    FDnsAllDone: Boolean;
    FDialStarted: Boolean;
    FOverallBound: Boolean;
    FFeedNotify: TAsyncTcpDialDnsFeed; { non-owning; cleared before Free }
    procedure OrderAddresses;
    procedure EnsureOverallTimer;
    procedure AppendAddresses(const ANew: array of TNetAddress);
    procedure OnDnsStream(const AEvent: TDnsStreamEvent);
    procedure StartDialing;
    procedure KickStagger;
    procedure StartNextAttempts;
    function StartAttempt(AIndex: Integer): Boolean;
    procedure OnAttemptDone(AAttempt: PDialAttempt; AResult: Int32);
    procedure FinishSuccess(AAttempt: PDialAttempt);
    procedure FinishFail(AError: Int32);
    procedure AbortAllAttempts;
    procedure CancelTimers;
    procedure MaybeCompleteIfIdle;
    procedure BindToken;
    procedure NotifyFeedDetached;
  public
    constructor Create(const ALoop: TAsyncLoop; APort: UInt16;
      const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
      AContext: Pointer);
    destructor Destroy; override;
    procedure BeginWithHost(const AHost: string);
    procedure BeginWithAddrs(const AAddrs: array of TNetAddress);
    procedure BeginWithDnsFeed;
  end;

procedure DialConnectCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;
procedure DialStaggerCallback(AContext: Pointer); forward;
procedure DialOverallCallback(AContext: Pointer); forward;
procedure DialTokenAbort(AContext: Pointer); forward;
procedure DialTokenNotify(AContext: Pointer); forward;
procedure DialStreamCallback(const AEvent: TDnsStreamEvent; AContext: Pointer); forward;
procedure DialDiscardTimer(AContext: Pointer); forward;
procedure DnsFeedPostCb(AContext: Pointer); forward;
procedure DnsFeedPostDiscard(AContext: Pointer); forward;

function DefaultAsyncTcpDialOptions: TAsyncTcpDialOptions;
begin
  { Default() for managed fields (Token, LocalAddr.IP); never FillChar. }
  Result := Default(TAsyncTcpDialOptions);
  Result.ConnectionAttemptDelayMs := HE_DEFAULT_CONNECTION_ATTEMPT_DELAY_MS;
  Result.MaxInFlight := HE_DEFAULT_MAX_IN_FLIGHT;
  Result.OverallDeadline := TDeadline.Infinite;
  Result.Token := nil;
  Result.PreferIPv6First := False;
  Result.InterleaveFamilies := True;
  Result.FirstAddressFamilyCount := HE_DEFAULT_FIRST_ADDRESS_FAMILY_COUNT;
  Result.ResolutionDelayMs := HE_DEFAULT_RESOLUTION_DELAY_MS;
  Result.OnAttemptStart := nil;
  Result.OnAttemptStartContext := nil;
  Result.LocalAddr.IP := '';
  Result.LocalAddr.Port := 0;
  Result.LocalAddr.IsIPv6 := False;
  Result.NoDelay := False;
  Result.KeepAlive := False;
end;

function InvalidSocket: TPlatformSocket;
begin
  Result := PLATFORM_INVALID_SOCKET;
end;

constructor TAsyncTcpDialer.Create(const ALoop: TAsyncLoop; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer);
begin
  inherited Create;
  FLoop := ALoop;
  FPort := APort;
  FOptions := AOptions;
  { CAD=0 is intentional (immediate refill / no start gap). Only MaxInFlight
    treats 0 as "use default". FirstAddressFamilyCount 0 = no lead prefix. }
  if FOptions.MaxInFlight = 0 then
    FOptions.MaxInFlight := HE_DEFAULT_MAX_IN_FLIGHT;
  FUserCb := ACallback;
  FUserCtx := AContext;
  FNextIndex := 0;
  FInFlight := 0;
  FFinished := 0;
  FLastError := -ECONNREFUSED_LINUX;
  FStaggerTimer := TAsyncTimerHandle.None;
  FOverallTimer := TAsyncTimerHandle.None;
  FTokenBound := False;
  FDnsAllDone := True; { Addrs path has no pending DNS }
  FDialStarted := False;
  FOverallBound := False;
  FFeedNotify := nil;
end;

constructor TAsyncTcpDialDnsFeed.Create(const ALoop: TAsyncLoop; ADialer: TAsyncTcpDialer);
begin
  inherited Create;
  FLoop := ALoop;
  FDialer := ADialer;
end;

destructor TAsyncTcpDialDnsFeed.Destroy;
begin
  if FDialer <> nil then
  begin
    FDialer.FFeedNotify := nil;
    FDialer := nil;
  end;
  inherited Destroy;
end;

procedure TAsyncTcpDialDnsFeed.DetachDialer;
begin
  FDialer := nil;
end;

procedure TAsyncTcpDialDnsFeed.PostEvent(const AEvent: TDnsStreamEvent);
var
  LPost: PDnsFeedPost;
begin
  if (FDialer = nil) or (FLoop = nil) or (not FLoop.IsValid) then
    Exit;
  New(LPost);
  LPost^ := Default(TDnsFeedPost);
  LPost^.Feed := Self;
  LPost^.Event := AEvent;
  Self._AddRef;
  FLoop.PostEx(@DnsFeedPostCb, LPost, @DnsFeedPostDiscard);
end;

procedure TAsyncTcpDialDnsFeed.FeedAddresses(const AAddrs: array of TNetAddress);
var
  LEvent: TDnsStreamEvent;
  LI: Integer;
begin
  if FDialer = nil then
    Exit;
  LEvent := Default(TDnsStreamEvent);
  LEvent.Error := 0;
  LEvent.AllDone := False;
  LEvent.IsIPv6 := False;
  SetLength(LEvent.Addresses, Length(AAddrs));
  for LI := 0 to High(AAddrs) do
  begin
    LEvent.Addresses[LI] := AAddrs[LI];
    if AAddrs[LI].IsIPv6 then
      LEvent.IsIPv6 := True;
  end;
  if Length(AAddrs) = 0 then
    Exit;
  PostEvent(LEvent);
end;

procedure TAsyncTcpDialDnsFeed.SignalDnsDone(AError: Int32);
var
  LEvent: TDnsStreamEvent;
begin
  if FDialer = nil then
    Exit;
  LEvent := Default(TDnsStreamEvent);
  LEvent.Error := AError;
  LEvent.AllDone := True;
  LEvent.IsIPv6 := False;
  SetLength(LEvent.Addresses, 0);
  PostEvent(LEvent);
end;

procedure TAsyncTcpDialer.NotifyFeedDetached;
begin
  if FFeedNotify <> nil then
  begin
    FFeedNotify.DetachDialer;
    FFeedNotify := nil;
  end;
end;

destructor TAsyncTcpDialer.Destroy;
var
  LI: Integer;
begin
  CancelTimers;
  AbortAllAttempts;
  for LI := 0 to High(FAttempts) do
    if FAttempts[LI] <> nil then
    begin
      Dispose(FAttempts[LI]);
      FAttempts[LI] := nil;
    end;
  SetLength(FAttempts, 0);
  inherited Destroy;
end;

procedure TAsyncTcpDialer.CancelTimers;
begin
  if FStaggerTimer.IsValid then
  begin
    FLoop.CancelTimer(FStaggerTimer);
    FStaggerTimer := TAsyncTimerHandle.None;
  end;
  if FOverallTimer.IsValid then
  begin
    FLoop.CancelTimer(FOverallTimer);
    FOverallTimer := TAsyncTimerHandle.None;
  end;
end;

procedure TAsyncTcpDialer.AbortAllAttempts;
var
  LI: Integer;
  LAtt: PDialAttempt;
begin
  for LI := 0 to High(FAttempts) do
  begin
    LAtt := FAttempts[LI];
    if (LAtt <> nil) and LAtt^.Active then
    begin
      LAtt^.Active := False;
      if LAtt^.Fd.IsValid then
      begin
        platform_socket_close(LAtt^.Fd);
        LAtt^.Fd := InvalidSocket;
      end;
      if FInFlight > 0 then
        Dec(FInFlight);
    end;
  end;
end;

procedure TAsyncTcpDialer.OrderAddresses;
var
  LV4, LV6, LOut: array of TNetAddress;
  LI, N4, N6, O, I4, I6, LLead, LTake: Integer;
  LTakeV6: Boolean;
  LLeadIsV6: Boolean;
begin
  if Length(FAddrs) <= 1 then
    Exit;

  SetLength(LV4, Length(FAddrs));
  SetLength(LV6, Length(FAddrs));
  N4 := 0;
  N6 := 0;
  for LI := 0 to High(FAddrs) do
    if FAddrs[LI].IsIPv6 then
    begin
      LV6[N6] := FAddrs[LI];
      Inc(N6);
    end
    else
    begin
      LV4[N4] := FAddrs[LI];
      Inc(N4);
    end;

  SetLength(LOut, N4 + N6);
  O := 0;
  I4 := 0;
  I6 := 0;

  { RFC First Address Family Count: lead with N of preferred family. }
  LLead := Integer(FOptions.FirstAddressFamilyCount);
  LLeadIsV6 := FOptions.PreferIPv6First;
  if LLead > 0 then
  begin
    if LLeadIsV6 then
    begin
      LTake := LLead;
      if LTake > N6 then
        LTake := N6;
      for LI := 0 to LTake - 1 do
      begin
        LOut[O] := LV6[I6];
        Inc(I6);
        Inc(O);
      end;
    end
    else
    begin
      LTake := LLead;
      if LTake > N4 then
        LTake := N4;
      for LI := 0 to LTake - 1 do
      begin
        LOut[O] := LV4[I4];
        Inc(I4);
        Inc(O);
      end;
    end;
  end;

  if not FOptions.InterleaveFamilies then
  begin
    if FOptions.PreferIPv6First then
    begin
      while I6 < N6 do begin LOut[O] := LV6[I6]; Inc(I6); Inc(O); end;
      while I4 < N4 do begin LOut[O] := LV4[I4]; Inc(I4); Inc(O); end;
    end
    else
    begin
      while I4 < N4 do begin LOut[O] := LV4[I4]; Inc(I4); Inc(O); end;
      while I6 < N6 do begin LOut[O] := LV6[I6]; Inc(I6); Inc(O); end;
    end;
  end
  else
  begin
    if (LLead > 0) and ((LLeadIsV6 and (I6 > 0)) or ((not LLeadIsV6) and (I4 > 0))) then
      LTakeV6 := not LLeadIsV6
    else
      LTakeV6 := FOptions.PreferIPv6First;
    while (I4 < N4) or (I6 < N6) do
    begin
      if LTakeV6 then
      begin
        if I6 < N6 then
        begin
          LOut[O] := LV6[I6];
          Inc(I6);
          Inc(O);
        end;
      end
      else if I4 < N4 then
      begin
        LOut[O] := LV4[I4];
        Inc(I4);
        Inc(O);
      end;
      if LTakeV6 then
      begin
        if I4 < N4 then
        begin
          LOut[O] := LV4[I4];
          Inc(I4);
          Inc(O);
        end;
      end
      else if I6 < N6 then
      begin
        LOut[O] := LV6[I6];
        Inc(I6);
        Inc(O);
      end;
      if (I4 >= N4) and (I6 >= N6) then
        Break;
      if LTakeV6 and (I6 >= N6) and (I4 < N4) then
        LTakeV6 := False
      else if (not LTakeV6) and (I4 >= N4) and (I6 < N6) then
        LTakeV6 := True;
    end;
  end;

  SetLength(FAddrs, O);
  for LI := 0 to O - 1 do
    FAddrs[LI] := LOut[LI];
end;

procedure TAsyncTcpDialer.BindToken;
begin
  if FTokenBound or (FOptions.Token = nil) then
    Exit;
  FOptions.Token.OnCancel(@DialTokenNotify, Self);
  FTokenBound := True;
end;

procedure TAsyncTcpDialer.FinishSuccess(AAttempt: PDialAttempt);
var
  LStream: ITcpStream;
  LAsync: IAsyncTcpStream;
  LCb: TAsyncTcpDialCallback;
  LCtx: Pointer;
  LRemote: TNetAddress;
  LExpected: Int32;
begin
  LExpected := 0;
  if not atomic_compare_exchange_strong(FFinished, LExpected, 1, mo_acq_rel, mo_acquire) then
  begin
    if (AAttempt <> nil) and AAttempt^.Fd.IsValid then
    begin
      platform_socket_close(AAttempt^.Fd);
      AAttempt^.Fd := InvalidSocket;
    end;
    Exit;
  end;

  CancelTimers;
  LRemote := FAddrs[AAttempt^.Index];
  if LRemote.Port = 0 then
    LRemote.Port := FPort;
  LStream := NetTcpStreamFromConnectedSocket(AAttempt^.Fd, LRemote);
  AAttempt^.Fd := InvalidSocket;
  AAttempt^.Active := False;
  if FInFlight > 0 then
    Dec(FInFlight);
  AbortAllAttempts;

  if FOptions.NoDelay then
    LStream.SetNoDelay(True);
  if FOptions.KeepAlive then
    LStream.SetKeepAlive(True);

  LAsync := AsyncTcpStreamAdopt(FLoop, LStream);
  LCb := FUserCb;
  LCtx := FUserCtx;
  if Assigned(LCb) then
    LCb(LAsync, 0, LCtx);
  NotifyFeedDetached;
  Free;
end;

procedure TAsyncTcpDialer.FinishFail(AError: Int32);
var
  LCb: TAsyncTcpDialCallback;
  LCtx: Pointer;
  LExpected: Int32;
begin
  LExpected := 0;
  if not atomic_compare_exchange_strong(FFinished, LExpected, 1, mo_acq_rel, mo_acquire) then
    Exit;
  CancelTimers;
  AbortAllAttempts;
  LCb := FUserCb;
  LCtx := FUserCtx;
  if Assigned(LCb) then
    LCb(nil, AError, LCtx);
  NotifyFeedDetached;
  Free;
end;

procedure TAsyncTcpDialer.MaybeCompleteIfIdle;
begin
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;
  if (FInFlight = 0) and (FNextIndex >= Length(FAddrs)) then
  begin
    if not FDnsAllDone then
      Exit; { more addresses may still arrive }
    FinishFail(FLastError);
  end;
end;

function TAsyncTcpDialer.StartAttempt(AIndex: Integer): Boolean;
var
  LAtt: PDialAttempt;
  LDomain: Int32;
  LRemote: TNetAddress;
  LLocalSa: TPlatformSockAddr;
  LRes: Int32;
begin
  Result := False;
  if (AIndex < 0) or (AIndex >= Length(FAddrs)) then
    Exit;
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;

  if AIndex = FNextIndex then
    Inc(FNextIndex)
  else if AIndex > FNextIndex then
    FNextIndex := AIndex + 1;

  LRemote := FAddrs[AIndex];
  if LRemote.Port = 0 then
    LRemote.Port := FPort;

  New(LAtt);
  FillChar(LAtt^, SizeOf(LAtt^), 0);
  LAtt^.Dialer := Self;
  LAtt^.Index := AIndex;
  LAtt^.Active := True;
  LAtt^.Fd := InvalidSocket;

  if not NetBuildConnectSockAddr(LRemote, LAtt^.Sa) then
  begin
    Dispose(LAtt);
    FLastError := -ECONNREFUSED_LINUX;
    Exit;
  end;

  if LRemote.IsIPv6 then
    LDomain := PLATFORM_AF_INET6
  else
    LDomain := PLATFORM_AF_INET;

  LRes := platform_socket_create(LDomain, PLATFORM_SOCK_STREAM, 0, LAtt^.Fd);
  if LRes <> 0 then
  begin
    Dispose(LAtt);
    FLastError := -LRes;
    Exit;
  end;

  { Optional local bind (family must match remote attempt). }
  if (FOptions.LocalAddr.IP <> '') and
     (FOptions.LocalAddr.IsIPv6 = LRemote.IsIPv6) then
  begin
    if not NetBuildConnectSockAddr(FOptions.LocalAddr, LLocalSa) then
    begin
      platform_socket_close(LAtt^.Fd);
      Dispose(LAtt);
      FLastError := -ECONNREFUSED_LINUX;
      Exit;
    end;
    LRes := platform_socket_bind(LAtt^.Fd, @LLocalSa.Storage[0],
      Int32(LLocalSa.Len));
    if LRes <> 0 then
    begin
      platform_socket_close(LAtt^.Fd);
      Dispose(LAtt);
      FLastError := -LRes;
      Exit;
    end;
  end;

  if AIndex >= Length(FAttempts) then
    SetLength(FAttempts, AIndex + 1);
  FAttempts[AIndex] := LAtt;
  Inc(FInFlight);

  if not FLoop.AsyncConnect(PtrInt(LAtt^.Fd.Value), @LAtt^.Sa.Storage[0],
    UInt32(LAtt^.Sa.Len), @DialConnectCallback, LAtt) then
  begin
    Dec(FInFlight);
    platform_socket_close(LAtt^.Fd);
    LAtt^.Fd := InvalidSocket;
    LAtt^.Active := False;
    FLastError := -ECONNREFUSED_LINUX;
    Exit;
  end;
  if Assigned(FOptions.OnAttemptStart) then
    FOptions.OnAttemptStart(AIndex, LRemote, FOptions.OnAttemptStartContext);
  Result := True;
end;

procedure TAsyncTcpDialer.StartNextAttempts;
var
  LGuard: Integer;
begin
  { RFC8305 CAD: at most one successful AsyncConnect submit per call.
    Synchronous setup failures may advance to the next address without waiting
    CAD (no SYN was sent). }
  LGuard := 0;
  while (atomic_load(FFinished, mo_acquire) = 0) and
        (FInFlight < Int32(FOptions.MaxInFlight)) and
        (FNextIndex < Length(FAddrs)) and
        (LGuard < Length(FAddrs) + 2) do
  begin
    Inc(LGuard);
    if StartAttempt(FNextIndex) then
    begin
      KickStagger;
      MaybeCompleteIfIdle;
      Exit;
    end;
  end;
  KickStagger;
  MaybeCompleteIfIdle;
end;

procedure TAsyncTcpDialer.KickStagger;
begin
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;
  if FNextIndex >= Length(FAddrs) then
    Exit;
  if FStaggerTimer.IsValid then
    Exit;
  { CAD=0 + at MaxInFlight: do not arm 0-delay timers (busy-spin). Refill from
    OnAttemptDone (CAD=0 path) when a slot frees. CAD>0 may recheck after delay. }
  if (FInFlight >= Int32(FOptions.MaxInFlight)) and
     (FOptions.ConnectionAttemptDelayMs = 0) then
    Exit;
  FStaggerTimer := FLoop.ScheduleEx(
    TDuration.FromMilliseconds(FOptions.ConnectionAttemptDelayMs),
    @DialStaggerCallback, Self, @DialDiscardTimer);
end;

procedure TAsyncTcpDialer.EnsureOverallTimer;
var
  LRem: TDuration;
begin
  if FOverallBound then
    Exit;
  FOverallBound := True;
  if FOptions.OverallDeadline.IsInfinite then
    Exit;
  LRem := FOptions.OverallDeadline.Remaining;
  if LRem.AsMilliseconds <= 0 then
  begin
    FinishFail(-ETIMEDOUT_LINUX);
    Exit;
  end;
  FOverallTimer := FLoop.ScheduleEx(LRem, @DialOverallCallback, Self, @DialDiscardTimer);
end;

procedure TAsyncTcpDialer.AppendAddresses(const ANew: array of TNetAddress);
var
  LI, LBase, LRemCount, LNewCount, O, IRem, INew: Integer;
  LRem, LMerged: array of TNetAddress;
  LTakeNew: Boolean;
begin
  LNewCount := Length(ANew);
  if LNewCount = 0 then
    Exit;

  if not FDialStarted then
  begin
    LBase := Length(FAddrs);
    SetLength(FAddrs, LBase + LNewCount);
    for LI := 0 to LNewCount - 1 do
      FAddrs[LBase + LI] := ANew[LI];
    Exit;
  end;

  { Interleave newly resolved family into not-yet-attempted suffix. }
  LRemCount := Length(FAddrs) - FNextIndex;
  if LRemCount < 0 then
    LRemCount := 0;
  SetLength(LRem, LRemCount);
  for LI := 0 to LRemCount - 1 do
    LRem[LI] := FAddrs[FNextIndex + LI];

  if FOptions.InterleaveFamilies and (LRemCount > 0) then
  begin
    SetLength(LMerged, LRemCount + LNewCount);
    O := 0;
    IRem := 0;
    INew := 0;
    LTakeNew := True; { bias new family into race soon }
    while (IRem < LRemCount) or (INew < LNewCount) do
    begin
      if LTakeNew and (INew < LNewCount) then
      begin
        LMerged[O] := ANew[INew];
        Inc(INew);
        Inc(O);
      end
      else if IRem < LRemCount then
      begin
        LMerged[O] := LRem[IRem];
        Inc(IRem);
        Inc(O);
      end;
      if (not LTakeNew) and (INew < LNewCount) then
      begin
        LMerged[O] := ANew[INew];
        Inc(INew);
        Inc(O);
      end
      else if LTakeNew and (IRem < LRemCount) then
      begin
        LMerged[O] := LRem[IRem];
        Inc(IRem);
        Inc(O);
      end;
      if (IRem >= LRemCount) and (INew >= LNewCount) then
        Break;
      LTakeNew := not LTakeNew;
    end;
    SetLength(FAddrs, FNextIndex + O);
    for LI := 0 to O - 1 do
      FAddrs[FNextIndex + LI] := LMerged[LI];
  end
  else
  begin
    LBase := Length(FAddrs);
    SetLength(FAddrs, LBase + LNewCount);
    for LI := 0 to LNewCount - 1 do
      FAddrs[LBase + LI] := ANew[LI];
  end;
  SetLength(FAttempts, Length(FAddrs));
end;

procedure TAsyncTcpDialer.OnDnsStream(const AEvent: TDnsStreamEvent);
begin
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;

  if Length(AEvent.Addresses) > 0 then
    AppendAddresses(AEvent.Addresses);

  if AEvent.AllDone then
    FDnsAllDone := True;

  if not FDialStarted then
  begin
    if Length(FAddrs) > 0 then
      StartDialing
    else if FDnsAllDone then
    begin
      if AEvent.Error <> 0 then
        FinishFail(-Abs(AEvent.Error))
      else
        FinishFail(-ECONNREFUSED_LINUX);
    end;
    Exit;
  end;

  if Length(AEvent.Addresses) > 0 then
    StartNextAttempts
  else
    MaybeCompleteIfIdle;
end;

procedure TAsyncTcpDialer.StartDialing;
begin
  if FDialStarted then
    Exit;
  if Length(FAddrs) = 0 then
  begin
    if FDnsAllDone then
      FinishFail(-ECONNREFUSED_LINUX);
    Exit;
  end;
  FDialStarted := True;
  OrderAddresses;
  SetLength(FAttempts, Length(FAddrs));
  BindToken;
  EnsureOverallTimer;
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;

  { First attempt immediate; further starts only via CAD stagger (or CAD=0 path). }
  if StartAttempt(0) then
    KickStagger
  else
    StartNextAttempts;
  MaybeCompleteIfIdle;
end;

procedure TAsyncTcpDialer.OnAttemptDone(AAttempt: PDialAttempt; AResult: Int32);
begin
  if AAttempt = nil then
    Exit;
  if not AAttempt^.Active then
    Exit;
  AAttempt^.Active := False;
  if FInFlight > 0 then
    Dec(FInFlight);

  if AResult >= 0 then
  begin
    FinishSuccess(AAttempt);
    Exit;
  end;

  FLastError := AResult;
  if AAttempt^.Fd.IsValid then
  begin
    platform_socket_close(AAttempt^.Fd);
    AAttempt^.Fd := InvalidSocket;
  end;

  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;

  MaybeCompleteIfIdle;
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;
  if FNextIndex >= Length(FAddrs) then
    Exit;
  { Keep CAD between starts: only CAD=0 refills immediately on failure.
    Otherwise the stagger timer armed at the previous start opens the next SYN. }
  if FOptions.ConnectionAttemptDelayMs = 0 then
    StartNextAttempts
  else
    KickStagger;
end;

procedure TAsyncTcpDialer.BeginWithHost(const AHost: string);
var
  LDnsOpts: TDnsResolveOptions;
begin
  FDnsAllDone := False;
  FDialStarted := False;
  BindToken;
  EnsureOverallTimer;
  if atomic_load(FFinished, mo_acquire) <> 0 then
    Exit;
  LDnsOpts := DefaultDnsResolveOptions;
  LDnsOpts.ResolutionDelayMs := FOptions.ResolutionDelayMs;
  LDnsOpts.PreferIPv6First := FOptions.PreferIPv6First;
  if not AsyncResolveStream(FLoop, AHost, LDnsOpts, @DialStreamCallback, Self) then
    FinishFail(-ECONNREFUSED_LINUX);
end;

procedure TAsyncTcpDialer.BeginWithAddrs(const AAddrs: array of TNetAddress);
var
  LI: Integer;
begin
  FDnsAllDone := True;
  SetLength(FAddrs, Length(AAddrs));
  for LI := 0 to High(AAddrs) do
    FAddrs[LI] := AAddrs[LI];
  StartDialing;
end;

procedure TAsyncTcpDialer.BeginWithDnsFeed;
begin
  FDnsAllDone := False;
  FDialStarted := False;
  BindToken;
  EnsureOverallTimer;
end;

procedure DialConnectCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LAtt: PDialAttempt;
begin
  LAtt := PDialAttempt(AContext);
  if (LAtt = nil) or (LAtt^.Dialer = nil) then
    Exit;
  LAtt^.Dialer.OnAttemptDone(LAtt, AResult);
end;

procedure DialStaggerCallback(AContext: Pointer);
var
  LDialer: TAsyncTcpDialer;
begin
  LDialer := TAsyncTcpDialer(AContext);
  if LDialer = nil then
    Exit;
  LDialer.FStaggerTimer := TAsyncTimerHandle.None;
  if atomic_load(LDialer.FFinished, mo_acquire) <> 0 then
    Exit;
  LDialer.StartNextAttempts;
end;

procedure DialOverallCallback(AContext: Pointer);
var
  LDialer: TAsyncTcpDialer;
begin
  LDialer := TAsyncTcpDialer(AContext);
  if LDialer = nil then
    Exit;
  LDialer.FOverallTimer := TAsyncTimerHandle.None;
  LDialer.FinishFail(-ETIMEDOUT_LINUX);
end;

procedure DialTokenAbort(AContext: Pointer);
var
  LDialer: TAsyncTcpDialer;
begin
  LDialer := TAsyncTcpDialer(AContext);
  if LDialer = nil then
    Exit;
  LDialer.FinishFail(-ECANCELED_LINUX);
end;

procedure DialTokenNotify(AContext: Pointer);
var
  LDialer: TAsyncTcpDialer;
begin
  LDialer := TAsyncTcpDialer(AContext);
  if (LDialer = nil) or (LDialer.FLoop = nil) then
    Exit;
  LDialer.FLoop.Post(@DialTokenAbort, LDialer);
end;

procedure DialStreamCallback(const AEvent: TDnsStreamEvent; AContext: Pointer);
var
  LDialer: TAsyncTcpDialer;
begin
  LDialer := TAsyncTcpDialer(AContext);
  if LDialer = nil then
    Exit;
  LDialer.OnDnsStream(AEvent);
end;

procedure DialDiscardTimer(AContext: Pointer);
begin
end;

procedure DnsFeedPostDiscard(AContext: Pointer);
var
  LPost: PDnsFeedPost;
begin
  LPost := PDnsFeedPost(AContext);
  if LPost = nil then
    Exit;
  if LPost^.Feed <> nil then
    LPost^.Feed._Release;
  LPost^.Event := Default(TDnsStreamEvent);
  Dispose(LPost);
end;

procedure DnsFeedPostCb(AContext: Pointer);
var
  LPost: PDnsFeedPost;
  LFeed: TAsyncTcpDialDnsFeed;
  LEvent: TDnsStreamEvent;
begin
  LPost := PDnsFeedPost(AContext);
  if LPost = nil then
    Exit;
  LFeed := LPost^.Feed;
  LEvent := LPost^.Event;
  LPost^.Event := Default(TDnsStreamEvent);
  Dispose(LPost);
  try
    if (LFeed <> nil) and (LFeed.FDialer <> nil) then
      LFeed.FDialer.OnDnsStream(LEvent);
  finally
    if LFeed <> nil then
      LFeed._Release;
  end;
end;

function AsyncTcpDialAddrs(const ALoop: TAsyncLoop;
  const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer): Boolean;
var
  LDialer: TAsyncTcpDialer;
  LOpts: TAsyncTcpDialOptions;
begin
  Result := False;
  if (ALoop = nil) or (not ALoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  if Length(AAddrs) = 0 then
    Exit;
  LOpts := AOptions;
  LDialer := TAsyncTcpDialer.Create(ALoop, APort, LOpts, ACallback, AContext);
  LDialer.BeginWithAddrs(AAddrs);
  Result := True;
end;

function AsyncTcpDialWithDnsFeed(const ALoop: TAsyncLoop; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer; out AFeed: IAsyncTcpDialDnsFeed): Boolean;
var
  LDialer: TAsyncTcpDialer;
  LFeedObj: TAsyncTcpDialDnsFeed;
  LOpts: TAsyncTcpDialOptions;
begin
  Result := False;
  AFeed := nil;
  if (ALoop = nil) or (not ALoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  LOpts := AOptions;
  LDialer := TAsyncTcpDialer.Create(ALoop, APort, LOpts, ACallback, AContext);
  LFeedObj := TAsyncTcpDialDnsFeed.Create(ALoop, LDialer);
  LDialer.FFeedNotify := LFeedObj;
  LDialer.BeginWithDnsFeed;
  AFeed := LFeedObj;
  Result := True;
end;

function AsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer): Boolean;
var
  LDialer: TAsyncTcpDialer;
  LOpts: TAsyncTcpDialOptions;
begin
  Result := False;
  if (ALoop = nil) or (not ALoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  if AHost = '' then
    Exit;
  LOpts := AOptions;
  LDialer := TAsyncTcpDialer.Create(ALoop, APort, LOpts, ACallback, AContext);
  LDialer.BeginWithHost(AHost);
  Result := True;
end;

end.
