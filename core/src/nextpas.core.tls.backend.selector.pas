{**
 * Unit: nextpas.core.tls.backend.selector
 * Purpose: 自动后端选择器 - 基于能力矩阵智能选择最佳后端
 *
 * v1.3.0 新增功能
 *
 * @author fafafa.ssl team
 * @version 1.3.0
 * @since 2026-02-05
 *}

unit nextpas.core.tls.backend.selector;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.tls.base;

type
  { TSSLOptimizationTarget - 优化目标 }
  TSSLOptimizationTarget = (
    optBalanced,       // 平衡（默认）
    optSecurity,       // 优先安全
    optPerformance,    // 优先性能
    optSize,           // 优先体积（嵌入式）
    optCompatibility   // 优先兼容性
  );

  { TSSLPlatformPreferences - 平台偏好 }
  TSSLPlatformPreferences = record
    PreferOSNative: Boolean;          // 优先 OS 原生实现
    PreferHardwareAccel: Boolean;     // 优先硬件加速
    PreferFIPSCompliant: Boolean;     // 优先 FIPS 兼容
    RequirePKCS11: Boolean;           // 需要 PKCS#11
    RequireTPM: Boolean;              // 需要 TPM
    RequireSystemCertStore: Boolean;  // 需要系统证书存储
  end;

  { TSSLRequirements - SSL 后端需求定义 }
  TSSLRequirements = record
    { 必需的协议支持 }
    RequiredProtocols: TSSLProtocolVersions;

    { 必需的算法支持 }
    RequiredCiphers: TSSLCipherSupport;
    RequiredHashes: TSSLHashSupport;
    RequiredKeyExchanges: TSSLKeyExchangeSupport;

    { 必需的功能 }
    RequiredFeatures: TSSLFeatures;

    { 优选的算法（可选） }
    PreferredCiphers: TSSLCipherSupport;
    PreferredHashes: TSSLHashSupport;

    { 最低评分要求 }
    MinSecurityScore: Integer;        // 0-100，默认 0（无要求）
    MinPerformanceScore: Integer;     // 0-100，默认 0（无要求）
    MinCompatibilityLevel: Integer;   // 0-100，默认 0（无要求）

    { 平台偏好 }
    PlatformPreferences: TSSLPlatformPreferences;

    { 优化目标 }
    OptimizationTarget: TSSLOptimizationTarget;
  end;

  { TSSLBackendMatchDetails - 后端匹配详情 }
  TSSLBackendMatchDetails = record
    RequiredFeaturesMatched: Integer;    // 必需功能匹配数
    RequiredFeaturesTotal: Integer;      // 必需功能总数
    PreferredFeaturesMatched: Integer;   // 优选功能匹配数
    PreferredFeaturesTotal: Integer;     // 优选功能总数
    SecurityScore: Integer;              // 安全评分
    PerformanceScore: Integer;           // 性能评分
    CompatibilityLevel: Integer;         // 兼容性级别
    PlatformMatch: Boolean;              // 平台偏好匹配
    MeetsMinimumRequirements: Boolean;   // 是否满足最低要求
  end;

  { TSSLBackendMatch - 后端匹配结果 }
  TSSLBackendMatch = record
    BackendType: TSSLLibraryType;
    BackendName: string;
    MatchScore: Integer;                 // 总匹配分数（0-100）
    Capabilities: TSSLBackendCapabilities;
    MatchDetails: TSSLBackendMatchDetails;
    RecommendationReason: string;        // 推荐原因
  end;

  { TSSLBackendMatchArray - 匹配结果数组 }
  TSSLBackendMatchArray = array of TSSLBackendMatch;

{ 主要选择函数 }

{ SelectBestBackend - 选择最佳后端

  @param ARequirements 后端需求定义
  @param ASelectedType 输出：选中的后端类型
  @param AMatchScore 输出：匹配分数（0-100）
  @return 是否成功选择到符合要求的后端
}
function SelectBestBackend(
  const ARequirements: TSSLRequirements;
  out ASelectedType: TSSLLibraryType;
  out AMatchScore: Integer
): Boolean;

