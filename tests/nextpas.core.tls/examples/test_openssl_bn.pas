program test_openssl_bn;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.bn;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestResult(const TestName: string; Passed: Boolean; const Expected: string = ''; const Got: string = '');
begin
  Write('  [', TestName, '] ... ');
  if Passed then
  begin
    WriteLn('PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('FAIL');
    if (Expected <> '') and (Got <> '') then
      WriteLn('    Expected: ', Expected, ', Got: ', Got);
    Inc(TestsFailed);
  end;
end;

function BNToHex(bn: PBIGNUM): string;
var
  hexStr: PAnsiChar;
begin
  Result := '';
  if Assigned(BN_bn2hex) and (bn <> nil) then
  begin
    hexStr := BN_bn2hex(bn);
    if hexStr <> nil then
    begin
      Result := LowerCase(string(hexStr));
      CRYPTO_free(hexStr, nil, 0);
    end;
  end;
end;

function BNToDec(bn: PBIGNUM): string;
var
  decStr: PAnsiChar;
begin
  Result := '';
  if Assigned(BN_bn2dec) and (bn <> nil) then
  begin
    decStr := BN_bn2dec(bn);
    if decStr <> nil then
    begin
      Result := string(decStr);
      CRYPTO_free(decStr, nil, 0);
    end;
  end;
end;

// Test basic BN creation and conversion
procedure TestBNBasic;
var
  bn: PBIGNUM;
  value: BN_ULONG;
  hex: string;
begin
  WriteLn('Testing BN Basic Operations:');
  
  // Test BN_new
  bn := BN_new();
  TestResult('BN_new', bn <> nil);
  
  if bn <> nil then
  begin
    // Test BN_set_word
    TestResult('BN_set_word', BN_set_word(bn, 12345) = 1);
    
    // Test BN_get_word
    value := BN_get_word(bn);
    TestResult('BN_get_word', value = 12345);
    
    // Test BN_is_zero
    TestResult('BN_is_zero (should be false)', BN_is_zero(bn) = 0);
    
    // Test BN_set_word to zero instead of BN_zero
    BN_set_word(bn, 0);
    TestResult('BN set to zero', BN_is_zero(bn) = 1);
    
    // Test BN_one
    if Assigned(BN_one) then
    begin
      TestResult('BN_one', BN_one(bn) = 1);
      TestResult('BN_is_one', BN_is_one(bn) = 1);
    end
    else
    begin
      WriteLn('    BN_one not loaded, using BN_set_word instead');
      BN_set_word(bn, 1);
      TestResult('BN_is_one (after set_word)', BN_is_one(bn) = 1);
    end;
    
    // Test BN_is_odd
    BN_set_word(bn, 5);
    TestResult('BN_is_odd (5)', BN_is_odd(bn) = 1);
    
    BN_set_word(bn, 4);
    TestResult('BN_is_odd (4)', BN_is_odd(bn) = 0);
    
    // Test hex conversion
    BN_set_word(bn, 255);
    hex := BNToHex(bn);
    TestResult('BN_bn2hex (FF)', hex = 'ff', 'ff', hex);
    
    BN_free(bn);
  end;
  
  WriteLn;
end;

// Test BN arithmetic operations
procedure TestBNArithmetic;
var
  a, b, r: PBIGNUM;
  ctx: PBN_CTX;
  resultStr: string;
begin
  WriteLn('Testing BN Arithmetic:');
  
  ctx := BN_CTX_new();
  if ctx = nil then
  begin
    WriteLn('  ERROR: Failed to create BN_CTX');
    Exit;
  end;
  
  a := BN_new();
  b := BN_new();
  r := BN_new();
  
  if (a <> nil) and (b <> nil) and (r <> nil) then
  begin
    // Test addition: 100 + 50 = 150
    BN_set_word(a, 100);
    BN_set_word(b, 50);
    BN_add(r, a, b);
    resultStr := BNToDec(r);
    TestResult('BN_add (100+50=150)', resultStr = '150', '150', resultStr);
    
    // Test subtraction: 100 - 50 = 50
    BN_set_word(a, 100);
    BN_set_word(b, 50);
    BN_sub(r, a, b);
    resultStr := BNToDec(r);
    TestResult('BN_sub (100-50=50)', resultStr = '50', '50', resultStr);
    
    // Test multiplication: 12 * 13 = 156
    BN_set_word(a, 12);
    BN_set_word(b, 13);
    BN_mul(r, a, b, ctx);
    resultStr := BNToDec(r);
    TestResult('BN_mul (12*13=156)', resultStr = '156', '156', resultStr);
    
    // Test square: 12^2 = 144
    BN_set_word(a, 12);
    BN_sqr(r, a, ctx);
    resultStr := BNToDec(r);
    TestResult('BN_sqr (12^2=144)', resultStr = '144', '144', resultStr);
    
    // Test division: 100 / 3 = 33 remainder 1
    BN_set_word(a, 100);
    BN_set_word(b, 3);
    BN_div(r, nil, a, b, ctx);
    resultStr := BNToDec(r);
    TestResult('BN_div (100/3=33)', resultStr = '33', '33', resultStr);
    
    // Test modulo: 100 % 7 = 2
    if Assigned(BN_mod) then
    begin
      BN_set_word(a, 100);
      BN_set_word(b, 7);
      BN_mod(r, a, b, ctx);
      resultStr := BNToDec(r);
      TestResult('BN_mod (100%7=2)', resultStr = '2', '2', resultStr);
    end
    else
      WriteLn('    BN_mod not loaded, skipping test');
  end;
  
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if r <> nil then BN_free(r);
  BN_CTX_free(ctx);
  
  WriteLn;
end;

// Test BN comparison
procedure TestBNComparison;
var
  a, b: PBIGNUM;
begin
  WriteLn('Testing BN Comparison:');
  
  a := BN_new();
  b := BN_new();
  
  if (a <> nil) and (b <> nil) then
  begin
    // Test equal
    BN_set_word(a, 100);
    BN_set_word(b, 100);
    TestResult('BN_cmp (100==100)', BN_cmp(a, b) = 0);
    
    // Test less than
    BN_set_word(a, 50);
    BN_set_word(b, 100);
    TestResult('BN_cmp (50<100)', BN_cmp(a, b) < 0);
    
    // Test greater than
    BN_set_word(a, 100);
    BN_set_word(b, 50);
    TestResult('BN_cmp (100>50)', BN_cmp(a, b) > 0);
    
    // Test BN_is_word
    BN_set_word(a, 12345);
    TestResult('BN_is_word (12345)', BN_is_word(a, 12345) = 1);
    TestResult('BN_is_word (wrong value)', BN_is_word(a, 99999) = 0);
  end;
  
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  
  WriteLn;
end;

// Test BN hex/dec conversion
procedure TestBNConversion;
var
  bn: PBIGNUM;
  hex, dec: string;
  pbn: PBIGNUM;
begin
  WriteLn('Testing BN Conversion:');
  
  bn := BN_new();
  
  if bn <> nil then
  begin
    // Test hex2bn: 1a2b3c = 1715004
    pbn := bn;
    BN_hex2bn(@pbn, '1a2b3c');
    dec := BNToDec(bn);
    TestResult('BN_hex2bn (1a2b3c=1715004)', dec = '1715004', '1715004', dec);
    
    // Test dec2bn: 999999
    pbn := bn;
    BN_dec2bn(@pbn, '999999');
    hex := BNToHex(bn);
    // OpenSSL may return with or without leading zeros, both are correct
    TestResult('BN_dec2bn (999999=f423f)', (hex = 'f423f') or (hex = '0f423f'), 'f423f or 0f423f', hex);
    
    // Test large number
    pbn := bn;
    BN_hex2bn(@pbn, 'ffffffffffffffffffffffffffffffffff');
    dec := BNToDec(bn);
    TestResult('BN_hex2bn (large number)', Length(dec) > 30);
  end;
  
  if bn <> nil then BN_free(bn);
  
  WriteLn;
end;

// Test BN bit operations
procedure TestBNBitOperations;
var
  a, r: PBIGNUM;
  resultStr: string;
begin
  WriteLn('Testing BN Bit Operations:');
  
  a := BN_new();
  r := BN_new();
  
  if (a <> nil) and (r <> nil) then
  begin
    // Test left shift: 1 << 8 = 256
    BN_set_word(a, 1);
    BN_lshift(r, a, 8);
    resultStr := BNToDec(r);
    TestResult('BN_lshift (1<<8=256)', resultStr = '256', '256', resultStr);
    
    // Test right shift: 256 >> 4 = 16
    BN_set_word(a, 256);
    BN_rshift(r, a, 4);
    resultStr := BNToDec(r);
    TestResult('BN_rshift (256>>4=16)', resultStr = '16', '16', resultStr);
    
    // Test set_bit
    BN_set_word(a, 0);
    BN_set_bit(a, 0);  // Set bit 0
    BN_set_bit(a, 3);  // Set bit 3
    BN_set_bit(a, 7);  // Set bit 7
    resultStr := BNToDec(r);
    // Bits 0,3,7 set = 1 + 8 + 128 = 137
    BN_copy(r, a);
    resultStr := BNToDec(r);
    TestResult('BN_set_bit (bits 0,3,7 = 137)', resultStr = '137', '137', resultStr);
    
    // Test is_bit_set
    TestResult('BN_is_bit_set (bit 3)', BN_is_bit_set(a, 3) = 1);
    TestResult('BN_is_bit_set (bit 4)', BN_is_bit_set(a, 4) = 0);
    
    // Test num_bits
    BN_set_word(a, 255);  // 11111111 = 8 bits
    TestResult('BN_num_bits (255=8 bits)', BN_num_bits(a) = 8);
  end;
  
  if a <> nil then BN_free(a);
  if r <> nil then BN_free(r);
  
  WriteLn;
end;

// Test BN modular exponentiation
procedure TestBNModExp;
var
  base, exp, modulus, result: PBIGNUM;
  ctx: PBN_CTX;
  resultStr: string;
begin
  WriteLn('Testing BN Modular Exponentiation:');
  
  ctx := BN_CTX_new();
  base := BN_new();
  exp := BN_new();
  modulus := BN_new();
  result := BN_new();
  
  if (ctx <> nil) and (base <> nil) and (exp <> nil) and (modulus <> nil) and (result <> nil) then
  begin
    // Test: 5^3 mod 13 = 125 mod 13 = 8
    BN_set_word(base, 5);
    BN_set_word(exp, 3);
    BN_set_word(modulus, 13);
    BN_mod_exp(result, base, exp, modulus, ctx);
    resultStr := BNToDec(result);
    TestResult('BN_mod_exp (5^3 mod 13 = 8)', resultStr = '8', '8', resultStr);
    
    // Test: 2^10 mod 1000 = 1024 mod 1000 = 24
    BN_set_word(base, 2);
    BN_set_word(exp, 10);
    BN_set_word(modulus, 1000);
    BN_mod_exp(result, base, exp, modulus, ctx);
    resultStr := BNToDec(result);
    TestResult('BN_mod_exp (2^10 mod 1000 = 24)', resultStr = '24', '24', resultStr);
  end;
  
  if base <> nil then BN_free(base);
  if exp <> nil then BN_free(exp);
  if modulus <> nil then BN_free(modulus);
  if result <> nil then BN_free(result);
  if ctx <> nil then BN_CTX_free(ctx);
  
  WriteLn;
end;

// Test BN GCD and modular inverse
procedure TestBNGCDInverse;
var
  a, b, gcd, inv, modulus: PBIGNUM;
  ctx: PBN_CTX;
  resultStr: string;
begin
  WriteLn('Testing BN GCD and Modular Inverse:');
  
  ctx := BN_CTX_new();
  a := BN_new();
  b := BN_new();
  gcd := BN_new();
  inv := BN_new();
  modulus := BN_new();
  
  if (ctx <> nil) and (a <> nil) and (b <> nil) and (gcd <> nil) then
  begin
    // Test GCD: gcd(48, 18) = 6
    BN_set_word(a, 48);
    BN_set_word(b, 18);
    BN_gcd(gcd, a, b, ctx);
    resultStr := BNToDec(gcd);
    TestResult('BN_gcd (gcd(48,18)=6)', resultStr = '6', '6', resultStr);
    
    // Test modular inverse: 3 * inv ≡ 1 (mod 11), inv = 4
    // Because 3 * 4 = 12 ≡ 1 (mod 11)
    BN_set_word(a, 3);
    BN_set_word(modulus, 11);
    BN_mod_inverse(inv, a, modulus, ctx);
    if inv <> nil then
    begin
      resultStr := BNToDec(inv);
      TestResult('BN_mod_inverse (3^-1 mod 11 = 4)', resultStr = '4', '4', resultStr);
    end
    else
      TestResult('BN_mod_inverse', False);
  end;
  
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if gcd <> nil then BN_free(gcd);
  if inv <> nil then BN_free(inv);
  if modulus <> nil then BN_free(modulus);
  if ctx <> nil then BN_CTX_free(ctx);
  
  WriteLn;
end;

// Test BN random generation
procedure TestBNRandom;
var
  rnd1, rnd2: PBIGNUM;
begin
  WriteLn('Testing BN Random Generation:');
  
  rnd1 := BN_new();
  rnd2 := BN_new();
  
  if (rnd1 <> nil) and (rnd2 <> nil) then
  begin
    // Generate 128-bit random numbers
    TestResult('BN_rand (128 bits)', BN_rand(rnd1, 128, BN_RAND_TOP_ANY, BN_RAND_BOTTOM_ANY) = 1);
    TestResult('BN_rand (128 bits #2)', BN_rand(rnd2, 128, BN_RAND_TOP_ANY, BN_RAND_BOTTOM_ANY) = 1);
    
    // Verify they are different
    TestResult('Random numbers are different', BN_cmp(rnd1, rnd2) <> 0);
    
    // Verify bit count
    TestResult('Random number bit count <= 128', BN_num_bits(rnd1) <= 128);
  end;
  
  if rnd1 <> nil then BN_free(rnd1);
  if rnd2 <> nil then BN_free(rnd2);
  
  WriteLn;
end;

begin
  WriteLn('OpenSSL BN (Big Number) Module Unit Test');
  WriteLn('=========================================');
  WriteLn;
  
  // Load OpenSSL
  Write('Loading OpenSSL libraries... ');
  try
    LoadOpenSSLCore();
    WriteLn('OK');
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ', E.Message);
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL version: ', OpenSSL_version(0));
  WriteLn;
  
  // Initialize crypto module (for CRYPTO_free)
  LoadOpenSSLCrypto();
  
  // Load BN module
  Write('Loading BN module... ');
  if not LoadOpenSSLBN then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;
  
  // Run tests
  try
    TestBNBasic;
    TestBNArithmetic;
    TestBNComparison;
    TestBNConversion;
    TestBNBitOperations;
    TestBNModExp;
    TestBNGCDInverse;
    TestBNRandom;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  // Print summary
  WriteLn('Test Summary:');
  WriteLn('=============');
  WriteLn('Tests Passed: ', TestsPassed);
  WriteLn('Tests Failed: ', TestsFailed);
  WriteLn('Total Tests:  ', TestsPassed + TestsFailed);
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('All tests PASSED! ✓');
  end
  else
  begin
    WriteLn;
    WriteLn('Some tests FAILED! ✗');
    Halt(1);
  end;
  
  // Cleanup
  UnloadOpenSSLBN();
  UnloadOpenSSLCore();
end.