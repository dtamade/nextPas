unit nextpas.core.graph.client;
{**
 * @desc Microsoft Graph REST 邮件客户端（/v1.0/me/messages，B5 第三片）。
 *       忠实投影 Graph 响应记录（不做 body_text/body_html 派生——该策略属
 *       应用层归一化管线）；access token 由调用方供给（获取/刷新/缓存走
 *       nextpas.core.oauth.client + 应用侧池策略）；transport 经 IHttpClient
 *       注入可测；错误分类四态结构化（Ok/ErrorKind/ErrorCode），transport
 *       异常原样传播（调用方区分「没网」与「API 失败」）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.intf;

type
  TGraphRecipient = record
    Name: string;
    Address: string;
  end;

  TGraphRecipientArray = array of TGraphRecipient;

  { 列表摘要（$select=id,subject,receivedDateTime,hasAttachments,from）。 }
  TGraphMessageSummary = record
    Id: string;
    Subject: string;
    ReceivedDateTime: string;   { Graph 原样 ISO8601，转换归调用方 }
    HasAttachments: Boolean;
    FromName: string;
    FromAddress: string;
  end;

  TGraphMessageSummaryArray = array of TGraphMessageSummary;

  { 正文原始形态：ContentType 为 Graph 的 'html' / 'text'。 }
  TGraphBody = record
    ContentType: string;
    Content: string;
  end;

  { 详情（$select 含 body/bodyPreview/toRecipients）。 }
  TGraphMessage = record
    Id: string;
    Subject: string;
    ReceivedDateTime: string;
    BodyPreview: string;
    HasAttachments: Boolean;
    FromName: string;
    FromAddress: string;
    ToRecipients: TGraphRecipientArray;
    Body: TGraphBody;
  end;

  { 错误分类：InvalidAuth=token/refresh 类（喂账号隔离判定安全）；
    NotFound；Transient=429/5xx/裸401（可重试）；Unexpected=其余。 }
  TGraphErrorKind = (gekNone, gekInvalidAuth, gekNotFound, gekTransient,
    gekUnexpected);

  TGraphListResult = record
    Ok: Boolean;
    Messages: TGraphMessageSummaryArray;
    NextLink: string;           { @odata.nextLink 分页游标，无则空 }
    ErrorKind: TGraphErrorKind;
    ErrorCode: string;
    ErrorMessage: string;
  end;

  TGraphMessageResult = record
    Ok: Boolean;
    Message: TGraphMessage;
    ErrorKind: TGraphErrorKind;
    ErrorCode: string;
    ErrorMessage: string;
  end;

{ 错误分类纯函数：2xx → None；token 关键词（invalid_grant/aadsts/
  interaction_required/invalid_client/invalid_token/expired_token/
  token has expired/refresh token，大小写不敏感子串）→ InvalidAuth；
  404 → NotFound；429 或 >=500 → Transient；
  裸 401（无关键词）→ Transient——临时 ACL 错误不得误判为凭证失效（原版
  同语义）；其余 → Unexpected。 }
function ClassifyGraphError(AStatus: Integer; const ACode,
  AMessage: string): TGraphErrorKind;

{ 列收件箱消息：GET {base}/v1.0/me/messages?$top=N&$orderby=receivedDateTime
  %20desc&$select=id,subject,receivedDateTime,hasAttachments,from。
  ATop 必须 >0；ABaseUrl 尾 '/' 容忍。非 2xx 走错误信封分类；
  JSON 缺 value 数组或条目缺 id → Unexpected/graph_parse_error。 }
function GraphListMessages(const AClient: IHttpClient; const ABaseUrl,
  AAccessToken: string; ATop: Integer): TGraphListResult;

{ 取单封详情：GET {base}/v1.0/me/messages/{id}?$select=id,subject,
  receivedDateTime,body,bodyPreview,hasAttachments,from,toRecipients
  （id 经 UrlEncode）。结果语义同上。 }
function GraphGetMessage(const AClient: IHttpClient; const ABaseUrl,
  AAccessToken, AMessageId: string): TGraphMessageResult;

implementation

uses
  nextpas.core.encoding.url,
  nextpas.core.http.client.helpers,
  nextpas.core.json;

type
  { token/refresh 类信号词（匹配前整体小写化） }
  TAuthSignalWords = array[0..7] of string;

const
  AUTH_SIGNAL_WORDS: TAuthSignalWords = (
    'invalid_grant', 'aadsts', 'interaction_required', 'invalid_client',
    'invalid_token', 'expired_token', 'token has expired', 'refresh token');

function IntToStrDec(const AValue: Integer): string;
begin
  Str(AValue, Result);
end;

procedure RequireCommonArgs(const AClient: IHttpClient; const ABaseUrl,
  AAccessToken: string);
var
  LBase: string;
begin
  if AClient = nil then
    raise EArgumentError.Create('graph: nil http client');
  if AAccessToken = '' then
    raise EArgumentError.Create('graph: empty access token');
  LBase := ABaseUrl;
  while (LBase <> '') and (LBase[Length(LBase)] = '/') do
    Delete(LBase, Length(LBase), 1);
  if (LBase = '') or (Pos('://', LBase) = 0) then
    raise EArgumentError.Create('graph: base url must include scheme');
end;

function TrimBase(const ABaseUrl: string): string;
begin
  Result := ABaseUrl;
  while (Result <> '') and (Result[Length(Result)] = '/') do
    Delete(Result, Length(Result), 1);
end;

function HasAuthSignal(const ALowerCombined: string): Boolean;
var
  LI: Integer;
begin
  Result := True;
  for LI := Low(AUTH_SIGNAL_WORDS) to High(AUTH_SIGNAL_WORDS) do
    if Pos(AUTH_SIGNAL_WORDS[LI], ALowerCombined) > 0 then
      Exit;
  Result := False;
end;

function ClassifyGraphError(AStatus: Integer; const ACode,
  AMessage: string): TGraphErrorKind;
var
  LI, LCh: Integer;
  LCombined: string;
begin
  { 大小写不敏感子串匹配：code + ' ' + message 拼接后比对 }
  LCombined := ACode + ' ' + AMessage;
  { 2xx 无错误可言（纯函数总契约；正常路径不会传入） }
  if (AStatus >= 200) and (AStatus <= 299) then
    Exit(gekNone);
  for LI := 1 to Length(LCombined) do
  begin
    LCh := Ord(LCombined[LI]);
    if (LCh >= Ord('A')) and (LCh <= Ord('Z')) then
      LCombined[LI] := Chr(LCh + 32);
  end;
  if HasAuthSignal(LCombined) then
    Exit(gekInvalidAuth);
  if AStatus = 404 then
    Exit(gekNotFound);
  if (AStatus = 429) or (AStatus >= 500) then
    Exit(gekTransient);
  if AStatus = 401 then
    Exit(gekTransient);
  Result := gekUnexpected;
end;

{ 解析 Graph 错误信封：code=root.error.code 否则 http_<status>；
  message=root.error.message 否则顶层 error_description 否则原文。 }
procedure ParseErrorEnvelope(const ABody: string; AStatus: Integer;
  out AKind: TGraphErrorKind; out ACode, AMessage: string);
var
  LDoc: IJsonDocument;
  LV, LE: TJsonValue;
begin
  ACode := 'http_' + IntToStrDec(AStatus);
  AMessage := ABody;
  LDoc := JsonParse(ABody);
  if (LDoc <> nil) and (not LDoc.HasError) and LDoc.Root.IsObject then
  begin
    LE := LDoc.Root.Get('error');
    if LE.IsObject then
    begin
      LV := LE.Get('code');
      if LV.IsStr and (LV.AsStr.ToString <> '') then
        ACode := LV.AsStr.ToString;
      LV := LE.Get('message');
      if LV.IsStr and (LV.AsStr.ToString <> '') then
        AMessage := LV.AsStr.ToString;
    end
    else if LE.IsStr and (LE.AsStr.ToString <> '') then
    begin
      { OAuth 风格扁平信封：{"error":"invalid_grant","error_description":...} }
      ACode := LE.AsStr.ToString;
      LV := LDoc.Root.Get('error_description');
      if LV.IsStr and (LV.AsStr.ToString <> '') then
        AMessage := LV.AsStr.ToString;
    end;
  end;
  AKind := ClassifyGraphError(AStatus, ACode, AMessage);
end;

function ParseRecipient(const AValue: TJsonValue): TGraphRecipient;
var
  LE: TJsonValue;
begin
  Result := Default(TGraphRecipient);
  LE := AValue.Get('emailAddress');
  if LE.IsObject then
  begin
    if LE.Get('name').IsStr then
      Result.Name := LE.Get('name').AsStr.ToString;
    if LE.Get('address').IsStr then
      Result.Address := LE.Get('address').AsStr.ToString;
  end;
end;

function GraphListMessages(const AClient: IHttpClient; const ABaseUrl,
  AAccessToken: string; ATop: Integer): TGraphListResult;
var
  LResp: IHttpResponse;
  LDoc: IJsonDocument;
  LArr, LItem, LFrom: TJsonValue;
  LIdx: Integer;
  LSum: TGraphMessageSummary;
  LStatus: Integer;
begin
  Result := Default(TGraphListResult);
  RequireCommonArgs(AClient, ABaseUrl, AAccessToken);
  if ATop <= 0 then
    raise EArgumentError.Create('graph: top must be positive');

  LResp := AClient.WithBearerAuth(AAccessToken).Get(
    TrimBase(ABaseUrl) + '/v1.0/me/messages?$top=' + IntToStrDec(ATop) +
    '&$orderby=receivedDateTime%20desc' +
    '&$select=id,subject,receivedDateTime,hasAttachments,from');
  LStatus := Integer(LResp.StatusCode);
  if (LStatus < 200) or (LStatus > 299) then
  begin
    ParseErrorEnvelope(HttpReadResponseBodyString(LResp), LStatus,
      Result.ErrorKind, Result.ErrorCode, Result.ErrorMessage);
    Exit;
  end;

  LDoc := JsonParse(HttpReadResponseBodyString(LResp));
  if (LDoc = nil) or LDoc.HasError or (not LDoc.Root.IsObject) then
  begin
    Result.ErrorKind := gekUnexpected;
    Result.ErrorCode := 'graph_parse_error';
    Result.ErrorMessage := 'list response is not a JSON object';
    Exit;
  end;
  LArr := LDoc.Root.Get('value');
  if not LArr.IsArray then
  begin
    Result.ErrorKind := gekUnexpected;
    Result.ErrorCode := 'graph_parse_error';
    Result.ErrorMessage := 'list response missing value array';
    Exit;
  end;
  SetLength(Result.Messages, LArr.ArrayLen);
  for LIdx := 0 to Integer(LArr.ArrayLen) - 1 do
  begin
    LItem := LArr.ArrayGet(LIdx);
    LSum := Default(TGraphMessageSummary);
    if LItem.Get('id').IsStr then
      LSum.Id := LItem.Get('id').AsStr.ToString;
    if LSum.Id = '' then
    begin
      Result.ErrorKind := gekUnexpected;
      Result.ErrorCode := 'graph_parse_error';
      Result.ErrorMessage := 'list item missing id';
      Exit;
    end;
    if LItem.Get('subject').IsStr then
      LSum.Subject := LItem.Get('subject').AsStr.ToString;
    if LItem.Get('receivedDateTime').IsStr then
      LSum.ReceivedDateTime := LItem.Get('receivedDateTime').AsStr.ToString;
    LSum.HasAttachments := LItem.Get('hasAttachments').AsBool;
    LFrom := LItem.Get('from');
    if LFrom.IsObject then
    begin
      LFrom := LFrom.Get('emailAddress');
      if LFrom.IsObject then
      begin
        if LFrom.Get('name').IsStr then
          LSum.FromName := LFrom.Get('name').AsStr.ToString;
        if LFrom.Get('address').IsStr then
          LSum.FromAddress := LFrom.Get('address').AsStr.ToString;
      end;
    end;
    Result.Messages[LIdx] := LSum;
  end;
  if LDoc.Root.Get('@odata.nextLink').IsStr then
    Result.NextLink := LDoc.Root.Get('@odata.nextLink').AsStr.ToString;
  Result.Ok := True;
end;

function GraphGetMessage(const AClient: IHttpClient; const ABaseUrl,
  AAccessToken, AMessageId: string): TGraphMessageResult;
var
  LResp: IHttpResponse;
  LDoc: IJsonDocument;
  LRoot, LTo, LItem: TJsonValue;
  LIdx: Integer;
  LMsg: TGraphMessage;
  LStatus: Integer;
begin
  Result := Default(TGraphMessageResult);
  RequireCommonArgs(AClient, ABaseUrl, AAccessToken);
  if AMessageId = '' then
    raise EArgumentError.Create('graph: empty message id');

  LResp := AClient.WithBearerAuth(AAccessToken).Get(
    TrimBase(ABaseUrl) + '/v1.0/me/messages/' + UrlEncode(AMessageId) +
    '?$select=id,subject,receivedDateTime,body,bodyPreview,' +
    'hasAttachments,from,toRecipients');
  LStatus := Integer(LResp.StatusCode);
  if (LStatus < 200) or (LStatus > 299) then
  begin
    ParseErrorEnvelope(HttpReadResponseBodyString(LResp), LStatus,
      Result.ErrorKind, Result.ErrorCode, Result.ErrorMessage);
    Exit;
  end;

  LDoc := JsonParse(HttpReadResponseBodyString(LResp));
  if (LDoc = nil) or LDoc.HasError or (not LDoc.Root.IsObject) then
  begin
    Result.ErrorKind := gekUnexpected;
    Result.ErrorCode := 'graph_parse_error';
    Result.ErrorMessage := 'message response is not a JSON object';
    Exit;
  end;
  LRoot := LDoc.Root;
  LMsg := Default(TGraphMessage);
  if LRoot.Get('id').IsStr then
    LMsg.Id := LRoot.Get('id').AsStr.ToString;
  if LMsg.Id = '' then
  begin
    Result.ErrorKind := gekUnexpected;
    Result.ErrorCode := 'graph_parse_error';
    Result.ErrorMessage := 'message response missing id';
    Exit;
  end;
  if LRoot.Get('subject').IsStr then
    LMsg.Subject := LRoot.Get('subject').AsStr.ToString;
  if LRoot.Get('receivedDateTime').IsStr then
    LMsg.ReceivedDateTime := LRoot.Get('receivedDateTime').AsStr.ToString;
  if LRoot.Get('bodyPreview').IsStr then
    LMsg.BodyPreview := LRoot.Get('bodyPreview').AsStr.ToString;
  LMsg.HasAttachments := LRoot.Get('hasAttachments').AsBool;
  if LRoot.Get('from').IsObject then
  begin
    LTo := LRoot.Get('from').Get('emailAddress');
    if LTo.IsObject then
    begin
      if LTo.Get('name').IsStr then
        LMsg.FromName := LTo.Get('name').AsStr.ToString;
      if LTo.Get('address').IsStr then
        LMsg.FromAddress := LTo.Get('address').AsStr.ToString;
    end;
  end;
  LTo := LRoot.Get('toRecipients');
  if LTo.IsArray then
  begin
    SetLength(LMsg.ToRecipients, LTo.ArrayLen);
    for LIdx := 0 to Integer(LTo.ArrayLen) - 1 do
    begin
      LItem := LTo.ArrayGet(LIdx);
      if LItem.IsObject then
        LMsg.ToRecipients[LIdx] := ParseRecipient(LItem)
      else
        LMsg.ToRecipients[LIdx] := Default(TGraphRecipient);
    end;
  end;
  if LRoot.Get('body').IsObject then
  begin
    if LRoot.Get('body').Get('contentType').IsStr then
      LMsg.Body.ContentType :=
        LRoot.Get('body').Get('contentType').AsStr.ToString;
    if LRoot.Get('body').Get('content').IsStr then
      LMsg.Body.Content := LRoot.Get('body').Get('content').AsStr.ToString;
  end;
  Result.Message := LMsg;
  Result.Ok := True;
end;

end.
