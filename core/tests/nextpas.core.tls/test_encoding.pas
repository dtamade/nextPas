{
  test_encoding.pas - Unit tests for nextpas.core.tls.encoding

  Tests encoding utilities:
  - Hex encoding/decoding (BytesToHex, HexToBytes)
  - Base64 encoding/decoding (OpenSSL BIO based)
  - Try* variants for error handling
  - String helper functions
}

unit test_encoding;

{$mode objfpc}{$H+}
{$UNITPATH framework}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  test_base, nextpas.core.tls.encoding, nextpas.core.tls.exceptions, nextpas.core.tls.base;

type
  { TTestEncoding - Tests for encoding utilities }
  TTestEncoding = class(TTestBase)
  private
    FOpenSSLAvailable: Boolean;
  protected
    procedure SetUp; override;
  published
    // Hex encoding tests
    procedure Test_BytesToHex_EmptyArray;
    procedure Test_BytesToHex_SingleByte;
    procedure Test_BytesToHex_MultiByte;
    procedure Test_BytesToHex_UpperCase;
    procedure Test_BytesToHex_LowerCase;
    procedure Test_BytesToHex_AllValues;

    // Hex decoding tests
    procedure Test_HexToBytes_EmptyString;
    procedure Test_HexToBytes_SingleByte;
    procedure Test_HexToBytes_MultiByte;
    procedure Test_HexToBytes_UpperCase;
    procedure Test_HexToBytes_LowerCase;
    procedure Test_HexToBytes_MixedCase;
    procedure Test_HexToBytes_OddLength;
    procedure Test_HexToBytes_InvalidChar;

    // Try Hex variants
    procedure Test_TryBytesToHex_Success;
    procedure Test_TryHexToBytes_Success;
    procedure Test_TryHexToBytes_Failure;

    // Base64 encoding tests (requires OpenSSL)
    procedure Test_Base64Encode_EmptyArray;
    procedure Test_Base64Encode_SingleByte;
    procedure Test_Base64Encode_ShortData;
    procedure Test_Base64Encode_HelloWorld;
    procedure Test_Base64Encode_BinaryData;
    procedure Test_Base64Encode_String;

    // Base64 decoding tests
    procedure Test_Base64Decode_EmptyString;
    procedure Test_Base64Decode_HelloWorld;
    procedure Test_Base64Decode_Padding1;
    procedure Test_Base64Decode_Padding2;
    procedure Test_Base64Decode_NoPadding;

    // Base64 Try variants
    procedure Test_TryBase64Encode_Success;
    procedure Test_TryBase64Decode_Success;

    // Roundtrip tests
    procedure Test_HexRoundtrip;
    procedure Test_Base64Roundtrip;

    // String helper tests
    procedure Test_StringToHex;
    procedure Test_HexToString;
  end;

implementation

uses
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

{ TTestEncoding }

procedure TTestEncoding.SetUp;
begin
  inherited SetUp;
  // Check if OpenSSL is available for Base64 tests
  try
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      LoadOpenSSLCore();
    FOpenSSLAvailable := TOpenSSLLoader.IsModuleLoaded(osmCore);
  except
    FOpenSSLAvailable := False;
  end;
end;

{ Hex Encoding Tests }

procedure TTestEncoding.Test_BytesToHex_EmptyArray;
var
  Data: TBytes;
  Result: string;
begin
  SetLength(Data, 0);
  Result := TEncodingUtils.BytesToHex(Data);
  AssertEquals('Empty array should produce empty string', '', Result);
end;

procedure TTestEncoding.Test_BytesToHex_SingleByte;
var
  Data: TBytes;
begin
  SetLength(Data, 1);
  Data[0] := $FF;
  AssertEquals('Single byte FF', 'FF', TEncodingUtils.BytesToHex(Data));

  Data[0] := $00;
  AssertEquals('Single byte 00', '00', TEncodingUtils.BytesToHex(Data));

  Data[0] := $AB;
  AssertEquals('Single byte AB', 'AB', TEncodingUtils.BytesToHex(Data));
end;

procedure TTestEncoding.Test_BytesToHex_MultiByte;
var
  Data: TBytes;
begin
  SetLength(Data, 3);
  Data[0] := $01;
  Data[1] := $23;
  Data[2] := $45;
  AssertEquals('Multi-byte hex', '012345', TEncodingUtils.BytesToHex(Data));
end;

procedure TTestEncoding.Test_BytesToHex_UpperCase;
var
  Data: TBytes;
begin
  SetLength(Data, 2);
  Data[0] := $AB;
  Data[1] := $CD;
  AssertEquals('Upper case', 'ABCD', TEncodingUtils.BytesToHex(Data, True));
end;

procedure TTestEncoding.Test_BytesToHex_LowerCase;
var
  Data: TBytes;
begin
  SetLength(Data, 2);
  Data[0] := $AB;
  Data[1] := $CD;
  AssertEquals('Lower case', 'abcd', TEncodingUtils.BytesToHex(Data, False));
end;

procedure TTestEncoding.Test_BytesToHex_AllValues;
var
  Data: TBytes;
  I: Integer;
  Expected: string;
