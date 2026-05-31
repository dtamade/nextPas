program test_hashdata_extended_algorithms;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.encoding;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  SkippedTests: Integer = 0;

procedure AssertTrue(const Msg: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(Format('[TEST] %s... ', [Msg]));
  if Condition then
  begin
    WriteLn('✓ PASS');
    Inc(PassedTests);
  end
  else
    WriteLn('✗ FAIL');
end;

procedure AssertSkip(const Msg, Reason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn(Format('[TEST] %s... ↷ SKIP (%s)', [Msg, Reason]));
end;

procedure AssertHashLength(const Name: string; HashType: TSSLHash; const Data: TBytes; ExpectedLen: Integer);
var
  DigestHex: string;
begin
  try
    DigestHex := TSSLHelper.HashData(Data, HashType);
    AssertTrue(Name + ' returns non-empty digest', DigestHex <> '');
    AssertTrue(Name + ' hex length', Length(DigestHex) = ExpectedLen);
  except
    on E: Exception do
      AssertTrue(Name + ' should be supported (exception: ' + E.Message + ')', False);
  end;
end;

procedure AssertOptionalHashLength(const Name: string; HashType: TSSLHash; const Data: TBytes; ExpectedLen: Integer);
var
  DigestHex: string;
  LMsg: string;
begin
  try
    DigestHex := TSSLHelper.HashData(Data, HashType);
    AssertTrue(Name + ' returns non-empty digest', DigestHex <> '');
    AssertTrue(Name + ' hex length', Length(DigestHex) = ExpectedLen);
  except
    on E: Exception do
    begin
      LMsg := LowerCase(E.Message);
      if Pos('not available', LMsg) > 0 then
        AssertSkip(Name + ' runtime availability', E.Message)
      else
        AssertTrue(Name + ' should be supported when backend capability exists (exception: ' + E.Message + ')', False);
    end;
  end;
end;

var
  Data: TBytes;
  FailedTests: Integer;
begin
  WriteLn('========================================');
  WriteLn('HashData Extended Algorithm Tests');
  WriteLn('========================================');

  Data := TEncoding.UTF8.GetBytes('hashdata-extended-algo-test');

  // Mandatory support added in this iteration
  AssertHashLength('SHA224', sslHashSHA224, Data, 56);

  // Optional: depends on runtime OpenSSL feature availability
  AssertOptionalHashLength('SHA3-256', sslHashSHA3_256, Data, 64);
  AssertOptionalHashLength('SHA3-512', sslHashSHA3_512, Data, 128);
  AssertOptionalHashLength('BLAKE2b', sslHashBLAKE2b, Data, 128);

  FailedTests := TotalTests - PassedTests - SkippedTests;

  WriteLn('========================================');
  WriteLn('HashData Extended Algorithm Summary');
  WriteLn('========================================');
  WriteLn(Format('Total tests: %d', [TotalTests]));
  WriteLn(Format('Passed: %d', [PassedTests]));
  WriteLn(Format('Skipped: %d', [SkippedTests]));
  WriteLn(Format('Failed: %d', [FailedTests]));

  if FailedTests = 0 then
    WriteLn('✅ HASHDATA EXTENDED ALGORITHM TESTS PASSED!')
  else
    Halt(1);
end.
