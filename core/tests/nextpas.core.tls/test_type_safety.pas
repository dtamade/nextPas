program test_type_safety;

{$mode objfpc}{$H+}{$J-}

{**
 * Phase 2.4 - Type Safety Test Suite
 *
 * Tests for:
 * - Enumeration types
 * - Unit types (TKeySize, TTimeoutDuration, TBufferSize)
 * - Generic types (TSecureData<T>, TResult<T,E>)
 *}

uses
  SysUtils,
  nextpas.core.tls.safety;

type
  TIntSecureData = specialize TSecureData<Integer>;
  TStringSecureData = specialize TSecureData<string>;
  TIntStringResult = specialize TResult<Integer, string>;
  TBytesStringResult = specialize TResult<TBytes, string>;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

{**
 * Test 1: SSLVersion Enum Conversions
 *}
procedure TestSSLVersionEnum;
var
  LVersion: TSSLVersion;
  LStr: string;
begin
  WriteLn;
  WriteLn('=== Test 1: TSSLVersion Enumeration ===');

  // Test enum to string
  LStr := SSLVersionToString(sslv_TLS12);
  Assert(LStr = 'TLS 1.2', 'TLS 1.2 should convert to string correctly');

  LStr := SSLVersionToString(sslv_TLS13);
  Assert(LStr = 'TLS 1.3', 'TLS 1.3 should convert to string correctly');

  // Test string to enum
  LVersion := StringToSSLVersion('TLS 1.2');
  Assert(LVersion = sslv_TLS12, 'String "TLS 1.2" should parse correctly');

  LVersion := StringToSSLVersion('TLS1.3');
  Assert(LVersion = sslv_TLS13, 'String "TLS1.3" should parse correctly');

  LVersion := StringToSSLVersion('tlsv13');
  Assert(LVersion = sslv_TLS13, 'String "tlsv13" should parse correctly (case insensitive)');
end;

{**
 * Test 2: KeyType Enum Conversions
 *}
procedure TestKeyTypeEnum;
var
  LStr: string;
begin
  WriteLn;
  WriteLn('=== Test 2: TKeyType Enumeration ===');

  LStr := KeyTypeToString(kt_RSA);
  Assert(LStr = 'RSA', 'RSA should convert correctly');

  LStr := KeyTypeToString(kt_EC);
  Assert(LStr = 'EC', 'EC should convert correctly');

  LStr := KeyTypeToString(kt_Ed25519);
  Assert(LStr = 'Ed25519', 'Ed25519 should convert correctly');
end;

{**
 * Test 3: CertificateFormat Enum Conversions
 *}
procedure TestCertificateFormatEnum;
var
  LStr: string;
begin
  WriteLn;
  WriteLn('=== Test 3: TCertificateFormat Enumeration ===');

  LStr := CertificateFormatToString(cf_PEM);
  Assert(LStr = 'PEM', 'PEM should convert correctly');

  LStr := CertificateFormatToString(cf_DER);
  Assert(LStr = 'DER', 'DER should convert correctly');

  LStr := CertificateFormatToString(cf_PKCS12);
  Assert(LStr = 'PKCS12', 'PKCS12 should convert correctly');
end;

{**
 * Test 4: TKeySize Unit Type Safety
 *}
procedure TestKeySizeUnitType;
var
  LSize1, LSize2, LSize3: TKeySize;
  LErrorRaised: Boolean;
begin
  WriteLn;
  WriteLn('=== Test 4: TKeySize Unit Type Safety ===');

  // Test bits constructor
  LSize1 := TKeySize.Bits(256);
  Assert(LSize1.ToBits = 256, 'Bits constructor should store bits correctly');
  Assert(LSize1.ToBytes = 32, 'Bits(256) should equal 32 bytes');

  // Test bytes constructor
  LSize2 := TKeySize.Bytes(32);
  Assert(LSize2.ToBits = 256, 'Bytes(32) should equal 256 bits');
  Assert(LSize2.ToBytes = 32, 'Bytes constructor should store bytes correctly');

  // Test equality
  Assert(LSize1.IsEqual(LSize2), '256 bits should equal 32 bytes');

  // Test comparison
  LSize3 := TKeySize.Bits(128);
  Assert(LSize3.Compare(LSize1) < 0, '128 bits should be less than 256 bits');
  Assert(LSize1.Compare(LSize3) > 0, '256 bits should be greater than 128 bits');
  Assert(LSize1.Compare(LSize2) = 0, 'Equal sizes should compare as 0');

  // Test validation
  Assert(LSize1.IsValid, 'Valid key size should pass validation');

  // Test error: non-multiple of 8
  LErrorRaised := False;
  try
    LSize1 := TKeySize.Bits(127);
  except
    on E: Exception do
      LErrorRaised := True;
  end;
  Assert(LErrorRaised, 'Non-multiple of 8 bits should raise error');

  // Test error: negative size
  LErrorRaised := False;
  try
    LSize1 := TKeySize.Bytes(-1);
  except
    on E: Exception do
      LErrorRaised := True;
  end;
  Assert(LErrorRaised, 'Negative size should raise error');
