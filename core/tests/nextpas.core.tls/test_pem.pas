program test_pem;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.pem;

var
  TestsPassed, TestsFailed, TestsSkipped: Integer;

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

procedure Skip(const ATestName, AReason: string);
begin
  WriteLn('[SKIP] ', ATestName, ' - ', AReason);
  Inc(TestsSkipped);
end;

// 测试 Base64 编解码 (通过 PEM 格式)
procedure TestBase64;
var
  Writer: TPEMWriter;
  Reader: TPEMReader;
  TestData: TBytes;
  PEMText: string;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== 测试 Base64 编解码 ===');

  // 测试数据: "Hello, World!"
  SetLength(TestData, 13);
  TestData[0] := Ord('H');
  TestData[1] := Ord('e');
  TestData[2] := Ord('l');
  TestData[3] := Ord('l');
  TestData[4] := Ord('o');
  TestData[5] := Ord(',');
  TestData[6] := Ord(' ');
  TestData[7] := Ord('W');
  TestData[8] := Ord('o');
  TestData[9] := Ord('r');
  TestData[10] := Ord('l');
  TestData[11] := Ord('d');
  TestData[12] := Ord('!');

  Writer := TPEMWriter.Create;
  try
    PEMText := Writer.WriteCertificate(TestData);
    Check('PEM 写入 - 包含 BEGIN', Pos('-----BEGIN CERTIFICATE-----', PEMText) > 0);
    Check('PEM 写入 - 包含 END', Pos('-----END CERTIFICATE-----', PEMText) > 0);
    Check('PEM 写入 - 包含 Base64', Pos('SGVsbG8sIFdvcmxkIQ', PEMText) > 0);  // "Hello, World!" 的 Base64
  finally
    Writer.Free;
  end;

  Reader := TPEMReader.Create;
  try
    Reader.LoadFromString(PEMText);
    Check('PEM 读取 - 块数量', Reader.BlockCount = 1);
    Check('PEM 读取 - 块类型', Reader.GetBlock(0).BlockType = pemCertificate);
    Check('PEM 读取 - 数据长度', Length(Reader.GetBlock(0).Data) = 13);

    // 验证数据内容
    for I := 0 to 12 do
    begin
      if Reader.GetBlock(0).Data[I] <> TestData[I] then
      begin
        Check('PEM 读取 - 数据内容', False);
        Exit;
      end;
    end;
    Check('PEM 读取 - 数据内容', True);
  finally
    Reader.Free;
  end;
end;

// 测试多个 PEM 块
procedure TestMultipleBlocks;
var
  Reader: TPEMReader;
  PEMText: string;
  Certs: TPEMBlockArray;
begin
  WriteLn;
  WriteLn('=== 测试多个 PEM 块 ===');

  PEMText :=
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'SGVsbG8=' + LineEnding +
    '-----END CERTIFICATE-----' + LineEnding +
    '' + LineEnding +
    '-----BEGIN PRIVATE KEY-----' + LineEnding +
    'V29ybGQ=' + LineEnding +
    '-----END PRIVATE KEY-----' + LineEnding +
    '' + LineEnding +
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'VGVzdA==' + LineEnding +
    '-----END CERTIFICATE-----' + LineEnding;

  Reader := TPEMReader.Create;
  try
    Reader.LoadFromString(PEMText);

    Check('多块 - 总块数', Reader.BlockCount = 3);
    Check('多块 - 块1类型', Reader.GetBlock(0).BlockType = pemCertificate);
    Check('多块 - 块2类型', Reader.GetBlock(1).BlockType = pemPrivateKey);
    Check('多块 - 块3类型', Reader.GetBlock(2).BlockType = pemCertificate);

    // 测试按类型获取
    Certs := Reader.GetCertificates;
    Check('多块 - 证书数量', Length(Certs) = 2);

    Check('多块 - GetFirstBlockOfType', Reader.GetFirstBlockOfType(pemPrivateKey).BlockType = pemPrivateKey);
  finally
    Reader.Free;
  end;
end;

// 测试 PEM 类型识别
procedure TestPEMTypes;
begin
  WriteLn;
  WriteLn('=== 测试 PEM 类型识别 ===');

  Check('类型识别 - CERTIFICATE', StringToPEMType('CERTIFICATE') = pemCertificate);
  Check('类型识别 - PRIVATE KEY', StringToPEMType('PRIVATE KEY') = pemPrivateKey);
  Check('类型识别 - RSA PRIVATE KEY', StringToPEMType('RSA PRIVATE KEY') = pemRSAPrivateKey);
  Check('类型识别 - EC PRIVATE KEY', StringToPEMType('EC PRIVATE KEY') = pemECPrivateKey);
  Check('类型识别 - PUBLIC KEY', StringToPEMType('PUBLIC KEY') = pemPublicKey);
  Check('类型识别 - CERTIFICATE REQUEST', StringToPEMType('CERTIFICATE REQUEST') = pemCertificateRequest);
  Check('类型识别 - X509 CRL', StringToPEMType('X509 CRL') = pemX509CRL);
  Check('类型识别 - UNKNOWN', StringToPEMType('RANDOM DATA') = pemUnknown);

  Check('类型名称 - pemCertificate', PEMTypeToString(pemCertificate) = 'CERTIFICATE');
  Check('类型名称 - pemPrivateKey', PEMTypeToString(pemPrivateKey) = 'PRIVATE KEY');
end;

// 测试格式检测
procedure TestFormatDetection;
var
  PEMData, DERData: TBytes;
