program hello_http_server;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.http,
  nextpas.core.text.conv;

procedure WritePlainText(const AW: IHttpResponseWriter; const AStatus: THttpStatus;
  const ABody: string);
begin
  AW.GetHeaders.Set_('content-type', 'text/plain; charset=utf-8');
  AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(ABody))));
  AW.WriteHeader(AStatus);
  if ABody <> '' then
    AW.Write(ABody[1], SizeUInt(Length(ABody)));
end;

var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;

begin
  LRouter := NewRouter;
  LRouter.Get('/hello/:name',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: string;
      LName: string;
      LPage: string;
    begin
      LName := AReq.PathParam('name');
      LPage := AReq.QueryParam('page');
      if LPage = '' then
        LPage := '1';
      LBody := 'hello=' + LName + LineEnding +
        'page=' + LPage + LineEnding +
        'path=' + AReq.Path + LineEnding;
      WritePlainText(AW, HTTP_STATUS_OK, LBody);
    end);

  LOptions := THttpServerOptions.Default;
  LServer := NewHttpServer(LRouter, LOptions);

  WriteLn('http-hello-server=ready');
  WriteLn('listen=127.0.0.1:8080');
  WriteLn('example=http://127.0.0.1:8080/hello/world?page=2');
  LServer.ListenAndServe('127.0.0.1', 8080);
end.
