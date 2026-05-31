program test_p384;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.p384;

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

procedure TestScalarMultBase;
var
  LScalar: TBytes;
  LPoint: TP384Point;
  LError: string;
  LOk: Boolean;
begin
  // 1 * G = G
  LScalar := HexToBytes('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001');
  LOk := TryP384ScalarMultBase(LScalar, LPoint, LError);
  Check('ScalarMultBase(1) ok', LOk);
  if LOk then
  begin
    Check('ScalarMultBase(1) = Gx',
      BytesToHex(LPoint.X) = 'aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab7');
    Check('ScalarMultBase(1) = Gy',
      BytesToHex(LPoint.Y) = '3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f');
  end;
end;

procedure TestECDHEKeyPair;
var
  LPriv, LPub: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LOk := TryP384ECDHEKeyPair(LPriv, LPub, LError);
  Check('ECDHE key pair generation ok', LOk);
  if LOk then
  begin
    Check('private key = 48 bytes', Length(LPriv) = 48);
    Check('public key = 97 bytes (04||X||Y)', Length(LPub) = 97);
    Check('public key starts with 04', LPub[0] = $04);
  end;
end;

procedure TestECDHERoundtrip;
var
  LPrivA, LPubA, LPrivB, LPubB: TBytes;
  LSharedAB, LSharedBA: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LOk := TryP384ECDHEKeyPair(LPrivA, LPubA, LError);
  Check('ECDHE A keygen ok', LOk);
  if not LOk then Exit;

  LOk := TryP384ECDHEKeyPair(LPrivB, LPubB, LError);
  Check('ECDHE B keygen ok', LOk);
  if not LOk then Exit;

  LOk := TryP384ECDHE(LPrivA, LPubB, LSharedAB, LError);
  Check('ECDHE A*B ok', LOk);
  if not LOk then begin WriteLn('    ', LError); Exit; end;

  LOk := TryP384ECDHE(LPrivB, LPubA, LSharedBA, LError);
  Check('ECDHE B*A ok', LOk);
  if not LOk then begin WriteLn('    ', LError); Exit; end;

  Check('shared secrets match', BytesToHex(LSharedAB) = BytesToHex(LSharedBA));
  Check('shared secret = 48 bytes', Length(LSharedAB) = 48);
end;

procedure TestValidatePublicKey;
var
  LPriv, LPub: TBytes;
  LBadPub: TBytes;
  LError: string;
  LOk: Boolean;
begin
  TryP384ECDHEKeyPair(LPriv, LPub, LError);

  LOk := TryP384ValidatePublicKey(LPub, LError);
  Check('validate: generated key is valid', LOk);

  // Invalid: wrong length
  SetLength(LBadPub, 10);
  LOk := TryP384ValidatePublicKey(LBadPub, LError);
  Check('validate: short key rejected', not LOk);

  // Invalid: point not on curve (random bytes)
  SetLength(LBadPub, 97);
  LBadPub[0] := $04;
  FillChar(LBadPub[1], 96, $AA);
  LOk := TryP384ValidatePublicKey(LBadPub, LError);
  Check('validate: random point rejected', not LOk);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== P-384 ECDHE Tests ===');
  WriteLn;

  TestScalarMultBase;
  TestECDHEKeyPair;
  TestECDHERoundtrip;
  TestValidatePublicKey;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
