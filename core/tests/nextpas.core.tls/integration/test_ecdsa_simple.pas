program test_ecdsa_simple;

{******************************************************************************}
{  ECDSA Simple Integration Tests                                              }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.ecdsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestECDSAKeyGeneration;
var
  Key: PEC_KEY;
  Group: PEC_GROUP;
begin
  WriteLn;
  WriteLn('=== ECDSA Key Generation Tests ===');

  // Test P-256 (NIST prime256v1) curve key generation
  Key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create P-256 EC_KEY structure', Key <> nil);

  if Key <> nil then
  begin
    if EC_KEY_generate_key(Key) = 1 then
    begin
      Runner.Check('Generate P-256 key pair', True);

      Group := EC_KEY_get0_group(Key);
      Runner.Check('Get EC group', Group <> nil);

      Runner.Check('Validate key', EC_KEY_check_key(Key) = 1);
    end
    else
      Runner.Check('Generate P-256 key pair', False, 'EC_KEY_generate_key failed');

    EC_KEY_free(Key);
  end;

  // Test secp384r1 curve
  Key := EC_KEY_new_by_curve_name(NID_secp384r1);
  Runner.Check('Create secp384r1 EC_KEY structure', Key <> nil);

  if Key <> nil then
  begin
    Runner.Check('Generate secp384r1 key pair', EC_KEY_generate_key(Key) = 1);
    EC_KEY_free(Key);
  end;
end;

procedure TestECDSASignVerify;
var
  Key: PEC_KEY;
  Digest: array[0..31] of Byte;
  Signature: array[0..255] of Byte;
  SigLen: Cardinal;
  I: Integer;
  VerifyResult: Integer;
begin
  WriteLn;
  WriteLn('=== ECDSA Sign/Verify Tests ===');

  Key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if Key = nil then
  begin
    Runner.Check('Create signing EC_KEY', False);
    Exit;
  end;

  try
    if EC_KEY_generate_key(Key) <> 1 then
    begin
      Runner.Check('Generate signing key', False);
      Exit;
    end;

    Runner.Check('Generate signing key', True);

    for I := 0 to 31 do
      Digest[I] := Byte(I);

    SigLen := SizeOf(Signature);
    if ECDSA_sign(0, @Digest[0], 32, @Signature[0], @SigLen, Key) = 1 then
    begin
      Runner.Check('Sign digest', True, Format('Generated %d byte signature', [SigLen]));

      VerifyResult := ECDSA_verify(0, @Digest[0], 32, @Signature[0], SigLen, Key);
      Runner.Check('Verify signature', VerifyResult = 1,
              Format('Verification result: %d', [VerifyResult]));

      Digest[0] := Digest[0] xor $FF;
      VerifyResult := ECDSA_verify(0, @Digest[0], 32, @Signature[0], SigLen, Key);
      Runner.Check('Detect tampered data', VerifyResult = 0,
              Format('Tamper detection result: %d (should be 0)', [VerifyResult]));
    end
    else
      Runner.Check('Sign digest', False, 'ECDSA_sign failed');

  finally
    EC_KEY_free(Key);
  end;
end;

procedure TestECDSADoSignVerify;
var
  Key: PEC_KEY;
  Digest: array[0..31] of Byte;
  Sig: PECDSA_SIG;
  I: Integer;
  VerifyResult: Integer;
  R, S: PBIGNUM;
begin
  WriteLn;
  WriteLn('=== ECDSA_do_sign/verify Tests ===');

  Key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if Key = nil then
  begin
    Runner.Check('Create do_sign EC_KEY', False);
    Exit;
  end;

  try
    if EC_KEY_generate_key(Key) <> 1 then
    begin
      Runner.Check('Generate do_sign key', False);
      Exit;
    end;

    for I := 0 to 31 do
      Digest[I] := Byte(31 - I);

    Sig := ECDSA_do_sign(@Digest[0], 32, Key);
    if Sig <> nil then
    begin
      Runner.Check('ECDSA_do_sign generate signature', True);

      R := ECDSA_SIG_get0_r(Sig);
      S := ECDSA_SIG_get0_s(Sig);
      Runner.Check('Get signature R and S values', (R <> nil) and (S <> nil));

      VerifyResult := ECDSA_do_verify(@Digest[0], 32, Sig, Key);
      Runner.Check('ECDSA_do_verify verification', VerifyResult = 1,
              Format('Verification result: %d', [VerifyResult]));

      ECDSA_SIG_free(Sig);
    end
    else
      Runner.Check('ECDSA_do_sign generate signature', False);

  finally
    EC_KEY_free(Key);
  end;
end;

procedure TestECDSASize;
var
  Key: PEC_KEY;
  SigSize: Integer;
begin
  WriteLn;
  WriteLn('=== ECDSA Signature Size Tests ===');

  // P-256
  Key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if Key <> nil then
  begin
    if EC_KEY_generate_key(Key) = 1 then
    begin
      SigSize := ECDSA_size(Key);
      Runner.Check('P-256 signature size', SigSize > 0,
              Format('Max signature size: %d bytes', [SigSize]));
    end;
    EC_KEY_free(Key);
  end;

  // secp384r1
  Key := EC_KEY_new_by_curve_name(NID_secp384r1);
  if Key <> nil then
  begin
    if EC_KEY_generate_key(Key) = 1 then
    begin
      SigSize := ECDSA_size(Key);
      Runner.Check('secp384r1 signature size', SigSize > 0,
              Format('Max signature size: %d bytes', [SigSize]));
    end;
    EC_KEY_free(Key);
  end;

  // secp521r1
  Key := EC_KEY_new_by_curve_name(NID_secp521r1);
  if Key <> nil then
  begin
    if EC_KEY_generate_key(Key) = 1 then
    begin
      SigSize := ECDSA_size(Key);
      Runner.Check('secp521r1 signature size', SigSize > 0,
              Format('Max signature size: %d bytes', [SigSize]));
    end;
    EC_KEY_free(Key);
  end;
end;

begin
  WriteLn('ECDSA Elliptic Curve Digital Signature Integration Tests');
  WriteLn('==========================================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmEC]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Ensure required functions are loaded
    LoadOpenSSLBN;
    LoadECFunctions(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto));
    LoadOpenSSLECDSA;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestECDSAKeyGeneration;
    TestECDSASignVerify;
    TestECDSADoSignVerify;
    TestECDSASize;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
