program test_aes_ct64;
{$mode ObjFPC}{$H+}
uses SysUtils, nextpas.core.crypto.aes.ct64, nextpas.core.crypto.aesgcm;

var GPass: Integer = 0; GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end else begin WriteLn('  [FAIL] ', N); Inc(GFail); end; end;

function HexToBytes(const H: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(H) div 2); for I := 0 to Length(Result)-1 do Result[I] := StrToInt('$'+Copy(H,I*2+1,2)); end;

function BytesToHex(const D: TBytes): string;
var I: Integer;
begin Result := ''; for I := 0 to Length(D)-1 do Result := Result + LowerCase(IntToHex(D[I],2)); end;

procedure TestSBox;
begin
  WriteLn('--- S-box known values ---');
  Check(CTSBox($00) = $63, 'SBox(00)=63');
  Check(CTSBox($01) = $7C, 'SBox(01)=7C');
  Check(CTSBox($FF) = $16, 'SBox(FF)=16');
  Check(CTSBox($53) = $ED, 'SBox(53)=ED');
  Check(CTSBox($11) = $82, 'SBox(11)=82');
end;

procedure TestFIPS197_AES128;
var
  LKey, LPlain, LExpected: TBytes;
  LExpKey: TAESCt64Key;
  LOut: array[0..15] of Byte;
  LOutBytes: TBytes;
  I: Integer;
begin
  WriteLn('--- FIPS 197 AES-128 test vector ---');
  LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  LPlain := HexToBytes('3243f6a8885a308d313198a2e0370734');
  LExpected := HexToBytes('3925841d02dc09fbdc118597196a0b32');

  AESCt64KeyExpand(LKey, LExpKey);
  AESCt64EncryptBlock(@LPlain[0], @LOut[0], LExpKey);

  SetLength(LOutBytes, 16);
  Move(LOut[0], LOutBytes[0], 16);
  Check(BytesToHex(LOutBytes) = BytesToHex(LExpected), 'AES-128 encrypt matches FIPS 197');
end;

procedure TestFIPS197_AES256;
var
  LKey, LPlain, LExpected: TBytes;
  LExpKey: TAESCt64Key;
  LOut: array[0..15] of Byte;
  LOutBytes: TBytes;
begin
  WriteLn('--- FIPS 197 AES-256 test vector ---');
  LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  LPlain := HexToBytes('6bc1bee22e409f96e93d7e117393172a');
  LExpected := HexToBytes('f3eed1bdb5d2a03c064b5a7e3db181f8');

  AESCt64KeyExpand(LKey, LExpKey);
  AESCt64EncryptBlock(@LPlain[0], @LOut[0], LExpKey);

  SetLength(LOutBytes, 16);
  Move(LOut[0], LOutBytes[0], 16);
  Check(BytesToHex(LOutBytes) = BytesToHex(LExpected), 'AES-256 encrypt matches NIST SP800-38A');
end;

procedure TestCrossValidateWithTableAES;
var
  LKey, LPlain: TBytes;
  LExpKeyTable: TAESExpandedKey;
  LExpKeyCT: TAESCt64Key;
  LNr: Integer;
  LOutTable, LOutCT: array[0..15] of Byte;
  I: Integer;
  LMatch: Boolean;
begin
  WriteLn('--- Cross-validate CT vs table-based ---');
  SetLength(LKey, 16);
  for I := 0 to 15 do LKey[I] := Byte(I * 17 + 5);
  SetLength(LPlain, 16);
  for I := 0 to 15 do LPlain[I] := Byte(I * 31 + 3);

  AESKeyExpand(LKey, LExpKeyTable, LNr);
  AESEncryptBlock(TAESBlock(Pointer(@LPlain[0])^), TAESBlock(Pointer(@LOutTable[0])^), LExpKeyTable, LNr);

  AESCt64KeyExpand(LKey, LExpKeyCT);
  AESCt64EncryptBlock(@LPlain[0], @LOutCT[0], LExpKeyCT);

  LMatch := True;
  for I := 0 to 15 do
    if LOutTable[I] <> LOutCT[I] then LMatch := False;
  Check(LMatch, 'CT output matches table-based output');
end;

procedure TestMultipleBlocks;
var
  LKey: TBytes;
  LExpKey: TAESCt64Key;
  LIn, LOut1, LOut2: array[0..15] of Byte;
  I, J: Integer;
  LAllMatch: Boolean;
begin
  WriteLn('--- Multiple blocks consistency ---');
  SetLength(LKey, 16);
  for I := 0 to 15 do LKey[I] := Byte(I);
  AESCt64KeyExpand(LKey, LExpKey);

  LAllMatch := True;
  for J := 0 to 9 do
  begin
    for I := 0 to 15 do LIn[I] := Byte(J * 16 + I);
    AESCt64EncryptBlock(@LIn[0], @LOut1[0], LExpKey);
    AESCt64EncryptBlock(@LIn[0], @LOut2[0], LExpKey);
    for I := 0 to 15 do
      if LOut1[I] <> LOut2[I] then LAllMatch := False;
  end;
  Check(LAllMatch, 'deterministic: same input gives same output');
end;

begin
  WriteLn('=== AES CT64 (Constant-Time) Tests ===');
  WriteLn;
  TestSBox;
  TestFIPS197_AES128;
  TestFIPS197_AES256;
  TestCrossValidateWithTableAES;
  TestMultipleBlocks;
  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
