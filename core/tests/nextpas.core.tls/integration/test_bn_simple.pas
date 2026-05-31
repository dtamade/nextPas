program test_bn_simple;

{******************************************************************************}
{  BN (Big Number) Integration Tests                                           }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                         }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestBNCreation;
var
  A, B: PBIGNUM;
begin
  WriteLn;
  WriteLn('=== BN Creation and Memory Tests ===');
  WriteLn;

  // Test BN_new
  A := BN_new();
  Runner.Check('Create BIGNUM', A <> nil);

  if A <> nil then
  begin
    // Test BN_set_word
    if BN_set_word(A, 12345) = 1 then
    begin
      Runner.Check('Set word value', True);
      Runner.Check('Get word value', BN_get_word(A) = 12345,
              Format('Value: %d', [BN_get_word(A)]));
    end
    else
      Runner.Check('Set word value', False);

    BN_free(A);
  end;

  // Test BN_dup
  A := BN_new();
  if A <> nil then
  begin
    BN_set_word(A, 999);
    B := BN_dup(A);
    Runner.Check('Duplicate BIGNUM', B <> nil);
    if B <> nil then
    begin
      Runner.Check('Duplicated value matches', BN_get_word(B) = 999);
      BN_free(B);
    end;
    BN_free(A);
  end;
end;

procedure TestBNArithmetic;
var
  A, B, R: PBIGNUM;
  Ctx: PBN_CTX;
  LResult: Integer;
begin
  WriteLn;
  WriteLn('=== BN Arithmetic Tests ===');
  WriteLn;

  A := BN_new();
  B := BN_new();
  R := BN_new();
  Ctx := BN_CTX_new();

  if (A = nil) or (B = nil) or (R = nil) or (Ctx = nil) then
  begin
    Runner.Check('Create BN structures for arithmetic', False);
    Exit;
  end;

  try
    // Test addition: 100 + 50 = 150
    BN_set_word(A, 100);
    BN_set_word(B, 50);
    LResult := BN_add(R, A, B);
    Runner.Check('Addition (100 + 50)', (LResult = 1) and (BN_get_word(R) = 150),
            Format('Result: %d', [BN_get_word(R)]));

    // Test subtraction: 100 - 30 = 70
    BN_set_word(A, 100);
    BN_set_word(B, 30);
    LResult := BN_sub(R, A, B);
    Runner.Check('Subtraction (100 - 30)', (LResult = 1) and (BN_get_word(R) = 70),
            Format('Result: %d', [BN_get_word(R)]));

    // Test multiplication: 25 * 4 = 100
    BN_set_word(A, 25);
    BN_set_word(B, 4);
    LResult := BN_mul(R, A, B, Ctx);
    Runner.Check('Multiplication (25 * 4)', (LResult = 1) and (BN_get_word(R) = 100),
            Format('Result: %d', [BN_get_word(R)]));

    // Test division: 100 / 5 = 20
    BN_set_word(A, 100);
    BN_set_word(B, 5);
    LResult := BN_div(R, nil, A, B, Ctx);
    Runner.Check('Division (100 / 5)', (LResult = 1) and (BN_get_word(R) = 20),
            Format('Result: %d', [BN_get_word(R)]));

    // Test modulo: 100 mod 7 = 2 (using div with remainder)
    BN_set_word(A, 100);
    BN_set_word(B, 7);
    LResult := BN_div(nil, R, A, B, Ctx);
    Runner.Check('Modulo (100 mod 7)', (LResult = 1) and (BN_get_word(R) = 2),
            Format('Result: %d', [BN_get_word(R)]));

  finally
    BN_free(A);
    BN_free(B);
    BN_free(R);
    BN_CTX_free(Ctx);
  end;
end;

procedure TestBNComparison;
var
  A, B: PBIGNUM;