{ SelectBestBackends - 选择多个最佳后端（排序列表）

  @param ARequirements 后端需求定义
  @param AMaxCount 最多返回多少个后端（默认 3）
  @return 排序后的匹配结果数组（按 MatchScore 降序）
}
function SelectBestBackends(
  const ARequirements: TSSLRequirements;
  AMaxCount: Integer = 3
): TSSLBackendMatchArray;

{ 辅助函数 }

{ CreateDefaultRequirements - 创建默认需求

  @param ATarget 优化目标
  @return 默认需求配置
}
function CreateDefaultRequirements(
  ATarget: TSSLOptimizationTarget = optBalanced
): TSSLRequirements;

{ CreateSecurityFirstRequirements - 创建安全优先需求 }
function CreateSecurityFirstRequirements: TSSLRequirements;

{ CreatePerformanceFirstRequirements - 创建性能优先需求 }
function CreatePerformanceFirstRequirements: TSSLRequirements;

{ CreateCompatibilityFirstRequirements - 创建兼容性优先需求 }
function CreateCompatibilityFirstRequirements: TSSLRequirements;

{ ValidateRequirements - 验证需求定义的合理性

  @param ARequirements 需求定义
  @param AErrors 输出：错误信息列表
  @return 是否有效
}
function ValidateRequirements(
  const ARequirements: TSSLRequirements;
  out AErrors: TStringArray
): Boolean;

implementation

uses
  nextpas.core.text.strings,
  nextpas.core.tls.factory;

{ 前向声明 }
function GenerateRecommendationReason(
  const AMatch: TSSLBackendMatch;
  const AReq: TSSLRequirements
): string; forward;

{ CreateDefaultRequirements }

function CreateDefaultRequirements(
  ATarget: TSSLOptimizationTarget
): TSSLRequirements;
begin
  FillChar(Result, SizeOf(Result), 0);

  // 默认要求 TLS 1.2+
  Result.RequiredProtocols := [sslProtocolTLS12, sslProtocolTLS13];

  // 默认无特定算法要求
  Result.RequiredCiphers := [];
  Result.RequiredHashes := [];
  Result.RequiredKeyExchanges := [];

  // 默认无特定功能要求
  Result.RequiredFeatures := [];

  // 根据目标设置评分要求
  case ATarget of
    optSecurity:
    begin
      Result.MinSecurityScore := 80;
      Result.MinPerformanceScore := 0;
      Result.OptimizationTarget := optSecurity;
    end;

    optPerformance:
    begin
      Result.MinSecurityScore := 0;
      Result.MinPerformanceScore := 80;
      Result.OptimizationTarget := optPerformance;
      Result.PlatformPreferences.PreferHardwareAccel := True;
    end;

    optCompatibility:
    begin
      Result.MinCompatibilityLevel := 80;
      Result.OptimizationTarget := optCompatibility;
    end;

    optSize:
    begin
      Result.OptimizationTarget := optSize;
      // 嵌入式场景通常选择 MbedTLS
    end;

    else // optBalanced
    begin
      Result.MinSecurityScore := 60;
      Result.MinPerformanceScore := 60;
      Result.OptimizationTarget := optBalanced;
    end;
  end;
end;

{ CreateSecurityFirstRequirements }

function CreateSecurityFirstRequirements: TSSLRequirements;
begin
  Result := CreateDefaultRequirements(optSecurity);

  // 强制 TLS 1.3
  Result.RequiredProtocols := [sslProtocolTLS13];

  // 要求现代密码套件
  Result.RequiredCiphers := [
    sslCipherAES256GCM,
    sslCipherCHACHA20_POLY1305
  ];

  // 要求 SHA-256 以上
  Result.RequiredHashes := [
    sslHashSHA256,
    sslHashSHA384,
    sslHashSHA512
  ];

  // 要求前向保密
  Result.RequiredKeyExchanges := [
    sslKexECDHE_RSA,
    sslKexECDHE_ECDSA
  ];

  Result.MinSecurityScore := 80;
end;

{ CreatePerformanceFirstRequirements }

