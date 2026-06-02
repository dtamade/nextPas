program test_crl;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.asn1, nextpas.core.tls.x509, nextpas.core.tls.crl;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const ATestName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

function TempCRLDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_crl_' + IntToStr(GetProcessID);
end;

procedure WriteTextFile(const AFileName, AContent: string);
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.Text := AContent;
    LText.SaveToFile(AFileName);
  finally
    LText.Free;
  end;
end;

procedure CleanupGeneratedCRLFixture(const ADir: string);
begin
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'ca.crl');
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'ca.crt');
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'ca.key');
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'config.cnf');
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'index.txt');
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'serial');
  DeleteFile(IncludeTrailingPathDelimiter(ADir) + 'crlnumber');
  RemoveDir(IncludeTrailingPathDelimiter(ADir) + 'newcerts');
  RemoveDir(ADir);
end;

function GenerateRuntimeCRL(out ACRLPath: string): Boolean;
var
  LDir: string;
  LConfigPath: string;
  LRet: Integer;
begin
  Result := False;
  LDir := TempCRLDir;
  CleanupGeneratedCRLFixture(LDir);
  if not ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'newcerts') then
    Exit(False);

  WriteTextFile(IncludeTrailingPathDelimiter(LDir) + 'index.txt', '');
  WriteTextFile(IncludeTrailingPathDelimiter(LDir) + 'serial', '1000');
  WriteTextFile(IncludeTrailingPathDelimiter(LDir) + 'crlnumber', '1000');

  LConfigPath := IncludeTrailingPathDelimiter(LDir) + 'config.cnf';
  WriteTextFile(
    LConfigPath,
    '[ ca ]' + LineEnding +
    'default_ca = CA_default' + LineEnding +
    LineEnding +
    '[ CA_default ]' + LineEnding +
    'dir = ' + LDir + LineEnding +
    'database = $dir/index.txt' + LineEnding +
    'new_certs_dir = $dir/newcerts' + LineEnding +
    'certificate = $dir/ca.crt' + LineEnding +
    'private_key = $dir/ca.key' + LineEnding +
    'serial = $dir/serial' + LineEnding +
    'crlnumber = $dir/crlnumber' + LineEnding +
    'default_md = sha256' + LineEnding +
    'default_days = 1' + LineEnding +
    'default_crl_hours = 1' + LineEnding +
    'policy = policy_loose' + LineEnding +
    LineEnding +
    '[ policy_loose ]' + LineEnding +
    'commonName = supplied'
  );

  LRet := ExecuteProcess(
    '/usr/bin/openssl',
    'req -x509 -newkey rsa:2048 -keyout ' +
    IncludeTrailingPathDelimiter(LDir) + 'ca.key -out ' +
    IncludeTrailingPathDelimiter(LDir) + 'ca.crt -sha256 -days 1 -nodes ' +
    '-subj "/CN=nextpas-crl-ca" -addext "basicConstraints=critical,CA:TRUE"');
  if LRet <> 0 then
    Exit(False);

  ACRLPath := IncludeTrailingPathDelimiter(LDir) + 'ca.crl';
  LRet := ExecuteProcess(
    '/usr/bin/openssl',
    'ca -gencrl -config ' + LConfigPath + ' -out ' + ACRLPath + ' -batch');
  Result := (LRet = 0) and FileExists(ACRLPath);
end;

// ========================================================================
// TX509CRL 基础测试
// ========================================================================
procedure TestCRLCreate;
var
  CRL: TX509CRL;
begin
  WriteLn;
  WriteLn('=== TX509CRL 创建测试 ===');

  CRL := TX509CRL.Create;
  try
    Check('默认 Version', CRL.Version = 1);
    Check('默认 SignatureAlgorithm', CRL.SignatureAlgorithm = '');
    Check('默认 ThisUpdate', CRL.ThisUpdate = 0);
    Check('默认 NextUpdate', CRL.NextUpdate = 0);
    Check('默认 HasNextUpdate', CRL.HasNextUpdate = False);
    Check('默认 EntryCount', CRL.EntryCount = 0);
    Check('默认 Entries 长度', Length(CRL.Entries) = 0);
    Check('默认 Extensions 长度', Length(CRL.Extensions) = 0);
  finally
    CRL.Free;
  end;
end;

// ========================================================================
// 序列号转换测试
// ========================================================================
procedure TestSerialNumberConversion;
var
  Serial: TBytes;
  HexStr: string;
