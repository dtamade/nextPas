program test_idna;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

procedure TestPunycodeRFC3493;
var
  LErr: string;
begin
  { "bücher" -> ACE xn--bcher-kva }
  CheckEqual(IDNAToASCII('bücher.de', LErr), 'xn--bcher-kva.de', 'bücher.de ToASCII');
  CheckEqual(LErr, '', 'no error bücher');
  CheckEqual(IDNAToUnicode('xn--bcher-kva.de', LErr), 'bücher.de', 'ACE ToUnicode');
  CheckEqual(LErr, '', 'no error ACE');

  CheckEqual(IDNAToASCII('example.com'), 'example.com', 'ASCII domain');
  CheckEqual(IDNAToUnicode('example.com'), 'example.com', 'ASCII unicode');

  CheckEqual(IDNAToASCII('münchen.de'), 'xn--mnchen-3ya.de', 'münchen ToASCII');
  CheckEqual(IDNAToUnicode('xn--mnchen-3ya.de'), 'münchen.de', 'münchen ToUnicode');
end;

procedure TestPunycodeBasics;
var
  S: string;
begin
  S := PunycodeEncode('abc');
  CheckEqual(S, 'abc', 'pure ASCII punycode encode identity');
  S := PunycodeEncode('bücher');
  Check(S <> '', 'bücher encodes');
  CheckEqual(PunycodeDecode(S), 'bücher', 'bücher punycode round-trip');
end;

procedure TestInvalid;
var
  E: string;
  R: string;
begin
  R := IDNAToASCII('', E);
  Check(R = '', 'empty domain fails');
  Check(E <> '', 'empty domain error set');
  R := IDNAToASCII('-bad.com', E);
  Check(R = '', 'leading hyphen fails');
end;

procedure TestErrorKinds;
var
  R: string;
  K: TIDNAErrorKind;
begin
  R := IDNAToASCII('', K);
  Check(R = '', 'empty domain empty result');
  CheckEqual(Integer(K), Integer(idnaEmptyDomain), 'kind empty domain');
  CheckEqual(IDNAErrorKindName(K), 'empty domain', 'name empty domain');

  R := IDNAToASCII('-bad.com', K);
  Check(R = '', 'leading hyphen empty result');
  CheckEqual(Integer(K), Integer(idnaCheckHyphens), 'kind CheckHyphens');

  R := IDNAToASCII('example.com', K);
  CheckEqual(R, 'example.com', 'ok domain');
  CheckEqual(Integer(K), Integer(idnaOk), 'kind ok');
  CheckEqual(IDNAErrorKindName(K), '', 'name ok empty');
end;

procedure TestIdnaMappingTable;
var
  K: TIDNAErrorKind;
  St: TIDNAMapStatus;
  Map: array[0..7] of TUnicodeCodepoint;
  MapLen: Byte;
  S: string;
