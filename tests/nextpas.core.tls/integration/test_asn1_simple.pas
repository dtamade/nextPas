program test_asn1_simple;

{******************************************************************************}
{  ASN.1 Simple Integration Tests                                              }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

type
  { ASN.1 Basic Function Types }
  TASN1_INTEGER_new = function: PASN1_INTEGER; cdecl;
  TASN1_INTEGER_free = procedure(a: PASN1_INTEGER); cdecl;
  TASN1_INTEGER_set = function(a: PASN1_INTEGER; v: clong): Integer; cdecl;
  TASN1_INTEGER_get = function(const a: PASN1_INTEGER): clong; cdecl;
  TASN1_INTEGER_set_int64 = function(a: PASN1_INTEGER; r: Int64): Integer; cdecl;
  TASN1_INTEGER_get_int64 = function(pr: PInt64; const a: PASN1_INTEGER): Integer; cdecl;
  TASN1_INTEGER_dup = function(const x: PASN1_INTEGER): PASN1_INTEGER; cdecl;
  TASN1_INTEGER_cmp = function(const x, y: PASN1_INTEGER): Integer; cdecl;

  TASN1_STRING_new = function: PASN1_STRING; cdecl;
  TASN1_STRING_free = procedure(a: PASN1_STRING); cdecl;
  TASN1_STRING_type_new = function(atype: Integer): PASN1_STRING; cdecl;
  TASN1_STRING_set = function(str: PASN1_STRING; const data: Pointer; len: Integer): Integer; cdecl;
  TASN1_STRING_length = function(const x: PASN1_STRING): Integer; cdecl;
  TASN1_STRING_get0_data = function(const x: PASN1_STRING): PByte; cdecl;
  TASN1_STRING_data = function(x: PASN1_STRING): PByte; cdecl;
  TASN1_STRING_type = function(const x: PASN1_STRING): Integer; cdecl;
  TASN1_STRING_cmp = function(const a, b: PASN1_STRING): Integer; cdecl;
  TASN1_STRING_dup = function(const a: PASN1_STRING): PASN1_STRING; cdecl;

  TASN1_OCTET_STRING_new = function: PASN1_OCTET_STRING; cdecl;
  TASN1_OCTET_STRING_free = procedure(a: PASN1_OCTET_STRING); cdecl;
  TASN1_OCTET_STRING_set = function(str: PASN1_OCTET_STRING; const data: PByte; len: Integer): Integer; cdecl;
  TASN1_OCTET_STRING_dup = function(const a: PASN1_OCTET_STRING): PASN1_OCTET_STRING; cdecl;
  TASN1_OCTET_STRING_cmp = function(const a, b: PASN1_OCTET_STRING): Integer; cdecl;

  TASN1_TIME_new = function: PASN1_TIME; cdecl;
  TASN1_TIME_free = procedure(a: PASN1_TIME); cdecl;
  TASN1_TIME_set = function(s: PASN1_TIME; t: time_t): PASN1_TIME; cdecl;
  TASN1_TIME_set_string = function(s: PASN1_TIME; const str: PAnsiChar): Integer; cdecl;
  TASN1_TIME_check = function(const t: PASN1_TIME): Integer; cdecl;

const
  V_ASN1_OCTET_STRING = 4;
  V_ASN1_UTF8STRING = 12;
  V_ASN1_PRINTABLESTRING = 19;

var
  Runner: TSimpleTestRunner;

  { Function pointers }
  ASN1_INTEGER_new: TASN1_INTEGER_new = nil;
  ASN1_INTEGER_free: TASN1_INTEGER_free = nil;
  ASN1_INTEGER_set: TASN1_INTEGER_set = nil;
  ASN1_INTEGER_get: TASN1_INTEGER_get = nil;
  ASN1_INTEGER_set_int64: TASN1_INTEGER_set_int64 = nil;
  ASN1_INTEGER_get_int64: TASN1_INTEGER_get_int64 = nil;
  ASN1_INTEGER_dup: TASN1_INTEGER_dup = nil;
  ASN1_INTEGER_cmp: TASN1_INTEGER_cmp = nil;

  ASN1_STRING_new: TASN1_STRING_new = nil;
  ASN1_STRING_free: TASN1_STRING_free = nil;
  ASN1_STRING_type_new: TASN1_STRING_type_new = nil;
  ASN1_STRING_set: TASN1_STRING_set = nil;
  ASN1_STRING_length: TASN1_STRING_length = nil;
  ASN1_STRING_get0_data: TASN1_STRING_get0_data = nil;
  ASN1_STRING_data: TASN1_STRING_data = nil;
  ASN1_STRING_type: TASN1_STRING_type = nil;
  ASN1_STRING_cmp: TASN1_STRING_cmp = nil;
  ASN1_STRING_dup: TASN1_STRING_dup = nil;

  ASN1_OCTET_STRING_new: TASN1_OCTET_STRING_new = nil;
  ASN1_OCTET_STRING_free: TASN1_OCTET_STRING_free = nil;
  ASN1_OCTET_STRING_set: TASN1_OCTET_STRING_set = nil;
  ASN1_OCTET_STRING_dup: TASN1_OCTET_STRING_dup = nil;
  ASN1_OCTET_STRING_cmp: TASN1_OCTET_STRING_cmp = nil;

  ASN1_TIME_new: TASN1_TIME_new = nil;
  ASN1_TIME_free: TASN1_TIME_free = nil;
  ASN1_TIME_set: TASN1_TIME_set = nil;
  ASN1_TIME_set_string: TASN1_TIME_set_string = nil;
  ASN1_TIME_check: TASN1_TIME_check = nil;

