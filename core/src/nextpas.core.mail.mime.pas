unit nextpas.core.mail.mime;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail.mime - 邮件语义 ↔ MIME 语法桥接层。
 *
 * MIME 语法（头/传输编码/multipart 树/RFC 2047-2231）唯一所有者是
 * nextpas.core.mime（INV-A3），本单元只做：
 *   1. TMailMessage（摊平业务模型）↔ TMimeMessage（通用树）双向映射；
 *   2. 邮件特定字段语义：地址头（MimeParseAddressList）、日期
 *      （MimeFormatDate/MimeParseDate 容错）、Subject/display-name 的
 *      RFC 2047 编解码接入；
 *   3. 公开 API 兼容既有调用方（旧函数名/类型名为包装或别名，行为不变）。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mime,
  nextpas.core.mime.parser,
  nextpas.core.mail.base;

type
  { 兼容既有类型名（指向 mime 层） }
  EMimeError = nextpas.core.mime.EMimeError;
  TMimeIssueKind = nextpas.core.mime.TMimeIssueKind;
  TMimeIssue = nextpas.core.mime.TMimeIssue;
  TMimeIssueList = nextpas.core.mime.TMimeIssueArray;
  TMimeHeader = nextpas.core.mime.TMimeHeader;
  TMimeHeaders = nextpas.core.mime.TMimeHeaderArray;
  TMimeParam = nextpas.core.mime.TMimeParameter;
  TMimeParams = nextpas.core.mime.TMimeParameterArray;
  TMimeContentType = nextpas.core.mime.TMimeContentType;
  TMimeContentDisposition = nextpas.core.mime.TMimeContentDisposition;
  TMailAddressArray = nextpas.core.mail.base.TMailAddressArray;

const
  { 枚举值 re-export（FPC 枚举值不随类型别名传播；值来自 mime.parser） }
  miNone = nextpas.core.mime.parser.miNone;
  miBadEncoding = nextpas.core.mime.parser.miBadEncoding;
  miBadDate = nextpas.core.mime.parser.miBadDate;
  miTruncatedMultipart = nextpas.core.mime.parser.miTruncatedMultipart;
  miBadHeader = nextpas.core.mime.parser.miBadHeader;
  miBadAddress = nextpas.core.mime.parser.miBadAddress;
  miUnknownTransferEncoding = nextpas.core.mime.parser.miUnknownTransferEncoding;
  miTooDeep = nextpas.core.mime.parser.miTooDeep;

{ --- 兼容转发：传输编码原语 --- }

{ base64 编码，76 列 CRLF 折行（RFC 2045 §6.8） }
function MimeBase64Encode(const AData: TBytes): string;
{ base64 解码：容忍折行空白，坏输入返回 False }
function MimeBase64Decode(const AEncoded: string; out AData: TBytes): Boolean;
{ quoted-printable 编码：=XX 转义、源行尾空白编码、76 列软换行 }
function MimeQuotedPrintableEncode(const AData: TBytes): string;
{ quoted-printable 解码：软换行移除、硬换行保留并清理行尾空白；坏编码返回 False }
function MimeQuotedPrintableDecode(const AEncoded: string; out AData: TBytes): Boolean;

{ --- 兼容转发：头 / 结构化字段（容错语义，与 mime.parser 一致） --- }

{ 拆出折叠头与正文；无冒号行跳过并记 miBadHeader；输入为空返回 False }
function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string): Boolean; overload;
function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string; out AIssues: TMimeIssueList): Boolean; overload;
{ 忽略大小写查找头；缺失返回 '' }
function MimeHeaderValue(const AHeaders: TMimeHeaders; const AName: string): string;
{ Content-Type 解析；空值返回 False }
function MimeParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
{ 参数表解析（引号内分号不受影响；RFC 2231 值自动解码） }
function MimeParseParams(const AValue: string; out AParams: TMimeParams): Boolean;

{ --- 邮件特定：地址与日期 --- }

