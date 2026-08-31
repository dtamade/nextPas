program test_graph_client;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.headers,
  nextpas.core.http.client,
  nextpas.core.graph.client;

var
  T: TTestSuite;

const
  BASE = 'https://graph.microsoft.com';
  TOKEN = 'at-123';

type
  { 记录请求 + 返回预设响应的 fake transport（零网络、确定性） }
  TFakeTransport = class(TInterfacedObject, IHttpTransport)
  public
    LastMethod: string;
    LastUrl: string;
    LastAuth: string;
    RespStatus: Integer;
    RespBody: string;
    RaiseOnCall: Boolean;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

function TFakeTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LB: TBytes;
begin
  if RaiseOnCall then
    raise ENextPasError.Create('transport down');
  LastMethod := HttpMethodToStr(AReq.Method);
  LastUrl := AReq.Url.ToString;
  LastAuth := AReq.Headers.Get('Authorization');
  SetLength(LB, Length(RespBody));
  if Length(LB) > 0 then
    Move(PAnsiChar(RespBody)^, LB[0], Length(LB));
  Result := NewResponse(THttpStatus(RespStatus), NewHttpHeaders, RespBody);
end;

function MakeClient(out ATransport: TFakeTransport): IHttpClient;
begin
  ATransport := TFakeTransport.Create;
  ATransport.RespStatus := 200;
  Result := NewHttpClient(ATransport);
end;

procedure TestListSuccess;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LR: TGraphListResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespBody :=
    '{"@odata.context":"ctx","value":[' +
    '{"id":"AAMk1","subject":"Hello","receivedDateTime":"2026-08-21T10:00:00Z",' +
    '"hasAttachments":true,"from":{"emailAddress":{"name":"Alice","address":"a@x.com"}}},' +
    '{"id":"AAMk2","subject":"No from","receivedDateTime":"2026-08-21T09:00:00Z"}' +
    '],"@odata.nextLink":"' + BASE + '/v1.0/me/messages?$skip=25"}';
  LR := GraphListMessages(LClient, BASE, TOKEN, 25);
  Check(LR.Ok, 'list ok');
  Check(LR.ErrorKind = gekNone, 'list error kind none');
  Check(Length(LR.Messages) = 2, 'list count');
  Check(LTransport.LastMethod = 'GET', 'list uses GET');
  Check(LTransport.LastAuth = 'Bearer ' + TOKEN, 'bearer header');
  Check(Pos('$top=25&$orderby=receivedDateTime%20desc', LTransport.LastUrl) > 0,
    'top + orderby in url');
  Check(Pos('&$select=id,subject,receivedDateTime,hasAttachments,from',
    LTransport.LastUrl) > 0, 'summary select fields');
  Check(Pos(BASE + '/v1.0/me/messages?', LTransport.LastUrl) = 1, 'base path');
  Check(LR.Messages[0].Id = 'AAMk1', 'summary id');
  Check(LR.Messages[0].Subject = 'Hello', 'summary subject');
  Check(LR.Messages[0].ReceivedDateTime = '2026-08-21T10:00:00Z',
    'summary receivedDateTime raw');
  Check(LR.Messages[0].HasAttachments, 'summary hasAttachments');
  Check(LR.Messages[0].FromAddress = 'a@x.com', 'nested from address');
  Check(LR.Messages[0].FromName = 'Alice', 'nested from name');
  Check((LR.Messages[1].FromAddress = '') and (not LR.Messages[1].HasAttachments),
    'missing optional fields default safe');
  Check(LR.NextLink = BASE + '/v1.0/me/messages?$skip=25', 'nextLink captured');
end;

procedure TestListEmptyValueAndTrailingSlash;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LR: TGraphListResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespBody := '{"value":[]}';
  LR := GraphListMessages(LClient, BASE + '/', TOKEN, 10);
  Check(LR.Ok and (Length(LR.Messages) = 0), 'empty inbox ok (trailing slash tolerated)');
  Check(Pos(BASE + '/v1.0/me/messages?', LTransport.LastUrl) = 1,
    'double slash collapsed');
  Check(LR.NextLink = '', 'no nextLink when absent');
end;

