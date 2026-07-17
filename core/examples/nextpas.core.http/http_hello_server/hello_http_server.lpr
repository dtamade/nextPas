program hello_http_server;

{$I nextpas.core.settings.inc}

uses
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

var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;
  LPort: UInt16;

begin
  if ParamCount >= 1 then
    LPort := UInt16(StrToIntDef(ParamStr(1), 8080))
  else
    LPort := 8080;

  LRouter := NewRouter;
  LRouter.Get('/hello/:name',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: string;
      LName: string;
      LPage: string;
      LArena: IArena;
      LScratch: Pointer;
      LUsed: SizeUInt;
    begin
      LArena := HttpRequestArenaOf(AReq);
      LScratch := nil;
      LUsed := 0;
      if LArena <> nil then
      begin
        LScratch := LArena.Alloc(256);
        if LScratch <> nil then
          FillChar(LScratch^, 256, 0);
        LUsed := LArena.UsedSize;
      end;
      LName := AReq.PathParam('name');
      LPage := AReq.QueryParam('page');
      if LPage = '' then
        LPage := '1';
      LBody := 'hello=' + LName + LineEnding +
        'page=' + LPage + LineEnding +
        'path=' + AReq.Path + LineEnding +
        'arena-used=' + IntToStr(Int64(LUsed)) + LineEnding;
      WritePlainText(AW, HTTP_STATUS_OK, LBody);
      { Arena dropped by server-root RequestArena wire — no FreeMem. }
    end);
  LRouter.Get('/memstats',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      WritePlainText(AW, HTTP_STATUS_OK, HttpFormatProcessMemStats + LineEnding);
    end);

  { Production Read/Write timeouts + RequestArena on server kernel wire. }
  LOptions := THttpServerOptions.Production.WithRequestArena;
  LServer := NewHttpServer(LRouter, LOptions);

  WriteLn('http-hello-server=ready');
  WriteLn('listen=127.0.0.1:', LPort);
  WriteLn('example=http://127.0.0.1:', LPort, '/hello/world?page=2');
  WriteLn('memstats=http://127.0.0.1:', LPort, '/memstats');
  LServer.ListenAndServe('127.0.0.1', LPort);
end.