{ 解析逗号分隔地址列表（引号内逗号不受影响）；返回成功解析个数 }
function MimeParseAddressList(const AValue: string; out AAddresses: TMailAddressArray): Integer;

{ RFC 5322 域日期："Mon, 02 Jan 2006 15:04:05 +0000"（UTC） }
function MimeFormatDate(const AUnixSeconds: Int64): string;
{ 容错解析常见 RFC 5322/2822/822 日期形式；失败返回 False }
function MimeParseDate(const AValue: string; out AUnixSeconds: Int64): Boolean;

{ --- 消息级桥接（TMailMessage ↔ MIME 树） --- }

{ 序列化 TMailMessage -> RFC 5322/MIME 文本（Subject/display-name 按需
  RFC 2047 编码；头值防注入清洗 CR/LF） }
function MimeSerialize(const AMessage: TMailMessage): string;
{ 严格解析：不可解析输入抛 EMimeError }
function MimeParse(const ARaw: string): TMailMessage;
{ 容错解析：不抛异常，问题经 AIssues 上报；空输入返回 False }
function MimeTryParse(const ARaw: string; out AMessage: TMailMessage;
  out AIssues: TMimeIssueList): Boolean; overload;
function MimeTryParse(const ARaw: string; out AMessage: TMailMessage): Boolean; overload;

implementation

uses
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.time.offsetdatetime;

const
  MONTH_NAMES: array[1..12] of string =
    ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  DAY_NAMES: array[1..7] of string =
    ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

procedure PushIssue(var AIssues: TMimeIssueList; const AKind: TMimeIssueKind;
  const ADetail: string);
begin
  SetLength(AIssues, Length(AIssues) + 1);
  AIssues[High(AIssues)].Kind := AKind;
  AIssues[High(AIssues)].Detail := ADetail;
end;

function Pad2(const AValue: Integer): string;
begin
  if AValue < 10 then
    Result := '0' + IntToStr(AValue)
  else
    Result := IntToStr(AValue);
end;

{ --- 兼容转发 --- }

function MimeBase64Encode(const AData: TBytes): string;
begin
  Result := nextpas.core.mime.EncodeBase64(AData);
end;

function MimeBase64Decode(const AEncoded: string; out AData: TBytes): Boolean;
begin
  Result := nextpas.core.mime.DecodeBase64(AEncoded, AData);
end;

function MimeQuotedPrintableEncode(const AData: TBytes): string;
begin
  Result := nextpas.core.mime.EncodeQuotedPrintable(AData);
end;

function MimeQuotedPrintableDecode(const AEncoded: string; out AData: TBytes): Boolean;
begin
  Result := nextpas.core.mime.DecodeQuotedPrintable(AEncoded, AData);
end;

function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string; out AIssues: TMimeIssueList): Boolean;
begin
  Result := nextpas.core.mime.TryParseHeaders(ARaw, AHeaders, ABody, AIssues);
end;

function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string): Boolean;
var
  LIssues: TMimeIssueList;
begin
  Result := nextpas.core.mime.TryParseHeaders(ARaw, AHeaders, ABody, LIssues);
end;

function MimeHeaderValue(const AHeaders: TMimeHeaders; const AName: string): string;
begin
  Result := nextpas.core.mime.HeaderValue(AHeaders, AName);
end;

function MimeParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
begin
  Result := nextpas.core.mime.ParseContentType(AValue, ACT);
end;

function MimeParseParams(const AValue: string; out AParams: TMimeParams): Boolean;
begin
  Result := nextpas.core.mime.ParseParameters(AValue, AParams);
end;

{ --- 地址与日期（邮件特定实现，保留原语义） --- }

function MimeParseAddressList(const AValue: string; out AAddresses: TMailAddressArray): Integer;
var
  LSegStart: Integer;
  I: Integer;
  LInQuote: Boolean;
  LSeg: string;
  LAddr: TMailAddress;
