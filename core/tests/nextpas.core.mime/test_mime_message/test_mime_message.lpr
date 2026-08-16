program test_mime_message;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.mime;

function MB(const S: string): TBytes;
begin
  Result := StringToUTF8Bytes(S);
end;

function StrFromBytes(const B: TBytes): string;
begin
  Result := UTF8BytesToString(B);
end;

function RepeatCh(const C: AnsiChar; const ACount: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 1 to ACount do
    Result[I] := C;
end;

procedure CheckPart(const APart: TMimePart; const AContentType, ABody: string);
begin
  CheckEqual(AContentType, APart.ContentType, 'content type');
  CheckEqual(ABody, StrFromBytes(APart.Body), 'body');
end;

procedure TestParseSingleText;
var
  M: TMimeMessage;
begin
  M := ParseMessage(MB('From: a@b.com' + #13#10 + #13#10 + 'just text'));
  CheckEqual('text/plain', M.Root.ContentType, 'default text/plain');
  CheckEqual('just text', StrFromBytes(M.Root.Body), 'body');
  CheckEqual(0, Length(M.Root.Children), 'no children');
  CheckEqual(1, Length(M.Headers), 'from header kept');
end;

procedure TestParseSingleHtml;
var
  M: TMimeMessage;
begin
  M := ParseMessage(MB('Content-Type: text/html; charset=utf-8' + #13#10 + #13#10 +
    '<p>x</p>'));
  CheckEqual('text/html', M.Root.ContentType, 'html type');
  CheckEqual('<p>x</p>', StrFromBytes(M.Root.Body), 'html body');
end;

procedure TestParseTransferDecoding;
var
  M: TMimeMessage;
begin
  M := ParseMessage(MB(
    'Content-Type: text/plain' + #13#10 +
    'Content-Transfer-Encoding: base64' + #13#10 + #13#10 +
    'aGVsbG8='));
  CheckEqual('hello', StrFromBytes(M.Root.Body), 'base64 decoded');
end;

procedure TestParseMultipartAlternative;
var
  M: TMimeMessage;
begin
  M := ParseMessage(MB(
    'Content-Type: multipart/alternative; boundary="alt"' + #13#10 + #13#10 +
    '--alt' + #13#10 +
    'Content-Type: text/plain' + #13#10 + #13#10 +
    'plain' + #13#10 +
    '--alt' + #13#10 +
    'Content-Type: text/html' + #13#10 + #13#10 +
    '<b>html</b>' + #13#10 +
    '--alt--' + #13#10));
  Check(M.Root.ContentType = 'multipart/alternative', 'root multipart');
  CheckEqual(2, Length(M.Root.Children), 'two children');
  CheckPart(M.Root.Children[0], 'text/plain', 'plain');
  CheckPart(M.Root.Children[1], 'text/html', '<b>html</b>');
end;

procedure TestParseMultipartMixedAttachment;
var
  M: TMimeMessage;
begin
  M := ParseMessage(MB(
    'Content-Type: multipart/mixed; boundary="mix"' + #13#10 + #13#10 +
    '--mix' + #13#10 +
    'Content-Type: text/plain' + #13#10 + #13#10 +
    'text' + #13#10 +
    '--mix' + #13#10 +
    'Content-Type: application/octet-stream; name="a.bin"' + #13#10 +
    'Content-Disposition: attachment; filename="a.bin"' + #13#10 +
    'Content-Transfer-Encoding: base64' + #13#10 + #13#10 +
    'AAECAwQ=' + #13#10 +
    '--mix--' + #13#10));
  CheckEqual(2, Length(M.Root.Children), 'two children');
  CheckEqual('application/octet-stream', M.Root.Children[1].ContentType, 'att type');
  CheckEqual('attachment', M.Root.Children[1].Disposition, 'att disposition');
  CheckEqual(5, Length(M.Root.Children[1].Body), 'att bytes');
  CheckEqual(0, M.Root.Children[1].Body[0], 'first byte');
end;

procedure TestParseNested;
var
  M: TMimeMessage;
begin
  M := ParseMessage(MB(
    'Content-Type: multipart/mixed; boundary="out"' + #13#10 + #13#10 +
    '--out' + #13#10 +
    'Content-Type: multipart/alternative; boundary="in"' + #13#10 + #13#10 +
    '--in' + #13#10 +
    'Content-Type: text/plain' + #13#10 + #13#10 +
    'inner' + #13#10 +
    '--in--' + #13#10 +
    '--out' + #13#10 +
    'Content-Type: image/png' + #13#10 + #13#10 +
    'PNGDATA' + #13#10 +
    '--out--' + #13#10));
  CheckEqual(2, Length(M.Root.Children), 'outer children');
  CheckEqual(1, Length(M.Root.Children[0].Children), 'inner alternative child');
  CheckEqual('text/plain', M.Root.Children[0].Children[0].ContentType, 'inner type');
end;

procedure TestParseMissingBoundaryRaises;
var
  MRaised: Boolean;
begin
  MRaised := False;
  try
    ParseMessage(MB('Content-Type: multipart/mixed' + #13#10 + #13#10 + 'x'));
  except
    on E: EMimeParseError do
      MRaised := True;
  end;
  Check(MRaised, 'missing boundary raises EMimeParseError');

  MRaised := False;
  try
    ParseMessage(MB('Content-Type: multipart/mixed; boundary="bad_bc;char"' + #13#10 +
      #13#10 + 'x'));
  except
    on E: EMimeParseError do
      MRaised := True;
  end;
  Check(MRaised, 'invalid boundary raises EMimeParseError');
end;

procedure TestParseTruncatedTolerant;
var
  M: TMimeMessage;
  Iss: TMimeIssueArray;
begin
  Check(TryParseMessage(MB(
    'Content-Type: multipart/alternative; boundary="t"' + #13#10 + #13#10 +
    '--t' + #13#10 +
    'Content-Type: text/plain' + #13#10 + #13#10 +
    'surviving' + #13#10), M, Iss), 'tolerant parses');
  CheckEqual(1, Length(Iss), 'one issue');
  Check(Iss[0].Kind = miTruncatedMultipart, 'kind truncated');
  CheckEqual(1, Length(M.Root.Children), 'child produced');
end;

procedure TestParseBadBase64StrictRaises;
var
  MRaised: Boolean;
begin
  MRaised := False;
  try
    ParseMessage(MB('Content-Type: text/plain' + #13#10 +
      'Content-Transfer-Encoding: base64' + #13#10 + #13#10 + '###'));
  except
    on E: EMimeParseError do
      MRaised := True;
  end;
  Check(MRaised, 'strict base64 bad raises');
end;

procedure TestParseBadBase64Tolerant;
var
  M: TMimeMessage;
  Iss: TMimeIssueArray;
begin
  Check(TryParseMessage(MB('Content-Type: text/plain' + #13#10 +
    'Content-Transfer-Encoding: base64' + #13#10 + #13#10 + '###'), M, Iss),
    'tolerant parses');
  CheckEqual(1, Length(Iss), 'one issue');
  Check(Iss[0].Kind = miBadEncoding, 'kind bad encoding');
  CheckEqual('###', StrFromBytes(M.Root.Body), 'raw kept');
end;

procedure TestParseUnknownEncodingRaises;
var
  MRaised: Boolean;
begin
  MRaised := False;
  try
    ParseMessage(MB('Content-Type: text/plain' + #13#10 +
      'Content-Transfer-Encoding: x-weird' + #13#10 + #13#10 + 'x'));
  except
    on E: EMimeParseError do
      MRaised := True;
  end;
  Check(MRaised, 'unknown encoding raises');
end;

procedure TestParseSizeLimit;
var
  LBig: TBytes;
  MRaised: Boolean;
begin
  SetLength(LBig, 100);
  FillChar(LBig[0], 100, Byte('a'));
  MRaised := False;
  try
    ParseMessage(LBig, 50);
  except
    on E: EMimeLimitError do
      MRaised := True;
  end;
  Check(MRaised, 'size limit raises EMimeLimitError');
end;

procedure TestParseDepthLimit;
var
  LRaw: string;
  I: Integer;
  M: TMimeMessage;
  Iss: TMimeIssueArray;
  LStrictRaised: Boolean;
begin
  { 40 层嵌套 multipart：严格路径用 8 做上限；容错路径默认 32 也必然触发 miTooDeep }
  LRaw := '';
  for I := 1 to 40 do
    LRaw := LRaw + 'Content-Type: multipart/mixed; boundary="b' + IntToStr(I) +
      '"' + #13#10 + #13#10 +
      '--b' + IntToStr(I) + #13#10;
  LRaw := LRaw + 'Content-Type: text/plain' + #13#10 + #13#10 + 'deep' + #13#10;
  for I := 40 downto 1 do
    LRaw := LRaw + '--b' + IntToStr(I) + '--' + #13#10;

  LStrictRaised := False;
  try
    ParseMessage(MB(LRaw), 67108864, 8);
  except
    on E: EMimeLimitError do
      LStrictRaised := True;
  end;
  Check(LStrictRaised, 'strict depth limit raises EMimeLimitError');

  Check(TryParseMessage(MB(LRaw), M, Iss), 'tolerant depth limit parses');
  Check(Length(Iss) > 0, 'tolerant reports issue');
  Check(Iss[0].Kind = miTooDeep, 'tolerant reports too deep');
end;

procedure TestBuildRoundTrip;
var
  LTree, LBack: TMimeMessage;
begin
  LTree := Default(TMimeMessage);
  SetLength(LTree.Headers, 1);
  LTree.Headers[0].Name := 'From';
  LTree.Headers[0].Value := 'alice@example.com';
  LTree.Root := Default(TMimePart);
  LTree.Root.ContentType := MEDIA_MULTIPART_MIXED;
  SetLength(LTree.Root.Children, 2);
  LTree.Root.Children[0] := Default(TMimePart);
  LTree.Root.Children[0].ContentType := MEDIA_TEXT_PLAIN;
  LTree.Root.Children[0].Body := MB('plain body');
  LTree.Root.Children[1] := Default(TMimePart);
  LTree.Root.Children[1].ContentType := MEDIA_APPLICATION_OCTET;
  LTree.Root.Children[1].Disposition := DISPOSITION_ATTACHMENT;
  LTree.Root.Children[1].Body := MB('data');

  LBack := ParseMessage(BuildMessage(LTree));
  Check(Length(LBack.Headers) >= 1, 'top header preserved');
  CheckEqual('alice@example.com', HeaderValue(LBack.Headers, 'From'), 'from value');
  CheckEqual(2, Length(LBack.Root.Children), 'children round-trip');
  CheckEqual('plain body', StrFromBytes(LBack.Root.Children[0].Body), 'text body');
  CheckEqual('data', StrFromBytes(LBack.Root.Children[1].Body), 'att body');
  CheckEqual('attachment', LBack.Root.Children[1].Disposition, 'att disposition');
end;

procedure TestBuildBoundaryValid;
var
  B: string;
  I: Integer;
begin
  for I := 1 to 5 do
  begin
    B := GenerateBoundary;
    Check(IsValidBoundary(B), 'boundary valid');
    Check(Length(B) <= 70, 'boundary length');
  end;
  Check(IsValidBoundary('ok-1._b'), 'valid chars accepted');
  Check(not IsValidBoundary('has space'), 'space rejected');
  Check(not IsValidBoundary(''), 'empty rejected');
  Check(not IsValidBoundary(RepeatCh('a', 71)), 'too long rejected');
end;

procedure TestEncodeTransfer;
begin
  CheckEqual('aGVsbG8=', StrFromBytes(EncodeTransferEncoding(ENC_BASE64, MB('hello'))),
    'base64 encode');
  CheckEqual('hello', StrFromBytes(EncodeTransferEncoding(ENC_7BIT, MB('hello'))),
    '7bit passthrough');
  CheckEqual('hello', StrFromBytes(EncodeTransferEncoding('', MB('hello'))),
    'empty passthrough');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.mime.message');
  T.Test('ParseSingleText', @TestParseSingleText);
  T.Test('ParseSingleHtml', @TestParseSingleHtml);
  T.Test('ParseTransferDecoding', @TestParseTransferDecoding);
  T.Test('ParseMultipartAlternative', @TestParseMultipartAlternative);
  T.Test('ParseMultipartMixedAttachment', @TestParseMultipartMixedAttachment);
  T.Test('ParseNested', @TestParseNested);
  T.Test('ParseMissingBoundaryRaises', @TestParseMissingBoundaryRaises);
  T.Test('ParseTruncatedTolerant', @TestParseTruncatedTolerant);
  T.Test('ParseBadBase64StrictRaises', @TestParseBadBase64StrictRaises);
  T.Test('ParseBadBase64Tolerant', @TestParseBadBase64Tolerant);
  T.Test('ParseUnknownEncodingRaises', @TestParseUnknownEncodingRaises);
  T.Test('ParseSizeLimit', @TestParseSizeLimit);
  T.Test('ParseDepthLimit', @TestParseDepthLimit);
  T.Test('BuildRoundTrip', @TestBuildRoundTrip);
  T.Test('BuildBoundaryValid', @TestBuildBoundaryValid);
  T.Test('EncodeTransfer', @TestEncodeTransfer);
  if not T.Run then
    Halt(1);
end.