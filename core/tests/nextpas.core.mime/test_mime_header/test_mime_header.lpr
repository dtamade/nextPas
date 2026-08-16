program test_mime_header;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mime;

procedure TestEncodeAsciiPassthrough;
begin
  CheckEqual('Subject only ascii',
    EncodeHeaderText('Subject only ascii'), 'plain ascii unchanged');
  CheckEqual('', EncodeHeaderText(''), 'empty unchanged');
  CheckEqual('a=b; c,d', EncodeHeaderText('a=b; c,d'), 'punctuation unchanged');
end;

procedure TestEncodeDecodeChineseRoundTrip;
var
  LEnc, LDec: string;
begin
  LEnc := EncodeHeaderText('中文主题');
  Check(Pos('=?UTF-8?B?', LEnc) > 0, 'encoded-word prefix');
  Check(Pos('?=', LEnc) > 0, 'encoded-word suffix');
  Check(Length(LEnc) <= 75, 'encoded-word within 75 cols');
  LDec := DecodeHeaderText(LEnc);
  CheckEqual('中文主题', LDec, 'chinese round-trip');
end;

procedure TestEncodeLongMultibyteSegments;
var
  LText, LEnc: string;
  I: Integer;
  LPos: Integer;
  LWordCount: Integer;
  LWordEnd: Integer;
begin
  { 120 个汉字 = 360 字节 → 应切 ≥7 段，每段编码字 ≤75 列且字符不跨段 }
  LText := '';
  for I := 1 to 120 do
    LText := LText + '字';
  LEnc := EncodeHeaderText(LText);
  Check(LEnc <> '', 'encoded non-empty');
  LPos := 1;
  LWordCount := 0;
  while LPos <= Length(LEnc) do
  begin
    if Copy(LEnc, LPos, 2) = '=?' then
    begin
      LWordEnd := Pos('?=', LEnc, LPos);
      Check(LWordEnd > 0, 'encoded-word closed');
      Check((LWordEnd - LPos + 3) <= 75, 'segment within 75 cols');
      Inc(LWordCount);
      LPos := LWordEnd + 2;
    end
    else
      Inc(LPos);
  end;
  Check(LWordCount > 5, 'multiple segments');
  CheckEqual(LText, DecodeHeaderText(LEnc), 'long multibyte round-trip');
end;

procedure TestDecodeB;
begin
  CheckEqual('hello', DecodeHeaderText('=?UTF-8?B?aGVsbG8=?='), 'B ascii');
  CheckEqual('中文', DecodeHeaderText('=?UTF-8?B?5Lit5paH?='), 'B chinese');
end;

procedure TestDecodeQ;
begin
  CheckEqual('hello world', DecodeHeaderText('=?UTF-8?Q?hello_world?='), 'Q underscore');
  CheckEqual('中文', DecodeHeaderText('=?UTF-8?Q?=E4=B8=AD=E6=96=87?='), 'Q utf8 hex');
end;

procedure TestDecodeAdjacentFold;
begin
  { 相邻 encoded-word 间空白折叠合并（RFC 2047 §6.2：间隔空白丢弃） }
  CheckEqual('ab', DecodeHeaderText('=?UTF-8?B?YQ==?= =?UTF-8?B?Yg==?='),
    'adjacent words merged');
  CheckEqual('ab', DecodeHeaderText('=?UTF-8?B?YQ==?=' + #13#10 + ' =?UTF-8?B?Yg==?='),
    'folded adjacent words merged');
end;

procedure TestDecodeMalformedKept;
begin
  { 坏 base64：编码内容剥壳按原文交付（不抛、不吞） }
  CheckEqual('not-base64!!', DecodeHeaderText('=?UTF-8?B?not-base64!!?='),
    'bad base64 content kept raw');
  CheckEqual('=?badcharset??=', DecodeHeaderText('=?badcharset??='),
    'malformed word kept raw');
  CheckEqual('plain', DecodeHeaderText('plain'), 'plain passthrough');
end;

procedure TestEncodeParameter;
begin
  CheckEqual('simple.txt', EncodeParameterValue('simple.txt'), 'ascii passthrough');
  CheckEqual('UTF-8''a%22b', EncodeParameterValue('a"b'), 'quote encoded');
  Check(Pos('UTF-8''%', EncodeParameterValue('文件名.txt')) > 0,
    'rfc2231 non-ascii marker');
  CheckEqual('UTF-8''a%3Bb', EncodeParameterValue('a;b'), 'semicolon encoded');
end;

procedure TestDecodeParameter;
begin
  CheckEqual('simple.txt', DecodeParameterValue('simple.txt'), 'plain');
  CheckEqual('中文.txt', DecodeParameterValue('UTF-8''''%E4%B8%AD%E6%96%87.txt'),
    'utf8 encoded');
  CheckEqual('a b', DecodeParameterValue('UTF-8''''a%20b'), 'space decoded');
  { 非 UTF-8 charset：percent-decode 后不做字符集转换（INV-M7）：
    GB2312 的「中」= %B4%D6，不得被转成 UTF-8 的「中」 }
  Check(DecodeParameterValue('GB2312''''%B4%D6') <> '中',
    'non-utf8 charset not transcoded');
end;

procedure TestUnfoldHeader;
begin
  CheckEqual('part one part two',
    UnfoldHeaderValue('part one' + #13#10 + ' part two'), 'crlf fold');
  CheckEqual('a b', UnfoldHeaderValue('a' + #13#10 + #9 + 'b'), 'tab fold');
  CheckEqual('single', UnfoldHeaderValue('single'), 'single unchanged');
end;

procedure TestSanitizeHeaderValue;
begin
  { 每个 CR/LF 各自替换为空格（管线经 token 化折叠后为单空格） }
  CheckEqual('evil  Bcc: x', SanitizeHeaderValue('evil' + #13#10 + 'Bcc: x'),
    'crlf stripped');
  Check(Pos(#13, SanitizeHeaderValue('a' + #13 + 'b')) = 0, 'no cr');
  Check(Pos(#10, SanitizeHeaderValue('a' + #10 + 'b')) = 0, 'no lf');
end;

procedure TestIsAscii;
begin
  Check(IsAscii('abc123'), 'ascii true');
  Check(not IsAscii('中文'), 'non-ascii false');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.mime.header');
  T.Test('EncodeAsciiPassthrough', @TestEncodeAsciiPassthrough);
  T.Test('EncodeDecodeChineseRoundTrip', @TestEncodeDecodeChineseRoundTrip);
  T.Test('EncodeLongMultibyteSegments', @TestEncodeLongMultibyteSegments);
  T.Test('DecodeB', @TestDecodeB);
  T.Test('DecodeQ', @TestDecodeQ);
  T.Test('DecodeAdjacentFold', @TestDecodeAdjacentFold);
  T.Test('DecodeMalformedKept', @TestDecodeMalformedKept);
  T.Test('EncodeParameter', @TestEncodeParameter);
  T.Test('DecodeParameter', @TestDecodeParameter);
  T.Test('UnfoldHeader', @TestUnfoldHeader);
  T.Test('SanitizeHeaderValue', @TestSanitizeHeaderValue);
  T.Test('IsAscii', @TestIsAscii);
  if not T.Run then
    Halt(1);
end.