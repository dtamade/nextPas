unit nextpas.core.mime.header;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mime.header - 头字段语法层（RFC 2047/2231 + 折叠工具）。
 *
 * - RFC 2047 encoded-word 编解码（=?charset?B|Q?text?=，UTF-8 首要 charset，
 *   非 UTF-8 仅解码交付原样字节，不做猜测式转码，INV-M7）。
 * - RFC 2231 参数扩展编码（filename*=UTF-8''percent-encoded；多段 *N* 由
 *   解析方收集拼接，本单元提供单值编解码原语）。
 * - Unfold / 防 CRLF 注入清洗（RFC 5322 §2.2.3 与邮件头序列化安全）。
 *
 * 本单元纯函数、无全局状态（INV-M3 上限由 parser 承载）。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mime.base;

type
  { UTF-8 字节按字符边界切段的结果容器 }
  TMimeByteSegments = array of TBytes;

{ RFC 2047 编码：纯 ASCII 原文返回；否则 UTF-8 B 编码，
  按字符边界切段保证每个 encoded-word ≤ 75 列（INV 编码确定性）。
  编码失败抛 EMimeEncodeError。 }
function EncodeHeaderText(const AValue: string; const ACharset: string = 'UTF-8'): string;

{ RFC 2047 解码：识别 =?...?=，B/Q 均支持；相邻 encoded-word 间
  空白折叠合并（RFC 2047 §6.2）；非法编码序列原样保留（宽容，不抛）。 }
function DecodeHeaderText(const AValue: string): string;

{ RFC 2231 编码单值：全 ASCII 且无参数语法风险字符时原文返回；
  否则 "UTF-8''" + percent-encoded（不含 name= 前缀）。 }
function EncodeParameterValue(const AValue: string): string;

{ RFC 2231 解码单值：可带 "charset''" 前缀；percent-decode 后
  UTF-8 charset 转码，其余 charset 交付原样字节（INV-M7）。 }
function DecodeParameterValue(const AValue: string): string;

{ RFC 5322 §2.2.3 unfold：折叠（CRLF 后随 WSP）合并为单一空格 }
function UnfoldHeaderValue(const AValue: string): string;

{ 头值防注入清洗：CR/LF 一律替换为空格 }
function SanitizeHeaderValue(const AValue: string): string;

{ 判定是否全 ASCII（字节 < 128）}
function IsAscii(const AValue: string): Boolean;

implementation

uses
  nextpas.core.encoding.base64,
  nextpas.core.text.builder,
  nextpas.core.text.conv;

const
  { RFC 2047 encoded-word 行宽上限（含 =?...?= 全部字符） }
  ENCODED_WORD_MAX = 75;
  { B 编码每段源字节数：45 字节 → 60 base64 字符，
    encoded-word 总长 = 2 + charset(UTF-8=5) + 2 + 60 + 2 = 71 ≤ 75 }
  B64_SOURCE_BYTES = 45;

{ 字节是否百分编码安全字符（RFC 3986 unreserved） }
function PercentSafe(const C: AnsiChar): Boolean; inline;
begin
  Result := ((C >= 'a') and (C <= 'z')) or
            ((C >= 'A') and (C <= 'Z')) or
            ((C >= '0') and (C <= '9')) or
            (C = '-') or (C = '.') or (C = '_') or (C = '~');
end;

