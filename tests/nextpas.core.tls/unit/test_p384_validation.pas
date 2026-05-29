program test_p384_validation;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.p384;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestValidKeyFromKeyPair;
var
  LPriv, LPub: TBytes;
  LError: string;
begin
  WriteLn('TestValidKeyFromKeyPair');
  Check(TryP384ECDHEKeyPair(LPriv, LPub, LError), 'Key pair generated');
  Check(TryP384ValidatePublicKey(LPub, LError), 'Generated key passes validation: ' + LError);
end;

procedure TestInvalidFormat;
var
  LKey: TBytes;
  LError: string;
begin
  WriteLn('TestInvalidFormat');
  SetLength(LKey, 50);
  Check(not TryP384ValidatePublicKey(LKey, LError), 'Too short rejected');

  SetLength(LKey, 97);
  LKey[0] := $02;
  Check(not TryP384ValidatePublicKey(LKey, LError), 'Wrong prefix rejected');
end;

procedure TestPointAtInfinity;
var
  LKey: TBytes;
  LError: string;
begin
  WriteLn('TestPointAtInfinity');
  SetLength(LKey, 97);
  FillChar(LKey[0], 97, 0);
  LKey[0] := $04;
  Check(not TryP384ValidatePublicKey(LKey, LError), 'Point at infinity rejected');
  Check(Pos('infinity', LowerCase(LError)) > 0, 'Error mentions infinity');
end;

procedure TestNotOnCurve;
var
  LKey: TBytes;
  LError: string;
begin
  WriteLn('TestNotOnCurve');
  SetLength(LKey, 97);
  LKey[0] := $04;
  FillChar(LKey[1], 48, $01);
  FillChar(LKey[49], 48, $02);
  Check(not TryP384ValidatePublicKey(LKey, LError), 'Off-curve point rejected');
  Check(Pos('not on curve', LowerCase(LError)) > 0, 'Error mentions not on curve');
end;

procedure TestGeneratorOnCurve;
var
  LKey: TBytes;
  LError: string;
begin
  WriteLn('TestGeneratorOnCurve');
  // P-384 generator point
  LKey := TBytes.Create(
    $04,
    $AA,$87,$CA,$22,$BE,$8B,$05,$37,$8E,$B1,$C7,$1E,$F3,$20,$AD,$74,
    $6E,$1D,$3B,$62,$8B,$A7,$9B,$98,$59,$F7,$41,$E0,$82,$54,$2A,$38,
    $55,$02,$F2,$5D,$BF,$55,$29,$6C,$3A,$54,$5E,$38,$72,$76,$0A,$B7,
    $36,$17,$DE,$4A,$96,$26,$2C,$6F,$5D,$9E,$98,$BF,$92,$92,$DC,$29,
    $F8,$F4,$1D,$BD,$28,$9A,$14,$7C,$E9,$DA,$31,$13,$B5,$F0,$B8,$C0,
    $0A,$60,$B1,$CE,$1D,$7E,$81,$9D,$7A,$43,$1D,$7C,$90,$EA,$0E,$5F
  );
  Check(TryP384ValidatePublicKey(LKey, LError), 'Generator point on curve: ' + LError);
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestValidKeyFromKeyPair;
  TestInvalidFormat;
  TestPointAtInfinity;
  TestNotOnCurve;
  TestGeneratorOnCurve;

  WriteLn;
  WriteLn('P-384 Validation tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
