unit nextpas.core.mail.mime;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail MIME 编解码（L2）。
 * TMailMessage <-> RFC 5322/MIME 文本：头解析/序列化、base64 与
 * quoted-printable、multipart/mixed、multipart/alternative 解析与组装。
 * 解析容错：畸形输入（缺头、坏编码、缺 CRLF、截断 multipart）不崩溃，
 * 问题经 TMimeIssueList 上报；要严格契约用 MimeParse（抛 EMimeError）。
 * 已知边界（后续批次）：RFC 2047 encoded-word、非 UTF-8 charset 转码、
 * RFC 2231 参数续行。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mail.base;

type
  EMimeError = class(EParseError);

  TMimeIssueKind = (
    miNone,
    miBadEncoding,               { base64/quoted-printable 解码失败，正文按原文保存 }
    miBadDate,                   { Date 头无法解析 }
    miTruncatedMultipart,        { 缺结束边界 }
    miBadHeader,                 { 无冒号头行被忽略 }
    miBadAddress,                { 地址列表中的非法地址被跳过 }
    miUnknownTransferEncoding    { 未认识的传输编码，按原文处理 }
  );

  TMimeIssue = record
    Kind: TMimeIssueKind;
    Detail: string;
  end;
  TMimeIssueList = array of TMimeIssue;

  TMimeHeader = record
    Name: string;   { 保留原始大小写；查找时忽略大小写 }
    Value: string;  { 已折叠：续行合并、去首尾空白 }
  end;
  TMimeHeaders = array of TMimeHeader;

  TMimeParam = record
    Name: string;
    Value: string;
  end;
  TMimeParams = array of TMimeParam;

  { 解析后的 Content-Type：media type 小写规范化 }
  TMimeContentType = record
  public
    MediaType: string;
    Params: TMimeParams;
    function Param(const AName: string): string;
    function CharSet: string;
    function Boundary: string;
    function Name: string;
    function IsMultipart: Boolean;
    function IsText: Boolean;
  end;

  { Content-Disposition 传真：disposition 小写规范化 }
  TMimeContentDisposition = record
  public
    Disposition: string;   { 'attachment' / 'inline' / '' }
    Params: TMimeParams;
    function Param(const AName: string): string;
    function FileName: string;
  end;

  TMailAddressArray = nextpas.core.mail.base.TMailAddressArray;

{ 编码 }

{ base64 编码，76 列 CRLF 折行（RFC 2045 §6.8） }
function MimeBase64Encode(const AData: TBytes): string;
{ base64 解码；容忍折行空白，坏输入返回 False }
function MimeBase64Decode(const AEncoded: string; out AData: TBytes): Boolean;
{ quoted-printable 编码：=XX 转义、源行尾空白编码、76 列软换行 }
function MimeQuotedPrintableEncode(const AData: TBytes): string;
{ quoted-printable 解码：软换行移除、硬换行保留并清理行尾空白；坏编码返回 False }
function MimeQuotedPrintableDecode(const AEncoded: string; out AData: TBytes): Boolean;

{ 日期 }

{ RFC 5322 域日期："Mon, 02 Jan 2006 15:04:05 +0000"（UTC） }
function MimeFormatDate(const AUnixSeconds: Int64): string;
{ 容错解析常见 RFC 5322/2822/822 日期形式；失败返回 False }
function MimeParseDate(const AValue: string; out AUnixSeconds: Int64): Boolean;

{ 头 }

{ 拆出折叠头与正文；无冒号行跳过并记 miBadHeader；输入为空返回 False }
function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string): Boolean; overload;
function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string; out AIssues: TMimeIssueList): Boolean; overload;
{ 忽略大小写查找头；缺失返回 '' }
function MimeHeaderValue(const AHeaders: TMimeHeaders; const AName: string): string;
{ 解析逗号分隔地址列表（引号内逗号不受影响）；返回成功解析个数 }
function MimeParseAddressList(const AValue: string; out AAddresses: TMailAddressArray): Integer;
function MimeParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
function MimeParseParams(const AValue: string; out AParams: TMimeParams): Boolean;

{ 消息 }

{ 序列化 TMailMessage -> RFC 5322/MIME 文本（头值防注入清洗 CR/LF） }
function MimeSerialize(const AMessage: TMailMessage): string;
{ 严格解析：不可解析输入抛 EMimeError }
function MimeParse(const ARaw: string): TMailMessage;
{ 容错解析：不抛异常，问题经 AIssues 上报；空输入返回 False }
function MimeTryParse(const ARaw: string; out AMessage: TMailMessage;
  out AIssues: TMimeIssueList): Boolean; overload;
function MimeTryParse(const ARaw: string; out AMessage: TMailMessage): Boolean; overload;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.encoding.base64,
  nextpas.core.time,
  nextpas.core.time.offsetdatetime;

const
  MIME_LINE_WRAP = 76;    { RFC 2045 编码行宽 }
  FOLD_TARGET = 76;       { 序列化头折叠列宽 }
  MONTH_NAMES: array[1..12] of string =
    ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  DAY_NAMES: array[1..7] of string =
    ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

var
  GBoundarySeq: Int64 = 0;