begin
  { A → a (mapped) }
  St := GetIdnaMapStatus(Ord('A'), Map, MapLen);
  CheckEqual(Integer(St), Integer(idmsMapped), 'A mapped');
  CheckEqual(Integer(MapLen), 1, 'A map len');
  CheckEqual(Integer(Map[0]), Ord('a'), 'A → a');

  { soft hyphen ignored }
  St := GetIdnaMapStatus($00AD, Map, MapLen);
  CheckEqual(Integer(St), Integer(idmsIgnored), 'soft hyphen ignored');
  S := ApplyIdnaMap('foo' + #$C2#$AD + 'bar', K); { U+00AD UTF-8 }
  CheckEqual(Integer(K), Integer(idnaOk), 'map soft hyphen ok');
  CheckEqual(S, 'foobar', 'soft hyphen dropped');

  { Deviation ß (U+00DF): table carries the transitional mapping, but
    Nontransitional processing keeps ß as-is → xn--strae-oqa.de }
  St := GetIdnaMapStatus($00DF, Map, MapLen);
  CheckEqual(Integer(St), Integer(idmsDeviation), 'sharp s deviation');
  CheckEqual(Integer(MapLen), 2, 'ß table map is ss');
  CheckEqual(Integer(Map[0]), Ord('s'), 'ß[0]=s');
  CheckEqual(Integer(Map[1]), Ord('s'), 'ß[1]=s');
  CheckEqual(IDNAToASCII('stra' + #$C3#$9F + 'e.de', K), 'xn--strae-oqa.de', 'Nontransitional keeps ß');
  CheckEqual(Integer(K), Integer(idnaOk), 'straße ok');

  { mixed case ASCII via mapping }
  CheckEqual(IDNAToASCII('ExAmPle.COM', K), 'example.com', 'ASCII case map');
  CheckEqual(Integer(K), Integer(idnaOk), 'ExAmPle ok');
end;

{ 精确错误码检查 — conformance harness 只做二元判定，这里锁定 kind。 }
procedure TestValidityKinds;
var
  R, LAce: string;
  K: TIDNAErrorKind;
begin
  { STD3: '$' 在 16.0 表中标 valid，由 validity 规则拒绝 }
  R := IDNAToASCII('a$b.com', K);
  Check(R = '', 'STD3 $ rejected');
  CheckEqual(Integer(K), Integer(idnaDisallowedSTD3), 'kind STD3');

  { V6: 首字符 combining mark (U+0301) }
  R := IDNAToASCII(#$CC#$81 + 'a.com', K);
  CheckEqual(Integer(K), Integer(idnaLeadingCombiningMark), 'kind leading mark');

  { ContextJ: ZWNJ (U+200C) 无 virama/joining 上下文 }
  R := IDNAToASCII('a' + #$E2#$80#$8C + 'b.com', K);
  CheckEqual(Integer(K), Integer(idnaContextJ), 'kind contextj');

  { ContextJ 满足: क(U+0915) ्(U+094D virama ccc=9) ZWNJ }
  R := IDNAToASCII(#$E0#$A4#$95#$E0#$A5#$8D#$E2#$80#$8C + '.com', K);
  CheckEqual(Integer(K), Integer(idnaOk), 'virama+ZWNJ ok');
  Check(R <> '', 'virama+ZWNJ encodes');

  { CheckBidi: LTR label 内混入希伯来 א(U+05D0) }
  R := IDNAToASCII('a' + #$D7#$90 + '.com', K);
  CheckEqual(Integer(K), Integer(idnaCheckBidi), 'kind bidi');

  { V2: 3-4 位 '--' }
  R := IDNAToASCII('ab--cd.com', K);
  CheckEqual(Integer(K), Integer(idnaCheckHyphens), 'kind hyphens 3-4');

  { 空 ACE body / 空 label }
  R := IDNAToASCII('xn--.com', K);
  CheckEqual(Integer(K), Integer(idnaEmptyAceBody), 'kind empty ACE body');
  R := IDNAToASCII('a..b', K);
  CheckEqual(Integer(K), Integer(idnaEmptyLabel), 'kind empty label');

  { V1: ACE 解码结果非 NFC (a + U+0301 应合成 á) }
  LAce := 'xn--' + PunycodeEncode('a' + #$CC#$81);
  R := IDNAToASCII(LAce + '.com', K);
  CheckEqual(Integer(K), Integer(idnaNotNfc), 'kind not NFC');

  { disallowed: U+0378 未分配 }
  R := IDNAToASCII('a' + #$CD#$B8 + 'b.com', K);
  CheckEqual(Integer(K), Integer(idnaDisallowed), 'kind disallowed');
end;

procedure TestProcessingOrder;
var
  R, L63, LLong: string;
  K: TIDNAErrorKind;
  I: Integer;
begin
  { U+3002 (。) 先 Map 后 Break — split-before-Map 旧 bug 的回归锚 }
  CheckEqual(IDNAToASCII('a' + #$E3#$80#$82 + 'com', K), 'a.com', 'U+3002 separator');
  CheckEqual(Integer(K), Integer(idnaOk), 'U+3002 ok');

  { deviation ς (U+03C2) 保持原样并可往返 }
  R := IDNAToASCII(#$CF#$82 + '.gr', K);
  CheckEqual(Integer(K), Integer(idnaOk), 'final sigma ok');
  CheckEqual(IDNAToUnicode(R, K), #$CF#$82 + '.gr', 'final sigma round-trip');

  { 尾点: ToUnicode 保留, ToASCII (VerifyDnsLength) 拒绝 }
  CheckEqual(IDNAToUnicode('a.b.', K), 'a.b.', 'trailing dot preserved');
  CheckEqual(Integer(K), Integer(idnaOk), 'trailing dot toUnicode ok');
  R := IDNAToASCII('a.b.', K);
  CheckEqual(Integer(K), Integer(idnaEmptyLabel), 'trailing dot toASCII rejected');

  { DNS 长度: label 64 / domain 255 }
  LLong := '';
  for I := 1 to 64 do
    LLong := LLong + 'a';
  R := IDNAToASCII(LLong + '.com', K);
  CheckEqual(Integer(K), Integer(idnaAceLabelTooLong), 'kind label too long');
  L63 := Copy(LLong, 1, 63);
  R := IDNAToASCII(L63 + '.' + L63 + '.' + L63 + '.' + L63, K);
  CheckEqual(Integer(K), Integer(idnaDomainTooLong), 'kind domain too long');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.idna');
  T.Test('PunycodeBasics', @TestPunycodeBasics);
  T.Test('PunycodeRFC3493', @TestPunycodeRFC3493);
  T.Test('Invalid', @TestInvalid);
  T.Test('ErrorKinds', @TestErrorKinds);
  T.Test('IdnaMappingTable', @TestIdnaMappingTable);
  T.Test('ValidityKinds', @TestValidityKinds);
  T.Test('ProcessingOrder', @TestProcessingOrder);
  if not T.Run then
    Halt(1);
end.