function CreatePerformanceFirstRequirements: TSSLRequirements;
begin
  Result := CreateDefaultRequirements(optPerformance);

  Result.PlatformPreferences.PreferHardwareAccel := True;
  Result.MinPerformanceScore := 85;

  // 优选硬件加速的算法
  Result.PreferredCiphers := [
    sslCipherAES128GCM,
    sslCipherAES256GCM
  ];
end;

{ CreateCompatibilityFirstRequirements }

function CreateCompatibilityFirstRequirements: TSSLRequirements;
begin
  Result := CreateDefaultRequirements(optCompatibility);

  // 支持 TLS 1.2 和 1.3
  Result.RequiredProtocols := [sslProtocolTLS12, sslProtocolTLS13];

  // 无特定算法要求
  Result.RequiredCiphers := [];

  Result.MinCompatibilityLevel := 85;
end;

{ ValidateRequirements }

function ValidateRequirements(
  const ARequirements: TSSLRequirements;
  out AErrors: TStringArray
): Boolean;
var
  ErrorList: TStringArray;
begin
  // 检查协议版本
  if ARequirements.RequiredProtocols = [] then
    ErrorList.Add('至少需要指定一个 TLS 协议版本');

  // 检查评分范围
  if (ARequirements.MinSecurityScore < 0) or
    (ARequirements.MinSecurityScore > 100) then
    ErrorList.Add('MinSecurityScore 必须在 0-100 之间');

  if (ARequirements.MinPerformanceScore < 0) or
    (ARequirements.MinPerformanceScore > 100) then
    ErrorList.Add('MinPerformanceScore 必须在 0-100 之间');

  if (ARequirements.MinCompatibilityLevel < 0) or
    (ARequirements.MinCompatibilityLevel > 100) then
    ErrorList.Add('MinCompatibilityLevel 必须在 0-100 之间');

  // 检查不合理的组合
  if ARequirements.PlatformPreferences.RequirePKCS11 and
    ARequirements.PlatformPreferences.RequireTPM then
    ErrorList.Add('PKCS#11 和 TPM 通常不同时需要，请检查需求');

  // 转换结果
  AErrors := Copy(ErrorList);
  Result := (Length(ErrorList) = 0);
  end;
end;

{ 内部评分函数 }

function CalculateRequiredFeaturesScore(
  const ACaps: TSSLBackendCapabilities;
  const AReq: TSSLRequirements;
  out ADetails: TSSLBackendMatchDetails
): Integer;
var
  RequiredCount, MatchedCount: Integer;
  LFeature: TSSLFeature;

  function CapabilitySatisfiesRequiredFeature(AFeature: TSSLFeature): Boolean;
  begin
    case AFeature of
      sslFeatSNI:
        Result := ACaps.SNISupport <> sslSupportNone;
      sslFeatALPN:
        Result := ACaps.ALPNSupport <> sslSupportNone;
      sslFeatSessionCache:
        Result := ACaps.SessionCacheSupport <> sslSupportNone;
      sslFeatSessionTickets:
        Result := ACaps.SessionTicketsSupport <> sslSupportNone;
      sslFeatRenegotiation:
        Result := ACaps.RenegotiationSupport <> sslSupportNone;
      sslFeatOCSPStapling:
        Result := ACaps.OCSPStaplingSupport <> sslSupportNone;
      sslFeatCertificateTransparency:
        Result := ACaps.CertTransparencySupport <> sslSupportNone;
    end;
  end;