begin
  WriteLn;
  WriteLn('=== BN Comparison Tests ===');
  WriteLn;

  A := BN_new();
  B := BN_new();

  if (A = nil) or (B = nil) then
  begin
    Runner.Check('Create BN structures for comparison', False);
    Exit;
  end;

  try
    // Test equality
    BN_set_word(A, 42);
    BN_set_word(B, 42);
    Runner.Check('Equal numbers (42 == 42)', BN_cmp(A, B) = 0);

    // Test less than
    BN_set_word(A, 10);
    BN_set_word(B, 20);
    Runner.Check('Less than (10 < 20)', BN_cmp(A, B) < 0);

    // Test greater than
    BN_set_word(A, 30);
    BN_set_word(B, 15);
    Runner.Check('Greater than (30 > 15)', BN_cmp(A, B) > 0);

    // Test is_zero
    BN_set_word(A, 0);
    Runner.Check('Is zero', BN_is_zero(A) = 1);

    // Test is_one
    BN_set_word(A, 1);
    Runner.Check('Is one', BN_is_one(A) = 1);

    // Test is_odd
    BN_set_word(A, 7);
    Runner.Check('Is odd (7)', BN_is_odd(A) = 1);

    BN_set_word(A, 8);
    Runner.Check('Is even (8)', BN_is_odd(A) = 0);

  finally
    BN_free(A);
    BN_free(B);
  end;
end;

procedure TestBNModularArithmetic;
var
  A, B, M, R: PBIGNUM;
  Ctx: PBN_CTX;
  LResult: Integer;
begin
  WriteLn;
  WriteLn('=== BN Modular Arithmetic Tests ===');
  WriteLn;

  A := BN_new();
  B := BN_new();
  M := BN_new();
  R := BN_new();
  Ctx := BN_CTX_new();

  if (A = nil) or (B = nil) or (M = nil) or (R = nil) or (Ctx = nil) then
  begin
    Runner.Check('Create BN structures for modular arithmetic', False);
    Exit;
  end;

  try
    // Modular addition: (10 + 7) mod 11 = 6
    BN_set_word(A, 10);
    BN_set_word(B, 7);
    BN_set_word(M, 11);
    LResult := BN_mod_add(R, A, B, M, Ctx);
    Runner.Check('Modular addition ((10 + 7) mod 11)',
            (LResult = 1) and (BN_get_word(R) = 6),
            Format('Result: %d', [BN_get_word(R)]));

    // Modular subtraction: (15 - 8) mod 11 = 7
    BN_set_word(A, 15);
    BN_set_word(B, 8);
    BN_set_word(M, 11);
    LResult := BN_mod_sub(R, A, B, M, Ctx);
    Runner.Check('Modular subtraction ((15 - 8) mod 11)',
            (LResult = 1) and (BN_get_word(R) = 7),
            Format('Result: %d', [BN_get_word(R)]));

    // Modular multiplication: (7 * 8) mod 11 = 1
    BN_set_word(A, 7);
    BN_set_word(B, 8);
    BN_set_word(M, 11);
    LResult := BN_mod_mul(R, A, B, M, Ctx);
    Runner.Check('Modular multiplication ((7 * 8) mod 11)',
            (LResult = 1) and (BN_get_word(R) = 1),
            Format('Result: %d', [BN_get_word(R)]));

    // Modular exponentiation: 2^10 mod 1000 = 24
    BN_set_word(A, 2);
    BN_set_word(B, 10);
    BN_set_word(M, 1000);
    LResult := BN_mod_exp(R, A, B, M, Ctx);
    Runner.Check('Modular exponentiation (2^10 mod 1000)',
            (LResult = 1) and (BN_get_word(R) = 24),
            Format('Result: %d', [BN_get_word(R)]));

  finally
    BN_free(A);
    BN_free(B);
    BN_free(M);
    BN_free(R);
    BN_CTX_free(Ctx);
  end;
end;

procedure TestBNBitOperations;
var
  A, R: PBIGNUM;
  NumBits: Integer;
