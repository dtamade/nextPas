unit nextpas.core.http.impl.h1.serve;
{**
 * @desc H1 threaded/blocking connection driver (ServeConn / Run loop).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.server.base,
  nextpas.core.http.impl.h1.conn;

function H1ServeRun(const AState: TH1ServerConnectionState): TTcpServerConnOwnership;

implementation

uses
  nextpas.core.base, nextpas.core.errors,
  nextpas.core.net.intf,
  nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.time,
  nextpas.core.http.base,
  nextpas.core.http.impl.h1.wire,
  nextpas.core.http.impl.h1.parser;

function H1ServeRun(const AState: TH1ServerConnectionState): TTcpServerConnOwnership;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LTotalRead: SizeUInt;
  LHeadersDone: Boolean;
  LRejected: Boolean;
  LHeaderStatus: THttpStatus;
  LIdleBeforeNextRequest: Boolean;
  LUsingIdleDeadline: Boolean;
begin
  Result := tscoServer;
  LIdleBeforeNextRequest := False;
  while AState.FKeepAlive do
  begin
    try
      LUsingIdleDeadline := LIdleBeforeNextRequest and (AState.FPending = '');
      if LUsingIdleDeadline then
        AState.FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(AState.FIdleMs)))
      else
        AState.FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(AState.FReadMs)));
      LIdleBeforeNextRequest := False;

      AState.ResetRequestParser;
      LTotalRead := 0;
      LHeadersDone := False;
      AState.FContinueSent := False;
      LRejected := False;
      { INV-12 keep-alive request-tail:
        parser only consumes the current framed request; any remainder stays in
        AState.FPending for the next loop. Partial follow-up bytes are not rejected
        early; conclusively malformed / EOF-truncated follow-ups become the
        next request's 400 after the prior response. }
      repeat
        if AState.FPending <> '' then
        begin
          LN := SizeUInt(Length(AState.FPending));
          if not ((LTotalRead = 0) and
             AState.TryUseFastRequestParser(PAnsiChar(AState.FPending), LN, LConsumed)) then
            LConsumed := AState.FParser.Execute(PAnsiChar(AState.FPending), LN);
          if LConsumed < LN then
            AState.FPending := Copy(AState.FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
          else
            AState.FPending := '';
        end
        else
        begin
          LN := AState.FConn.Read(AState.FBuf[0], 16384);
          if LN = 0 then
          begin
            AState.FKeepAlive := False;
            if (LTotalRead > 0) and (not AState.FParser.IsComplete) and
               (not AState.FParser.HasError) then
              AState.FParser.Finish;
            Break;
          end;
          if LUsingIdleDeadline then
          begin
            AState.FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(AState.FReadMs)));
            LUsingIdleDeadline := False;
          end;
          if not ((LTotalRead = 0) and
             AState.TryUseFastRequestParser(@AState.FBuf[0], LN, LConsumed)) then
            LConsumed := AState.FParser.Execute(@AState.FBuf[0], LN);
          if LConsumed < LN then
          begin
            SetLength(AState.FPending, Int32(LN - LConsumed));
            Move(AState.FBuf[LConsumed], AState.FPending[1], LN - LConsumed);
          end;
        end;
        Inc(LTotalRead, LConsumed);
        if (not LHeadersDone) and AState.FParser.HeadersComplete then
        begin
          LHeadersDone := True;
          LHeaderStatus := HeaderPolicyErrorStatus(AState.FParser, AState.FOptions,
            LTotalRead, AState.FParserIsSnapshot);
          if LHeaderStatus <> 0 then
          begin
            WriteErrorResponse(AState.FConn, LHeaderStatus, AState.FOptions.WriteTimeout);
            LRejected := True;
            AState.FKeepAlive := False;
            Break;
          end;
          if ShouldSendContinueResponse(AState.FParser, LHeadersDone, AState.FContinueSent) then
          begin
            if not TryWriteContinueResponse(AState.FConn, AState.FOptions.WriteTimeout) then
            begin
              AState.FKeepAlive := False;
              Break;
            end;
            AState.FContinueSent := True;
          end;
        end;
        if LHeadersDone and (AState.FOptions.MaxHeaderSize > 0) and
           (AState.FParser.GetTrailerBytes > Int64(AState.FOptions.MaxHeaderSize)) then
        begin
          WriteErrorResponse(AState.FConn, HTTP_STATUS_HEADER_TOO_LARGE,
            AState.FOptions.WriteTimeout);
          LRejected := True;
          AState.FKeepAlive := False;
          Break;
        end;
        if (AState.FOptions.MaxBodySize > 0) and
           (AState.FParser.GetBodySize > AState.FOptions.MaxBodySize) then
        begin
          WriteErrorResponse(AState.FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE,
            AState.FOptions.WriteTimeout);
          LRejected := True;
          AState.FKeepAlive := False;
          Break;
        end;
        if AState.FParser.HasError then
        begin
          WriteErrorResponse(AState.FConn, ParserErrorStatus(AState.FParser),
            AState.FOptions.WriteTimeout);
          LRejected := True;
          AState.FKeepAlive := False;
          Break;
        end;
      until AState.FParser.IsComplete or AState.FParser.HasError;

      if LRejected then
        Break;

      if AState.FParser.HasError then
      begin
        WriteErrorResponse(AState.FConn, ParserErrorStatus(AState.FParser),
          AState.FOptions.WriteTimeout);
        Break;
      end;

      if not AState.FParser.IsComplete then
        Break;

      if AState.FOptions.MaxBodySize > 0 then
      begin
        if AState.FParser.GetBodySize > AState.FOptions.MaxBodySize then
        begin
          WriteErrorResponse(AState.FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE,
            AState.FOptions.WriteTimeout);
          AState.FKeepAlive := False;
          Continue;
        end;
      end;

      Result := AState.ExecuteCurrentRequest;
      if Result <> tscoServer then
        Continue;
      LIdleBeforeNextRequest := AState.FKeepAlive and (AState.FPending = '');
    except
      { Per-request isolation: handler/IO fault ends keep-alive; loop may exit. }
      on E: Exception do
      begin
        if not IsRequestReadFailure(E) then
          WriteErrorResponse(AState.FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR,
            AState.FOptions.WriteTimeout)
        else if HttpErrorIsTimeout(E) and (not LUsingIdleDeadline) then
        begin
          { R11: request read deadline expired mid-request — best-effort 408
            so blind-retrying clients stop on a structured answer instead of a
            bare reset. Idle keep-alive waits (client sent nothing) stay
            silent, matching the poll backend. }
          AState.NotifyReadAbort;
          WriteErrorResponse(AState.FConn, HTTP_STATUS_REQUEST_TIMEOUT,
            AState.FOptions.WriteTimeout);
        end;
        AState.FKeepAlive := False;
      end;
    end;
  end;
end;

end.
