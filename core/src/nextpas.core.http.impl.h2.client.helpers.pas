unit nextpas.core.http.impl.h2.client.helpers;
{**
 * @desc Pure H2 client free helpers (no connection state).
 *       Mechanical extract from impl.h2.client (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf;

function MinUInt32(const ALeft, ARight: UInt32): UInt32; inline;
procedure ValidateH2ClientUrlScheme(const AUrl: TUrl);
function HeadersHaveConnectionCloseToken(const AHeaders: IHttpHeaders): Boolean;
function IsH2ForbiddenRequestHeader(const AName: string): Boolean; inline;
function IsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
function HasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
function CaptureRetryBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
procedure RewindRetryBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
function ClientRequestDeadline(const ATimeoutMs: Int64): TDeadline;
procedure ApplyClientDeadline(const AConn: ITcpStream; const ADeadline: TDeadline);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.http.message;

function MinUInt32(const ALeft, ARight: UInt32): UInt32; inline;
begin
  if ALeft < ARight then
    Result := ALeft
  else
    Result := ARight;
end;

procedure ValidateH2ClientUrlScheme(const AUrl: TUrl);
var
  LScheme: string;
begin
  LScheme := LowerCase(AUrl.Scheme);
  if (LScheme <> '') and (LScheme <> 'http') and (LScheme <> 'https') then
    raise EHttpError.Create(hekParse, 'unsupported HTTP client URL scheme: ' +
      AUrl.Scheme);
end;

function HeadersHaveConnectionCloseToken(const AHeaders: IHttpHeaders): Boolean;
var
  LValues: TStringArray;
  LI: SizeInt;
begin
  Result := False;
  if AHeaders = nil then
    Exit;
  LValues := AHeaders.GetAll('connection');
  for LI := Low(LValues) to High(LValues) do
    if Pos('close', LowerCase(LValues[LI])) > 0 then
      Exit(True);
end;

function IsH2ForbiddenRequestHeader(const AName: string): Boolean; inline;
begin
  Result :=
    (AName = 'connection') or
    (AName = 'upgrade') or
    (AName = 'keep-alive') or
    (AName = 'proxy-connection') or
    (AName = 'transfer-encoding');
end;

function IsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := HttpIsRetryableMethod(AMethod);
end;

function HasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpHasRetryIdempotencyKey(AReq);
end;

function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpIsRetrySafeRequest(AReq);
end;

function CaptureRetryBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
begin
  ABodyStream := nil;
  AStartPosition := 0;
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit(True);
  Result := Supports(AReq.Body, IStream, ABodyStream);
  if Result then
    AStartPosition := ABodyStream.Position;
end;

procedure RewindRetryBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
begin
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit;
  if ABodyStream = nil then
    raise EHttpError.Create(hekBody, 'pooled retry request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

function ClientRequestDeadline(const ATimeoutMs: Int64): TDeadline;
begin
  if ATimeoutMs > 0 then
    Result := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    Result := TDeadline.Infinite;
end;

procedure ApplyClientDeadline(const AConn: ITcpStream; const ADeadline: TDeadline);
begin
  { Always set, including Infinite, so Timeout=0 can clear a prior ConnectTimeout. }
  AConn.SetReadDeadline(ADeadline);
  AConn.SetWriteDeadline(ADeadline);
end;

end.