begin
  Result := 0;
  AAddresses := nil;
  LInQuote := False;
  LSegStart := 1;
  for I := 1 to Length(AValue) + 1 do
  begin
    if I <= Length(AValue) then
    begin
      if AValue[I] = '"' then
      begin
        LInQuote := not LInQuote;
        Continue;
      end;
      if (AValue[I] <> ',') or LInQuote then
        Continue;
    end;
    LSeg := Trim(Copy(AValue, LSegStart, I - LSegStart));
    if LSeg <> '' then
    begin
      if TMailAddress.TryParse(LSeg, LAddr) then
      begin
        SetLength(AAddresses, Result + 1);
        AAddresses[Result] := LAddr;
        Inc(Result);
      end;
    end;
    if I > Length(AValue) then
      Break;
    LSegStart := I + 1;
  end;
end;

{ 按空白拆 token（日期解析） }
function SplitWhitespace(const AValue: string): TStringArray;
var
  LCount, I, LStart: Integer;
begin
  Result := nil;
  LCount := 0;
  LStart := 0;
  for I := 1 to Length(AValue) + 1 do
  begin
    if (I > Length(AValue)) or (AValue[I] = ' ') or (AValue[I] = #9) then
    begin
      if LStart > 0 then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := Copy(AValue, LStart, I - LStart);
        Inc(LCount);
        LStart := 0;
      end;
    end
    else if LStart = 0 then
      LStart := I;
  end;
end;

{ 时区解析：+HHMM / -HHMM / +HH:MM / GMT/UTC/UT/Z / 美军时区缩写 }
function ParseZone(const AValue: string; out ASeconds: Integer): Boolean;
var
  LVal: string;
  LSign: Integer;
  LHour, LMin: Integer;
  LDummy: Int64;
begin
  Result := False;
  ASeconds := 0;
  LVal := UpperCase(Trim(AValue));
  if (LVal = '') or (LVal = 'GMT') or (LVal = 'UT') or
     (LVal = 'UTC') or (LVal = 'Z') then
  begin
    ASeconds := 0;
    Result := True;
    Exit;
  end;
  case LVal of
    'EST': begin ASeconds := -5 * 3600; Result := True; Exit; end;
    'EDT': begin ASeconds := -4 * 3600; Result := True; Exit; end;
    'CST': begin ASeconds := -6 * 3600; Result := True; Exit; end;
    'CDT': begin ASeconds := -5 * 3600; Result := True; Exit; end;
    'MST': begin ASeconds := -7 * 3600; Result := True; Exit; end;
    'MDT': begin ASeconds := -6 * 3600; Result := True; Exit; end;
    'PST': begin ASeconds := -8 * 3600; Result := True; Exit; end;
    'PDT': begin ASeconds := -7 * 3600; Result := True; Exit; end;
  end;
  if (LVal = '') or ((LVal[1] <> '+') and (LVal[1] <> '-')) then
    Exit;
  if LVal[1] = '-' then
    LSign := -1
  else
    LSign := 1;
  LVal := Copy(LVal, 2, Length(LVal) - 1);
  if (Length(LVal) <> 4) and (Length(LVal) <> 5) then
    Exit;
  if (Length(LVal) = 5) and (LVal[3] <> ':') then
    Exit;
  if Length(LVal) = 5 then
    Delete(LVal, 3, 1);
  if not TryStrToInt(Copy(LVal, 1, 2), LDummy) then
    Exit;
  LHour := Integer(LDummy);
  if not TryStrToInt(Copy(LVal, 3, 2), LDummy) then
    Exit;
  LMin := Integer(LDummy);
  if (LHour > 23) or (LMin > 59) then
    Exit;
  ASeconds := LSign * (LHour * 3600 + LMin * 60);
  Result := True;
end;

function MonthToIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 1 to 12 do
    if AName = MONTH_NAMES[I] then
      Exit(I);
  Result := 0;
end;

function MimeFormatDate(const AUnixSeconds: Int64): string;
var
  LODT: TOffsetDateTime;
  LD: TDate;
begin
  LODT := TOffsetDateTime.FromUnixSeconds(AUnixSeconds);
  LD := LODT.GetDate;
  Result := DAY_NAMES[Ord(LD.GetDayOfWeek)] + ', ' +
    Pad2(LD.GetDay) + ' ' + MONTH_NAMES[LD.GetMonth] + ' ' +
    IntToStr(LD.GetYear) + ' ' +
    Pad2(LODT.GetHour) + ':' + Pad2(LODT.GetMinute) + ':' +
    Pad2(LODT.GetSecond) + ' +0000';
end;

function MimeParseDate(const AValue: string; out AUnixSeconds: Int64): Boolean;
var
  LTokens: TStringArray;
  LIdx: Integer;
  LDay, LMonth, LYear: Integer;
  LHour, LMin, LSec: Integer;
  LZone: Integer;
  LTimeParts: TStringArray;
  LDummy: Int64;
  LDate: TDate;
begin
  Result := False;
  AUnixSeconds := 0;
  LTokens := SplitWhitespace(Trim(AValue));
  if Length(LTokens) < 4 then
    Exit;
  LIdx := 0;
  if (LTokens[LIdx] <> '') and (LTokens[LIdx][Length(LTokens[LIdx])] = ',') then
    Inc(LIdx);
  if LIdx + 3 >= Length(LTokens) then
    Exit;
  if not TryStrToInt(LTokens[LIdx], LDummy) then
    Exit;
  LDay := Integer(LDummy);
  LMonth := MonthToIndex(LTokens[LIdx + 1]);
  if LMonth = 0 then
    Exit;
  if not TryStrToInt(LTokens[LIdx + 2], LDummy) then
    Exit;
  LYear := Integer(LDummy);
  if LYear < 100 then
  begin
    if LYear < 70 then
      LYear := 2000 + LYear
    else
      LYear := 1900 + LYear;
  end;
  LHour := 0;
  LMin := 0;
  LSec := 0;
  LTimeParts := SplitWhitespace(StringReplace(LTokens[LIdx + 3], ':', ' ', True));
  if (Length(LTimeParts) < 2) or (Length(LTimeParts) > 3) then
    Exit;
  if not TryStrToInt(LTimeParts[0], LDummy) then
    Exit;
  LHour := Integer(LDummy);
  if not TryStrToInt(LTimeParts[1], LDummy) then
    Exit;
  LMin := Integer(LDummy);
  if Length(LTimeParts) = 3 then
  begin
    if not TryStrToInt(LTimeParts[2], LDummy) then
      Exit;
    LSec := Integer(LDummy);
  end;
  if (LHour > 23) or (LMin > 59) or (LSec > 60) then
    Exit;
  LZone := 0;
  if LIdx + 4 < Length(LTokens) then
    if not ParseZone(LTokens[LIdx + 4], LZone) then
      Exit;
  if not TDate.TryCreate(LYear, LMonth, LDay, LDate) then
    Exit;
  AUnixSeconds := Int64(LDate.ToUnixDays) * 86400 +
    LHour * 3600 + LMin * 60 + LSec - LZone;
  Result := True;
end;

{ --- 消息桥接：TMailMessage → MIME 树 --- }

{ 正文行 CRLF 归一化（容忍 LF / CR） }
function NormalizeCrlf(const AText: string): string;
var
  LOut: TBufStringBuilder;
  I: Integer;
begin
  LOut.Init(Length(AText) + 16);
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = #10 then
    begin
      LOut.AppendStr(#13#10);
      Inc(I);
    end
    else if AText[I] = #13 then
    begin
      LOut.AppendStr(#13#10);
      Inc(I);
      if (I <= Length(AText)) and (AText[I] = #10) then
        Inc(I);
    end
    else
    begin
      LOut.AppendChar(AText[I]);
      Inc(I);
    end;
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

{ 单地址格式化：display-name 非 ASCII 时 RFC 2047 编码（INV-A4/2047 接入） }
function FormatMailAddress(const AAddr: TMailAddress): string;
begin
  if AAddr.DisplayName <> '' then
    Result := '"' + EncodeHeaderText(AAddr.DisplayName) + '" <' + AAddr.Full + '>'
  else
    Result := AAddr.Full;
end;

{ 地址列表格式化（逗号连接） }
function FormatAddressList(const AList: TMailAddressArray): string;
var
  I: Integer;
begin
  if Length(AList) = 0 then
    Exit('');
  Result := FormatMailAddress(AList[0]);
  for I := 1 to Length(AList) - 1 do
    Result := Result + ', ' + FormatMailAddress(AList[I]);
end;

procedure AppendTreeHeader(var ATree: TMimeMessage; const AName, AValue: string);
begin
  if AValue = '' then
    Exit;
  SetLength(ATree.Headers, Length(ATree.Headers) + 1);
  ATree.Headers[High(ATree.Headers)].Name := AName;
  ATree.Headers[High(ATree.Headers)].Value := AValue;
end;

{ 文本部件（QP 传输编码，正文 CRLF 归一化） }
function MakeTextPart(const AContentType, ABody: string): TMimePart;
begin
  Result := Default(TMimePart);
  Result.ContentType := AContentType;
  Result.ContentTransferEncoding := ENC_QUOTED_PRINTABLE;
  Result.Body := StringToUTF8Bytes(NormalizeCrlf(ABody));
end;

{ 附件部件（base64；ContentId 存在 → inline + Content-ID 头） }
function MakeAttachmentPart(const AAtt: TMailAttachment): TMimePart;
var
  LFileName: string;
begin
  LFileName := AAtt.FileName;
  if LFileName = '' then
    LFileName := 'unnamed';
  Result := Default(TMimePart);
  if AAtt.ContentType <> '' then
    Result.ContentType := LowerCase(AAtt.ContentType)
  else
    Result.ContentType := MEDIA_APPLICATION_OCTET;
  Result.ContentTransferEncoding := ENC_BASE64;
  SetLength(Result.DispositionParams, 1);
  Result.DispositionParams[0].Name := PARAM_FILENAME;
  Result.DispositionParams[0].Value := LFileName;
  if AAtt.ContentId <> '' then
  begin
    Result.Disposition := DISPOSITION_INLINE;
    SetLength(Result.Headers, 1);
    Result.Headers[0].Name := 'Content-ID';
    Result.Headers[0].Value := '<' + SanitizeHeaderValue(AAtt.ContentId) + '>';
  end
  else
    Result.Disposition := DISPOSITION_ATTACHMENT;
  Result.Body := AAtt.Data;
end;

function MimeSerialize(const AMessage: TMailMessage): string;
var
  LTree: TMimeMessage;
  LBodyPart: TMimePart;
  LHasAlternative: Boolean;
  LHasMixed: Boolean;
  LBytes: TBytes;
  I: Integer;
begin
  LTree := Default(TMimeMessage);

  { 顶层头（字段语义在 mail 层；语法与 2047 编码经 mime） }
  if AMessage.From.LocalPart <> '' then
    AppendTreeHeader(LTree, 'From', FormatMailAddress(AMessage.From));
  AppendTreeHeader(LTree, 'To', FormatAddressList(AMessage.ToList));
  AppendTreeHeader(LTree, 'Cc', FormatAddressList(AMessage.CcList));
  AppendTreeHeader(LTree, 'Reply-To', FormatAddressList(AMessage.ReplyToList));
  AppendTreeHeader(LTree, 'Subject', EncodeHeaderText(AMessage.Subject));
  if AMessage.DateUtc <> 0 then
    AppendTreeHeader(LTree, 'Date', MimeFormatDate(AMessage.DateUtc));
  if AMessage.MessageId <> '' then
    AppendTreeHeader(LTree, 'Message-ID',
      '<' + SanitizeHeaderValue(AMessage.MessageId) + '>');

  { 根部件：mixed(alternative|单文本 + 附件) > alternative > 单 html > 单文本 }
  LHasAlternative := (AMessage.BodyText <> '') and (AMessage.BodyHtml <> '');
  LHasMixed := Length(AMessage.Attachments) > 0;

  if LHasMixed then
  begin
    LTree.Root := Default(TMimePart);
    LTree.Root.ContentType := MEDIA_MULTIPART_MIXED;
    if LHasAlternative then
    begin
      LBodyPart := Default(TMimePart);
      LBodyPart.ContentType := MEDIA_MULTIPART_ALTERNATIVE;
      SetLength(LBodyPart.Children, 2);
      LBodyPart.Children[0] := MakeTextPart(MEDIA_TEXT_PLAIN, AMessage.BodyText);
      LBodyPart.Children[1] := MakeTextPart(MEDIA_TEXT_HTML, AMessage.BodyHtml);
    end
    else if AMessage.BodyHtml <> '' then
      LBodyPart := MakeTextPart(MEDIA_TEXT_HTML, AMessage.BodyHtml)
    else
      LBodyPart := MakeTextPart(MEDIA_TEXT_PLAIN, AMessage.BodyText);
    SetLength(LTree.Root.Children, 1 + Length(AMessage.Attachments));
    LTree.Root.Children[0] := LBodyPart;
    for I := 0 to Length(AMessage.Attachments) - 1 do
      LTree.Root.Children[1 + I] := MakeAttachmentPart(AMessage.Attachments[I]);
  end
  else if LHasAlternative then
  begin
    LTree.Root := Default(TMimePart);
    LTree.Root.ContentType := MEDIA_MULTIPART_ALTERNATIVE;
    SetLength(LTree.Root.Children, 2);
    LTree.Root.Children[0] := MakeTextPart(MEDIA_TEXT_PLAIN, AMessage.BodyText);
    LTree.Root.Children[1] := MakeTextPart(MEDIA_TEXT_HTML, AMessage.BodyHtml);
  end
  else if AMessage.BodyHtml <> '' then
    LTree.Root := MakeTextPart(MEDIA_TEXT_HTML, AMessage.BodyHtml)
  else
    LTree.Root := MakeTextPart(MEDIA_TEXT_PLAIN, AMessage.BodyText);

  LBytes := BuildMessage(LTree);
  Result := UTF8BytesToString(LBytes);
end;

{ --- 消息桥接：MIME 树 → TMailMessage --- }

{ 部件附件文件名：disposition filename → content-type name → '' }
function PartFileName(const APart: TMimePart): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(APart.DispositionParams) - 1 do
    if LowerCase(APart.DispositionParams[I].Name) = PARAM_FILENAME then
      Exit(APart.DispositionParams[I].Value);
  for I := 0 to Length(APart.ContentTypeParams) - 1 do
    if LowerCase(APart.ContentTypeParams[I].Name) = PARAM_FILENAME then
      Exit(APart.ContentTypeParams[I].Value);
end;

{ 部件 Content-ID（去 <>） }
function PartContentId(const APart: TMimePart): string;
var
  LValue: string;
begin
  LValue := MimeHeaderValue(APart.Headers, 'content-id');
  if (Length(LValue) >= 2) and (LValue[1] = '<') and
     (LValue[Length(LValue)] = '>') then
    Result := Copy(LValue, 2, Length(LValue) - 2)
  else
    Result := Trim(LValue);
end;

{ 摊平一棵部件树到摊平模型（DFS 先序；首个 text/plain → BodyText、
  首个 text/html → BodyHtml、其余非 attachment-text 与 attachment → 附件） }
procedure FlattenTree(const APart: TMimePart; var AMessage: TMailMessage);
var
  I: Integer;
  LIsText: Boolean;
  LAtt: TMailAttachment;
begin
  if Copy(LowerCase(APart.ContentType), 1, 10) = 'multipart/' then
  begin
    for I := 0 to Length(APart.Children) - 1 do
      FlattenTree(APart.Children[I], AMessage);
    Exit;
  end;

  LIsText := Copy(LowerCase(APart.ContentType), 1, 5) = 'text/';
  if LIsText and (APart.Disposition <> DISPOSITION_ATTACHMENT) then
  begin
    if LowerCase(APart.ContentType) = MEDIA_TEXT_HTML then
    begin
      if AMessage.BodyHtml = '' then
        AMessage.BodyHtml := UTF8BytesToString(APart.Body);
    end
    else if AMessage.BodyText = '' then
      AMessage.BodyText := UTF8BytesToString(APart.Body);
  end
  else
  begin
    LAtt := Default(TMailAttachment);
    LAtt.ContentType := LowerCase(APart.ContentType);
    if LAtt.ContentType = '' then
      LAtt.ContentType := MEDIA_APPLICATION_OCTET;
    LAtt.ContentId := PartContentId(APart);
    LAtt.Data := APart.Body;
    LAtt.FileName := PartFileName(APart);
    SetLength(AMessage.Attachments, Length(AMessage.Attachments) + 1);
    AMessage.Attachments[High(AMessage.Attachments)] := LAtt;
  end;
end;

function MimeTryParse(const ARaw: string; out AMessage: TMailMessage;
  out AIssues: TMimeIssueList): Boolean;
var
  LTree: TMimeMessage;
  LTreeIssues: TMimeIssueArray;
  LValue: string;
  LAddrList: TMailAddressArray;
begin
  Result := False;
  AMessage := Default(TMailMessage);
  SetLength(AIssues, 0);
  if not nextpas.core.mime.TryParseMessage(StringToUTF8Bytes(ARaw), LTree, LTreeIssues) then
    Exit;
  AIssues := LTreeIssues;

  { 头字段语义（mail 层） }
  LValue := MimeHeaderValue(LTree.Headers, 'from');
  if LValue <> '' then
  begin
    MimeParseAddressList(LValue, LAddrList);
    if Length(LAddrList) > 0 then
      AMessage.From := LAddrList[0]
    else
      PushIssue(AIssues, miBadAddress, 'from: ' + LValue);
  end;

  LValue := MimeHeaderValue(LTree.Headers, 'to');
  if LValue <> '' then
    MimeParseAddressList(LValue, AMessage.ToList);
  LValue := MimeHeaderValue(LTree.Headers, 'cc');
  if LValue <> '' then
    MimeParseAddressList(LValue, AMessage.CcList);
  LValue := MimeHeaderValue(LTree.Headers, 'reply-to');
  if LValue <> '' then
    MimeParseAddressList(LValue, AMessage.ReplyToList);

  { Subject：RFC 2047 解码（ASCII 原样） }
  AMessage.Subject := DecodeHeaderText(MimeHeaderValue(LTree.Headers, 'subject'));

  LValue := MimeHeaderValue(LTree.Headers, 'message-id');
  if (Length(LValue) >= 2) and (LValue[1] = '<') and
     (LValue[Length(LValue)] = '>') then
    AMessage.MessageId := Copy(LValue, 2, Length(LValue) - 2)
  else
    AMessage.MessageId := Trim(LValue);

  LValue := MimeHeaderValue(LTree.Headers, 'date');
  if LValue <> '' then
    if not MimeParseDate(LValue, AMessage.DateUtc) then
      PushIssue(AIssues, miBadDate, LValue);

  { 正文摊平 }
  FlattenTree(LTree.Root, AMessage);
  AMessage.HasAttachments := Length(AMessage.Attachments) > 0;
  Result := True;
end;

function MimeTryParse(const ARaw: string; out AMessage: TMailMessage): Boolean;
var
  LIssues: TMimeIssueList;
begin
  Result := MimeTryParse(ARaw, AMessage, LIssues);
end;

function MimeParse(const ARaw: string): TMailMessage;
var
  LIssues: TMimeIssueList;
begin
  if not MimeTryParse(ARaw, Result, LIssues) then
    raise EMimeError.Create('invalid mime message');
end;

end.