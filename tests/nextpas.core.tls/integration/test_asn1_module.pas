program test_asn1_module;

{******************************************************************************}
{  ASN.1 Module Integration Tests                                              }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestASN1IntegerBasic;
var
  int1: PASN1_INTEGER;
  value: clong;
begin
  WriteLn;
  WriteLn('=== ASN1_INTEGER Basic Operations ===');

  int1 := ASN1_INTEGER_new();
  Runner.Check('Create ASN1_INTEGER', int1 <> nil);
  if int1 = nil then Exit;

  Runner.Check('Set value to 42', ASN1_INTEGER_set(int1, 42) = 1);

  value := ASN1_INTEGER_get(int1);
  Runner.Check('Get value equals 42', value = 42, Format('Value=%d', [value]));

  ASN1_INTEGER_free(int1);
end;

procedure TestASN1IntegerInt64;
var
  int1: PASN1_INTEGER;
  value: Int64;
  test_val: Int64;
begin
  WriteLn;
  WriteLn('=== ASN1_INTEGER 64-bit Operations ===');

  int1 := ASN1_INTEGER_new();
  Runner.Check('Create ASN1_INTEGER', int1 <> nil);
  if int1 = nil then Exit;

  test_val := 9876543210;
  Runner.Check('Set 64-bit value', ASN1_INTEGER_set_int64(int1, test_val) = 1,
          Format('Value: %d', [test_val]));

  value := 0;
  Runner.Check('Get 64-bit value', ASN1_INTEGER_get_int64(@value, int1) = 1);
  Runner.Check('Value matches', value = test_val, Format('Got: %d', [value]));

  ASN1_INTEGER_free(int1);
end;

procedure TestASN1IntegerDupCmp;
var
  int1, int2: PASN1_INTEGER;
begin
  WriteLn;
  WriteLn('=== ASN1_INTEGER Duplication and Comparison ===');

  int1 := ASN1_INTEGER_new();
  Runner.Check('Create ASN1_INTEGER', int1 <> nil);
  if int1 = nil then Exit;

  ASN1_INTEGER_set(int1, 12345);

  int2 := ASN1_INTEGER_dup(int1);
  Runner.Check('Duplicate ASN1_INTEGER', int2 <> nil);

  if int2 <> nil then
  begin
    Runner.Check('Integers are equal', ASN1_INTEGER_cmp(int1, int2) = 0);
    ASN1_INTEGER_free(int2);
  end;

  ASN1_INTEGER_free(int1);
end;

procedure TestASN1StringBasic;
var
  str1: PASN1_STRING;
  data: PByte;
  len: Integer;
  test_data: AnsiString;
begin
  WriteLn;
  WriteLn('=== ASN1_STRING Basic Operations ===');

  test_data := 'Hello ASN.1!';

  str1 := ASN1_STRING_new();
  Runner.Check('Create ASN1_STRING', str1 <> nil);
  if str1 = nil then Exit;

  Runner.Check('Set string data', ASN1_STRING_set(str1, PAnsiChar(test_data), Length(test_data)) = 1);

  len := ASN1_STRING_length(str1);
  Runner.Check('Get string length', len = Length(test_data), Format('Length=%d', [len]));

  data := ASN1_STRING_get0_data(str1);
  Runner.Check('Get string data', data <> nil);
  if data <> nil then
    WriteLn('  String content: ', PAnsiChar(data));

  ASN1_STRING_free(str1);
end;

procedure TestASN1StringTyped;
var
  str1: PASN1_STRING;
  str_type: Integer;
begin
  WriteLn;
  WriteLn('=== ASN1_STRING Type-Specific ===');

  str1 := ASN1_STRING_type_new(V_ASN1_UTF8STRING);
  Runner.Check('Create UTF8 string', str1 <> nil);
  if str1 = nil then Exit;

  str_type := ASN1_STRING_type(str1);
  Runner.Check('Verify string type', str_type = V_ASN1_UTF8STRING,
          Format('Type: %d (expected %d)', [str_type, V_ASN1_UTF8STRING]));

  ASN1_STRING_free(str1);
end;

procedure TestASN1OctetString;
var
  oct1, oct2: PASN1_OCTET_STRING;
  test_data: array[0..9] of Byte = (1,2,3,4,5,6,7,8,9,10);
begin
  WriteLn;
  WriteLn('=== ASN1_OCTET_STRING Operations ===');

  oct1 := ASN1_OCTET_STRING_new();
  Runner.Check('Create ASN1_OCTET_STRING', oct1 <> nil);
  if oct1 = nil then Exit;

  Runner.Check('Set octet string data', ASN1_OCTET_STRING_set(oct1, @test_data[0], Length(test_data)) = 1);

  oct2 := ASN1_OCTET_STRING_dup(oct1);
  Runner.Check('Duplicate octet string', oct2 <> nil);

  if oct2 <> nil then
  begin
    Runner.Check('Octet strings are equal', ASN1_OCTET_STRING_cmp(oct1, oct2) = 0);
    ASN1_OCTET_STRING_free(oct2);
  end;

  ASN1_OCTET_STRING_free(oct1);
end;

procedure TestASN1Time;
var
  time1: PASN1_TIME;
  current_time: time_t;
begin
  WriteLn;
  WriteLn('=== ASN1_TIME Operations ===');

  time1 := ASN1_TIME_new();
  Runner.Check('Create ASN1_TIME', time1 <> nil);
  if time1 = nil then Exit;

  current_time := 0; // Use 0 for current time
  Runner.Check('Set time to current', ASN1_TIME_set(time1, current_time) <> nil);
  Runner.Check('Check time validity', ASN1_TIME_check(time1) = 1);
  Runner.Check('Set time from string', ASN1_TIME_set_string(time1, '20250101120000Z') = 1);

  ASN1_TIME_free(time1);
end;

begin
  WriteLn('ASN.1 Module Integration Test');
  WriteLn('==============================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Load ASN1 functions
    if not LoadOpenSSLASN1(GetCryptoLibHandle) then
    begin
      WriteLn('ERROR: Could not load ASN1 functions');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestASN1IntegerBasic;
    TestASN1IntegerInt64;
    TestASN1IntegerDupCmp;
    TestASN1StringBasic;
    TestASN1StringTyped;
    TestASN1OctetString;
    TestASN1Time;

    Runner.PrintSummary;
    UnloadOpenSSLASN1;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
