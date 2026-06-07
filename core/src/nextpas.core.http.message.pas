unit nextpas.core.http.message;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.url;

type
  THttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    type
      TPathParam = record
        Name: string;
        Value: string;
      end;
    var
      FMethod: THttpMethod;
      FUrl: TUrl;
      FRawRequestTarget: string;
      FUrlParsed: Boolean;
      FRequestTargetPartsParsed: Boolean;
      FVersion: THttpVersion;
      FHeaders: IHttpHeaders;
      FBody: IReader;
      FContentLength: Int64;
      FPathParams: array of TPathParam;
      FRemoteAddr: string;
      FRemoteNetAddr: TNetAddress;
      FRemoteAddrFromNet: Boolean;
      FQueryParsed: Boolean;
      FQueryParams: TQueryParams;
    procedure EnsureUrlParsed;
    procedure EnsureRequestTargetParts;
  public
    constructor Create(const AMethod: THttpMethod; const AUrl: TUrl;
      const AVersion: THttpVersion; const AHeaders: IHttpHeaders;
      const ABody: IReader; const AContentLength: Int64);
    constructor CreateFromRequestTarget(const AMethod: THttpMethod;
      const ARequestTarget: string; const AVersion: THttpVersion;
      const AHeaders: IHttpHeaders; const ABody: IReader;
      const AContentLength: Int64);
    procedure SetPathParam(const AName, AValue: string);
    procedure SetRemoteAddr(const AAddr: string);
    procedure SetRemoteNetAddr(const AAddr: TNetAddress);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  end;

  THttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: THttpStatus;
    FHeaders: IHttpHeaders;
    FBody: IReader;
  public
    constructor Create(const AStatusCode: THttpStatus;
      const AHeaders: IHttpHeaders; const ABody: IReader);
    function GetStatusCode: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
  end;

{ Factory helpers }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ANilBody: Pointer): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ANilBody: Pointer): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType, ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewGetRequest(const APath: string): IHttpRequest;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse;
function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;

implementation

uses
  nextpas.core.errors,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.http.headers;

function BytesBodyReader(const ABodyBytes: TBytes): IReader;
var
  LStream: IStream;
begin
  LStream := CreateBytesStreamFrom(ABodyBytes);
  Result := LStream as IReader;
end;

function StringBodyReader(const ABodyText: string): IReader;
var
  LData: TBytes;
begin
  SetLength(LData, Length(ABodyText));
  if Length(ABodyText) > 0 then
    Move(ABodyText[1], LData[0], Length(ABodyText));
  Result := BytesBodyReader(LData);
end;

function HeadersOrNew(const AHeaders: IHttpHeaders): IHttpHeaders;
begin
  if AHeaders <> nil then
    Result := AHeaders
  else
    Result := NewHttpHeaders;
end;

function NewRequestContentTypeHeaders(const AContentType: string): IHttpHeaders;
begin
  if AContentType = '' then
    Exit(nil);
  Result := NewHttpHeaders;
  Result.Set_('content-type', AContentType);
end;

function ResponseStatusMustNotHaveBody(const AStatus: THttpStatus): Boolean;
begin
  Result := HttpStatusIsInformational(AStatus) or
    (AStatus = HTTP_STATUS_NO_CONTENT) or
    (AStatus = HTTP_STATUS_NOT_MODIFIED);
end;

procedure RequireResponseWriter(const AW: IHttpResponseWriter);
begin
  if AW = nil then
    raise EArgumentError.Create('HTTP response writer is nil');
end;

function WriteAllResponseBodyString(const AW: IHttpResponseWriter;
  const ABody: string): SizeUInt;
var
  LTotal: SizeUInt;
  LWritten: SizeUInt;
  LLen: SizeUInt;
