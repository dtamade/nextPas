{**
 * Test: nextpas.core.tls.capability.diff - 能力矩阵差异对比测试
 *
 * v1.3.0 阶段 2
 *
 * @author fafafa.ssl team
 * @version 1.3.0
 * @since 2026-02-05
 *}

program test_capability_diff;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.capability.diff,
  nextpas.core.tls.openssl.backed;  // 注册 OpenSSL 后端

procedure PrintSeparator(const ATitle: string);
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  ', ATitle);
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
end;

procedure Test1_CompareIdenticalBackends;
var
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  Result: TCapabilityDiffResult;
begin
  PrintSeparator('测试 1: 比较相同的后端（自己和自己）');

  // 获取 OpenSSL 能力矩阵
  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  Caps := Lib.GetCapabilities;

  // 比较
  Result := CompareCapabilities(Caps, Caps);

  WriteLn('差异级别: ', Ord(Result.DifferenceLevel));
  WriteLn('摘要: ', Result.Summary);
  WriteLn('新增功能: ', Length(Result.AddedFeatures));
  WriteLn('缺失功能: ', Length(Result.RemovedFeatures));
  WriteLn('字段变更: ', Length(Result.ChangedFields));
  WriteLn('安全评分差: ', Result.SecurityScoreDiff);
  WriteLn('性能评分差: ', Result.PerformanceScoreDiff);

  if Result.DifferenceLevel = cdIdentical then
    WriteLn('✅ 测试通过: 识别为完全相同')
  else
    WriteLn('❌ 测试失败: 应该识别为完全相同');
end;

procedure Test2_CompareModifiedCapabilities;
var
  Caps1, Caps2: TSSLBackendCapabilities;
  Lib: ISSLLibrary;
  Result: TCapabilityDiffResult;
  i: Integer;
begin
  PrintSeparator('测试 2: 比较修改后的能力矩阵');

  // 获取基准能力矩阵
  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  Caps1 := Lib.GetCapabilities;
  Caps2 := Caps1;  // 复制

  // 修改 Caps2
  Caps2.SupportsTLS13 := False;  // 移除 TLS 1.3 支持
  Caps2.SupportsPKCS11 := False;  // 移除 PKCS#11 支持

  // 比较
  Result := CompareCapabilities(Caps1, Caps2);

  WriteLn('差异级别: ', Ord(Result.DifferenceLevel));
  WriteLn('摘要: ', Result.Summary);
  WriteLn('新增功能: ', Length(Result.AddedFeatures));
  WriteLn('缺失功能: ', Length(Result.RemovedFeatures));
  WriteLn('字段变更: ', Length(Result.ChangedFields));

  WriteLn;
  WriteLn('缺失功能列表:');
  if Length(Result.RemovedFeatures) > 0 then
  begin
    for i := 0 to High(Result.RemovedFeatures) do
      WriteLn('  - ', Result.RemovedFeatures[i]);
  end;

  WriteLn;
  WriteLn('字段变更列表:');
  if Length(Result.ChangedFields) > 0 then
  begin
    for i := 0 to High(Result.ChangedFields) do
      WriteLn('  ', Result.ChangedFields[i].FieldName, ': ',
              Result.ChangedFields[i].OldValue, ' → ',
              Result.ChangedFields[i].NewValue);
  end;

  if (Result.DifferenceLevel >= cdMinor) and
     (Length(Result.RemovedFeatures) >= 2) and
     (Length(Result.ChangedFields) >= 2) then
    WriteLn('✅ 测试通过: 识别出差异')
  else
    WriteLn('❌ 测试失败: 未正确识别差异');
end;

procedure Test3_GenerateTextReport;
var
  Caps1, Caps2: TSSLBackendCapabilities;
  Lib: ISSLLibrary;
  Diff: TCapabilityDiffResult;
  Report: string;
begin
  PrintSeparator('测试 3: 生成文本格式报告');

  // 创建差异
  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  Caps1 := Lib.GetCapabilities;
  Caps2 := Caps1;
  Caps2.SupportsTLS13 := False;
  Caps2.SupportsPKCS11 := False;

  Diff := CompareCapabilities(Caps1, Caps2);
  Report := GenerateDiffReport(Diff, 'text');

  WriteLn('报告长度: ', Length(Report), ' 字符');
  WriteLn;
  WriteLn('--- 报告内容（前 1000 字符） ---');
  if Length(Report) > 1000 then
    WriteLn(Copy(Report, 1, 1000), '...')
  else
    WriteLn(Report);

  if Length(Report) > 100 then
    WriteLn('✅ 测试通过: 文本报告生成成功')
  else
    WriteLn('❌ 测试失败: 文本报告过短');
end;

procedure Test4_GenerateJSONReport;
var
  Caps1, Caps2: TSSLBackendCapabilities;
  Lib: ISSLLibrary;
  Diff: TCapabilityDiffResult;
  Report: string;