procedure TestListNonJsonBody;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphListResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespBody := '<html>gateway error</html>';
  LR := GraphListMessages(LClient, BASE, TOKEN, 25);
  Check(not LR.Ok, 'non-json body fails');
  Check(LR.ErrorKind = gekUnexpected, 'parse failure classified unexpected');
  Check(LR.ErrorCode = 'graph_parse_error', 'parse error code');
end;

procedure TestListMissingValueArray;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphListResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespBody := '{"odata":"whatever"}';
  LR := GraphListMessages(LClient, BASE, TOKEN, 25);
  Check(not LR.Ok, 'missing value array fails');
  Check(LR.ErrorCode = 'graph_parse_error', 'missing value error code');
end;

procedure TestGetSuccessHtmlWithRecipients;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphMessageResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespBody :=
    '{"id":"MSG/1=","subject":"Full","receivedDateTime":"2026-08-21T11:00:00Z",' +
    '"bodyPreview":"prev","hasAttachments":false,' +
    '"from":{"emailAddress":{"name":"Bob","address":"b@y.com"}},' +
    '"toRecipients":[{"emailAddress":{"name":"","address":"me@hot.com"}},' +
    '{"emailAddress":{"address":"other@hot.com"}}],' +
    '"body":{"contentType":"html","content":"<p>hi</p>"}}';
  LR := GraphGetMessage(LClient, BASE, TOKEN, 'MSG/1=');
  Check(LR.Ok, 'get ok');
  Check(Pos(BASE + '/v1.0/me/messages/MSG%2F1%3D?',
    LTransport.LastUrl) = 1, 'message id url-encoded');
  Check(Pos('$select=id,subject,receivedDateTime,body,bodyPreview,' +
    'hasAttachments,from,toRecipients', LTransport.LastUrl) > 0,
    'detail select fields');
  Check(LR.Message.Id = 'MSG/1=', 'decoded id kept raw');
  Check(LR.Message.FromAddress = 'b@y.com', 'from address');
  Check(Length(LR.Message.ToRecipients) = 2, 'recipients count');
  Check(LR.Message.ToRecipients[0].Address = 'me@hot.com', 'recipient 1');
  Check(LR.Message.ToRecipients[1].Address = 'other@hot.com', 'recipient 2');
  Check(LR.Message.Body.ContentType = 'html', 'body content type html');
  Check(LR.Message.Body.Content = '<p>hi</p>', 'body content raw');
  Check(LR.Message.BodyPreview = 'prev', 'body preview');
end;

procedure TestGet404Envelope;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphMessageResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 404;
  LTransport.RespBody :=
    '{"error":{"code":"ErrorItemNotFound",' +
    '"message":"The specified object was not found"}}';
  LR := GraphGetMessage(LClient, BASE, TOKEN, 'gone');
  Check(not LR.Ok, '404 not ok');
  Check(LR.ErrorKind = gekNotFound, '404 -> NotFound');
  Check(LR.ErrorCode = 'ErrorItemNotFound', 'envelope code extracted');
  Check(Pos('not found', LR.ErrorMessage) > 0, 'envelope message extracted');
end;

procedure TestGetBare401IsTransient;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphMessageResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 401;
  LTransport.RespBody := 'gateway hiccup';
  LR := GraphGetMessage(LClient, BASE, TOKEN, 'm1');
  Check(LR.ErrorKind = gekTransient, 'bare 401 -> Transient (no keyword)');
  Check(LR.ErrorCode = 'http_401', 'non-json fallback code http_401');
end;

procedure TestGet403UnexpectedNotInvalidAuth;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphMessageResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 403;
  LTransport.RespBody :=
    '{"error":{"code":"ErrorAccessDenied","message":"ACL glitch"}}';
  LR := GraphGetMessage(LClient, BASE, TOKEN, 'm2');
  Check(LR.ErrorKind = gekUnexpected,
    'bare 403 -> Unexpected (must not feed auth quarantine)');
end;

procedure TestGetInvalidGrantClassified;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LR: TGraphMessageResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 400;
  LTransport.RespBody :=
    '{"error":{"code":"invalid_grant","message":"token expired"}}';
  LR := GraphGetMessage(LClient, BASE, TOKEN, 'm3');
  Check(LR.ErrorKind = gekInvalidAuth, 'invalid_grant -> InvalidAuth');