begin
  // Test all 256 byte values
  SetLength(Data, 256);
  Expected := '';
  for I := 0 to 255 do
  begin
    Data[I] := Byte(I);
    Expected := Expected + IntToHex(I, 2);
  end;
  AssertEquals('All byte values', Expected, TEncodingUtils.BytesToHex(Data));
end;

{ Hex Decoding Tests }

procedure TTestEncoding.Test_HexToBytes_EmptyString;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('');
  AssertEquals('Empty string should produce empty array', 0, Length(Result));
end;

procedure TTestEncoding.Test_HexToBytes_SingleByte;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('FF');
  AssertEquals('Single byte length', 1, Length(Result));
  AssertEquals('Single byte value', $FF, Result[0]);

  Result := TEncodingUtils.HexToBytes('00');
  AssertEquals('Zero byte value', $00, Result[0]);
end;

procedure TTestEncoding.Test_HexToBytes_MultiByte;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('0123456789ABCDEF');
  AssertEquals('Multi-byte length', 8, Length(Result));
  AssertEquals('Byte 0', $01, Result[0]);
  AssertEquals('Byte 1', $23, Result[1]);
  AssertEquals('Byte 2', $45, Result[2]);
  AssertEquals('Byte 3', $67, Result[3]);
  AssertEquals('Byte 4', $89, Result[4]);
  AssertEquals('Byte 5', $AB, Result[5]);
  AssertEquals('Byte 6', $CD, Result[6]);
  AssertEquals('Byte 7', $EF, Result[7]);
end;

procedure TTestEncoding.Test_HexToBytes_UpperCase;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('ABCD');
  AssertEquals('Upper case', $AB, Result[0]);
  AssertEquals('Upper case', $CD, Result[1]);
end;

procedure TTestEncoding.Test_HexToBytes_LowerCase;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('abcd');
  AssertEquals('Lower case', $AB, Result[0]);
  AssertEquals('Lower case', $CD, Result[1]);
end;

procedure TTestEncoding.Test_HexToBytes_MixedCase;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('AbCd');
  AssertEquals('Mixed case', $AB, Result[0]);
  AssertEquals('Mixed case', $CD, Result[1]);
end;

procedure TTestEncoding.Test_HexToBytes_OddLength;
var
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  try
    TEncodingUtils.HexToBytes('ABC'); // Odd length
  except
    on E: ESSLException do
      ExceptionRaised := True;
  end;
  AssertTrue('Odd length should raise exception', ExceptionRaised);
end;

procedure TTestEncoding.Test_HexToBytes_InvalidChar;
var
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  try
    TEncodingUtils.HexToBytes('GHIJ'); // Invalid hex chars
  except
    on E: ESSLException do
      ExceptionRaised := True;
  end;
  AssertTrue('Invalid chars should raise exception', ExceptionRaised);
end;

{ Try Hex Variants }

procedure TTestEncoding.Test_TryBytesToHex_Success;
var
  Data: TBytes;
  Result: string;
begin
  SetLength(Data, 2);
  Data[0] := $AB;
  Data[1] := $CD;
  AssertTrue('TryBytesToHex should succeed', TEncodingUtils.TryBytesToHex(Data, Result));
  AssertEquals('TryBytesToHex result', 'ABCD', Result);
end;

procedure TTestEncoding.Test_TryHexToBytes_Success;
var
  Result: TBytes;
begin
  AssertTrue('TryHexToBytes should succeed', TEncodingUtils.TryHexToBytes('ABCD', Result));
  AssertEquals('TryHexToBytes length', 2, Length(Result));
end;

procedure TTestEncoding.Test_TryHexToBytes_Failure;
var
  Result: TBytes;
begin
  AssertFalse('TryHexToBytes should fail for odd length', TEncodingUtils.TryHexToBytes('ABC', Result));
  AssertEquals('Result should be empty on failure', 0, Length(Result));
end;

{ Base64 Encoding Tests }

procedure TTestEncoding.Test_Base64Encode_EmptyArray;
var
  Data: TBytes;
  Result: string;
begin
  SetLength(Data, 0);
  Result := TEncodingUtils.Base64Encode(Data);
  AssertEquals('Empty array should produce empty string', '', Result);
end;

procedure TTestEncoding.Test_Base64Encode_SingleByte;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  SetLength(Data, 1);
  Data[0] := $00;
  Result := TEncodingUtils.Base64Encode(Data);
  AssertEquals('Single zero byte', 'AA==', Result);
end;

procedure TTestEncoding.Test_Base64Encode_ShortData;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  SetLength(Data, 2);
  Data[0] := $01;
  Data[1] := $02;
  Result := TEncodingUtils.Base64Encode(Data);
  AssertEquals('Two bytes', 'AQI=', Result);
end;

procedure TTestEncoding.Test_Base64Encode_HelloWorld;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  // "Hello World" in bytes
  Data := TEncoding.UTF8.GetBytes('Hello World');
  Result := TEncodingUtils.Base64Encode(Data);
  AssertEquals('Hello World', 'SGVsbG8gV29ybGQ=', Result);
end;