function HexVal(const C: AnsiChar): Integer; inline;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function IsAscii(const AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(AValue) do
    if Ord(AValue[I]) >= 128 then
      Exit(False);
  Result := True;
end;

{ UTF-8 字节按字符边界切段：加入下一字符前判界，保证 bchars 段 ≤ 上限 }
procedure SplitUtf8Segments(const ABytes: TBytes; const ABytesPerSegment: Integer;
  out ASegments: TMimeByteSegments);
var
  LSegStart, LSegEnd, LCharLen: Integer;
  I, LCount: Integer;
begin
  ASegments := nil;
  LCount := 0;
  I := 0;
  while I < Length(ABytes) do
  begin
    LSegStart := I;
    LSegEnd := I;
    while LSegEnd < Length(ABytes) do
    begin
      if ABytes[LSegEnd] < $80 then
        LCharLen := 1
      else if ABytes[LSegEnd] and $E0 = $C0 then
        LCharLen := 2
      else if ABytes[LSegEnd] and $F0 = $E0 then
        LCharLen := 3
      else
        LCharLen := 4;
      if (LSegEnd - LSegStart) + LCharLen > ABytesPerSegment then
        Break;                        { 加入会超界 → 本段到此为止 }
      Inc(LSegEnd, LCharLen);
    end;
    if LSegEnd = LSegStart then
      Inc(LSegEnd, 1);                { 防御：畸形字节强制前进 }
    SetLength(ASegments, LCount + 1);
    SetLength(ASegments[LCount], LSegEnd - LSegStart);
    Move(ABytes[LSegStart], ASegments[LCount][0], LSegEnd - LSegStart);
    Inc(LCount);
    I := LSegEnd;
  end;
end;

function EncodeHeaderText(const AValue: string; const ACharset: string = 'UTF-8'): string;
var
  LBytes: TBytes;
  LSegments: TMimeByteSegments;
  LWord: string;
  LOut: TBufStringBuilder;
  I: Integer;
begin
  if AValue = '' then
    Exit('');
  if IsAscii(AValue) then
    Exit(AValue);        { 纯 ASCII 无需 encoded-word（超长折叠属序列化层） }

  LBytes := StringToUTF8Bytes(AValue);
  SplitUtf8Segments(LBytes, B64_SOURCE_BYTES, LSegments);
  LOut.Init(Length(AValue) + Length(LSegments) * 16);
  for I := 0 to Length(LSegments) - 1 do
  begin
    LWord := '=?' + ACharset + '?B?' + Base64Encode(LSegments[I]) + '?=';
    if Length(LWord) > ENCODED_WORD_MAX then
      raise EMimeEncodeError.CreateFmt(
        'encoded-word exceeds %d chars: charset=%s bytes=%d',
        [ENCODED_WORD_MAX, ACharset, Length(LSegments[I])]);
    if I > 0 then
      LOut.AppendChar(' ');
    LOut.AppendStr(LWord);
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

{ Q 编码文本解码：=XX 十六进制 + '_'→空格（RFC 2047 §4.2），其余原样 }
function QDecodeSegment(const AText: string): TBytes;
var
  LOut: TBytes;
  LOutLen, I, LHi, LLo: Integer;
begin
  SetLength(LOut, Length(AText));
  LOutLen := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = '_' then
    begin
      LOut[LOutLen] := Ord(' ');
      Inc(LOutLen);
      Inc(I);
    end
    else if (AText[I] = '=') and (I + 2 <= Length(AText)) then
    begin
      LHi := HexVal(AText[I + 1]);
      LLo := HexVal(AText[I + 2]);
      if (LHi < 0) or (LLo < 0) then
      begin
        LOut[LOutLen] := Ord(AText[I]);
        Inc(LOutLen);
        Inc(I);
      end
      else
      begin
        LOut[LOutLen] := Byte(LHi shl 4 or LLo);
        Inc(LOutLen);
        Inc(I, 3);
      end;
    end
    else
    begin
      LOut[LOutLen] := Ord(AText[I]);
      Inc(LOutLen);
      Inc(I);
    end;
  end;
  SetLength(LOut, LOutLen);
  Result := LOut;
end;

function BytesToRawString(const ABytes: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(ABytes));
  for I := 0 to Length(ABytes) - 1 do
    Result[I + 1] := Chr(ABytes[I]);
end;

function DecodeHeaderText(const AValue: string): string;
var
  LOut: TBufStringBuilder;
  LPos, LQ1, LEnd: Integer;
  LCharset, LEncKind, LEncText: string;
  LBytes: TBytes;
  LDecoded: Boolean;
begin
  if AValue = '' then
    Exit('');
  LOut.Init(Length(AValue));
  LPos := 1;
  while LPos <= Length(AValue) do
  begin
    LDecoded := False;
    { 尝试匹配 =?charset?B|Q?text?= }
    if (AValue[LPos] = '=') and (LPos + 1 <= Length(AValue)) and
       (AValue[LPos + 1] = '?') then
    begin
      LQ1 := LPos + 2;
      LCharset := '';
      while (LQ1 <= Length(AValue)) and (AValue[LQ1] <> '?') do
      begin
        LCharset := LCharset + AValue[LQ1];
        Inc(LQ1);
      end;
      if (LQ1 + 2 <= Length(AValue)) then
      begin
        LEncKind := AValue[LQ1 + 1];
        if ((LEncKind = 'B') or (LEncKind = 'b') or
            (LEncKind = 'Q') or (LEncKind = 'q')) and
           (AValue[LQ1 + 2] = '?') then
        begin
          LEnd := LQ1 + 3;
          while (LEnd + 1 <= Length(AValue)) and
                not ((AValue[LEnd] = '?') and (AValue[LEnd + 1] = '=')) do
            Inc(LEnd);
          if (LEnd + 1 <= Length(AValue)) then
          begin
            LEncText := Copy(AValue, LQ1 + 3, LEnd - LQ1 - 3);
            if (LEncKind = 'B') or (LEncKind = 'b') then
            begin
              try
                LBytes := Base64Decode(LEncText);
              except
                on E: EConvertError do
                  LBytes := StringToUTF8Bytes(LEncText);
              end;
            end
            else
              LBytes := QDecodeSegment(LEncText);
            LOut.AppendStr(BytesToRawString(LBytes));
            LPos := LEnd + 2;
            { 相邻 encoded-word 的间隔线性空白折叠（RFC 2047 §6.2） }
            while (LPos <= Length(AValue)) and
                  ((AValue[LPos] = ' ') or (AValue[LPos] = #9) or
                   (AValue[LPos] = #13) or (AValue[LPos] = #10)) do
              Inc(LPos);
            LDecoded := True;
          end;
        end;
      end;
    end;
    if not LDecoded then
    begin
      LOut.AppendChar(AValue[LPos]);
      Inc(LPos);
    end;
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

{ RFC 2231 编码：值中非 ASCII 与结构化字符百分编码 }
function EncodeParameterValue(const AValue: string): string;
var
  LBytes: TBytes;
  LOut: TBufStringBuilder;
  I: Integer;
  LNeedEncode: Boolean;
begin
  LNeedEncode := False;
  for I := 1 to Length(AValue) do
    if (Ord(AValue[I]) >= 128) or
       (AValue[I] = '"') or (AValue[I] = ';') or (AValue[I] = '\') or
       (AValue[I] = '=') then
    begin
      LNeedEncode := True;
      Break;
    end;
  if not LNeedEncode then
    Exit(AValue);

  LBytes := StringToUTF8Bytes(AValue);
  LOut.Init(Length(LBytes) * 3 + 8);
  LOut.AppendStr('UTF-8''');
  for I := 0 to Length(LBytes) - 1 do
  begin
    if PercentSafe(AnsiChar(LBytes[I])) then
      LOut.AppendByte(LBytes[I])
    else
      LOut.AppendStr('%' + IntToHex(LBytes[I], 2));
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

{ RFC 2231 解码：剥离 "charset''" 前缀，percent-decode，UTF-8 转码 }
function DecodeParameterValue(const AValue: string): string;
var
  LEq: Integer;
  LCharset, LEncoded: string;
  LBytes: TBytes;
  LOutLen, I, LHi, LLo: Integer;
begin
  if AValue = '' then
    Exit('');
  LEq := Pos('''', AValue);
  if (LEq > 1) and (LEq + 1 <= Length(AValue)) and (AValue[LEq + 1] = '''') then
  begin
    LCharset := Copy(AValue, 1, LEq - 1);
    LEncoded := Copy(AValue, LEq + 2, Length(AValue) - LEq - 1);
  end
  else
  begin
    LCharset := '';
    LEncoded := AValue;
  end;

  SetLength(LBytes, Length(LEncoded));
  LOutLen := 0;
  I := 1;
  while I <= Length(LEncoded) do
  begin
    if (LEncoded[I] = '%') and (I + 2 <= Length(LEncoded)) then
    begin
      LHi := HexVal(LEncoded[I + 1]);
      LLo := HexVal(LEncoded[I + 2]);
      if (LHi >= 0) and (LLo >= 0) then
      begin
        LBytes[LOutLen] := Byte(LHi shl 4 or LLo);
        Inc(LOutLen);
        Inc(I, 3);
        Continue;
      end;
    end;
    LBytes[LOutLen] := Ord(LEncoded[I]);
    Inc(LOutLen);
    Inc(I);
  end;
  SetLength(LBytes, LOutLen);

  if (LCharset = '') or (LowerCase(LCharset) = 'utf-8') or
     (LowerCase(LCharset) = 'utf8') then
    Result := UTF8BytesToString(LBytes)
  else
    Result := BytesToRawString(LBytes);
end;

function UnfoldHeaderValue(const AValue: string): string;
var
  LOut: TBufStringBuilder;
  I: Integer;
begin
  LOut.Init(Length(AValue));
  I := 1;
  while I <= Length(AValue) do
  begin
    if (AValue[I] = #13) or (AValue[I] = #10) then
    begin
      while (I <= Length(AValue)) and
            ((AValue[I] = #13) or (AValue[I] = #10) or
             (AValue[I] = ' ') or (AValue[I] = #9)) do
        Inc(I);
      if LOut.Len > 0 then
        LOut.AppendChar(' ');
    end
    else
    begin
      LOut.AppendChar(AValue[I]);
      Inc(I);
    end;
  end;
  Result := LOut.ToString;
  LOut.Done;
end;

function SanitizeHeaderValue(const AValue: string): string;
var
  LOut: TBufStringBuilder;
  I: Integer;
begin
  LOut.Init(Length(AValue));
  for I := 1 to Length(AValue) do
    if (AValue[I] = #13) or (AValue[I] = #10) then
      LOut.AppendChar(' ')
    else
      LOut.AppendChar(AValue[I]);
  Result := LOut.ToString;
  LOut.Done;
end;

end.