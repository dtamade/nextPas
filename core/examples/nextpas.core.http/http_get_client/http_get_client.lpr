program http_get_client;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.http;

procedure PrintHeaders(const AHeaders: IHttpHeaders);
begin
  AHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      WriteLn(AName, ': ', AValue);
    end);
end;

var
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LUrl: string;
  LBody: string;

begin
  if ParamCount >= 1 then
    LUrl := ParamStr(1)
  else
  begin
    LUrl := Trim(GetEnvironmentVariable('NEXTPAS_HTTP_GET_URL'));
    if LUrl = '' then
      LUrl := 'http://127.0.0.1:8080/hello/world?page=1';
  end;

  LClient := NewHttpClient;
  LResp := LClient.Get(LUrl);

  WriteLn('url=', LUrl);
  WriteLn('status-code=', LResp.StatusCode);
  WriteLn('status-text=', HttpStatusText(LResp.StatusCode));
  WriteLn('headers:');
  PrintHeaders(LResp.Headers);
  LBody := HttpReadResponseBodyString(LResp);
  WriteLn('body:');
  WriteLn(LBody);
end.
