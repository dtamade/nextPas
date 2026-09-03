program test_tls13_clienthello;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.test, nextpas.core.base, nextpas.core.text, nextpas.core.text.conv;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls13.clienthello');

  LSuite.Test('basic handshake', procedure
  var LKeyShare, LHandshake: TBytes;
  begin
    SetLength(LKeyShare, 32); FillChar(LKeyShare[0], 32, $AA);
    LHandshake := BuildTLS13ClientHelloHandshake('example.com', 'h2', LKeyShare);
    CheckTrue(Length(LHandshake) > 0);
    CheckTrue(LHandshake[0] = $01);
    CheckTrue(Length(LHandshake) > 100);
    CheckTrue((LHandshake[4] = $03) and (LHandshake[5] = $03));
    CheckTrue(Length(LHandshake) > 38);
  end);

  LSuite.Test('record format', procedure
  var LKeyShare, LRecord: TBytes; LLen: Word;
  begin
    SetLength(LKeyShare, 32); FillChar(LKeyShare[0], 32, $BB);
    LRecord := BuildTLS13ClientHelloRecord('test.example.org', 'h2', LKeyShare);
    CheckTrue(Length(LRecord) > 0);
    CheckTrue(LRecord[0] = $16);
    CheckTrue((LRecord[1] = $03) and (LRecord[2] = $03));
    LLen := (Word(LRecord[3]) shl 8) or Word(LRecord[4]);
    CheckTrue(LLen = Length(LRecord) - 5);
  end);

  LSuite.Test('contains SNI', procedure
  var LKeyShare, LHandshake: TBytes; LHex: string;
  begin
    SetLength(LKeyShare, 32); FillChar(LKeyShare[0], 32, $CC);
    LHandshake := BuildTLS13ClientHelloHandshake('myserver.io', '', LKeyShare);
    LHex := BytesToHex(LHandshake);
    CheckTrue(Pos('6d797365727665722e696f', LHex) > 0);
  end);

  LSuite.Test('contains key share', procedure
  var LKeyShare, LHandshake: TBytes; LHex: string;
  begin
    LKeyShare := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LHandshake := BuildTLS13ClientHelloHandshake('ks.test', '', LKeyShare);
    LHex := BytesToHex(LHandshake);
    CheckTrue(Pos('0102030405060708091011121314151617181920212223242526272829303132', LHex) > 0);
  end);

  LSuite.Test('contains supported versions', procedure
  var LKeyShare, LHandshake: TBytes; LHex: string;
  begin
    SetLength(LKeyShare, 32);
    LHandshake := BuildTLS13ClientHelloHandshake('ver.test', '', LKeyShare);
    LHex := BytesToHex(LHandshake);
    CheckTrue(Pos('002b', LHex) > 0);
    CheckTrue(Pos('0304', LHex) > 0);
  end);

  LSuite.Test('randomized', procedure
  var LKeyShare, LCH1, LCH2: TBytes;
  begin
    LKeyShare := HexToBytes('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    LCH1 := BuildTLS13ClientHelloHandshake('det.test', 'h2', LKeyShare);
    LCH2 := BuildTLS13ClientHelloHandshake('det.test', 'h2', LKeyShare);
    CheckTrue(BytesToHex(LCH1) <> BytesToHex(LCH2));
    CheckTrue(Length(LCH1) = Length(LCH2));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.tls13.clienthello');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
