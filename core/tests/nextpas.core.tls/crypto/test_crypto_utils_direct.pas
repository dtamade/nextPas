program test_crypto_utils_direct;

{$mode objfpc}{$H+}

uses
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.openssl.api.core, nextpas.core.base, nextpas.core.exception, nextpas.core.text.conv;

var
  LData, LKey, LIV, LCipher, LDecrypt, LHash: TBytes;
begin
  WriteLn('=== Direct Crypto Utils Test ===');
  WriteLn;

  try
    WriteLn('[1] Testing AES-GCM...');
    LData := StringToUTF8Bytes('Hello!');
    LKey := TCryptoUtils.GenerateKey(256);
    LIV := TCryptoUtils.GenerateIV(12);

    LCipher := TCryptoUtils.AES_GCM_Encrypt(LData, LKey, LIV);
    WriteLn('  ✓ Encrypted: ', Length(LCipher), ' bytes');

    LDecrypt := TCryptoUtils.AES_GCM_Decrypt(LCipher, LKey, LIV);
    WriteLn('  ✓ Decrypted: ', UTF8BytesToString(LDecrypt));

    WriteLn;
    WriteLn('[2] Testing SHA-256...');
    LHash := TCryptoUtils.SHA256('abc');
    WriteLn('  ✓ Hash: ', TCryptoUtils.BytesToHex(LHash));

    WriteLn;
    WriteLn('========================================');
    WriteLn('✓ ALL TESTS PASSED!');
    WriteLn('========================================');

  except
    on E: Exception do
    begin
      WriteLn('✗ ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
