unit nextpas.core.mime.parser;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mime.parser - MIME 解析层（RFC 2045/2046 严格 + 容错双通道）。
 *
 * 严格通道（Parse*）:语法/结构违规一律抛 EMimeParseError/EMimeLimitError，
 * 不允许宽容吞错产出物化结果（INV-M1/INV-M3/INV-M6）。
 * 容错通道（Try*）:不抛异常，问题经 TMimeIssueArray 上报（供 SMTP 收信等
 * 边界入口的统一捕获，问题列表即诊断）。
 *
 * 输出为通用 MIME 树（TMimeMessage.Root → TMimePart.Children）；类型
 * 语义解码（地址/日期/消息模型摊平）归 nextpas.core.mail 层。
 * 本单元输入为字节（TBytes），内部行扫描按 UTF-8 字符串完成（拷贝一次，
 * 非热路径；消息级解析一次一封）。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mime.base,
  nextpas.core.mime.header;

type
  { 容错通道问题类型（mail 层扩展 mi* 邮件语义问题） }
  TMimeIssueKind = (
    miNone,
    miBadEncoding,               { base64/quoted-printable 解码失败，正文按原文保存 }
    miBadDate,                   { Date 头无法解析（mail 层产生） }
    miTruncatedMultipart,        { 缺结束边界 }
    miBadHeader,                 { 无冒号头行被忽略 }
    miBadAddress,                { 地址列表中的非法地址被跳过（mail 层产生） }
    miUnknownTransferEncoding,   { 未认识的传输编码，按原文处理 }
    miTooDeep                    { 嵌套深度超限，该分支截断（INV-M3） }
  );

  TMimeIssue = record
    Kind: TMimeIssueKind;
    Detail: string;
  end;
  TMimeIssueArray = array of TMimeIssue;

  { multipart 子部件原始文本列表 }
  TMimeRawPartArray = array of string;

  { 解析后的 MIME 部件（树节点） }
  TMimePart = record
    Headers: TMimeHeaderArray;       { 部件头（Name 原样，检索大小写不敏感） }
    ContentType: string;             { 小写；缺省 MEDIA_TEXT_PLAIN }
    ContentTypeParams: TMimeParameterArray;  { 原参数表（含 boundary；2231 已解码） }
    ContentTransferEncoding: string; { 小写；缺省 ENC_7BIT }
    Disposition: string;             { 小写；'' | attachment | inline }
    DispositionParams: TMimeParameterArray;  { 原参数表（如 filename；2231 已解码） }
    Body: TBytes;                    { 传输解码后内容；multipart/* 时为空 }
    Children: array of TMimePart;    { multipart 子部件 }
  end;

  { 解析后的完整 MIME 消息 }
  TMimeMessage = record
    Headers: TMimeHeaderArray;       { 顶层头 }
    Root: TMimePart;                 { 根部件（可为 multipart 树） }
  end;

{ --- 头 / 结构化字段 --- }

{ 严格头解析：无冒号行/空输入等违规抛 EMimeParseError；正文在首个空行后 }
function ParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string): Boolean;

{ 容错头解析：问题经 AIssues 上报；输入为空返回 False }
function TryParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string; out AIssues: TMimeIssueArray): Boolean; overload;

{ 参数表解析（分号分隔、引号内不分；值去引号/反斜杠转义；
  带 * 后缀（RFC 2231）参数值自动解码为 UTF-8；至少一个参数才返回 True） }
function ParseParameters(const AValue: string; out AParams: TMimeParameterArray): Boolean;

{ Content-Type 解析；空值返回 False；media type 小写归一 }
function ParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;

{ Content-Disposition 解析；disposition 小写归一 }
procedure ParseContentDisposition(const AValue: string; out ADisp: TMimeContentDisposition);

{ 忽略大小写查找头；缺失返回 '' }
function HeaderValue(const AHeaders: TMimeHeaderArray; const AName: string): string;

{ --- 传输解码 --- }

{ base64 解码：容忍折行空白/坏填充，坏输入返回 False（原语，供容错通道） }
function DecodeBase64(const AEncoded: string; out AData: TBytes): Boolean;

{ quoted-printable 解码：软换行移除、硬换行保留并清理行尾空白；坏编码返回 False }
function DecodeQuotedPrintable(const AEncoded: string; out AData: TBytes): Boolean;

{ 严格传输解码：base64/QP 坏输入与未知编码抛 EMimeParseError；
  7bit/8bit/binary/identity/'' 原样返回 }
function DecodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes;

{ --- 消息树解析 --- }

{ 严格解析：语法/结构违规抛 EMime*；超限抛 EMimeLimitError（INV-M3） }
function ParseMessage(const AData: TBytes;
  const AMaxBytes: Int64 = 67108864;
  const AMaxDepth: Integer = 32): TMimeMessage;

{ 容错解析：不抛异常，问题经 AIssues 上报；空输入返回 False }
function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AIssues: TMimeIssueArray): Boolean; overload;

{ 容错解析：错误摘要串（逗号连接问题 Detail；为空即成功） }
function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AError: string): Boolean; overload;

{ RFC 2046 §5.1.1 boundary 合法性（≤70 字符、bchars 子集） }
function IsValidBoundary(const ABoundary: string): Boolean;

implementation

uses
  nextpas.core.encoding.base64,
  nextpas.core.text.builder,
  nextpas.core.text.conv;

const
  { bchars（RFC 2046 §5.1.1）：digits/alpha/指定标点 }
  BOUNDARY_MAX_LEN = 70;

procedure PushIssue(var AIssues: TMimeIssueArray; const AKind: TMimeIssueKind;
  const ADetail: string);
begin
  SetLength(AIssues, Length(AIssues) + 1);
  AIssues[High(AIssues)].Kind := AKind;
  AIssues[High(AIssues)].Detail := ADetail;
end;

function HexValChar(const C: AnsiChar): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function IsBoundaryChar(const C: AnsiChar): Boolean;
begin
  Result := ((C >= '0') and (C <= '9')) or
            ((C >= 'a') and (C <= 'z')) or
            ((C >= 'A') and (C <= 'Z')) or
            (C = '''') or (C = '(') or (C = ')') or (C = '+') or
            (C = '_') or (C = ',') or (C = '-') or (C = '.') or
            (C = '/') or (C = ':') or (C = '=') or (C = '?');
end;

function IsValidBoundary(const ABoundary: string): Boolean;
var
  I: Integer;
begin
  if (ABoundary = '') or (Length(ABoundary) > BOUNDARY_MAX_LEN) then
    Exit(False);
  for I := 1 to Length(ABoundary) do
    if not IsBoundaryChar(ABoundary[I]) then
      Exit(False);
  Result := True;
end;

{ 按空白拆 token（头折叠/日期解析共用） }
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

{ --- 参数 / Content-Type / Disposition --- }

{ 单段 RFC 2231 解码应用：原名 name*（或 name*N*）的存储键归一到 name，
  值经 DecodeParameterValue。多段 *N* 拼接基线：单段优先，
  多段由调用方（本函数）逐段解码后覆盖——邮件现实世界以单段为主
  （INV-M7 不做 charset 猜测）。 }
function ParseParameters(const AValue: string; out AParams: TMimeParameterArray): Boolean;
var
  I: Integer;
  LInQuote: Boolean;
  LSegStart: Integer;
  LSeg: string;
  LName: string;
  LValue: string;
  LEq: Integer;
  LJ: Integer;
  LStarPos: Integer;
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
          LJ := 1;
          while LJ <= Length(LValue) do
          begin
            if (LValue[LJ] = '\') and (LJ < Length(LValue)) and
               ((LValue[LJ + 1] = '"') or (LValue[LJ + 1] = '\')) then
              Delete(LValue, LJ, 1);
            Inc(LJ);
          end;
        end;
        { RFC 2231:name* 或 name*N* → 键归一 name，值解码 }
        LStarPos := Pos('*', LName);
        if LStarPos > 0 then
        begin
          LName := Copy(LName, 1, LStarPos - 1) +
                   Copy(LName, LStarPos + 1, Length(LName) - LStarPos);
          if LName = '' then
            LName := 'ext';       { 防御：纯星号名兜底 }
          LValue := DecodeParameterValue(LValue);
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

function ParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
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
    ParseParameters(Copy(AValue, LSemi, Length(AValue) - LSemi + 1), ACT.Params);
  end;
  ACT.MediaType := LowerCase(LMain);
  Result := ACT.MediaType <> '';
end;

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
  ParseParameters(AValue, ADisp.Params);
end;

{ --- 头解析 --- }

function TryParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string; out AIssues: TMimeIssueArray): Boolean;
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
  Result := (Length(AHeaders) > 0) or (ABody <> '');
end;

function ParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string): Boolean;
var
  LIssues: TMimeIssueArray;
  I: Integer;
begin
  Result := TryParseHeaders(ARaw, AHeaders, ABody, LIssues);
  if not Result then
    raise EMimeParseError.Create('empty message headers');
  for I := 0 to Length(LIssues) - 1 do
    raise EMimeParseError.Create('invalid header line: ' + LIssues[I].Detail);
end;

function HeaderValue(const AHeaders: TMimeHeaderArray; const AName: string): string;
var
  I: Integer;
begin
  for I := 0 to Length(AHeaders) - 1 do
    if LowerCase(AHeaders[I].Name) = LowerCase(AName) then
      Exit(AHeaders[I].Value);
  Result := '';
end;

{ --- 传输解码原语（容错） --- }

function BytesToRawString(const ABytes: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(ABytes));
  for I := 0 to Length(ABytes) - 1 do
    Result[I + 1] := Chr(ABytes[I]);
end;

function DecodeBase64(const AEncoded: string; out AData: TBytes): Boolean;
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

function DecodeQuotedPrintable(const AEncoded: string; out AData: TBytes): Boolean;
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
        if (LBytes[I + 1] = 13) and (I + 2 < Length(LBytes)) and
           (LBytes[I + 2] = 10) then
          Inc(I, 3)
        else
          Inc(I, 2);
      end
      else if (I + 2 < Length(LBytes)) then
      begin
        LHi := HexValChar(Chr(LBytes[I + 1]));
        LLo := HexValChar(Chr(LBytes[I + 2]));
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

function DecodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes;
var
  LEnc: string;
begin
  LEnc := LowerCase(Trim(AEncoding));
  if LEnc = ENC_BASE64 then
  begin
    if not DecodeBase64(BytesToRawString(AData), Result) then
      raise EMimeParseError.Create('invalid base64 body');
  end
  else if LEnc = ENC_QUOTED_PRINTABLE then
  begin
    if not DecodeQuotedPrintable(BytesToRawString(AData), Result) then
      raise EMimeParseError.Create('invalid quoted-printable body');
  end
  else if (LEnc = '') or (LEnc = ENC_7BIT) or (LEnc = ENC_8BIT) or
          (LEnc = ENC_BINARY) or (LEnc = 'identity') then
    Result := AData
  else
    raise EMimeParseError.Create('unknown transfer encoding: ' + LEnc);
end;

function BytesToStr(const ABytes: TBytes): string;
begin
  Result := UTF8BytesToString(ABytes);
end;

{ 合成根部件 raw：顶层 content-* 头 + 空行 + 正文（根实体头归属消息头）。
  其余头（From/To/Subject 等）是消息字段语义，不属于部件语法树。 }
function ComposePartRaw(const AHeaders: TMimeHeaderArray; const ABody: string): string;
var
  LOut: TBufStringBuilder;
  I: Integer;
  LName: string;
begin
  LOut.Init(Length(ABody) + 64);
  for I := 0 to Length(AHeaders) - 1 do
  begin
    LName := LowerCase(Trim(AHeaders[I].Name));
    if (LName = 'content-type') or (LName = 'content-transfer-encoding') or
       (LName = 'content-disposition') or (LName = 'content-id') then
      LOut.AppendStr(AHeaders[I].Name + ': ' + AHeaders[I].Value + #13#10);
  end;
  LOut.AppendStr(#13#10);
  LOut.AppendStr(ABody);
  Result := LOut.ToString;
  LOut.Done;
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
  out AParts: TMimeRawPartArray; out AClosed: Boolean);
var
  LOut: TBufStringBuilder;
  LPartList: array of string;
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
  LOut := Default(TBufStringBuilder);
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
        SetLength(LPartList, LCount + 1);
        LPartList[LCount] := TrimPartTail(LOut.ToString);
        Inc(LCount);
        AParts := Copy(LPartList);
        { 每个 part 一个 Init；先释放上一个缓冲再 Init，否则重复
          Init 覆盖 FBuf 指针导致缓冲区泄漏（CA-016 配对纪律） }
        LOut.Done;
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
    SetLength(LPartList, LCount + 1);
    LPartList[LCount] := TrimPartTail(LOut.ToString);
    AParts := Copy(LPartList);
  end;
  LOut.Done;
end;

{ --- 树解析 --- }

{ 解析单部件原始文本 → 树节点（严格） }
procedure ParsePartTreeStrict(const APartRaw: string; const ADepth: Integer;
  const AMaxDepth: Integer; out APart: TMimePart);
var
  LPHeaders: TMimeHeaderArray;
  LPBody: string;
  LCT: TMimeContentType;
  LEnc: string;
  LDisp: TMimeContentDisposition;
  LParts: array of string;
  LClosed: Boolean;
  I: Integer;
  LChild: TMimePart;
begin
  APart := Default(TMimePart);
  ParseHeaders(APartRaw, LPHeaders, LPBody);
  APart.Headers := LPHeaders;

  LEnc := HeaderValue(LPHeaders, 'content-transfer-encoding');
  APart.ContentTransferEncoding := LowerCase(Trim(LEnc));
  ParseContentDisposition(HeaderValue(LPHeaders, 'content-disposition'), LDisp);
  APart.Disposition := LDisp.Disposition;
  APart.DispositionParams := LDisp.Params;

  if not ParseContentType(HeaderValue(LPHeaders, 'content-type'), LCT) then
  begin
    LCT := Default(TMimeContentType);
    LCT.MediaType := MEDIA_TEXT_PLAIN;
  end;
  APart.ContentType := LCT.MediaType;
  APart.ContentTypeParams := LCT.Params;

  if LCT.IsMultipart then
  begin
    if (LCT.Boundary = '') or (not IsValidBoundary(LCT.Boundary)) then
      raise EMimeParseError.Create('multipart missing or invalid boundary');
    if ADepth + 1 > AMaxDepth then
      raise EMimeLimitError.CreateFmt(
        'multipart nesting exceeds depth limit %d', [AMaxDepth]);
    SplitMultipart(LPBody, LCT.Boundary, LParts, LClosed);
    if not LClosed then
      raise EMimeParseError.Create('multipart missing closing boundary');
    for I := 0 to Length(LParts) - 1 do
    begin
      ParsePartTreeStrict(LParts[I], ADepth + 1, AMaxDepth, LChild);
      SetLength(APart.Children, Length(APart.Children) + 1);
      APart.Children[High(APart.Children)] := LChild;
    end;
  end
  else
    APart.Body := DecodeTransferEncoding(APart.ContentTransferEncoding,
      StringToUTF8Bytes(LPBody));
end;

{ 解析单部件原始文本 → 树节点（容错）}
procedure ParsePartTreeTolerant(const APartRaw: string; const ADepth: Integer;
  const AMaxDepth: Integer; out APart: TMimePart; var AIssues: TMimeIssueArray);
var
  LPHeaders: TMimeHeaderArray;
  LPBody: string;
  LPIssues: TMimeIssueArray;
  LCT: TMimeContentType;
  LEnc: string;
  LDisp: TMimeContentDisposition;
  LParts: array of string;
  LClosed: Boolean;
  LChild: TMimePart;
  LOK: Boolean;
  I: Integer;
begin
  APart := Default(TMimePart);
  TryParseHeaders(APartRaw, LPHeaders, LPBody, LPIssues);
  for I := 0 to Length(LPIssues) - 1 do
    PushIssue(AIssues, LPIssues[I].Kind, LPIssues[I].Detail);
  APart.Headers := LPHeaders;

  LEnc := HeaderValue(LPHeaders, 'content-transfer-encoding');
  APart.ContentTransferEncoding := LowerCase(Trim(LEnc));
  ParseContentDisposition(HeaderValue(LPHeaders, 'content-disposition'), LDisp);
  APart.Disposition := LDisp.Disposition;
  APart.DispositionParams := LDisp.Params;

  if not ParseContentType(HeaderValue(LPHeaders, 'content-type'), LCT) then
  begin
    LCT := Default(TMimeContentType);
    LCT.MediaType := MEDIA_TEXT_PLAIN;
  end;
  APart.ContentType := LCT.MediaType;
  APart.ContentTypeParams := LCT.Params;

  if LCT.IsMultipart and (LCT.Boundary <> '') then
  begin
    if ADepth + 1 > AMaxDepth then
    begin
      PushIssue(AIssues, miTooDeep, 'multipart depth limit ' + IntToStr(AMaxDepth));
      Exit;
    end;
    SplitMultipart(LPBody, LCT.Boundary, LParts, LClosed);
    if not LClosed then
      PushIssue(AIssues, miTruncatedMultipart, LCT.Boundary);
    for I := 0 to Length(LParts) - 1 do
    begin
      ParsePartTreeTolerant(LParts[I], ADepth + 1, AMaxDepth, LChild, AIssues);
      SetLength(APart.Children, Length(APart.Children) + 1);
      APart.Children[High(APart.Children)] := LChild;
    end;
    Exit;
  end;

  { 非 multipart：传输解码（容错） }
  LOK := True;
  if APart.ContentTransferEncoding = ENC_BASE64 then
    LOK := DecodeBase64(LPBody, APart.Body)
  else if APart.ContentTransferEncoding = ENC_QUOTED_PRINTABLE then
    LOK := DecodeQuotedPrintable(LPBody, APart.Body)
  else if (APart.ContentTransferEncoding = '') or
          (APart.ContentTransferEncoding = ENC_7BIT) or
          (APart.ContentTransferEncoding = ENC_8BIT) or
          (APart.ContentTransferEncoding = ENC_BINARY) then
    APart.Body := StringToUTF8Bytes(LPBody)
  else
  begin
    PushIssue(AIssues, miUnknownTransferEncoding, APart.ContentTransferEncoding);
    APart.Body := StringToUTF8Bytes(LPBody);
  end;
  if not LOK then
  begin
    PushIssue(AIssues, miBadEncoding,
      APart.ContentTransferEncoding + ': ' + Copy(LPBody, 1, 64));
    APart.Body := StringToUTF8Bytes(LPBody);
  end;
end;

function ParseMessage(const AData: TBytes;
  const AMaxBytes: Int64 = 67108864;
  const AMaxDepth: Integer = 32): TMimeMessage;
var
  LHeaders: TMimeHeaderArray;
  LBody: string;
  LRoot: TMimePart;
begin
  if Length(AData) = 0 then
    raise EMimeParseError.Create('empty message');
  if Length(AData) > AMaxBytes then
    raise EMimeLimitError.CreateFmt(
      'message size %d exceeds limit %d', [Length(AData), AMaxBytes]);
  Result := Default(TMimeMessage);
  ParseHeaders(BytesToStr(AData), LHeaders, LBody);
  Result.Headers := LHeaders;
  ParsePartTreeStrict(ComposePartRaw(LHeaders, LBody), 1, AMaxDepth, LRoot);
  Result.Root := LRoot;
end;

function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AIssues: TMimeIssueArray): Boolean;
var
  LHeaders: TMimeHeaderArray;
  LBody: string;
  LRoot: TMimePart;
begin
  Result := False;
  AMsg := Default(TMimeMessage);
  SetLength(AIssues, 0);
  if Length(AData) = 0 then
    Exit;
  if not TryParseHeaders(BytesToStr(AData), LHeaders, LBody, AIssues) then
    Exit;
  AMsg.Headers := LHeaders;
  ParsePartTreeTolerant(ComposePartRaw(LHeaders, LBody), 1, MIME_DEFAULT_MAX_DEPTH,
    LRoot, AIssues);
  AMsg.Root := LRoot;
  Result := True;
end;

function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AError: string): Boolean;
var
  LIssues: TMimeIssueArray;
  LBuilder: TBufStringBuilder;
  I: Integer;
begin
  Result := TryParseMessage(AData, AMsg, LIssues);
  AError := '';
  if Result then
    Exit;
  LBuilder.Init(64);
  for I := 0 to Length(LIssues) - 1 do
  begin
    if LBuilder.Len > 0 then
      LBuilder.AppendChar(',');
    LBuilder.AppendStr(LIssues[I].Detail);
  end;
  AError := LBuilder.ToString;
  LBuilder.Done;
end;

end.