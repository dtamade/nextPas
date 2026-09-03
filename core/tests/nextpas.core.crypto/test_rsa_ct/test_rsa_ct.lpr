program test_rsa_ct;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.path,
  nextpas.core.crypto.rsa.ct,
  nextpas.core.crypto.bigint,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result)-1 do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to Length(AData)-1 do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

function LoadTextFile(const APath: string): string;
begin
  Result := ReadFileText(APath);
end;

function SourcePath(const AUnitFile: string): string;
begin
  Result := ExpandFileName(
    ExtractFileDir(ParamStr(0)) + DirectorySeparator + '..' + DirectorySeparator + '..' + DirectorySeparator +
    '..' + DirectorySeparator + '..' + DirectorySeparator + 'src' + DirectorySeparator + AUnitFile);
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('rsa_ct');

  LSuite.Test('small modexp cross-validate', procedure
  var LMsg, LMod, LExp, LSig, LSigOld: TBytes; LError, LOldError: string;
  begin
    LMsg := TBytes.Create(0,0,0,3); LMod := TBytes.Create(0,0,0,11); LExp := TBytes.Create(0,0,0,7);
    CheckTrue(TryRSACTModExpSign(LMsg, LMod, LExp, LSig, LError));
    CheckEqual('', LError);
    CheckTrue(LSig[Length(LSig)-1] = 9);
    TryBigIntModExpFromUnsignedBytes(LMsg, LExp, LMod, LSigOld, LOldError);
    CheckTrue(LSigOld[Length(LSigOld)-1] = 9);
  end);

  LSuite.Test('m^1 mod n = m', procedure
  var LN, LExp, LMsg, LSig: TBytes; LError: string;
  begin
    LN := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF97');
    LExp := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
    LMsg := HexToBytes('000000000000000000000000000000000000000000000000000000000000012A');
    CheckTrue(TryRSACTModExpSign(LMsg, LN, LExp, LSig, LError));
    CheckTrue(LSig[Length(LSig)-1] = $2A);
    CheckTrue(LSig[Length(LSig)-2] = $01);
  end);

  LSuite.Test('m^2 mod n', procedure
  var LN, LExp, LMsg, LSigCT, LSigOld: TBytes; LError, LOldError: string;
  begin
    LN := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEF');
    LExp := HexToBytes('0000000000000000000000000000000000000000000000000000000000000002');
    LMsg := HexToBytes('0000000000000000000000000000000000000000000000000000000000000005');
    CheckTrue(TryRSACTModExpSign(LMsg, LN, LExp, LSigCT, LError));
    CheckTrue(LSigCT[Length(LSigCT)-1] = 25);
    TryBigIntModExpFromUnsignedBytes(LMsg, LExp, LN, LSigOld, LOldError);
    CheckTrue(LSigOld[Length(LSigOld)-1] = 25);
  end);

  LSuite.Test('cross-validate 1024-bit', procedure
  var LN, LD, LMsg, LSigCT, LSigOld: TBytes; LError, LOldError: string; I: Integer;
  begin
    SetLength(LN, 128);
    for I := 0 to 127 do LN[I] := Byte((I*37+13) and $FF);
    LN[127] := LN[127] or 1; LN[0] := LN[0] or $80;
    SetLength(LD, 128);
    for I := 0 to 127 do LD[I] := Byte((I*53+7) and $FF);
    LD[127] := LD[127] or 1;
    SetLength(LMsg, 128);
    for I := 0 to 127 do LMsg[I] := Byte((I*17+3) and $FF);
    LMsg[0] := LMsg[0] and $7F;
    CheckTrue(TryRSACTModExpSign(LMsg, LN, LD, LSigCT, LError));
    CheckTrue(TryRSAModExpSignPurePascal(LMsg, LN, LD, LSigOld, LOldError));
    CheckEqual(BytesToHex(LSigCT), BytesToHex(LSigOld));
  end);

  LSuite.Test('error cases', procedure
  var LSig: TBytes; LError: string; LN, LE, LD: TBytes;
  begin
    SetLength(LN, 0); LE := TBytes.Create(1); LD := TBytes.Create(1);
    CheckTrue(not TryRSACTModExpSign(LE, LN, LD, LSig, LError));
    LN := TBytes.Create(0,0,0,4);
    CheckTrue(not TryRSACTModExpSign(LE, LN, LD, LSig, LError));
  end);

  LSuite.Test('512-bit with large exponent', procedure
  var LN, LD, LMsg, LSigCT, LSigOld: TBytes; LError, LOldError: string; I: Integer;
  begin
    SetLength(LN, 64);
    for I := 0 to 63 do LN[I] := Byte((I*41+19) and $FF);
    LN[63] := LN[63] or 1; LN[0] := LN[0] or $C0;
    SetLength(LD, 64);
    for I := 0 to 63 do LD[I] := Byte((I*67+31) and $FF);
    LD[63] := LD[63] or 1; LD[0] := LD[0] or $80;
    SetLength(LMsg, 64);
    for I := 0 to 63 do LMsg[I] := Byte((I*23+5) and $FF);
    LMsg[0] := LMsg[0] and $3F;
    CheckTrue(TryRSACTModExpSign(LMsg, LN, LD, LSigCT, LError));
    CheckTrue(TryRSAModExpSignPurePascal(LMsg, LN, LD, LSigOld, LOldError));
    CheckEqual(BytesToHex(LSigCT), BytesToHex(LSigOld));
  end);

  LSuite.Test('CRT cross-validate', procedure
  var LMsg, LN, LD, LE, LP, LQ, LDP, LDQ, LQInv, LCRT, LExpected: TBytes;
    LCRTError, LExpectedError: string;
  begin
    LMsg := TBytes.Create(42); LN := TBytes.Create(0,143); LD := TBytes.Create(103);
    LE := TBytes.Create(7); LP := TBytes.Create(11); LQ := TBytes.Create(13);
    LDP := TBytes.Create(3); LDQ := TBytes.Create(7); LQInv := TBytes.Create(6);
    CheckTrue(TryRSACTModExpSign(LMsg, LN, LD, LExpected, LExpectedError));
    CheckTrue(TryRSACTSignWithCRT(LMsg, LN, LE, LP, LQ, LDP, LDQ, LQInv, LCRT, LCRTError));
    CheckEqual(BytesToHex(LCRT), BytesToHex(LExpected));
  end);

  LSuite.Test('sensitive scratch cleanup contract', procedure
  var LSource: string;
  begin
    LSource := LowerCase(LoadTextFile(SourcePath('nextpas.core.crypto.rsa.ct.pas')));
    CheckTrue(Pos('procedure ctnatsecurezero(var a: tctnat);', LSource) > 0);
    CheckTrue(Pos('procedure ctmontctxsecurezero(var ctx: tctmontctx);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(a);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(lmsg);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(lresult);', LSource) > 0);
    CheckTrue(Pos('ctmontctxsecurezero(lctx);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(lm1);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(lm2);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(lh);', LSource) > 0);
    CheckTrue(Pos('ctnatsecurezero(lsig);', LSource) > 0);
    CheckTrue(Pos('ctmontctxsecurezero(lctxp);', LSource) > 0);
    CheckTrue(Pos('ctmontctxsecurezero(lctxq);', LSource) > 0);
    CheckTrue(Pos('ctmontctxsecurezero(lctxn);', LSource) > 0);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.rsa_ct');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
