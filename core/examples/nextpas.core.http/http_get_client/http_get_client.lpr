program http_get_client;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http,
  nextpas.core.io;

function BytesToString(const ABytes: TBytes): string;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

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
    LUrl := 'http://127.0.0.1:8080/hello/world?page=1';

  LClient := NewHttpClient;
  LResp := LClient.Get(LUrl);

  WriteLn('url=', LUrl);
  WriteLn('status-code=', LResp.StatusCode);
  WriteLn('status-text=', HttpStatusText(LResp.StatusCode));
  WriteLn('headers:');
  PrintHeaders(LResp.Headers);
  if LResp.Body <> nil then
    LBody := BytesToString(ReadAll(LResp.Body))
  else
    LBody := '';
  WriteLn('body:');
  WriteLn(LBody);
end.
