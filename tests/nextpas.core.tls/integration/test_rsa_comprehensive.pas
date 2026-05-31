program test_rsa_comprehensive;

{******************************************************************************}
{  RSA Comprehensive Integration Tests                                         }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, Math,
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

// Simple fake hash function for testing
function CreateTestHash(const Data: PByte; Len: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, 32);
  // Create a simple deterministic "hash" for testing
  for I := 0 to 31 do
    Result[I] := Byte((I * 7 + Len) mod 256);
  // Mix in some data if available
  if (Data <> nil) and (Len > 0) then
  begin
    for I := 0 to Min(Len-1, 31) do
      Result[I] := Result[I] xor Data[I];
  end;
end;

procedure TestRSAKeyGeneration;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  KeySize, Bits: Integer;
begin
  WriteLn;
  WriteLn('=== RSA Key Generation Tests ===');

  // Test 1: 1024-bit key (for compatibility testing only)
  Rsa := RSA_new();
  if Rsa <> nil then
  begin
    Exponent := BN_new();
    if BN_set_word(Exponent, RSA_F4) = 1 then
    begin
      if RSA_generate_key_ex(Rsa, 1024, Exponent, nil) = 1 then
      begin
        KeySize := RSA_size(Rsa);
        Bits := RSA_bits(Rsa);
        Runner.Check('Generate 1024-bit RSA key', (KeySize = 128) and (Bits = 1024),
                Format('Key size: %d bytes (%d bits)', [KeySize, Bits]));
      end
      else
        Runner.Check('Generate 1024-bit RSA key', False, 'Key generation failed');
    end;
    BN_free(Exponent);
    RSA_free(Rsa);
  end;

  // Test 2: 2048-bit key (recommended)
  Rsa := RSA_new();
  if Rsa <> nil then
  begin
    Exponent := BN_new();
    if BN_set_word(Exponent, RSA_F4) = 1 then
    begin
      if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) = 1 then
      begin
        KeySize := RSA_size(Rsa);
        Bits := RSA_bits(Rsa);
        Runner.Check('Generate 2048-bit RSA key', (KeySize = 256) and (Bits = 2048),
                Format('Key size: %d bytes (%d bits)', [KeySize, Bits]));
      end
      else
        Runner.Check('Generate 2048-bit RSA key', False, 'Key generation failed');
    end;
    BN_free(Exponent);
    RSA_free(Rsa);
  end;

  // Test 3: 4096-bit key (high security)
  Rsa := RSA_new();
  if Rsa <> nil then
  begin
    Exponent := BN_new();
    if BN_set_word(Exponent, RSA_F4) = 1 then
    begin
      WriteLn('  Generating 4096-bit key (this may take several seconds)...');
      if RSA_generate_key_ex(Rsa, 4096, Exponent, nil) = 1 then
      begin
        KeySize := RSA_size(Rsa);
        Bits := RSA_bits(Rsa);
        Runner.Check('Generate 4096-bit RSA key', (KeySize = 512) and (Bits = 4096),
                Format('Key size: %d bytes (%d bits)', [KeySize, Bits]));
      end
      else
        Runner.Check('Generate 4096-bit RSA key', False, 'Key generation failed');
    end;
    BN_free(Exponent);
    RSA_free(Rsa);
  end;

  // Test 4: Key validation
  Rsa := RSA_new();
  if Rsa <> nil then
  begin
    Exponent := BN_new();
    if BN_set_word(Exponent, RSA_F4) = 1 then
    begin
      if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) = 1 then
      begin
        Runner.Check('Validate RSA key', RSA_check_key(Rsa) = 1,
                'RSA_check_key validation');
      end;
    end;
    BN_free(Exponent);
    RSA_free(Rsa);
  end;
end;

procedure TestRSAParameterAccess;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  n, e, d: PBIGNUM;
  p, q: PBIGNUM;
  n_bits, e_bits: Integer;
