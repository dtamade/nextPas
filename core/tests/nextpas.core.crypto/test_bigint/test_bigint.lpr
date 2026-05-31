program test_bigint;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.bigint;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestModExp_Small;
var
  LBase, LExp, LMod, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 3^7 mod 13 = 2187 mod 13 = 3
  LBase := HexToBytes('03');
  LExp := HexToBytes('07');
  LMod := HexToBytes('0d');
  LOk := TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult, LError);
  Check('ModExp small: 3^7 mod 13 ok', LOk);
  if LOk then
    Check('ModExp small: 3^7 mod 13 = 3', BytesToHex(LResult) = '03');
end;

procedure TestModExp_Medium;
var
  LBase, LExp, LMod, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 2^16 mod 257 = 65536 mod 257 = 1 (Fermat prime)
  LBase := HexToBytes('02');
  LExp := HexToBytes('10');
  LMod := HexToBytes('0101');
  LOk := TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult, LError);
  Check('ModExp medium: 2^16 mod 257 ok', LOk);
  if LOk then
    Check('ModExp medium: 2^16 mod 257 = 1', BytesToHex(LResult) = '01');
end;

procedure TestModExp_RSASize;
var
  LBase, LExp, LMod, LResult, LResult2: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // Use a 128-bit modulus for a quick RSA-like test
  // n = 0xFFFFFFFFFFFFFFFFC90FDAA22168C235 (first 128 bits of a well-known prime)
  // base = 0x02, exp = 0x10001 (65537)
  LBase := HexToBytes('02');
  LExp := HexToBytes('010001');
  LMod := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFF0001');
  LOk := TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult, LError);
  Check('ModExp RSA-like: 2^65537 mod large ok', LOk);
  Check('ModExp RSA-like: result is non-zero', (Length(LResult) > 0) and (LResult[High(LResult)] <> 0));

  // Verify determinism
  TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult2, LError);
  Check('ModExp RSA-like: deterministic', BytesToHex(LResult) = BytesToHex(LResult2));
end;

procedure TestModMul;
var
  LLeft, LRight, LMod, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 7 * 8 mod 13 = 56 mod 13 = 4
  LLeft := HexToBytes('07');
  LRight := HexToBytes('08');
  LMod := HexToBytes('0d');
  LOk := TryBigIntModMulFromUnsignedBytes(LLeft, LRight, LMod, LResult, LError);
  Check('ModMul: 7*8 mod 13 ok', LOk);
  if LOk then
    Check('ModMul: 7*8 mod 13 = 4', BytesToHex(LResult) = '04');
end;

procedure TestModSub;
var
  LLeft, LRight, LMod, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 3 - 7 mod 13 = -4 mod 13 = 9
  LLeft := HexToBytes('03');
  LRight := HexToBytes('07');
  LMod := HexToBytes('0d');
  LOk := TryBigIntSubtractModuloFromUnsignedBytes(LLeft, LRight, LMod, LResult, LError);
  Check('ModSub: 3-7 mod 13 ok', LOk);
  if LOk then
    Check('ModSub: 3-7 mod 13 = 9', BytesToHex(LResult) = '09');
end;

procedure TestAdd;
var
  LLeft, LRight, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 0xFF + 0x01 = 0x0100
  LLeft := HexToBytes('ff');
  LRight := HexToBytes('01');
  LOk := TryBigIntAddFromUnsignedBytes(LLeft, LRight, LResult, LError);
  Check('Add: 0xFF + 0x01 ok', LOk);
  if LOk then
    Check('Add: 0xFF + 0x01 = 0x0100', BytesToHex(LResult) = '0100');
end;

procedure TestMul;
var
  LLeft, LRight, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 0xFF * 0xFF = 0xFE01
  LLeft := HexToBytes('ff');
  LRight := HexToBytes('ff');
  LOk := TryBigIntMulFromUnsignedBytes(LLeft, LRight, LResult, LError);
  Check('Mul: 0xFF * 0xFF ok', LOk);
  if LOk then
    Check('Mul: 0xFF * 0xFF = 0xFE01', BytesToHex(LResult) = 'fe01');
end;

procedure TestModReduction;
var
  LValue, LMod, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  // 256 mod 13 = 9
  LValue := HexToBytes('0100');
  LMod := HexToBytes('0d');
  LOk := TryBigIntModFromUnsignedBytes(LValue, LMod, LResult, LError);
  Check('Mod: 256 mod 13 ok', LOk);
  if LOk then
    Check('Mod: 256 mod 13 = 9', BytesToHex(LResult) = '09');
end;

procedure TestFixedLength;
var
  LValue, LResult: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LValue := HexToBytes('0102');
  LOk := TryBigIntToFixedLengthFromUnsignedBytes(LValue, 4, LResult, LError);
  Check('FixedLength: 2 bytes → 4 bytes ok', LOk);
  if LOk then
    Check('FixedLength: padded with leading zeros', BytesToHex(LResult) = '00000102');
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== BigInt Crypto Tests ===');
  WriteLn;
  TestModExp_Small;
  TestModExp_Medium;
  TestModExp_RSASize;
  TestModMul;
  TestModSub;
  TestAdd;
  TestMul;
  TestModReduction;
  TestFixedLength;
  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