procedure PushIssue(var AIssues: TMimeIssueList; const AKind: TMimeIssueKind;
  const ADetail: string);
begin
  SetLength(AIssues, Length(AIssues) + 1);
  AIssues[High(AIssues)].Kind := AKind;
  AIssues[High(AIssues)].Detail := ADetail;
end;

function HexVal(const C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function Pad2(const AValue: Integer): string;
begin
  if AValue < 10 then
    Result := '0' + IntToStr(AValue)
  else
    Result := IntToStr(AValue);
end;

{ 去 CR/LF（防头注入）：序列化时头值一律清洗 }
function SanitizeHeaderValue(const AValue: string): string;
var
  I: Integer;
  LBuilder: TBufStringBuilder;
begin
  LBuilder.Init(Length(AValue));
  for I := 1 to Length(AValue) do
    if (AValue[I] = #13) or (AValue[I] = #10) then
      LBuilder.AppendChar(' ')
    else
      LBuilder.AppendChar(AValue[I]);
  Result := LBuilder.ToString;
  LBuilder.Done;
end;

{ 按空白拆 token }
function SplitWhitespace(const AValue: string): TStringArray;
var
  LCount, I: Integer;
  LStart: Integer;
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

{ TMimeContentType }

function TMimeContentType.Param(const AName: string): string;
var
  I: Integer;
begin
  for I := 0 to Length(Params) - 1 do
    if LowerCase(Params[I].Name) = LowerCase(AName) then
      Exit(Params[I].Value);
  Result := '';
end;

function TMimeContentType.CharSet: string; begin Result := Param('charset'); end;
function TMimeContentType.Boundary: string; begin Result := Param('boundary'); end;
function TMimeContentType.Name: string; begin Result := Param('name'); end;

function TMimeContentType.IsMultipart: Boolean;
begin
  Result := Copy(MediaType, 1, 10) = 'multipart/';
end;

function TMimeContentType.IsText: Boolean;
begin
  Result := Copy(MediaType, 1, 5) = 'text/';
end;

{ TMimeContentDisposition }

function TMimeContentDisposition.Param(const AName: string): string;
var
  I: Integer;
begin
  for I := 0 to Length(Params) - 1 do
    if LowerCase(Params[I].Name) = LowerCase(AName) then
      Exit(Params[I].Value);
  Result := '';
end;

function TMimeContentDisposition.FileName: string;
begin
  Result := Param('filename');
end;

{ 参数解析：分号分隔（引号内不分），值去引号/反斜杠转义 }
function MimeParseParams(const AValue: string; out AParams: TMimeParams): Boolean;
var
  I: Integer;
  LInQuote: Boolean;
  LSegStart: Integer;
  LSeg: string;
  LName: string;
  LValue: string;
  LEq: Integer;
  LJ: Integer;
begin
  Result := False;
  AParams := nil;
  LInQuote := False;
  LSegStart := 1;
  for I := 1 to Length(AValue) + 1 do
  begin
    if I <= Length(AValue) then
    begin
      if AValue[I] = '"' then
      begin
        if (I > 1) and (AValue[I - 1] = '\') and LInQuote then
          Continue
        else
          LInQuote := not LInQuote;
        Continue;
      end;
      if (AValue[I] <> ';') or LInQuote then
        Continue;
    end;
    LSeg := Trim(Copy(AValue, LSegStart, I - LSegStart));
    if LSeg <> '' then
    begin
      LEq := Pos('=', LSeg);
      if LEq > 0 then
      begin
        LName := Trim(Copy(LSeg, 1, LEq - 1));
        LValue := Trim(Copy(LSeg, LEq + 1, Length(LSeg) - LEq));
        if (Length(LValue) >= 2) and (LValue[1] = '"') and
           (LValue[Length(LValue)] = '"') then
        begin
          LValue := Copy(LValue, 2, Length(LValue) - 2);
          { 反斜杠转义：\" \\ }
          LJ := 1;
          while LJ <= Length(LValue) do
          begin
            if (LValue[LJ] = '\') and (LJ < Length(LValue)) and
               ((LValue[LJ + 1] = '"') or (LValue[LJ + 1] = '\')) then
              Delete(LValue, LJ, 1);
            Inc(LJ);
          end;
        end;
        SetLength(AParams, Length(AParams) + 1);
        AParams[High(AParams)].Name := LName;
        AParams[High(AParams)].Value := LValue;
      end
      else
      begin
        SetLength(AParams, Length(AParams) + 1);
        AParams[High(AParams)].Name := LSeg;
        AParams[High(AParams)].Value := '';
      end;
      Result := True;
    end;
    if I > Length(AValue) then
      Break;
    LSegStart := I + 1;
  end;
end;

{ Content-Type 头解析；空值返回 False }
function MimeParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
var
  LSemi: Integer;
  LMain: string;
begin
  Result := False;
  ACT := Default(TMimeContentType);
  LMain := Trim(AValue);
  if LMain = '' then
    Exit;
  LSemi := Pos(';', LMain);
  if LSemi > 0 then
  begin
    LMain := Trim(Copy(LMain, 1, LSemi - 1));
    MimeParseParams(Copy(AValue, LSemi, Length(AValue) - LSemi + 1), ACT.Params);
  end;
  ACT.MediaType := LowerCase(LMain);
  Result := ACT.MediaType <> '';
end;

{ base64：76 列硬折行 }
function MimeBase64Encode(const AData: TBytes): string;
var
  LEnc: string;
  LBuilder: TBufStringBuilder;
  I: Integer;
  LChunk: Integer;
begin
  LEnc := Base64Encode(AData);
  if LEnc = '' then
    Exit('');
  LBuilder.Init(Length(LEnc) + (Length(LEnc) div MIME_LINE_WRAP + 1) * 2);
  I := 1;
  while I <= Length(LEnc) do
  begin
    LChunk := Length(LEnc) - I + 1;
    if LChunk > MIME_LINE_WRAP then
      LChunk := MIME_LINE_WRAP;
    LBuilder.AppendStr(Copy(LEnc, I, LChunk));
    Inc(I, LChunk);
    if I <= Length(LEnc) then
      LBuilder.AppendStr(#13#10);
  end;
  Result := LBuilder.ToString;
  LBuilder.Done;
end;

{ base64：容忍折行空白；按 core 严格解码，坏输入 False }
function MimeBase64Decode(const AEncoded: string; out AData: TBytes): Boolean;
var
  I: Integer;
  LClean: TBufStringBuilder;
begin
  Result := False;
  AData := nil;
  LClean.Init(Length(AEncoded));
  for I := 1 to Length(AEncoded) do
    if not ((AEncoded[I] = ' ') or (AEncoded[I] = #9) or
            (AEncoded[I] = #13) or (AEncoded[I] = #10)) then
      LClean.AppendChar(AEncoded[I]);
  if LClean.Len = 0 then
  begin
    SetLength(AData, 0);
    LClean.Done;
    Result := True;
    Exit;
  end;
  try
    AData := Base64Decode(LClean.ToString);
    Result := True;
  except
    on E: EConvertError do
      Result := False;
  end;
  LClean.Done;
end;

{ quoted-printable 编码。
  源行尾空白编码 =20/=09；76 列处插 '=\r\n' 软换行；源行界原样保留。 }
function MimeQuotedPrintableEncode(const AData: TBytes): string;
var
  LOut: TBufStringBuilder;
  I, J, T, K: Integer;
  LLineLen: Integer;
  LEnc: string;
begin
  LOut.Init(Length(AData) + 64);
  I := 0;
  LLineLen := 0;
  while I < Length(AData) do
  begin
    { 定位源行末（CR/LF 或 EOF） }
    J := I;
    while (J < Length(AData)) and (AData[J] <> 13) and (AData[J] <> 10) do
      Inc(J);
    { 行尾空白起点 }
    T := J;
    while (T > I) and ((AData[T - 1] = 32) or (AData[T - 1] = 9)) do
      Dec(T);
    K := I;
    while K < J do
    begin
      if (K >= T) and ((AData[K] = 32) or (AData[K] = 9)) then
        LEnc := '=' + IntToHex(AData[K], 2)
      else if ((AData[K] >= 33) and (AData[K] <= 60)) or
              ((AData[K] >= 62) and (AData[K] <= 126)) then
        LEnc := Chr(AData[K])
      else
        LEnc := '=' + IntToHex(AData[K], 2);
      { 超过 75 内容列则先软换行：'=' 位于第 76 列内（RFC 2045 §6.7） }
      if (LLineLen > 0) and (LLineLen + Length(LEnc) > MIME_LINE_WRAP - 1) then
      begin
        LOut.AppendChar('=');
        LOut.AppendStr(#13#10);
        LLineLen := 0;
      end;
      LOut.AppendStr(LEnc);
      Inc(LLineLen, Length(LEnc));
      Inc(K);
    end;
    if J < Length(AData) then
    begin
      if AData[J] = 13 then
      begin
        LOut.AppendByte(13);
        LOut.AppendByte(10);
        if (J + 1 < Length(AData)) and (AData[J + 1] = 10) then
          Inc(J);
      end
      else
        LOut.AppendByte(10);
      Inc(J);               { 越过换行符，指向下一行首字符 }
      LLineLen := 0;
    end
    else
      Inc(J);               { 越过最后一行结尾 }
    I := J;
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

{ quoted-printable 解码。
  软换行（'='+换行）移除；硬换行保留并清理行尾空白；坏 '=' 序列返回 False。 }
function MimeQuotedPrintableDecode(const AEncoded: string; out AData: TBytes): Boolean;
var
  LBytes: TBytes;
  LOut: TBytes;
  LOutLen: Integer;
  I: Integer;
  LHi, LLo: Integer;
begin
  Result := False;
  AData := nil;
  LBytes := StringToUTF8Bytes(AEncoded);
  SetLength(LOut, Length(LBytes));
  LOutLen := 0;
  I := 0;
  while I < Length(LBytes) do
  begin
    if (LBytes[I] = 10) or (LBytes[I] = 13) then
    begin
      { 行尾随空白删除（RFC 2045 §6.7 允许解码方删除） }
      while (LOutLen > 0) and ((LOut[LOutLen - 1] = 32) or (LOut[LOutLen - 1] = 9)) do
        Dec(LOutLen);
      if LBytes[I] = 13 then
      begin
        LOut[LOutLen] := 13;
        Inc(LOutLen);
        if (I + 1 < Length(LBytes)) and (LBytes[I + 1] = 10) then
        begin
          LOut[LOutLen] := 10;
          Inc(LOutLen);
          Inc(I, 2);
        end
        else
          Inc(I);
      end
      else
      begin
        LOut[LOutLen] := 10;
        Inc(LOutLen);
        Inc(I);
      end;
    end
    else if LBytes[I] = 61 then
    begin
      if (I + 1 < Length(LBytes)) and
         ((LBytes[I + 1] = 13) or (LBytes[I + 1] = 10)) then
      begin
        { 软换行：移除 }
        if (LBytes[I + 1] = 13) and (I + 2 < Length(LBytes)) and
           (LBytes[I + 2] = 10) then
          Inc(I, 3)
        else
          Inc(I, 2);
      end
      else if (I + 2 < Length(LBytes)) then
      begin
        LHi := HexVal(Chr(LBytes[I + 1]));
        LLo := HexVal(Chr(LBytes[I + 2]));
        if (LHi < 0) or (LLo < 0) then
          Exit(False);
        LOut[LOutLen] := Byte(LHi shl 4 or LLo);
        Inc(LOutLen);
        Inc(I, 3);
      end
      else
        Exit(False);
    end
    else
    begin
      LOut[LOutLen] := LBytes[I];
      Inc(LOutLen);
      Inc(I);
    end;
  end;
  SetLength(LOut, LOutLen);
  AData := LOut;
  Result := True;
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

{ RFC 5322 域日期格式化（UTC）。 }
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

{ 容错日期解析。
  接受 "Mon, 2 Jan 2006 15:04:05 -0700" 及变体：可无星期、日可 1-2 位、
  时间可无秒、时区可缺席（按 +0000）。 }
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
  { 跳过 "Mon," / "Monday," }
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
    { 两位年份：<70 归 2000 后，否则 1900 后 }
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
  { 时区；缺省 +0000 }
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

{ 头解析：折叠头、容错换行（CRLF / LF / 无结尾换行） }
function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string; out AIssues: TMimeIssueList): Boolean;
var
  LPos, LEnd: Integer;
  LLine: string;
  LColon: Integer;
  LLastHeader: Integer;
  LInHeaders: Boolean;
begin
  Result := False;
  AHeaders := nil;
  ABody := '';
  SetLength(AIssues, 0);
  if ARaw = '' then
    Exit;
  LPos := 1;
  LLastHeader := -1;
  LInHeaders := True;
  while LPos <= Length(ARaw) do
  begin
    LEnd := LPos;
    while (LEnd <= Length(ARaw)) and (ARaw[LEnd] <> #10) do
      Inc(LEnd);
    LLine := Copy(ARaw, LPos, LEnd - LPos);
    if (LLine <> '') and (LLine[Length(LLine)] = #13) then
      LLine := Copy(LLine, 1, Length(LLine) - 1);
    if LLine = '' then
    begin
      if LInHeaders then
      begin
        LInHeaders := False;
        ABody := Copy(ARaw, LEnd + 1, Length(ARaw) - LEnd);
      end;
    end
    else if LInHeaders then
    begin
      if (LLine[1] = ' ') or (LLine[1] = #9) then
      begin
        if LLastHeader >= 0 then
          AHeaders[LLastHeader].Value :=
            AHeaders[LLastHeader].Value + ' ' + Trim(LLine)
        else
          PushIssue(AIssues, miBadHeader, 'continuation without header: ' + LLine);
      end
      else
      begin
        LColon := Pos(':', LLine);
        if LColon > 0 then
        begin
          SetLength(AHeaders, Length(AHeaders) + 1);
          AHeaders[High(AHeaders)].Name := Trim(Copy(LLine, 1, LColon - 1));
          AHeaders[High(AHeaders)].Value :=
            Trim(Copy(LLine, LColon + 1, Length(LLine) - LColon));
          LLastHeader := High(AHeaders);
        end
        else
          PushIssue(AIssues, miBadHeader, 'missing colon: ' + LLine);
      end;
    end;
    if LEnd > Length(ARaw) then
      Break;
    LPos := LEnd + 1;
  end;
  { 无空行分隔 → 全部当头部处理，正文为空（RFC 语义） }
  Result := (Length(AHeaders) > 0) or (ABody <> '');
end;

function MimeParseHeaders(const ARaw: string; out AHeaders: TMimeHeaders;
  out ABody: string): Boolean;
var
  LIssues: TMimeIssueList;
begin
  Result := MimeParseHeaders(ARaw, AHeaders, ABody, LIssues);
end;

function MimeHeaderValue(const AHeaders: TMimeHeaders; const AName: string): string;
var
  I: Integer;
begin
  for I := 0 to Length(AHeaders) - 1 do
    if LowerCase(AHeaders[I].Name) = LowerCase(AName) then
      Exit(AHeaders[I].Value);
  Result := '';
end;

{ 地址列表：顶层逗号分割（引号内逗号不受影响），逐项容错解析 }
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

{ 组装文本部分（text/plain / text/html，QP 编码） }
function ComposeTextPart(const ABody: string; const AIsHtml: Boolean): string;
var
  LOut: TBufStringBuilder;
begin
  LOut.Init(Length(ABody) + 64);
  if AIsHtml then
    LOut.AppendStr('Content-Type: text/html; charset=utf-8' + #13#10)
  else
    LOut.AppendStr('Content-Type: text/plain; charset=utf-8' + #13#10);
  LOut.AppendStr('Content-Transfer-Encoding: quoted-printable' + #13#10);
  LOut.AppendStr(#13#10);
  LOut.AppendStr(MimeQuotedPrintableEncode(StringToUTF8Bytes(NormalizeCrlf(ABody))));
  Result := LOut.ToString;
  LOut.Done;
end;

{ 组装附件部分（base64） }
function ComposeAttachmentPart(const AAtt: TMailAttachment): string;
var
  LOut: TBufStringBuilder;
  LFileName: string;
begin
  LFileName := AAtt.FileName;
  if LFileName = '' then
    LFileName := 'unnamed';
  LOut.Init(Length(AAtt.Data) + 128);
  if AAtt.ContentType <> '' then
    LOut.AppendStr('Content-Type: ' + LowerCase(AAtt.ContentType) +
      '; name="' + SanitizeHeaderValue(LFileName) + '"' + #13#10)
  else
    LOut.AppendStr('Content-Type: application/octet-stream; name="' +
      SanitizeHeaderValue(LFileName) + '"' + #13#10);
  if AAtt.ContentId <> '' then
  begin
    LOut.AppendStr('Content-ID: <' + SanitizeHeaderValue(AAtt.ContentId) + '>' + #13#10);
    LOut.AppendStr('Content-Disposition: inline; filename="' +
      SanitizeHeaderValue(LFileName) + '"' + #13#10);
  end
  else
    LOut.AppendStr('Content-Disposition: attachment; filename="' +
      SanitizeHeaderValue(LFileName) + '"' + #13#10);
  LOut.AppendStr('Content-Transfer-Encoding: base64' + #13#10 + #13#10);
  LOut.AppendStr(MimeBase64Encode(AAtt.Data));
  Result := LOut.ToString;
  LOut.Done;
end;

{ 组装 multipart/alternative（text/plain + text/html 两个部分） }
function ComposeAlternative(const AText, AHtml: string): string;
var
  LBoundary: string;
  LOut: TBufStringBuilder;
begin
  Inc(GBoundarySeq);
  LBoundary := '=_nextpas_' + IntToHex(GetTickCount64 and $7FFFFFFF, 8) +
    '_' + IntToStr(GBoundarySeq);
  LOut.Init(Length(AText) + Length(AHtml) + 128);
  LOut.AppendStr('Content-Type: multipart/alternative; boundary="' +
    LBoundary + '"' + #13#10 + #13#10);
  LOut.AppendStr('--' + LBoundary + #13#10);
  LOut.AppendStr(ComposeTextPart(AText, False));
  LOut.AppendStr(#13#10 + '--' + LBoundary + #13#10);
  LOut.AppendStr(ComposeTextPart(AHtml, True));
  LOut.AppendStr(#13#10 + '--' + LBoundary + '--');
  Result := LOut.ToString;
  LOut.Done;
end;

{ 序列化头值并折叠（>目标列宽按空白折行，续行单空格） }
procedure AppendFoldedHeader(var AOut: TBufStringBuilder; const AName, AValue: string);
var
  LValue: string;
  LParts: TStringArray;
  LLineLen: Integer;
  I: Integer;
  LFirstLen: Integer;
begin
  LValue := SanitizeHeaderValue(AValue);
  if LValue = '' then
    Exit;
  LParts := SplitWhitespace(LValue);
  AOut.AppendStr(AName + ': ');
  LFirstLen := Length(AName) + 2;
  LLineLen := LFirstLen;
  for I := 0 to Length(LParts) - 1 do
  begin
    if (LLineLen + Length(LParts[I]) > FOLD_TARGET) and (LLineLen > LFirstLen) then
    begin
      AOut.AppendStr(#13#10 + ' ');
      LLineLen := 1;
    end
    else if I > 0 then
    begin
      AOut.AppendChar(' ');
      Inc(LLineLen);
    end;
    AOut.AppendStr(LParts[I]);
    Inc(LLineLen, Length(LParts[I]));
  end;
  AOut.AppendStr(#13#10);
end;

{ 序列化单地址头 }
procedure AppendSingleAddressHeader(var AOut: TBufStringBuilder; const AName: string;
  const AAddr: TMailAddress);
begin
  if AAddr.LocalPart = '' then
    Exit;
  AppendFoldedHeader(AOut, AName, AAddr.ToString);
end;

{ 序列化地址列表头 }
procedure AppendAddressHeader(var AOut: TBufStringBuilder; const AName: string;
  const AList: TMailAddressArray);
var
  I: Integer;
  LValue: string;
begin
  if Length(AList) = 0 then
    Exit;
  LValue := AList[0].ToString;
  for I := 1 to Length(AList) - 1 do
    LValue := LValue + ', ' + AList[I].ToString;
  AppendFoldedHeader(AOut, AName, LValue);
end;

function MimeSerialize(const AMessage: TMailMessage): string;
var
  LOut: TBufStringBuilder;
  LHasAlternative: Boolean;
  LHasMixed: Boolean;
  LInner: string;
  LBoundary: string;
  I: Integer;
begin
  LHasAlternative := (AMessage.BodyText <> '') and (AMessage.BodyHtml <> '');
  LHasMixed := Length(AMessage.Attachments) > 0;

  LOut.Init(512);
  AppendSingleAddressHeader(LOut, 'From', AMessage.From);
  AppendAddressHeader(LOut, 'To', AMessage.ToList);
  AppendAddressHeader(LOut, 'Cc', AMessage.CcList);
  AppendAddressHeader(LOut, 'Reply-To', AMessage.ReplyToList);
  AppendFoldedHeader(LOut, 'Subject', AMessage.Subject);
  if AMessage.DateUtc <> 0 then
    LOut.AppendStr('Date: ' + MimeFormatDate(AMessage.DateUtc) + #13#10);
  if AMessage.MessageId <> '' then
    LOut.AppendStr('Message-ID: <' + SanitizeHeaderValue(AMessage.MessageId) + '>' + #13#10);
  LOut.AppendStr('MIME-Version: 1.0' + #13#10);

  if LHasAlternative or LHasMixed then
  begin
    Inc(GBoundarySeq);
    LBoundary := '=_nextpas_' + IntToHex(GetTickCount64 and $7FFFFFFF, 8) +
      '_' + IntToStr(GBoundarySeq);
    if LHasMixed then
      LOut.AppendStr('Content-Type: multipart/mixed; boundary="' +
        LBoundary + '"' + #13#10 + #13#10)
    else
      LOut.AppendStr('Content-Type: multipart/alternative; boundary="' +
        LBoundary + '"' + #13#10 + #13#10);
    if LHasAlternative then
      LInner := ComposeAlternative(AMessage.BodyText, AMessage.BodyHtml)
    else if AMessage.BodyHtml <> '' then
      LInner := ComposeTextPart(AMessage.BodyHtml, True)
    else
      LInner := ComposeTextPart(AMessage.BodyText, False);
    LOut.AppendStr('--' + LBoundary + #13#10);
    LOut.AppendStr(LInner);
    for I := 0 to Length(AMessage.Attachments) - 1 do
    begin
      LOut.AppendStr(#13#10 + '--' + LBoundary + #13#10);
      LOut.AppendStr(ComposeAttachmentPart(AMessage.Attachments[I]));
    end;
    LOut.AppendStr(#13#10 + '--' + LBoundary + '--');
  end
  else if AMessage.BodyHtml <> '' then
    LOut.AppendStr(ComposeTextPart(AMessage.BodyHtml, True))
  else
    LOut.AppendStr(ComposeTextPart(AMessage.BodyText, False));

  Result := LOut.ToString;
  LOut.Done;
end;

{ 按传输编码解码部分正文；解码失败按原文并用 miBadEncoding 上报 }
procedure DecodePartBody(const AEncoding: string; const AData: string;
  out ABytes: TBytes; var AIssues: TMimeIssueList);
var
  LEnc: string;
begin
  LEnc := LowerCase(Trim(AEncoding));
  if LEnc = 'base64' then
  begin
    if MimeBase64Decode(AData, ABytes) then
      Exit;
    PushIssue(AIssues, miBadEncoding, 'base64: ' + Copy(AData, 1, 64));
    ABytes := StringToUTF8Bytes(AData);
  end
  else if LEnc = 'quoted-printable' then
  begin
    if MimeQuotedPrintableDecode(AData, ABytes) then
      Exit;
    PushIssue(AIssues, miBadEncoding, 'quoted-printable: ' + Copy(AData, 1, 64));
    ABytes := StringToUTF8Bytes(AData);
  end
  else if (LEnc = '') or (LEnc = '7bit') or (LEnc = '8bit') or
          (LEnc = 'binary') or (LEnc = 'identity') then
    ABytes := StringToUTF8Bytes(AData)
  else
  begin
    PushIssue(AIssues, miUnknownTransferEncoding, LEnc);
    ABytes := StringToUTF8Bytes(AData);
  end;
end;

{ Content-Disposition 容错解析：关键字 + 参数表 }
procedure ParseContentDisposition(const AValue: string; out ADisp: TMimeContentDisposition);
var
  LSemi: Integer;
begin
  ADisp := Default(TMimeContentDisposition);
  if Trim(AValue) = '' then
    Exit;
  LSemi := Pos(';', AValue);
  if LSemi > 0 then
    ADisp.Disposition := LowerCase(Trim(Copy(AValue, 1, LSemi - 1)))
  else
    ADisp.Disposition := LowerCase(Trim(AValue));
  MimeParseParams(AValue, ADisp.Params);
end;

{ 解码后的部分落位：text/plain→BodyText、text/html→BodyHtml、其余→附件 }
procedure AssignDecodedPart(var AMessage: TMailMessage;
  const ACT: TMimeContentType; const AEnc: string; const ADisp: TMimeContentDisposition;
  const AContentId: string; const AData: string; var AIssues: TMimeIssueList);
var
  LBytes: TBytes;
  LAtt: TMailAttachment;
  LFileName: string;
begin
  DecodePartBody(AEnc, AData, LBytes, AIssues);
  if ACT.IsText and (ADisp.Disposition <> 'attachment') then
  begin
    if ACT.MediaType = 'text/html' then
    begin
      if AMessage.BodyHtml = '' then
        AMessage.BodyHtml := UTF8BytesToString(LBytes);
    end
    else if AMessage.BodyText = '' then
      AMessage.BodyText := UTF8BytesToString(LBytes);
  end
  else
  begin
    LAtt := Default(TMailAttachment);
    LAtt.ContentType := ACT.MediaType;
    LAtt.ContentId := AContentId;
    LAtt.Data := LBytes;
    LFileName := ADisp.FileName;
    if LFileName = '' then
      LFileName := ACT.Name;
    LAtt.FileName := LFileName;
    SetLength(AMessage.Attachments, Length(AMessage.Attachments) + 1);
    AMessage.Attachments[High(AMessage.Attachments)] := LAtt;
  end;
end;

{ 边界行匹配；AClose 表示结束边界 }
function MatchBoundaryLine(const ALine, ABoundary: string; out AClose: Boolean): Boolean;
var
  S: string;
  LRest: string;
  I: Integer;
begin
  Result := False;
  AClose := False;
  S := '--' + ABoundary;
  if Copy(ALine, 1, Length(S)) <> S then
    Exit;
  LRest := Copy(ALine, Length(S) + 1, Length(ALine) - Length(S));
  if LRest = '' then
    Exit(True);
  if LRest = '--' then
  begin
    AClose := True;
    Exit(True);
  end;
  { 尾部空白容错 }
  for I := 1 to Length(LRest) do
    if (LRest[I] <> ' ') and (LRest[I] <> #9) then
      Exit;
  Result := True;
end;

{ multipart 部分正文尾部 CRLF 属于边界定界符（RFC 2046），剥离 1 个换行 }
function TrimPartTail(const AValue: string): string;
begin
  Result := AValue;
  if Length(Result) >= 2 then
  begin
    if (Result[Length(Result) - 1] = #13) and (Result[Length(Result)] = #10) then
      SetLength(Result, Length(Result) - 2)
    else if Result[Length(Result)] = #10 then
      SetLength(Result, Length(Result) - 1);
  end;
end;

{ multipart 分割：返回各部分原始文本；AClosed 表示存在结束边界 }
procedure SplitMultipart(const ABody: string; const ABoundary: string;
  out AParts: TStringArray; out AClosed: Boolean);
var
  LOut: TBufStringBuilder;
  LParts: TStringArray;
  LCount: Integer;
  LPos, LEnd: Integer;
  LLine: string;
  LClose: Boolean;
  LInPart: Boolean;
begin
  AParts := nil;
  AClosed := False;
  LInPart := False;
  LCount := 0;
  LPos := 1;
  while LPos <= Length(ABody) do
  begin
    LEnd := LPos;
    while (LEnd <= Length(ABody)) and (ABody[LEnd] <> #10) do
      Inc(LEnd);
    LLine := Copy(ABody, LPos, LEnd - LPos);
    if (LLine <> '') and (LLine[Length(LLine)] = #13) then
      LLine := Copy(LLine, 1, Length(LLine) - 1);
    if MatchBoundaryLine(LLine, ABoundary, LClose) then
    begin
      if LInPart then
      begin
        SetLength(LParts, LCount + 1);
        LParts[LCount] := TrimPartTail(LOut.ToString);
        Inc(LCount);
        AParts := LParts;
      end;
      if LClose then
      begin
        AClosed := True;
        Break;
      end;
      LInPart := True;
      LOut.Init(256);
    end
    else if LInPart then
    begin
      LOut.AppendStr(LLine);
      if LEnd <= Length(ABody) then
        LOut.AppendStr(#13#10);
    end;
    if LEnd > Length(ABody) then
      Break;
    LPos := LEnd + 1;
  end;
  if (not AClosed) and LInPart then
  begin
    { 未闭合（截断）部分仍产出，由上层报 miTruncatedMultipart }
    SetLength(LParts, LCount + 1);
    LParts[LCount] := TrimPartTail(LOut.ToString);
    AParts := LParts;
  end;
  LOut.Done;
end;

{ 递归解析 multipart 树：径向填充 BodyText/BodyHtml/Attachments }
procedure ParsePartTree(const APartRaw: string; var AMessage: TMailMessage;
  var AIssues: TMimeIssueList);
var
  LPHeaders: TMimeHeaders;
  LPBody: string;
  LPIssues: TMimeIssueList;
  LCT: TMimeContentType;
  LEnc: string;
  LDisp: TMimeContentDisposition;
  LContentId: string;
  LParts: TStringArray;
  LClosed: Boolean;
  I: Integer;
begin
  LPIssues := nil;
  MimeParseHeaders(APartRaw, LPHeaders, LPBody, LPIssues);
  for I := 0 to Length(LPIssues) - 1 do
    PushIssue(AIssues, LPIssues[I].Kind, LPIssues[I].Detail);

  if not MimeParseContentType(MimeHeaderValue(LPHeaders, 'content-type'), LCT) then
  begin
    LCT := Default(TMimeContentType);
    LCT.MediaType := 'text/plain';
  end;
  LEnc := MimeHeaderValue(LPHeaders, 'content-transfer-encoding');
  ParseContentDisposition(MimeHeaderValue(LPHeaders, 'content-disposition'), LDisp);
  LContentId := MimeHeaderValue(LPHeaders, 'content-id');
  if (Length(LContentId) >= 2) and (LContentId[1] = '<') and
     (LContentId[Length(LContentId)] = '>') then
    LContentId := Copy(LContentId, 2, Length(LContentId) - 2);

  if LCT.IsMultipart and (LCT.Boundary <> '') then
  begin
    SplitMultipart(LPBody, LCT.Boundary, LParts, LClosed);
    if not LClosed then
      PushIssue(AIssues, miTruncatedMultipart, LCT.Boundary);
    for I := 0 to Length(LParts) - 1 do
      ParsePartTree(LParts[I], AMessage, AIssues);
    Exit;
  end;

  AssignDecodedPart(AMessage, LCT, LEnc, LDisp, LContentId, LPBody, AIssues);
end;

function MimeTryParse(const ARaw: string; out AMessage: TMailMessage;
  out AIssues: TMimeIssueList): Boolean;
var
  LHeaders: TMimeHeaders;
  LBody: string;
  LValue: string;
  LCT: TMimeContentType;
  LAddrList: TMailAddressArray;
  LDisp: TMimeContentDisposition;
  LEnc: string;
  LContentId: string;
  LParts: TStringArray;
  LClosed: Boolean;
  I: Integer;
begin
  Result := False;
  AMessage := Default(TMailMessage);
  SetLength(AIssues, 0);
  if not MimeParseHeaders(ARaw, LHeaders, LBody, AIssues) then
    Exit;

  { From：取地址列表首个成功项 }
  LValue := MimeHeaderValue(LHeaders, 'from');
  if LValue <> '' then
  begin
    MimeParseAddressList(LValue, LAddrList);
    if Length(LAddrList) > 0 then
      AMessage.From := LAddrList[0]
    else
      PushIssue(AIssues, miBadAddress, 'from: ' + LValue);
  end;

  LValue := MimeHeaderValue(LHeaders, 'to');
  if LValue <> '' then
    MimeParseAddressList(LValue, AMessage.ToList);
  LValue := MimeHeaderValue(LHeaders, 'cc');
  if LValue <> '' then
    MimeParseAddressList(LValue, AMessage.CcList);
  LValue := MimeHeaderValue(LHeaders, 'reply-to');
  if LValue <> '' then
    MimeParseAddressList(LValue, AMessage.ReplyToList);

  AMessage.Subject := MimeHeaderValue(LHeaders, 'subject');
  LValue := MimeHeaderValue(LHeaders, 'message-id');
  if (Length(LValue) >= 2) and (LValue[1] = '<') and
     (LValue[Length(LValue)] = '>') then
    AMessage.MessageId := Copy(LValue, 2, Length(LValue) - 2)
  else
    AMessage.MessageId := Trim(LValue);

  LValue := MimeHeaderValue(LHeaders, 'date');
  if LValue <> '' then
    if not MimeParseDate(LValue, AMessage.DateUtc) then
      PushIssue(AIssues, miBadDate, LValue);

  if not MimeParseContentType(MimeHeaderValue(LHeaders, 'content-type'), LCT) then
  begin
    LCT := Default(TMimeContentType);
    LCT.MediaType := 'text/plain';
  end;

  { 顶层：multipart → 树；单部分 → 直接解码 }
  if LCT.IsMultipart and (LCT.Boundary <> '') then
  begin
    SplitMultipart(LBody, LCT.Boundary, LParts, LClosed);
    if not LClosed then
      PushIssue(AIssues, miTruncatedMultipart, LCT.Boundary);
    for I := 0 to Length(LParts) - 1 do
      ParsePartTree(LParts[I], AMessage, AIssues);
  end
  else
  begin
    LEnc := MimeHeaderValue(LHeaders, 'content-transfer-encoding');
    ParseContentDisposition(MimeHeaderValue(LHeaders, 'content-disposition'), LDisp);
    LContentId := MimeHeaderValue(LHeaders, 'content-id');
    if (Length(LContentId) >= 2) and (LContentId[1] = '<') and
       (LContentId[Length(LContentId)] = '>') then
      LContentId := Copy(LContentId, 2, Length(LContentId) - 2);
    AssignDecodedPart(AMessage, LCT, LEnc, LDisp, LContentId, LBody, AIssues);
  end;
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