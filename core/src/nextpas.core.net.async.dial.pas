unit nextpas.core.net.async.dial;
{**
 * Concurrent Happy Eyeballs (RFC8305 subset) over TAsyncLoop.
 * Staggered multi-A / dual-stack dial: MaxInFlight attempts in parallel,
 * ConnectionAttemptDelay between starts; first success wins.
 * AsyncTcpConnect remains HE-lite (sequential sync). Use AsyncTcpDial for race.
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

type
  TAsyncTcpDialOptions = record
    ConnectionAttemptDelayMs: UInt32; { default 250 }
    MaxInFlight: UInt32;              { default 2 }
    OverallDeadline: TDeadline;       { Infinite = no overall timer }
    Token: IAsyncCancellationToken;   { optional }
    PreferIPv6First: Boolean;         { first family in interleaved order }
    InterleaveFamilies: Boolean;      { default True: vX[0],vY[0],vX[1]... }
  end;

  TAsyncTcpDialCallback = procedure(AStream: IAsyncTcpStream; AError: Int32;
    AContext: Pointer);

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

  PDialAttempt = ^TDialAttempt;
  TDialAttempt = record
    Dialer: TAsyncTcpDialer;
    Index: Integer;
    Fd: TPlatformSocket;
    Sa: TPlatformSockAddr;
    Active: Boolean;
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
    procedure OrderAddresses;
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
  public
    constructor Create(const ALoop: TAsyncLoop; APort: UInt16;
      const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
      AContext: Pointer);
    destructor Destroy; override;
    procedure BeginWithHost(const AHost: string);
    procedure BeginWithAddrs(const AAddrs: array of TNetAddress);
  end;

procedure DialConnectCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer); forward;
procedure DialStaggerCallback(AContext: Pointer); forward;
procedure DialOverallCallback(AContext: Pointer); forward;
procedure DialTokenAbort(AContext: Pointer); forward;
procedure DialTokenNotify(AContext: Pointer); forward;
procedure DialResolveCallback(const AResult: TDnsResult; AContext: Pointer); forward;
procedure DialDiscardTimer(AContext: Pointer); forward;

function DefaultAsyncTcpDialOptions: TAsyncTcpDialOptions;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ConnectionAttemptDelayMs := 250;
  Result.MaxInFlight := 2;
  Result.OverallDeadline := TDeadline.Infinite;
  Result.Token := nil;
  Result.PreferIPv6First := False;
  Result.InterleaveFamilies := True;
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
  if FOptions.ConnectionAttemptDelayMs = 0 then
    FOptions.ConnectionAttemptDelayMs := 250;
  if FOptions.MaxInFlight = 0 then
    FOptions.MaxInFlight := 2;
  FUserCb := ACallback;
  FUserCtx := AContext;
  FNextIndex := 0;
  FInFlight := 0;
  FFinished := 0;
  FLastError := -ECONNREFUSED_LINUX;
  FStaggerTimer := TAsyncTimerHandle.None;
  FOverallTimer := TAsyncTimerHandle.None;
  FTokenBound := False;
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
  LI, N4, N6, O, I4, I6: Integer;
  LTakeV6: Boolean;
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

  if not FOptions.InterleaveFamilies then
  begin
    { Bucket order only }
    SetLength(LOut, N4 + N6);
    O := 0;
    if FOptions.PreferIPv6First then
    begin
      for LI := 0 to N6 - 1 do begin LOut[O] := LV6[LI]; Inc(O); end;
      for LI := 0 to N4 - 1 do begin LOut[O] := LV4[LI]; Inc(O); end;
    end
    else
    begin
      for LI := 0 to N4 - 1 do begin LOut[O] := LV4[LI]; Inc(O); end;
      for LI := 0 to N6 - 1 do begin LOut[O] := LV6[LI]; Inc(O); end;
    end;
  end
  else
  begin
    { RFC8305-style interleave: alternate families }
    SetLength(LOut, N4 + N6);
    O := 0;
    I4 := 0;
    I6 := 0;
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
      { if one family exhausted, loop continues with the other via checks }
      if (I4 >= N4) and (I6 >= N6) then
        Break;
      if LTakeV6 and (I6 >= N6) and (I4 < N4) then
        LTakeV6 := False
      else if (not LTakeV6) and (I4 >= N4) and (I6 < N6) then
        LTakeV6 := True;
    end;
  end;

  SetLength(FAddrs, Length(LOut));
  for LI := 0 to High(LOut) do
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
begin
  if AtomicCompareExchange32(FFinished, 0, 1, moAcqRel) <> 0 then
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

  LAsync := AsyncTcpStreamAdopt(FLoop, LStream);
  LCb := FUserCb;
  LCtx := FUserCtx;
  if Assigned(LCb) then
    LCb(LAsync, 0, LCtx);
  Free;
