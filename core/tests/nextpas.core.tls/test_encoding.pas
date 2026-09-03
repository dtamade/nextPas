{
  test_encoding.pas - Unit tests for nextpas.core.tls.encoding

  Tests encoding utilities:
  - Hex encoding/decoding (BytesToHex, HexToBytes)
  - Base64 encoding/decoding (OpenSSL BIO based)
  - Try* variants for error handling
  - String helper functions
}

unit test_encoding;

{$mode objfpc}{$H+}{$M+}
{$UNITPATH framework}

interface

uses
  nextpas.core.test,
  test_base, nextpas.core.tls.encoding, nextpas.core.tls.exceptions, nextpas.core.tls.base, nextpas.core.base, nextpas.core.text.conv;

type
  { TTestEncoding - Tests for encoding utilities }
  TTestEncoding = class(TTestBase)
  private
    FOpenSSLAvailable: Boolean;
  protected
    procedure BeforeEach; override;
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

procedure TTestEncoding.BeforeEach;
begin
  inherited BeforeEach;
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
  CheckEqual('', Result, 'Empty array should produce empty string');
end;

procedure TTestEncoding.Test_BytesToHex_SingleByte;
var
  Data: TBytes;
begin
  SetLength(Data, 1);
  Data[0] := $FF;
  CheckEqual('FF', TEncodingUtils.BytesToHex(Data), 'Single byte FF');

  Data[0] := $00;
  CheckEqual('00', TEncodingUtils.BytesToHex(Data), 'Single byte 00');

  Data[0] := $AB;
  CheckEqual('AB', TEncodingUtils.BytesToHex(Data), 'Single byte AB');
end;

procedure TTestEncoding.Test_BytesToHex_MultiByte;
var
  Data: TBytes;
begin
  SetLength(Data, 3);
  Data[0] := $01;
  Data[1] := $23;
  Data[2] := $45;
  CheckEqual('012345', TEncodingUtils.BytesToHex(Data), 'Multi-byte hex');
end;

procedure TTestEncoding.Test_BytesToHex_UpperCase;
var
  Data: TBytes;
begin
  SetLength(Data, 2);
  Data[0] := $AB;
  Data[1] := $CD;
  CheckEqual('ABCD', TEncodingUtils.BytesToHex(Data, True), 'Upper case');
end;

procedure TTestEncoding.Test_BytesToHex_LowerCase;
var
  Data: TBytes;
begin
  SetLength(Data, 2);
  Data[0] := $AB;
  Data[1] := $CD;
  CheckEqual('abcd', TEncodingUtils.BytesToHex(Data, False), 'Lower case');
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
  CheckEqual(Expected, TEncodingUtils.BytesToHex(Data), 'All byte values');
end;

{ Hex Decoding Tests }

procedure TTestEncoding.Test_HexToBytes_EmptyString;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('');
  CheckEqual(0, Length(Result), 'Empty string should produce empty array');
end;

procedure TTestEncoding.Test_HexToBytes_SingleByte;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('FF');
  CheckEqual(1, Length(Result), 'Single byte length');
  CheckEqual($FF, Result[0], 'Single byte value');

  Result := TEncodingUtils.HexToBytes('00');
  CheckEqual($00, Result[0], 'Zero byte value');
end;

procedure TTestEncoding.Test_HexToBytes_MultiByte;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('0123456789ABCDEF');
  CheckEqual(8, Length(Result), 'Multi-byte length');
  CheckEqual($01, Result[0], 'Byte 0');
  CheckEqual($23, Result[1], 'Byte 1');
  CheckEqual($45, Result[2], 'Byte 2');
  CheckEqual($67, Result[3], 'Byte 3');
  CheckEqual($89, Result[4], 'Byte 4');
  CheckEqual($AB, Result[5], 'Byte 5');
  CheckEqual($CD, Result[6], 'Byte 6');
  CheckEqual($EF, Result[7], 'Byte 7');
end;

procedure TTestEncoding.Test_HexToBytes_UpperCase;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('ABCD');
  CheckEqual($AB, Result[0], 'Upper case');
  CheckEqual($CD, Result[1], 'Upper case');
end;

procedure TTestEncoding.Test_HexToBytes_LowerCase;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('abcd');
  CheckEqual($AB, Result[0], 'Lower case');
  CheckEqual($CD, Result[1], 'Lower case');
end;

procedure TTestEncoding.Test_HexToBytes_MixedCase;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.HexToBytes('AbCd');
  CheckEqual($AB, Result[0], 'Mixed case');
  CheckEqual($CD, Result[1], 'Mixed case');
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
  CheckTrue(ExceptionRaised, 'Odd length should raise exception');
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
  CheckTrue(ExceptionRaised, 'Invalid chars should raise exception');
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
  CheckTrue(TEncodingUtils.TryBytesToHex(Data, Result), 'TryBytesToHex should succeed');
  CheckEqual('ABCD', Result, 'TryBytesToHex result');
end;

procedure TTestEncoding.Test_TryHexToBytes_Success;
var
  Result: TBytes;
begin
  CheckTrue(TEncodingUtils.TryHexToBytes('ABCD', Result), 'TryHexToBytes should succeed');
  CheckEqual(2, Length(Result), 'TryHexToBytes length');
end;

procedure TTestEncoding.Test_TryHexToBytes_Failure;
var
  Result: TBytes;
begin
  CheckFalse(TEncodingUtils.TryHexToBytes('ABC', Result), 'TryHexToBytes should fail for odd length');
  CheckEqual(0, Length(Result), 'Result should be empty on failure');
