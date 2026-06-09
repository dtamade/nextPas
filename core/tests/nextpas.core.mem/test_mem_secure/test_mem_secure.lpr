program test_mem_secure;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.mem.secure;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure TestSecureZeroMemoryZerosBuffer;
var
  LBuffer: array[0..31] of Byte;
  I: Integer;
begin
  for I := 0 to High(LBuffer) do
    LBuffer[I] := Byte(I + 1);

  SecureZeroMemory(@LBuffer[0], SizeOf(LBuffer));

  for I := 0 to High(LBuffer) do
    Check(LBuffer[I] = 0, 'SecureZeroMemory should zero every byte');
end;

procedure TestSecureZeroMemoryIgnoresNilAndZeroSize;
var
  LByte: Byte;
begin
  SecureZeroMemory(nil, SizeOf(LByte));

  LByte := $A5;
  SecureZeroMemory(@LByte, 0);
  Check(LByte = $A5, 'SecureZeroMemory should not touch zero-size buffers');
end;

procedure TestSecureZeroBytesClearsAndReleasesArray;
var
  LData: TBytes;
  I: Integer;
begin
  SetLength(LData, 16);
  for I := 0 to High(LData) do
    LData[I] := $5A;

  SecureZeroBytes(LData);

  Check(Length(LData) = 0, 'SecureZeroBytes should release the byte array');
end;

procedure TestSecureZeroStringClearsString;
var
  LText: AnsiString;
begin
  LText := 'sensitive-value';

  SecureZeroString(LText);

  Check(LText = '', 'SecureZeroString should clear the string');
end;

begin
  TestSecureZeroMemoryZerosBuffer;
  TestSecureZeroMemoryIgnoresNilAndZeroSize;
  TestSecureZeroBytesClearsAndReleasesArray;
  TestSecureZeroStringClearsString;
  WriteLn('PASS: mem.secure tests passed');
end.
