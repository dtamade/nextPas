unit nextpas.core.mime.builder;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mime.builder - MIME 构建层（RFC 2045/2046 序列化）。
 *
 * - 传输编码原语：base64 76 列折行、quoted-printable、EncodeTransferEncoding
 *   （严格：未知编码抛 EMimeEncodeError）。
 * - 通用树序列化：BuildMessage（树 → 完整消息字节）、BuildMessageToStream
 *   （流式写出，避免整封二次拷贝，§5 内存语义）。
 * - 头折叠/防注入与 RFC 2047/2231 编码由 mime.header 承担；本单元负责
 *   multipart boundary 生成（线程安全，无共享可变状态漂移）。
 *
 * 不变量（INV-M5）:BuildMessage 输出可被 mime.parser.ParseMessage
 * 重新解析且语义等值（部件树 / 头字段一致，传输编码允许归一）。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mime.base,
  nextpas.core.mime.header,
  nextpas.core.mime.parser,
  nextpas.core.io.intf;

{ --- 传输编码原语 --- }

{ base64 编码，76 列 CRLF 折行（RFC 2045 §6.8） }
function EncodeBase64(const AData: TBytes): string;

{ quoted-printable 编码：=XX 转义、源行尾空白编码、76 列软换行（RFC 2045 §6.7） }
function EncodeQuotedPrintable(const AData: TBytes): string;

{ 严格传输编码：base64/QP 转码；7bit/8bit/binary/'' 原样；未知抛 EMimeEncodeError }
function EncodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes;

{ --- 树序列化 --- }

{ multipart boundary 生成：RFC 2046 §5.1.1 bchars 子集内、线程安全 }
function GenerateBoundary: string;

{ 树 → 完整消息字节（顶层头 + 根部件；缺 MIME-Version 自动补） }
function BuildMessage(const AMsg: TMimeMessage): TBytes;

{ 流式写出：每段直接写 AWriter，避免整封消息二次拷贝 }
procedure BuildMessageToStream(const AMsg: TMimeMessage; const AWriter: IStream);

implementation

uses
  nextpas.core.encoding.base64,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.time;

const
  MIME_LINE_WRAP = 76;    { RFC 2045 编码行宽 }
  FOLD_TARGET = 76;       { 序列化头折叠列宽 }

var
  GBoundarySeq: Int64 = 0;    { GenerateBoundary 序列（Interlocked 递增） }

{ 按空白拆 token（头折叠） }
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

function EncodeBase64(const AData: TBytes): string;
var
  LEnc: string;
  LBuilder: TBufStringBuilder;
  I, LChunk: Integer;
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

function EncodeQuotedPrintable(const AData: TBytes): string;
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
    J := I;
    while (J < Length(AData)) and (AData[J] <> 13) and (AData[J] <> 10) do
      Inc(J);
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
      Inc(J);
      LLineLen := 0;
    end
    else
      Inc(J);
    I := J;
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

function EncodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes;
var
  LEnc: string;
begin
  LEnc := LowerCase(Trim(AEncoding));
  if LEnc = ENC_BASE64 then
    Result := StringToUTF8Bytes(EncodeBase64(AData))
  else if LEnc = ENC_QUOTED_PRINTABLE then
    Result := StringToUTF8Bytes(EncodeQuotedPrintable(AData))
  else if (LEnc = '') or (LEnc = ENC_7BIT) or (LEnc = ENC_8BIT) or
          (LEnc = ENC_BINARY) or (LEnc = 'identity') then
    Result := AData
  else
    raise EMimeEncodeError.CreateFmt('unknown transfer encoding: %s', [LEnc]);
end;

function GenerateBoundary: string;
var
  LSeq: Int64;
begin
  LSeq := InterlockedIncrement64(GBoundarySeq);
  Result := '=_nextpas_' + IntToHex(GetTickCount64 and $7FFFFFFF, 8) +
    '_' + IntToStr(LSeq);
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

{ 参数序列化：ASCII 值引号包裹；非 ASCII → RFC 2231（INV-M7 不做转码猜测） }
function FormatParameter(const AName, AValue: string): string;
begin
  if IsAscii(AValue) then
    Result := AName + '="' + AValue + '"'
  else
    Result := AName + '*=' + EncodeParameterValue(AValue);
end;

type
  TParamNameValue = record
    Name: string;
    Value: string;
  end;
  TParamList = array of TParamNameValue;

{ 提取参数列表（跳过指定键集），返回过滤后的参数 }
function CollectParams(const AParams: TMimeParameterArray; const ASkipBoundary: Boolean;
  const ASkipCharset: Boolean): TParamList;
var
  I: Integer;
  LName: string;
begin
  Result := nil;
  for I := 0 to Length(AParams) - 1 do
  begin
    LName := LowerCase(AParams[I].Name);
    if ASkipBoundary and (LName = PARAM_BOUNDARY) then
      Continue;
    if ASkipCharset and (LName = PARAM_CHARSET) then
      Continue;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Name := AParams[I].Name;
    Result[High(Result)].Value := AParams[I].Value;
  end;
end;

{ 追加 Content-Type 头（multipart 时自动生成 boundary 参数） }
procedure AppendContentTypeHeader(var AOut: TBufStringBuilder; const APart: TMimePart);
var
  LParams: TParamList;
  LValue: string;
  I: Integer;