begin
  WriteLn;
  WriteLn('=== 序列号转换测试 ===');

  // 测试序列号到十六进制
  SetLength(Serial, 4);
  Serial[0] := $01;
  Serial[1] := $23;
  Serial[2] := $45;
  Serial[3] := $67;

  HexStr := SerialNumberToHex(Serial);
  Check('SerialNumberToHex', HexStr = '01234567');

  // 测试十六进制到序列号
  Serial := HexToSerialNumber('AABBCCDD');
  Check('HexToSerialNumber 长度', Length(Serial) = 4);
  Check('HexToSerialNumber[0]', Serial[0] = $AA);
  Check('HexToSerialNumber[1]', Serial[1] = $BB);
  Check('HexToSerialNumber[2]', Serial[2] = $CC);
  Check('HexToSerialNumber[3]', Serial[3] = $DD);

  // 测试带分隔符的十六进制
  Serial := HexToSerialNumber('AA:BB:CC:DD');
  Check('带冒号 HexToSerialNumber', Length(Serial) = 4);

  Serial := HexToSerialNumber('AA BB CC DD');
  Check('带空格 HexToSerialNumber', Length(Serial) = 4);
end;

// ========================================================================
// CompareSerialNumber 测试
// ========================================================================
procedure TestCompareSerialNumber;
var
  A, B: TBytes;
begin
  WriteLn;
  WriteLn('=== CompareSerialNumber 测试 ===');

  // 相同序列号
  SetLength(A, 4);
  SetLength(B, 4);
  A[0] := $01; A[1] := $02; A[2] := $03; A[3] := $04;
  B[0] := $01; B[1] := $02; B[2] := $03; B[3] := $04;
  Check('相同序列号比较', CompareSerialNumber(A, B));

  // 不同序列号
  B[3] := $05;
  Check('不同序列号比较', not CompareSerialNumber(A, B));

  // 带前导零的序列号
  SetLength(A, 5);
  SetLength(B, 4);
  A[0] := $00; A[1] := $01; A[2] := $02; A[3] := $03; A[4] := $04;
  B[0] := $01; B[1] := $02; B[2] := $03; B[3] := $04;
  Check('带前导零的序列号比较', CompareSerialNumber(A, B));

  // 多个前导零
  SetLength(A, 6);
  A[0] := $00; A[1] := $00; A[2] := $01; A[3] := $02; A[4] := $03; A[5] := $04;
  Check('多个前导零比较', CompareSerialNumber(A, B));
end;

// ========================================================================
// CRLRevokeReasonToString 测试
// ========================================================================
procedure TestRevokeReasonToString;
begin
  WriteLn;
  WriteLn('=== CRLRevokeReasonToString 测试 ===');

  Check('crlrrUnspecified', CRLRevokeReasonToString(crlrrUnspecified) = 'Unspecified');
  Check('crlrrKeyCompromise', CRLRevokeReasonToString(crlrrKeyCompromise) = 'Key Compromise');
  Check('crlrrCACompromise', CRLRevokeReasonToString(crlrrCACompromise) = 'CA Compromise');
  Check('crlrrAffiliationChanged', CRLRevokeReasonToString(crlrrAffiliationChanged) = 'Affiliation Changed');
  Check('crlrrSuperseded', CRLRevokeReasonToString(crlrrSuperseded) = 'Superseded');
  Check('crlrrCessationOfOperation', CRLRevokeReasonToString(crlrrCessationOfOperation) = 'Cessation of Operation');
  Check('crlrrCertificateHold', CRLRevokeReasonToString(crlrrCertificateHold) = 'Certificate Hold');
  Check('crlrrRemoveFromCRL', CRLRevokeReasonToString(crlrrRemoveFromCRL) = 'Remove from CRL');
  Check('crlrrPrivilegeWithdrawn', CRLRevokeReasonToString(crlrrPrivilegeWithdrawn) = 'Privilege Withdrawn');
  Check('crlrrAACompromise', CRLRevokeReasonToString(crlrrAACompromise) = 'AA Compromise');
end;

// ========================================================================
// TCRLEntry 测试
// ========================================================================
procedure TestCRLEntry;
var
  Entry: TCRLEntry;
begin
  WriteLn;
  WriteLn('=== TCRLEntry 测试 ===');

  FillChar(Entry, SizeOf(Entry), 0);

  // 测试默认值
  Check('默认 SerialNumber 长度', Length(Entry.SerialNumber) = 0);
  Check('默认 RevocationDate', Entry.RevocationDate = 0);
  Check('默认 Reason', Entry.Reason = crlrrUnspecified);
  Check('默认 HasReason', Entry.HasReason = False);
  Check('默认 HasInvalidityDate', Entry.HasInvalidityDate = False);

  // 设置值
  SetLength(Entry.SerialNumber, 4);
  Entry.SerialNumber[0] := $01;
  Entry.SerialNumber[1] := $02;
  Entry.SerialNumber[2] := $03;
  Entry.SerialNumber[3] := $04;
  Entry.RevocationDate := Now;
  Entry.Reason := crlrrKeyCompromise;
  Entry.HasReason := True;

  Check('设置 SerialNumber', Length(Entry.SerialNumber) = 4);
  Check('设置 Reason', Entry.Reason = crlrrKeyCompromise);
  Check('设置 HasReason', Entry.HasReason);
