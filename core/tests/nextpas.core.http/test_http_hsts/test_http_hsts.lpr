program test_http_hsts;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.hsts;

type
  TMockWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FHdrs: IHttpHeaders;
    FStatus: THttpStatus;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
  end;

constructor TMockWriter.Create;
begin
  inherited Create;
  FHdrs := NewHttpHeaders;
  FStatus := HTTP_STATUS_OK;
end;

procedure TMockWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TMockWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TMockWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHdrs;
end;

function TMockWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

procedure TMockWriter.Flush;
begin
end;

{ === HSTS Tests === }

procedure TestHstsDefault;
var
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LHdrs: IHttpHeaders;
  LW: TMockWriter;
  LHsts: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [HstsMiddleware]
  );
  LHdrs := NewHttpHeaders;
  { HTTPS request: HSTS header should be added }
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('https://example.com/test'), hvHttp11, LHdrs, nil, 0);
  LW := TMockWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  LHsts := LW.GetHeaders.Get('strict-transport-security');
  Check(LHsts <> '', 'HSTS header is set for HTTPS');
  Check(Pos('max-age=31536000', LHsts) > 0, 'Default max-age is 31536000');
  Check(Pos('includeSubDomains', LHsts) > 0, 'Default includes subdomains');
  Check(Pos('preload', LHsts) = 0, 'Default does not include preload');
end;

procedure TestHstsHttpNoHeader;
var
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LHdrs: IHttpHeaders;
  LW: TMockWriter;
  LHsts: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [HstsMiddleware]
  );
  LHdrs := NewHttpHeaders;
  { Plain HTTP request: HSTS header must NOT be added (RFC 6797 §7.2) }
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/test'), hvHttp11, LHdrs, nil, 0);
  LW := TMockWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  LHsts := LW.GetHeaders.Get('strict-transport-security');
  Check(LHsts = '', 'No HSTS header for plain HTTP');
end;

procedure TestHstsForwardedProto;
var
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LHdrs: IHttpHeaders;
  LW: TMockWriter;
  LHsts: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [HstsMiddleware]
  );
  LHdrs := NewHttpHeaders;
  LHdrs.SetHeader('x-forwarded-proto', 'https');
  { HTTP request behind reverse proxy with X-Forwarded-Proto: https }
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/test'), hvHttp11, LHdrs, nil, 0);
  LW := TMockWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  LHsts := LW.GetHeaders.Get('strict-transport-security');
  Check(LHsts <> '', 'HSTS header set when X-Forwarded-Proto is https');
end;

procedure TestHstsCustom;
var
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LHdrs: IHttpHeaders;
  LW: TMockWriter;
  LHsts: string;
  LOpts: THstsOptions;
begin
  LOpts.MaxAge := 86400;
  LOpts.IncludeSubDomains := False;
  LOpts.Preload := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [HstsMiddlewareWith(LOpts)]
  );
  LHdrs := NewHttpHeaders;
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('https://example.com/test'), hvHttp11, LHdrs, nil, 0);
  LW := TMockWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  LHsts := LW.GetHeaders.Get('strict-transport-security');
  Check(Pos('max-age=86400', LHsts) > 0, 'Custom max-age is 86400');
  Check(Pos('includeSubDomains', LHsts) = 0, 'No includeSubDomains when disabled');
  Check(Pos('preload', LHsts) > 0, 'Preload enabled');
end;

procedure TestHstsOptions;
var
  LOpts: THstsOptions;
begin
  LOpts := THstsOptions.Default;
  CheckEqual(Int64(31536000), LOpts.MaxAge, 'Default max-age is 31536000');
  Check(LOpts.IncludeSubDomains = True, 'Default includeSubDomains is true');
  Check(LOpts.Preload = False, 'Default preload is false');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('HSTS Middleware Tests');
  T.Test('Default options', @TestHstsDefault);
  T.Test('HTTP no header', @TestHstsHttpNoHeader);
  T.Test('Forwarded proto', @TestHstsForwardedProto);
  T.Test('Custom options', @TestHstsCustom);
  T.Test('Options defaults', @TestHstsOptions);
  if not T.Run then
    Halt(1);
end.
