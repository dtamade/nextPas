program test_facade;
{$mode ObjFPC}{$H+}
uses
  SysUtils,
  nextpas.core.crypto.hash, nextpas.core.crypto.hmac, nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519, nextpas.core.crypto.aesgcm, nextpas.core.crypto.aescbc,
  nextpas.core.crypto.constant_time, nextpas.core.tls.tls13.chacha20poly1305;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin
  if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', N); Inc(GFail); end;
end;

var
  LKey, LPub, LMsg, LSig, LCT, LTag, LNonce, LIV, LPT: TBytes;
  LErr: string;
  LOk: Boolean;
begin
  WriteLn('=== Crypto Facade Import Test ===');
  WriteLn;

  // Verify all sub-modules accessible via single import
  WriteLn('--- Hash ---');
  Check(Length(SHA256(TBytes.Create(1,2,3))) = 32, 'SHA256 returns 32 bytes');
  Check(Length(SHA384(TBytes.Create(1,2,3))) = 48, 'SHA384 returns 48 bytes');
  Check(Length(SHA512(TBytes.Create(1,2,3))) = 64, 'SHA512 returns 64 bytes');

  WriteLn('--- HMAC ---');
  SetLength(LKey, 32);
  Check(Length(HMAC_SHA256(LKey, TBytes.Create(1))) = 32, 'HMAC_SHA256 works');

  WriteLn('--- X25519 ---');
  GenerateX25519KeyPair(LKey, LPub);
  Check(Length(LKey) = 32, 'X25519 key generated');
  Check(Length(LPub) = 32, 'X25519 pub generated');

  WriteLn('--- Ed25519 ---');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $42);
  LOk := TryEd25519Sign(LKey, TBytes.Create(1,2,3), LSig, LErr);
  Check(LOk, 'TryEd25519Sign succeeds');
  Check(Length(LSig) = 64, 'Ed25519 sig is 64 bytes');
  LOk := TryEd25519PublicKeyFromPrivate(LKey, LPub, LErr);
  Check(LOk, 'TryEd25519PublicKeyFromPrivate succeeds');
  Check(Ed25519Verify(LPub, TBytes.Create(1,2,3), LSig), 'Ed25519 verify ok');

  WriteLn('--- AES-GCM ---');
  SetLength(LKey, 16); SetLength(LIV, 12);
  LOk := PurePascalAESGCMEncrypt(LKey, LIV, TBytes.Create(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16), nil, LCT, LTag);
  Check(LOk, 'AES-GCM encrypt ok');

  WriteLn('--- AES-CBC ---');
  SetLength(LKey, 16); SetLength(LIV, 16);
  SetLength(LPT, 16); FillChar(LPT[0], 16, $AA);
  LOk := TryAESCBCEncryptNoPadding(LKey, LIV, LPT, LCT, LErr);
  Check(LOk, 'TryAESCBCEncrypt ok');
  LOk := TryAESCBCDecryptNoPadding(LKey, LIV, LCT, LPT, LErr);
  Check(LOk, 'TryAESCBCDecrypt ok');

  WriteLn('--- ChaCha20-Poly1305 ---');
  SetLength(LKey, 32); SetLength(LNonce, 12);
  LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, nil, TBytes.Create(1,2,3), LCT, LTag);
  Check(LOk, 'ChaCha20 encrypt ok');

  WriteLn('--- Constant-Time ---');
  Check(TConstantTime.CompareBytes(TBytes.Create(1,2,3), TBytes.Create(1,2,3)) = 1, 'CT compare equal');
  Check(TConstantTime.CompareBytes(TBytes.Create(1,2,3), TBytes.Create(1,2,4)) = 0, 'CT compare diff');

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
