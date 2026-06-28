program test_argon2;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.crypto.argon2,
  nextpas.core.test;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TTestRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('argon2');

  LSuite.Test('basic', procedure
  var LPwd, LSalt, LHash: TBytes;
  begin
    SetLength(LPwd, 8); Move(PAnsiChar('password')^, LPwd[0], 8);
    SetLength(LSalt, 8); Move(PAnsiChar('saltsalt')^, LSalt[0], 8);
    LHash := Argon2Hash(LPwd, LSalt, 1, 16, 1, 32, atArgon2id);
    CheckEqual(32, Length(LHash));
    CheckTrue(BytesToHex(LHash) <> StringOfChar('0', 64));
  end);

  LSuite.Test('deterministic', procedure
  var LPwd, LSalt, LH1, LH2: TBytes;
  begin
    SetLength(LPwd, 4); Move(PAnsiChar('test')^, LPwd[0], 4);
    SetLength(LSalt, 8); Move(PAnsiChar('saltsalt')^, LSalt[0], 8);
    LH1 := Argon2Hash(LPwd, LSalt, 1, 16, 1, 32, atArgon2id);
    LH2 := Argon2Hash(LPwd, LSalt, 1, 16, 1, 32, atArgon2id);
    CheckEqual(BytesToHex(LH1), BytesToHex(LH2));
  end);

  LSuite.Test('different params → different hash', procedure
  var LPwd, LSalt, LH1, LH2: TBytes;
  begin
    SetLength(LPwd, 4); Move(PAnsiChar('test')^, LPwd[0], 4);
    SetLength(LSalt, 8); Move(PAnsiChar('saltsalt')^, LSalt[0], 8);
    LH1 := Argon2Hash(LPwd, LSalt, 1, 16, 1, 32, atArgon2id);
    LH2 := Argon2Hash(LPwd, LSalt, 2, 16, 1, 32, atArgon2id);
    CheckTrue(BytesToHex(LH1) <> BytesToHex(LH2));
  end);

  LSuite.Test('output length', procedure
  var LPwd, LSalt, LHash: TBytes;
  begin
    SetLength(LPwd, 4); Move(PAnsiChar('test')^, LPwd[0], 4);
    SetLength(LSalt, 8); Move(PAnsiChar('saltsalt')^, LSalt[0], 8);
    LHash := Argon2Hash(LPwd, LSalt, 1, 16, 1, 16, atArgon2id);
    CheckEqual(16, Length(LHash));
    LHash := Argon2Hash(LPwd, LSalt, 1, 16, 1, 64, atArgon2id);
    CheckEqual(64, Length(LHash));
  end);

  LRunner := TTestRunner.Create('nextpas.core.crypto.argon2');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
