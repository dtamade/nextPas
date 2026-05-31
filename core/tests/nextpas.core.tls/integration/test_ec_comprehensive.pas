program test_ec_comprehensive;

{******************************************************************************}
{  EC Module Comprehensive Integration Tests                                   }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestECKeyGeneration;
var
  key256, key384, key521: PEC_KEY;
begin
  WriteLn;
  WriteLn('=== EC Key Generation ===');

  key256 := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create P-256 key', key256 <> nil);

  if key256 <> nil then
  begin
    Runner.Check('Generate P-256 key', EC_KEY_generate_key(key256) = 1);
    Runner.Check('Verify P-256 key', EC_KEY_check_key(key256) = 1);
    EC_KEY_free(key256);
  end;

  key384 := EC_KEY_new_by_curve_name(NID_secp384r1);
  Runner.Check('Create P-384 key', key384 <> nil);
  if key384 <> nil then
  begin
    Runner.Check('Generate P-384 key', EC_KEY_generate_key(key384) = 1);
    EC_KEY_free(key384);
  end;

  key521 := EC_KEY_new_by_curve_name(NID_secp521r1);
  Runner.Check('Create P-521 key', key521 <> nil);
  if key521 <> nil then
  begin
    Runner.Check('Generate P-521 key', EC_KEY_generate_key(key521) = 1);
    EC_KEY_free(key521);
  end;
end;

procedure TestECKeyCopyDup;
var
  key1, key2, key3: PEC_KEY;
begin
  WriteLn;
  WriteLn('=== EC Key Copy and Duplication ===');

  key1 := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create original key', key1 <> nil);
  if key1 = nil then Exit;

  Runner.Check('Generate original key', EC_KEY_generate_key(key1) = 1);

  key2 := EC_KEY_dup(key1);
  Runner.Check('EC_KEY_dup', key2 <> nil);
  if key2 <> nil then
  begin
    Runner.Check('Verify duplicated key', EC_KEY_check_key(key2) = 1);
    EC_KEY_free(key2);
  end;

  key3 := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if key3 <> nil then
  begin
    Runner.Check('EC_KEY_copy', EC_KEY_copy(key3, key1) <> nil);
    Runner.Check('Verify copied key', EC_KEY_check_key(key3) = 1);
    EC_KEY_free(key3);
  end;

  EC_KEY_free(key1);
end;

procedure TestECGroupOperations;
var
  group: PEC_GROUP;
  nid, degree: Integer;
  order, cofactor: PBIGNUM;
  ctx: PBN_CTX;
begin
  WriteLn;
  WriteLn('=== EC Group Operations ===');

  group := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create EC group (P-256)', group <> nil);
  if group = nil then Exit;

  nid := EC_GROUP_get_curve_name(group);
  Runner.Check('Get curve NID', nid = NID_X9_62_prime256v1, Format('NID=%d', [nid]));

  degree := EC_GROUP_get_degree(group);
  Runner.Check('Get curve degree', degree > 0, Format('Degree=%d bits', [degree]));

  ctx := BN_CTX_new();
  if ctx <> nil then
  begin
    order := BN_new();
    if order <> nil then
    begin
      Runner.Check('Get curve order', EC_GROUP_get_order(group, order, ctx) = 1);
      WriteLn('  Order bits: ', BN_num_bits(order));
      BN_free(order);
    end;

    cofactor := BN_new();
    if cofactor <> nil then
    begin
      Runner.Check('Get curve cofactor', EC_GROUP_get_cofactor(group, cofactor, ctx) = 1);
      WriteLn('  Cofactor: ', BN_get_word(cofactor));
      BN_free(cofactor);
    end;

    BN_CTX_free(ctx);
  end;

  EC_GROUP_free(group);
end;

procedure TestECPointOperations;
var
  group: PEC_GROUP;
  point1, point2, point3: PEC_POINT;
  ctx: PBN_CTX;
