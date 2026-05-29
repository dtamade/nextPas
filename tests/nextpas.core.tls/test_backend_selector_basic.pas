{**
 * 测试程序: 后端自动选择基础测试
 *
 * v1.3.0 新增功能
 *
 * 测试场景:
 * 1. 使用默认需求选择后端
 * 2. 安全优先选择
 * 3. 性能优先选择
 * 4. 兼容性优先选择
 * 5. 选择多个后端并排序
 *}

program test_backend_selector_basic;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.openssl.backed;  // 注册 OpenSSL 后端

procedure TestDefaultRequirements;
var
  Requirements: TSSLRequirements;
  SelectedType: TSSLLibraryType;
  MatchScore: Integer;
begin
  WriteLn('=== 测试 1: 默认需求选择后端 ===');

  Requirements := CreateDefaultRequirements(optBalanced);

  if SelectBestBackend(Requirements, SelectedType, MatchScore) then
  begin
    WriteLn('✅ 选择成功');
    WriteLn('  后端类型: ', Ord(SelectedType));
    WriteLn('  匹配分数: ', MatchScore, '/100');
  end
  else
    WriteLn('❌ 选择失败');

  WriteLn;
end;

procedure TestSecurityFirstRequirements;
var
  Requirements: TSSLRequirements;
  SelectedType: TSSLLibraryType;
  MatchScore: Integer;
begin
  WriteLn('=== 测试 2: 安全优先需求 ===');

  Requirements := CreateSecurityFirstRequirements;

  if SelectBestBackend(Requirements, SelectedType, MatchScore) then
  begin
    WriteLn('✅ 选择成功');
    WriteLn('  后端类型: ', Ord(SelectedType));
    WriteLn('  匹配分数: ', MatchScore, '/100');
    WriteLn('  最低安全评分要求: ', Requirements.MinSecurityScore);
  end
  else
    WriteLn('❌ 选择失败');

  WriteLn;
end;

procedure TestPerformanceFirstRequirements;
var
  Requirements: TSSLRequirements;
  SelectedType: TSSLLibraryType;
  MatchScore: Integer;
begin
  WriteLn('=== 测试 3: 性能优先需求 ===');

  Requirements := CreatePerformanceFirstRequirements;

  if SelectBestBackend(Requirements, SelectedType, MatchScore) then
  begin
    WriteLn('✅ 选择成功');
    WriteLn('  后端类型: ', Ord(SelectedType));
    WriteLn('  匹配分数: ', MatchScore, '/100');
    WriteLn('  最低性能评分要求: ', Requirements.MinPerformanceScore);
  end
  else
    WriteLn('❌ 选择失败');

  WriteLn;
end;

procedure TestCompatibilityFirstRequirements;
var
  Requirements: TSSLRequirements;
  SelectedType: TSSLLibraryType;
  MatchScore: Integer;
begin
  WriteLn('=== 测试 4: 兼容性优先需求 ===');

  Requirements := CreateCompatibilityFirstRequirements;

  if SelectBestBackend(Requirements, SelectedType, MatchScore) then
  begin
    WriteLn('✅ 选择成功');
    WriteLn('  后端类型: ', Ord(SelectedType));
    WriteLn('  匹配分数: ', MatchScore, '/100');
    WriteLn('  最低兼容性要求: ', Requirements.MinCompatibilityLevel);
  end
  else
    WriteLn('❌ 选择失败');

  WriteLn;
end;

procedure TestSelectMultipleBackends;
var
  Requirements: TSSLRequirements;
  Results: TSSLBackendMatchArray;
  i: Integer;
begin
  WriteLn('=== 测试 5: 选择多个后端（排序） ===');

  Requirements := CreateDefaultRequirements(optBalanced);
  Results := SelectBestBackends(Requirements, 5);

  WriteLn('找到 ', Length(Results), ' 个匹配的后端:');
  WriteLn;

  for i := 0 to High(Results) do
  begin
    WriteLn('  #', i + 1, ': ', Results[i].BackendName);
    WriteLn('     匹配分数: ', Results[i].MatchScore, '/100');
    WriteLn('     推荐原因: ', Results[i].RecommendationReason);
    WriteLn('     安全评分: ', Results[i].MatchDetails.SecurityScore, '/100');
    WriteLn('     性能评分: ', Results[i].MatchDetails.PerformanceScore, '/100');
    WriteLn;
  end;
end;

procedure TestRequirementsValidation;
var
  Requirements: TSSLRequirements;
  Errors: TStringArray;
  i: Integer;
  IsValid: Boolean;
begin
  WriteLn('=== 测试 6: 需求验证 ===');

  // 创建一个无效的需求（没有协议版本）
  FillChar(Requirements, SizeOf(Requirements), 0);
  Requirements.MinSecurityScore := -10;  // 无效范围

  IsValid := ValidateRequirements(Requirements, Errors);

  if not IsValid then
  begin
    WriteLn('✅ 成功检测到无效需求');
    WriteLn('  错误数量: ', Length(Errors));
    for i := 0 to High(Errors) do
      WriteLn('  错误 ', i + 1, ': ', Errors[i]);
  end
  else
    WriteLn('❌ 未能检测到无效需求');

  WriteLn;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║  后端自动选择基础测试 (v1.3.0)                            ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    TestDefaultRequirements;
    TestSecurityFirstRequirements;
    TestPerformanceFirstRequirements;
    TestCompatibilityFirstRequirements;
    TestSelectMultipleBackends;
    TestRequirementsValidation;

    WriteLn('════════════════════════════════════════════════════════════');
    WriteLn('✅ 所有测试完成');
    WriteLn('════════════════════════════════════════════════════════════');
  except
    on E: Exception do
    begin
      WriteLn('❌ 测试失败: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
