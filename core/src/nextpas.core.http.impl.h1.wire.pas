unit nextpas.core.http.impl.h1.wire;
{**
 * @desc H1 wire free helpers (STRUCT-opt extract from impl.h1).
 *       Header/target validation, proxy authority helpers, and
 *       error/100-continue response writers.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

function LowerTrim(const AValue: string): string; inline;
function HeaderValueHasToken(const AValue, AToken: string): Boolean;
procedure ValidateWireHeaderValue(const AValue: string);
procedure ValidateWireRequestTarget(const ATarget: string);
procedure ValidateWireHeaderName(const AName: string);
procedure ValidatePlainHttpClientUrlScheme(const AUrl: TUrl);
function ProxyBasicAuthorizationValue(const AUserInfo: string): string;
function ConnectAuthority(const AHost: string; const APort: UInt16): string;
function DefaultPortForHttpScheme(const AScheme: string): UInt16;
function HeadersHaveConnectionCloseToken(const AHeaders: IHttpHeaders): Boolean;

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus;
  const AWriteTimeoutMs: Int64 = 0);
procedure WriteErrorResponseToWriter(const AWriter: IWriter;
  const AStatus: THttpStatus);
function TryWriteContinueResponse(const AConn: ITcpStream;
  const AWriteTimeoutMs: Int64 = 0): Boolean;
procedure WriteContinueResponseToWriter(const AWriter: IWriter);

implementation

uses
  nextpas.core.errors,
  nextpas.core.encoding,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.time.deadline,
  nextpas.core.http.headers,
  nextpas.core.http.static,
  nextpas.core.http.impl.h1.writer;

function LowerTrim(const AValue: string): string; inline;
begin
  Result := LowerCase(Trim(AValue));
end;

function HeaderValueHasToken(const AValue, AToken: string): Boolean;
var
  LStart: SizeInt;
  LPos: SizeInt;
begin
  Result := False;
  if AValue = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(AValue) do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    if LowerTrim(Copy(AValue, LStart, LPos - LStart)) = AToken then
      Exit(True);
    LStart := LPos + 1;
  end;
end;

procedure ValidateWireHeaderValue(const AValue: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(AValue) do
    if (((AValue[LI] < #32) and (AValue[LI] <> #9)) or
        (AValue[LI] = #127)) then
      raise EHttpError.Create(hekParse, 'invalid header value character');
end;

procedure ValidateWireRequestTarget(const ATarget: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(ATarget) do
    if (ATarget[LI] <= #32) or (ATarget[LI] = #127) then
      raise EHttpError.Create(hekParse, 'invalid request target character');
end;

procedure ValidateWireHeaderName(const AName: string);
var
  LI: SizeInt;
begin
  if AName = '' then
    raise EHttpError.Create(hekProtocol, 'empty header name');
  for LI := 1 to Length(AName) do
    if not IsHttpHeaderNameChar(AnsiChar(AName[LI])) then
      raise EHttpError.Create(hekParse, 'invalid header name character');
end;

procedure ValidatePlainHttpClientUrlScheme(const AUrl: TUrl);
var
  LScheme: string;
begin
  LScheme := LowerCase(AUrl.Scheme);
  if LScheme = '' then
    Exit;
  if (LScheme = 'http') or (LScheme = 'https') then
    Exit;
  raise EHttpError.CreateOp(hekProtocol, 'transport',
    'unsupported HTTP client URL scheme: ' + AUrl.Scheme);
end;

function ProxyBasicAuthorizationValue(const AUserInfo: string): string;
begin
  if AUserInfo = '' then
    Exit('');
  { Wave I product freeze: proxy authentication is Basic only.
    Raw UserInfo from TUrl.Parse (no percent-decode). Same encoding path as
    THttpRequestBuilder.BasicAuth. Digest / NTLM / Negotiate are not
    implemented and must not be added as silent half-implementations. }
  Result := 'Basic ' + Base64Encode(StringToUTF8Bytes(AUserInfo));
end;

function ConnectAuthority(const AHost: string; const APort: UInt16): string;
var
  LHost: string;
begin
  if (AHost <> '') and (AHost[1] <> '[') and (Pos(':', AHost) > 0) then
    LHost := '[' + AHost + ']'
  else
    LHost := AHost;
  Result := LHost + ':' + IntToStr(Int64(APort));
end;

function DefaultPortForHttpScheme(const AScheme: string): UInt16;
var
  LScheme: string;
begin
  LScheme := LowerCase(AScheme);
  if LScheme = 'https' then
    Result := 443
  else
    Result := 80;
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
    if HeaderValueHasToken(LValues[LI], 'close') then
      Exit(True);
end;

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus;
  const AWriteTimeoutMs: Int64);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  try
    if AWriteTimeoutMs > 0 then
      AConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(AWriteTimeoutMs)));
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LBody := HttpStatusText(AStatus);
    HttpEnsureDateHeader(LW.GetHeaders);
    LW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    LW.GetHeaders.SetHeader('connection', 'close');
    LW.WriteHeader(AStatus);
    if Length(LBody) > 0 then
      LW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    { Ignore secondary write failures while sending an error response. }
  end;
end;

procedure WriteErrorResponseToWriter(const AWriter: IWriter;
  const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LBody := HttpStatusText(AStatus);
  HttpEnsureDateHeader(LW.GetHeaders);
  LW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
  LW.GetHeaders.SetHeader('connection', 'close');
  LW.WriteHeader(AStatus);
  if Length(LBody) > 0 then
    LW.Write(LBody[1], SizeUInt(Length(LBody)));
end;

function TryWriteContinueResponse(const AConn: ITcpStream;
  const AWriteTimeoutMs: Int64): Boolean;
var
  LW: IHttpResponseWriter;
begin
  Result := False;
  try
    if AWriteTimeoutMs > 0 then
      AConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(AWriteTimeoutMs)));
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LW.WriteHeader(HTTP_STATUS_CONTINUE);
    Result := True;
  except
    Result := False;
  end;
end;

procedure WriteContinueResponseToWriter(const AWriter: IWriter);
var
  LW: IHttpResponseWriter;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LW.WriteHeader(HTTP_STATUS_CONTINUE);
end;

end.