procedure TTestEncoding.Test_Base64Encode_BinaryData;
var
  Data: TBytes;
  I: Integer;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  // Binary data 0-255
  SetLength(Data, 256);
  for I := 0 to 255 do
    Data[I] := Byte(I);

  Result := TEncodingUtils.Base64Encode(Data);
  AssertTrue('Base64 result should not be empty', Length(Result) > 0);
  // Base64 output is ~4/3 of input, 256 bytes -> ~344 chars
  AssertTrue('Base64 result should be reasonable length', Length(Result) < 400);
end;

procedure TTestEncoding.Test_Base64Encode_String;
var
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  Result := TEncodingUtils.Base64Encode('Hello');
  AssertEquals('String input', 'SGVsbG8=', Result);
end;

{ Base64 Decoding Tests }

procedure TTestEncoding.Test_Base64Decode_EmptyString;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.Base64Decode('');
  AssertEquals('Empty string should produce empty array', 0, Length(Result));
end;

procedure TTestEncoding.Test_Base64Decode_HelloWorld;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  Result := TEncodingUtils.Base64Decode('SGVsbG8gV29ybGQ=');
  ResultStr := TEncoding.UTF8.GetString(Result);
  AssertEquals('Hello World', 'Hello World', ResultStr);
end;

procedure TTestEncoding.Test_Base64Decode_Padding1;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  // Single = padding (2 bytes input mod 3 = 2)
  Result := TEncodingUtils.Base64Decode('SGk=');
  ResultStr := TEncoding.UTF8.GetString(Result);
  AssertEquals('Padding 1', 'Hi', ResultStr);
end;

procedure TTestEncoding.Test_Base64Decode_Padding2;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  // Double == padding (1 byte input mod 3 = 1)
  Result := TEncodingUtils.Base64Decode('QQ==');
  ResultStr := TEncoding.UTF8.GetString(Result);
  AssertEquals('Padding 2', 'A', ResultStr);
end;

procedure TTestEncoding.Test_Base64Decode_NoPadding;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  // No padding (3 bytes input mod 3 = 0)
  Result := TEncodingUtils.Base64Decode('QWJj');
  ResultStr := TEncoding.UTF8.GetString(Result);
  AssertEquals('No padding', 'Abc', ResultStr);
end;

{ Base64 Try Variants }

procedure TTestEncoding.Test_TryBase64Encode_Success;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  Data := TEncoding.UTF8.GetBytes('Test');
  AssertTrue('TryBase64Encode should succeed', TEncodingUtils.TryBase64Encode(Data, Result));
  AssertEquals('TryBase64Encode result', 'VGVzdA==', Result);
end;

procedure TTestEncoding.Test_TryBase64Decode_Success;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  AssertTrue('TryBase64Decode should succeed', TEncodingUtils.TryBase64Decode('VGVzdA==', Result));
  ResultStr := TEncoding.UTF8.GetString(Result);
  AssertEquals('TryBase64Decode result', 'Test', ResultStr);
end;

{ Roundtrip Tests }

procedure TTestEncoding.Test_HexRoundtrip;
var
  OriginalData: TBytes;
  Hex: string;
  DecodedData: TBytes;
  I: Integer;
begin
  // Create test data
  SetLength(OriginalData, 100);
  for I := 0 to High(OriginalData) do
    OriginalData[I] := Byte(Random(256));

  // Roundtrip
  Hex := TEncodingUtils.BytesToHex(OriginalData);
  DecodedData := TEncodingUtils.HexToBytes(Hex);

  // Verify
  AssertEquals('Roundtrip length', Length(OriginalData), Length(DecodedData));
  for I := 0 to High(OriginalData) do
    AssertEquals('Roundtrip byte ' + IntToStr(I), OriginalData[I], DecodedData[I]);
end;

procedure TTestEncoding.Test_Base64Roundtrip;
var
  OriginalData: TBytes;
  B64: string;
  DecodedData: TBytes;
  I: Integer;
begin
  if not FOpenSSLAvailable then
  begin
    Ignore('OpenSSL not available');
    Exit;
  end;

  // Create test data
  SetLength(OriginalData, 100);
  for I := 0 to High(OriginalData) do
    OriginalData[I] := Byte(Random(256));

  // Roundtrip
  B64 := TEncodingUtils.Base64Encode(OriginalData);
  DecodedData := TEncodingUtils.Base64Decode(B64);

  // Verify
  AssertEquals('Roundtrip length', Length(OriginalData), Length(DecodedData));
  for I := 0 to High(OriginalData) do
    AssertEquals('Roundtrip byte ' + IntToStr(I), OriginalData[I], DecodedData[I]);
end;

{ String Helper Tests }

procedure TTestEncoding.Test_StringToHex;
var
  Result: string;
begin
  Result := TEncodingUtils.StringToHex('AB');
  // 'A' = $41, 'B' = $42
  AssertEquals('StringToHex', '4142', Result);
end;

procedure TTestEncoding.Test_HexToString;
var
  Result: string;
begin
  Result := TEncodingUtils.HexToString('4142');
  AssertEquals('HexToString', 'AB', Result);
end;

initialization
  Randomize;
  RegisterTest(TTestEncoding);

end.
