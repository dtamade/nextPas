program test_tls13_clienthello;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.tls.tls13.clienthello;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestBuildClientHello_Basic;
var
  LKeyShare, LHandshake: TBytes;
begin
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $AA);

  LHandshake := BuildTLS13ClientHelloHandshake('example.com', 'h2', LKeyShare);

  Check('CH handshake non-empty', Length(LHandshake) > 0);
  Check('CH starts with handshake type 01 (ClientHello)', LHandshake[0] = $01);
  Check('CH length > 100 bytes', Length(LHandshake) > 100);

  // Verify TLS 1.2 legacy version in body (0x0303)
  Check('CH legacy version 0x0303', (LHandshake[4] = $03) and (LHandshake[5] = $03));

  // Random is 32 bytes starting at offset 6
  Check('CH has 32 random bytes at offset 6', Length(LHandshake) > 38);
end;

procedure TestBuildClientHelloRecord;
var
  LKeyShare, LRecord: TBytes;
  LLen: Word;
begin
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $BB);

  LRecord := BuildTLS13ClientHelloRecord('test.example.org', 'h2', LKeyShare);

  Check('CH record non-empty', Length(LRecord) > 0);
  // TLS record: content_type=22 (handshake), version=0x0301 (legacy), length
  Check('CH record type = 0x16 (handshake)', LRecord[0] = $16);
  Check('CH record version = 0x0303 (TLS 1.2 compat)', (LRecord[1] = $03) and (LRecord[2] = $03));

  // Length field (2 bytes big-endian)
  LLen := (Word(LRecord[3]) shl 8) or Word(LRecord[4]);
  Check('CH record length field matches', LLen = Length(LRecord) - 5);
end;

procedure TestBuildClientHello_ContainsSNI;
var
  LKeyShare, LHandshake: TBytes;
  LHex: string;
begin
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $CC);

  LHandshake := BuildTLS13ClientHelloHandshake('myserver.io', '', LKeyShare);
  LHex := BytesToHex(LHandshake);

  // SNI extension contains the hostname as ASCII
  Check('CH contains SNI hostname', Pos('6d797365727665722e696f', LHex) > 0);
end;

procedure TestBuildClientHello_ContainsKeyShare;
var
  LKeyShare, LHandshake: TBytes;
  LHex: string;
begin
  LKeyShare := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');

  LHandshake := BuildTLS13ClientHelloHandshake('ks.test', '', LKeyShare);
  LHex := BytesToHex(LHandshake);

  // Key share bytes should appear in the handshake
  Check('CH contains key share bytes', Pos('0102030405060708091011121314151617181920212223242526272829303132', LHex) > 0);
end;

procedure TestBuildClientHello_ContainsSupportedVersions;
var
  LKeyShare, LHandshake: TBytes;
  LHex: string;
begin
  SetLength(LKeyShare, 32);
  LHandshake := BuildTLS13ClientHelloHandshake('ver.test', '', LKeyShare);
  LHex := BytesToHex(LHandshake);

  // supported_versions extension (type 0x002b) should contain 0x0304 (TLS 1.3)
  Check('CH contains supported_versions ext (002b)', Pos('002b', LHex) > 0);
  Check('CH contains TLS 1.3 version (0304)', Pos('0304', LHex) > 0);
end;

procedure TestBuildClientHello_Deterministic;
var
  LKeyShare, LCH1, LCH2: TBytes;
begin
  LKeyShare := HexToBytes('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

  LCH1 := BuildTLS13ClientHelloHandshake('det.test', 'h2', LKeyShare);
  LCH2 := BuildTLS13ClientHelloHandshake('det.test', 'h2', LKeyShare);

  // ClientHello contains random bytes, so two calls should differ
  Check('CH is randomized (different each call)', BytesToHex(LCH1) <> BytesToHex(LCH2));
  // But same length
  Check('CH same length each call', Length(LCH1) = Length(LCH2));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 ClientHello Tests ===');
  WriteLn;

  TestBuildClientHello_Basic;
  TestBuildClientHelloRecord;
  TestBuildClientHello_ContainsSNI;
  TestBuildClientHello_ContainsKeyShare;
  TestBuildClientHello_ContainsSupportedVersions;
  TestBuildClientHello_Deterministic;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
