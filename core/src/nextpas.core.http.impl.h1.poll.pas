unit nextpas.core.http.impl.h1.poll;
{**
 * @desc H1 poll/epoll connection driver (Advance / WorkerHandoff / drain).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.io.base,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.base,
  nextpas.core.time.deadline,
  nextpas.core.http.impl.h1.conn,
  nextpas.core.http.impl.h1.outbound;

type
  TH1PollRunWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
  end;

  TH1PollRequestWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
    FOutbound: IH1OutboundBuffer;
    FCloseAfterDrain: Boolean;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
    property Outbound: IH1OutboundBuffer read FOutbound;
    property CloseAfterDrain: Boolean read FCloseAfterDrain;
  end;

  TH1PollRunCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TH1PollRequestCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
    FWorkRef: ITcpServerWork;
    FWork: TH1PollRequestWork;
  public
    constructor Create(const AState: TH1ServerConnectionState;
      const AWork: TH1PollRequestWork);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

function H1PollEvents(const AState: TH1ServerConnectionState): TPlatformPollEvents;
function H1PollAdvance(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
function H1PollWakeDeadline(const AState: TH1ServerConnectionState): TDeadline;

implementation

uses
  nextpas.core.base, nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.time.base, nextpas.core.time,
  nextpas.core.http.base,
  nextpas.core.http.impl.h1.wire,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.serve;

function H1PollAdvanceWholeRunBridge(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult; forward;
function H1PollSubmitCurrentRequest(const AState: TH1ServerConnectionState;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult; forward;
function H1PollContinueAfterCompletion(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult; forward;
function H1PollAdvanceResponseDrain(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult; forward;
function H1PollAdvanceRequestParse(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult; forward;

{ R11: read-deadline expiry close path (408 best-effort, sink notify). }
function FinishPollReadDeadlineExpired(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult; forward;

constructor TH1PollRunWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRunWork.Execute: TTcpServerConnOwnership;
begin
  Result := H1ServeRun(FState);
end;

{ TH1PollRequestWork }

constructor TH1PollRequestWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRequestWork.Execute: TTcpServerConnOwnership;
begin
  if FState.UsePollOwnedResponseDrain then
    Result := FState.ExecuteCurrentPollRequest(FOutbound, FCloseAfterDrain)
  else
    Result := FState.ExecuteCurrentRequest;
end;

{ TH1PollRunCompletion }

constructor TH1PollRunCompletion.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

procedure TH1PollRunCompletion.Complete(const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
      FState.FPollCompletionOwnership := AOwnership
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FState := nil;
end;

{ TH1PollRequestCompletion }

constructor TH1PollRequestCompletion.Create(const AState: TH1ServerConnectionState;
  const AWork: TH1PollRequestWork);
begin
  inherited Create;
  FState := AState;
  FWorkRef := AWork as ITcpServerWork;
  FWork := AWork;
end;

procedure TH1PollRequestCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
    begin
      if AOwnership = tscoServer then
        FState.ApplyPollRequestResult(FWork.Outbound, FWork.CloseAfterDrain);
      FState.FPollCompletionOwnership := AOwnership;
    end
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FWorkRef := nil;
  FWork := nil;
  FState := nil;
end;

{ TH1ServerConnectionState }

function H1PollAdvanceWholeRunBridge(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
begin
  AOwnership := tscoServer;

  if not AState.FPollSubmitted then
  begin
    if not (peReadable in AEvents) then
    begin
      ANextEvents := [peReadable];
      Exit(tsprWait);
    end;

    if AState.FWorkerHandoff = nil then
    begin
      ANextEvents := [];
      AOwnership := H1ServeRun(AState);
      Exit(tsprDone);
    end;

    if AState.FSocketRuntime <> nil then
      AState.FSocketRuntime.SetBlocking(True);

    LWork := TH1PollRunWork.Create(AState);
    LCompletion := TH1PollRunCompletion.Create(AState);
    LHandoffResult := AState.FWorkerHandoff.Submit(LWork, LCompletion);
    if LHandoffResult <> tshrAccepted then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;

    AState.FPollSubmitted := True;
    ANextEvents := [];
    Exit(tsprWait);
  end;

  if not AState.FPollCompletionReady then
  begin
    ANextEvents := [];
    Exit(tsprWait);
  end;

  ANextEvents := [];
  AOwnership := AState.FPollCompletionOwnership;
  Result := tsprDone;
end;

function H1PollSubmitCurrentRequest(const AState: TH1ServerConnectionState;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWorkRef: TH1PollRequestWork;
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
  LOutbound: IH1OutboundBuffer;
  LCloseAfterDrain: Boolean;
  LInlineOnReactor: Boolean;
begin
  LOutbound := nil;
  LCloseAfterDrain := False;
  AOwnership := tscoServer;
  AState.ClearPollReadDeadline;

  { S1-1: Prefer reactor-inline handler execution when poll owns response drain
    and PreferPollWorkerHandoff is False (production default).
    Multi-conn keep-alive on epoll was ~0.59x Go while threaded was ~3.3x Go —
    per-request WorkerHandoff (pool submit + completion wake) dominated short
    request cost. Inline removes that tax.

    Tradeoff: a blocking handler stalls the readiness reactor. PreferPollWorkerHandoff
    restores legacy isolation for tests / long-handler deployments. }
  LInlineOnReactor := (AState.FWorkerHandoff = nil) or
    (AState.UsePollOwnedResponseDrain and (not AState.FOptions.PreferPollWorkerHandoff));
  if LInlineOnReactor then
  begin
    if AState.FSocketRuntime <> nil then
      AState.FSocketRuntime.SetBlocking(True);
    AState.FPollNeedRequestReset := True;
    if AState.UsePollOwnedResponseDrain then
      AOwnership := AState.ExecuteCurrentPollRequest(LOutbound, LCloseAfterDrain)
    else
      AOwnership := AState.ExecuteCurrentRequest;
    if AOwnership <> tscoServer then
    begin
      { hijack 让位：若连接已在途非阻塞迁移（B8-2 WS 升级），提交迁移并保持
        本 target 存活（tsprWait + 空事件），由 reactor 摘旧挂新——不能
        tsprDone（会 Free target + RestoreBlocking，破坏迁移前提）。 }
      if (AOwnership = tscoHandler) and (AState.FSessionContext <> nil) and
        AState.FSessionContext.SubmitHijackMigration then
      begin
        ANextEvents := [];
        Exit(tsprWait);
      end;
      ANextEvents := [];
      Exit(tsprDone);
    end;
    if AState.UsePollOwnedResponseDrain then
      AState.EnqueuePollResponse(LOutbound, LCloseAfterDrain);
    if AState.FSocketRuntime <> nil then
      AState.FSocketRuntime.SetBlocking(False);
    if AState.CanParseBufferedPollRequestWhileDraining then
    begin
      AState.PreparePollRequestParse;
      Exit(H1PollAdvanceRequestParse(AState, [], ANextEvents, AOwnership));
    end;
    if AState.FPollResponsePending then
    begin
      if AState.ShouldWaitForWritableInsteadOfEagerDrain([]) then
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
      Exit(H1PollAdvanceResponseDrain(AState, [], ANextEvents, AOwnership));
    end;
    if not AState.FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    AState.PreparePollKeepAliveRequestParse;
    Exit(H1PollAdvanceRequestParse(AState, [], ANextEvents, AOwnership));
  end;

  if AState.FSocketRuntime <> nil then
    AState.FSocketRuntime.SetBlocking(True);

  AState.FPollNeedRequestReset := True;
  AState.FPollWorkerPending := True;
  AState.FPollCompletionReady := False;
  LWorkRef := TH1PollRequestWork.Create(AState);
  LWork := LWorkRef;
  LCompletion := TH1PollRequestCompletion.Create(AState, LWorkRef);
  LHandoffResult := AState.FWorkerHandoff.Submit(LWork, LCompletion);
  if LHandoffResult <> tshrAccepted then
  begin
    AState.FPollWorkerPending := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  ANextEvents := [];
  Result := tsprWait;
end;

function H1PollContinueAfterCompletion(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AState.FPollWorkerPending := False;
  AState.FPollCompletionReady := False;
  AOwnership := AState.FPollCompletionOwnership;

  if AOwnership <> tscoServer then
  begin
    { hijack 让位（worker 路径）：同上，提交在途迁移并保持 target 存活。 }
    if (AOwnership = tscoHandler) and (AState.FSessionContext <> nil) and
      AState.FSessionContext.SubmitHijackMigration then
    begin
      ANextEvents := [];
      Exit(tsprWait);
    end;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if AState.FSocketRuntime <> nil then
    AState.FSocketRuntime.SetBlocking(False);
  if AState.CanParseBufferedPollRequestWhileDraining then
  begin
    AState.PreparePollRequestParse;
    Exit(H1PollAdvanceRequestParse(AState, [], ANextEvents, AOwnership));
  end;
  if AState.FPollResponsePending then
  begin
    if AState.ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
  end;
  if not AState.FKeepAlive then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;
  AState.PreparePollKeepAliveRequestParse;
  Result := H1PollAdvanceRequestParse(AState, [], ANextEvents, AOwnership);
end;

function H1PollAdvanceResponseDrain(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWritten: SizeUInt;
  LWriteResult: TTcpStreamIOResult;
  LCloseAfterDrain: Boolean;
begin
  AOwnership := tscoServer;

  if (not AState.FPollResponsePending) or (AState.FPollOutbound = nil) or AState.FPollOutbound.IsEmpty then
  begin
    AState.PromoteQueuedPollResponse;
    if (not AState.FPollResponsePending) or (AState.FPollOutbound = nil) or AState.FPollOutbound.IsEmpty then
      AState.ResetPollResponseState;
    if not AState.FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    AState.PreparePollKeepAliveRequestParse;
    Exit(H1PollAdvanceRequestParse(AState, AEvents, ANextEvents, AOwnership));
  end;

  if (not AState.FPollWriteDeadline.IsInfinite) and AState.FPollWriteDeadline.IsExpired then
  begin
    AState.ResetPollResponseState;
    AState.FKeepAlive := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if AState.FPollWriteDeadline.IsInfinite then
    AState.ArmPollWriteDeadline;

  LWriteResult := AState.FPollOutbound.TryDrainTo(AState.FStreamRuntime, LWritten);
  case LWriteResult of
    tsiorOk:
      begin
        if AState.FPollOutbound.IsEmpty then
        begin
          LCloseAfterDrain := AState.FPollCloseAfterDrain;
          AState.ReleaseOutboundBuffer(AState.FPollOutbound);
          AState.FPollResponsePending := False;
          AState.FPollCloseAfterDrain := False;
          AState.FPollWriteDeadline := TDeadline.Infinite;
          if LCloseAfterDrain then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          if AState.FPollQueuedResponsePending then
          begin
            AState.PromoteQueuedPollResponse;
            if (AState.FPending <> '') and (not AState.FPollCloseAfterDrain) then
            begin
              ANextEvents := [peWritable];
              Exit(tsprWait);
            end;
            Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
          end;
          if not AState.FKeepAlive then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          AState.PreparePollKeepAliveRequestParse;
          Exit(H1PollAdvanceRequestParse(AState, [], ANextEvents, AOwnership));
        end;
        if LWritten > 0 then
          AState.ArmPollWriteDeadline;
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  else
    begin
      AState.ResetPollResponseState;
      AState.FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;
  end;
end;

{ R11: request read deadline expired mid-parse — fire the read-abort sink and
  best-effort queue a 408 before closing, so blind-retrying clients stop on a
  structured answer instead of a bare reset. Idle keep-alive waits (no request
  bytes) stay silent. Any drain fault falls back to the bare close. }
function FinishPollReadDeadlineExpired(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LMidRequest: Boolean;
begin
  LMidRequest := not AState.FPollReadDeadlineIsIdle;
  AState.ClearPollReadDeadline;
  AState.FKeepAlive := False;
  if LMidRequest then
  begin
    AState.NotifyReadAbort;
    try
      if AState.QueuePollErrorResponse(HTTP_STATUS_REQUEST_TIMEOUT) then
        Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
    except
      { Best-effort only: a drain fault ends the session like the bare close.
        Drop the queued response and disarm the write deadline so the wake
        deadline contract (infinite after close) still holds. }
      AState.ResetPollResponseState;
    end;
  end;
  ANextEvents := [];
  Result := tsprDone;
end;

function H1PollAdvanceRequestParse(const AState: TH1ServerConnectionState;
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LReadResult: TTcpStreamIOResult;
  LContinueOutbound: IH1OutboundBuffer;
  LHeaderStatus: THttpStatus;
  function FinishPollParseError(const AStatus: THttpStatus): TTcpServerPollResult;
  begin
    AState.ClearPollReadDeadline;
    if AState.QueuePollErrorResponse(AStatus) then
    begin
      AState.FKeepAlive := False;
      Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
    end;

    WriteErrorResponse(AState.FConn, AStatus, AState.FOptions.WriteTimeout);
    AState.FKeepAlive := False;
    ANextEvents := [];
    Result := tsprDone;
  end;
begin
  Result := tsprWait;
  AOwnership := tscoServer;

  while True do
  begin
    if AState.FPending <> '' then
    begin
      LN := SizeUInt(Length(AState.FPending));
      if not ((AState.FParseTotalRead = 0) and
         AState.TryUseFastRequestParser(PAnsiChar(AState.FPending), LN, LConsumed)) then
        LConsumed := AState.FParser.Execute(PAnsiChar(AState.FPending), LN);
      if LConsumed < LN then
        AState.FPending := Copy(AState.FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
      else
        AState.FPending := '';
    end
    else
    begin
      if AState.FStreamRuntime = nil then
        Exit(H1PollAdvanceWholeRunBridge(AState, AEvents, ANextEvents, AOwnership));
      if not (peReadable in AEvents) then
      begin
        if AState.FPollReadDeadline.IsExpired then
          Exit(FinishPollReadDeadlineExpired(AState, AEvents, ANextEvents, AOwnership));
        if AState.FPollResponsePending then
          Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
        ANextEvents := [peReadable];
        Exit(tsprWait);
      end;

      LReadResult := AState.FStreamRuntime.TryRead(AState.FBuf[0], SizeUInt(SizeOf(AState.FBuf)), LN);
      case LReadResult of
        tsiorWouldBlock:
          begin
            if AState.FPollReadDeadline.IsExpired then
              Exit(FinishPollReadDeadlineExpired(AState, AEvents, ANextEvents, AOwnership));
            ANextEvents := [peReadable];
            Exit(tsprWait);
          end;
        tsiorClosed:
          begin
            AState.ClearPollReadDeadline;
            AState.FKeepAlive := False;
            if (AState.FParseTotalRead > 0) and (not AState.FParser.IsComplete) and
               (not AState.FParser.HasError) then
              AState.FParser.Finish;
            if AState.FParser.HasError then
              Exit(FinishPollParseError(ParserErrorStatus(AState.FParser)));
            ANextEvents := [];
            Exit(tsprDone);
          end;
      else
      begin
        if AState.FPollReadDeadlineIsIdle then
          AState.ArmPollRequestReadDeadline;
        if not ((AState.FParseTotalRead = 0) and
           AState.TryUseFastRequestParser(@AState.FBuf[0], LN, LConsumed)) then
          LConsumed := AState.FParser.Execute(@AState.FBuf[0], LN);
        if LConsumed < LN then
        begin
          SetLength(AState.FPending, Int32(LN - LConsumed));
          Move(AState.FBuf[LConsumed], AState.FPending[1], LN - LConsumed);
        end;
      end;
      end;
    end;

    Inc(AState.FParseTotalRead, LConsumed);
    if (not AState.FParseHeadersDone) and AState.FParser.HeadersComplete then
    begin
      AState.FParseHeadersDone := True;
      LHeaderStatus := HeaderPolicyErrorStatus(AState.FParser, AState.FOptions,
        AState.FParseTotalRead, AState.FParserIsSnapshot);
      if LHeaderStatus <> 0 then
        Exit(FinishPollParseError(LHeaderStatus));
      if ShouldSendContinueResponse(AState.FParser, AState.FParseHeadersDone, AState.FContinueSent) then
      begin
        LContinueOutbound := NewH1OutboundBuffer;
        WriteContinueResponseToWriter(LContinueOutbound as IWriter);
        if not AState.EnqueuePollResponse(LContinueOutbound, False) then
        begin
          AState.FKeepAlive := False;
          ANextEvents := [];
          Exit(tsprDone);
        end;
        AState.FContinueSent := True;
        Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
      end;
    end;

    if AState.FParseHeadersDone and (AState.FOptions.MaxHeaderSize > 0) and
       (AState.FParser.GetTrailerBytes > Int64(AState.FOptions.MaxHeaderSize)) then
      Exit(FinishPollParseError(HTTP_STATUS_HEADER_TOO_LARGE));

    if (AState.FOptions.MaxBodySize > 0) and
       (AState.FParser.GetBodySize > AState.FOptions.MaxBodySize) then
      Exit(FinishPollParseError(HTTP_STATUS_PAYLOAD_TOO_LARGE));

    if AState.FParser.HasError then
      Exit(FinishPollParseError(ParserErrorStatus(AState.FParser)));

    if AState.FParser.IsComplete then
      Exit(H1PollSubmitCurrentRequest(AState, ANextEvents, AOwnership));
  end;
end;

function H1PollEvents(const AState: TH1ServerConnectionState): TPlatformPollEvents;
begin
  Result := [peReadable];
end;

function H1PollAdvance(const AState: TH1ServerConnectionState; const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;

  if AState.FStreamRuntime = nil then
    Exit(H1PollAdvanceWholeRunBridge(AState, AEvents, ANextEvents, AOwnership));

  if AState.FPollWorkerPending then
  begin
    if not AState.FPollCompletionReady then
    begin
      ANextEvents := [];
      Exit(tsprWait);
    end;
    Exit(H1PollContinueAfterCompletion(AState, AEvents, ANextEvents, AOwnership));
  end;

  if AState.CanParseBufferedPollRequestWhileDraining then
  begin
    AState.PreparePollRequestParse;
    Exit(H1PollAdvanceRequestParse(AState, [], ANextEvents, AOwnership));
  end;
  if AState.FPollResponsePending then
  begin
    if AState.ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(H1PollAdvanceResponseDrain(AState, AEvents, ANextEvents, AOwnership));
  end;

  Result := H1PollAdvanceRequestParse(AState, AEvents, ANextEvents, AOwnership);
end;

function H1PollWakeDeadline(const AState: TH1ServerConnectionState): TDeadline;
begin
  Result := TDeadline.Min(AState.FPollReadDeadline, AState.FPollWriteDeadline);
end;

{ TH1ServerTransport }

end.
