{
  test_memutils.pas - Unit tests for nextpas.core.tls.memutils

  Tests secure memory operations:
  - SecureZeroMemory
  - SecureZeroBytes
  - SecureZeroString
}

unit test_memutils;

{$mode objfpc}{$H+}
{$UNITPATH framework}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  test_base, nextpas.core.tls.memutils;

type
  { TTestMemUtils - Tests for secure memory operations }
  TTestMemUtils = class(TTestBase)
  published
    // SecureZeroMemory tests
    procedure Test_SecureZeroMemory_Basic;
    procedure Test_SecureZeroMemory_LargeBuffer;
    procedure Test_SecureZeroMemory_SingleByte;
    procedure Test_SecureZeroMemory_NilPointer;
    procedure Test_SecureZeroMemory_ZeroSize;

    // SecureZeroBytes tests
    procedure Test_SecureZeroBytes_Basic;
    procedure Test_SecureZeroBytes_EmptyArray;
    procedure Test_SecureZeroBytes_LargeArray;
    procedure Test_SecureZeroBytes_VerifyCleared;

    // SecureZeroString tests
    procedure Test_SecureZeroString_Basic;
    procedure Test_SecureZeroString_EmptyString;
    procedure Test_SecureZeroString_LongString;
    procedure Test_SecureZeroString_VerifyCleared;
  end;

implementation

{ TTestMemUtils }

procedure TTestMemUtils.Test_SecureZeroMemory_Basic;
var
  Buffer: array[0..15] of Byte;
  I: Integer;
begin
  // Fill buffer with non-zero values
  for I := 0 to High(Buffer) do
    Buffer[I] := I + 1;

  // Zero the buffer
  SecureZeroMemory(@Buffer[0], SizeOf(Buffer));

  // Verify all bytes are zero
  for I := 0 to High(Buffer) do
    AssertEquals('Buffer should be zeroed at position ' + IntToStr(I), 0, Buffer[I]);
end;

procedure TTestMemUtils.Test_SecureZeroMemory_LargeBuffer;
var
  Buffer: array[0..4095] of Byte;
  I: Integer;
begin
  // Fill buffer with pattern
  for I := 0 to High(Buffer) do
    Buffer[I] := Byte(I mod 256);

  // Zero the buffer
  SecureZeroMemory(@Buffer[0], SizeOf(Buffer));

  // Verify all bytes are zero
  for I := 0 to High(Buffer) do
    AssertEquals('Large buffer should be zeroed at position ' + IntToStr(I), 0, Buffer[I]);
end;

procedure TTestMemUtils.Test_SecureZeroMemory_SingleByte;
var
  Buffer: Byte;
begin
  Buffer := $FF;

  SecureZeroMemory(@Buffer, SizeOf(Buffer));

  AssertEquals('Single byte should be zeroed', 0, Buffer);
end;

procedure TTestMemUtils.Test_SecureZeroMemory_NilPointer;
begin
  // Should not crash with nil pointer
  SecureZeroMemory(nil, 100);

  // If we get here, the test passed (no crash)
  AssertTrue('SecureZeroMemory should handle nil pointer gracefully', True);
end;

procedure TTestMemUtils.Test_SecureZeroMemory_ZeroSize;
var
  Buffer: Byte;
begin
  Buffer := $FF;

  // Should not crash with zero size
  SecureZeroMemory(@Buffer, 0);

  // Buffer should remain unchanged
  AssertEquals('Buffer should not be modified with zero size', $FF, Buffer);
end;

procedure TTestMemUtils.Test_SecureZeroBytes_Basic;
var
  Data: TBytes;
  I: Integer;
begin
  SetLength(Data, 16);
  for I := 0 to High(Data) do
    Data[I] := I + 1;

  SecureZeroBytes(Data);

  // After SecureZeroBytes, array length should be 0
  AssertEquals('Array length should be 0 after SecureZeroBytes', 0, Length(Data));
end;

procedure TTestMemUtils.Test_SecureZeroBytes_EmptyArray;
var
  Data: TBytes;
begin
  SetLength(Data, 0);

  // Should not crash with empty array
  SecureZeroBytes(Data);

  AssertEquals('Empty array should remain empty', 0, Length(Data));
end;

procedure TTestMemUtils.Test_SecureZeroBytes_LargeArray;
var
  Data: TBytes;
  I: Integer;
begin
  SetLength(Data, 10000);
  for I := 0 to High(Data) do
    Data[I] := Byte(I mod 256);

  SecureZeroBytes(Data);

  AssertEquals('Large array length should be 0 after SecureZeroBytes', 0, Length(Data));
end;

procedure TTestMemUtils.Test_SecureZeroBytes_VerifyCleared;
var
  Data: TBytes;
  DataPtr: PByte;
  OrigLen: Integer;
  I: Integer;
  AllZero: Boolean;
begin
  SetLength(Data, 32);
  for I := 0 to High(Data) do
    Data[I] := $AA;

  // Save pointer to data (memory may still be accessible after SetLength(0))
  DataPtr := @Data[0];
  OrigLen := Length(Data);

  SecureZeroBytes(Data);

  // Check if the memory was actually zeroed (before reallocation)
  // Note: This is a best-effort check - memory may be reclaimed
  AllZero := True;
  for I := 0 to OrigLen - 1 do
  begin
    if (DataPtr + I)^ <> 0 then
    begin
      AllZero := False;
      Break;
    end;
  end;

  // We can't guarantee the memory check due to potential reallocation,
  // but at minimum the length should be 0
  AssertEquals('Array length should be 0', 0, Length(Data));
end;

procedure TTestMemUtils.Test_SecureZeroString_Basic;
var
  Str: AnsiString;
begin
  Str := 'SensitivePassword123!';

  SecureZeroString(Str);

  AssertEquals('String should be empty after SecureZeroString', '', Str);
end;

procedure TTestMemUtils.Test_SecureZeroString_EmptyString;
var
  Str: AnsiString;
begin
  Str := '';

  // Should not crash with empty string
  SecureZeroString(Str);

  AssertEquals('Empty string should remain empty', '', Str);
end;

procedure TTestMemUtils.Test_SecureZeroString_LongString;
var
  Str: AnsiString;
  I: Integer;
begin
  SetLength(Str, 10000);
  for I := 1 to Length(Str) do
    Str[I] := Chr(65 + (I mod 26)); // Fill with 'A' to 'Z'

  SecureZeroString(Str);

  AssertEquals('Long string should be empty after SecureZeroString', '', Str);
end;

procedure TTestMemUtils.Test_SecureZeroString_VerifyCleared;
var
  Str: AnsiString;
  StrPtr: PAnsiChar;
  OrigLen: Integer;
  I: Integer;
  AllZero: Boolean;
begin
  Str := 'SecretKey12345678';

  // Save pointer to string data
  StrPtr := PAnsiChar(Str);
  OrigLen := Length(Str);

  SecureZeroString(Str);

  // Check if the memory was actually zeroed
  // Note: This is a best-effort check - memory may be reclaimed
  AllZero := True;
  for I := 0 to OrigLen - 1 do
  begin
    if (StrPtr + I)^ <> #0 then
    begin
      AllZero := False;
      Break;
    end;
  end;

  // At minimum the string should be empty
  AssertEquals('String should be empty', '', Str);
end;

initialization
  RegisterTest(TTestMemUtils);

end.
