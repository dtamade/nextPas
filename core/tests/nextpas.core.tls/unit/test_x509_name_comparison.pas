program test_x509_name_comparison;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.factory,
  fafafa.ssl;

var
  GPassed, GFailed: Integer;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('[OK] ', AMessage);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure TestBasicComparison;
begin
  WriteLn('=== Test: Basic DN Comparison ===');
  
  // 相同DN
  AssertTrue(
    TCertificateUtils.CompareX509Names('CN=Test', 'CN=Test'),
    'Identical DNs should match'
  );
  
  // 不同DN
  AssertTrue(
    not TCertificateUtils.CompareX509Names('CN=Test1', 'CN=Test2'),
    'Different CNs should not match'
  );
  
  WriteLn;
end;

procedure TestComponentOrder;
begin
  WriteLn('=== Test: Component Order Independence ===');
  
  // 顺序不同但等价
  AssertTrue(
    TCertificateUtils.CompareX509Names(
      'CN=Test,O=Org,C=US',
      'C=US,O=Org,CN=Test'
    ),
    'Different order should match (normalized)'
  );
  
  AssertTrue(
    TCertificateUtils.CompareX509Names(
      'C=US,ST=CA,O=Company,CN=example.com',
      'CN=example.com,O=Company,ST=CA,C=US'
    ),
    'Complex DN order should match'
  );
  
  WriteLn;
end;

procedure TestCaseSensitivity;
begin
  WriteLn('=== Test: Case Sensitivity ===');
  
  // 默认大小写不敏感 (ACaseInsensitive=True is default)
  AssertTrue(
    TCertificateUtils.CompareX509Names('CN=test', 'CN=TEST'),
    'Different case should match (default case-insensitive)'
  );
  
  // 显式大小写敏感
  AssertTrue(
    not TCertificateUtils.CompareX509Names('CN=test', 'CN=TEST', False),
    'Different case should NOT match (case-sensitive mode)'
  );
  
  // 显式大小写不敏感
  AssertTrue(
    TCertificateUtils.CompareX509Names(
      'CN=Example,O=COMPANY',
      'cn=example,o=company',
      True
    ),
    'Complex case-insensitive comparison'
  );
  
  WriteLn;
end;

procedure TestWhitespace;
begin
  WriteLn('=== Test: Whitespace Handling ===');
  
  // 空格规范化
  AssertTrue(
    TCertificateUtils.CompareX509Names('CN=Test', 'CN = Test'),
    'Whitespace around = should be normalized'
  );
  
  AssertTrue(
    TCertificateUtils.CompareX509Names('CN=Test,O=Org', 'CN=Test, O=Org'),
    'Whitespace after comma should be normalized'
  );
  
  WriteLn;
end;

begin
  GPassed := 0;
  GFailed := 0;
  
  WriteLn('====================================');
  WriteLn('  X509_NAME Comparison Test Suite');
  WriteLn('====================================');
  WriteLn;
  
  try
    TestBasicComparison;
    TestComponentOrder;
    TestCaseSensitivity;
    TestWhitespace;
    
    WriteLn('====================================');
    WriteLn('Results:');
    WriteLn('  Passed: ', GPassed);
    WriteLn('  Failed: ', GFailed);
    WriteLn('====================================');
    
    if GFailed > 0 then
      Halt(1);
      
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