function LoadASN1Functions: Boolean;
var
  LibHandle: TLibHandle;
begin
  Result := False;
  LibHandle := GetCryptoLibHandle;
  if LibHandle = 0 then Exit;

  ASN1_INTEGER_new := TASN1_INTEGER_new(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_new'));
  ASN1_INTEGER_free := TASN1_INTEGER_free(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_free'));
  ASN1_INTEGER_set := TASN1_INTEGER_set(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_set'));
  ASN1_INTEGER_get := TASN1_INTEGER_get(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_get'));
  ASN1_INTEGER_set_int64 := TASN1_INTEGER_set_int64(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_set_int64'));
  ASN1_INTEGER_get_int64 := TASN1_INTEGER_get_int64(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_get_int64'));
  ASN1_INTEGER_dup := TASN1_INTEGER_dup(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_dup'));
  ASN1_INTEGER_cmp := TASN1_INTEGER_cmp(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_cmp'));

  ASN1_STRING_new := TASN1_STRING_new(GetProcedureAddress(LibHandle, 'ASN1_STRING_new'));
  ASN1_STRING_free := TASN1_STRING_free(GetProcedureAddress(LibHandle, 'ASN1_STRING_free'));
  ASN1_STRING_type_new := TASN1_STRING_type_new(GetProcedureAddress(LibHandle, 'ASN1_STRING_type_new'));
  ASN1_STRING_set := TASN1_STRING_set(GetProcedureAddress(LibHandle, 'ASN1_STRING_set'));
  ASN1_STRING_length := TASN1_STRING_length(GetProcedureAddress(LibHandle, 'ASN1_STRING_length'));
  ASN1_STRING_get0_data := TASN1_STRING_get0_data(GetProcedureAddress(LibHandle, 'ASN1_STRING_get0_data'));
  ASN1_STRING_data := TASN1_STRING_data(GetProcedureAddress(LibHandle, 'ASN1_STRING_data'));
  ASN1_STRING_type := TASN1_STRING_type(GetProcedureAddress(LibHandle, 'ASN1_STRING_type'));
  ASN1_STRING_cmp := TASN1_STRING_cmp(GetProcedureAddress(LibHandle, 'ASN1_STRING_cmp'));
  ASN1_STRING_dup := TASN1_STRING_dup(GetProcedureAddress(LibHandle, 'ASN1_STRING_dup'));

  ASN1_OCTET_STRING_new := TASN1_OCTET_STRING_new(GetProcedureAddress(LibHandle, 'ASN1_OCTET_STRING_new'));
  ASN1_OCTET_STRING_free := TASN1_OCTET_STRING_free(GetProcedureAddress(LibHandle, 'ASN1_OCTET_STRING_free'));
  ASN1_OCTET_STRING_set := TASN1_OCTET_STRING_set(GetProcedureAddress(LibHandle, 'ASN1_OCTET_STRING_set'));
  ASN1_OCTET_STRING_dup := TASN1_OCTET_STRING_dup(GetProcedureAddress(LibHandle, 'ASN1_OCTET_STRING_dup'));
  ASN1_OCTET_STRING_cmp := TASN1_OCTET_STRING_cmp(GetProcedureAddress(LibHandle, 'ASN1_OCTET_STRING_cmp'));

  ASN1_TIME_new := TASN1_TIME_new(GetProcedureAddress(LibHandle, 'ASN1_TIME_new'));
  ASN1_TIME_free := TASN1_TIME_free(GetProcedureAddress(LibHandle, 'ASN1_TIME_free'));
  ASN1_TIME_set := TASN1_TIME_set(GetProcedureAddress(LibHandle, 'ASN1_TIME_set'));
  ASN1_TIME_set_string := TASN1_TIME_set_string(GetProcedureAddress(LibHandle, 'ASN1_TIME_set_string'));
  ASN1_TIME_check := TASN1_TIME_check(GetProcedureAddress(LibHandle, 'ASN1_TIME_check'));

  Result := Assigned(ASN1_INTEGER_new) and Assigned(ASN1_STRING_new);
end;

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
  Runner.Check('Get value equals 42', value = 42, Format('Value: %d', [value]));

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
  Runner.Check('Get string length', len = Length(test_data), Format('Length: %d', [len]));

  data := ASN1_STRING_get0_data(str1);
  Runner.Check('Get string data', data <> nil);

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

  current_time := 0;
  Runner.Check('Set time to epoch', ASN1_TIME_set(time1, current_time) <> nil);

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
    if not LoadASN1Functions then
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
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