begin
  LLen := SizeUInt(Length(ABody));
  LTotal := 0;
  while LTotal < LLen do
  begin
    LWritten := AW.Write(ABody[LTotal + 1], LLen - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('HTTP response writer made zero progress');
    Inc(LTotal, LWritten);
  end;
  Result := LTotal;
end;

{ THttpRequest }

constructor THttpRequest.Create(const AMethod: THttpMethod; const AUrl: TUrl;
  const AVersion: THttpVersion; const AHeaders: IHttpHeaders;
  const ABody: IReader; const AContentLength: Int64);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := AUrl;
  FRawRequestTarget := '';
  FUrlParsed := True;
  FRequestTargetPartsParsed := True;
  FVersion := AVersion;
  FHeaders := HeadersOrNew(AHeaders);
  FBody := ABody;
  FContentLength := AContentLength;
end;

constructor THttpRequest.CreateFromRequestTarget(const AMethod: THttpMethod;
  const ARequestTarget: string; const AVersion: THttpVersion;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FRawRequestTarget := ARequestTarget;
  FUrlParsed := False;
  FRequestTargetPartsParsed := False;
  FVersion := AVersion;
  FHeaders := HeadersOrNew(AHeaders);
  FBody := ABody;
  FContentLength := AContentLength;
end;

procedure THttpRequest.EnsureUrlParsed;
begin
  if FUrlParsed then
    Exit;
  FUrl := TUrl.ParseRequestTarget(FRawRequestTarget);
  FUrlParsed := True;
  FRequestTargetPartsParsed := True;
end;

procedure THttpRequest.EnsureRequestTargetParts;
var
  LRest: string;
  LPos: SizeInt;
begin
  if FRequestTargetPartsParsed then
    Exit;
  if FUrlParsed then
  begin
    FRequestTargetPartsParsed := True;
    Exit;
  end;

  if FRawRequestTarget = '' then
    raise EHttpError.Create('Cannot parse empty request-target');

  if (FRawRequestTarget[1] <> '/') and (FRawRequestTarget[1] <> '*') and
    (Pos('://', FRawRequestTarget) > 0) then
  begin
    EnsureUrlParsed;
    Exit;
  end;

  LRest := FRawRequestTarget;

  LPos := Pos('#', LRest);
  if LPos > 0 then
  begin
    FUrl.Fragment := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  LPos := Pos('?', LRest);
  if LPos > 0 then
  begin
    FUrl.RawQuery := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  FUrl.Path := LRest;
  FRequestTargetPartsParsed := True;
end;

procedure THttpRequest.SetPathParam(const AName, AValue: string);
var
  LLen: Int32;
begin
  LLen := Length(FPathParams);
  SetLength(FPathParams, LLen + 1);
  FPathParams[LLen].Name := AName;
  FPathParams[LLen].Value := AValue;
end;

function THttpRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function THttpRequest.GetUrl: TUrl;
begin
  EnsureUrlParsed;
  Result := FUrl;
end;

function THttpRequest.GetPath: string;
begin
  EnsureRequestTargetParts;
  Result := FUrl.Path;
end;

function THttpRequest.GetRawQuery: string;
begin
  EnsureRequestTargetParts;
  Result := FUrl.RawQuery;
end;

function THttpRequest.GetVersion: THttpVersion;
begin
  Result := FVersion;
end;

function THttpRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function THttpRequest.GetBody: IReader;
begin
  Result := FBody;
end;

function THttpRequest.GetContentLength: Int64;
begin
  Result := FContentLength;
end;

function THttpRequest.PathParam(const AName: string): string;
var
  LI: Int32;
begin
  for LI := 0 to High(FPathParams) do
    if FPathParams[LI].Name = AName then
      Exit(FPathParams[LI].Value);
  Result := '';
end;

function THttpRequest.GetRemoteAddr: string;
begin
  if FRemoteAddrFromNet and (FRemoteAddr = '') then
    FRemoteAddr := FRemoteNetAddr.ToString;
  Result := FRemoteAddr;
end;

procedure THttpRequest.SetRemoteAddr(const AAddr: string);
begin
  FRemoteAddr := AAddr;
  FRemoteAddrFromNet := False;
end;

procedure THttpRequest.SetRemoteNetAddr(const AAddr: TNetAddress);
begin
  FRemoteNetAddr := AAddr;
  FRemoteAddr := '';
  FRemoteAddrFromNet := True;
end;

function THttpRequest.QueryParam(const AName: string): string;
begin
  if not FQueryParsed then
  begin
    EnsureRequestTargetParts;
    FQueryParams := ParseQueryString(FUrl.RawQuery);
    FQueryParsed := True;
  end;
  Result := QueryParamValue(FQueryParams, AName);
end;

{ THttpResponse }

constructor THttpResponse.Create(const AStatusCode: THttpStatus;
  const AHeaders: IHttpHeaders; const ABody: IReader);
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FHeaders := HeadersOrNew(AHeaders);
  FBody := ABody;
end;

function THttpResponse.GetStatusCode: THttpStatus;
begin
  Result := FStatusCode;
end;

function THttpResponse.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function THttpResponse.GetBody: IReader;
begin
  Result := FBody;
end;

{ Factory helpers }

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, NewHttpHeaders, nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AHeaders, nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ANilBody: Pointer): IHttpRequest;
begin
  if ANilBody <> nil then
    raise EArgumentError.Create(
      'HTTP nil-body compatibility overload only accepts nil');
  Result := NewRequest(AMethod, AUrl, TBytes(nil));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ANilBody: Pointer): IHttpRequest;
begin
  if ANilBody <> nil then
    raise EArgumentError.Create(
      'HTTP nil-body compatibility overload only accepts nil');
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), TBytes(nil));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), nil, ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl,
    NewRequestContentTypeHeaders(AContentType), ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AContentType, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
var
  LHeaders: IHttpHeaders;
begin
  if AContentLength < 0 then
    raise EArgumentError.Create('HTTP request content-length is negative');

  LHeaders := AHeaders;
  if LHeaders = nil then
    LHeaders := NewHttpHeaders;
  if (ABody <> nil) or (AContentLength > 0) then
    LHeaders.Set_('content-length', IntToStr(AContentLength));
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, LHeaders, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), nil, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType, ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl,
    NewRequestContentTypeHeaders(AContentType), ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AContentType, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AHeaders, StringBodyReader(ABodyText),
    Int64(Length(ABodyText)));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), nil, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl,
    NewRequestContentTypeHeaders(AContentType), ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AContentType, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AHeaders, BytesBodyReader(ABodyBytes),
    Int64(Length(ABodyBytes)));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, ABodyBytes);
end;

function NewGetRequest(const APath: string): IHttpRequest;
var
  LUrl: TUrl;
begin
  LUrl := Default(TUrl);
  LUrl.Path := APath;
  Result := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse;
begin
  Result := THttpResponse.Create(AStatus, AHeaders, ABody);
end;

function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
begin
  RequireResponseWriter(AW);
  if HttpStatusIsInformational(AStatus) then
    raise EHttpError.Create(
      'HTTP response string helper requires a final response status');
  if ResponseStatusMustNotHaveBody(AStatus) then
  begin
    if ABody <> '' then
      raise EHttpError.Create('HTTP response status must not include a body');
    AW.WriteHeader(AStatus);
    Exit(0);
  end;

  if AContentType <> '' then
    AW.GetHeaders.Set_('content-type', AContentType);
  AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(ABody))));
  AW.WriteHeader(AStatus);
  Result := WriteAllResponseBodyString(AW, ABody);
end;

end.