begin
  WriteLn;
  WriteLn('=== BN Bit Operations Tests ===');
  WriteLn;

  A := BN_new();
  R := BN_new();

  if (A = nil) or (R = nil) then
  begin
    Runner.Check('Create BN structures for bit operations', False);
    Exit;
  end;

  try
    // Test num_bits
    BN_set_word(A, 255);  // 0xFF = 8 bits
    NumBits := BN_num_bits(A);
    Runner.Check('Number of bits (255)', NumBits = 8,
            Format('Bits: %d', [NumBits]));

    // Test left shift: 1 << 10 = 1024
    BN_set_word(A, 1);
    if BN_lshift(R, A, 10) = 1 then
      Runner.Check('Left shift (1 << 10)', BN_get_word(R) = 1024,
              Format('Result: %d', [BN_get_word(R)]))
    else
      Runner.Check('Left shift (1 << 10)', False);

    // Test right shift: 1024 >> 10 = 1
    BN_set_word(A, 1024);
    if BN_rshift(R, A, 10) = 1 then
      Runner.Check('Right shift (1024 >> 10)', BN_get_word(R) = 1,
              Format('Result: %d', [BN_get_word(R)]))
    else
      Runner.Check('Right shift (1024 >> 10)', False);

    // Test set_bit
    BN_set_word(A, 0);  // Clear to zero
    if BN_set_bit(A, 5) = 1 then  // Set bit 5 = 32
      Runner.Check('Set bit 5', BN_get_word(A) = 32,
              Format('Result: %d', [BN_get_word(A)]))
    else
      Runner.Check('Set bit 5', False);

    // Test is_bit_set
    BN_set_word(A, 32);  // bit 5 is set
    Runner.Check('Test bit 5 is set', BN_is_bit_set(A, 5) = 1);
    Runner.Check('Test bit 4 is not set', BN_is_bit_set(A, 4) = 0);

  finally
    BN_free(A);
    BN_free(R);
  end;
end;

procedure TestBNConversion;
var
  A: PBIGNUM;
  HexStr, DecStr: PAnsiChar;
  Bin: array[0..31] of Byte;
  BinLen: Integer;
begin
  WriteLn;
  WriteLn('=== BN Conversion Tests ===');
  WriteLn;

  A := BN_new();

  if A = nil then
  begin
    Runner.Check('Create BN for conversion', False);
    Exit;
  end;

  try
    // Test dec2bn
    if BN_dec2bn(@A, '12345') > 0 then
    begin
      Runner.Check('Decimal string to BN', True);
      Runner.Check('Verify decimal value', BN_get_word(A) = 12345);
    end
    else
      Runner.Check('Decimal string to BN', False);

    // Test bn2dec
    BN_set_word(A, 67890);
    DecStr := BN_bn2dec(A);
    if DecStr <> nil then
    begin
      Runner.Check('BN to decimal string', string(DecStr) = '67890',
              Format('String: %s', [DecStr]));
    end
    else
      Runner.Check('BN to decimal string', False);

    // Test hex2bn
    if BN_hex2bn(@A, 'FF') > 0 then
    begin
      Runner.Check('Hex string to BN', True);
      Runner.Check('Verify hex value (0xFF)', BN_get_word(A) = 255);
    end
    else
      Runner.Check('Hex string to BN', False);

    // Test bn2hex
    BN_set_word(A, 4095);  // 0xFFF
    HexStr := BN_bn2hex(A);
    if HexStr <> nil then
    begin
      // OpenSSL 3.x may add leading zero, accept both 'FFF' and '0FFF'
      Runner.Check('BN to hex string', (string(HexStr) = 'FFF') or (string(HexStr) = '0FFF'),
              Format('String: %s', [HexStr]));
    end
    else
      Runner.Check('BN to hex string', False);

    // Test bn2bin and bin2bn
    BN_set_word(A, 256);
    FillChar(Bin, SizeOf(Bin), 0);
    BinLen := BN_bn2bin(A, @Bin[0]);
    Runner.Check('BN to binary', BinLen > 0,
            Format('Binary length: %d bytes', [BinLen]));

    if BinLen > 0 then
    begin
      BN_set_word(A, 0);  // Clear to zero
      if BN_bin2bn(@Bin[0], BinLen, A) <> nil then
        Runner.Check('Binary to BN', BN_get_word(A) = 256)
      else
        Runner.Check('Binary to BN', False);
    end;

  finally
    BN_free(A);
  end;
end;

begin
  WriteLn('BN (Big Number) Integration Tests');
  WriteLn('==================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    // Declare required modules (P1-2.2: Dependency-based initialization)
    Runner.RequireModules([osmCore, osmBN]);

    // Initialize OpenSSL and load required modules
    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', TOpenSSLTestBase.OpenSSLVersion.VersionString);
    WriteLn;

    // Run test suites
    TestBNCreation;
    TestBNArithmetic;
    TestBNComparison;
    TestBNModularArithmetic;
    TestBNBitOperations;
    TestBNConversion;

    // Print unified summary (P1-2.2: Consistent output format)
    Runner.PrintSummary;

    if Runner.FailCount > 0 then
      Halt(1);
  finally
    Runner.Free;
  end;
end.
