program test_dsa_simple;

{******************************************************************************}
{  DSA Simple Integration Tests                                                }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.dsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestDSAKeyGeneration;
var
  Dsa: PDSA;
  KeyBits: Integer;
begin
  WriteLn;
  WriteLn('=== DSA Key Generation Tests ===');

  // Test 1024-bit DSA key generation (minimum for DSA)
  Dsa := DSA_new();
  Runner.Check('Create DSA structure', Dsa <> nil);

  if Dsa <> nil then
  begin
    // Generate 1024-bit parameters
    if DSA_generate_parameters_ex(Dsa, 1024, nil, 0, nil, nil, nil) = 1 then
    begin
      Runner.Check('Generate 1024-bit DSA parameters', True);

      // Generate key pair
      if DSA_generate_key(Dsa) = 1 then
      begin
        KeyBits := DSA_bits(Dsa);
        Runner.Check('Generate DSA key pair', True,
                Format('Key size: %d bits', [KeyBits]));
        Runner.Check('Verify key size', KeyBits = 1024);
      end
      else
        Runner.Check('Generate DSA key pair', False);
    end
    else
      Runner.Check('Generate 1024-bit DSA parameters', False);

    DSA_free(Dsa);
  end;

  // Test 2048-bit DSA key (recommended size)
  Dsa := DSA_new();
  if Dsa <> nil then
  begin
    if DSA_generate_parameters_ex(Dsa, 2048, nil, 0, nil, nil, nil) = 1 then
    begin
      if DSA_generate_key(Dsa) = 1 then
      begin
        KeyBits := DSA_bits(Dsa);
        Runner.Check('Generate 2048-bit DSA key', KeyBits = 2048,
                Format('Key size: %d bits', [KeyBits]));
      end
      else
        Runner.Check('Generate 2048-bit DSA key', False);
    end
    else
      Runner.Check('Generate 2048-bit DSA parameters', False);

    DSA_free(Dsa);
  end;
end;

procedure TestDSASignVerify;
var
  Dsa: PDSA;
  Digest: array[0..19] of Byte;  // SHA-1 hash (20 bytes for DSA)
  Signature: array[0..255] of Byte;
  SigLen: Cardinal;
  I: Integer;
  VerifyResult: Integer;
begin
  WriteLn;
  WriteLn('=== DSA Sign/Verify Tests ===');

  // Generate test key
  Dsa := DSA_new();
  if Dsa = nil then
  begin
    Runner.Check('Create DSA structure for signing', False);
    Exit;
  end;

  try
    // Generate parameters and key (using 1024-bit for speed)
    if DSA_generate_parameters_ex(Dsa, 1024, nil, 0, nil, nil, nil) <> 1 then
    begin
      Runner.Check('Generate DSA parameters for signing', False);
      Exit;
    end;

    if DSA_generate_key(Dsa) <> 1 then
    begin
      Runner.Check('Generate DSA key for signing', False);
      Exit;
    end;

    Runner.Check('Generate DSA key for signing', True);

    // Create fake digest (normally SHA-1 output)
    for I := 0 to 19 do
      Digest[I] := Byte(I);

    // Sign the digest
    SigLen := SizeOf(Signature);
    if DSA_sign(0, @Digest[0], 20, @Signature[0], @SigLen, Dsa) = 1 then
    begin
      Runner.Check('Sign digest', True, Format('Generated %d byte signature', [SigLen]));

      // Verify the signature
      VerifyResult := DSA_verify(0, @Digest[0], 20, @Signature[0], SigLen, Dsa);
      Runner.Check('Verify signature', VerifyResult = 1,
              Format('Verification result: %d', [VerifyResult]));

      // Test tamper detection: modify digest
      Digest[0] := Digest[0] xor $FF;
      VerifyResult := DSA_verify(0, @Digest[0], 20, @Signature[0], SigLen, Dsa);
      Runner.Check('Detect tampered data', VerifyResult = 0,
              Format('Tamper detection result: %d (should be 0)', [VerifyResult]));
    end
    else
      Runner.Check('Sign digest', False, 'DSA_sign failed');

  finally
    DSA_free(Dsa);
  end;
end;

procedure TestDSADoSignVerify;
var
  Dsa: PDSA;
  Digest: array[0..19] of Byte;
  Sig: PDSA_SIG;
  I: Integer;
  VerifyResult: Integer;
  R, S: PBIGNUM;
