program test_rsa_integration;

{******************************************************************************}
{  RSA Integration Tests                                                       }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.init,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

type
  size_t = NativeUInt;

var
  Runner: TSimpleTestRunner;

procedure TestRSAKeyGen2048;
var
  Key: PEVP_PKEY;
  Ctx: PEVP_PKEY_CTX;
begin
  WriteLn;
  WriteLn('=== RSA 2048-bit Key Generation ===');

  if not Assigned(EVP_PKEY_CTX_new_id) then
  begin
    Runner.Check('EVP_PKEY_CTX_new_id available', False);
    Exit;
  end;

  Ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
  Runner.Check('Create PKEY context', Ctx <> nil);
  if Ctx = nil then Exit;

  try
    Runner.Check('Initialize keygen', EVP_PKEY_keygen_init(Ctx) > 0);
    Runner.Check('Set key size to 2048', EVP_PKEY_CTX_set_rsa_keygen_bits(Ctx, 2048) > 0);

    Key := nil;
    Runner.Check('Generate key', EVP_PKEY_keygen(Ctx, Key) > 0);
    Runner.Check('Key is valid', Key <> nil);

    if Key <> nil then
      EVP_PKEY_free(Key);
  finally
    EVP_PKEY_CTX_free(Ctx);
  end;
end;

procedure TestRSASignVerify;
var
  Key: PEVP_PKEY;
  Ctx: PEVP_PKEY_CTX;
  SignCtx, VerifyCtx: PEVP_MD_CTX;
  Signature: array[0..511] of Byte;
  SigLen: size_t;
  Data: AnsiString;
  MD: PEVP_MD;
begin
  WriteLn;
  WriteLn('=== RSA Sign/Verify ===');

  Ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
  if Ctx = nil then
  begin
    Runner.Check('Create context', False);
    Exit;
  end;

  try
    if (EVP_PKEY_keygen_init(Ctx) <= 0) or
       (EVP_PKEY_CTX_set_rsa_keygen_bits(Ctx, 2048) <= 0) then
    begin
      Runner.Check('Initialize keygen', False);
      Exit;
    end;

    Key := nil;
    if EVP_PKEY_keygen(Ctx, Key) <= 0 then
    begin
      Runner.Check('Generate key', False);
      Exit;
    end;

    try
      MD := EVP_sha256();
      Runner.Check('Get SHA-256', MD <> nil);
      if MD = nil then Exit;

      Data := 'Test data for RSA signature';
      SignCtx := EVP_MD_CTX_new();
      Runner.Check('Create sign context', SignCtx <> nil);
      if SignCtx = nil then Exit;

      try
        Runner.Check('DigestSignInit', EVP_DigestSignInit(SignCtx, nil, MD, nil, Key) > 0);
        Runner.Check('DigestSignUpdate', EVP_DigestSignUpdate(SignCtx, @Data[1], Length(Data)) > 0);

        SigLen := 0;
        Runner.Check('Get signature length', EVP_DigestSignFinal(SignCtx, nil, SigLen) > 0);

        if SigLen > SizeOf(Signature) then
        begin
          Runner.Check('Signature fits buffer', False);
          Exit;
        end;

        Runner.Check('DigestSignFinal', EVP_DigestSignFinal(SignCtx, @Signature[0], SigLen) > 0);
        WriteLn('  Signature length: ', SigLen, ' bytes');

        VerifyCtx := EVP_MD_CTX_new();
        if VerifyCtx <> nil then
        begin
          try
            Runner.Check('DigestVerifyInit', EVP_DigestVerifyInit(VerifyCtx, nil, MD, nil, Key) > 0);
            Runner.Check('DigestVerifyUpdate', EVP_DigestVerifyUpdate(VerifyCtx, @Data[1], Length(Data)) > 0);
            Runner.Check('DigestVerifyFinal', EVP_DigestVerifyFinal(VerifyCtx, @Signature[0], SigLen) = 1);
          finally
            EVP_MD_CTX_free(VerifyCtx);
          end;
        end;
      finally
        EVP_MD_CTX_free(SignCtx);
      end;
    finally
      EVP_PKEY_free(Key);
    end;
  finally
    EVP_PKEY_CTX_free(Ctx);
  end;
