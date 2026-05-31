program test_rsa_simple;

{******************************************************************************}
{  RSA Simple Integration Tests                                                }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestRSAKeyGeneration;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  KeySize: Integer;
begin
  WriteLn;
  WriteLn('=== RSA Key Generation Tests ===');
  WriteLn;

  Rsa := RSA_new();
  Runner.Check('Create RSA structure', Rsa <> nil);

  if Rsa <> nil then
  begin
    Exponent := BN_new();
    if Exponent <> nil then
    begin
      if BN_set_word(Exponent, 65537) = 1 then
      begin
        if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) = 1 then
        begin
          KeySize := RSA_size(Rsa);
          Runner.Check('Generate 2048-bit RSA key', True,
                  Format('Generated key with size %d bytes (%d bits)',
                         [KeySize, KeySize * 8]));
        end
        else
          Runner.Check('Generate 2048-bit RSA key', False, 'RSA_generate_key_ex failed');
      end
      else
        Runner.Check('Set exponent', False);

      BN_free(Exponent);
    end
    else
      Runner.Check('Create exponent', False);

    RSA_free(Rsa);
  end;
end;

procedure TestRSASignVerify;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  Digest: array[0..31] of Byte;
  Signature: array[0..511] of Byte;
  SigLen: Cardinal;
  I: Integer;
  VerifyResult: Integer;
begin
  WriteLn;
  WriteLn('=== RSA Sign/Verify Tests ===');
  WriteLn;

  Rsa := RSA_new();
  if Rsa = nil then
  begin
    Runner.Check('Create RSA structure for signing', False);
    Exit;
  end;

  Exponent := BN_new();
  if Exponent = nil then
  begin
    RSA_free(Rsa);
    Runner.Check('Create exponent for signing', False);
    Exit;
  end;

  try
    if BN_set_word(Exponent, 65537) <> 1 then
    begin
      Runner.Check('Set exponent for signing', False);
      Exit;
    end;

    if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) <> 1 then
    begin
      Runner.Check('Generate key for signing', False);
      Exit;
    end;

    for I := 0 to 31 do
      Digest[I] := Byte(I);

    SigLen := SizeOf(Signature);
    if RSA_sign(NID_sha256, @Digest[0], 32, @Signature[0], @SigLen, Rsa) = 1 then
    begin
      Runner.Check('Sign digest', True, Format('Generated %d byte signature', [SigLen]));

      VerifyResult := RSA_verify(NID_sha256, @Digest[0], 32, @Signature[0], SigLen, Rsa);
      Runner.Check('Verify signature', VerifyResult = 1,
              Format('Verification result: %d', [VerifyResult]));
    end
    else
      Runner.Check('Sign digest', False, 'RSA_sign failed');

  finally
    BN_free(Exponent);
    RSA_free(Rsa);
  end;
end;

procedure TestRSAEncryptDecrypt;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  Plaintext: AnsiString;
  Ciphertext: array[0..511] of Byte;
  Decrypted: array[0..511] of Byte;
  CiphertextLen, DecryptedLen: Integer;
  DecryptedStr: AnsiString;
begin
  WriteLn;
  WriteLn('=== RSA Encrypt/Decrypt Tests ===');
  WriteLn;

  Rsa := RSA_new();
  if Rsa = nil then
  begin
    Runner.Check('Create RSA structure for encryption', False);
    Exit;
  end;

  Exponent := BN_new();
  if Exponent = nil then
  begin
    RSA_free(Rsa);
    Runner.Check('Create exponent for encryption', False);
    Exit;
  end;

  try
    if BN_set_word(Exponent, 65537) <> 1 then
    begin
      Runner.Check('Set exponent for encryption', False);
      Exit;
    end;

    if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) <> 1 then
    begin
      Runner.Check('Generate key for encryption', False);
      Exit;
    end;

    Plaintext := 'Hello RSA!';

    CiphertextLen := RSA_public_encrypt(Length(Plaintext), @Plaintext[1],
                                        @Ciphertext[0], Rsa, RSA_PKCS1_PADDING);

    if CiphertextLen >= 0 then
    begin
      Runner.Check('Encrypt data', True, Format('Encrypted to %d bytes', [CiphertextLen]));

      DecryptedLen := RSA_private_decrypt(CiphertextLen, @Ciphertext[0],
                                          @Decrypted[0], Rsa, RSA_PKCS1_PADDING);

      if DecryptedLen >= 0 then
      begin
        Runner.Check('Decrypt data', True, Format('Decrypted %d bytes', [DecryptedLen]));

        SetString(DecryptedStr, PAnsiChar(@Decrypted[0]), DecryptedLen);
        Runner.Check('Decrypted data matches', DecryptedStr = Plaintext,
                Format('Original: "%s", Decrypted: "%s"', [Plaintext, DecryptedStr]));
      end
      else
        Runner.Check('Decrypt data', False, Format('RSA_private_decrypt returned %d', [DecryptedLen]));
    end
    else
      Runner.Check('Encrypt data', False, Format('RSA_public_encrypt returned %d', [CiphertextLen]));

  finally
    BN_free(Exponent);
    RSA_free(Rsa);
  end;
end;

begin
  WriteLn('RSA Simple Integration Tests');
  WriteLn('===========================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmRSA]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;

    TestRSAKeyGeneration;
    TestRSASignVerify;
    TestRSAEncryptDecrypt;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
