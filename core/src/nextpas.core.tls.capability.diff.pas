{**
 * Unit: nextpas.core.tls.capability.diff
 * Purpose: 能力矩阵差异对比工具
 *
 * v1.3.0 阶段 2
 *
 * @author fafafa.ssl team
 * @version 1.3.0
 * @since 2026-02-05
 *}

unit nextpas.core.tls.capability.diff;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.tls.base;

type
  { TCapabilityDifference - 差异级别 }
  TCapabilityDifference = (
    cdIdentical,      // 完全相同
    cdMinor,          // 小差异
    cdMajor,          // 大差异
    cdIncompatible    // 不兼容
  );

  { TCapabilityFieldChange - 字段变更 }
  TCapabilityFieldChange = record
    FieldName: string;
    OldValue: string;
    NewValue: string;
  end;

  { TCapabilityFieldChangeArray - 字段变更数组 }
  TCapabilityFieldChangeArray = array of TCapabilityFieldChange;

  { TCapabilityDiffResult - 差异对比结果 }
  TCapabilityDiffResult = record
    DifferenceLevel: TCapabilityDifference;
    AddedFeatures: TStringArray;       // Backend2 新增的功能
    RemovedFeatures: TStringArray;     // Backend2 缺失的功能
    ChangedFields: TCapabilityFieldChangeArray;  // 变更的字段
    SecurityScoreDiff: Integer;        // 安全评分差异
    PerformanceScoreDiff: Integer;     // 性能评分差异
    CompatibilityLevelDiff: Integer;   // 兼容性级别差异
    Summary: string;                   // 差异摘要
  end;

{ CompareCapabilities - 对比两个能力矩阵

  @param ACaps1 第一个能力矩阵（基准）
  @param ACaps2 第二个能力矩阵（对比目标）
  @return 差异对比结果
}
function CompareCapabilities(
  const ACaps1, ACaps2: TSSLBackendCapabilities
): TCapabilityDiffResult;

{ GenerateDiffReport - 生成差异报告

  @param ADiff 差异对比结果
  @param AFormat 格式：text/json/html
  @return 格式化的报告字符串
}
function GenerateDiffReport(
  const ADiff: TCapabilityDiffResult;
  const AFormat: string = 'text'
): string;

{ CompareTwoBackends - 直接对比两个后端

  @param AType1 第一个后端类型
  @param AType2 第二个后端类型
  @return 差异对比结果
}
function CompareTwoBackends(
  AType1, AType2: TSSLLibraryType
): TCapabilityDiffResult;

implementation

uses
  nextpas.core.text.strings,
    nextpas.core.tls.factory,
  fpjson, jsonparser;

{ 内部辅助函数 }

procedure AddFeature(var AArray: TStringArray; const AFeature: string);
begin
  SetLength(AArray, Length(AArray) + 1);
  AArray[High(AArray)] := AFeature;
end;

procedure AddFieldChange(
  var AArray: TCapabilityFieldChangeArray;
  const AFieldName, AOldValue, ANewValue: string
);
var
  Change: TCapabilityFieldChange;
begin
  Change.FieldName := AFieldName;
  Change.OldValue := AOldValue;
  Change.NewValue := ANewValue;
  SetLength(AArray, Length(AArray) + 1);
  AArray[High(AArray)] := Change;
end;

function BoolToStr(AValue: Boolean): string;
begin
  if AValue then
    Result := 'True'
  else
    Result := 'False';
end;

