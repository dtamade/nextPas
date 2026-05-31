program test_bn_comprehensive;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.openssl.api, nextpas.core.tls.openssl.api.bn;

var
  TestsPassed, TestsFailed: Integer;

procedure RunTest(const TestName: string; Passed: Boolean);
begin
  if Passed then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure Test_BN_Creation;
var
  bn: PBIGNUM;
begin
  bn := BN_new();
  RunTest('BN_new creates BIGNUM', bn <> nil);
  if bn <> nil then
    BN_free(bn);
end;

procedure Test_BN_SetWord;
var
  bn: PBIGNUM;
  value: Cardinal;
begin
  bn := BN_new();
  if bn <> nil then
  begin
    BN_set_word(bn, 12345);
    value := BN_get_word(bn);
    RunTest('BN_set_word and BN_get_word', value = 12345);
    BN_free(bn);
  end
  else
    RunTest('BN_set_word and BN_get_word', False);
end;

procedure Test_BN_Addition;
var
  a, b, result: PBIGNUM;
  ctx: PBN_CTX;
  res_value: Cardinal;
begin
  a := BN_new();
  b := BN_new();
  result := BN_new();
  ctx := BN_CTX_new();
  
  if (a <> nil) and (b <> nil) and (result <> nil) and (ctx <> nil) then
  begin
    BN_set_word(a, 100);
    BN_set_word(b, 200);
    BN_add(result, a, b);
    res_value := BN_get_word(result);
    RunTest('BN_add (100 + 200 = 300)', res_value = 300);
  end
  else
    RunTest('BN_add (100 + 200 = 300)', False);
    
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if result <> nil then BN_free(result);
  if ctx <> nil then BN_CTX_free(ctx);
end;

procedure Test_BN_Subtraction;
var
  a, b, result: PBIGNUM;
  ctx: PBN_CTX;
  res_value: Cardinal;
begin
  a := BN_new();
  b := BN_new();
  result := BN_new();
  ctx := BN_CTX_new();
  
  if (a <> nil) and (b <> nil) and (result <> nil) and (ctx <> nil) then
  begin
    BN_set_word(a, 500);
    BN_set_word(b, 200);
    BN_sub(result, a, b);
    res_value := BN_get_word(result);
    RunTest('BN_sub (500 - 200 = 300)', res_value = 300);
  end
  else
    RunTest('BN_sub (500 - 200 = 300)', False);
    
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if result <> nil then BN_free(result);
  if ctx <> nil then BN_CTX_free(ctx);
end;

procedure Test_BN_Multiplication;
var
  a, b, result: PBIGNUM;
  ctx: PBN_CTX;
  res_value: Cardinal;
begin
  a := BN_new();
  b := BN_new();
  result := BN_new();
  ctx := BN_CTX_new();
  
  if (a <> nil) and (b <> nil) and (result <> nil) and (ctx <> nil) then
  begin
    BN_set_word(a, 15);
    BN_set_word(b, 20);
    BN_mul(result, a, b, ctx);
    res_value := BN_get_word(result);
    RunTest('BN_mul (15 * 20 = 300)', res_value = 300);
  end
  else
    RunTest('BN_mul (15 * 20 = 300)', False);
    
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if result <> nil then BN_free(result);
  if ctx <> nil then BN_CTX_free(ctx);
end;

procedure Test_BN_Division;
var
  a, b, quotient, remainder: PBIGNUM;
  ctx: PBN_CTX;
  quot_value: Cardinal;
begin
  a := BN_new();
  b := BN_new();
  quotient := BN_new();
  remainder := BN_new();
  ctx := BN_CTX_new();
  
  if (a <> nil) and (b <> nil) and (quotient <> nil) and (remainder <> nil) and (ctx <> nil) then
  begin
    BN_set_word(a, 1000);
    BN_set_word(b, 7);
    BN_div(quotient, remainder, a, b, ctx);
    quot_value := BN_get_word(quotient);
    RunTest('BN_div (1000 / 7 = 142)', quot_value = 142);
  end
  else
    RunTest('BN_div (1000 / 7 = 142)', False);
    
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if quotient <> nil then BN_free(quotient);
  if remainder <> nil then BN_free(remainder);
  if ctx <> nil then BN_CTX_free(ctx);
end;

procedure Test_BN_Modulo;
var
  a, b, result: PBIGNUM;
  ctx: PBN_CTX;
  res_value: Cardinal;