begin
  RequiredCount := 0;
  MatchedCount := 0;

  // 检查协议支持
  if sslProtocolTLS12 in AReq.RequiredProtocols then
  begin
    Inc(RequiredCount);
    if ACaps.MinTLSVersion <= sslProtocolTLS12 then
      Inc(MatchedCount);
  end;

  if sslProtocolTLS13 in AReq.RequiredProtocols then
  begin
    Inc(RequiredCount);
    if ACaps.SupportsTLS13 then
      Inc(MatchedCount);
  end;

  // 检查算法支持
  if AReq.RequiredCiphers <> [] then
  begin
    Inc(RequiredCount);
    if (AReq.RequiredCiphers * ACaps.SupportedCiphers) = AReq.RequiredCiphers then
      Inc(MatchedCount);
  end;

  if AReq.RequiredHashes <> [] then
  begin
    Inc(RequiredCount);
    if (AReq.RequiredHashes * ACaps.SupportedHashes) = AReq.RequiredHashes then
      Inc(MatchedCount);
  end;

  if AReq.RequiredKeyExchanges <> [] then
  begin
    Inc(RequiredCount);
    if (AReq.RequiredKeyExchanges * ACaps.SupportedKeyExchanges) = AReq.RequiredKeyExchanges then
      Inc(MatchedCount);
  end;

  // 检查功能支持
  for LFeature := Low(TSSLFeature) to High(TSSLFeature) do
  begin
    if not (LFeature in AReq.RequiredFeatures) then
      Continue;

    Inc(RequiredCount);
    if CapabilitySatisfiesRequiredFeature(LFeature) then
      Inc(MatchedCount);
  end;

  // 检查平台特性
  if AReq.PlatformPreferences.RequirePKCS11 then
  begin
    Inc(RequiredCount);
    if ACaps.SupportsPKCS11 then
      Inc(MatchedCount);
  end;

  if AReq.PlatformPreferences.RequireTPM then
  begin
    Inc(RequiredCount);
    if ACaps.SupportsTPM then
      Inc(MatchedCount);
  end;

  if AReq.PlatformPreferences.RequireSystemCertStore then
  begin
    Inc(RequiredCount);
    if ACaps.SupportsSystemCertStore then
      Inc(MatchedCount);
  end;

  ADetails.RequiredFeaturesTotal := RequiredCount;
  ADetails.RequiredFeaturesMatched := MatchedCount;

  // 返回百分比（0-100）
  if RequiredCount > 0 then
    Result := (MatchedCount * 100) div RequiredCount
  else
    Result := 100;  // 无必需功能，算作全部满足
end;

function CalculatePreferredFeaturesScore(
  const ACaps: TSSLBackendCapabilities;
  const AReq: TSSLRequirements;
  out ADetails: TSSLBackendMatchDetails
): Integer;
var
  PreferredCount, MatchedCount: Integer;
begin
  PreferredCount := 0;
  MatchedCount := 0;

  // 检查优选算法
  if AReq.PreferredCiphers <> [] then
  begin
    Inc(PreferredCount);
    if (AReq.PreferredCiphers * ACaps.SupportedCiphers) <> [] then
      Inc(MatchedCount);
  end;

  if AReq.PreferredHashes <> [] then
  begin
    Inc(PreferredCount);
    if (AReq.PreferredHashes * ACaps.SupportedHashes) <> [] then
      Inc(MatchedCount);
  end;

  ADetails.PreferredFeaturesTotal := PreferredCount;
  ADetails.PreferredFeaturesMatched := MatchedCount;

  if PreferredCount > 0 then
    Result := (MatchedCount * 100) div PreferredCount
  else
    Result := 0;  // 无优选功能
end;

function CalculatePlatformScore(
  const ACaps: TSSLBackendCapabilities;
  const AReq: TSSLRequirements
): Integer;
var
  Score: Integer;
begin
  Score := 0;

  // OS 原生偏好
  if AReq.PlatformPreferences.PreferOSNative then
  begin
    if ACaps.BackendImplType = sslImplOSNative then
      Score += 30;
  end;

  // 硬件加速偏好
  if AReq.PlatformPreferences.PreferHardwareAccel then
  begin
    if ACaps.HasHardwareAcceleration then
      Score += 25;
  end;

  // FIPS 兼容偏好
  if AReq.PlatformPreferences.PreferFIPSCompliant then
  begin
    if ACaps.SupportsFIPSMode then
      Score += 25;
  end;

  // PKCS#11 支持
  if ACaps.SupportsPKCS11 then
    Score += 10;

  // TPM 支持
  if ACaps.SupportsTPM then
    Score += 10;

  Result := Score;
  if Result > 100 then
    Result := 100;
end;

function CalculateTotalMatchScore(
  const ACaps: TSSLBackendCapabilities;
  const AReq: TSSLRequirements;
  out ADetails: TSSLBackendMatchDetails
): Integer;
var
  RequiredScore, PreferredScore, PlatformScore: Integer;
  SecurityWeight, PerformanceWeight, PlatformWeight: Integer;