end;

// ========================================================================
// CRL DER 解析测试
// ========================================================================
procedure TestCRLParsing;
var
  CRL: TX509CRL;
begin
  WriteLn;
  WriteLn('=== CRL DER 解析测试 ===');

  CRL := TX509CRL.Create;
  try
    // 测试创建成功
    Check('CRL 创建成功', CRL <> nil);
    Check('创建后 EntryCount', CRL.EntryCount = 0);
  finally
    CRL.Free;
  end;
end;

// ========================================================================
// IsRevoked 和 GetRevokedEntry 测试
// ========================================================================
procedure TestIsRevoked;
var
  CRL: TX509CRL;
  Serial: TBytes;
begin
  WriteLn;
  WriteLn('=== IsRevoked 测试 ===');

  CRL := TX509CRL.Create;
  try
    // 在空 CRL 中查找
    SetLength(Serial, 4);
    Serial[0] := $01;
    Serial[1] := $02;
    Serial[2] := $03;
    Serial[3] := $04;

    Check('空 CRL IsRevoked', not CRL.IsRevoked(Serial));
    Check('空 CRL IsRevokedHex', not CRL.IsRevokedHex('01020304'));
  finally
    CRL.Free;
  end;
end;

// ========================================================================
// IsExpired 和 IsValid 测试
// ========================================================================
procedure TestCRLValidity;
var
  CRL: TX509CRL;
  LCRLPath: string;
begin
  WriteLn;
  WriteLn('=== CRL 有效期测试 ===');

  CRL := TX509CRL.Create;
  try
    // 无 nextUpdate 时不认为过期
    Check('无 NextUpdate 时 IsExpired', not CRL.IsExpired);

    // thisUpdate 为 0 时不有效
    Check('ThisUpdate=0 时 IsValid', not CRL.IsValid);
  finally
    CRL.Free;
  end;

  if not GenerateRuntimeCRL(LCRLPath) then
  begin
    Check('运行时生成短时有效 CRL', False);
    Exit;
  end;

  CRL := TX509CRL.Create;
  try
    CRL.LoadFromFile(LCRLPath);
    Check('生成的 CRL 有 nextUpdate', CRL.HasNextUpdate);
    Check('生成的 CRL 当前有效', CRL.IsValid);
    Check('生成的 CRL 当前未过期', not CRL.IsExpired);
  finally
    CRL.Free;
    CleanupGeneratedCRLFixture(TempCRLDir);
  end;
end;

// ========================================================================
// 吊销原因枚举测试
// ========================================================================
procedure TestRevokeReasonEnum;
begin
  WriteLn;
  WriteLn('=== 吊销原因枚举测试 ===');

  // RFC 5280 定义的吊销原因
  Check('crlrrUnspecified 值', Ord(crlrrUnspecified) = 0);
  Check('crlrrKeyCompromise 值', Ord(crlrrKeyCompromise) = 1);
  Check('crlrrCACompromise 值', Ord(crlrrCACompromise) = 2);
  Check('crlrrAffiliationChanged 值', Ord(crlrrAffiliationChanged) = 3);
  Check('crlrrSuperseded 值', Ord(crlrrSuperseded) = 4);
  Check('crlrrCessationOfOperation 值', Ord(crlrrCessationOfOperation) = 5);
  Check('crlrrCertificateHold 值', Ord(crlrrCertificateHold) = 6);
  Check('crlrrRemoveFromCRL 值', Ord(crlrrRemoveFromCRL) = 7);
  Check('crlrrPrivilegeWithdrawn 值', Ord(crlrrPrivilegeWithdrawn) = 8);
  Check('crlrrAACompromise 值', Ord(crlrrAACompromise) = 9);
end;

begin
  WriteLn('========================================');
  WriteLn('nextpas.core.tls.crl 单元测试');
  WriteLn('========================================');

  TestsPassed := 0;
  TestsFailed := 0;

  TestCRLCreate;
  TestSerialNumberConversion;
  TestCompareSerialNumber;
  TestRevokeReasonToString;
  TestCRLEntry;
  TestCRLParsing;
  TestIsRevoked;
  TestCRLValidity;
  TestRevokeReasonEnum;

  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
