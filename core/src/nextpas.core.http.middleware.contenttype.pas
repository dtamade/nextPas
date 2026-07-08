unit nextpas.core.http.middleware.contenttype;
{**
 * @desc Content-Type validation middleware. Rejects requests whose Content-Type
 *       header does not match any of the accepted media types with
 *       415 Unsupported Media Type.
 *       Only applies to methods that typically carry a body (POST, PUT, PATCH).
 *       Requests without Content-Type pass through.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Create middleware that rejects requests with unaccepted Content-Type.
   AAccepted is a list of accepted media types (e.g. ['application/json']).
   Comparison is case-insensitive and ignores parameters (charset etc).
   Only checks POST/PUT/PATCH requests. Returns 415 on mismatch.
   Empty AAccepted means any Content-Type is accepted (no-op). }
function ContentTypeMiddleware(
  const AAccepted: array of string): IHttpMiddleware;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message;

function ContentTypeMiddleware(
  const AAccepted: array of string): IHttpMiddleware;
var
  LAccepted: array of string;
  I: Int32;
begin
  SetLength(LAccepted, Length(AAccepted));
  for I := 0 to High(AAccepted) do
    LAccepted[I] := AAccepted[I];

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LContentType: string;
      LMedia: string;
      LSemi: SizeInt;
      J: Int32;
      LFound: Boolean;
    begin
      if (AReq.Method <> hmPost) and (AReq.Method <> hmPut)
        and (AReq.Method <> hmPatch) then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      LContentType := AReq.GetHeaders.Get('content-type');
      if LContentType = '' then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      if Length(LAccepted) = 0 then
      begin
        ANext.ServeHTTP(AReq, AW);
        Exit;
      end;

      LSemi := Pos(';', LContentType);
      if LSemi > 0 then
        LMedia := Copy(LContentType, 1, LSemi - 1)
      else
        LMedia := LContentType;

      LFound := False;
      for J := 0 to High(LAccepted) do
      begin
        if SameText(LMedia, LAccepted[J]) then
        begin
          LFound := True;
          Break;
        end;
      end;

      if not LFound then
      begin
        HttpWriteErrorUnsupportedMediaType(AW, 'Unsupported content type');
        Exit;
      end;

      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
