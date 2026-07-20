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
  CheckEqual(Integer(K), Integer(idnaInvalidAsciiLabel), 'kind invalid ASCII label');

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

  { Nontransitional: ß (U+00DF) → ss }
  St := GetIdnaMapStatus($00DF, Map, MapLen);
  CheckEqual(Integer(St), Integer(idmsDeviation), 'sharp s deviation');
  CheckEqual(Integer(MapLen), 2, 'ß → two cps');
  CheckEqual(Integer(Map[0]), Ord('s'), 'ß[0]=s');
  CheckEqual(Integer(Map[1]), Ord('s'), 'ß[1]=s');
  CheckEqual(IDNAToASCII('stra' + #$C3#$9F + 'e.de', K), 'strasse.de', 'Nontransitional ß → ss ASCII');
  CheckEqual(Integer(K), Integer(idnaOk), 'straße ok');

  { mixed case ASCII via mapping }
  CheckEqual(IDNAToASCII('ExAmPle.COM', K), 'example.com', 'ASCII case map');
  CheckEqual(Integer(K), Integer(idnaOk), 'ExAmPle ok');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.idna');
  T.Test('PunycodeBasics', @TestPunycodeBasics);
  T.Test('PunycodeRFC3493', @TestPunycodeRFC3493);
  T.Test('Invalid', @TestInvalid);
  T.Test('ErrorKinds', @TestErrorKinds);
  T.Test('IdnaMappingTable', @TestIdnaMappingTable);
  if not T.Run then
    Halt(1);
end.
