program http_server_options_demo;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.http,
  nextpas.core.io,
  nextpas.core.text.conv;

function BytesToString(const ABytes: TBytes): string;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

function BackendName(const ABackend: TTcpServerBackend): string;
begin
  case ABackend of
    TCP_SERVER_BACKEND_THREADED:
      Result := 'threaded';
    TCP_SERVER_BACKEND_EPOLL:
      Result := 'epoll';
  else
    Result := 'unknown';
  end;
end;

function ParseBackend(const AValue: string): TTcpServerBackend;
var
  LLower: string;
begin
  if AValue = '' then
    Exit(TCP_SERVER_BACKEND_THREADED);

  LLower := LowerCase(AValue);
  if LLower = 'threaded' then
    Exit(TCP_SERVER_BACKEND_THREADED);
  if LLower = 'epoll' then
    Exit(TCP_SERVER_BACKEND_EPOLL);

  raise Exception.Create('unknown backend: ' + AValue +
    ' (expected threaded or epoll)');
end;

procedure WritePlainText(const AW: IHttpResponseWriter; const AStatus: THttpStatus;
  const ABody: string);
begin
  AW.GetHeaders.Set_('content-type', 'text/plain; charset=utf-8');
  AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(ABody))));
  AW.WriteHeader(AStatus);
  if ABody <> '' then
    AW.Write(ABody[1], SizeUInt(Length(ABody)));
end;

function BuildServerOptionsBody(const AOptions: THttpServerOptions): string;
begin
  Result :=
    'backend=' + BackendName(AOptions.Backend) + LineEnding +
    'write-timeout-ms=' + IntToStr(AOptions.WriteTimeout) + LineEnding +
    'max-header-size=' + IntToStr(AOptions.MaxHeaderSize) + LineEnding +
    'max-body-size=' + IntToStr(AOptions.MaxBodySize) + LineEnding;
end;

var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;
  LPort: UInt16;

begin
  LOptions := THttpServerOptions.Default;
  LOptions.Backend := ParseBackend(ParamStr(1));
  LOptions.WriteTimeout := 5000;
  LOptions.MaxHeaderSize := 1024;
  LOptions.MaxBodySize := 64;

  if ParamCount >= 2 then
    LPort := UInt16(StrToIntDef(ParamStr(2), 8081))
  else
    LPort := 8081;

  LRouter := NewRouter;
  LRouter.Get('/health',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      WritePlainText(AW, HTTP_STATUS_OK, BuildServerOptionsBody(LOptions));
    end);

  LRouter.Get('/hello/:name',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: string;
      LName: string;
    begin
      LName := AReq.PathParam('name');
      LBody := 'hello=' + LName + LineEnding +
        BuildServerOptionsBody(LOptions);
      WritePlainText(AW, HTTP_STATUS_OK, LBody);
    end);

  LRouter.Post('/echo',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBytes: TBytes;
      LBody: string;
    begin
      if AReq.Body <> nil then
        LBytes := ReadAll(AReq.Body)
      else
        SetLength(LBytes, 0);
      LBody :=
        'bytes=' + IntToStr(Int64(Length(LBytes))) + LineEnding +
        'body=' + BytesToString(LBytes) + LineEnding +
        BuildServerOptionsBody(LOptions);
      WritePlainText(AW, HTTP_STATUS_OK, LBody);
    end);

  LServer := NewHttpServer(LRouter, LOptions);

  WriteLn('http-server-options-demo=ready');
  WriteLn('listen=127.0.0.1:', LPort);
  WriteLn('backend=', BackendName(LOptions.Backend));
  WriteLn('write-timeout-ms=', LOptions.WriteTimeout);
  WriteLn('max-header-size=', LOptions.MaxHeaderSize);
  WriteLn('max-body-size=', LOptions.MaxBodySize);
  WriteLn('try-health=curl http://127.0.0.1:', LPort, '/health');
  WriteLn('try-hello=curl http://127.0.0.1:', LPort, '/hello/world');
  WriteLn('try-echo=curl -X POST --data ''hello'' http://127.0.0.1:', LPort, '/echo');
  WriteLn('limit-note=payloads larger than max-body-size are rejected before handler');
  LServer.ListenAndServe('127.0.0.1', LPort);
end.
