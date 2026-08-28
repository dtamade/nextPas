program test_graphql;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.json,
  nextpas.core.test,
  nextpas.core.graphql;

var
  T: TTestSuite;
  GCapturedBody: string;
  GCapturedContentType: string;
  GResponseBody: string;
  GResponseStatus: THttpStatus;

type
  TMockGraphqlClient = class(TInterfacedObject, IHttpClient)
  public
    function Send(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
    function Get(const AUrl: string): IHttpResponse;
    function GetString(const AUrl: string): string;
    function GetBytes(const AUrl: string): TBytes;
    function GetJson(const AUrl: string): IJsonDocument;
    function PostString(const AUrl, AContentType, ABody: string): string;
    function PutString(const AUrl, AContentType, ABody: string): string;
    function PatchString(const AUrl, AContentType, ABody: string): string;
    function DeleteString(const AUrl: string): string;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Delete(const AUrl: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Head(const AUrl: string): IHttpResponse;
    function Options(const AUrl: string): IHttpResponse;
    function PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse;
    function PostMultipart(const AUrl: string; const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse;
    function PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string; const AContentType: string; const ABody: IReader; const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
    function WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
    function WithProxyUrl(const AProxyUrl: string): IHttpClient;
    function WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
    function WithTLSContext(const ATLSContext: ISSLContext): IHttpClient;
  end;

function TMockGraphqlClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  GCapturedBody := HttpReadRequestBodyString(AReq);
  if AReq.Headers <> nil then
    GCapturedContentType := AReq.Headers.Get('content-type')
  else
    GCapturedContentType := '';
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-type', 'application/json');
  Result := NewResponse(GResponseStatus, LHeaders, GResponseBody);
end;

procedure TMockGraphqlClient.CloseIdleConnections; begin end;
function TMockGraphqlClient.Get(const AUrl: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.GetString(const AUrl: string): string; begin Result := ''; end;
function TMockGraphqlClient.GetBytes(const AUrl: string): TBytes; begin Result := nil; end;
function TMockGraphqlClient.GetJson(const AUrl: string): IJsonDocument; begin Result := nil; end;
function TMockGraphqlClient.PostString(const AUrl, AContentType, ABody: string): string; begin Result := ''; end;
function TMockGraphqlClient.PutString(const AUrl, AContentType, ABody: string): string; begin Result := ''; end;
function TMockGraphqlClient.PatchString(const AUrl, AContentType, ABody: string): string; begin Result := ''; end;
function TMockGraphqlClient.DeleteString(const AUrl: string): string; begin Result := ''; end;
function TMockGraphqlClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Delete(const AUrl: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Head(const AUrl: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.Options(const AUrl: string): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.PostMultipart(const AUrl: string; const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.SendStreaming(const AMethod: THttpMethod; const AUrl: string; const AContentType: string; const ABody: IReader; const AContentLength: Int64): IHttpResponse; begin Result := nil; end;
function TMockGraphqlClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithBearerAuth(const AToken: string): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithHeader(const AName, AValue: string): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithRetry(const AMaxRetries: Int32): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithCookieJar(const AJar: IHttpCookieJar): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithProxyUrl(const AProxyUrl: string): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithDialFunc(const ADial: THttpDialFunc): IHttpClient; begin Result := Self; end;
function TMockGraphqlClient.WithTLSContext(const ATLSContext: ISSLContext): IHttpClient; begin Result := Self; end;

procedure SetupMock(const ABody: string; AStatus: THttpStatus = HTTP_STATUS_OK);
begin
  GResponseBody := ABody;
  GResponseStatus := AStatus;
  GCapturedBody := '';
  GCapturedContentType := '';
end;

procedure TestQueryOnly;
var
  C: IHttpClient;
  D: IJsonDocument;
  V: TJsonValue;
begin
  SetupMock('{"data":{"ok":1}}');
  C := TMockGraphqlClient.Create;
  D := GraphqlFetch(C, 'http://example.com/graphql', '{ ok }');
  CheckEqual('application/json', GCapturedContentType, 'content-type');
  CheckContains(GCapturedBody, '"query"', 'has query key');
  CheckContains(GCapturedBody, '{ ok }', 'query value');
  CheckFalse(Pos('"variables"', GCapturedBody) > 0, 'no variables when empty');
  CheckFalse(Pos('"operationName"', GCapturedBody) > 0, 'no opName when empty');
  V := D.Root.ObjectGet('data').ObjectGet('ok');
  Check(V.IsInt, 'ok is int');
  CheckEqual(Int64(1), V.AsInt, 'ok=1');
end;

procedure TestVariables;
var
  C: IHttpClient;
  D: IJsonDocument;
begin
  SetupMock('{"data":{"user":1}}');
  C := TMockGraphqlClient.Create;
  D := GraphqlFetch(C, 'http://example.com/graphql', 'query Q($id:ID){user}', '{"id":1}', '');
  CheckContains(GCapturedBody, '"variables"', 'has variables');
  CheckContains(GCapturedBody, '"id":1', 'variables raw json');
  CheckFalse(Pos('\"id\"', GCapturedBody) > 0, 'variables not double escaped');
  Check(D <> nil, 'doc not nil');
end;

procedure TestOperationName;
var
  C: IHttpClient;
begin
  SetupMock('{"data":{"x":1}}');
  C := TMockGraphqlClient.Create;
  GraphqlFetch(C, 'http://example.com/graphql', 'query MyOp{field}', '{"a":2}', 'MyOp');
  CheckContains(GCapturedBody, '"operationName"', 'has opName');
  CheckContains(GCapturedBody, 'MyOp', 'opName value');
  CheckContains(GCapturedBody, '"variables"', 'has variables with opName');
end;

procedure TestInvalidVariablesJson;
var
  C: IHttpClient;
  LRaised: Boolean;
  LMsg: string;
begin
  SetupMock('{"data":{}}');
  C := TMockGraphqlClient.Create;
  LRaised := False;
  try
    GraphqlFetch(C, 'http://example.com/graphql', '{x}', 'not json', '');
  except
    on E: EArgumentError do
    begin
      LRaised := True;
      LMsg := E.Message;
    end;
    on E: Exception do
      Fail('wrong exception: ' + E.ClassName);
  end;
  Check(LRaised, 'invalid variables raises EArgumentError');
  CheckContains(LMsg, 'graphql variables is not valid JSON', 'message prefix');
end;

procedure TestErrorsString;
var
  C: IHttpClient;
  LRaised: Boolean;
  LMsg: string;
begin
  SetupMock('{"errors":["boom","fail"],"data":null}');
  C := TMockGraphqlClient.Create;
  LRaised := False;
  try
    GraphqlFetch(C, 'http://example.com/graphql', '{x}');
  except
    on E: EGraphqlError do
    begin
      LRaised := True;
      LMsg := E.Message;
    end;
    on E: Exception do
    begin
      if Pos('graphql error:', E.Message) > 0 then
      begin
        LRaised := True;
        LMsg := E.Message;
      end
      else
        Fail('wrong message: ' + E.Message);
    end;
  end;
  Check(LRaised, 'errors string raises');
  CheckContains(LMsg, 'graphql error:', 'prefix');
  CheckContains(LMsg, 'boom', 'contains boom');
  CheckContains(LMsg, 'fail', 'contains fail');
end;

procedure TestErrorsObject;
var
  C: IHttpClient;
  LRaised: Boolean;
  LMsg: string;
begin
  SetupMock('{"errors":[{"message":"boom object"}]}');
  C := TMockGraphqlClient.Create;
  LRaised := False;
  try
    GraphqlFetch(C, 'http://example.com/graphql', '{x}');
  except
    on E: Exception do
    begin
      if Pos('graphql error:', E.Message) > 0 then
      begin
        LRaised := True;
        LMsg := E.Message;
      end;
    end;
  end;
  Check(LRaised, 'errors object raises');
  CheckContains(LMsg, 'boom object', 'object message extracted');
end;

procedure TestErrorsObjectWithoutMessage;
var
  C: IHttpClient;
  LRaised: Boolean;
  LMsg: string;
begin
  SetupMock('{"errors":[{"code":123}],"data":null}');
  C := TMockGraphqlClient.Create;
  LRaised := False;
  try
    GraphqlFetch(C, 'http://example.com/graphql', '{x}');
  except
    on E: Exception do
    begin
      if Pos('graphql error:', E.Message) > 0 then
      begin
        LRaised := True;
        LMsg := E.Message;
      end;
    end;
  end;
  Check(LRaised, 'errors object without message raises');
  CheckContains(LMsg, '123', 'fallback stringify contains code');
end;

procedure TestEmptyData;
var
  C: IHttpClient;
  LRaised: Boolean;
  LMsg: string;
begin
  SetupMock('{"foo":1}');
  C := TMockGraphqlClient.Create;
  LRaised := False;
  try
    GraphqlFetch(C, 'http://example.com/graphql', '{x}');
  except
    on E: EGraphqlError do
    begin
      LRaised := True;
      LMsg := E.Message;
    end;
    on E: Exception do
    begin
      if Pos('empty graphql response', E.Message) > 0 then
      begin
        LRaised := True;
        LMsg := E.Message;
      end;
    end;
  end;
  Check(LRaised, 'empty data raises');
  CheckContains(LMsg, 'empty graphql response', 'message');
end;

procedure TestSuccessData;
var
  C: IHttpClient;
  D: IJsonDocument;
begin
  SetupMock('{"data":{"user":{"name":"Alice"}}}');
  C := TMockGraphqlClient.Create;
  D := GraphqlFetch(C, 'http://example.com/graphql', '{user{name}}');
  Check(D <> nil, 'success not nil');
  CheckFalse(D.HasError, 'no parse error');
  CheckEqual('Alice', D.Root.ObjectGet('data').ObjectGet('user').ObjectGet('name').AsStr.ToString, 'name=Alice');
end;

procedure TestVariablesOmittedWhenEmpty;
var
  C: IHttpClient;
begin
  SetupMock('{"data":{}}');
  C := TMockGraphqlClient.Create;
  GraphqlFetch(C, 'http://example.com/graphql', '{x}', '', 'OpOnly');
  CheckFalse(Pos('"variables"', GCapturedBody) > 0, 'variables omitted');
  CheckContains(GCapturedBody, '"operationName"', 'opName present');
end;

begin
  T := TTestSuite.Create('nextpas.core.graphql');
  T.Test('query only', @TestQueryOnly);
  T.Test('variables', @TestVariables);
  T.Test('operationName', @TestOperationName);
  T.Test('invalid variables json', @TestInvalidVariablesJson);
  T.Test('errors string', @TestErrorsString);
  T.Test('errors object', @TestErrorsObject);
  T.Test('errors object without message', @TestErrorsObjectWithoutMessage);
  T.Test('empty data', @TestEmptyData);
  T.Test('success data', @TestSuccessData);
  T.Test('variables omitted when empty', @TestVariablesOmittedWhenEmpty);
  if not T.Run then Halt(1);
end.
