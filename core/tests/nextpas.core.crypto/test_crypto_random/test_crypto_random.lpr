program test_crypto_random;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.crypto.random,
  nextpas.core.errors,
  nextpas.core.test;

function BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do
    if A[I] <> B[I] then Exit(False);
  Result := True;
end;

var
  LSuite: TTestSuite;
  LRunner: TSuiteRunner;

begin
  LSuite := TTestSuite.Create('crypto.random');

  { C-16：0 长度合法，返回空数组不抛异常（此前 RandomBytes(0) 抛
    ECryptoRandomError，调用方无法表达「0 字节合法」语义） }
  LSuite.Test('GenerateSecureRandomBytes(0) returns empty array', procedure
  var
    LB: TBytes;
    LRaised: Boolean;
  begin
    LRaised := False;
    try
      LB := GenerateSecureRandomBytes(0);
    except
      on E: Exception do
        LRaised := True;
    end;
    CheckFalse(LRaised, '0 长度不应抛异常');
    CheckEqual(0, Length(LB));
  end);

  { 负值是编程错误：EArgumentError（区别于环境故障 ECryptoRandomError） }
  LSuite.Test('GenerateSecureRandomBytes negative raises EArgumentError', procedure
  var
    LRaised: Boolean;
    LRight: Boolean;
  begin
    LRaised := False;
    LRight := False;
    try
      GenerateSecureRandomBytes(-1);
    except
      on E: EArgumentError do
      begin
        LRaised := True;
        LRight := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
    CheckTrue(LRaised, '负值应抛异常');
    CheckTrue(LRight, '负值应抛 EArgumentError 而非其他异常类型');
  end);

  LSuite.Test('GenerateSecureRandomBytes(16) length and freshness', procedure
  var
    LB1, LB2: TBytes;
  begin
    LB1 := GenerateSecureRandomBytes(16);
    LB2 := GenerateSecureRandomBytes(16);
    CheckEqual(16, Length(LB1));
    CheckEqual(16, Length(LB2));
    { 两次采样几乎必不等：16 字节空间 2^128 }
    CheckFalse(BytesEqual(LB1, LB2));
  end);

  { 低层：0 长度 = 无操作成功（与高层语义一致） }
  LSuite.Test('SecureRandomBytes zero length is no-op success', procedure
  var
    LByte: Byte;
  begin
    CheckTrue(SecureRandomBytes(@LByte, 0));
  end);

  LSuite.Test('SecureRandomBytes negative length rejected', procedure
  var
    LByte: Byte;
  begin
    CheckFalse(SecureRandomBytes(@LByte, -1));
  end);

  LSuite.Test('SecureRandomBytes nil buffer rejected', procedure
  begin
    CheckFalse(SecureRandomBytes(nil, 8));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.random');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.