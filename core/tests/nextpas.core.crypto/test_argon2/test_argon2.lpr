program test_argon2;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.argon2,
  nextpas.core.test;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
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
    CheckTrue(BytesToHex(LHash) <> TextOfChar('0', 64));
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

  LSuite.Test('hashstr/verify roundtrip', procedure
  var LPwd: TBytes;
      LEnc, LEnc2: string;
  begin
    SetLength(LPwd, 8); Move(PAnsiChar('password')^, LPwd[0], 8);
    LEnc := Argon2HashStr(LPwd, 65536, 2, 1, 32, atArgon2id);
    CheckTrue(LEnc <> '');
    CheckTrue(Argon2Verify(LPwd, LEnc));
    { 相同参数两次 → 盐不同 → 串不同，但都能验证通过 }
    LEnc2 := Argon2HashStr(LPwd, 65536, 2, 1, 32, atArgon2id);
    CheckTrue(LEnc <> LEnc2);
    CheckTrue(Argon2Verify(LPwd, LEnc2));
  end);

  LSuite.Test('verify wrong password', procedure
  var LPwd, LBad: TBytes;
      LEnc: string;
  begin
    SetLength(LPwd, 8); Move(PAnsiChar('password')^, LPwd[0], 8);
    SetLength(LBad, 4); Move(PAnsiChar('nope')^, LBad[0], 4);
    LEnc := Argon2HashStr(LPwd, 65536, 2, 1, 32, atArgon2id);
    CheckTrue(not Argon2Verify(LBad, LEnc));
  end);

  LSuite.Test('verify argon2i/argon2d types', procedure
  var LPwd: TBytes;
      LEnc: string;
  begin
    SetLength(LPwd, 4); Move(PAnsiChar('test')^, LPwd[0], 4);
    LEnc := Argon2HashStr(LPwd, 65536, 2, 1, 32, atArgon2i);
    CheckTrue(Argon2Verify(LPwd, LEnc));
    LEnc := Argon2HashStr(LPwd, 65536, 2, 1, 32, atArgon2d);
    CheckTrue(Argon2Verify(LPwd, LEnc));
  end);

  LSuite.Test('verify rejects malformed', procedure
  var LPwd: TBytes;
  begin
    SetLength(LPwd, 4); Move(PAnsiChar('test')^, LPwd[0], 4);
    CheckTrue(not Argon2Verify(LPwd, ''));
    CheckTrue(not Argon2Verify(LPwd, 'garbage'));
    CheckTrue(not Argon2Verify(LPwd, '$argon2x$v=19$m=64,t=2,p=1$AAAA$AAAA'));
    CheckTrue(not Argon2Verify(LPwd, '$argon2id$v=18$m=64,t=2,p=1$AAAA$AAAA'));
    CheckTrue(not Argon2Verify(LPwd, '$argon2id$v=19$m=4,t=2,p=1$AAAA$AAAA'));
    CheckTrue(not Argon2Verify(LPwd, '$argon2id$v=19$t=2,p=1$AAAA$AAAA'));
    CheckTrue(not Argon2Verify(LPwd, '$argon2id$v=19$m=64,x=2,p=1$AAAA$AAAA'));
  end);

  LSuite.Test('verify rejects tampered hash', procedure
  var LPwd: TBytes;
      LEnc, LTampered: string;
  begin
    SetLength(LPwd, 4); Move(PAnsiChar('test')^, LPwd[0], 4);
    LEnc := Argon2HashStr(LPwd, 65536, 2, 1, 32, atArgon2id);
    { 篡改 hash 段末字符（保证替换后不同） }
    LTampered := LEnc;
    if LTampered[Length(LTampered)] = 'A' then
      LTampered[Length(LTampered)] := 'B'
    else
      LTampered[Length(LTampered)] := 'A';
    CheckTrue(not Argon2Verify(LPwd, LTampered));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.argon2');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