end;

procedure TAsyncTcpDialer.FinishFail(AError: Int32);
var
  LCb: TAsyncTcpDialCallback;
  LCtx: Pointer;
begin
  if AtomicCompareExchange32(FFinished, 0, 1, moAcqRel) <> 0 then
    Exit;
  CancelTimers;
  AbortAllAttempts;
  LCb := FUserCb;
  LCtx := FUserCtx;
  if Assigned(LCb) then
    LCb(nil, AError, LCtx);
  Free;
end;

procedure TAsyncTcpDialer.MaybeCompleteIfIdle;
begin
  if AtomicLoad32(FFinished, moAcquire) <> 0 then
    Exit;
  if (FInFlight = 0) and (FNextIndex >= Length(FAddrs)) then
    FinishFail(FLastError);
end;

function TAsyncTcpDialer.StartAttempt(AIndex: Integer): Boolean;
var
  LAtt: PDialAttempt;
  LDomain: Int32;
  LRemote: TNetAddress;
  LRes: Int32;
begin
  Result := False;
  if (AIndex < 0) or (AIndex >= Length(FAddrs)) then
    Exit;
  if AtomicLoad32(FFinished, moAcquire) <> 0 then
    Exit;

  { Always consume this index. }
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
  Result := True;
end;

procedure TAsyncTcpDialer.StartNextAttempts;
var
  LGuard: Integer;
begin
  LGuard := 0;
  while (AtomicLoad32(FFinished, moAcquire) = 0) and
        (FInFlight < Int32(FOptions.MaxInFlight)) and
        (FNextIndex < Length(FAddrs)) and
        (LGuard < Length(FAddrs) + 2) do
  begin
    StartAttempt(FNextIndex);
    Inc(LGuard);
  end;
  KickStagger;
  MaybeCompleteIfIdle;
end;

procedure TAsyncTcpDialer.KickStagger;
begin
  if AtomicLoad32(FFinished, moAcquire) <> 0 then
    Exit;
  if FNextIndex >= Length(FAddrs) then
    Exit;
  if FInFlight >= Int32(FOptions.MaxInFlight) then
    Exit;
  if FStaggerTimer.IsValid then
    Exit;
  FStaggerTimer := FLoop.ScheduleEx(
    TDuration.FromMilliseconds(FOptions.ConnectionAttemptDelayMs),
    @DialStaggerCallback, Self, @DialDiscardTimer);
end;

procedure TAsyncTcpDialer.StartDialing;
var
  LRem: TDuration;
begin
  if Length(FAddrs) = 0 then
  begin
    FinishFail(-ECONNREFUSED_LINUX);
    Exit;
  end;
  OrderAddresses;
  SetLength(FAttempts, Length(FAddrs));
  BindToken;

  if not FOptions.OverallDeadline.IsInfinite then
  begin
    LRem := FOptions.OverallDeadline.Remaining;
    if LRem.AsMilliseconds <= 0 then
    begin
      FinishFail(-ETIMEDOUT_LINUX);
      Exit;
    end;
    FOverallTimer := FLoop.ScheduleEx(LRem, @DialOverallCallback, Self, @DialDiscardTimer);
  end;

  StartAttempt(0);
  KickStagger;
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

  if AtomicLoad32(FFinished, moAcquire) <> 0 then
    Exit;

  StartNextAttempts;
end;

procedure TAsyncTcpDialer.BeginWithHost(const AHost: string);
begin
  if not AsyncResolve(FLoop, AHost, @DialResolveCallback, Self) then
    FinishFail(-ECONNREFUSED_LINUX);
end;

procedure TAsyncTcpDialer.BeginWithAddrs(const AAddrs: array of TNetAddress);
var
  LI: Integer;
begin
  SetLength(FAddrs, Length(AAddrs));
  for LI := 0 to High(AAddrs) do
    FAddrs[LI] := AAddrs[LI];
  StartDialing;
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
  if AtomicLoad32(LDialer.FFinished, moAcquire) <> 0 then
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

procedure DialResolveCallback(const AResult: TDnsResult; AContext: Pointer);
var
  LDialer: TAsyncTcpDialer;
  LI: Integer;
begin
  LDialer := TAsyncTcpDialer(AContext);
  if LDialer = nil then
    Exit;
  if not AResult.Success then
  begin
    if AResult.Error <> 0 then
      LDialer.FinishFail(-Abs(AResult.Error))
    else
      LDialer.FinishFail(-ECONNREFUSED_LINUX);
    Exit;
  end;
  SetLength(LDialer.FAddrs, Length(AResult.Addresses));
  for LI := 0 to High(AResult.Addresses) do
    LDialer.FAddrs[LI] := AResult.Addresses[LI];
  LDialer.StartDialing;
end;

procedure DialDiscardTimer(AContext: Pointer);
begin
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