end;

{**
 * Test 5: TTimeoutDuration Unit Type Safety
 *}
procedure TestTimeoutDurationUnitType;
var
  LTimeout1, LTimeout2, LTimeout3: TTimeoutDuration;
begin
  WriteLn;
  WriteLn('=== Test 5: TTimeoutDuration Unit Type Safety ===');

  // Test milliseconds constructor
  LTimeout1 := TTimeoutDuration.Milliseconds(5000);
  Assert(LTimeout1.ToMilliseconds = 5000, 'Milliseconds should store correctly');
  Assert(Abs(LTimeout1.ToSeconds - 5.0) < 0.001, '5000ms should equal 5 seconds');

  // Test seconds constructor
  LTimeout2 := TTimeoutDuration.Seconds(5);
  Assert(LTimeout2.ToMilliseconds = 5000, 'Seconds should convert to milliseconds');
  Assert(LTimeout1.IsEqual(LTimeout2), '5000ms should equal 5 seconds');

  // Test minutes constructor
  LTimeout3 := TTimeoutDuration.Minutes(2);
  Assert(LTimeout3.ToMilliseconds = 120000, 'Minutes should convert correctly');
  Assert(Abs(LTimeout3.ToSeconds - 120.0) < 0.001, '2 minutes should equal 120 seconds');

  // Test infinite
  LTimeout1 := TTimeoutDuration.Infinite;
  Assert(LTimeout1.IsInfinite, 'Infinite timeout should be recognized');

  // Test comparison
  LTimeout1 := TTimeoutDuration.Seconds(10);
  LTimeout2 := TTimeoutDuration.Seconds(5);
  Assert(LTimeout1.Compare(LTimeout2) > 0, '10s should be greater than 5s');
  Assert(LTimeout2.Compare(LTimeout1) < 0, '5s should be less than 10s');
end;

{**
 * Test 6: TBufferSize Unit Type Safety
 *}
procedure TestBufferSizeUnitType;
var
  LSize1, LSize2, LSize3: TBufferSize;
begin
  WriteLn;
  WriteLn('=== Test 6: TBufferSize Unit Type Safety ===');

  // Test bytes constructor
  LSize1 := TBufferSize.Bytes(2048);
  Assert(LSize1.ToBytes = 2048, 'Bytes should store correctly');
  Assert(LSize1.ToKB = 2, '2048 bytes should equal 2 KB');

  // Test KB constructor
  LSize2 := TBufferSize.KB(2);
  Assert(LSize2.ToBytes = 2048, 'KB should convert to bytes');
  Assert(LSize1.IsEqual(LSize2), '2048 bytes should equal 2 KB');

  // Test MB constructor
  LSize3 := TBufferSize.MB(1);
  Assert(LSize3.ToBytes = 1048576, 'MB should convert to bytes');
  Assert(LSize3.ToKB = 1024, '1 MB should equal 1024 KB');
  Assert(LSize3.ToMB = 1, 'MB should round-trip correctly');

  // Test comparison
  Assert(LSize3.Compare(LSize1) > 0, '1 MB should be greater than 2 KB');
  Assert(LSize1.Compare(LSize3) < 0, '2 KB should be less than 1 MB');
end;

{**
 * Test 7: TSecureData<T> - Some/None Pattern
 *}
procedure TestSecureDataSomeNone;
var
  LData: TIntSecureData;
  LValue: Integer;