begin
  WriteLn;
  WriteLn('=== EC Point Operations ===');

  group := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create EC group', group <> nil);
  if group = nil then Exit;

  ctx := BN_CTX_new();
  if ctx = nil then
  begin
    EC_GROUP_free(group);
    Exit;
  end;

  point1 := EC_POINT_new(group);
  point2 := EC_POINT_new(group);
  point3 := EC_POINT_new(group);
  Runner.Check('Create EC points', (point1 <> nil) and (point2 <> nil) and (point3 <> nil));

  if (point1 <> nil) and (point2 <> nil) and (point3 <> nil) then
  begin
    Runner.Check('EC_POINT_copy', EC_POINT_copy(point2, point1) = 1);
    Runner.Check('EC_POINT_add', EC_POINT_add(group, point3, point1, point2, ctx) = 1);
    Runner.Check('EC_POINT_dbl', EC_POINT_dbl(group, point3, point1, ctx) = 1);
  end;

  if point1 <> nil then EC_POINT_free(point1);
  if point2 <> nil then EC_POINT_free(point2);
  if point3 <> nil then EC_POINT_free(point3);
  BN_CTX_free(ctx);
  EC_GROUP_free(group);
end;

procedure TestECKeyComponentAccess;
var
  key: PEC_KEY;
  group: PEC_GROUP;
  priv_key: PBIGNUM;
  pub_key: PEC_POINT;
begin
  WriteLn;
  WriteLn('=== EC Key Component Access ===');

  key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create key', key <> nil);
  if key = nil then Exit;

  Runner.Check('Generate key', EC_KEY_generate_key(key) = 1);

  group := EC_KEY_get0_group(key);
  Runner.Check('Access EC group', group <> nil);

  priv_key := EC_KEY_get0_private_key(key);
  Runner.Check('Access private key', priv_key <> nil);
  if priv_key <> nil then
    WriteLn('  Private key: ', BN_num_bits(priv_key), ' bits');

  pub_key := EC_KEY_get0_public_key(key);
  Runner.Check('Access public key', pub_key <> nil);

  EC_KEY_free(key);
end;

procedure TestECMultipleCurves;
var
  key: PEC_KEY;

  procedure TestCurve(CurveNID: Integer; const CurveName: string);
  begin
    key := EC_KEY_new_by_curve_name(CurveNID);
    if key <> nil then
    begin
      if (EC_KEY_generate_key(key) = 1) and (EC_KEY_check_key(key) = 1) then
        Runner.Check('Curve ' + CurveName, True)
      else
        Runner.Check('Curve ' + CurveName, False);
      EC_KEY_free(key);
    end
    else
      Runner.Check('Curve ' + CurveName, False);
  end;

begin
  WriteLn;
  WriteLn('=== Multiple Curve Types ===');

  TestCurve(NID_X9_62_prime256v1, 'P-256');
  TestCurve(NID_secp384r1, 'P-384');
  TestCurve(NID_secp521r1, 'P-521');
  TestCurve(NID_secp256k1, 'secp256k1');
  TestCurve(NID_secp224r1, 'P-224');
end;

procedure TestECPointSerialization;
var
  key: PEC_KEY;
  group: PEC_GROUP;
  pub_key, restored_point: PEC_POINT;
  buf: array[0..255] of Byte;
  buf_len: NativeUInt;
  ctx: PBN_CTX;
begin
  WriteLn;
  WriteLn('=== EC Point Serialization ===');

  key := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  Runner.Check('Create key', key <> nil);
  if key = nil then Exit;

  Runner.Check('Generate key', EC_KEY_generate_key(key) = 1);

  group := EC_KEY_get0_group(key);
  pub_key := EC_KEY_get0_public_key(key);

  ctx := BN_CTX_new();
  if ctx = nil then
  begin
    EC_KEY_free(key);
    Exit;
  end;

  buf_len := EC_POINT_point2oct(group, pub_key, POINT_CONVERSION_UNCOMPRESSED, @buf[0], SizeOf(buf), ctx);
  Runner.Check('Serialize public key', buf_len > 0, Format('%d bytes', [buf_len]));

  restored_point := EC_POINT_new(group);
  if restored_point <> nil then
  begin
    Runner.Check('Deserialize public key', EC_POINT_oct2point(group, restored_point, @buf[0], buf_len, ctx) = 1);
    Runner.Check('Compare points', EC_POINT_cmp(group, pub_key, restored_point, ctx) = 0);
    EC_POINT_free(restored_point);
  end;

  BN_CTX_free(ctx);
  EC_KEY_free(key);
end;

begin
  WriteLn('EC Module Comprehensive Integration Test');
  WriteLn('=========================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmBN, osmEC]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    LoadOpenSSLBN;
    LoadECFunctions(GetCryptoLibHandle);

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestECKeyGeneration;
    TestECKeyCopyDup;
    TestECGroupOperations;
    TestECPointOperations;
    TestECKeyComponentAccess;
    TestECMultipleCurves;
    TestECPointSerialization;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
