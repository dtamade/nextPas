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
  { RFC 3492 3.1 Arabic-Indic digits example — simplified known vectors }
  { "bücher" -> Punycode bcher-kva then ACE xn--bcher-kva }
  CheckEqual(IDNAToASCII('bücher.de', LErr), 'xn--bcher-kva.de', 'bücher.de ToASCII');
  CheckEqual(LErr, '', 'no error bücher');
  CheckEqual(IDNAToUnicode('xn--bcher-kva.de', LErr), 'bücher.de', 'ACE ToUnicode');
  CheckEqual(LErr, '', 'no error ACE');

  { round-trip ASCII }
  CheckEqual(IDNAToASCII('example.com'), 'example.com', 'ASCII domain');
  CheckEqual(IDNAToUnicode('example.com'), 'example.com', 'ASCII unicode');

  { münchen }
  CheckEqual(IDNAToASCII('münchen.de'), 'xn--mnchen-3ya.de', 'münchen ToASCII');
  CheckEqual(IDNAToUnicode('xn--mnchen-3ya.de'), 'münchen.de', 'münchen ToUnicode');
end;

procedure TestPunycodeBasics;
var
  S: string;
begin
  { RFC 3492: pure basic encode is identity; decode without delimiter is delta stream, not identity. }
  S := PunycodeEncode('abc');
  CheckEqual(S, 'abc', 'pure ASCII punycode encode identity');
  { non-ASCII label round-trip via encode/decode }
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

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.idna');
  T.Test('PunycodeBasics', @TestPunycodeBasics);
  T.Test('PunycodeRFC3493', @TestPunycodeRFC3493);
  T.Test('Invalid', @TestInvalid);
  if not T.Run then
    Halt(1);
end.
