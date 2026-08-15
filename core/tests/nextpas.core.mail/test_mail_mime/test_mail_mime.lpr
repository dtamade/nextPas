program test_mail_mime;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.mail,
  nextpas.core.mail.mime;

function StrBytes(const S: string): TBytes;
begin
  Result := StringToUTF8Bytes(S);
end;

function BytesToStr(const B: TBytes): string;
begin
  Result := UTF8BytesToString(B);
end;

{ 独立地址数组（动态数组赋值共享引用，逐次构造避免串写） }
function MakeList(const AAddrs: array of string): TMailAddressArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AAddrs));
  for I := 0 to Length(AAddrs) - 1 do
    Result[I] := TMailAddress.Parse(AAddrs[I]);
end;

{ 最长行宽（不含行尾 CRLF） }
function MaxLineLen(const S: string): Integer;
var
  I: Integer;
  LRun: Integer;
begin
  Result := 0;
  LRun := 0;
  for I := 1 to Length(S) do
  begin
    if S[I] = #10 then
    begin
      if LRun > Result then
        Result := LRun;
      LRun := 0;
    end
    else if S[I] <> #13 then
      Inc(LRun);
  end;
  if LRun > Result then
    Result := LRun;
end;

procedure TestHeaderParseBasic;
var
  HRaw: string;
  H: TMimeHeaders;
  B: string;
begin
  HRaw := 'From: alice@example.com' + #13#10 +
          'To: bob@example.com' + #13#10 +
          'Subject: hello' + #13#10 +
          'Date: Mon, 02 Jan 2006 15:04:05 +0000' + #13#10 +
          'Message-ID: <abc@example.com>' + #13#10 + #13#10 +
          'body line';
  Check(MimeParseHeaders(HRaw, H, B), 'headers parse ok');
  CheckEqual('alice@example.com', MimeHeaderValue(H, 'From'), 'from');
  CheckEqual('bob@example.com', MimeHeaderValue(H, 'To'), 'to');
  CheckEqual('hello', MimeHeaderValue(H, 'Subject'), 'subject');
  CheckEqual('Mon, 02 Jan 2006 15:04:05 +0000', MimeHeaderValue(H, 'Date'), 'date');
  CheckEqual('<abc@example.com>', MimeHeaderValue(H, 'Message-ID'), 'message-id');
  CheckEqual('body line', B, 'body split');
  CheckEqual(5, Length(H), 'five headers');
end;

procedure TestHeaderCaseInsensitive;
var
  H: TMimeHeaders;
  B: string;