end;

procedure TestRSAEncryptDecrypt;
var
  Key: PEVP_PKEY;
  Ctx: PEVP_PKEY_CTX;
  EncCtx, DecCtx: PEVP_PKEY_CTX;
  Plaintext: AnsiString;
  Ciphertext: array[0..511] of Byte;
  Decrypted: array[0..511] of Byte;
  CipherLen, DecryptLen: size_t;
begin
  WriteLn;
  WriteLn('=== RSA Encrypt/Decrypt ===');

  Ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
  if Ctx = nil then
  begin
    Runner.Check('Create context', False);
    Exit;
  end;

  try
    if (EVP_PKEY_keygen_init(Ctx) <= 0) or
       (EVP_PKEY_CTX_set_rsa_keygen_bits(Ctx, 2048) <= 0) then
      Exit;

    Key := nil;
    if EVP_PKEY_keygen(Ctx, Key) <= 0 then Exit;
    if Key = nil then Exit;

    try
      Plaintext := 'Test data for RSA encryption';

      EncCtx := EVP_PKEY_CTX_new(Key, nil);
      Runner.Check('Create encrypt context', EncCtx <> nil);
      if EncCtx = nil then Exit;

      try
        Runner.Check('Encrypt init', EVP_PKEY_encrypt_init(EncCtx) > 0);
        Runner.Check('Set OAEP padding', EVP_PKEY_CTX_set_rsa_padding(EncCtx, RSA_PKCS1_OAEP_PADDING) > 0);

        CipherLen := 0;
        Runner.Check('Get ciphertext length', EVP_PKEY_encrypt(EncCtx, nil, CipherLen, @Plaintext[1], Length(Plaintext)) > 0);

        if CipherLen > SizeOf(Ciphertext) then
        begin
          Runner.Check('Ciphertext fits buffer', False);
          Exit;
        end;

        Runner.Check('Encrypt', EVP_PKEY_encrypt(EncCtx, @Ciphertext[0], CipherLen, @Plaintext[1], Length(Plaintext)) > 0);
        WriteLn('  Encrypted ', Length(Plaintext), ' bytes -> ', CipherLen, ' bytes');

        DecCtx := EVP_PKEY_CTX_new(Key, nil);
        if DecCtx <> nil then
        begin
          try
            Runner.Check('Decrypt init', EVP_PKEY_decrypt_init(DecCtx) > 0);
            Runner.Check('Set OAEP padding for decrypt', EVP_PKEY_CTX_set_rsa_padding(DecCtx, RSA_PKCS1_OAEP_PADDING) > 0);

            DecryptLen := 0;
            Runner.Check('Get decrypted length', EVP_PKEY_decrypt(DecCtx, nil, DecryptLen, @Ciphertext[0], CipherLen) > 0);

            if DecryptLen > SizeOf(Decrypted) then
            begin
              Runner.Check('Decrypted fits buffer', False);
              Exit;
            end;

            Runner.Check('Decrypt', EVP_PKEY_decrypt(DecCtx, @Decrypted[0], DecryptLen, @Ciphertext[0], CipherLen) > 0);
            Runner.Check('Decrypted matches original',
                    (DecryptLen = size_t(Length(Plaintext))) and CompareMem(@Decrypted[0], @Plaintext[1], DecryptLen));
          finally
            EVP_PKEY_CTX_free(DecCtx);
          end;
        end;
      finally
        EVP_PKEY_CTX_free(EncCtx);
      end;
    finally
      EVP_PKEY_free(Key);
    end;
  finally
    EVP_PKEY_CTX_free(Ctx);
  end;
end;

begin
  WriteLn('RSA Integration Tests');
  WriteLn('=====================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmRSA, osmEVP]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    try
      InitializeOpenSSL;
    except
      on E: Exception do
      begin
        WriteLn('ERROR: Failed to initialize OpenSSL: ', E.Message);
        Halt(1);
      end;
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestRSAKeyGen2048;
    TestRSASignVerify;
    TestRSAEncryptDecrypt;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
