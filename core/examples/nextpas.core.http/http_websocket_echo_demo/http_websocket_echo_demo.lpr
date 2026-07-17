program http_websocket_echo_demo;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http,
  nextpas.core.text.conv;

procedure WritePlainText(const AW: IHttpResponseWriter; const AStatus: THttpStatus;
  const ABody: string);
begin
  AW.GetHeaders.SetHeader('content-type', 'text/plain; charset=utf-8');
  AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(ABody))));
  AW.WriteHeader(AStatus);
  if ABody <> '' then
    AW.Write(ABody[1], SizeUInt(Length(ABody)));
end;

function BytesToString(const ABytes: TBytes): string;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;
  LPort: UInt16;

begin
  if ParamCount >= 1 then
    LPort := UInt16(StrToIntDef(ParamStr(1), 8082))
  else
    LPort := 8082;

  LOptions := THttpServerOptions.Production;
  LRouter := NewRouter;

  LRouter.Get('/health',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      WritePlainText(AW, HTTP_STATUS_OK, 'websocket-echo=ready' + LineEnding);
    end);

  LRouter.Get('/ws',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LWs: IWebSocket;
      LFrame: TWebSocketFrame;
      LWsOpts: TWebSocketOptions;
    begin
      { Demo accepts non-browser clients (no Origin) for smoke/scripts. }
      LWsOpts := TWebSocketOptions.Default;
      LWsOpts.OnCheckOrigin :=
        function(const AOrigin: string): Boolean
        begin
          Result := True;
        end;
      LWs := UpgradeWebSocket(AReq, AW, LWsOpts);
      LFrame := LWs.ReadFrame;
      if LFrame.Opcode = wsOpText then
        LWs.WriteText('echo=' + BytesToString(LFrame.Payload))
      else
        LWs.WriteText('unsupported-opcode=' + IntToStr(Int64(Ord(LFrame.Opcode))));
      LWs.Close(1000, 'bye');
    end);

  LServer := NewHttpServer(LRouter, LOptions);

  WriteLn('http-websocket-echo-demo=ready');
  WriteLn('listen=127.0.0.1:', LPort);
  WriteLn('try-health=curl http://127.0.0.1:', LPort, '/health');
  WriteLn('try-websocket=connect to ws://127.0.0.1:', LPort, '/ws and send a text frame');
  LServer.ListenAndServe('127.0.0.1', LPort);
end.
