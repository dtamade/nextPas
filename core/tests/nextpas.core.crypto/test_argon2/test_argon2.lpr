program test_argon2;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.argon2;

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

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestArgon2id_Basic;
var
  LPassword, LSalt, LHash: TBytes;
begin
  SetLength(LPassword, 8);
  Move(PAnsiChar('password')^, LPassword[0], 8);
  SetLength(LSalt, 8);
  Move(PAnsiChar('saltsalt')^, LSalt[0], 8);

  LHash := Argon2Hash(LPassword, LSalt, 1, 16, 1, 32, atArgon2id);
  Check('Argon2id basic: output length = 32', Length(LHash) = 32);
  Check('Argon2id basic: non-zero', BytesToHex(LHash) <> StringOfChar('0', 64));
end;

procedure TestArgon2id_Deterministic;
var
  LPassword, LSalt, LHash1, LHash2: TBytes;
begin
  SetLength(LPassword, 4);
  Move(PAnsiChar('test')^, LPassword[0], 4);
  SetLength(LSalt, 8);
  Move(PAnsiChar('saltsalt')^, LSalt[0], 8);

  LHash1 := Argon2Hash(LPassword, LSalt, 1, 16, 1, 32, atArgon2id);
  LHash2 := Argon2Hash(LPassword, LSalt, 1, 16, 1, 32, atArgon2id);
  Check('Argon2id deterministic', BytesToHex(LHash1) = BytesToHex(LHash2));
end;

procedure TestArgon2id_DifferentParams;
var
  LPassword, LSalt, LHash1, LHash2: TBytes;
begin
  SetLength(LPassword, 4);
  Move(PAnsiChar('test')^, LPassword[0], 4);
  SetLength(LSalt, 8);
  Move(PAnsiChar('saltsalt')^, LSalt[0], 8);

  LHash1 := Argon2Hash(LPassword, LSalt, 1, 16, 1, 32, atArgon2id);
  LHash2 := Argon2Hash(LPassword, LSalt, 2, 16, 1, 32, atArgon2id);
  Check('different time cost → different hash', BytesToHex(LHash1) <> BytesToHex(LHash2));
end;

procedure TestArgon2id_OutputLength;
var
  LPassword, LSalt, LHash: TBytes;
begin
  SetLength(LPassword, 4);
  Move(PAnsiChar('test')^, LPassword[0], 4);
  SetLength(LSalt, 8);
  Move(PAnsiChar('saltsalt')^, LSalt[0], 8);

  LHash := Argon2Hash(LPassword, LSalt, 1, 16, 1, 16, atArgon2id);
  Check('output 16 bytes', Length(LHash) = 16);

  LHash := Argon2Hash(LPassword, LSalt, 1, 16, 1, 64, atArgon2id);
  Check('output 64 bytes', Length(LHash) = 64);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Argon2 KDF Tests ===');
  WriteLn;

  TestArgon2id_Basic;
  TestArgon2id_Deterministic;
  TestArgon2id_DifferentParams;
  TestArgon2id_OutputLength;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
