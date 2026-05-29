program test_hmac_simple;

{******************************************************************************}
{  HMAC Simple Integration Tests                                               }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.hmac,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

function BytesToHex(const data: array of Byte; len: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to len - 1 do
    Result := Result + LowerCase(IntToHex(data[i], 2));
end;

procedure TestHMACSHA1OneShot;
var
  key, data: AnsiString;
  digest: array[0..19] of Byte;
  result_ptr: PByte;
  hex_digest, expected: string;
begin
  WriteLn;
  WriteLn('=== HMAC-SHA1 One-Shot ===');

  key := 'secret';
  data := 'Hello World!';
  expected := '5efed98b0787c83f9cb0135ba283c390ca49320e';

  FillChar(digest, SizeOf(digest), 0);
  result_ptr := HMAC_SHA1(@key[1], Length(key), @data[1], Length(data), @digest[0]);
  Runner.Check('Compute HMAC-SHA1', result_ptr <> nil);

  if result_ptr <> nil then
  begin
    hex_digest := BytesToHex(digest, 20);
    Runner.Check('Verify HMAC-SHA1 digest', hex_digest = expected,
            Format('got: %s', [hex_digest]));
  end;
end;

procedure TestHMACSHA256OneShot;
var
  key, data: AnsiString;
  digest: array[0..31] of Byte;
  result_ptr: PByte;
  hex_digest, expected: string;
begin
  WriteLn;
  WriteLn('=== HMAC-SHA256 One-Shot ===');

  key := 'secret';
  data := 'Hello World!';
  expected := '6fa7b4dea28ee348df10f9bb595ad985ff150a4adfd6131cca677d9acee07dc6';

  FillChar(digest, SizeOf(digest), 0);
  result_ptr := HMAC_SHA256(@key[1], Length(key), @data[1], Length(data), @digest[0]);
  Runner.Check('Compute HMAC-SHA256', result_ptr <> nil);

  if result_ptr <> nil then
  begin
    hex_digest := BytesToHex(digest, 32);
    Runner.Check('Verify HMAC-SHA256 digest', hex_digest = expected,
            Format('got: %s', [hex_digest]));
  end;
end;

procedure TestHMACSHA512OneShot;
var
  key, data: AnsiString;
  digest: array[0..63] of Byte;
  result_ptr: PByte;
  hex_digest: string;
begin
  WriteLn;
  WriteLn('=== HMAC-SHA512 One-Shot ===');

  key := 'secret';
  data := 'Hello World!';

  FillChar(digest, SizeOf(digest), 0);
  result_ptr := HMAC_SHA512(@key[1], Length(key), @data[1], Length(data), @digest[0]);
  Runner.Check('Compute HMAC-SHA512', result_ptr <> nil);

  if result_ptr <> nil then
  begin
    hex_digest := BytesToHex(digest, 64);
    Runner.Check('Verify HMAC-SHA512 length', Length(hex_digest) = 128,
            Format('%d bytes', [Length(hex_digest) div 2]));
  end;
end;

procedure TestHMACContextBased;
var
  ctx: PHMAC_CTX;
  key, data1, data2, data3: AnsiString;
  digest: array[0..31] of Byte;
  digest_len: Cardinal;
  hex_digest: string;
begin
  WriteLn;
  WriteLn('=== HMAC Context-Based ===');

  key := 'secret';
  data1 := 'Hello ';
  data2 := 'World';
  data3 := '!';

  ctx := HMAC_CTX_new();
  Runner.Check('Create HMAC context', ctx <> nil);
  if ctx = nil then Exit;

  Runner.Check('Initialize HMAC-SHA256',
          HMAC_Init_ex(ctx, @key[1], Length(key), EVP_sha256(), nil) = 1);

  Runner.Check('Update HMAC (part 1)', HMAC_Update(ctx, @data1[1], Length(data1)) = 1);
  Runner.Check('Update HMAC (part 2)', HMAC_Update(ctx, @data2[1], Length(data2)) = 1);
  Runner.Check('Update HMAC (part 3)', HMAC_Update(ctx, @data3[1], Length(data3)) = 1);

  FillChar(digest, SizeOf(digest), 0);
  digest_len := 0;
  Runner.Check('Finalize HMAC', HMAC_Final(ctx, @digest[0], @digest_len) = 1);
  Runner.Check('Digest length', digest_len = 32, Format('%d bytes', [digest_len]));

  hex_digest := BytesToHex(digest, digest_len);
  Runner.Check('Compare with one-shot',
          hex_digest = '6fa7b4dea28ee348df10f9bb595ad985ff150a4adfd6131cca677d9acee07dc6');

  HMAC_CTX_free(ctx);
end;

procedure TestHMACContextReset;
var
  ctx: PHMAC_CTX;
  key, data: AnsiString;
  digest1, digest2: array[0..31] of Byte;
  digest_len: Cardinal;
  hex1, hex2: string;
begin
  WriteLn;
  WriteLn('=== HMAC Context Reset ===');

  key := 'secret';
  data := 'Test Data';

  ctx := HMAC_CTX_new();
  Runner.Check('Create HMAC context', ctx <> nil);
  if ctx = nil then Exit;

  // First computation
  HMAC_Init_ex(ctx, @key[1], Length(key), EVP_sha256(), nil);
  HMAC_Update(ctx, @data[1], Length(data));
  FillChar(digest1, SizeOf(digest1), 0);
  digest_len := 0;
  HMAC_Final(ctx, @digest1[0], @digest_len);
  hex1 := BytesToHex(digest1, digest_len);
  Runner.Check('First HMAC computation', True);

  // Reset context
  Runner.Check('Reset HMAC context', HMAC_CTX_reset(ctx) = 1);

  // Second computation
  HMAC_Init_ex(ctx, @key[1], Length(key), EVP_sha256(), nil);
  HMAC_Update(ctx, @data[1], Length(data));
  FillChar(digest2, SizeOf(digest2), 0);
  digest_len := 0;
  HMAC_Final(ctx, @digest2[0], @digest_len);
  hex2 := BytesToHex(digest2, digest_len);
  Runner.Check('Second HMAC computation', True);

  Runner.Check('Digests match after reset', hex1 = hex2);

  HMAC_CTX_free(ctx);
end;

procedure TestHMACContextCopy;
var
  ctx1, ctx2: PHMAC_CTX;
  key, data1, data2: AnsiString;
  digest1, digest2: array[0..31] of Byte;
  digest_len: Cardinal;
  hex1, hex2: string;
begin
  WriteLn;
  WriteLn('=== HMAC Context Copy ===');

  key := 'secret';
  data1 := 'Part 1 ';
  data2 := 'Part 2';

  ctx1 := HMAC_CTX_new();
  ctx2 := HMAC_CTX_new();
  Runner.Check('Create HMAC contexts', (ctx1 <> nil) and (ctx2 <> nil));
  if (ctx1 = nil) or (ctx2 = nil) then
  begin
    if ctx1 <> nil then HMAC_CTX_free(ctx1);
    if ctx2 <> nil then HMAC_CTX_free(ctx2);
    Exit;
  end;

  HMAC_Init_ex(ctx1, @key[1], Length(key), EVP_sha256(), nil);
  HMAC_Update(ctx1, @data1[1], Length(data1));
  Runner.Check('Initialize and update first context', True);

  Runner.Check('Copy context', HMAC_CTX_copy(ctx2, ctx1) = 1);

  // Complete both contexts
  HMAC_Update(ctx1, @data2[1], Length(data2));
  HMAC_Update(ctx2, @data2[1], Length(data2));

  FillChar(digest1, SizeOf(digest1), 0);
  FillChar(digest2, SizeOf(digest2), 0);
  digest_len := 0;

  HMAC_Final(ctx1, @digest1[0], @digest_len);
  hex1 := BytesToHex(digest1, digest_len);
  digest_len := 0;
  HMAC_Final(ctx2, @digest2[0], @digest_len);
  hex2 := BytesToHex(digest2, digest_len);

  Runner.Check('Digests match after copy', hex1 = hex2);

  HMAC_CTX_free(ctx1);
  HMAC_CTX_free(ctx2);
end;

procedure TestHMACSize;
var
  ctx: PHMAC_CTX;
  key: AnsiString;
  size: size_t;
begin
  WriteLn;
  WriteLn('=== HMAC Size Query ===');

  key := 'secret';

  ctx := HMAC_CTX_new();
  Runner.Check('Create HMAC context', ctx <> nil);
  if ctx = nil then Exit;

  HMAC_Init_ex(ctx, @key[1], Length(key), EVP_sha256(), nil);
  size := HMAC_size(ctx);
  Runner.Check('Query HMAC size', size = 32, Format('%d bytes for SHA256', [size]));

  HMAC_CTX_free(ctx);
end;

begin
  WriteLn('HMAC Module Integration Test');
  WriteLn('=============================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore, osmEVP, osmHMAC]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestHMACSHA1OneShot;
    TestHMACSHA256OneShot;
    TestHMACSHA512OneShot;
    TestHMACContextBased;
    TestHMACContextReset;
    TestHMACContextCopy;
    TestHMACSize;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