begin
  // 1. 必需功能评分（40%）
  RequiredScore := CalculateRequiredFeaturesScore(ACaps, AReq, ADetails);

  // 如果必需功能不满足，直接返回 0
  if RequiredScore < 100 then
  begin
    ADetails.MeetsMinimumRequirements := False;
    Result := 0;
    Exit;
  end;

  ADetails.MeetsMinimumRequirements := True;

  // 2. 优选功能评分（20%）
  PreferredScore := CalculatePreferredFeaturesScore(ACaps, AReq, ADetails);

  // 3. 平台偏好评分（10%）
  PlatformScore := CalculatePlatformScore(ACaps, AReq);
  ADetails.PlatformMatch := (PlatformScore > 50);

  // 4. 安全和性能评分（30%）
  ADetails.SecurityScore := GetSecurityScore(ACaps);
  ADetails.PerformanceScore := GetPerformanceScore(ACaps);
  ADetails.CompatibilityLevel := ACaps.CompatibilityLevel;

  // 检查最低评分要求
  if (AReq.MinSecurityScore > 0) and
    (ADetails.SecurityScore < AReq.MinSecurityScore) then
  begin
    ADetails.MeetsMinimumRequirements := False;
    Result := 0;
    Exit;
  end;

  if (AReq.MinPerformanceScore > 0) and
    (ADetails.PerformanceScore < AReq.MinPerformanceScore) then
  begin
    ADetails.MeetsMinimumRequirements := False;
    Result := 0;
    Exit;
  end;

  if (AReq.MinCompatibilityLevel > 0) and
    (ADetails.CompatibilityLevel < AReq.MinCompatibilityLevel) then
  begin
    ADetails.MeetsMinimumRequirements := False;
    Result := 0;
    Exit;
  end;

  // 5. 根据优化目标调整权重
  case AReq.OptimizationTarget of
    optSecurity:
    begin
      SecurityWeight := 40;
      PerformanceWeight := 10;
      PlatformWeight := 10;
    end;

    optPerformance:
    begin
      SecurityWeight := 10;
      PerformanceWeight := 40;
      PlatformWeight := 10;
    end;

    optCompatibility:
    begin
      SecurityWeight := 15;
      PerformanceWeight := 15;
      PlatformWeight := 10;
    end;

    optSize:
    begin
      SecurityWeight := 15;
      PerformanceWeight := 15;
      PlatformWeight := 10;
    end;

    else // optBalanced
    begin
      SecurityWeight := 20;
      PerformanceWeight := 20;
      PlatformWeight := 10;
    end;
  end;

  // 6. 计算总分
  Result :=
    40 +  // 必需功能已全部满足（固定 40 分）
    (PreferredScore * 20) div 100 +
    (ADetails.SecurityScore * SecurityWeight) div 100 +
    (ADetails.PerformanceScore * PerformanceWeight) div 100 +
    (PlatformScore * PlatformWeight) div 100;

  if Result > 100 then
    Result := 100;
end;

{ SelectBestBackend }

function SelectBestBackend(
  const ARequirements: TSSLRequirements;
  out ASelectedType: TSSLLibraryType;
  out AMatchScore: Integer
): Boolean;
var
  AvailableBackends: TSSLLibraryTypes;
  BackendType: TSSLLibraryType;
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  Details: TSSLBackendMatchDetails;
  Score: Integer;
  BestScore: Integer;
  BestType: TSSLLibraryType;
begin
  Result := False;
  BestScore := -1;
  BestType := sslOpenSSL;  // 默认

  // 获取所有可用的后端
  AvailableBackends := TSSLFactory.GetAvailableLibraries;

  if AvailableBackends = [] then
    Exit;

  // 遍历所有后端，计算匹配分数
  for BackendType in AvailableBackends do
  begin
    try
      // 获取库实例
      Lib := TSSLFactory.GetLibrary(BackendType);

      // 获取能力矩阵（极快，已缓存）
      Caps := Lib.GetCapabilities;

      // 计算匹配分数
      Score := CalculateTotalMatchScore(Caps, ARequirements, Details);

      // Only qualifying backends may participate in final selection.
      if (not Details.MeetsMinimumRequirements) or (Score <= 0) then
        Continue;

      // 更新最佳匹配
      if Score > BestScore then
      begin
        BestScore := Score;
        BestType := BackendType;
        Result := True;
      end;

    except
      // 忽略不可用的后端
      Continue;
    end;
  end;

  if Result then
  begin
    ASelectedType := BestType;
    AMatchScore := BestScore;
  end;