begin
  a := BN_new();
  b := BN_new();
  result := BN_new();
  ctx := BN_CTX_new();
  
  if (a <> nil) and (b <> nil) and (result <> nil) and (ctx <> nil) then
  begin
    BN_set_word(a, 100);
    BN_set_word(b, 7);
    BN_mod(result, a, b, ctx);
    res_value := BN_get_word(result);
    RunTest('BN_mod (100 mod 7 = 2)', res_value = 2);
  end
  else
    RunTest('BN_mod (100 mod 7 = 2)', False);
    
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
  if result <> nil then BN_free(result);
  if ctx <> nil then BN_CTX_free(ctx);
end;

procedure Test_BN_Comparison;
var
  a, b: PBIGNUM;
  cmp_result: Integer;
begin
  a := BN_new();
  b := BN_new();
  
  if (a <> nil) and (b <> nil) then
  begin
    BN_set_word(a, 100);
    BN_set_word(b, 200);
    cmp_result := BN_cmp(a, b);
    RunTest('BN_cmp (100 < 200)', cmp_result < 0);
    
    BN_set_word(a, 200);
    BN_set_word(b, 200);
    cmp_result := BN_cmp(a, b);
    RunTest('BN_cmp (200 = 200)', cmp_result = 0);
    
    BN_set_word(a, 300);
    BN_set_word(b, 200);
    cmp_result := BN_cmp(a, b);
    RunTest('BN_cmp (300 > 200)', cmp_result > 0);
  end
  else
  begin
    RunTest('BN_cmp (100 < 200)', False);
    RunTest('BN_cmp (200 = 200)', False);
    RunTest('BN_cmp (300 > 200)', False);
  end;
    
  if a <> nil then BN_free(a);
  if b <> nil then BN_free(b);
end;

procedure Test_BN_Hex_Conversion;
var
  bn: PBIGNUM;
  hex_str: PAnsiChar;
  success: Boolean;
begin
  bn := BN_new();
  if bn <> nil then
  begin
    BN_set_word(bn, $DEADBEEF);
    hex_str := BN_bn2hex(bn);
    success := (hex_str <> nil) and (Length(string(hex_str)) > 0);
    RunTest('BN_bn2hex conversion', success);
    // Note: hex_str should be freed with OPENSSL_free, omitted for simplicity
    BN_free(bn);
  end
  else
    RunTest('BN_bn2hex conversion', False);
end;

procedure Test_BN_Dec_Conversion;
var
  bn: PBIGNUM;
  dec_str: PAnsiChar;
  success: Boolean;
begin
  bn := BN_new();
  if bn <> nil then
  begin
    BN_set_word(bn, 123456789);
    dec_str := BN_bn2dec(bn);
    success := (dec_str <> nil) and (string(dec_str) = '123456789');
    RunTest('BN_bn2dec conversion', success);
    // Note: dec_str should be freed with OPENSSL_free, omitted for simplicity
    BN_free(bn);
  end
  else
    RunTest('BN_bn2dec conversion', False);
end;

begin
  WriteLn('========================================');
  WriteLn('  OpenSSL BN (BigNum) Module Test');
  WriteLn('========================================');
  WriteLn;
  
  TestsPassed := 0;
  TestsFailed := 0;
  
  if not LoadOpenSSLLibrary then
  begin
    WriteLn('ERROR: Failed to load OpenSSL library');
    Halt(1);
  end;
  
  try
    WriteLn('Running BN tests...');
    WriteLn;
    
    Test_BN_Creation;
    Test_BN_SetWord;
    Test_BN_Addition;
    Test_BN_Subtraction;
    Test_BN_Multiplication;
    Test_BN_Division;
    Test_BN_Modulo;
    Test_BN_Comparison;
    Test_BN_Hex_Conversion;
    Test_BN_Dec_Conversion;
    
    WriteLn;
    WriteLn('========================================');
    WriteLn('  Test Results');
    WriteLn('========================================');
    WriteLn('Tests Passed: ', TestsPassed);
    WriteLn('Tests Failed: ', TestsFailed);
    WriteLn('Total Tests:  ', TestsPassed + TestsFailed);
    WriteLn('Success Rate: ', ((TestsPassed * 100) div (TestsPassed + TestsFailed)):3, '%');
    WriteLn;
    
    if TestsFailed = 0 then
    begin
      WriteLn('✓ All BN tests PASSED!');
      Halt(0);
    end
    else
    begin
      WriteLn('✗ Some BN tests FAILED!');
      Halt(1);
    end;
    
  finally
    UnloadOpenSSLLibrary;
  end;
end.