begin
  WriteLn;
  WriteLn('=== DSA_do_sign/verify Tests ===');

  // Generate test key
  Dsa := DSA_new();
  if Dsa = nil then
  begin
    Runner.Check('Create DSA structure for do_sign', False);
    Exit;
  end;

  try
    // Generate parameters and key
    if DSA_generate_parameters_ex(Dsa, 1024, nil, 0, nil, nil, nil) <> 1 then
    begin
      Runner.Check('Generate DSA parameters for do_sign', False);
      Exit;
    end;

    if DSA_generate_key(Dsa) <> 1 then
    begin
      Runner.Check('Generate DSA key for do_sign', False);
      Exit;
    end;

    // Create digest
    for I := 0 to 19 do
      Digest[I] := Byte(19 - I);

    // Use DSA_do_sign to generate signature
    Sig := DSA_do_sign(@Digest[0], 20, Dsa);
    if Sig <> nil then
    begin
      Runner.Check('DSA_do_sign generate signature', True);

      // Get R and S values
      R := nil;
      S := nil;
      DSA_SIG_get0(Sig, @R, @S);
      Runner.Check('Get signature R and S values', (R <> nil) and (S <> nil));

      // Verify signature
      VerifyResult := DSA_do_verify(@Digest[0], 20, Sig, Dsa);
      Runner.Check('DSA_do_verify verification', VerifyResult = 1,
              Format('Verification result: %d', [VerifyResult]));

      DSA_SIG_free(Sig);
    end
    else
      Runner.Check('DSA_do_sign generate signature', False);

  finally
    DSA_free(Dsa);
  end;
end;

procedure TestDSASize;
var
  Dsa: PDSA;
  SigSize: Integer;
begin
  WriteLn;
  WriteLn('=== DSA Signature Size Tests ===');

  // 1024-bit
  Dsa := DSA_new();
  if Dsa <> nil then
  begin
    if (DSA_generate_parameters_ex(Dsa, 1024, nil, 0, nil, nil, nil) = 1) and
       (DSA_generate_key(Dsa) = 1) then
    begin
      SigSize := DSA_size(Dsa);
      Runner.Check('1024-bit signature size', SigSize > 0,
              Format('Max signature size: %d bytes', [SigSize]));
    end;
    DSA_free(Dsa);
  end;

  // 2048-bit
  Dsa := DSA_new();
  if Dsa <> nil then
  begin
    if (DSA_generate_parameters_ex(Dsa, 2048, nil, 0, nil, nil, nil) = 1) and
       (DSA_generate_key(Dsa) = 1) then
    begin
      SigSize := DSA_size(Dsa);
      Runner.Check('2048-bit signature size', SigSize > 0,
              Format('Max signature size: %d bytes', [SigSize]));
    end;
    DSA_free(Dsa);
  end;
end;

procedure TestDSAParameters;
var
  Dsa: PDSA;
  P, Q, G: PBIGNUM;
  PubKey, PrivKey: PBIGNUM;
begin
  WriteLn;
  WriteLn('=== DSA Parameter Access Tests ===');

  Dsa := DSA_new();
  if Dsa = nil then
  begin
    Runner.Check('Create DSA for parameter test', False);
    Exit;
  end;

  try
    // Generate parameters and key
    if (DSA_generate_parameters_ex(Dsa, 1024, nil, 0, nil, nil, nil) = 1) and
       (DSA_generate_key(Dsa) = 1) then
    begin
      // Get parameters (p, q, g)
      P := nil;
      Q := nil;
      G := nil;
      DSA_get0_pqg(Dsa, @P, @Q, @G);
      Runner.Check('Get DSA parameters (p, q, g)', (P <> nil) and (Q <> nil) and (G <> nil));

      // Get keys
      PubKey := nil;
      PrivKey := nil;
      DSA_get0_key(Dsa, @PubKey, @PrivKey);
      Runner.Check('Get DSA public key', PubKey <> nil);
      Runner.Check('Get DSA private key', PrivKey <> nil);

      // Individual accessors
      Runner.Check('Get DSA p parameter', DSA_get0_p(Dsa) <> nil);
      Runner.Check('Get DSA q parameter', DSA_get0_q(Dsa) <> nil);
      Runner.Check('Get DSA g parameter', DSA_get0_g(Dsa) <> nil);
      Runner.Check('Get DSA public key accessor', DSA_get0_pub_key(Dsa) <> nil);
      Runner.Check('Get DSA private key accessor', DSA_get0_priv_key(Dsa) <> nil);
    end
    else
      Runner.Check('Generate DSA for parameter test', False);

  finally
    DSA_free(Dsa);
  end;
end;

begin
  WriteLn('DSA (Digital Signature Algorithm) Integration Tests');
  WriteLn('===================================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmDSA]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Ensure BN and DSA functions are loaded
    LoadOpenSSLBN;
    LoadOpenSSLDSA;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn('NOTE: DSA key generation may take some time...');

    TestDSAKeyGeneration;
    TestDSASignVerify;
    TestDSADoSignVerify;
    TestDSASize;
    TestDSAParameters;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