begin
  WriteLn;
  WriteLn('=== Test 7: TSecureData<T> Some/None Pattern ===');

  // Test Some
  LData := TIntSecureData.Some(42);
  Assert(LData.IsValid, 'Some should be valid');
  Assert(LData.IsSome, 'Some should return true for IsSome');
  Assert(not LData.IsNone, 'Some should return false for IsNone');

  LValue := LData.Unwrap;
  Assert(LValue = 42, 'Unwrap should return stored value');

  // Test None
  LData := TIntSecureData.None('Test error');
  Assert(not LData.IsValid, 'None should not be valid');
  Assert(LData.IsNone, 'None should return true for IsNone');
  Assert(not LData.IsSome, 'None should return false for IsSome');
  Assert(LData.ErrorMessage = 'Test error', 'Error message should be stored');
end;

{**
 * Test 8: TSecureData<T> - UnwrapOr Default Value
 *}
procedure TestSecureDataUnwrapOr;
var
  LData: TIntSecureData;
  LValue: Integer;
begin
  WriteLn;
  WriteLn('=== Test 8: TSecureData<T> UnwrapOr ===');

  // Test Some with UnwrapOr
  LData := TIntSecureData.Some(42);
  LValue := LData.UnwrapOr(100);
  Assert(LValue = 42, 'UnwrapOr should return actual value for Some');

  // Test None with UnwrapOr
  LData := TIntSecureData.None;
  LValue := LData.UnwrapOr(100);
  Assert(LValue = 100, 'UnwrapOr should return default value for None');
end;

{**
 * Test 9: TSecureData<T> - Unwrap Error Handling
 *}
procedure TestSecureDataUnwrapError;
var
  LData: TIntSecureData;
  LValue: Integer;
  LErrorRaised: Boolean;
begin
  WriteLn;
  WriteLn('=== Test 9: TSecureData<T> Unwrap Error ===');

  // Test Unwrap on None should raise error
  LData := TIntSecureData.None('No value');
  LErrorRaised := False;
  try
    LValue := LData.Unwrap;
  except
    on E: Exception do
      LErrorRaised := True;
  end;
  Assert(LErrorRaised, 'Unwrap on None should raise exception');
end;

{**
 * Test 10: TResult<T,E> - Ok/Err Pattern
 *}
procedure TestResultOkErr;
var
  LResult: TIntStringResult;
  LValue: Integer;
  LError: string;
begin
  WriteLn;
  WriteLn('=== Test 10: TResult<T,E> Ok/Err Pattern ===');

  // Test Ok
  LResult := TIntStringResult.Ok(42);
  Assert(LResult.IsOk, 'Ok should return true for IsOk');
  Assert(not LResult.IsErr, 'Ok should return false for IsErr');

  LValue := LResult.Unwrap;
  Assert(LValue = 42, 'Unwrap should return Ok value');

  // Test Err
  LResult := TIntStringResult.Err('Operation failed');
  Assert(LResult.IsErr, 'Err should return true for IsErr');
  Assert(not LResult.IsOk, 'Err should return false for IsOk');

  LError := LResult.UnwrapErr;
  Assert(LError = 'Operation failed', 'UnwrapErr should return error value');
end;

{**
 * Test 11: TResult<T,E> - UnwrapOr Default Value
 *}
procedure TestResultUnwrapOr;
var
  LResult: TIntStringResult;
  LValue: Integer;
begin
  WriteLn;
  WriteLn('=== Test 11: TResult<T,E> UnwrapOr ===');

  // Test Ok with UnwrapOr
  LResult := TIntStringResult.Ok(42);
  LValue := LResult.UnwrapOr(100);
  Assert(LValue = 42, 'UnwrapOr should return actual value for Ok');

  // Test Err with UnwrapOr
  LResult := TIntStringResult.Err('Error');
  LValue := LResult.UnwrapOr(100);
  Assert(LValue = 100, 'UnwrapOr should return default value for Err');
end;

{**
 * Test 12: TResult<T,E> - Unwrap/UnwrapErr Error Handling
 *}
procedure TestResultUnwrapErrors;
var
  LResult: TIntStringResult;
  LValue: Integer;
  LError: string;
  LErrorRaised: Boolean;