begin
  WriteLn;
  WriteLn('=== RSA Parameter Access Tests ===');

  Rsa := RSA_new();
  if Rsa = nil then
  begin
    Runner.Check('Create RSA for parameter test', False);
    Exit;
  end;

  Exponent := BN_new();
  if BN_set_word(Exponent, RSA_F4) = 1 then
  begin
    if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) = 1 then
    begin
      // Test 5: Access public key components (n, e)
      n := nil;
      e := nil;
      d := nil;
      RSA_get0_key(Rsa, @n, @e, @d);
      Runner.Check('Access RSA key components', (n <> nil) and (e <> nil) and (d <> nil),
              'n, e, d pointers retrieved');

      if (n <> nil) and (e <> nil) then
      begin
        n_bits := BN_num_bits(n);
        e_bits := BN_num_bits(e);
        Runner.Check('Verify modulus size', n_bits = 2048,
                Format('Modulus: %d bits', [n_bits]));
        Runner.Check('Verify exponent', e_bits = 17,
                Format('Exponent: %d bits (65537 = 2^16+1)', [e_bits]));
      end;

      // Test 6: Access private key factors (p, q)
      p := nil;
      q := nil;
      RSA_get0_factors(Rsa, @p, @q);
      Runner.Check('Access RSA factors', (p <> nil) and (q <> nil),
              'p, q factors retrieved');

      if (p <> nil) and (q <> nil) then
      begin
        Runner.Check('Verify factor sizes',
                (BN_num_bits(p) > 1000) and (BN_num_bits(q) > 1000),
                Format('p: %d bits, q: %d bits', [BN_num_bits(p), BN_num_bits(q)]));
      end;

      // Test 7: Individual accessors
      if Assigned(RSA_get0_n) and Assigned(RSA_get0_e) and Assigned(RSA_get0_d) then
      begin
        n := RSA_get0_n(Rsa);
        e := RSA_get0_e(Rsa);
        d := RSA_get0_d(Rsa);
        Runner.Check('Individual parameter accessors',
                (n <> nil) and (e <> nil) and (d <> nil),
                'RSA_get0_n/e/d functions work');
      end
      else
        Runner.Check('Individual parameter accessors', False, 'Functions not available');
    end;
  end;

  BN_free(Exponent);
  RSA_free(Rsa);
end;

procedure TestRSASignVerify;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  data, hash: TBytes;
  sig: array[0..511] of Byte;
  siglen: Cardinal;
  tampered_data, tampered_hash: TBytes;
begin
  WriteLn;
  WriteLn('=== RSA Sign/Verify Tests ===');

  // Generate key
  Rsa := RSA_new();
  if Rsa = nil then Exit;

  Exponent := BN_new();
  if BN_set_word(Exponent, RSA_F4) <> 1 then
  begin
    BN_free(Exponent);
    RSA_free(Rsa);
    Exit;
  end;

  if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) <> 1 then
  begin
    BN_free(Exponent);
    RSA_free(Rsa);
    Exit;
  end;

  try
    // Test 8: Basic signing
    SetLength(data, 100);
    FillChar(data[0], 100, $AA);
    hash := CreateTestHash(@data[0], Length(data));

    siglen := RSA_size(Rsa);
    if RSA_sign(NID_sha256, @hash[0], Length(hash), @sig[0], @siglen, Rsa) = 1 then
    begin
      Runner.Check('RSA sign operation', True,
              Format('Signature: %d bytes', [siglen]));

      // Test 9: Verify correct signature
      Runner.Check('RSA verify correct signature',
              RSA_verify(NID_sha256, @hash[0], Length(hash), @sig[0], siglen, Rsa) = 1);

      // Test 10: Detect data tampering
      tampered_data := Copy(data);
      tampered_data[0] := tampered_data[0] xor $FF;
      tampered_hash := CreateTestHash(@tampered_data[0], Length(tampered_data));
      Runner.Check('Detect data tampering',
              RSA_verify(NID_sha256, @tampered_hash[0], Length(tampered_hash),
                        @sig[0], siglen, Rsa) <> 1,
              'Tampered data correctly rejected');

      // Test 11: Detect signature tampering
      sig[10] := sig[10] xor $FF;
      Runner.Check('Detect signature tampering',
              RSA_verify(NID_sha256, @hash[0], Length(hash), @sig[0], siglen, Rsa) <> 1,
              'Tampered signature correctly rejected');
    end
    else
      Runner.Check('RSA sign operation', False);

  finally
    BN_free(Exponent);
    RSA_free(Rsa);
  end;
end;

procedure TestRSAEncryptDecrypt;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  plaintext: AnsiString;
  ciphertext: array[0..511] of Byte;
  decrypted: array[0..511] of Byte;
  ct_len, dec_len: Integer;
  recovered: AnsiString;