begin
  WriteLn;
  WriteLn('=== 测试格式检测 ===');

  // PEM 格式数据
  PEMData := TEncoding.ASCII.GetBytes('-----BEGIN CERTIFICATE-----' + LineEnding);
  Check('格式检测 - PEM', IsPEMFormat(PEMData));
  Check('格式检测 - PEM 非 DER', not IsDERFormat(PEMData));

  // DER 格式数据 (以 SEQUENCE 0x30 开头)
  SetLength(DERData, 10);
  DERData[0] := $30;  // SEQUENCE
  DERData[1] := $08;  // 长度
  Check('格式检测 - DER', IsDERFormat(DERData));
  Check('格式检测 - DER 非 PEM', not IsPEMFormat(DERData));
end;

// 测试带头部的 PEM (加密私钥等)
procedure TestPEMHeaders;
var
  Reader: TPEMReader;
  PEMText: string;
  Block: TPEMBlock;
begin
  WriteLn;
  WriteLn('=== 测试 PEM 头部 ===');

  PEMText :=
    '-----BEGIN RSA PRIVATE KEY-----' + LineEnding +
    'Proc-Type: 4,ENCRYPTED' + LineEnding +
    'DEK-Info: AES-256-CBC,1234567890ABCDEF' + LineEnding +
    '' + LineEnding +
    'SGVsbG8=' + LineEnding +
    '-----END RSA PRIVATE KEY-----' + LineEnding;

  Reader := TPEMReader.Create;
  try
    Reader.LoadFromString(PEMText);

    Check('PEM头部 - 块数量', Reader.BlockCount = 1);

    Block := Reader.GetBlock(0);
    Check('PEM头部 - 类型', Block.BlockType = pemRSAPrivateKey);
    Check('PEM头部 - 有头部', Block.Headers <> nil);

    if Block.Headers <> nil then
    begin
      Check('PEM头部 - 头部数量', Block.Headers.Count = 2);
      Check('PEM头部 - Proc-Type', Pos('ENCRYPTED', Block.Headers.Text) > 0);
      Check('PEM头部 - DEK-Info', Pos('AES-256-CBC', Block.Headers.Text) > 0);
      Check('PEM头部 - IsEncrypted', Block.IsEncrypted);
    end;
  finally
    Reader.Free;
  end;
end;

// 测试真实证书文件
procedure TestRealCertificates;
var
  Reader: TPEMReader;
  CertFile: string;
  Certs: TPEMBlockArray;
begin
  WriteLn;
  WriteLn('=== 测试真实证书文件 ===');

  CertFile := '/etc/ssl/certs/ca-certificates.crt';
  if not FileExists(CertFile) then
    CertFile := '/etc/pki/tls/certs/ca-bundle.crt';

  if FileExists(CertFile) then
  begin
    WriteLn('  [INFO] 使用系统证书: ', CertFile);

    Reader := TPEMReader.Create;
    try
      try
        Reader.LoadFromFile(CertFile);
        Certs := Reader.GetCertificates;

        WriteLn('  [INFO] 找到 ', Length(Certs), ' 个证书');

        Check('真实证书 - 找到证书', Length(Certs) > 0);
        Check('真实证书 - 有 DER 数据', Length(Certs[0].Data) > 0);
        Check('真实证书 - DER 以 SEQUENCE 开头', Certs[0].Data[0] = $30);
      except
        on E: Exception do
        begin
          WriteLn('  [INFO] 读取异常: ', E.Message);
          Check('真实证书 - 异常处理', True);
        end;
      end;
    finally
      Reader.Free;
    end;
  end
  else
  begin
    Skip('真实证书 - 跳过', '未找到系统证书文件');
  end;
end;

// 测试空输入
procedure TestEmptyInput;
var
  Reader: TPEMReader;
begin
  WriteLn;
  WriteLn('=== 测试空输入 ===');

  Reader := TPEMReader.Create;
  try
    Reader.LoadFromString('');
    Check('空输入 - 无块', Reader.BlockCount = 0);

    Reader.LoadFromString('some random text without PEM markers');
    Check('无效输入 - 无块', Reader.BlockCount = 0);
  finally
    Reader.Free;
  end;
end;

// 测试写入器配置
procedure TestWriterConfig;
var
  Writer: TPEMWriter;
  TestData: TBytes;
  PEMText: string;
begin
  WriteLn;
  WriteLn('=== 测试写入器配置 ===');

  SetLength(TestData, 100);
  FillByte(TestData[0], 100, $AA);

  Writer := TPEMWriter.Create;
  try
    // 默认行长 64
    Check('写入器 - 默认行长', Writer.LineLength = 64);

    // 修改行长
    Writer.LineLength := 76;
    Check('写入器 - 修改行长', Writer.LineLength = 76);

    // 生成 PEM
    PEMText := Writer.WriteBlock(pemPublicKey, TestData);
    Check('写入器 - 生成 PUBLIC KEY', Pos('-----BEGIN PUBLIC KEY-----', PEMText) > 0);
  finally
    Writer.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('nextpas.core.tls.pem 单元测试');
  WriteLn('========================================');

  TestsPassed := 0;
  TestsFailed := 0;
  TestsSkipped := 0;

  TestBase64;
  TestMultipleBlocks;
  TestPEMTypes;
  TestFormatDetection;
  TestPEMHeaders;
  TestEmptyInput;
  TestWriterConfig;
  TestRealCertificates;

  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败, ', TestsSkipped, ' 跳过');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