end;

procedure TestClassifyDirectMatrix;
begin
  Check(ClassifyGraphError(200, '', '') = gekNone, 'classify none on 2xx');
  Check(ClassifyGraphError(500, 'X', 'contains AADSTS50173') = gekInvalidAuth,
    'AADSTS in message -> InvalidAuth');
  Check(ClassifyGraphError(429, 'throttled', '') = gekTransient,
    '429 -> Transient');
  Check(ClassifyGraphError(503, 'oops', '') = gekTransient, '5xx -> Transient');
  Check(ClassifyGraphError(401, 'InvalidAuthenticationToken', 'nope') =
    gekTransient, 'bare 401 token-ish code w/o signal word -> Transient');
  Check(ClassifyGraphError(400, 'Interaction_Required', '') = gekInvalidAuth,
    'interaction_required case-insensitive');
  Check(ClassifyGraphError(400, 'Other', 'refresh token is bad') =
    gekInvalidAuth, 'refresh token phrase in message');
end;

procedure TestTransportExceptionPropagates;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;
  LOk: Boolean;
  LR: TGraphListResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RaiseOnCall := True;
  LOk := False;
  try
    LR := GraphListMessages(LClient, BASE, TOKEN, 25);
    if not LR.Ok then LOk := False;
  except
    on E: ENextPasError do
      LOk := Pos('transport down', E.Message) > 0;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'transport exception propagates (caller distinguishes outage)');
end;

procedure TestArgValidation;
var
  LClient: IHttpClient;
  LTransport: TFakeTransport;

  procedure ExpectListArg(const ABase, AToken: string; AClientNil: Boolean;
    ATop: Integer; const AMsg: string);
  var
    LC: IHttpClient;
    LOk2: Boolean;
  begin
    if AClientNil then LC := nil else LC := LClient;
    LOk2 := False;
    try
      GraphListMessages(LC, ABase, AToken, ATop);
    except
      on E: EArgumentError do LOk2 := True;
      on E: Exception do LOk2 := False;
    end;
    Check(LOk2, AMsg);
  end;

  procedure ExpectGetArg(const ABase, AToken, AMsgId: string;
    const AMsg: string);
  var
    LOk2: Boolean;
  begin
    LOk2 := False;
    try
      GraphGetMessage(LClient, ABase, AToken, AMsgId);
    except
      on E: EArgumentError do LOk2 := True;
      on E: Exception do LOk2 := False;
    end;
    Check(LOk2, AMsg);
  end;

begin
  LClient := MakeClient(LTransport);
  ExpectListArg(BASE, TOKEN, True, 25, 'nil client -> EArgumentError');
  ExpectListArg(BASE, '', False, 25, 'empty token -> EArgumentError');
  ExpectListArg(BASE, TOKEN, False, 0, 'top<=0 -> EArgumentError');
  ExpectListArg('no-scheme', TOKEN, False, 25, 'base without scheme -> EArgumentError');
  ExpectGetArg('no-scheme', TOKEN, 'm', 'bad base on get too');
  ExpectGetArg(BASE, TOKEN, '', 'empty message id -> EArgumentError');
end;

begin
  T := TTestSuite.Create('nextpas.core.graph.client');
  T.Test('List success (url/bearer/nested parse)', @TestListSuccess);
  T.Test('List empty value + trailing slash base', @TestListEmptyValueAndTrailingSlash);
  T.Test('List non-json body parse error', @TestListNonJsonBody);
  T.Test('List missing value array', @TestListMissingValueArray);
  T.Test('Get success html with recipients', @TestGetSuccessHtmlWithRecipients);
  T.Test('Get 404 envelope classified NotFound', @TestGet404Envelope);
  T.Test('Get bare 401 transient not invalid-auth', @TestGetBare401IsTransient);
  T.Test('Get bare 403 unexpected', @TestGet403UnexpectedNotInvalidAuth);
  T.Test('Get invalid_grant InvalidAuth', @TestGetInvalidGrantClassified);
  T.Test('Classify direct matrix', @TestClassifyDirectMatrix);
  T.Test('Transport exception propagates', @TestTransportExceptionPropagates);
  T.Test('Arg validation', @TestArgValidation);
  if not T.Run then Halt(1);
end.
