program test_tls12_serverhello_parse;
{$mode objfpc}{$H+}{$J-}
uses
  SysUtils,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.wire;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;
  GFailed: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean);
begin
  Inc(GTotal);
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure TestTLS12ServerHelloNoExtensions;
var
  LHandshake: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LOffset: Integer;
begin
  WriteLn('TLS 1.2 ServerHello without extensions');

  // Build a minimal TLS 1.2 ServerHello (no extensions)
  // Type(1) + Length(3) + Version(2) + Random(32) + SessionIDLen(1) + SessionID(32) + CipherSuite(2) + Compression(1)
  SetLength(LHandshake, 4 + 2 + 32 + 1 + 32 + 2 + 1);
  LHandshake[0] := $02; // ServerHello type
  LOffset := 4 + 2 + 32 + 1 + 32 + 2 + 1 - 4; // body length
  LHandshake[1] := 0;
  LHandshake[2] := 0;
  LHandshake[3] := Byte(LOffset);
  // Version
  LHandshake[4] := $03; LHandshake[5] := $03;
  // Random (32 bytes of 0xAA)
  FillChar(LHandshake[6], 32, $AA);
  // Session ID length = 32
  LHandshake[38] := 32;
  // Session ID (32 bytes of 0xBB)
  FillChar(LHandshake[39], 32, $BB);
  // Cipher suite = 0xC02F (ECDHE-RSA-AES128-GCM-SHA256)
  LHandshake[71] := $C0; LHandshake[72] := $2F;
  // Compression = 0
  LHandshake[73] := $00;

  Check('Parse succeeds', TryParseServerHelloFromHandshake(LHandshake, LInfo));
  Check('Valid flag set', LInfo.Valid);
  Check('Version is legacy (0x0303)', LInfo.LegacyVersion = $0303);
  Check('SelectedVersion defaults to legacy', LInfo.SelectedVersion = TLS_LEGACY_VERSION);
  Check('Cipher suite = 0xC02F', LInfo.SelectedCipherSuite = $C02F);
  Check('No key_share', not LInfo.HasKeyShare);
  Check('No PSK', not LInfo.HasPreSharedKey);
  Check('No cookie', not LInfo.HasCookie);
end;

procedure TestTLS13ServerHelloWithExtensions;
var
  LHandshake: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LOffset: Integer;
begin
  WriteLn('TLS 1.3 ServerHello with supported_versions + key_share');

  // Build a TLS 1.3 ServerHello with extensions
  SetLength(LHandshake, 4 + 2 + 32 + 1 + 32 + 2 + 1 + 2 + 12);
  LOffset := Length(LHandshake) - 4;
  LHandshake[0] := $02;
  LHandshake[1] := Byte(LOffset shr 16);
  LHandshake[2] := Byte(LOffset shr 8);
  LHandshake[3] := Byte(LOffset);
  LHandshake[4] := $03; LHandshake[5] := $03;
  FillChar(LHandshake[6], 32, $CC);
  LHandshake[38] := 32;
  FillChar(LHandshake[39], 32, $DD);
  LHandshake[71] := $13; LHandshake[72] := $01; // TLS_AES_128_GCM_SHA256
  LHandshake[73] := $00;
  // Extensions length = 12
  LHandshake[74] := $00; LHandshake[75] := $0C;
  // supported_versions: type=0x002B, len=2, value=0x0304
  LHandshake[76] := $00; LHandshake[77] := $2B;
  LHandshake[78] := $00; LHandshake[79] := $02;
  LHandshake[80] := $03; LHandshake[81] := $04;
  // key_share: type=0x0033, len=2, group=0x001D (X25519, HRR style)
  LHandshake[82] := $00; LHandshake[83] := $33;
  LHandshake[84] := $00; LHandshake[85] := $02;
  LHandshake[86] := $00; LHandshake[87] := $1D;

  Check('Parse succeeds', TryParseServerHelloFromHandshake(LHandshake, LInfo));
  Check('Valid flag set', LInfo.Valid);
  Check('SelectedVersion = TLS 1.3', LInfo.SelectedVersion = $0304);
  Check('Cipher suite = 0x1301', LInfo.SelectedCipherSuite = $1301);
  Check('Has key_share', LInfo.HasKeyShare);
  Check('Key share group = X25519', LInfo.KeyShareGroup = $001D);
  Check('Key share length = 0 (HRR)', LInfo.KeyShareLength = 0);
end;

begin
  WriteLn('=== ServerHello Parser Tests ===');
  WriteLn;
  TestTLS12ServerHelloNoExtensions;
  WriteLn;
  TestTLS13ServerHelloWithExtensions;
  WriteLn;

  if GFailed > 0 then
  begin
    WriteLn('FAILED: ', GFailed, '/', GTotal);
    Halt(1);
  end;
  WriteLn('All passed: ', GPassed, '/', GTotal);
end.