begin
  WriteLn;
  WriteLn('=== Test 12: TResult<T,E> Unwrap Errors ===');

  // Test Unwrap on Err should raise error
  LResult := TIntStringResult.Err('Failed');
  LErrorRaised := False;
  try
    LValue := LResult.Unwrap;
  except
    on E: Exception do
      LErrorRaised := True;
  end;
  Assert(LErrorRaised, 'Unwrap on Err should raise exception');

  // Test UnwrapErr on Ok should raise error
  LResult := TIntStringResult.Ok(42);
  LErrorRaised := False;
  try
    LError := LResult.UnwrapErr;
  except
    on E: Exception do
      LErrorRaised := True;
  end;
  Assert(LErrorRaised, 'UnwrapErr on Ok should raise exception');
end;

{**
 * Test 13: EllipticCurve NID Mappings
 *}
procedure TestEllipticCurveNID;
var
  LNID: Integer;
  LStr: string;
begin
  WriteLn;
  WriteLn('=== Test 13: TEllipticCurve NID Mappings ===');

  // Test NID conversions
  LNID := EllipticCurveToNID(ec_P256);
  Assert(LNID = 415, 'P-256 should map to NID 415');

  LNID := EllipticCurveToNID(ec_P384);
  Assert(LNID = 715, 'P-384 should map to NID 715');

  LNID := EllipticCurveToNID(ec_X25519);
  Assert(LNID = 1034, 'X25519 should map to NID 1034');

  // Test string conversions
  LStr := EllipticCurveToString(ec_P256);
  Assert(LStr = 'P-256', 'P-256 should convert to string correctly');

  LStr := EllipticCurveToString(ec_BrainpoolP384);
  Assert(LStr = 'Brainpool P-384', 'BrainpoolP384 should convert correctly');
end;

{**
 * Test 14: CipherMode Enum Conversions
 *}
procedure TestCipherModeEnum;
var
  LStr: string;
begin
  WriteLn;
  WriteLn('=== Test 14: TCipherMode Enumeration ===');

  LStr := CipherModeToString(cm_GCM);
  Assert(LStr = 'GCM', 'GCM should convert correctly');

  LStr := CipherModeToString(cm_CBC);
  Assert(LStr = 'CBC', 'CBC should convert correctly');

  LStr := CipherModeToString(cm_CTR);
  Assert(LStr = 'CTR', 'CTR should convert correctly');
end;

{**
 * Test 15: Practical Use Case - TSecureData<string>
 *}
procedure TestSecureDataStringPractical;
var
  LData: TStringSecureData;
  LValue: string;
begin
  WriteLn;
  WriteLn('=== Test 15: TSecureData<string> Practical Use ===');

  // Simulate optional configuration value
  LData := TStringSecureData.Some('localhost');
  Assert(LData.IsSome, 'Config value should be Some');
  LValue := LData.UnwrapOr('default.server.com');
  Assert(LValue = 'localhost', 'Should use configured value');

  // Simulate missing configuration
  LData := TStringSecureData.None('Config not found');
  Assert(LData.IsNone, 'Missing config should be None');
  LValue := LData.UnwrapOr('default.server.com');
  Assert(LValue = 'default.server.com', 'Should use default value');
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.4: Type Safety Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Test Summary:');
  WriteLn('  Tests Passed: ', GTestsPassed);
  WriteLn('  Tests Failed: ', GTestsFailed);
  WriteLn('  Total Tests:  ', GTestsPassed + GTestsFailed);
  WriteLn;

  if GTestsFailed = 0 then
  begin
    WriteLn('  ✓ ALL TESTS PASSED!');
    WriteLn;
  end
  else
  begin
    WriteLn('  ✗ SOME TESTS FAILED!');
    WriteLn;
    Halt(1);
  end;
end;

begin
  try
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Phase 2.4: Type Safety Tests');
    WriteLn('═══════════════════════════════════════════════════════════');

    TestSSLVersionEnum;
    TestKeyTypeEnum;
    TestCertificateFormatEnum;
    TestKeySizeUnitType;
    TestTimeoutDurationUnitType;
    TestBufferSizeUnitType;
    TestSecureDataSomeNone;
    TestSecureDataUnwrapOr;
    TestSecureDataUnwrapError;
    TestResultOkErr;
    TestResultUnwrapOr;
    TestResultUnwrapErrors;
    TestEllipticCurveNID;
    TestCipherModeEnum;
    TestSecureDataStringPractical;

    PrintSummary;

    WriteLn('✓ Phase 2.4 Type safety implementation complete!');
    WriteLn('✓ All enumeration, unit, and generic types working correctly!');
    WriteLn;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('✗ Unexpected error: ', E.Message);
      Halt(1);
    end;
  end;
end.