begin
  WriteLn;
  WriteLn('=== RSA Encrypt/Decrypt Tests ===');

  // Generate key
  Rsa := RSA_new();
  if Rsa = nil then Exit;

  Exponent := BN_new();
  if BN_set_word(Exponent, RSA_F4) <> 1 then
  begin
    BN_free(Exponent);
    RSA_free(Rsa);
    Exit;
  end;

  if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) <> 1 then
  begin
    BN_free(Exponent);
    RSA_free(Rsa);
    Exit;
  end;

  try
    // Test 12: PKCS#1 v1.5 padding encryption
    plaintext := 'Hello RSA with PKCS1 padding!';
    ct_len := RSA_public_encrypt(Length(plaintext), @plaintext[1],
                                  @ciphertext[0], Rsa, RSA_PKCS1_PADDING);

    if ct_len > 0 then
    begin
      Runner.Check('RSA PKCS#1 encrypt', True,
              Format('Encrypted %d bytes to %d bytes', [Length(plaintext), ct_len]));

      dec_len := RSA_private_decrypt(ct_len, @ciphertext[0],
                                     @decrypted[0], Rsa, RSA_PKCS1_PADDING);

      if dec_len > 0 then
      begin
        SetString(recovered, PAnsiChar(@decrypted[0]), dec_len);
        Runner.Check('RSA PKCS#1 decrypt', recovered = plaintext,
                Format('Recovered: "%s"', [recovered]));
      end
      else
        Runner.Check('RSA PKCS#1 decrypt', False);
    end
    else
      Runner.Check('RSA PKCS#1 encrypt', False);

    // Test 13: OAEP padding encryption
    plaintext := 'Hello RSA with OAEP!';
    ct_len := RSA_public_encrypt(Length(plaintext), @plaintext[1],
                                  @ciphertext[0], Rsa, RSA_PKCS1_OAEP_PADDING);

    if ct_len > 0 then
    begin
      Runner.Check('RSA OAEP encrypt', True,
              Format('Encrypted %d bytes to %d bytes', [Length(plaintext), ct_len]));

      dec_len := RSA_private_decrypt(ct_len, @ciphertext[0],
                                     @decrypted[0], Rsa, RSA_PKCS1_OAEP_PADDING);

      if dec_len > 0 then
      begin
        SetString(recovered, PAnsiChar(@decrypted[0]), dec_len);
        Runner.Check('RSA OAEP decrypt', recovered = plaintext,
                Format('Recovered: "%s"', [recovered]));
      end
      else
        Runner.Check('RSA OAEP decrypt', False);
    end
    else
      Runner.Check('RSA OAEP encrypt', False);

    // Test 14: Maximum plaintext size for PKCS#1
    plaintext := StringOfChar('X', RSA_size(Rsa) - RSA_PKCS1_PADDING_SIZE);
    ct_len := RSA_public_encrypt(Length(plaintext), @plaintext[1],
                                  @ciphertext[0], Rsa, RSA_PKCS1_PADDING);

    if ct_len > 0 then
    begin
      dec_len := RSA_private_decrypt(ct_len, @ciphertext[0],
                                     @decrypted[0], Rsa, RSA_PKCS1_PADDING);
      if dec_len > 0 then
      begin
        SetString(recovered, PAnsiChar(@decrypted[0]), dec_len);
        Runner.Check('RSA max plaintext size (PKCS#1)',
                Length(recovered) = Length(plaintext),
                Format('Max size: %d bytes', [Length(plaintext)]));
      end;
    end
    else
      Runner.Check('RSA max plaintext size (PKCS#1)', False);

  finally
    BN_free(Exponent);
    RSA_free(Rsa);
  end;
end;

procedure TestRSAPrivateEncrypt;
var
  Rsa: PRSA;
  Exponent: PBIGNUM;
  plaintext: AnsiString;
  ciphertext: array[0..511] of Byte;
  decrypted: array[0..511] of Byte;
  ct_len, dec_len: Integer;
  recovered: AnsiString;
begin
  WriteLn;
  WriteLn('=== RSA Private Encrypt Tests ===');

  // Generate key
  Rsa := RSA_new();
  if Rsa = nil then Exit;

  Exponent := BN_new();
  if BN_set_word(Exponent, RSA_F4) <> 1 then
  begin
    BN_free(Exponent);
    RSA_free(Rsa);
    Exit;
  end;

  if RSA_generate_key_ex(Rsa, 2048, Exponent, nil) <> 1 then
  begin
    BN_free(Exponent);
    RSA_free(Rsa);
    Exit;
  end;

  try
    // Test 15: Private encrypt / Public decrypt (for signing simulation)
    plaintext := 'Test private encryption';
    ct_len := RSA_private_encrypt(Length(plaintext), @plaintext[1],
                                   @ciphertext[0], Rsa, RSA_PKCS1_PADDING);

    if ct_len > 0 then
    begin
      Runner.Check('RSA private encrypt', True,
              Format('Encrypted %d bytes', [ct_len]));

      dec_len := RSA_public_decrypt(ct_len, @ciphertext[0],
                                    @decrypted[0], Rsa, RSA_PKCS1_PADDING);

      if dec_len > 0 then
      begin
        SetString(recovered, PAnsiChar(@decrypted[0]), dec_len);
        Runner.Check('RSA public decrypt', recovered = plaintext,
                Format('Recovered: "%s"', [recovered]));
      end
      else
        Runner.Check('RSA public decrypt', False);
    end
    else
      Runner.Check('RSA private encrypt', False);

  finally
    BN_free(Exponent);
    RSA_free(Rsa);
  end;
end;

begin
  WriteLn('RSA Comprehensive Integration Tests');
  WriteLn('====================================');
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

    // Run test suites
    TestRSAKeyGeneration;         // Tests 1-4
    TestRSAParameterAccess;       // Tests 5-7
    TestRSASignVerify;            // Tests 8-11
    TestRSAEncryptDecrypt;        // Tests 12-14
    TestRSAPrivateEncrypt;        // Tests 15-16

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
