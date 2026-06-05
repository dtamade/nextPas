unit nextpas.core.http.message;

{$I nextpas.core.settings.inc}

interface

uses
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
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
function NewGetRequest(const APath: string): IHttpRequest;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse;

implementation

uses
  nextpas.core.http.headers;

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
  FHeaders := AHeaders;
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
  FHeaders := AHeaders;
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
  FHeaders := AHeaders;
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

end.
