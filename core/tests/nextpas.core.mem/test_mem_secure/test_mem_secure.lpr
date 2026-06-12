program test_mem_secure;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.secure;

var
  T: TTestRunner;

procedure TestSecureZeroMemoryNilAndZeroSize;
var
  LByte: Byte;
begin
  SecureZeroMemory(nil, 16);

  LByte := $A5;
  SecureZeroMemory(@LByte, 0);
  CheckEqual(Int64($A5), Int64(LByte), 'zero-size secure zero leaves buffer unchanged');
end;

procedure TestSecureZeroMemorySmallBuffers;
var
  LOne: Byte;
  LThree: array[0..2] of Byte;
  LGuarded: array[0..4] of Byte;
  LIndex: Integer;
begin
  LOne := $7F;
  SecureZeroMemory(@LOne, SizeOf(LOne));
  CheckEqual(Int64(0), Int64(LOne), 'single-byte secure zero');

  LThree[0] := $11;
  LThree[1] := $22;
  LThree[2] := $33;
  SecureZeroMemory(@LThree[0], SizeOf(LThree));
  for LIndex := Low(LThree) to High(LThree) do
    CheckEqual(Int64(0), Int64(LThree[LIndex]), 'three-byte secure zero');

  LGuarded[0] := $AA;
  LGuarded[1] := $11;
  LGuarded[2] := $22;
  LGuarded[3] := $33;
  LGuarded[4] := $BB;
  SecureZeroMemory(@LGuarded[1], 3);
  CheckEqual(Int64($AA), Int64(LGuarded[0]), 'leading guard unchanged');
  CheckEqual(Int64(0), Int64(LGuarded[1]), 'guarded byte 1 cleared');
  CheckEqual(Int64(0), Int64(LGuarded[2]), 'guarded byte 2 cleared');
  CheckEqual(Int64(0), Int64(LGuarded[3]), 'guarded byte 3 cleared');
  CheckEqual(Int64($BB), Int64(LGuarded[4]), 'trailing guard unchanged');
end;

procedure TestSecureZeroBytesClearsAndShrinks;
var
  LData: TBytes;
begin
  SetLength(LData, 3);
  LData[0] := $41;
  LData[1] := $42;
  LData[2] := $43;

  SecureZeroBytes(LData);
  CheckEqual(Int64(0), Int64(Length(LData)), 'secure zero bytes shrinks array');
end;

procedure TestSecureZeroStringClears;
var
  LText: AnsiString;
begin
  LText := 'secret';
  SecureZeroString(LText);
  CheckEqual('', LText, 'secure zero string clears value');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.secure');
  T.Run('nil and zero-size memory', @TestSecureZeroMemoryNilAndZeroSize);
  T.Run('small buffers', @TestSecureZeroMemorySmallBuffers);
  T.Run('byte arrays', @TestSecureZeroBytesClearsAndShrinks);
  T.Run('strings', @TestSecureZeroStringClears);
  T.Summary;
end.