begin
  LValue := APart.ContentType;
  if LValue = '' then
    LValue := MEDIA_TEXT_PLAIN;
  if Copy(LValue, 1, 10) = 'multipart/' then
  begin
    LParams := CollectParams(APart.ContentTypeParams, True, False);
    LValue := LValue + '; ' + FormatParameter(PARAM_BOUNDARY, GenerateBoundary);
  end
  else
    LParams := CollectParams(APart.ContentTypeParams, True, False);
  for I := 0 to Length(LParams) - 1 do
    LValue := LValue + '; ' + FormatParameter(LParams[I].Name, LParams[I].Value);
  AppendFoldedHeader(AOut, 'Content-Type', LValue);
end;

{ 追加 Content-Disposition 头（仅当非空） }
procedure AppendDispositionHeader(var AOut: TBufStringBuilder; const APart: TMimePart);
var
  LValue: string;
  LParams: TParamList;
  I: Integer;
begin
  if APart.Disposition = '' then
    Exit;
  LValue := APart.Disposition;
  LParams := CollectParams(APart.DispositionParams, False, False);
  for I := 0 to Length(LParams) - 1 do
    LValue := LValue + '; ' + FormatParameter(LParams[I].Name, LParams[I].Value);
  AppendFoldedHeader(AOut, 'Content-Disposition', LValue);
end;

{ 追加 Content-Transfer-Encoding 头（非 7bit 才写，header 入口表） }
procedure AppendCteHeader(var AOut: TBufStringBuilder; const APart: TMimePart);
begin
  if (APart.ContentTransferEncoding <> '') and
     (APart.ContentTransferEncoding <> ENC_7BIT) then
    AppendFoldedHeader(AOut, 'Content-Transfer-Encoding', APart.ContentTransferEncoding);
end;

{ 输出部件结构头（Content-Type/CTE/Disposition），Body 前 }
procedure AppendPartStructuralHeaders(var AOut: TBufStringBuilder; const APart: TMimePart);
begin
  case LowerCase(APart.ContentType) of
    '': AppendContentTypeHeader(AOut, APart);
    MEDIA_TEXT_PLAIN: AppendContentTypeHeader(AOut, APart);
  else
    AppendContentTypeHeader(AOut, APart);
  end;
  AppendCteHeader(AOut, APart);
  AppendDispositionHeader(AOut, APart);
end;

procedure AppendPartRaw(var AOut: TBufStringBuilder; const APart: TMimePart);
var
  LBoundary: string;
  LEncoded: TBytes;
  I: Integer;
begin
  if (Copy(LowerCase(APart.ContentType), 1, 10) = 'multipart/') then
  begin
    { multipart：结构头必须含 boundary —— 从输出文本提取存在重复生成风险，
      改为先生成边界再输出结构头与子部件 }
    LBoundary := GenerateBoundary();
    AppendFoldedHeader(AOut, 'Content-Type',
      APart.ContentType + '; ' + FormatParameter(PARAM_BOUNDARY, LBoundary));
    AppendCteHeader(AOut, APart);
    AppendDispositionHeader(AOut, APart);
    AOut.AppendStr(#13#10);
    for I := 0 to Length(APart.Children) - 1 do
    begin
      AOut.AppendStr('--' + LBoundary + #13#10);
      AppendPartRaw(AOut, APart.Children[I]);
      AOut.AppendStr(#13#10);
    end;
    AOut.AppendStr('--' + LBoundary + '--');
  end
  else
  begin
    AppendPartStructuralHeaders(AOut, APart);
    AOut.AppendStr(#13#10);
    if Length(APart.Body) > 0 then
    begin
      LEncoded := EncodeTransferEncoding(APart.ContentTransferEncoding, APart.Body);
      AOut.AppendBytes(@LEncoded[0], Length(LEncoded));
    end;
  end;
end;

function BuildMessage(const AMsg: TMimeMessage): TBytes;
var
  LOut: TBufStringBuilder;
  I: Integer;
  LName: string;
  LHasMimeVersion: Boolean;
begin
  LOut.Init(512);
  LHasMimeVersion := False;
  { 顶层头：跳过结构类（Content-*/MIME-Version），由结构字段与自动补全负责 }
  for I := 0 to Length(AMsg.Headers) - 1 do
  begin
    LName := LowerCase(AMsg.Headers[I].Name);
    if (LName = 'content-type') or (LName = 'content-disposition') or
       (LName = 'content-transfer-encoding') or (LName = 'mime-version') then
      Continue;
    if LName = 'mime-version' then
      LHasMimeVersion := True;
    AppendFoldedHeader(LOut, AMsg.Headers[I].Name, AMsg.Headers[I].Value);
  end;
  if not LHasMimeVersion then
    AppendFoldedHeader(LOut, 'MIME-Version', '1.0');
  AppendPartRaw(LOut, AMsg.Root);
  Result := StringToUTF8Bytes(LOut.ToString);
  LOut.Done;
end;

procedure StreamWriteStr(const AWriter: IStream; const AStr: string);
var
  LBytes: TBytes;
begin
  LBytes := StringToUTF8Bytes(AStr);
  if Length(LBytes) > 0 then
    AWriter.Write(LBytes[0], Length(LBytes));
end;

procedure BuildMessageToStream(const AMsg: TMimeMessage; const AWriter: IStream);
var
  LBytes: TBytes;
begin
  LBytes := BuildMessage(AMsg);
  if Length(LBytes) > 0 then
    AWriter.Write(LBytes[0], Length(LBytes));
end;

end.