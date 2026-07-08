unit nextpas.core.http.middleware.methodguard;
{**
 * @desc Method guard middleware. Rejects requests whose HTTP method is not in
 *       the allowed set with 405 Method Not Allowed and an Allow header.
 *       Useful for protecting handlers that only accept specific methods.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

{** @desc Create middleware that only allows the specified methods.
   Requests with other methods receive 405 Method Not Allowed with an Allow
   header listing the permitted methods. }
function MethodGuardMiddleware(const AAllowed: array of THttpMethod): IHttpMiddleware;

implementation

uses
  nextpas.core.http.middleware;

function MethodGuardMiddleware(const AAllowed: array of THttpMethod): IHttpMiddleware;
var
  LAllowed: array of THttpMethod;
  LAllowHeader: string;
  LI: Int32;
begin
  SetLength(LAllowed, Length(AAllowed));
  for LI := 0 to High(AAllowed) do
    LAllowed[LI] := AAllowed[LI];

  LAllowHeader := '';
  for LI := 0 to High(LAllowed) do
  begin
    if LI > 0 then
      LAllowHeader := LAllowHeader + ', ';
    LAllowHeader := LAllowHeader + HttpMethodToStr(LAllowed[LI]);
  end;

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LMethod: THttpMethod;
      LFound: Boolean;
      LI: Int32;
    begin
      LMethod := AReq.GetMethod;
      LFound := False;
      for LI := 0 to High(LAllowed) do
        if LAllowed[LI] = LMethod then
        begin
          LFound := True;
          Break;
        end;

      if LFound then
        ANext.ServeHTTP(AReq, AW)
      else
      begin
        AW.GetHeaders.SetHeader('allow', LAllowHeader);
        AW.WriteHeader(HTTP_STATUS_METHOD_NOT_ALLOWED);
      end;
    end);
  end);
end;

end.
