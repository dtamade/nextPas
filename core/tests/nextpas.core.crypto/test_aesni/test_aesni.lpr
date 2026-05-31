program test_aesni;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin WriteLn('  [PASS] ', AName); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', AName); Inc(GFail); end;
end;

function BlockToHex(const B: TAESNIBlock): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to 15 do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

procedure TestAES128_FIPS197;
const
  // FIPS 197 Appendix B: AES-128
  KEY: TAESNIBlock = ($2b,$7e,$15,$16,$28,$ae,$d2,$a6,$ab,$f7,$15,$88,$09,$cf,$4f,$3c);
  PLAIN: TAESNIBlock = ($32,$43,$f6,$a8,$88,$5a,$30,$8d,$31,$31,$98,$a2,$e0,$37,$07,$34);
  CIPHER_HEX = '3925841d02dc09fbdc118597196a0b32';
var
  LExpKey: TAESNIExpandedKey128;
  LOut, LDec: TAESNIBlock;
begin
  WriteLn('--- AES-128 FIPS 197 ---');

  AESNIExpandKey128(KEY, LExpKey);
  AESNIEncryptBlock128(PLAIN, LOut, LExpKey);
  Check('AES-128 encrypt', BlockToHex(LOut) = CIPHER_HEX);

  AESNIDecryptBlock128(LOut, LDec, LExpKey);
  Check('AES-128 decrypt roundtrip', CompareMem(@LDec, @PLAIN, 16));
end;

procedure TestAES256_FIPS197;
const
  // FIPS 197 Appendix C.3: AES-256
  KEY256: array[0..31] of Byte = (
    $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,
    $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f);
  PLAIN256: TAESNIBlock = ($00,$11,$22,$33,$44,$55,$66,$77,$88,$99,$aa,$bb,$cc,$dd,$ee,$ff);
  CIPHER256_HEX = '8ea2b7ca516745bfeafc49904b496089';
var
  LExpKey: TAESNIExpandedKey256;
  LOut: TAESNIBlock;
begin
  WriteLn('--- AES-256 FIPS 197 ---');

  AESNIExpandKey256(KEY256, LExpKey);
  AESNIEncryptBlock256(PLAIN256, LOut, LExpKey);
  Check('AES-256 encrypt', BlockToHex(LOut) = CIPHER256_HEX);
end;

procedure TestCTR128;
const
  KEY: TAESNIBlock = ($2b,$7e,$15,$16,$28,$ae,$d2,$a6,$ab,$f7,$15,$88,$09,$cf,$4f,$3c);
  // NIST SP 800-38A F.5.1 CTR-AES128 first block
  IV: TAESNIBlock = ($f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$ff);
  PLAIN: TAESNIBlock = ($6b,$c1,$be,$e2,$2e,$40,$9f,$96,$e9,$3d,$7e,$11,$73,$93,$17,$2a);
  CIPHER_HEX = '874d6191b620e3261bef6864990db6ce';
var
  LExpKey: TAESNIExpandedKey128;
  LOut: array[0..15] of Byte;
  LIV: TAESNIBlock;
begin
  WriteLn('--- AES-128 CTR ---');

  AESNIExpandKey128(KEY, LExpKey);
  LIV := IV;
  AESNIEncryptCTR128(LExpKey, LIV, @PLAIN[0], 16, @LOut[0]);
  Check('CTR-128 first block', BlockToHex(TAESNIBlock(LOut)) = CIPHER_HEX);
end;

procedure TestCrossValidation;
var
  KEY: TAESNIBlock;
  PLAIN, LNI, LCT: TAESNIBlock;
  LExpKeyNI: TAESNIExpandedKey128;
  LExpKeyCT: TAESCt64Key;
  LKeyBytes: TBytes;
  I: Integer;
begin
  WriteLn('--- Cross-validation AES-NI vs CT64 ---');

  for I := 0 to 15 do begin KEY[I] := Byte(I * 17 + 3); PLAIN[I] := Byte(I * 31 + 7); end;

  AESNIExpandKey128(KEY, LExpKeyNI);
  AESNIEncryptBlock128(PLAIN, LNI, LExpKeyNI);

  SetLength(LKeyBytes, 16);
  Move(KEY[0], LKeyBytes[0], 16);
  AESCt64KeyExpand(LKeyBytes, LExpKeyCT);
  AESCt64EncryptBlock(@PLAIN[0], @LCT[0], LExpKeyCT);

  Check('AES-NI == CT64 (same key, same plaintext)', CompareMem(@LNI, @LCT, 16));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== AES-NI Tests ===');
  WriteLn;

  if not IsAESNIAvailable then
  begin
    WriteLn('SKIP: AES-NI not available on this CPU');
    Halt(0);
  end;

  TestAES128_FIPS197;
  TestAES256_FIPS197;
  TestCTR128;
  TestCrossValidation;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