end;

{ SelectBestBackends }

function SelectBestBackends(
  const ARequirements: TSSLRequirements;
  AMaxCount: Integer
): TSSLBackendMatchArray;
var
  AvailableBackends: TSSLLibraryTypes;
  BackendType: TSSLLibraryType;
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  Details: TSSLBackendMatchDetails;
  Score: Integer;
  Match: TSSLBackendMatch;
  ResultList: array of TSSLBackendMatch;
  i, j: Integer;
  Temp: TSSLBackendMatch;
begin
  SetLength(ResultList, 0);

  // 获取所有可用的后端
  AvailableBackends := TSSLFactory.GetAvailableLibraries;

  // 遍历所有后端
  for BackendType in AvailableBackends do
  begin
    try
      Lib := TSSLFactory.GetLibrary(BackendType);
      Caps := Lib.GetCapabilities;

      // 计算匹配分数
      Score := CalculateTotalMatchScore(Caps, ARequirements, Details);

      // 只保留满足最低要求的后端
      if not Details.MeetsMinimumRequirements then
        Continue;

      // 创建匹配记录
      Match.BackendType := BackendType;
      Match.BackendName := Lib.GetVersionString;
      Match.MatchScore := Score;
      Match.Capabilities := Caps;
      Match.MatchDetails := Details;

      // 生成推荐原因
      Match.RecommendationReason := GenerateRecommendationReason(Match, ARequirements);

      // 添加到结果列表
      SetLength(ResultList, Length(ResultList) + 1);
      ResultList[High(ResultList)] := Match;

    except
      Continue;
    end;
  end;

  // 排序：按 MatchScore 降序
  for i := 0 to High(ResultList) - 1 do
  begin
    for j := i + 1 to High(ResultList) do
    begin
      if ResultList[j].MatchScore > ResultList[i].MatchScore then
      begin
        Temp := ResultList[i];
        ResultList[i] := ResultList[j];
        ResultList[j] := Temp;
      end;
    end;
  end;

  // 限制返回数量
  if (AMaxCount > 0) and (Length(ResultList) > AMaxCount) then
    SetLength(ResultList, AMaxCount);

  Result := ResultList;
end;

{ GenerateRecommendationReason }

function GenerateRecommendationReason(
  const AMatch: TSSLBackendMatch;
  const AReq: TSSLRequirements
): string;
var
  Reasons: TStringArray;
  Caps: TSSLBackendCapabilities;
begin
    Caps := AMatch.Capabilities;

    // 根据匹配情况生成原因
    if AMatch.MatchScore >= 90 then
      Reasons.Add('完美匹配所有需求');

    if AMatch.MatchDetails.SecurityScore >= 90 then
      Reasons.Add('优秀的安全评分');

    if AMatch.MatchDetails.PerformanceScore >= 90 then
      Reasons.Add('优秀的性能评分');

    if Caps.BackendImplType = sslImplOSNative then
      Reasons.Add('OS 原生实现，零依赖');

    if Caps.HasHardwareAcceleration then
      Reasons.Add('支持硬件加速');

    if Caps.SupportsPKCS11 then
      Reasons.Add('支持 PKCS#11 硬件安全模块');

    if Caps.SupportsTPM then
      Reasons.Add('支持 TPM 可信平台模块');

    if Caps.SupportsFIPSMode then
      Reasons.Add('支持 FIPS 140-2 模式');

    if Caps.SupportsTLS13 then
      Reasons.Add('支持最新的 TLS 1.3 协议');

    if Length(Reasons) = 0 then
      Result := '满足基本需求'
    else
      Result := StringsJoin(Reasons, '; ');
  end;
end;

end.