end;

{ Base64 Encoding Tests }

procedure TTestEncoding.Test_Base64Encode_EmptyArray;
var
  Data: TBytes;
  Result: string;
begin
  SetLength(Data, 0);
  Result := TEncodingUtils.Base64Encode(Data);
  CheckEqual('', Result, 'Empty array should produce empty string');
end;

procedure TTestEncoding.Test_Base64Encode_SingleByte;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  SetLength(Data, 1);
  Data[0] := $00;
  Result := TEncodingUtils.Base64Encode(Data);
  CheckEqual('AA==', Result, 'Single zero byte');
end;

procedure TTestEncoding.Test_Base64Encode_ShortData;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  SetLength(Data, 2);
  Data[0] := $01;
  Data[1] := $02;
  Result := TEncodingUtils.Base64Encode(Data);
  CheckEqual('AQI=', Result, 'Two bytes');
end;

procedure TTestEncoding.Test_Base64Encode_HelloWorld;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  // "Hello World" in bytes
  Data := StringToUTF8Bytes('Hello World');
  Result := TEncodingUtils.Base64Encode(Data);
  CheckEqual('SGVsbG8gV29ybGQ=', Result, 'Hello World');
end;

procedure TTestEncoding.Test_Base64Encode_BinaryData;
var
  Data: TBytes;
  I: Integer;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  // Binary data 0-255
  SetLength(Data, 256);
  for I := 0 to 255 do
    Data[I] := Byte(I);

  Result := TEncodingUtils.Base64Encode(Data);
  CheckTrue(Length(Result) > 0, 'Base64 result should not be empty');
  // Base64 output is ~4/3 of input, 256 bytes -> ~344 chars
  CheckTrue(Length(Result) < 400, 'Base64 result should be reasonable length');
end;

procedure TTestEncoding.Test_Base64Encode_String;
var
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Result := TEncodingUtils.Base64Encode('Hello');
  CheckEqual('SGVsbG8=', Result, 'String input');
end;

{ Base64 Decoding Tests }

procedure TTestEncoding.Test_Base64Decode_EmptyString;
var
  Result: TBytes;
begin
  Result := TEncodingUtils.Base64Decode('');
  CheckEqual(0, Length(Result), 'Empty string should produce empty array');
end;

procedure TTestEncoding.Test_Base64Decode_HelloWorld;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Result := TEncodingUtils.Base64Decode('SGVsbG8gV29ybGQ=');
  ResultStr := UTF8BytesToString(Result);
  CheckEqual('Hello World', ResultStr, 'Hello World');
end;

procedure TTestEncoding.Test_Base64Decode_Padding1;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  // Single = padding (2 bytes input mod 3 = 2)
  Result := TEncodingUtils.Base64Decode('SGk=');
  ResultStr := UTF8BytesToString(Result);
  CheckEqual('Hi', ResultStr, 'Padding 1');
end;

procedure TTestEncoding.Test_Base64Decode_Padding2;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  // Double == padding (1 byte input mod 3 = 1)
  Result := TEncodingUtils.Base64Decode('QQ==');
  ResultStr := UTF8BytesToString(Result);
  CheckEqual('A', ResultStr, 'Padding 2');
end;

procedure TTestEncoding.Test_Base64Decode_NoPadding;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  // No padding (3 bytes input mod 3 = 0)
  Result := TEncodingUtils.Base64Decode('QWJj');
  ResultStr := UTF8BytesToString(Result);
  CheckEqual('Abc', ResultStr, 'No padding');
end;

{ Base64 Try Variants }

procedure TTestEncoding.Test_TryBase64Encode_Success;
var
  Data: TBytes;
  Result: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Data := StringToUTF8Bytes('Test');
  CheckTrue(TEncodingUtils.TryBase64Encode(Data, Result), 'TryBase64Encode should succeed');
  CheckEqual('VGVzdA==', Result, 'TryBase64Encode result');
end;

procedure TTestEncoding.Test_TryBase64Decode_Success;
var
  Result: TBytes;
  ResultStr: string;
begin
  if not FOpenSSLAvailable then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  CheckTrue(TEncodingUtils.TryBase64Decode('VGVzdA==', Result), 'TryBase64Decode should succeed');
  ResultStr := UTF8BytesToString(Result);
  CheckEqual('Test', ResultStr, 'TryBase64Decode result');
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
  CheckEqual(Length(OriginalData), Length(DecodedData), 'Roundtrip length');
  for I := 0 to High(OriginalData) do
    CheckEqual(OriginalData[I], DecodedData[I], 'Roundtrip byte ' + IntToStr(I));
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
    Skip('OpenSSL not available');
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
  CheckEqual(Length(OriginalData), Length(DecodedData), 'Roundtrip length');
  for I := 0 to High(OriginalData) do
    CheckEqual(OriginalData[I], DecodedData[I], 'Roundtrip byte ' + IntToStr(I));
end;

{ String Helper Tests }

procedure TTestEncoding.Test_StringToHex;
var
  Result: string;
begin
  Result := TEncodingUtils.StringToHex('AB');
  // 'A' = $41, 'B' = $42
  CheckEqual('4142', Result, 'StringToHex');
end;

procedure TTestEncoding.Test_HexToString;
var
  Result: string;
begin
  Result := TEncodingUtils.HexToString('4142');
  CheckEqual('AB', Result, 'HexToString');
end;

end.
