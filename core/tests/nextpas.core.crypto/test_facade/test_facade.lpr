program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.hash, nextpas.core.crypto.hmac, nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519, nextpas.core.crypto.aesgcm, nextpas.core.crypto.aescbc,
  nextpas.core.crypto.constant_time, nextpas.core.tls.tls13.chacha20poly1305,
  nextpas.core.test;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('crypto.facade');

  LSuite.Test('hash functions', procedure begin
    CheckEqual(32, Length(SHA256(TBytes.Create(1,2,3))));
    CheckEqual(48, Length(SHA384(TBytes.Create(1,2,3))));
    CheckEqual(64, Length(SHA512(TBytes.Create(1,2,3))));
  end);

  LSuite.Test('HMAC', procedure
  var LKey: TBytes;
  begin
    SetLength(LKey, 32);
    CheckEqual(32, Length(HMAC_SHA256(LKey, TBytes.Create(1))));
  end);

  LSuite.Test('X25519', procedure
  var LKey, LPub: TBytes;
  begin
    GenerateX25519KeyPair(LKey, LPub);
    CheckEqual(32, Length(LKey));
    CheckEqual(32, Length(LPub));
  end);

  LSuite.Test('Ed25519', procedure
  var LKey, LSig, LPub: TBytes; LErr: string; LOk: Boolean;
  begin
    SetLength(LKey, 32); FillChar(LKey[0], 32, $42);
    LOk := TryEd25519Sign(LKey, TBytes.Create(1,2,3), LSig, LErr);
    CheckTrue(LOk, 'TryEd25519Sign');
    CheckEqual(64, Length(LSig));
    LOk := TryEd25519PublicKeyFromPrivate(LKey, LPub, LErr);
    CheckTrue(LOk, 'TryEd25519PublicKeyFromPrivate');
    CheckTrue(Ed25519Verify(LPub, TBytes.Create(1,2,3), LSig));
  end);

  LSuite.Test('AES-GCM', procedure
  var LKey, LIV, LCT, LTag: TBytes; LOk: Boolean;
  begin
    SetLength(LKey, 16); SetLength(LIV, 12);
    LOk := PurePascalAESGCMEncrypt(LKey, LIV,
      TBytes.Create(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16), nil, LCT, LTag);
    CheckTrue(LOk);
  end);

  LSuite.Test('AES-CBC', procedure
  var LKey, LIV, LPT, LCT: TBytes; LErr: string; LOk: Boolean;
  begin
    SetLength(LKey, 16); SetLength(LIV, 16);
    SetLength(LPT, 16); FillChar(LPT[0], 16, $AA);
    LOk := TryAESCBCEncryptNoPadding(LKey, LIV, LPT, LCT, LErr);
    CheckTrue(LOk, 'encrypt');
    LOk := TryAESCBCDecryptNoPadding(LKey, LIV, LCT, LPT, LErr);
    CheckTrue(LOk, 'decrypt');
  end);

  LSuite.Test('ChaCha20-Poly1305', procedure
  var LKey, LNonce, LCT, LTag: TBytes; LOk: Boolean;
  begin
    SetLength(LKey, 32); SetLength(LNonce, 12);
    LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, nil, TBytes.Create(1,2,3), LCT, LTag);
    CheckTrue(LOk);
  end);

  LSuite.Test('constant-time compare', procedure begin
    CheckEqual(1, TConstantTime.CompareBytes(TBytes.Create(1,2,3), TBytes.Create(1,2,3)));
    CheckEqual(0, TConstantTime.CompareBytes(TBytes.Create(1,2,3), TBytes.Create(1,2,4)));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.facade');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
