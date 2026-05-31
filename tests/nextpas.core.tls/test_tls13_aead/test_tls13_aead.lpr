program test_tls13_aead;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.tls13.wire;

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

const
  CS_AES128_GCM = $1301;
  CS_AES256_GCM = $1302;
  CS_CHACHA20   = $1303;

procedure TestIsSupported;
begin
  Check('AES-128-GCM supported', TLS13AEADIsSupported(CS_AES128_GCM));
  Check('AES-256-GCM supported', TLS13AEADIsSupported(CS_AES256_GCM));
  Check('ChaCha20-Poly1305 supported', TLS13AEADIsSupported(CS_CHACHA20));
  Check('unknown not supported', not TLS13AEADIsSupported($FFFF));
end;

procedure TestTagLength;
begin
  Check('AES-128-GCM tag = 16', TLS13AEADTagLength(CS_AES128_GCM) = 16);
  Check('AES-256-GCM tag = 16', TLS13AEADTagLength(CS_AES256_GCM) = 16);
  Check('ChaCha20 tag = 16', TLS13AEADTagLength(CS_CHACHA20) = 16);
end;

procedure TestAES128GCM_Roundtrip;
var
  LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LNonce := HexToBytes('5d313eb2671276ee13000b30');
  LAAD := HexToBytes('1703030020');
  LPlain := HexToBytes('48656c6c6f20544c532031');

  LOk := TryTLS13AEADEncrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
  Check('AES-128-GCM encrypt ok', LOk);
  if not LOk then begin WriteLn('    ', LError); Exit; end;
  Check('AES-128-GCM encrypted length = plain + 16', Length(LEncrypted) = Length(LPlain) + 16);

  LOk := TryTLS13AEADDecrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
  Check('AES-128-GCM decrypt ok', LOk);
  if LOk then
    Check('AES-128-GCM roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestAES256GCM_Roundtrip;
var
  LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000001');
  LAAD := HexToBytes('17030300ff');
  LPlain := HexToBytes('deadbeefcafebabe01020304');

  LOk := TryTLS13AEADEncrypt(CS_AES256_GCM, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
  Check('AES-256-GCM encrypt ok', LOk);

  LOk := TryTLS13AEADDecrypt(CS_AES256_GCM, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
  Check('AES-256-GCM decrypt ok', LOk);
  if LOk then
    Check('AES-256-GCM roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestChaCha20_Roundtrip;
var
  LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000002');
  LAAD := HexToBytes('1703030010');
  LPlain := HexToBytes('48656c6c6f');

  LOk := TryTLS13AEADEncrypt(CS_CHACHA20, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
  Check('ChaCha20-Poly1305 encrypt ok', LOk);
  if not LOk then begin WriteLn('    ', LError); Exit; end;

  LOk := TryTLS13AEADDecrypt(CS_CHACHA20, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
  Check('ChaCha20-Poly1305 decrypt ok', LOk);
  if LOk then
    Check('ChaCha20-Poly1305 roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestTamperedEncrypted;
var
  LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LNonce := HexToBytes('5d313eb2671276ee13000b30');
  LAAD := HexToBytes('1703030010');
  LPlain := HexToBytes('aabbccdd');

  TryTLS13AEADEncrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
  LEncrypted[0] := LEncrypted[0] xor $FF;

  LOk := TryTLS13AEADDecrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
  Check('tampered encrypted rejected', not LOk);
end;

procedure TestUnsupportedCipher;
var
  LKey, LNonce, LAAD, LPlain, LEncrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LNonce := HexToBytes('5d313eb2671276ee13000b30');
  SetLength(LAAD, 0);
  LPlain := HexToBytes('aa');

  LOk := TryTLS13AEADEncrypt($FFFF, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
  Check('unsupported cipher rejected', not LOk);
  Check('error mentions unsupported', Pos('upport', LError) > 0);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 AEAD Dispatch Tests ===');
  WriteLn;

  TestIsSupported;
  TestTagLength;
  TestAES128GCM_Roundtrip;
  TestAES256GCM_Roundtrip;
  TestChaCha20_Roundtrip;
  TestTamperedEncrypted;
  TestUnsupportedCipher;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