begin
  Check(MimeParseHeaders('from: a@b.com' + #13#10 + 'SUBJECT: x' + #13#10 +
    #13#10 + 'b', H, B), 'parse');
  CheckEqual('a@b.com', MimeHeaderValue(H, 'FROM'), 'upper lookup');
  CheckEqual('x', MimeHeaderValue(H, 'subject'), 'lower lookup');
  CheckEqual('', MimeHeaderValue(H, 'missing'), 'missing returns empty');
end;

procedure TestHeaderFolding;
var
  H: TMimeHeaders;
  B: string;
begin
  Check(MimeParseHeaders('Subject: part one' + #13#10 + '  part two' + #13#10 +
    'X-Ext: a' + #13#10 + #9 + 'tab' + #13#10 + #13#10, H, B), 'parse folded');
  CheckEqual('part one part two', MimeHeaderValue(H, 'Subject'),
    'continuation folded with single space');
  CheckEqual('a tab', MimeHeaderValue(H, 'X-Ext'), 'tab continuation trimmed');
end;

procedure TestHeaderMissingCrlf;
var
  H: TMimeHeaders;
  B: string;
begin
  { 裸 LF + 无结尾换行的最后一行 }
  Check(MimeParseHeaders('From: a@b.com'#10'To: c@d.com'#10#10'body', H, B),
    'bare LF headers');
  CheckEqual('a@b.com', MimeHeaderValue(H, 'From'), 'from');
  CheckEqual('body', B, 'body');
  { 无空行分隔：全当头处理 }
  Check(MimeParseHeaders('From: a@b.com', H, B), 'no separator');
  CheckEqual('', B, 'no body');
end;

procedure TestHeaderMissingColon;
var
  H: TMimeHeaders;
  B: string;
  Iss: TMimeIssueList;
begin
  Check(MimeParseHeaders('garbage line' + #13#10 + 'From: a@b.com' + #13#10 +
    #13#10 + 'b', H, B, Iss), 'parse with bad line');
  CheckEqual(1, Length(H), 'one valid header kept');
  CheckEqual('a@b.com', MimeHeaderValue(H, 'From'), 'from');
  CheckEqual(1, Length(Iss), 'one issue reported');
  Check(Iss[0].Kind = miBadHeader, 'issue kind bad header');
end;

procedure TestContentTypeParse;
var
  CT: TMimeContentType;
begin
  Check(MimeParseContentType('text/plain; charset=utf-8', CT), 'plain');
  CheckEqual('text/plain', CT.MediaType, 'media');
  CheckEqual('utf-8', CT.CharSet, 'charset');
  Check(MimeParseContentType('Multipart/Mixed; boundary="B1"', CT), 'mixed');
  CheckEqual('multipart/mixed', CT.MediaType, 'media normalized lower');
  CheckEqual('B1', CT.Boundary, 'boundary');
  Check(CT.IsMultipart, 'is multipart');
  Check(not MimeParseContentType('', CT), 'empty fails');
end;

procedure TestParamQuoted;
var
  P: TMimeParams;
begin
  Check(MimeParseParams('boundary="a;b=1"; filename="x\"y.txt"', P), 'quoted params');
  CheckEqual(2, Length(P), 'two params');
  CheckEqual('boundary', P[0].Name, 'first name');
  CheckEqual('a;b=1', P[0].Value, 'semicolon inside quotes preserved');
  CheckEqual('filename', P[1].Name, 'second name');
  CheckEqual('x"y.txt', P[1].Value, 'escaped quote unescaped');
end;

procedure TestAddressList;
var
  A: TMailAddressArray;
begin
  CheckEqual(3, MimeParseAddressList('a@x.com, "Doe, John" <b@y.com>, c@z.com', A),
    'three addresses');
  CheckEqual('a@x.com', A[0].Full, 'first');
  CheckEqual('Doe, John', A[1].DisplayName, 'display with comma');
  CheckEqual('b@y.com', A[1].Full, 'second');
  CheckEqual('c@z.com', A[2].Full, 'third');
  CheckEqual(1, MimeParseAddressList('a@x.com, bad-addr,,', A),
    'invalid items skipped');
  CheckEqual('a@x.com', A[0].Full, 'only valid kept');
end;

procedure TestBase64;
var
  B64: string;
  D: TBytes;
  I: Integer;
  Long: TBytes;
begin
  SetLength(D, 0);
  Check(MimeBase64Decode('Zm9v', D), 'foo decode');
  CheckEqual('foo', BytesToStr(D), 'foo value');
  CheckEqual('Zm9v', MimeBase64Encode(StrBytes('foo')), 'foo encode');
  Check(MimeBase64Decode(MimeBase64Encode(StrBytes('hello world')), D),
    'roundtrip decode');
  CheckEqual('hello world', BytesToStr(D), 'roundtrip value');
  { 102 字节输入 → 折行输出，行长 <= 76 }
  SetLength(Long, 102);
  for I := 0 to 101 do
    Long[I] := Byte(I);
  B64 := MimeBase64Encode(Long);
  Check(Pos(#13#10, B64) > 0, 'wrapped with CRLF');
  Check(MaxLineLen(B64) <= 76, 'no line exceeds 76');
  Check(MimeBase64Decode(B64, D), 'wrapped decode');
  CheckEqual(102, Length(D), 'wrapped length');
  Check(MimeBase64Decode('Zm9v' + #13#10 + 'IGJhcg==', D), 'whitespace tolerant');
  CheckEqual('foo bar', BytesToStr(D), 'whitespace value');
  Check(not MimeBase64Decode('!!!not-base64!!!', D), 'invalid rejected');
end;

procedure TestQuotedPrintable;
var
  D: TBytes;
  E: string;
  Long: string;
  I: Integer;
begin
  CheckEqual('a=3Db', MimeQuotedPrintableEncode(StrBytes('a=b')), 'equal encoded');
  Check(MimeQuotedPrintableDecode('a=3Db', D), 'equal decoded');
  CheckEqual('a=b', BytesToStr(D), 'equal value');
  { 高位字节转义 }
  E := MimeQuotedPrintableEncode(StrBytes(#$E4#$B8#$AD#$E6#$96#$87));
  CheckEqual('=E4=B8=AD=E6=96=87', E, 'utf8 bytes escaped');
  Check(MimeQuotedPrintableDecode(E, D), 'utf8 decode');
  CheckEqual(#$E4#$B8#$AD#$E6#$96#$87, BytesToStr(D), 'utf8 value');
  { 行尾空白编码 }
  CheckEqual('ab=20', MimeQuotedPrintableEncode(StrBytes('ab ')), 'trailing space');
  { 软换行 }
  Long := '';
  for I := 1 to 80 do
    Long := Long + 'a';
  E := MimeQuotedPrintableEncode(StrBytes(Long));
  Check(Pos('=' + #13#10, E) > 0, 'soft break inserted');
  CheckEqual(80, Length(E) - 3, 'soft break removed only'); { 81 - '=\r\n'(3) }
  Check(MimeQuotedPrintableDecode(E, D), 'soft break decode');
  CheckEqual(Long, BytesToStr(D), 'soft break roundtrip');
  { 解码坏序列 }
  Check(not MimeQuotedPrintableDecode('bad =X1 end', D), 'bad hex rejected');
  Check(not MimeQuotedPrintableDecode('x =', D), 'trailing equal rejected');
  { 行尾空白剥离（硬换行） }
  Check(MimeQuotedPrintableDecode('a b  ' + #13#10 + 'c', D), 'strip ws decode');
  CheckEqual('a b' + #13#10 + 'c', BytesToStr(D), 'trailing ws stripped');
end;

procedure TestDateParse;
var
  U: Int64;
begin
  { 2006-01-02 15:04:05 -0700 == 22:04:05 UTC == 1136239445 }
  Check(MimeParseDate('Mon, 02 Jan 2006 15:04:05 -0700', U), 'rfc5322 full');
  CheckEqual(1136239445, U, 'zone offset applied');
  Check(MimeParseDate('2 Jan 2006 22:04:05 +0000', U), 'no weekday');
  CheckEqual(1136239445, U, 'no weekday value');
  Check(MimeParseDate('02 Jan 2006 15:04:05 GMT', U), 'gmt zone');
  CheckEqual(1136214245, U, 'gmt value');
  Check(MimeParseDate('2 Jan 06 15:04:05 -0000', U), 'two-digit year');
  CheckEqual(1136214245, U, 'two-digit year value');
  Check(MimeParseDate('Tue, 02 Jan 2006 15:04:05 +05:30', U), 'colon zone');
  CheckEqual(1136194445, U, 'colon zone value');
  U := 0;
  Check(MimeParseDate('2 Jan 2006 15:04 EST', U), 'military zone');
  CheckEqual(1136160000 + 15 * 3600 + 4 * 60 + 5 * 3600, U, 'est value');
  Check(not MimeParseDate('not a date', U), 'garbage rejected');
  Check(not MimeParseDate('32 Foo 2006 15:04:05 +0000', U), 'bad month/day rejected');
end;

procedure TestDateFormatRoundTrip;
var
  U: Int64;
begin
  CheckEqual('Mon, 02 Jan 2006 15:04:05 +0000', MimeFormatDate(1136214245),
    'formatted date');
  Check(MimeParseDate(MimeFormatDate(1136214245), U), 'parse back');
  CheckEqual(1136214245, U, 'round trip value');
end;

procedure TestSerializeBasic;
var
  M: TMailMessage;
  S: string;
begin
  M := Default(TMailMessage);
  M.From := TMailAddress.Parse('alice@example.com');
  M.Subject := 'greetings';
  M.DateUtc := 1136214245;
  M.MessageId := 'mid-1@example.com';
  M.BodyText := 'hi there';
  S := MimeSerialize(M);
  Check(Pos('From: alice@example.com', S) > 0, 'from header');
  Check(Pos('Subject: greetings', S) > 0, 'subject header');
  Check(Pos('Date: Mon, 02 Jan 2006 15:04:05 +0000', S) > 0, 'date header');
  Check(Pos('Message-ID: <mid-1@example.com>', S) > 0, 'message-id header');
  Check(Pos('Content-Type: text/plain', S) > 0, 'content type');
  Check(Pos(#13#10 + #13#10, S) > 0, 'header/body separator');
end;

procedure TestSerializeHeaderInjection;
var
  M: TMailMessage;
  S: string;
begin
  M := Default(TMailMessage);
  M.From := TMailAddress.Parse('a@b.com');
  M.Subject := 'evil' + #13#10 + 'Bcc: injected@x.com';
  S := MimeSerialize(M);
  Check(Pos(#13#10 + 'Bcc:', S) = 0, 'crlf stripped from header value');
  Check(Pos('Subject: evil Bcc: injected@x.com', S) > 0, 'sanitized inline');
end;

procedure TestRoundTripFull;
var
  M, M2: TMailMessage;
  S: string;
begin
  M := Default(TMailMessage);
  M.From := TMailAddress.Parse('"Alice" <alice@example.com>');
  M.ToList := MakeList(['bob@example.com', 'carol@example.com']);
  M.CcList := MakeList(['dave@example.com']);
  M.ReplyToList := MakeList(['reply@example.com']);
  M.Subject := 'full test';
  M.DateUtc := 1136214245;
  M.MessageId := 'roundtrip@example.com';
  M.BodyText := 'plain body' + #13#10 + 'line two';
  M.BodyHtml := '<p>plain body<br>line two</p>';
  SetLength(M.Attachments, 1);
  M.Attachments[0].FileName := 'notes.txt';
  M.Attachments[0].ContentType := 'text/csv';
  M.Attachments[0].Data := StrBytes('a,b,c');
  M.HasAttachments := True;
  S := MimeSerialize(M);
  Check(MimeTryParse(S, M2), 'roundtrip parse');
  CheckEqual('alice@example.com', M2.From.Full, 'from');
  CheckEqual(2, Length(M2.ToList), 'to count');
  CheckEqual('bob@example.com', M2.ToList[0].Full, 'to[0]');
  CheckEqual('carol@example.com', M2.ToList[1].Full, 'to[1]');
  CheckEqual(1, Length(M2.CcList), 'cc count');
  CheckEqual('dave@example.com', M2.CcList[0].Full, 'cc');
  CheckEqual(1, Length(M2.ReplyToList), 'reply-to count');
  CheckEqual('reply@example.com', M2.ReplyToList[0].Full, 'reply-to');
  CheckEqual('full test', M2.Subject, 'subject');
  CheckEqual('roundtrip@example.com', M2.MessageId, 'message-id');
  CheckEqual('plain body' + #13#10 + 'line two', M2.BodyText, 'body text');
  CheckEqual('<p>plain body<br>line two</p>', M2.BodyHtml, 'body html');
  CheckEqual(1, Length(M2.Attachments), 'attachment count');
  CheckEqual('notes.txt', M2.Attachments[0].FileName, 'attachment name');
  CheckEqual('text/csv', M2.Attachments[0].ContentType, 'attachment type');
  CheckEqual('a,b,c', BytesToStr(M2.Attachments[0].Data), 'attachment data');
end;

procedure TestAlternativeParse;
var
  Raw: string;
  M: TMailMessage;
  Iss: TMimeIssueList;
begin
  Raw := 'From: a@b.com' + #13#10 +
    'Content-Type: multipart/alternative; boundary="alt"' + #13#10 + #13#10 +
    '--alt' + #13#10 +
    'Content-Type: text/plain; charset=utf-8' + #13#10 + #13#10 +
    'simple text' + #13#10 +
    '--alt' + #13#10 +
    'Content-Type: text/html; charset=utf-8' + #13#10 + #13#10 +
    '<b>simple</b> html' + #13#10 +
    '--alt--' + #13#10;
  Check(MimeTryParse(Raw, M, Iss), 'alternative parse');
  CheckEqual('simple text', M.BodyText, 'text body');
  CheckEqual('<b>simple</b> html', M.BodyHtml, 'html body');
  CheckEqual(0, Length(M.Attachments), 'no attachments');
  CheckEqual(0, Length(Iss), 'no issues');
end;

procedure TestMixedParse;
var
  Raw: string;
  M: TMailMessage;
begin
  Raw := 'From: a@b.com' + #13#10 +
    'Content-Type: multipart/mixed; boundary="mix"' + #13#10 + #13#10 +
    '--mix' + #13#10 +
    'Content-Type: text/plain; charset=utf-8' + #13#10 +
    'Content-Transfer-Encoding: quoted-printable' + #13#10 + #13#10 +
    'hello=20world' + #13#10 +
    '--mix' + #13#10 +
    'Content-Type: application/octet-stream; name="a.bin"' + #13#10 +
    'Content-Disposition: attachment; filename="a.bin"' + #13#10 +
    'Content-Transfer-Encoding: base64' + #13#10 + #13#10 +
    'AAECAwQ=' + #13#10 +
    '--mix--' + #13#10;
  Check(MimeTryParse(Raw, M), 'mixed parse');
  CheckEqual('hello world', M.BodyText, 'qp text body');
  CheckEqual(1, Length(M.Attachments), 'one attachment');
  CheckEqual('a.bin', M.Attachments[0].FileName, 'filename');
  CheckEqual('application/octet-stream', M.Attachments[0].ContentType, 'ctype');
  CheckEqual(5, Length(M.Attachments[0].Data), 'b64 data length');
  CheckEqual(0, M.Attachments[0].Data[0], 'first byte');
  CheckEqual(4, M.Attachments[0].Data[4], 'last byte');
end;

procedure TestNestedMixedAlternative;
var
  Raw: string;
  M: TMailMessage;
begin
  Raw := 'From: a@b.com' + #13#10 +
    'Content-Type: multipart/mixed; boundary="out"' + #13#10 + #13#10 +
    '--out' + #13#10 +
    'Content-Type: multipart/alternative; boundary="in"' + #13#10 + #13#10 +
    '--in' + #13#10 +
    'Content-Type: text/plain; charset=utf-8' + #13#10 + #13#10 +
    'inner plain' + #13#10 +
    '--in' + #13#10 +
    'Content-Type: text/html; charset=utf-8' + #13#10 + #13#10 +
    '<i>inner</i>' + #13#10 +
    '--in--' + #13#10 +
    '--out' + #13#10 +
    'Content-Type: image/png; name="img.png"' + #13#10 +
    'Content-Disposition: attachment; filename="img.png"' + #13#10 +
    'Content-Transfer-Encoding: base64' + #13#10 + #13#10 +
    'iVBORw0KGgo=' + #13#10 +
    '--out--' + #13#10;
  Check(MimeTryParse(Raw, M), 'nested parse');
  CheckEqual('inner plain', M.BodyText, 'inner plain');
  CheckEqual('<i>inner</i>', M.BodyHtml, 'inner html');
  CheckEqual(1, Length(M.Attachments), 'outer attachment');
  CheckEqual('img.png', M.Attachments[0].FileName, 'attachment name');
  CheckEqual('image/png', M.Attachments[0].ContentType, 'attachment type');
end;

procedure TestBodyTextHtmlDistinguish;
var
  M: TMailMessage;
begin
  Check(MimeTryParse('From: a@b.com' + #13#10 + #13#10 + 'just text', M),
    'text-only parse');
  CheckEqual('just text', M.BodyText, 'text set');
  CheckEqual('', M.BodyHtml, 'html empty');
  Check(MimeTryParse('From: a@b.com' + #13#10 +
    'Content-Type: text/html; charset=utf-8' + #13#10 + #13#10 + '<p>x</p>', M),
    'html-only parse');
  CheckEqual('', M.BodyText, 'text empty');
  CheckEqual('<p>x</p>', M.BodyHtml, 'html set');
end;

procedure TestTruncatedMultipart;
var
  Raw: string;
  M: TMailMessage;
  Iss: TMimeIssueList;
begin
  Raw := 'From: a@b.com' + #13#10 +
    'Content-Type: multipart/alternative; boundary="t"' + #13#10 + #13#10 +
    '--t' + #13#10 +
    'Content-Type: text/plain' + #13#10 + #13#10 +
    'surviving part';
  Check(MimeTryParse(Raw, M, Iss), 'truncated parse');
  CheckEqual('surviving part', M.BodyText, 'part before truncation kept');
  CheckEqual(1, Length(Iss), 'issue reported');
  Check(Iss[0].Kind = miTruncatedMultipart, 'kind truncated multipart');
end;

procedure TestBadBase64Body;
var
  Raw: string;
  M: TMailMessage;
  Iss: TMimeIssueList;
begin
  Raw := 'From: a@b.com' + #13#10 +
    'Content-Type: text/plain' + #13#10 +
    'Content-Transfer-Encoding: base64' + #13#10 + #13#10 +
    '###not-valid###';
  Check(MimeTryParse(Raw, M, Iss), 'bad base64 still parses');
  CheckEqual('###not-valid###', M.BodyText, 'raw text preserved');
  CheckEqual(1, Length(Iss), 'issue reported');
  Check(Iss[0].Kind = miBadEncoding, 'kind bad encoding');
end;

procedure TestBadDateIssue;
var
  Raw: string;
  M: TMailMessage;
  Iss: TMimeIssueList;
begin
  Raw := 'From: a@b.com' + #13#10 + 'Date: yesterday-ish' + #13#10 + #13#10 + 'x';
  Check(MimeTryParse(Raw, M, Iss), 'bad date parse ok');
  CheckEqual(0, M.DateUtc, 'date zeroed');
  CheckEqual(1, Length(Iss), 'issue reported');
  Check(Iss[0].Kind = miBadDate, 'kind bad date');
end;

procedure TestEmptyInput;
var
  M: TMailMessage;
begin
  Check(not MimeTryParse('', M), 'empty rejected');
  Check(not MimeTryParse('   ' + #13#10, M), 'whitespace rejected');
  try
    M := MimeParse('');
    Check(False, 'MimeParse should raise');
  except
    on E: EMimeError do
      Check(True, 'raised EMimeError');
  end;
end;

procedure TestMissingFrom;
var
  Raw: string;
  M: TMailMessage;
begin
  Raw := 'To: bob@example.com' + #13#10 + 'Subject: no from' + #13#10 + #13#10 + 'x';
  Check(MimeTryParse(Raw, M), 'no-from parse');
  CheckEqual('', M.From.LocalPart, 'from empty');
  CheckEqual('', M.From.Domain, 'from domain empty');
  CheckEqual('bob@example.com', M.ToList[0].Full, 'to still parsed');
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.mail.mime');
  T.Test('HeaderParseBasic', @TestHeaderParseBasic);
  T.Test('HeaderCaseInsensitive', @TestHeaderCaseInsensitive);
  T.Test('HeaderFolding', @TestHeaderFolding);
  T.Test('HeaderMissingCrlf', @TestHeaderMissingCrlf);
  T.Test('HeaderMissingColon', @TestHeaderMissingColon);
  T.Test('ContentTypeParse', @TestContentTypeParse);
  T.Test('ParamQuoted', @TestParamQuoted);
  T.Test('AddressList', @TestAddressList);
  T.Test('Base64', @TestBase64);
  T.Test('QuotedPrintable', @TestQuotedPrintable);
  T.Test('DateParse', @TestDateParse);
  T.Test('DateFormatRoundTrip', @TestDateFormatRoundTrip);
  T.Test('SerializeBasic', @TestSerializeBasic);
  T.Test('SerializeHeaderInjection', @TestSerializeHeaderInjection);
  T.Test('RoundTripFull', @TestRoundTripFull);
  T.Test('AlternativeParse', @TestAlternativeParse);
  T.Test('MixedParse', @TestMixedParse);
  T.Test('NestedMixedAlternative', @TestNestedMixedAlternative);
  T.Test('BodyTextHtmlDistinguish', @TestBodyTextHtmlDistinguish);
  T.Test('TruncatedMultipart', @TestTruncatedMultipart);
  T.Test('BadBase64Body', @TestBadBase64Body);
  T.Test('BadDateIssue', @TestBadDateIssue);
  T.Test('EmptyInput', @TestEmptyInput);
  T.Test('MissingFrom', @TestMissingFrom);
  if not T.Run then
    Halt(1);
end.