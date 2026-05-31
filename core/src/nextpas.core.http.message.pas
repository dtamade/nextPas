unit nextpas.core.http.message;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

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
      FVersion: THttpVersion;
      FHeaders: IHttpHeaders;
      FBody: IReader;
      FContentLength: Int64;
      FPathParams: array of TPathParam;
  public
    constructor Create(const AMethod: THttpMethod; const AUrl: TUrl;
      const AVersion: THttpVersion; const AHeaders: IHttpHeaders;
      const ABody: IReader; const AContentLength: Int64);
    procedure SetPathParam(const AName, AValue: string);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function PathParam(const AName: string): string;
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
  FVersion := AVersion;
  FHeaders := AHeaders;
  FBody := ABody;
  FContentLength := AContentLength;
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
  Result := FUrl;
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