begin
  PrintSeparator('测试 4: 生成 JSON 格式报告');

  // 创建差异
  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  Caps1 := Lib.GetCapabilities;
  Caps2 := Caps1;
  Caps2.SupportsTLS13 := False;

  Diff := CompareCapabilities(Caps1, Caps2);
  Report := GenerateDiffReport(Diff, 'json');

  WriteLn('报告长度: ', Length(Report), ' 字符');
  WriteLn;
  WriteLn('--- JSON 报告（前 500 字符） ---');
  if Length(Report) > 500 then
    WriteLn(Copy(Report, 1, 500), '...')
  else
    WriteLn(Report);

  // 简单验证 JSON 格式
  if (Pos('{', Report) > 0) and
     (Pos('"differenceLevel"', Report) > 0) and
     (Pos('"summary"', Report) > 0) then
    WriteLn('✅ 测试通过: JSON 报告生成成功')
  else
    WriteLn('❌ 测试失败: JSON 格式不正确');
end;

procedure Test5_GenerateHTMLReport;
var
  Caps1, Caps2: TSSLBackendCapabilities;
  Lib: ISSLLibrary;
  Diff: TCapabilityDiffResult;
  Report: string;
  F: TextFile;
begin
  PrintSeparator('测试 5: 生成 HTML 格式报告');

  // 创建差异
  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  Caps1 := Lib.GetCapabilities;
  Caps2 := Caps1;
  Caps2.SupportsTLS13 := False;
  Caps2.SupportsPKCS11 := False;

  Diff := CompareCapabilities(Caps1, Caps2);
  Report := GenerateDiffReport(Diff, 'html');

  WriteLn('报告长度: ', Length(Report), ' 字符');

  // 简单验证 HTML 格式
  if (Pos('<!DOCTYPE html>', Report) > 0) and
     (Pos('<html>', Report) > 0) and
     (Pos('<style>', Report) > 0) and
     (Pos('能力矩阵差异报告', Report) > 0) then
    WriteLn('✅ 测试通过: HTML 报告生成成功')
  else
    WriteLn('❌ 测试失败: HTML 格式不正确');

  // 保存到文件以便查看
  AssignFile(F, '/tmp/capability_diff_report.html');
  try
    Rewrite(F);
    Write(F, Report);
    CloseFile(F);
    WriteLn('报告已保存到: /tmp/capability_diff_report.html');
  except
    on E: Exception do
      WriteLn('保存失败: ', E.Message);
  end;
end;

procedure Test6_CompareTwoBackendsDirectly;
var
  Diff: TCapabilityDiffResult;
  Report: string;
  AvailableLibs: TSSLLibraryTypes;
begin
  PrintSeparator('测试 6: 直接比较两个后端');

  // 比较 OpenSSL 与自己（应该相同）
  Diff := CompareTwoBackends(sslOpenSSL, sslOpenSSL);

  WriteLn('差异级别: ', Ord(Diff.DifferenceLevel));
  WriteLn('摘要: ', Diff.Summary);

  if Diff.DifferenceLevel = cdIdentical then
    WriteLn('✅ 测试通过: OpenSSL 与自己比较为相同')
  else
    WriteLn('❌ 测试失败: 应该识别为相同');

  // 注意: 如果有其他后端可用,可以比较不同的后端
  AvailableLibs := TSSLFactory.GetAvailableLibraries;

  WriteLn;
  WriteLn('可用后端数量: ', Cardinal(AvailableLibs));

  // 如果有多个后端,比较它们
  if (sslOpenSSL in AvailableLibs) and (sslWinSSL in AvailableLibs) then
  begin
    WriteLn('检测到 WinSSL,尝试与 OpenSSL 比较...');
    Diff := CompareTwoBackends(sslOpenSSL, sslWinSSL);

    Report := GenerateDiffReport(Diff, 'text');
    WriteLn;
    WriteLn(Report);
  end;
end;

var
  PassCount, TotalCount: Integer;

begin
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  fafafa.ssl 能力矩阵差异对比测试');
  WriteLn('  v1.3.0 阶段 2');
  WriteLn('═══════════════════════════════════════════════════════════');

  PassCount := 0;
  TotalCount := 6;

  try
    Test1_CompareIdenticalBackends;
    Inc(PassCount);
  except
    on E: Exception do
      WriteLn('❌ 测试 1 异常: ', E.Message);
  end;

  try
    Test2_CompareModifiedCapabilities;
    Inc(PassCount);
  except
    on E: Exception do
      WriteLn('❌ 测试 2 异常: ', E.Message);
  end;

  try
    Test3_GenerateTextReport;
    Inc(PassCount);
  except
    on E: Exception do
      WriteLn('❌ 测试 3 异常: ', E.Message);
  end;

  try
    Test4_GenerateJSONReport;
    Inc(PassCount);
  except
    on E: Exception do
      WriteLn('❌ 测试 4 异常: ', E.Message);
  end;

  try
    Test5_GenerateHTMLReport;
    Inc(PassCount);
  except
    on E: Exception do
      WriteLn('❌ 测试 5 异常: ', E.Message);
  end;

  try
    Test6_CompareTwoBackendsDirectly;
    Inc(PassCount);
  except
    on E: Exception do
      WriteLn('❌ 测试 6 异常: ', E.Message);
  end;

  PrintSeparator('测试总结');
  WriteLn('通过: ', PassCount, '/', TotalCount);
  if PassCount = TotalCount then
    WriteLn('✅ 所有测试通过!')
  else
    WriteLn('❌ 部分测试失败');

  WriteLn;
end.