function FeatureLevelPresent(ALevel: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ALevel <> sslSupportNone;
end;

{$WARN 6018 OFF}
function SupportLevelToStr(ALevel: TSSLFeatureSupportLevel): string;
begin
  case ALevel of
    sslSupportNone: Result := 'None';
    sslSupportExperimental: Result := 'Experimental';
    sslSupportStable: Result := 'Stable';
    sslSupportDeprecated: Result := 'Deprecated';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

{$WARN 6018 OFF}
function ImplTypeToStr(AType: TSSLBackendImplType): string;
begin
  case AType of
    sslImplNative: Result := 'Native';
    sslImplCLibrary: Result := 'CLibrary';
    sslImplOSNative: Result := 'OSNative';
    sslImplHybrid: Result := 'Hybrid';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

procedure CompareProjectedCapability(
  var ADiff: TCapabilityDiffResult;
  var AChanges: Integer;
  const ALevelFieldName,
        ALegacyFieldName,
        AFeatureName: string;
  const ALevel1, ALevel2: TSSLFeatureSupportLevel;
  const ALegacyBool1, ALegacyBool2: Boolean);
begin
  if ALevel1 <> ALevel2 then
  begin
    AddFieldChange(ADiff.ChangedFields, ALevelFieldName,
      SupportLevelToStr(ALevel1),
      SupportLevelToStr(ALevel2));
    Inc(AChanges);

    if FeatureLevelPresent(ALevel2) and not FeatureLevelPresent(ALevel1) then
      AddFeature(ADiff.AddedFeatures, AFeatureName)
    else if FeatureLevelPresent(ALevel1) and not FeatureLevelPresent(ALevel2) then
      AddFeature(ADiff.RemovedFeatures, AFeatureName);
    Exit;
  end;

  if ALegacyBool1 <> ALegacyBool2 then
  begin
    AddFieldChange(ADiff.ChangedFields, ALegacyFieldName,
      BoolToStr(ALegacyBool1),
      BoolToStr(ALegacyBool2));
    Inc(AChanges);

    if not FeatureLevelPresent(ALevel1) then
    begin
      if ALegacyBool2 and not ALegacyBool1 then
        AddFeature(ADiff.AddedFeatures, AFeatureName)
      else if ALegacyBool1 and not ALegacyBool2 then
        AddFeature(ADiff.RemovedFeatures, AFeatureName);
    end;
  end;
end;

procedure CompareSupportLevelCapability(
  var ADiff: TCapabilityDiffResult;
  var AChanges: Integer;
  const AFieldName,
        AFeatureName: string;
  const ALevel1, ALevel2: TSSLFeatureSupportLevel);
begin
  if ALevel1 <> ALevel2 then
  begin
    AddFieldChange(ADiff.ChangedFields, AFieldName,
      SupportLevelToStr(ALevel1),
      SupportLevelToStr(ALevel2));
    Inc(AChanges);

    if FeatureLevelPresent(ALevel2) and not FeatureLevelPresent(ALevel1) then
      AddFeature(ADiff.AddedFeatures, AFeatureName)
    else if FeatureLevelPresent(ALevel1) and not FeatureLevelPresent(ALevel2) then
      AddFeature(ADiff.RemovedFeatures, AFeatureName);
  end;
end;

{ CompareCapabilities }

function CompareCapabilities(
  const ACaps1, ACaps2: TSSLBackendCapabilities
): TCapabilityDiffResult;
var
  Changes: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  SetLength(Result.AddedFeatures, 0);
  SetLength(Result.RemovedFeatures, 0);
  SetLength(Result.ChangedFields, 0);
  Changes := 0;

  // 1. 比较后端实现类型
  if ACaps1.BackendImplType <> ACaps2.BackendImplType then
  begin
    AddFieldChange(Result.ChangedFields, 'BackendImplType',
      ImplTypeToStr(ACaps1.BackendImplType),
      ImplTypeToStr(ACaps2.BackendImplType));
    Inc(Changes);
  end;

  // 2. 比较协议支持
  if ACaps1.SupportsTLS13 <> ACaps2.SupportsTLS13 then
  begin
    AddFieldChange(Result.ChangedFields, 'SupportsTLS13',
      BoolToStr(ACaps1.SupportsTLS13),
      BoolToStr(ACaps2.SupportsTLS13));
    Inc(Changes);

    if ACaps2.SupportsTLS13 and not ACaps1.SupportsTLS13 then
      AddFeature(Result.AddedFeatures, 'TLS 1.3 support')
    else
      AddFeature(Result.RemovedFeatures, 'TLS 1.3 support');
  end;

  if ACaps1.SupportsDTLS <> ACaps2.SupportsDTLS then
  begin
    AddFieldChange(Result.ChangedFields, 'SupportsDTLS',
      BoolToStr(ACaps1.SupportsDTLS),
      BoolToStr(ACaps2.SupportsDTLS));
    Inc(Changes);
  end;

  // 3. 比较算法支持
  if ACaps1.SupportedCiphers <> ACaps2.SupportedCiphers then
  begin
    Inc(Changes);
    // 简化：只记录差异存在
    // Backend2 有 Backend1 没有的算法
    if not (ACaps2.SupportedCiphers <= ACaps1.SupportedCiphers) then
      AddFeature(Result.AddedFeatures, 'Additional cipher algorithms');
    // Backend1 有 Backend2 没有的算法
    if not (ACaps1.SupportedCiphers <= ACaps2.SupportedCiphers) then
      AddFeature(Result.RemovedFeatures, 'Some cipher algorithms');
  end;

  if ACaps1.SupportedHashes <> ACaps2.SupportedHashes then
  begin
    Inc(Changes);
    if not (ACaps2.SupportedHashes <= ACaps1.SupportedHashes) then
      AddFeature(Result.AddedFeatures, 'Additional hash algorithms');
    if not (ACaps1.SupportedHashes <= ACaps2.SupportedHashes) then
      AddFeature(Result.RemovedFeatures, 'Some hash algorithms');
  end;

  if ACaps1.SupportedKeyExchanges <> ACaps2.SupportedKeyExchanges then
  begin
    Inc(Changes);
    if not (ACaps2.SupportedKeyExchanges <= ACaps1.SupportedKeyExchanges) then
      AddFeature(Result.AddedFeatures, 'Additional key exchange algorithms');
    if not (ACaps1.SupportedKeyExchanges <= ACaps2.SupportedKeyExchanges) then
      AddFeature(Result.RemovedFeatures, 'Some key exchange algorithms');
  end;

  // 4. 比较功能支持（v1.2 support-level 为真相，legacy boolean 仅作兼容回退）
  CompareProjectedCapability(Result, Changes,
    'SNISupport', 'SupportsSNI', 'SNI support',
    ACaps1.SNISupport, ACaps2.SNISupport,
    ACaps1.SupportsSNI, ACaps2.SupportsSNI);
  CompareProjectedCapability(Result, Changes,
    'ALPNSupport', 'SupportsALPN', 'ALPN support',
    ACaps1.ALPNSupport, ACaps2.ALPNSupport,
    ACaps1.SupportsALPN, ACaps2.SupportsALPN);
  CompareProjectedCapability(Result, Changes,
    'OCSPStaplingSupport', 'SupportsOCSPStapling', 'OCSP stapling support',
    ACaps1.OCSPStaplingSupport, ACaps2.OCSPStaplingSupport,
    ACaps1.SupportsOCSPStapling, ACaps2.SupportsOCSPStapling);
  CompareProjectedCapability(Result, Changes,
    'CertTransparencySupport', 'SupportsCertificateTransparency',
    'Certificate transparency support',
    ACaps1.CertTransparencySupport, ACaps2.CertTransparencySupport,
    ACaps1.SupportsCertificateTransparency, ACaps2.SupportsCertificateTransparency);
  CompareProjectedCapability(Result, Changes,
    'SessionTicketsSupport', 'SupportsSessionTickets', 'Session tickets support',
    ACaps1.SessionTicketsSupport, ACaps2.SessionTicketsSupport,
    ACaps1.SupportsSessionTickets, ACaps2.SupportsSessionTickets);
  CompareSupportLevelCapability(Result, Changes,
    'SessionCacheSupport', 'Session cache support',
    ACaps1.SessionCacheSupport, ACaps2.SessionCacheSupport);
  CompareSupportLevelCapability(Result, Changes,
    'ZeroRTTSupport', '0-RTT support',
    ACaps1.ZeroRTTSupport, ACaps2.ZeroRTTSupport);
  CompareSupportLevelCapability(Result, Changes,
    'EarlyDataSupport', 'Early data support',
    ACaps1.EarlyDataSupport, ACaps2.EarlyDataSupport);
  CompareSupportLevelCapability(Result, Changes,
    'RenegotiationSupport', 'Renegotiation support',
    ACaps1.RenegotiationSupport, ACaps2.RenegotiationSupport);
  CompareSupportLevelCapability(Result, Changes,
    'PostHandshakeAuthSupport', 'Post-handshake authentication support',
    ACaps1.PostHandshakeAuthSupport, ACaps2.PostHandshakeAuthSupport);

  // 5. 比较平台特性
  if ACaps1.SupportsPKCS11 <> ACaps2.SupportsPKCS11 then
  begin
    AddFieldChange(Result.ChangedFields, 'SupportsPKCS11',
      BoolToStr(ACaps1.SupportsPKCS11),
      BoolToStr(ACaps2.SupportsPKCS11));
    Inc(Changes);

    if ACaps2.SupportsPKCS11 and not ACaps1.SupportsPKCS11 then
      AddFeature(Result.AddedFeatures, 'PKCS#11 support')
    else
      AddFeature(Result.RemovedFeatures, 'PKCS#11 support');
  end;

  if ACaps1.SupportsTPM <> ACaps2.SupportsTPM then
  begin
    AddFieldChange(Result.ChangedFields, 'SupportsTPM',
      BoolToStr(ACaps1.SupportsTPM),
      BoolToStr(ACaps2.SupportsTPM));
    Inc(Changes);

    if ACaps2.SupportsTPM and not ACaps1.SupportsTPM then
      AddFeature(Result.AddedFeatures, 'TPM support')
    else
      AddFeature(Result.RemovedFeatures, 'TPM support');
  end;

  if ACaps1.HasHardwareAcceleration <> ACaps2.HasHardwareAcceleration then
  begin
    AddFieldChange(Result.ChangedFields, 'HasHardwareAcceleration',
      BoolToStr(ACaps1.HasHardwareAcceleration),
      BoolToStr(ACaps2.HasHardwareAcceleration));
    Inc(Changes);

    if ACaps2.HasHardwareAcceleration and not ACaps1.HasHardwareAcceleration then
      AddFeature(Result.AddedFeatures, 'Hardware acceleration')
    else
      AddFeature(Result.RemovedFeatures, 'Hardware acceleration');
  end;

  if ACaps1.SupportsFIPSMode <> ACaps2.SupportsFIPSMode then
  begin
    AddFieldChange(Result.ChangedFields, 'SupportsFIPSMode',
      BoolToStr(ACaps1.SupportsFIPSMode),
      BoolToStr(ACaps2.SupportsFIPSMode));
    Inc(Changes);

    if ACaps2.SupportsFIPSMode and not ACaps1.SupportsFIPSMode then
      AddFeature(Result.AddedFeatures, 'FIPS 140-2 mode')
    else
      AddFeature(Result.RemovedFeatures, 'FIPS 140-2 mode');
  end;

  // 6. 计算评分差异
  Result.SecurityScoreDiff := GetSecurityScore(ACaps2) - GetSecurityScore(ACaps1);
  Result.PerformanceScoreDiff := GetPerformanceScore(ACaps2) - GetPerformanceScore(ACaps1);
  Result.CompatibilityLevelDiff := ACaps2.CompatibilityLevel - ACaps1.CompatibilityLevel;

  // 7. 确定差异级别
  if (Length(Result.AddedFeatures) = 0) and
    (Length(Result.RemovedFeatures) = 0) and
    (Length(Result.ChangedFields) = 0) and
    (Abs(Result.SecurityScoreDiff) < 5) and
    (Abs(Result.PerformanceScoreDiff) < 5) then
  begin
    Result.DifferenceLevel := cdIdentical;
    Result.Summary := '两个后端完全相同';
  end
  else if (Length(Result.RemovedFeatures) > 3) or
          (Abs(Result.SecurityScoreDiff) > 30) then
  begin
    Result.DifferenceLevel := cdIncompatible;
    Result.Summary := nextpas.core.text.conv.Format('重大差异：%d 个功能缺失，安全评分差 %d 分',
      [Length(Result.RemovedFeatures), Abs(Result.SecurityScoreDiff)]);
  end
  else if (Length(Result.RemovedFeatures) > 0) or
          (Abs(Result.SecurityScoreDiff) > 20) or
          (Changes > 5) then
  begin
    Result.DifferenceLevel := cdMajor;
    Result.Summary := nextpas.core.text.conv.Format('较大差异：%d 处变更', [Changes]);
  end
  else
  begin
    Result.DifferenceLevel := cdMinor;
    Result.Summary := nextpas.core.text.conv.Format('轻微差异：%d 处变更', [Changes]);
  end;
end;

{ GenerateDiffReport - Text format }

function GenerateTextReport(const ADiff: TCapabilityDiffResult): string;
var
  Report: TStringArray;
  i: Integer;
begin
  try
    Report.Add('════════════════════════════════════════════════════════════');
    Report.Add('  能力矩阵差异报告');
    Report.Add('════════════════════════════════════════════════════════════');
    Report.Add('');

    // 差异级别
    Report.Add('差异级别: ' + ADiff.Summary);
    Report.Add('');

    // 评分差异
    Report.Add('评分变化:');
    Report.Add(nextpas.core.text.conv.Format('  安全评分: %+d', [ADiff.SecurityScoreDiff]));
    Report.Add(nextpas.core.text.conv.Format('  性能评分: %+d', [ADiff.PerformanceScoreDiff]));
    Report.Add(nextpas.core.text.conv.Format('  兼容性级别: %+d', [ADiff.CompatibilityLevelDiff]));
    Report.Add('');

    // 新增功能
    if Length(ADiff.AddedFeatures) > 0 then
    begin
      Report.Add(nextpas.core.text.conv.Format('新增功能 (%d):' , [Length(ADiff.AddedFeatures)]));
      for i := 0 to High(ADiff.AddedFeatures) do
        Report.Add('  + ' + ADiff.AddedFeatures[i]);
      Report.Add('');
    end;

    // 缺失功能
    if Length(ADiff.RemovedFeatures) > 0 then
    begin
      Report.Add(nextpas.core.text.conv.Format('缺失功能 (%d):', [Length(ADiff.RemovedFeatures)]));
      for i := 0 to High(ADiff.RemovedFeatures) do
        Report.Add('  - ' + ADiff.RemovedFeatures[i]);
      Report.Add('');
    end;

    // 字段变更
    if Length(ADiff.ChangedFields) > 0 then
    begin
      Report.Add(nextpas.core.text.conv.Format('字段变更 (%d):', [Length(ADiff.ChangedFields)]));
      for i := 0 to High(ADiff.ChangedFields) do
      begin
        Report.Add(nextpas.core.text.conv.Format('  • %s:', [ADiff.ChangedFields[i].FieldName]));
        Report.Add(nextpas.core.text.conv.Format('      %s → %s',
          [ADiff.ChangedFields[i].OldValue, ADiff.ChangedFields[i].NewValue]));
      end;
      Report.Add('');
    end;

    Report.Add('════════════════════════════════════════════════════════════');

    Result := Report.Text;
  finally
  end;
end;

{ GenerateDiffReport - JSON format }

function GenerateJSONReport(const ADiff: TCapabilityDiffResult): string;
var
  Root, Scores, Added, Removed, Changed: TJSONObject;
  AddedArray, RemovedArray, ChangedArray: TJSONArray;
  FieldObj: TJSONObject;
  i: Integer;
begin
  Root := TJSONObject.Create;
  try
    // 差异级别
    Root.Add('differenceLevel', Ord(ADiff.DifferenceLevel));
    Root.Add('summary', ADiff.Summary);

    // 评分差异
    Scores := TJSONObject.Create;
    Scores.Add('security', ADiff.SecurityScoreDiff);
    Scores.Add('performance', ADiff.PerformanceScoreDiff);
    Scores.Add('compatibility', ADiff.CompatibilityLevelDiff);
    Root.Add('scoreDiff', Scores);

    // 新增功能
    AddedArray := TJSONArray.Create;
    for i := 0 to High(ADiff.AddedFeatures) do
      AddedArray.Add(ADiff.AddedFeatures[i]);
    Root.Add('addedFeatures', AddedArray);

    // 缺失功能
    RemovedArray := TJSONArray.Create;
    for i := 0 to High(ADiff.RemovedFeatures) do
      RemovedArray.Add(ADiff.RemovedFeatures[i]);
    Root.Add('removedFeatures', RemovedArray);

    // 字段变更
    ChangedArray := TJSONArray.Create;
    for i := 0 to High(ADiff.ChangedFields) do
    begin
      FieldObj := TJSONObject.Create;
      FieldObj.Add('field', ADiff.ChangedFields[i].FieldName);
      FieldObj.Add('oldValue', ADiff.ChangedFields[i].OldValue);
      FieldObj.Add('newValue', ADiff.ChangedFields[i].NewValue);
      ChangedArray.Add(FieldObj);
    end;
    Root.Add('changedFields', ChangedArray);

    Result := Root.FormatJSON;
  finally
  end;
end;

{ GenerateDiffReport - HTML format }

function GenerateHTMLReport(const ADiff: TCapabilityDiffResult): string;
var
  HTML: TStringArray;
  i: Integer;
  LevelClass, LevelText: string;
begin
  try
    // 差异级别样式
    case ADiff.DifferenceLevel of
      cdIdentical:
      begin
        LevelClass := 'identical';
        LevelText := '✅ 完全相同';
      end;
      cdMinor:
      begin
        LevelClass := 'minor';
        LevelText := '⚠️ 轻微差异';
      end;
      cdMajor:
      begin
        LevelClass := 'major';
        LevelText := '⚠️ 较大差异';
      end;
      cdIncompatible:
      begin
        LevelClass := 'incompatible';
        LevelText := '❌ 不兼容';
      end;
    end;

    HTML.Add('<!DOCTYPE html>');
    HTML.Add('<html>');
    HTML.Add('<head>');
    HTML.Add('<meta charset="UTF-8">');
    HTML.Add('<title>能力矩阵差异报告</title>');
    HTML.Add('<style>');
    HTML.Add('body { font-family: sans-serif; margin: 20px; background: #f5f5f5; }');
    HTML.Add('.container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }');
    HTML.Add('h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }');
    HTML.Add('h2 { color: #555; margin-top: 30px; }');
    HTML.Add('.level { font-size: 24px; font-weight: bold; padding: 15px; border-radius: 5px; margin: 20px 0; }');
    HTML.Add('.identical { background: #d4edda; color: #155724; }');
    HTML.Add('.minor { background: #fff3cd; color: #856404; }');
    HTML.Add('.major { background: #f8d7da; color: #721c24; }');
    HTML.Add('.incompatible { background: #f8d7da; color: #721c24; border: 2px solid #721c24; }');
    HTML.Add('.score { display: flex; gap: 20px; margin: 20px 0; }');
    HTML.Add('.score-item { flex: 1; padding: 15px; border-radius: 5px; text-align: center; }');
    HTML.Add('.score-positive { background: #d4edda; color: #155724; }');
    HTML.Add('.score-negative { background: #f8d7da; color: #721c24; }');
    HTML.Add('.score-neutral { background: #e2e3e5; color: #383d41; }');
    HTML.Add('.feature-list { list-style: none; padding: 0; }');
    HTML.Add('.feature-list li { padding: 8px; margin: 5px 0; border-radius: 3px; }');
    HTML.Add('.added { background: #d4edda; color: #155724; }');
    HTML.Add('.removed { background: #f8d7da; color: #721c24; }');
    HTML.Add('.changed { background: #cfe2ff; color: #084298; padding: 10px; margin: 5px 0; border-radius: 3px; }');
    HTML.Add('.field-name { font-weight: bold; }');
    HTML.Add('.arrow { color: #666; margin: 0 10px; }');
    HTML.Add('</style>');
    HTML.Add('</head>');
    HTML.Add('<body>');
    HTML.Add('<div class="container">');
    HTML.Add('<h1>🔍 能力矩阵差异报告</h1>');

    // 差异级别
    HTML.Add(nextpas.core.text.conv.Format('<div class="level %s">%s</div>', [LevelClass, LevelText]));
    HTML.Add(nextpas.core.text.conv.Format('<p><strong>摘要:</strong> %s</p>', [ADiff.Summary]));

    // 评分差异
    HTML.Add('<h2>📊 评分变化</h2>');
    HTML.Add('<div class="score">');

    // 安全评分
    if ADiff.SecurityScoreDiff > 0 then
      HTML.Add(nextpas.core.text.conv.Format('<div class="score-item score-positive"><div>安全评分</div><div style="font-size:28px;">+%d</div></div>', [ADiff.SecurityScoreDiff]))
    else if ADiff.SecurityScoreDiff < 0 then
      HTML.Add(nextpas.core.text.conv.Format('<div class="score-item score-negative"><div>安全评分</div><div style="font-size:28px;">%d</div></div>', [ADiff.SecurityScoreDiff]))
    else
      HTML.Add('<div class="score-item score-neutral"><div>安全评分</div><div style="font-size:28px;">0</div></div>');

    // 性能评分
    if ADiff.PerformanceScoreDiff > 0 then
      HTML.Add(nextpas.core.text.conv.Format('<div class="score-item score-positive"><div>性能评分</div><div style="font-size:28px;">+%d</div></div>', [ADiff.PerformanceScoreDiff]))
    else if ADiff.PerformanceScoreDiff < 0 then
      HTML.Add(nextpas.core.text.conv.Format('<div class="score-item score-negative"><div>性能评分</div><div style="font-size:28px;">%d</div></div>', [ADiff.PerformanceScoreDiff]))
    else
      HTML.Add('<div class="score-item score-neutral"><div>性能评分</div><div style="font-size:28px;">0</div></div>');

    // 兼容性
    if ADiff.CompatibilityLevelDiff > 0 then
      HTML.Add(nextpas.core.text.conv.Format('<div class="score-item score-positive"><div>兼容性</div><div style="font-size:28px;">+%d</div></div>', [ADiff.CompatibilityLevelDiff]))
    else if ADiff.CompatibilityLevelDiff < 0 then
      HTML.Add(nextpas.core.text.conv.Format('<div class="score-item score-negative"><div>兼容性</div><div style="font-size:28px;">%d</div></div>', [ADiff.CompatibilityLevelDiff]))
    else
      HTML.Add('<div class="score-item score-neutral"><div>兼容性</div><div style="font-size:28px;">0</div></div>');

    HTML.Add('</div>');

    // 新增功能
    if Length(ADiff.AddedFeatures) > 0 then
    begin
      HTML.Add(nextpas.core.text.conv.Format('<h2>➕ 新增功能 (%d)</h2>', [Length(ADiff.AddedFeatures)]));
      HTML.Add('<ul class="feature-list">');
      for i := 0 to High(ADiff.AddedFeatures) do
        HTML.Add(nextpas.core.text.conv.Format('<li class="added">✅ %s</li>', [ADiff.AddedFeatures[i]]));
      HTML.Add('</ul>');
    end;

    // 缺失功能
    if Length(ADiff.RemovedFeatures) > 0 then
    begin
      HTML.Add(nextpas.core.text.conv.Format('<h2>➖ 缺失功能 (%d)</h2>', [Length(ADiff.RemovedFeatures)]));
      HTML.Add('<ul class="feature-list">');
      for i := 0 to High(ADiff.RemovedFeatures) do
        HTML.Add(nextpas.core.text.conv.Format('<li class="removed">❌ %s</li>', [ADiff.RemovedFeatures[i]]));
      HTML.Add('</ul>');
    end;

    // 字段变更
    if Length(ADiff.ChangedFields) > 0 then
    begin
      HTML.Add(nextpas.core.text.conv.Format('<h2>🔄 字段变更 (%d)</h2>', [Length(ADiff.ChangedFields)]));
      for i := 0 to High(ADiff.ChangedFields) do
      begin
        HTML.Add('<div class="changed">');
        HTML.Add(nextpas.core.text.conv.Format('<span class="field-name">%s:</span>', [ADiff.ChangedFields[i].FieldName]));
        HTML.Add(nextpas.core.text.conv.Format('<span>%s</span><span class="arrow">→</span><span>%s</span>',
          [ADiff.ChangedFields[i].OldValue, ADiff.ChangedFields[i].NewValue]));
        HTML.Add('</div>');
      end;
    end;

    HTML.Add('</div>');
    HTML.Add('</body>');
    HTML.Add('</html>');

    Result := HTML.Text;
  finally
  end;
end;

{ GenerateDiffReport }

function GenerateDiffReport(
  const ADiff: TCapabilityDiffResult;
  const AFormat: string
): string;
var
  Format: string;
begin
  Format := LowerCase(AFormat);

  if Format = 'json' then
    Result := GenerateJSONReport(ADiff)
  else if Format = 'html' then
    Result := GenerateHTMLReport(ADiff)
  else
    Result := GenerateTextReport(ADiff);
end;

{ CompareTwoBackends }

function CompareTwoBackends(
  AType1, AType2: TSSLLibraryType
): TCapabilityDiffResult;
var
  Lib1, Lib2: ISSLLibrary;
  Caps1, Caps2: TSSLBackendCapabilities;
begin
  Lib1 := TSSLFactory.GetLibrary(AType1);
  Lib2 := TSSLFactory.GetLibrary(AType2);

  Caps1 := Lib1.GetCapabilities;
  Caps2 := Lib2.GetCapabilities;

  Result := CompareCapabilities(Caps1, Caps2);
end;

end.
