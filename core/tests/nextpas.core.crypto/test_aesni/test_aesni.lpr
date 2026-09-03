program test_aesni;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.test;

function BlockToHex(const B: TAESNIBlock): string;
var I: Integer;
begin Result := '';
  for I := 0 to 15 do Result := Result + LowerCase(IntToHex(B[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  if not IsAESNIAvailable then begin
    WriteLn('SKIP: AES-NI not available on this CPU');
    Halt(0);
  end;

  LSuite := TTestSuite.Create('aesni');

  LSuite.Test('AES-128 FIPS 197', procedure
  const
    KEY: TAESNIBlock = ($2b,$7e,$15,$16,$28,$ae,$d2,$a6,$ab,$f7,$15,$88,$09,$cf,$4f,$3c);
    PLAIN: TAESNIBlock = ($32,$43,$f6,$a8,$88,$5a,$30,$8d,$31,$31,$98,$a2,$e0,$37,$07,$34);
  var LExpKey: TAESNIExpandedKey128; LOut, LDec: TAESNIBlock;
  begin
    AESNIExpandKey128(KEY, LExpKey);
    AESNIEncryptBlock128(PLAIN, LOut, LExpKey);
    CheckEqual('3925841d02dc09fbdc118597196a0b32', BlockToHex(LOut));
    AESNIDecryptBlock128(LOut, LDec, LExpKey);
    CheckTrue(CompareMem(@LDec, @PLAIN, 16));
  end);

  LSuite.Test('AES-256 FIPS 197', procedure
  const
    KEY256: array[0..31] of Byte = (
      $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f,
      $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f);
    PLAIN256: TAESNIBlock = ($00,$11,$22,$33,$44,$55,$66,$77,$88,$99,$aa,$bb,$cc,$dd,$ee,$ff);
  var LExpKey: TAESNIExpandedKey256; LOut: TAESNIBlock;
  begin
    AESNIExpandKey256(KEY256, LExpKey);
    AESNIEncryptBlock256(PLAIN256, LOut, LExpKey);
    CheckEqual('8ea2b7ca516745bfeafc49904b496089', BlockToHex(LOut));
  end);

  LSuite.Test('CTR-128', procedure
  const
    KEY: TAESNIBlock = ($2b,$7e,$15,$16,$28,$ae,$d2,$a6,$ab,$f7,$15,$88,$09,$cf,$4f,$3c);
    IV: TAESNIBlock = ($f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$ff);
    PLAIN: TAESNIBlock = ($6b,$c1,$be,$e2,$2e,$40,$9f,$96,$e9,$3d,$7e,$11,$73,$93,$17,$2a);
  var LExpKey: TAESNIExpandedKey128; LOut: array[0..15] of Byte; LIV: TAESNIBlock;
  begin
    AESNIExpandKey128(KEY, LExpKey); LIV := IV;
    AESNIEncryptCTR128(LExpKey, LIV, @PLAIN[0], 16, @LOut[0]);
    CheckEqual('874d6191b620e3261bef6864990db6ce', BlockToHex(TAESNIBlock(LOut)));
  end);

  LSuite.Test('AES-NI vs CT64 cross-validate', procedure
  var KEY, PLAIN, LNI, LCT: TAESNIBlock;
    LExpKeyNI: TAESNIExpandedKey128; LExpKeyCT: TAESCt64Key; LKeyBytes: TBytes; I: Integer;
  begin
    for I := 0 to 15 do begin KEY[I] := Byte(I*17+3); PLAIN[I] := Byte(I*31+7); end;
    AESNIExpandKey128(KEY, LExpKeyNI);
    AESNIEncryptBlock128(PLAIN, LNI, LExpKeyNI);
    SetLength(LKeyBytes, 16); Move(KEY[0], LKeyBytes[0], 16);
    AESCt64KeyExpand(LKeyBytes, LExpKeyCT);
    AESCt64EncryptBlock(@PLAIN[0], @LCT[0], LExpKeyCT);
    CheckTrue(CompareMem(@LNI, @LCT, 16));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.aesni');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
