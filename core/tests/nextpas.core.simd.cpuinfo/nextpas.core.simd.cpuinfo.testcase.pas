unit nextpas.core.simd.cpuinfo.testcase;

{$I nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.test,
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.intrinsics,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo,
  {$IFDEF SIMD_X86_AVAILABLE}
  nextpas.core.simd.cpuinfo.x86.base,
  nextpas.core.simd.cpuinfo.x86,
  {$ENDIF}
  {$IFDEF SIMD_ARM_AVAILABLE}
  nextpas.core.simd.cpuinfo.arm,
  {$ENDIF}
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  nextpas.core.simd.cpuinfo.riscv,
  {$ENDIF}
  nextpas.core.simd.cpuinfo.lazy,
  nextpas.core.simd.cpuinfo.diagnostic,
  nextpas.core.simd.dispatch;

{$M+}
type
  // 全局函数测试
  TTestFixture_Global = class(TTestFixture)
  published
    procedure Test_GetCPUInfo;
    procedure Test_IsBackendAvailable;
    procedure Test_BackendSupportPredicateConsistency;
    procedure Test_GetAvailableBackends;
    procedure Test_ClearSupportedAliases_PreserveCpuOnlySemantics;
    procedure Test_GetBestBackend;
    procedure Test_GetBestBackendOnCPU_IndependentFromActiveBackend;
    procedure Test_GetBackendInfo;
    procedure Test_ResetCPUInfo;
  end;

  // 线程安全测试
  TTestFixture_ThreadSafety = class(TTestFixture)
  published
    procedure Test_GetCPUInfo_Consistency;
    procedure Test_GetCPUInfo_Performance;
  end;

  // 平台特定测试
  TTestFixture_PlatformSpecific = class(TTestFixture)
  published
    procedure Test_X86Features;
    procedure Test_IntrinsicsAVXAvailability_Semantics;
    procedure Test_IntrinsicsFacade_FullConsistency;
    procedure Test_BackendFeatureBidirectionalConsistency;
    procedure Test_X86RawAVX_RemainsVisible_When_OSXSAVE_Disabled;
    procedure Test_X86RawAVX_RemainsVisible_When_XCR0_Disabled;
    procedure Test_X86UsableAVX_FailCloses_When_AVX2_Without_AVX;
    procedure Test_X86UsableAVX512_FailCloses_When_AVX512F_Without_AVX2;
    procedure Test_AVXUsable_XCR0Semantics;
    procedure Test_AVX512Usable_XCR0Semantics;
    procedure Test_DiagnosticReport_UsableViewConsistency;
    procedure Test_ARMFeatures;
    procedure Test_LoongArchFeatures;
    procedure Test_ARMFeatureParserSamples;
    procedure Test_ARMHWCAPMergeSamples;
    procedure Test_ARMVendorModelParserSamples;
    procedure Test_ARMProcessorInfoBasic;
    procedure Test_ARMProcessorInfoParserSamples;
    procedure Test_CacheSizeParserSamples;
    procedure Test_NonX86CacheInfoOnLinux;
    procedure Test_RISCVISAParserSamples;
    procedure Test_RISCVISASelectionSamples;
    procedure Test_RISCVHWCAPMergeSamples;
    procedure Test_RISCVVendorModelParserSamples;
    procedure Test_RISCVProcessorInfoBasic;
    procedure Test_FeatureHierarchy;
  end;

  // 错误处理测试
  TTestFixture_ErrorHandling = class(TTestFixture)
  published
    procedure Test_InvalidBackend;
    procedure Test_ExceptionHandling;
  end;

implementation

function BackendInArray(aBackend: TSimdBackend; const aBackends: TSimdBackendArray): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(aBackends) do
    if aBackends[LIndex] = aBackend then
      Exit(True);
  Result := False;
end;

function XCR0EnablesAVX512_Local(const aCPUInfo: TCPUInfo): Boolean; inline;
begin
  Result := ((aCPUInfo.XCR0 and (UInt64(1) shl 1)) <> 0) and
            ((aCPUInfo.XCR0 and (UInt64(1) shl 2)) <> 0) and
            ((aCPUInfo.XCR0 and (UInt64(1) shl 5)) <> 0) and
            ((aCPUInfo.XCR0 and (UInt64(1) shl 6)) <> 0) and
            ((aCPUInfo.XCR0 and (UInt64(1) shl 7)) <> 0);
end;

function XCR0EnablesAVX_Local(const aCPUInfo: TCPUInfo): Boolean; inline;
begin
  Result := ((aCPUInfo.XCR0 and (UInt64(1) shl 1)) <> 0) and
            ((aCPUInfo.XCR0 and (UInt64(1) shl 2)) <> 0);
end;

{$IFDEF LINUX}
function ReadFirstLineTrimmedLocal(const aPath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, aPath);
  {$I-} Reset(LFile); {$I+}
  if IOResult <> 0 then
    Exit;
  try
    if not EOF(LFile) then
    begin
      ReadLn(LFile, LLine);
      Result := Trim(LLine);
    end;
  finally
    Close(LFile);
  end;
end;

function ParseCacheSizeToKBLocal(const aText: string): Integer;
var
  LText: string;
  LNumText: string;
  LCode: Integer;
  LValue: Int64;
  LUnit: Char;

  function ClampKBToIntegerLocal(const aValue: Int64): Integer; inline;
  begin
    if aValue <= 0 then
      Exit(0);
    if aValue > High(Integer) then
      Exit(High(Integer));
    Result := Integer(aValue);
  end;

  function BytesToKBLocal(const aBytes: Int64): Integer; inline;
  var
    LKBValue: Int64;
  begin
    if aBytes <= 0 then
      Exit(0);
    LKBValue := ((aBytes - 1) div 1024) + 1;
    Result := ClampKBToIntegerLocal(LKBValue);
  end;
begin
  Result := 0;
  LText := UpperCase(Trim(aText));
  if LText = '' then
    Exit;

  LText := StringReplace(LText, ' ', '', [rfReplaceAll]);
  LText := StringReplace(LText, #9, '', [rfReplaceAll]);
  if LText = '' then
    Exit;

  if (Length(LText) >= 3) and (Copy(LText, Length(LText) - 2, 3) = 'KIB') then
  begin
    LUnit := 'K';
    LNumText := Copy(LText, 1, Length(LText) - 3);
  end
  else if (Length(LText) >= 3) and (Copy(LText, Length(LText) - 2, 3) = 'MIB') then
  begin
    LUnit := 'M';
    LNumText := Copy(LText, 1, Length(LText) - 3);
  end
  else if (Length(LText) >= 3) and (Copy(LText, Length(LText) - 2, 3) = 'GIB') then
  begin
    LUnit := 'G';
    LNumText := Copy(LText, 1, Length(LText) - 3);
  end
  else if (Length(LText) >= 2) and (Copy(LText, Length(LText) - 1, 2) = 'KB') then
  begin
    LUnit := 'K';
    LNumText := Copy(LText, 1, Length(LText) - 2);
  end
  else if (Length(LText) >= 2) and (Copy(LText, Length(LText) - 1, 2) = 'MB') then
  begin
    LUnit := 'M';
    LNumText := Copy(LText, 1, Length(LText) - 2);
  end
  else if (Length(LText) >= 2) and (Copy(LText, Length(LText) - 1, 2) = 'GB') then
  begin
    LUnit := 'G';
    LNumText := Copy(LText, 1, Length(LText) - 2);
  end
  else if (Length(LText) >= 1) and (LText[Length(LText)] in ['K', 'M', 'G']) then
  begin
    LUnit := LText[Length(LText)];
    LNumText := Copy(LText, 1, Length(LText) - 1);
  end
  else if (Length(LText) >= 1) and (LText[Length(LText)] = 'B') then
  begin
    LNumText := Copy(LText, 1, Length(LText) - 1);
    Val(LNumText, LValue, LCode);
    if (LCode = 0) and (LValue > 0) then
      Result := BytesToKBLocal(LValue);
    Exit;
  end
  else
  begin
    Val(LText, LValue, LCode);
    if (LCode = 0) and (LValue > 0) then
      Result := BytesToKBLocal(LValue);
    Exit;
  end;

  Val(LNumText, LValue, LCode);
  if (LCode <> 0) or (LValue <= 0) then
    Exit;

  case LUnit of
    'K':
      Result := ClampKBToIntegerLocal(LValue);
    'M':
      begin
        if LValue > (High(Integer) div 1024) then
          Result := High(Integer)
        else
          Result := Integer(LValue * 1024);
      end;
    'G':
      begin
        if LValue > (High(Integer) div (1024 * 1024)) then
          Result := High(Integer)
        else
          Result := Integer(LValue * 1024 * 1024);
      end;
  else
    Result := BytesToKBLocal(LValue);
  end;
end;

function IsLinuxCpuDirectoryNameLocal(const aName: string): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(aName) > 3) and (Copy(aName, 1, 3) = 'cpu');
  if not Result then
    Exit;

  for LIndex := 4 to Length(aName) do
    if not (aName[LIndex] in ['0'..'9']) then
      Exit(False);
end;

function ReadLinuxSysfsCacheSnapshot(out aCache: TCacheInfo): Boolean;
var
  LCpuBase: string;
  LCpuCacheBase: string;
  LDir: string;
  LCpuRec: TSearchRec;
  LIndexRec: TSearchRec;
  LTypeText: string;
  LLevelText: string;
  LSizeText: string;
  LLineSizeText: string;
  LLevel: Integer;
  LSizeKB: Integer;
  LLineSize: Integer;
  LHasAnyValue: Boolean;
begin
  FillChar(aCache, SizeOf(aCache), 0);
  Result := False;
  LHasAnyValue := False;
  LCpuBase := '/sys/devices/system/cpu';

  if not DirectoryExists(LCpuBase) then
    Exit;
  if FindFirst(LCpuBase + '/cpu*', faDirectory, LCpuRec) <> 0 then
    Exit;
  try
    repeat
      if (LCpuRec.Name = '.') or (LCpuRec.Name = '..') then
        Continue;
      if (LCpuRec.Attr and faDirectory) = 0 then
        Continue;
      if not IsLinuxCpuDirectoryNameLocal(LCpuRec.Name) then
        Continue;

      LCpuCacheBase := LCpuBase + '/' + LCpuRec.Name + '/cache';
      if not DirectoryExists(LCpuCacheBase) then
        Continue;
      if FindFirst(LCpuCacheBase + '/index*', faDirectory, LIndexRec) <> 0 then
        Continue;
      try
        repeat
          if (LIndexRec.Name = '.') or (LIndexRec.Name = '..') then
            Continue;
          if (LIndexRec.Attr and faDirectory) = 0 then
            Continue;

          LDir := LCpuCacheBase + '/' + LIndexRec.Name;
          LTypeText := LowerCase(ReadFirstLineTrimmedLocal(LDir + '/type'));
          LLevelText := ReadFirstLineTrimmedLocal(LDir + '/level');
          LSizeText := ReadFirstLineTrimmedLocal(LDir + '/size');
          LLineSizeText := ReadFirstLineTrimmedLocal(LDir + '/coherency_line_size');

          LLevel := StrToIntDef(LLevelText, 0);
          LSizeKB := ParseCacheSizeToKBLocal(LSizeText);
          LLineSize := StrToIntDef(LLineSizeText, 0);

          if LLineSize > aCache.LineSize then
            aCache.LineSize := LLineSize;

          if (LLevel <= 0) or (LSizeKB <= 0) then
            Continue;

          LHasAnyValue := True;
          case LLevel of
            1:
              begin
                if LTypeText = 'instruction' then
                begin
                  if LSizeKB > aCache.L1InstrKB then
                    aCache.L1InstrKB := LSizeKB;
                end
                else if LTypeText = 'unified' then
                begin
                  if LSizeKB > aCache.L1DataKB then
                    aCache.L1DataKB := LSizeKB;
                  if LSizeKB > aCache.L1InstrKB then
                    aCache.L1InstrKB := LSizeKB;
                end
                else
                begin
                  if LSizeKB > aCache.L1DataKB then
                    aCache.L1DataKB := LSizeKB;
                end;
              end;
            2:
              begin
                if LSizeKB > aCache.L2KB then
                  aCache.L2KB := LSizeKB;
              end;
            3:
              begin
                if LSizeKB > aCache.L3KB then
                  aCache.L3KB := LSizeKB;
              end;
          end;
        until FindNext(LIndexRec) <> 0;
      finally
        FindClose(LIndexRec);
      end;
    until FindNext(LCpuRec) <> 0;
  finally
    FindClose(LCpuRec);
  end;

  Result := LHasAnyValue or (aCache.LineSize > 0);
end;
{$ENDIF}

// === TTestFixture_Global ===

procedure TTestFixture_Global.Test_GetCPUInfo;
var
  cpuInfo: TCPUInfo;
  cpuInfo2: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  
  // 基本验证
  CheckTrue(cpuInfo.Vendor <> '', 'CPU vendor should not be empty');
  CheckTrue(cpuInfo.Model <> '', 'CPU model should not be empty');
  
  // 多次调用应该返回相同结果
  cpuInfo2 := GetCPUInfo;
  CheckEqual(cpuInfo.Vendor, cpuInfo2.Vendor, 'Vendor should be consistent');
  CheckEqual(cpuInfo.Model, cpuInfo2.Model, 'Model should be consistent');
end;

procedure TTestFixture_Global.Test_IsBackendAvailable;
var
  sse2Available: Boolean;
  avx2Available: Boolean;
  neonAvailable: Boolean;
begin
  // Scalar 后端必须总是可用
  CheckTrue(IsBackendAvailableOnCPU(sbScalar), 'Scalar backend must always be available');
  
  // 测试其他后端
  sse2Available := IsBackendAvailableOnCPU(sbSSE2);
  avx2Available := IsBackendAvailableOnCPU(sbAVX2);
  neonAvailable := IsBackendAvailableOnCPU(sbNEON);
  
  // 记录结果用于调试
  WriteLn('SSE2 available: ', sse2Available);
  WriteLn('AVX2 available: ', avx2Available);
  WriteLn('NEON available: ', neonAvailable);
end;

procedure TTestFixture_Global.Test_BackendSupportPredicateConsistency;
const
  BACKENDS: array[0..9] of TSimdBackend = (
    sbAVX512, sbAVX2, sbSSE42, sbSSE41, sbSSSE3, sbSSE3, sbSSE2, sbNEON, sbRISCVV, sbScalar
  );
var
  LBackends: TSimdBackendArray;
  LIndex: Integer;
  LBackend: TSimdBackend;
  LSupportedByCpuInfo: Boolean;
  LAvailableByDispatch: Boolean;
begin
  LBackends := GetSupportedBackends;

  for LIndex := Low(BACKENDS) to High(BACKENDS) do
  begin
    LBackend := BACKENDS[LIndex];
    LSupportedByCpuInfo := nextpas.core.simd.cpuinfo.IsBackendSupportedOnCPU(LBackend);
    LAvailableByDispatch := IsBackendAvailableOnCPU(LBackend);

    CheckEqual(LSupportedByCpuInfo, LAvailableByDispatch, 'cpuinfo predicate and dispatch predicate should agree for backend=' + IntToStr(Ord(LBackend)));
    CheckEqual(LSupportedByCpuInfo, BackendInArray(LBackend, LBackends), 'cpuinfo predicate should match GetSupportedBackends membership for backend=' + IntToStr(Ord(LBackend)));
  end;
end;

procedure TTestFixture_Global.Test_GetAvailableBackends;
var
  backends: TSimdBackendArray;
  i: Integer;
  foundScalar: Boolean;
  info1: TSimdBackendInfo;
  info2: TSimdBackendInfo;
begin
  backends := GetAvailableBackends;
  
  // 至少应该有 Scalar 后端
  CheckTrue(Length(backends) > 0, 'Should have at least one backend');
  
  // 检查是否包含 Scalar 后端
  foundScalar := False;
  for i := 0 to Length(backends) - 1 do
  begin
    if backends[i] = sbScalar then
    begin
      foundScalar := True;
      Break;
    end;
  end;
  CheckTrue(foundScalar, 'Should include scalar backend');
  
  // 验证后端按优先级排序（高优先级在前）
  for i := 0 to Length(backends) - 2 do
  begin
    info1 := GetBackendInfo(backends[i]);
    info2 := GetBackendInfo(backends[i + 1]);
    CheckTrue(info1.Priority >= info2.Priority, 'Backends should be sorted by priority');
  end;
end;

procedure TTestFixture_Global.Test_ClearSupportedAliases_PreserveCpuOnlySemantics;
var
  LSupportedLegacy: TSimdBackendArray;
  LSupportedAlias: TSimdBackendArray;
  LAvailableLegacy: TSimdBackendArray;
  LIndex: Integer;
  LBestLegacy: TSimdBackend;
  LBestAlias: TSimdBackend;
  LBestCompat: TSimdBackend;
begin
  LSupportedLegacy := GetSupportedBackends;
  LSupportedAlias := GetSupportedBackendList;
  LAvailableLegacy := GetAvailableBackends;

  CheckEqual(Length(LSupportedLegacy), Length(LSupportedAlias), 'GetSupportedBackendList length should match GetSupportedBackends');
  CheckEqual(Length(LSupportedLegacy), Length(LAvailableLegacy), 'GetAvailableBackends length should match GetSupportedBackends');

  for LIndex := 0 to High(LSupportedLegacy) do
  begin
    CheckEqual(Ord(LSupportedLegacy[LIndex]), Ord(LSupportedAlias[LIndex]), 'GetSupportedBackendList should preserve CPU-supported ordering');
    CheckEqual(Ord(LSupportedLegacy[LIndex]), Ord(LAvailableLegacy[LIndex]), 'GetAvailableBackends should remain a compatibility alias for CPU-supported ordering');
  end;

  LBestLegacy := GetBestBackendOnCPU;
  LBestAlias := GetBestSupportedBackend;
  LBestCompat := GetBestBackend;

  CheckEqual(Ord(LBestLegacy), Ord(LBestAlias), 'GetBestSupportedBackend should alias GetBestBackendOnCPU');
  CheckEqual(Ord(LBestLegacy), Ord(LBestCompat), 'GetBestBackend should remain a compatibility alias');
end;

procedure TTestFixture_Global.Test_GetBestBackend;
var
  bestBackend: TSimdBackend;
  backendInfo: TSimdBackendInfo;
begin
  InitializeDispatch;
  bestBackend := GetBestBackend;
  
  // 最佳后端必须可用
  CheckTrue(IsBackendAvailableOnCPU(bestBackend), 'Best backend must be available');
  
  // Dispatch 返回的是“已注册并激活”的后端信息；它不一定与 CPU 最优后端同一个枚举值。
  backendInfo := GetBackendInfo(GetActiveBackend);
  CheckTrue(backendInfo.Available, 'Active backend info should be available');
  CheckTrue(backendInfo.Name <> '', 'Active backend name should not be empty');
end;

procedure TTestFixture_Global.Test_GetBestBackendOnCPU_IndependentFromActiveBackend;
var
  LBestCPU: TSimdBackend;
  LBestAlias: TSimdBackend;
  LOriginalActive: TSimdBackend;
  LBackends: TSimdBackendArray;
  LIndex: Integer;
begin
  LBestCPU := GetBestBackendOnCPU;
  LBestAlias := GetBestBackend;
  CheckEqual(Ord(LBestCPU), Ord(LBestAlias), 'GetBestBackend should alias GetBestBackendOnCPU');

  InitializeDispatch;
  LOriginalActive := GetActiveBackend;
  LBackends := GetAvailableBackends;

  if TrySetActiveBackend(sbScalar) then
    CheckEqual(Ord(LBestCPU), Ord(GetBestBackendOnCPU), 'CPU best backend should not depend on active backend (scalar)');

  for LIndex := 0 to High(LBackends) do
  begin
    if LBackends[LIndex] = GetActiveBackend then
      Continue;
    if TrySetActiveBackend(LBackends[LIndex]) then
    begin
      CheckEqual(Ord(LBestCPU), Ord(GetBestBackendOnCPU), 'CPU best backend should remain stable when active backend changes');
      Break;
    end;
  end;

  if not TrySetActiveBackend(LOriginalActive) then
    ResetToAutomaticBackend;
end;

procedure TTestFixture_Global.Test_GetBackendInfo;
var
  info: TSimdBackendInfo;
begin
  InitializeDispatch;
  // 测试 Scalar 后端信息
  info := GetBackendInfo(sbScalar);
  CheckTrue(info.Available, 'Scalar backend should be available');
  CheckTrue(info.Name <> '', 'Scalar backend name should not be empty');
  CheckTrue(info.Priority >= 0, 'Scalar backend priority should be non-negative');
  
  // 测试其他后端
  info := GetBackendInfo(sbSSE2);
  if info.Available then
    CheckTrue(info.Name <> '', 'SSE2 backend name should not be empty when available');
  
  info := GetBackendInfo(sbAVX2);
  if info.Available then
    CheckTrue(info.Name <> '', 'AVX2 backend name should not be empty when available');
  
  info := GetBackendInfo(sbNEON);
  if info.Available then
    CheckTrue(info.Name <> '', 'NEON backend name should not be empty when available');
end;

procedure TTestFixture_Global.Test_ResetCPUInfo;
var
  cpuInfo1, cpuInfo2: TCPUInfo;
begin
  // 获取初始信息
  cpuInfo1 := GetCPUInfo;
  
  // 重置
  ResetCPUInfo;
  
  // 重新获取
  cpuInfo2 := GetCPUInfo;
  
  // 结果应该相同
  CheckEqual(cpuInfo1.Vendor, cpuInfo2.Vendor, 'Vendor should be same after reset');
  CheckEqual(cpuInfo1.Model, cpuInfo2.Model, 'Model should be same after reset');
end;

// === TTestFixture_ThreadSafety ===

procedure TTestFixture_ThreadSafety.Test_GetCPUInfo_Consistency;
const
  NUM_ITERATIONS = 1000;
var
  i: Integer;
  cpuInfo1, cpuInfo2: TCPUInfo;
begin
  cpuInfo1 := GetCPUInfo;
  
  // 多次调用验证一致性
  for i := 1 to NUM_ITERATIONS do
  begin
    cpuInfo2 := GetCPUInfo;
    
    CheckEqual(cpuInfo1.Vendor, cpuInfo2.Vendor, 'Vendor should be consistent');
    CheckEqual(cpuInfo1.Model, cpuInfo2.Model, 'Model should be consistent');
    
    {$IFDEF SIMD_X86_AVAILABLE}
    CheckEqual(cpuInfo1.X86.HasSSE, cpuInfo2.X86.HasSSE, 'x86 SSE should be consistent');
    CheckEqual(cpuInfo1.X86.HasSSE2, cpuInfo2.X86.HasSSE2, 'x86 SSE2 should be consistent');
    CheckEqual(cpuInfo1.X86.HasAVX, cpuInfo2.X86.HasAVX, 'x86 AVX should be consistent');
    CheckEqual(cpuInfo1.X86.HasAVX2, cpuInfo2.X86.HasAVX2, 'x86 AVX2 should be consistent');
    {$ENDIF}
    
    {$IFDEF SIMD_ARM_AVAILABLE}
    CheckEqual(cpuInfo1.ARM.HasNEON, cpuInfo2.ARM.HasNEON, 'ARM NEON should be consistent');
    CheckEqual(cpuInfo1.ARM.HasAdvSIMD, cpuInfo2.ARM.HasAdvSIMD, 'ARM AdvSIMD should be consistent');
    {$ENDIF}
  end;
end;

procedure TTestFixture_ThreadSafety.Test_GetCPUInfo_Performance;
const
  NUM_CALLS = 10000;
var
  i: Integer;
  cpuInfo: TCPUInfo;
  startTime, endTime: QWord;
  avgTimeNs: Double;
begin
  // 预热
  for i := 1 to 10 do
    cpuInfo := GetCPUInfo;
    
  // 性能测试
  startTime := GetTickCount64;
  for i := 1 to NUM_CALLS do
    cpuInfo := GetCPUInfo;
  endTime := GetTickCount64;
  
  avgTimeNs := ((endTime - startTime) * 1000000.0) / NUM_CALLS;
  
  WriteLn('Average GetCPUInfo time: ', FormatFloat('0.00', avgTimeNs), ' ns');
  
  // 性能要求：每次调用应该小于 10μs
  CheckTrue(avgTimeNs < 10000, 'GetCPUInfo should be fast (< 10μs)');
end;

// === TTestFixture_PlatformSpecific ===

procedure TTestFixture_PlatformSpecific.Test_X86Features;
var
  cpuInfo: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  
  {$IFDEF SIMD_X86_AVAILABLE}
  WriteLn('x86 Features:');
  WriteLn('  SSE: ', cpuInfo.X86.HasSSE);
  WriteLn('  SSE2: ', cpuInfo.X86.HasSSE2);
  WriteLn('  SSE3: ', cpuInfo.X86.HasSSE3);
  WriteLn('  SSSE3: ', cpuInfo.X86.HasSSSE3);
  WriteLn('  SSE4.1: ', cpuInfo.X86.HasSSE41);
  WriteLn('  SSE4.2: ', cpuInfo.X86.HasSSE42);
  WriteLn('  AVX: ', cpuInfo.X86.HasAVX);
  WriteLn('  AVX2: ', cpuInfo.X86.HasAVX2);
  WriteLn('  FMA: ', cpuInfo.X86.HasFMA);
  WriteLn('  AVX512F: ', cpuInfo.X86.HasAVX512F);
  {$ELSE}
  WriteLn('x86 features not available in this build');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_IntrinsicsAVXAvailability_Semantics;
var
  LCPUInfo: TCPUInfo;
  LExpectedAVX: Boolean;
  LExpectedAVX2: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedAVX := LCPUInfo.X86.HasAVX and (gfSimd256 in LCPUInfo.GenericUsable);
    LExpectedAVX2 := LCPUInfo.X86.HasAVX2 and (gfSimd256 in LCPUInfo.GenericUsable);
  end
  else
  begin
    LExpectedAVX := False;
    LExpectedAVX2 := False;
  end;

  CheckEqual(LExpectedAVX, simd_has_avx, 'simd_has_avx should follow AVX usable semantics');
  CheckEqual(LExpectedAVX2, simd_has_avx2, 'simd_has_avx2 should follow AVX2 usable semantics');
  if simd_has_avx2 then
    CheckTrue(simd_has_avx, 'simd_has_avx2 implies simd_has_avx');
  {$ELSE}
  CheckFalse(simd_has_avx, 'simd_has_avx should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx2, 'simd_has_avx2 should be false when x86 cpuinfo is disabled');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_IntrinsicsFacade_FullConsistency;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    CheckEqual(LCPUInfo.X86.HasMMX, simd_has_mmx, 'simd_has_mmx should match x86 MMX flag');
    CheckEqual(LCPUInfo.X86.HasSSE, simd_has_sse, 'simd_has_sse should match x86 SSE flag');
    CheckEqual(LCPUInfo.X86.HasSSE2, simd_has_sse2, 'simd_has_sse2 should match x86 SSE2 flag');
    CheckEqual(LCPUInfo.X86.HasSSE3, simd_has_sse3, 'simd_has_sse3 should match x86 SSE3 flag');
    CheckEqual(LCPUInfo.X86.HasSSE41, simd_has_sse41, 'simd_has_sse41 should match x86 SSE4.1 flag');
    CheckEqual(LCPUInfo.X86.HasSSE42, simd_has_sse42, 'simd_has_sse42 should match x86 SSE4.2 flag');
    CheckEqual(LCPUInfo.X86.HasAVX and (gfSimd256 in LCPUInfo.GenericUsable), simd_has_avx, 'simd_has_avx should match AVX usable semantics');
    CheckEqual(LCPUInfo.X86.HasAVX2 and (gfSimd256 in LCPUInfo.GenericUsable), simd_has_avx2, 'simd_has_avx2 should match AVX2 usable semantics');
    CheckEqual(LCPUInfo.X86.HasAVX512F and (gfSimd512 in LCPUInfo.GenericUsable), simd_has_avx512f, 'simd_has_avx512f should match AVX512 usable semantics');
    CheckEqual(LCPUInfo.X86.HasAES and (gfAES in LCPUInfo.GenericUsable), simd_has_aes, 'simd_has_aes should match AES usable semantics');
    CheckEqual(LCPUInfo.X86.HasSHA and (gfSHA in LCPUInfo.GenericUsable), simd_has_sha, 'simd_has_sha should match SHA usable semantics');
    CheckEqual(LCPUInfo.X86.HasFMA and (gfFMA in LCPUInfo.GenericUsable), simd_has_fma3, 'simd_has_fma3 should match FMA usable semantics');
  end
  else
  begin
    CheckFalse(simd_has_mmx, 'simd_has_mmx should be false on non-x86 arch');
    CheckFalse(simd_has_sse, 'simd_has_sse should be false on non-x86 arch');
    CheckFalse(simd_has_sse2, 'simd_has_sse2 should be false on non-x86 arch');
    CheckFalse(simd_has_sse3, 'simd_has_sse3 should be false on non-x86 arch');
    CheckFalse(simd_has_sse41, 'simd_has_sse41 should be false on non-x86 arch');
    CheckFalse(simd_has_sse42, 'simd_has_sse42 should be false on non-x86 arch');
    CheckFalse(simd_has_avx, 'simd_has_avx should be false on non-x86 arch');
    CheckFalse(simd_has_avx2, 'simd_has_avx2 should be false on non-x86 arch');
    CheckFalse(simd_has_avx512f, 'simd_has_avx512f should be false on non-x86 arch');
    CheckFalse(simd_has_aes, 'simd_has_aes should be false on non-x86 arch');
    CheckFalse(simd_has_sha, 'simd_has_sha should be false on non-x86 arch');
    CheckFalse(simd_has_fma3, 'simd_has_fma3 should be false on non-x86 arch');
  end;
  {$ELSE}
  CheckFalse(simd_has_mmx, 'simd_has_mmx should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_sse, 'simd_has_sse should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_sse2, 'simd_has_sse2 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_sse3, 'simd_has_sse3 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_sse41, 'simd_has_sse41 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_sse42, 'simd_has_sse42 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx, 'simd_has_avx should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx2, 'simd_has_avx2 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx512f, 'simd_has_avx512f should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_aes, 'simd_has_aes should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_sha, 'simd_has_sha should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_fma3, 'simd_has_fma3 should be false when x86 cpuinfo is disabled');
  {$ENDIF}

  if simd_has_fma3 then
    CheckTrue(simd_has_avx, 'simd_has_fma3 implies simd_has_avx');
end;

procedure TTestFixture_PlatformSpecific.Test_BackendFeatureBidirectionalConsistency;
var
  LCPUInfo: TCPUInfo;
  LBackends: TSimdBackendArray;
  LIndex: Integer;
  LExpectedAVX512Backend: Boolean;
begin
  LCPUInfo := GetCPUInfo;
  LBackends := GetSupportedBackends;

  CheckTrue(BackendInArray(sbScalar, LBackends), 'Supported backend list should include Scalar');

  // Direction A: backend list -> availability API must agree
  for LIndex := 0 to High(LBackends) do
    CheckTrue(IsBackendAvailableOnCPU(LBackends[LIndex]), 'Each listed backend must be available on CPU');

  {$IFDEF SIMD_X86_AVAILABLE}
  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedAVX512Backend := X86SupportsAVX512BackendOnCPU(LCPUInfo.X86, gfSimd512 in LCPUInfo.GenericUsable);

    // Direction B1: x86 intrinsics facade -> backend list
    CheckEqual(simd_has_sse2, BackendInArray(sbSSE2, LBackends), 'SSE2 backend presence should match simd_has_sse2');
    CheckEqual(simd_has_avx2, BackendInArray(sbAVX2, LBackends), 'AVX2 backend presence should match simd_has_avx2');
    CheckEqual(LExpectedAVX512Backend, BackendInArray(sbAVX512, LBackends), 'AVX512 backend presence should match backend-supported predicate, not raw simd_has_avx512f semantics');

    // Direction B2: backend list -> x86 intrinsics facade
    if BackendInArray(sbSSE2, LBackends) then
      CheckTrue(simd_has_sse2, 'SSE2 backend listed implies simd_has_sse2');
    if BackendInArray(sbAVX2, LBackends) then
      CheckTrue(simd_has_avx2, 'AVX2 backend listed implies simd_has_avx2');
    if BackendInArray(sbAVX512, LBackends) then
      CheckTrue(LExpectedAVX512Backend, 'AVX512 backend listed implies backend-supported predicate');
  end
  else
  begin
    CheckFalse(BackendInArray(sbSSE2, LBackends), 'x86 SSE2 backend should not appear on non-x86 arch');
    CheckFalse(BackendInArray(sbAVX2, LBackends), 'x86 AVX2 backend should not appear on non-x86 arch');
    CheckFalse(BackendInArray(sbAVX512, LBackends), 'x86 AVX512 backend should not appear on non-x86 arch');
  end;
  {$ELSE}
  CheckFalse(BackendInArray(sbSSE2, LBackends), 'x86 SSE2 backend should not appear when x86 cpuinfo is disabled');
  CheckFalse(BackendInArray(sbAVX2, LBackends), 'x86 AVX2 backend should not appear when x86 cpuinfo is disabled');
  CheckFalse(BackendInArray(sbAVX512, LBackends), 'x86 AVX512 backend should not appear when x86 cpuinfo is disabled');
  {$ENDIF}

  {$IFDEF SIMD_ARM_AVAILABLE}
  if LCPUInfo.Arch = caARM then
    CheckEqual(HasNEON, BackendInArray(sbNEON, LBackends), 'NEON backend presence should match HasNEON');
  {$ENDIF}

  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  if LCPUInfo.Arch = caRISCV then
    CheckEqual(HasRISCVV, BackendInArray(sbRISCVV, LBackends), 'RISCVV backend presence should match HasRISCVV');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_X86RawAVX_RemainsVisible_When_OSXSAVE_Disabled;
{$IFDEF SIMD_X86_AVAILABLE}
var
  LLeaf1: TX86CPUIDRegs;
  LLeaf7: TX86CPUIDRegs;
  LExtLeaf1: TX86CPUIDRegs;
  LFeatures: TX86Features;
  {$if declared(X86GenericRawFeatures)}
  LRaw: TGenericFeatureSet;
  LUsable: TGenericFeatureSet;
  {$endif}
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LLeaf1 := MakeX86CPUIDRegs(
    0,
    0,
    (1 shl 12) or (1 shl 25) or (1 shl 28),
    (1 shl 25) or (1 shl 26)
  );
  LLeaf7 := MakeX86CPUIDRegs(
    0,
    (1 shl 5) or (1 shl 16) or (1 shl 17) or (1 shl 29) or (1 shl 30) or (1 shl 31),
    (1 shl 1),
    0
  );
  LExtLeaf1 := MakeX86CPUIDRegs(0, 0, 0, 0);

  LFeatures := X86FeaturesFromCPUID(7, 0, LLeaf1, LLeaf7, LExtLeaf1, 0);
  {$if declared(X86GenericRawFeatures)}
  LRaw := X86GenericRawFeatures(LFeatures);
  LUsable := X86GenericUsableFeatures(LFeatures, False, 0);
  {$endif}

  CheckTrue(LFeatures.HasAVX, 'raw AVX should remain visible without OSXSAVE');
  CheckTrue(LFeatures.HasAVX2, 'raw AVX2 should remain visible without OSXSAVE');
  CheckTrue(LFeatures.HasFMA, 'raw FMA should remain visible without OSXSAVE');
  CheckTrue(LFeatures.HasAVX512F, 'raw AVX512F should remain visible without OSXSAVE');
  CheckTrue(LFeatures.HasAVX512BW, 'raw AVX512BW should remain visible without OSXSAVE');
  {$if declared(X86GenericRawFeatures)}
  CheckTrue(gfSimd256 in LRaw, 'GenericRaw should include SIMD-256 when raw AVX/AVX2 exists');
  CheckTrue(gfSimd512 in LRaw, 'GenericRaw should include SIMD-512 when raw AVX512F exists');
  CheckTrue(gfFMA in LRaw, 'GenericRaw should include FMA when raw FMA exists');
  CheckFalse(gfSimd256 in LUsable, 'GenericUsable should gate SIMD-256 without OSXSAVE');
  CheckFalse(gfSimd512 in LUsable, 'GenericUsable should gate SIMD-512 without OSXSAVE');
  CheckFalse(gfFMA in LUsable, 'GenericUsable should gate FMA without OSXSAVE');
  {$endif}
  {$ELSE}
  Skip('x86 raw AVX OSXSAVE fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_X86RawAVX_RemainsVisible_When_XCR0_Disabled;
{$IFDEF SIMD_X86_AVAILABLE}
var
  LLeaf1: TX86CPUIDRegs;
  LLeaf7: TX86CPUIDRegs;
  LExtLeaf1: TX86CPUIDRegs;
  LFeatures: TX86Features;
  {$if declared(X86GenericRawFeatures)}
  LRaw: TGenericFeatureSet;
  LUsable: TGenericFeatureSet;
  {$endif}
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LLeaf1 := MakeX86CPUIDRegs(
    0,
    0,
    (1 shl 12) or (1 shl 27) or (1 shl 28),
    (1 shl 25) or (1 shl 26)
  );
  LLeaf7 := MakeX86CPUIDRegs(
    0,
    (1 shl 5) or (1 shl 16) or (1 shl 17) or (1 shl 30) or (1 shl 31),
    (1 shl 1),
    0
  );
  LExtLeaf1 := MakeX86CPUIDRegs(0, 0, 0, 0);

  LFeatures := X86FeaturesFromCPUID(7, 0, LLeaf1, LLeaf7, LExtLeaf1, 0);
  {$if declared(X86GenericRawFeatures)}
  LRaw := X86GenericRawFeatures(LFeatures);
  LUsable := X86GenericUsableFeatures(LFeatures, True, 0);
  {$endif}

  CheckTrue(LFeatures.HasAVX, 'raw AVX should remain visible when XCR0 lacks XMM/YMM');
  CheckTrue(LFeatures.HasAVX2, 'raw AVX2 should remain visible when XCR0 lacks XMM/YMM');
  CheckTrue(LFeatures.HasFMA, 'raw FMA should remain visible when XCR0 lacks XMM/YMM');
  CheckTrue(LFeatures.HasAVX512F, 'raw AVX512F should remain visible when XCR0 lacks ZMM state');
  {$if declared(X86GenericRawFeatures)}
  CheckTrue(gfSimd256 in LRaw, 'GenericRaw should include SIMD-256 when XCR0 disables execution');
  CheckTrue(gfSimd512 in LRaw, 'GenericRaw should include SIMD-512 when XCR0 disables execution');
  CheckTrue(gfFMA in LRaw, 'GenericRaw should include FMA when XCR0 disables execution');
  CheckFalse(gfSimd256 in LUsable, 'GenericUsable should gate SIMD-256 when XCR0 lacks XMM/YMM');
  CheckFalse(gfSimd512 in LUsable, 'GenericUsable should gate SIMD-512 when XCR0 lacks ZMM state');
  CheckFalse(gfFMA in LUsable, 'GenericUsable should gate FMA when XCR0 lacks XMM/YMM');
  {$endif}
  {$ELSE}
  Skip('x86 raw AVX XCR0 fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_X86UsableAVX_FailCloses_When_AVX2_Without_AVX;
{$IFDEF SIMD_X86_AVAILABLE}
var
  LLeaf1: TX86CPUIDRegs;
  LLeaf7: TX86CPUIDRegs;
  LExtLeaf1: TX86CPUIDRegs;
  LFeatures: TX86Features;
  LRaw: TGenericFeatureSet;
  LUsable: TGenericFeatureSet;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LLeaf1 := MakeX86CPUIDRegs(
    0,
    0,
    (1 shl 12) or (1 shl 23) or (1 shl 27),
    (1 shl 25) or (1 shl 26)
  );
  LLeaf7 := MakeX86CPUIDRegs(
    0,
    (1 shl 5) or (1 shl 16) or (1 shl 30),
    0,
    0
  );
  LExtLeaf1 := MakeX86CPUIDRegs(0, 0, 0, 0);

  LFeatures := X86FeaturesFromCPUID(7, 0, LLeaf1, LLeaf7, LExtLeaf1, 0);
  LRaw := X86GenericRawFeatures(LFeatures);
  LUsable := X86GenericUsableFeatures(LFeatures, True, (UInt64(1) shl 1) or (UInt64(1) shl 2));

  CheckFalse(LFeatures.HasAVX, 'raw AVX should remain false in malformed AVX2-only CPUID fixture');
  CheckTrue(LFeatures.HasAVX2, 'raw AVX2 should remain visible in malformed CPUID fixture');
  CheckTrue(LFeatures.HasFMA, 'raw FMA should remain visible in malformed CPUID fixture');
  CheckTrue(gfSimd256 in LRaw, 'GenericRaw should preserve SIMD-256 when raw AVX2 exists');
  CheckTrue(gfFMA in LRaw, 'GenericRaw should preserve FMA when raw FMA exists');
  CheckFalse(gfSimd256 in LUsable, 'GenericUsable should fail-close SIMD-256 when raw AVX prerequisite is missing');
  CheckFalse(gfFMA in LUsable, 'GenericUsable should fail-close FMA when raw AVX prerequisite is missing');
  CheckFalse(X86SupportsAVX512BackendOnCPU(LFeatures, True), 'AVX-512 backend helper should fail-close when only raw AVX prerequisite is missing');
  {$ELSE}
  Skip('x86 malformed AVX2-only fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_X86UsableAVX512_FailCloses_When_AVX512F_Without_AVX2;
{$IFDEF SIMD_X86_AVAILABLE}
var
  LLeaf1: TX86CPUIDRegs;
  LLeaf7: TX86CPUIDRegs;
  LExtLeaf1: TX86CPUIDRegs;
  LFeatures: TX86Features;
  LRaw: TGenericFeatureSet;
  LUsable: TGenericFeatureSet;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LLeaf1 := MakeX86CPUIDRegs(
    0,
    0,
    (1 shl 12) or (1 shl 27) or (1 shl 28),
    (1 shl 23) or (1 shl 25) or (1 shl 26)
  );
  LLeaf7 := MakeX86CPUIDRegs(
    0,
    (1 shl 16) or (1 shl 30),
    0,
    0
  );
  LExtLeaf1 := MakeX86CPUIDRegs(0, 0, 0, 0);

  LFeatures := X86FeaturesFromCPUID(7, 0, LLeaf1, LLeaf7, LExtLeaf1, 0);
  LRaw := X86GenericRawFeatures(LFeatures);
  LUsable := X86GenericUsableFeatures(
    LFeatures,
    True,
    (UInt64(1) shl 1) or (UInt64(1) shl 2) or
    (UInt64(1) shl 5) or (UInt64(1) shl 6) or (UInt64(1) shl 7)
  );

  CheckTrue(LFeatures.HasAVX, 'raw AVX should remain visible in malformed AVX512F-only fixture');
  CheckFalse(LFeatures.HasAVX2, 'raw AVX2 should remain false in malformed AVX512F-only fixture');
  CheckTrue(LFeatures.HasAVX512F, 'raw AVX512F should remain visible in malformed AVX512F-only fixture');
  CheckTrue(gfSimd512 in LRaw, 'GenericRaw should preserve SIMD-512 when raw AVX512F exists');
  CheckFalse(gfSimd512 in LUsable, 'GenericUsable should fail-close SIMD-512 when raw AVX2 prerequisite is missing');
  CheckFalse(X86SupportsAVX512BackendOnCPU(LFeatures, True), 'AVX-512 backend helper should fail-close when raw AVX2 prerequisite is missing');
  {$ELSE}
  Skip('x86 malformed AVX512F-only fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_AVXUsable_XCR0Semantics;
var
  LCPUInfo: TCPUInfo;
  LExpectedUsable256: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedUsable256 := LCPUInfo.X86.HasAVX and LCPUInfo.OSXSAVE and XCR0EnablesAVX_Local(LCPUInfo);
    CheckEqual(LExpectedUsable256, gfSimd256 in LCPUInfo.GenericUsable, 'gfSimd256 usable should follow AVX XCR0 semantics');
    CheckEqual(LCPUInfo.X86.HasAVX2 and LExpectedUsable256, nextpas.core.simd.cpuinfo.HasAVX2, 'HasAVX2 should match AVX2 usable semantics');
    CheckEqual(LCPUInfo.X86.HasAVX2 and LExpectedUsable256, nextpas.core.simd.cpuinfo.x86.HasAVX2, 'legacy x86 HasAVX2 should match AVX2 usable semantics');
    CheckEqual(LCPUInfo.X86.HasAVX and LExpectedUsable256, simd_has_avx, 'simd_has_avx should match AVX usable semantics');
    CheckEqual(LCPUInfo.X86.HasAVX2 and LExpectedUsable256, simd_has_avx2, 'simd_has_avx2 should match AVX2 usable semantics');
  end
  else
  begin
    CheckFalse(nextpas.core.simd.cpuinfo.HasAVX2, 'HasAVX2 should be false on non-x86 arch');
    CheckFalse(simd_has_avx, 'simd_has_avx should be false on non-x86 arch');
    CheckFalse(simd_has_avx2, 'simd_has_avx2 should be false on non-x86 arch');
  end;
  {$ELSE}
  CheckFalse(nextpas.core.simd.cpuinfo.HasAVX2, 'HasAVX2 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx, 'simd_has_avx should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx2, 'simd_has_avx2 should be false when x86 cpuinfo is disabled');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_AVX512Usable_XCR0Semantics;
var
  LCPUInfo: TCPUInfo;
  LExpectedUsable: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedUsable := LCPUInfo.X86.HasAVX and LCPUInfo.X86.HasAVX2 and LCPUInfo.X86.HasAVX512F and LCPUInfo.OSXSAVE and XCR0EnablesAVX512_Local(LCPUInfo);
    CheckEqual(LExpectedUsable, gfSimd512 in LCPUInfo.GenericUsable, 'gfSimd512 usable should follow AVX-512 XCR0 semantics');
    CheckEqual(LExpectedUsable, nextpas.core.simd.cpuinfo.HasAVX512, 'HasAVX512 should match AVX-512 usable semantics');
    CheckEqual(LExpectedUsable, simd_has_avx512f, 'simd_has_avx512f should match AVX-512 usable semantics');
  end
  else
  begin
    CheckFalse(nextpas.core.simd.cpuinfo.HasAVX512, 'HasAVX512 should be false on non-x86 arch');
    CheckFalse(simd_has_avx512f, 'simd_has_avx512f should be false on non-x86 arch');
  end;
  {$ELSE}
  CheckFalse(nextpas.core.simd.cpuinfo.HasAVX512, 'HasAVX512 should be false when x86 cpuinfo is disabled');
  CheckFalse(simd_has_avx512f, 'simd_has_avx512f should be false when x86 cpuinfo is disabled');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_DiagnosticReport_UsableViewConsistency;
var
  LReport: TCPUInfoDiagnosticReport;
  LExpectedUsable256: Boolean;
  LExpectedUsable512: Boolean;
begin
  LReport := GenerateDiagnosticReport;

  CheckEqual(ValidateCPUInfo(LReport.CPUInfo), LReport.ValidationPassed, 'Diagnostic report validation should match ValidateCPUInfo');
  CheckEqual(nextpas.core.simd.cpuinfo.HasFeature(gfSimd128), gfSimd128 in LReport.CPUInfo.GenericUsable, 'HasFeature(gfSimd128) should match report GenericUsable');
  CheckEqual(nextpas.core.simd.cpuinfo.HasFeature(gfSimd256), gfSimd256 in LReport.CPUInfo.GenericUsable, 'HasFeature(gfSimd256) should match report GenericUsable');
  CheckEqual(nextpas.core.simd.cpuinfo.HasFeature(gfSimd512), gfSimd512 in LReport.CPUInfo.GenericUsable, 'HasFeature(gfSimd512) should match report GenericUsable');
  CheckEqual(nextpas.core.simd.cpuinfo.HasFeature(gfAES), gfAES in LReport.CPUInfo.GenericUsable, 'HasFeature(gfAES) should match report GenericUsable');
  CheckEqual(nextpas.core.simd.cpuinfo.HasFeature(gfSHA), gfSHA in LReport.CPUInfo.GenericUsable, 'HasFeature(gfSHA) should match report GenericUsable');
  CheckEqual(nextpas.core.simd.cpuinfo.HasFeature(gfFMA), gfFMA in LReport.CPUInfo.GenericUsable, 'HasFeature(gfFMA) should match report GenericUsable');

  {$IFDEF SIMD_X86_AVAILABLE}
  if LReport.CPUInfo.Arch = caX86 then
  begin
    LExpectedUsable256 := LReport.CPUInfo.X86.HasAVX and LReport.CPUInfo.OSXSAVE and XCR0EnablesAVX_Local(LReport.CPUInfo);
    LExpectedUsable512 := LReport.CPUInfo.X86.HasAVX and LReport.CPUInfo.X86.HasAVX2 and LReport.CPUInfo.X86.HasAVX512F and LReport.CPUInfo.OSXSAVE and XCR0EnablesAVX512_Local(LReport.CPUInfo);
    CheckEqual(LExpectedUsable256, gfSimd256 in LReport.CPUInfo.GenericUsable, 'Diagnostic report SIMD-256 usable should follow AVX XCR0 semantics');
    CheckEqual(LExpectedUsable512, gfSimd512 in LReport.CPUInfo.GenericUsable, 'Diagnostic report SIMD-512 usable should follow AVX-512 XCR0 semantics');
  end;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_ARMFeatures;
var
  cpuInfo: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  
  {$IFDEF SIMD_ARM_AVAILABLE}
  WriteLn('ARM Features:');
  WriteLn('  NEON: ', cpuInfo.ARM.HasNEON);
  WriteLn('  AdvSIMD: ', cpuInfo.ARM.HasAdvSIMD);
  WriteLn('  FP: ', cpuInfo.ARM.HasFP);
  WriteLn('  SVE: ', cpuInfo.ARM.HasSVE);
  WriteLn('  Crypto: ', cpuInfo.ARM.HasCrypto);
  
  {$IFDEF CPUAARCH64}
  // AArch64 上 NEON 是强制的
  CheckTrue(cpuInfo.ARM.HasNEON, 'NEON should be available on AArch64');
  CheckTrue(cpuInfo.ARM.HasAdvSIMD, 'AdvSIMD should be available on AArch64');
  {$ENDIF}

  if cpuInfo.Arch = caARM then
  begin
    CheckEqual(cpuInfo.ARM.HasCrypto, gfAES in cpuInfo.GenericRaw, 'ARM crypto capability should map to GenericRaw AES flag');
    CheckEqual(cpuInfo.ARM.HasCrypto, gfSHA in cpuInfo.GenericRaw, 'ARM crypto capability should map to GenericRaw SHA flag');
    CheckEqual(cpuInfo.ARM.HasCrypto, gfAES in cpuInfo.GenericUsable, 'ARM crypto capability should map to GenericUsable AES flag');
    CheckEqual(cpuInfo.ARM.HasCrypto, gfSHA in cpuInfo.GenericUsable, 'ARM crypto capability should map to GenericUsable SHA flag');
  end;
  {$ELSE}
  WriteLn('ARM features not available in this build');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_LoongArchFeatures;
var
  LCPUInfo: TCPUInfo;
begin
  LCPUInfo := GetCPUInfo;

  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  if LCPUInfo.Arch = caLoongArch then
  begin
    WriteLn('LoongArch Features:');
    WriteLn('  LASX: ', LCPUInfo.LoongArch.HasLASX);
    CheckEqual(LCPUInfo.LoongArch.HasLASX, HasLASX, 'HasLASX should match cpuinfo record');
    CheckEqual(LCPUInfo.LoongArch.HasLASX, gfSimd256 in LCPUInfo.GenericUsable, 'LoongArch LASX capability should map to GenericUsable SIMD-256 flag');
  end
  else
    CheckFalse(HasLASX, 'HasLASX should be false on non-LoongArch arch');
  {$ELSE}
  CheckFalse(HasLASX, 'HasLASX should be false when loongarch cpuinfo is disabled');
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_ARMFeatureParserSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LFeatures: TARMFeatures;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  LFeatures := ParseARMFeaturesFromCpuInfo(
    'Features : fp asimd sve aes sha1 sha2 crc32' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'Features key should set AdvSIMD through asimd');
  CheckTrue(LFeatures.HasNEON, 'Features key should set NEON through asimd');
  CheckTrue(LFeatures.HasFP, 'Features key should set FP');
  CheckTrue(LFeatures.HasSVE, 'Features key should set SVE');
  CheckTrue(LFeatures.HasCrypto, 'Features key should set crypto from aes/sha*');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'flags = ASIMD,FP,SVE2,AES,SHA512' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'flags key should parse asimd');
  CheckTrue(LFeatures.HasFP, 'flags key should parse fp');
  CheckTrue(LFeatures.HasSVE, 'flags key should parse sve2 as SVE capability');
  CheckTrue(LFeatures.HasCrypto, 'flags key should parse crypto tokens');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'cpu features : neon vfpv4 pmull' + LineEnding
  );
  CheckTrue(LFeatures.HasNEON, 'cpu features key should parse neon');
  CheckTrue(LFeatures.HasAdvSIMD, 'cpu features key should map neon to AdvSIMD');
  CheckTrue(LFeatures.HasFP, 'cpu features key should parse vfpv4 as FP');
  CheckTrue(LFeatures.HasCrypto, 'cpu features key should parse pmull as crypto');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'extensions = asimdrdm sha256 aesce pmull2' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'extensions key should parse asimdrdm as AdvSIMD');
  CheckTrue(LFeatures.HasNEON, 'extensions key should map asimdrdm to NEON');
  CheckTrue(LFeatures.HasCrypto, 'extensions key should parse sha*/aes*/pmull* as crypto');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'cpu feature(s) : asimd fp' + LineEnding +
    'isa extension(s) : sve sha256' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'cpu feature(s) key should parse asimd as AdvSIMD');
  CheckTrue(LFeatures.HasNEON, 'cpu feature(s) key should map asimd to NEON');
  CheckTrue(LFeatures.HasFP, 'cpu feature(s) key should parse fp');
  CheckTrue(LFeatures.HasSVE, 'isa extension(s) key should parse sve');
  CheckTrue(LFeatures.HasCrypto, 'isa extension(s) key should parse crypto tokens');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'features : shaoxing shanghai' + LineEnding
  );
  CheckFalse(LFeatures.HasCrypto, 'non-feature sha* words should not imply crypto');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'features : sha256sum sha3extra' + LineEnding
  );
  CheckFalse(LFeatures.HasCrypto, 'prefix-only sha* tokens should not imply crypto');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'features : aesop pmuller' + LineEnding
  );
  CheckFalse(LFeatures.HasCrypto, 'non-feature aes*/pmull* words should not imply crypto');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'isa_ext: asimddp fphp' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'isa_ext key should parse asimd* as AdvSIMD');
  CheckTrue(LFeatures.HasNEON, 'isa_ext key should map asimd* to NEON');
  CheckTrue(LFeatures.HasFP, 'isa_ext key should parse fphp as FP');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'cpu feature = asimdhp' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'cpu feature key should parse asimdhp as AdvSIMD');
  CheckTrue(LFeatures.HasNEON, 'cpu feature key should map asimdhp to NEON');
  CheckTrue(LFeatures.HasFP, 'cpu feature key should parse asimdhp as FP');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'model name : superfastprocessor' + LineEnding +
    'hardware : sample-board' + LineEnding
  );
  CheckFalse(LFeatures.HasNEON, 'non-feature keys should not imply NEON');
  CheckFalse(LFeatures.HasFP, 'non-feature keys should not imply FP');
  CheckFalse(LFeatures.HasSVE, 'non-feature keys should not imply SVE');
  CheckFalse(LFeatures.HasCrypto, 'non-feature keys should not imply crypto');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'model name : Cortex-A55 sha256 edition' + LineEnding +
    'hardware : asimd fp board' + LineEnding
  );
  CheckFalse(LFeatures.HasNEON, 'metadata key values should not imply NEON in fallback mode');
  CheckFalse(LFeatures.HasAdvSIMD, 'metadata key values should not imply AdvSIMD in fallback mode');
  CheckFalse(LFeatures.HasFP, 'metadata key values should not imply FP in fallback mode');
  CheckFalse(LFeatures.HasCrypto, 'metadata key values should not imply crypto in fallback mode');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'capabilities : asimd fp sve sha256 pmull2' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'capabilities key should parse as fallback feature-like key (asimd)');
  CheckTrue(LFeatures.HasNEON, 'capabilities key should map asimd to NEON');
  CheckTrue(LFeatures.HasFP, 'capabilities key should parse fp');
  CheckTrue(LFeatures.HasSVE, 'capabilities key should parse sve');
  CheckTrue(LFeatures.HasCrypto, 'capabilities key should parse crypto tokens');

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'caps asimd fp' + LineEnding +
    'caps2 sve sha256 pmull' + LineEnding
  );
  CheckTrue(LFeatures.HasAdvSIMD, 'fallback text parser should handle multi-line asimd token');
  CheckTrue(LFeatures.HasNEON, 'fallback text parser should map asimd to NEON');
  CheckTrue(LFeatures.HasFP, 'fallback text parser should parse FP token');
  CheckTrue(LFeatures.HasSVE, 'fallback text parser should parse SVE token');
  CheckTrue(LFeatures.HasCrypto, 'fallback text parser should parse crypto tokens');
  {$ELSE}
  Skip('ARM feature parser samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_ARMHWCAPMergeSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LFeatures: TARMFeatures;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  {$IFDEF LINUX}
  {$IFDEF CPUAARCH64}
  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, (QWord(1) shl 0) or (QWord(1) shl 1), 0);
  CheckTrue(LFeatures.HasFP, 'AArch64 HWCAP FP bit should set FP');
  CheckTrue(LFeatures.HasNEON, 'AArch64 HWCAP ASIMD bit should set NEON');
  CheckTrue(LFeatures.HasAdvSIMD, 'AArch64 HWCAP ASIMD bit should set AdvSIMD');

  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, QWord(1) shl 22, 0);
  CheckTrue(LFeatures.HasSVE, 'AArch64 HWCAP SVE bit should set SVE');

  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, QWord(1) shl 3, 0);
  CheckTrue(LFeatures.HasCrypto, 'AArch64 HWCAP AES bit should set Crypto');
  {$ELSE}
  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, (QWord(1) shl 6) or (QWord(1) shl 12), 0);
  CheckTrue(LFeatures.HasFP, 'ARM32 HWCAP VFP bit should set FP');
  CheckTrue(LFeatures.HasNEON, 'ARM32 HWCAP NEON bit should set NEON');
  CheckTrue(LFeatures.HasAdvSIMD, 'ARM32 HWCAP NEON bit should set AdvSIMD');

  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, 0, (QWord(1) shl 0) or (QWord(1) shl 3));
  CheckTrue(LFeatures.HasCrypto, 'ARM32 HWCAP2 AES/SHA2 bits should set Crypto');
  {$ENDIF}
  {$ELSE}
  Skip('ARM HWCAP merge samples skipped on non-Linux');
  Exit;
  {$ENDIF}
  {$ELSE}
  Skip('ARM HWCAP merge samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_ARMVendorModelParserSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LVendor: string;
  LModel: string;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  CheckTrue(ParseARMVendorFromCpuInfo( 'CPU implementer : 0x41' + LineEnding + 'model name : Cortex-A76' + LineEnding, LVendor, LModel ), 'ARM vendor/model parser should accept implementer + model name');
  CheckEqual('0x41', LVendor, 'implementer should be parsed as vendor candidate');
  CheckEqual('Cortex-A76', LModel, 'model name should be parsed as model candidate');

  CheckTrue(ParseARMVendorFromCpuInfo( 'processor : 0' + LineEnding + 'processor : 1' + LineEnding + 'vendor = Qualcomm' + LineEnding + 'cpu model = Kryo 680' + LineEnding, LVendor, LModel ), 'ARM vendor/model parser should ignore numeric processor index and keep stronger cpu model');
  CheckEqual('Qualcomm', LVendor, 'vendor key should be parsed');
  CheckEqual('Kryo 680', LModel, 'cpu model should win over numeric processor index');

  CheckTrue(ParseARMVendorFromCpuInfo( 'processor : 0x0' + LineEnding + 'processor : $1' + LineEnding + 'vendor : ARM-LAB' + LineEnding, LVendor, LModel ), 'ARM vendor/model parser should ignore hex/$ processor indexes and keep vendor-only identity');
  CheckEqual('ARM-LAB', LVendor, 'vendor should still be parsed with hex/$ processor indexes');
  CheckEqual('', LModel, 'hex/$ processor indexes should not be promoted as model');

  CheckTrue(ParseARMVendorFromCpuInfo( 'cpu implementer : 0x51' + LineEnding + 'vendor : override-ignored' + LineEnding + 'model name : FirstModel' + LineEnding + 'cpu model : SecondModel' + LineEnding, LVendor, LModel ), 'same-priority ARM identity keys should keep first non-empty candidate');
  CheckEqual('0x51', LVendor, 'first same-priority vendor should be preserved');
  CheckEqual('FirstModel', LModel, 'first same-priority model should be preserved');

  CheckTrue(ParseARMVendorFromCpuInfo( 'processor : ARMv7 Processor rev 3 (v7l)' + LineEnding, LVendor, LModel ), 'non-numeric processor value can be used as weak model fallback');
  CheckEqual('', LVendor, 'processor fallback should not invent vendor');
  CheckEqual('ARMv7 Processor rev 3 (v7l)', LModel, 'processor fallback should provide model text');

  CheckFalse(ParseARMVendorFromCpuInfo( 'processor : 0' + LineEnding + 'processor : 0x1' + LineEnding + 'processor : $2' + LineEnding, LVendor, LModel ), 'numeric processor index variants alone should not produce ARM vendor/model');
  CheckEqual('', LVendor, 'vendor should stay empty when only numeric processor indexes exist');
  CheckEqual('', LModel, 'model should stay empty when only numeric processor indexes exist');

  CheckFalse(ParseARMVendorFromCpuInfo( 'Features : fp asimd sve' + LineEnding + 'BogoMIPS : 48.00' + LineEnding, LVendor, LModel ), 'non-identity cpuinfo lines should not produce ARM vendor/model');
  CheckEqual('', LVendor, 'vendor should stay empty without identity keys');
  CheckEqual('', LModel, 'model should stay empty without identity keys');
  {$ELSE}
  Skip('ARM vendor/model parser samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_ARMProcessorInfoBasic;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LInfo: TARMProcessorInfo;
  LInstructionSet: string;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  LInfo := GetARMProcessorInfo;
  LInstructionSet := UpperCase(Trim(LInfo.InstructionSet));

  CheckTrue(Trim(LInfo.Architecture) <> '', 'ARM processor architecture should not be empty');
  CheckTrue(LInstructionSet <> '', 'ARM processor instruction set should not be empty');
  CheckTrue(Trim(LInfo.CoreType) <> '', 'ARM processor core type should not be empty');

  {$IFDEF CPUAARCH64}
  CheckEqual('AArch64', LInfo.Architecture, 'AArch64 build should report AArch64 architecture');
  CheckTrue(Pos('ARMV8', LInstructionSet) = 1, 'AArch64 build should report ARMv8+ instruction set');
  {$ELSE}
  CheckEqual('AArch32', LInfo.Architecture, 'ARM32 build should report AArch32 architecture');
  CheckTrue(Pos('ARMV', LInstructionSet) = 1, 'ARM32 build should report ARMv* instruction set');
  {$ENDIF}
  {$ELSE}
  Skip('ARM processor info test skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_ARMProcessorInfoParserSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LInstructionSet: string;
  LCoreType: string;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  CheckTrue(ParseARMProcessorInfoFromCpuInfo( 'cpu architecture : 8' + LineEnding + 'model name : ARM Cortex-A72' + LineEnding, LInstructionSet, LCoreType ), 'cpu architecture numeric value + model name should be parsed deterministically');
  CheckEqual('ARMv8-A', LInstructionSet, 'cpu architecture numeric value should map to ARMv8-A');
  CheckEqual('Cortex-A', LCoreType, 'model name should map cortex-a family to Cortex-A');

  CheckTrue(ParseARMProcessorInfoFromCpuInfo( 'isa : armv9-a+sve2' + LineEnding + 'uarch : Neoverse-V2' + LineEnding, LInstructionSet, LCoreType ), 'isa string should drive instruction set and neoverse model should drive core type');
  CheckEqual('ARMv9-A', LInstructionSet, 'armv9 isa text should normalize to ARMv9-A');
  CheckEqual('Neoverse', LCoreType, 'neoverse text should normalize to Neoverse');

  CheckTrue(ParseARMProcessorInfoFromCpuInfo( 'model name : ARMv7 Processor rev 4 (v7l)' + LineEnding, LInstructionSet, LCoreType ), 'model name should provide ARMv7 fallback when dedicated ISA keys are absent');
  CheckEqual('ARMv7-A', LInstructionSet, 'ARMv7 model fallback should normalize to ARMv7-A');
  CheckEqual('', LCoreType, 'model fallback without known core family should keep core type empty');

  CheckTrue(ParseARMProcessorInfoFromCpuInfo( 'arch=arm64' + LineEnding + 'cpu model=Kryo 780' + LineEnding, LInstructionSet, LCoreType ), 'key=value arch and cpu model should be parsed');
  CheckEqual('ARMv8-A', LInstructionSet, 'arm64 arch should normalize to ARMv8-A');
  CheckEqual('Kryo', LCoreType, 'kryo model should normalize to Kryo core type');

  CheckTrue(ParseARMProcessorInfoFromCpuInfo( 'uarch : Neoverse-V2' + LineEnding, LInstructionSet, LCoreType ), 'uarch-only Neoverse token should provide core type without inventing low ISA version');
  CheckEqual('', LInstructionSet, 'uarch-only Neoverse token should not invent ARMv2 ISA');
  CheckEqual('Neoverse', LCoreType, 'uarch-only Neoverse token should normalize core type');

  CheckFalse(ParseARMProcessorInfoFromCpuInfo( 'processor : 0' + LineEnding + 'processor : 1' + LineEnding, LInstructionSet, LCoreType ), 'numeric processor index lines should not produce instruction set/core type alone');
  CheckEqual('', LInstructionSet, 'numeric processor-only sample should keep instruction set empty');
  CheckEqual('', LCoreType, 'numeric processor-only sample should keep core type empty');
  {$ELSE}
  Skip('ARM processor info parser samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_CacheSizeParserSamples;
begin
  CheckEqual(0, ParseCacheSizeTextToKB(''), 'empty text should parse to 0');
  CheckEqual(0, ParseCacheSizeTextToKB('   '), 'whitespace-only text should parse to 0');
  CheckEqual(0, ParseCacheSizeTextToKB('0'), 'zero bytes should parse to 0');
  CheckEqual(0, ParseCacheSizeTextToKB('-1K'), 'negative value should parse to 0');
  CheckEqual(32, ParseCacheSizeTextToKB('32K'), '32K should parse to 32KB');
  CheckEqual(32, ParseCacheSizeTextToKB('32KB'), '32KB should parse to 32KB');
  CheckEqual(32, ParseCacheSizeTextToKB('32KiB'), '32KiB should parse to 32KB');
  CheckEqual(64, ParseCacheSizeTextToKB('64kIb'), 'mixed-case KiB should parse to 64KB');
  CheckEqual(64, ParseCacheSizeTextToKB(' 64 KiB '), 'space-padded unit should parse to 64KB');
  CheckEqual(1024, ParseCacheSizeTextToKB('1M'), '1M should parse to 1024KB');
  CheckEqual(1024, ParseCacheSizeTextToKB('1MiB'), '1MiB should parse to 1024KB');
  CheckEqual(1024, ParseCacheSizeTextToKB('1 MB'), 'space-padded MB should parse to 1024KB');
  CheckEqual(1024 * 1024, ParseCacheSizeTextToKB('1G'), '1G should parse to 1048576KB');
  CheckEqual(1024 * 1024, ParseCacheSizeTextToKB('1GiB'), '1GiB should parse to 1048576KB');
  CheckEqual(2, ParseCacheSizeTextToKB('2048'), 'bare number should be treated as bytes and ceil to KB');
  CheckEqual(32, ParseCacheSizeTextToKB('32768'), '32768 bytes should parse to 32KB');
  CheckEqual(32, ParseCacheSizeTextToKB('32768B'), '32768B should parse to 32KB');
  CheckEqual(1, ParseCacheSizeTextToKB('1024B'), '1024B should parse to 1KB');
  CheckEqual(2, ParseCacheSizeTextToKB('1025B'), '1025B should ceil to 2KB');
  CheckEqual(2, ParseCacheSizeTextToKB('1536B'), '1536B should ceil to 2KB');
  CheckEqual(0, ParseCacheSizeTextToKB('invalid'), 'invalid size should parse to 0');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('3000000000K'), 'large K value should saturate to Integer max');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('3000000M'), 'large M value should saturate to Integer max');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('5000G'), 'large G value should saturate to Integer max');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('9223372036854775807B'), 'huge byte value should saturate to Integer max');
end;

procedure TTestFixture_PlatformSpecific.Test_NonX86CacheInfoOnLinux;
var
  LCPUInfo: TCPUInfo;
  LLazyCPUInfo: TCPUInfo;
  LExpectedCache: TCacheInfo;
  LHasSnapshot: Boolean;
begin
  {$IFDEF LINUX}
  LCPUInfo := GetCPUInfo;
  if not (LCPUInfo.Arch in [caARM, caRISCV, caLoongArch]) then
    Exit;

  CheckTrue(LCPUInfo.Cache.LineSize > 0, 'Non-x86 cache line size should be positive');

  LHasSnapshot := ReadLinuxSysfsCacheSnapshot(LExpectedCache);
  if LHasSnapshot then
  begin
    if LExpectedCache.LineSize > 0 then
      CheckEqual(LExpectedCache.LineSize, LCPUInfo.Cache.LineSize, 'Non-x86 cache line size should match Linux sysfs snapshot');
    if LExpectedCache.L1DataKB > 0 then
      CheckEqual(LExpectedCache.L1DataKB, LCPUInfo.Cache.L1DataKB, 'Non-x86 L1 data cache should match Linux sysfs snapshot');
    if LExpectedCache.L1InstrKB > 0 then
      CheckEqual(LExpectedCache.L1InstrKB, LCPUInfo.Cache.L1InstrKB, 'Non-x86 L1 instruction cache should match Linux sysfs snapshot');
    if LExpectedCache.L2KB > 0 then
      CheckEqual(LExpectedCache.L2KB, LCPUInfo.Cache.L2KB, 'Non-x86 L2 cache should match Linux sysfs snapshot');
    if LExpectedCache.L3KB > 0 then
      CheckEqual(LExpectedCache.L3KB, LCPUInfo.Cache.L3KB, 'Non-x86 L3 cache should match Linux sysfs snapshot');
  end;

  LazyCPUInfo.Reset;
  LLazyCPUInfo := GetCPUInfoLazy;
  CheckEqual(LCPUInfo.Vendor, LLazyCPUInfo.Vendor, 'Lazy/eager non-x86 vendor should match');
  CheckEqual(LCPUInfo.Model, LLazyCPUInfo.Model, 'Lazy/eager non-x86 model should match');
  CheckEqual(LCPUInfo.Cache.LineSize, LLazyCPUInfo.Cache.LineSize, 'Lazy/eager non-x86 cache line size should match');
  CheckEqual(LCPUInfo.Cache.L1DataKB, LLazyCPUInfo.Cache.L1DataKB, 'Lazy/eager non-x86 L1 data cache should match');
  CheckEqual(LCPUInfo.Cache.L1InstrKB, LLazyCPUInfo.Cache.L1InstrKB, 'Lazy/eager non-x86 L1 instruction cache should match');
  CheckEqual(LCPUInfo.Cache.L2KB, LLazyCPUInfo.Cache.L2KB, 'Lazy/eager non-x86 L2 cache should match');
  CheckEqual(LCPUInfo.Cache.L3KB, LLazyCPUInfo.Cache.L3KB, 'Lazy/eager non-x86 L3 cache should match');
  {$ELSE}
  Skip('Non-x86 cache Linux-specific validation skipped on non-Linux');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_RISCVISAParserSamples;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LFeatures: TRISCVFeatures;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'processor : 0' + LineEnding +
    'isa : rv64imafdcv_zicsr_zifencei' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'compact rv64 ISA should set RV64I');
  CheckTrue(LFeatures.HasM, 'compact rv64 ISA should set M');
  CheckTrue(LFeatures.HasA, 'compact rv64 ISA should set A');
  CheckTrue(LFeatures.HasF, 'compact rv64 ISA should set F');
  CheckTrue(LFeatures.HasD, 'compact rv64 ISA should set D');
  CheckTrue(LFeatures.HasC, 'compact rv64 ISA should set C');
  CheckTrue(LFeatures.HasV, 'compact rv64 ISA should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'versioned ISA should set RV64I');
  CheckTrue(LFeatures.HasM, 'versioned ISA should set M');
  CheckTrue(LFeatures.HasA, 'versioned ISA should set A');
  CheckTrue(LFeatures.HasF, 'versioned ISA should set F');
  CheckTrue(LFeatures.HasD, 'versioned ISA should set D');
  CheckTrue(LFeatures.HasC, 'versioned ISA should set C');
  CheckTrue(LFeatures.HasV, 'versioned ISA should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa string : rv64g' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'rv64g should set RV64I');
  CheckTrue(LFeatures.HasM, 'rv64g should include M');
  CheckTrue(LFeatures.HasA, 'rv64g should include A');
  CheckTrue(LFeatures.HasF, 'rv64g should include F');
  CheckTrue(LFeatures.HasD, 'rv64g should include D');
  CheckFalse(LFeatures.HasC, 'rv64g should not imply C');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rva23u64' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'profile-style rva token should not imply RV64I');
  CheckFalse(LFeatures.HasRV32I, 'profile-style rva token should not imply RV32I');
  CheckFalse(LFeatures.HasA, 'profile-style rva token should not imply A extension');
  CheckFalse(LFeatures.HasV, 'profile-style rva token should not imply vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i rva23u64' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'rv64i should still set RV64I when profile token is present');
  CheckFalse(LFeatures.HasA, 'profile token should not add A extension when compact ISA lacks A');
  CheckFalse(LFeatures.HasV, 'profile token should not imply vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i2p1_zve32x1p0_zvl128b1p0' + LineEnding
  );
  CheckTrue(LFeatures.HasV, 'zve* tokens should imply vector extension');
  CheckFalse(LFeatures.HasM, 'zve-only sample should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zve' + LineEnding
  );
  CheckFalse(LFeatures.HasV, 'incomplete zve token should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'incomplete zve token should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvl' + LineEnding
  );
  CheckFalse(LFeatures.HasV, 'incomplete zvl token should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'incomplete zvl token should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvefoo' + LineEnding
  );
  CheckFalse(LFeatures.HasV, 'malformed zve token without numeric width should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'malformed zve token should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvlfoo' + LineEnding
  );
  CheckFalse(LFeatures.HasV, 'malformed zvl token without numeric width should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'malformed zvl token should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvbb1p0_zvkned1p0' + LineEnding
  );
  CheckTrue(LFeatures.HasV, 'zv* tokens should imply vector extension');
  CheckFalse(LFeatures.HasM, 'zv-only sample should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zv' + LineEnding
  );
  CheckFalse(LFeatures.HasV, 'incomplete zv token should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'incomplete zv token should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zv-foo' + LineEnding
  );
  CheckFalse(LFeatures.HasV, 'malformed zv token with punctuation should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'malformed zv token should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'hart isa : RV64I_XVENTANACONDOPS_ZVBC32E' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'hart isa key should be recognized');
  CheckTrue(LFeatures.HasV, 'zv* tokens should imply vector extension even with vendor token noise');
  CheckFalse(LFeatures.HasM, 'xv/zv-only sample should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'hart isa : RV64I_XVENTANACONDOPS' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'hart isa key should keep RV64I from compact base token');
  CheckFalse(LFeatures.HasV, 'xv*-only vendor token should not imply vector extension');
  CheckFalse(LFeatures.HasM, 'xv-only vendor sample should not imply M');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa extensions = rv64i m a f d c v' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'isa extensions key should be recognized');
  CheckTrue(LFeatures.HasM, 'isa extensions should set M');
  CheckTrue(LFeatures.HasA, 'isa extensions should set A');
  CheckTrue(LFeatures.HasF, 'isa extensions should set F');
  CheckTrue(LFeatures.HasD, 'isa extensions should set D');
  CheckTrue(LFeatures.HasC, 'isa extensions should set C');
  CheckTrue(LFeatures.HasV, 'isa extensions should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : rv64i m a f d c v' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'extensions key should be recognized');
  CheckTrue(LFeatures.HasM, 'extensions key should set M');
  CheckTrue(LFeatures.HasA, 'extensions key should set A');
  CheckTrue(LFeatures.HasF, 'extensions key should set F');
  CheckTrue(LFeatures.HasD, 'extensions key should set D');
  CheckTrue(LFeatures.HasC, 'extensions key should set C');
  CheckTrue(LFeatures.HasV, 'extensions key should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : alpha beta gamma' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'weak extensions key should ignore non-ISA free-form text (no RV64I)');
  CheckFalse(LFeatures.HasRV32I, 'weak extensions key should ignore non-ISA free-form text (no RV32I)');
  CheckFalse(LFeatures.HasM, 'weak extensions key should ignore non-ISA free-form text (no M)');
  CheckFalse(LFeatures.HasV, 'weak extensions key should ignore non-ISA free-form text (no V)');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : a55 board-v2' + LineEnding
  );
  CheckFalse(LFeatures.HasA, 'weak extensions key should ignore mixed metadata tokens (no A)');
  CheckFalse(LFeatures.HasV, 'weak extensions key should ignore mixed metadata tokens (no V)');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : rv64i m a board-v2' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'weak extensions key should reject mixed ISA+metadata tokens (no RV64I)');
  CheckFalse(LFeatures.HasRV32I, 'weak extensions key should reject mixed ISA+metadata tokens (no RV32I)');
  CheckFalse(LFeatures.HasM, 'weak extensions key should reject mixed ISA+metadata tokens (no M)');
  CheckFalse(LFeatures.HasA, 'weak extensions key should reject mixed ISA+metadata tokens (no A)');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : a55' + LineEnding
  );
  CheckFalse(LFeatures.HasA, 'weak extensions key should not treat metadata-like a55 as A extension');
  CheckFalse(LFeatures.HasRV64I, 'weak extensions key should not treat metadata-like a55 as RV64I base');
  CheckFalse(LFeatures.HasRV32I, 'weak extensions key should not treat metadata-like a55 as RV32I base');
  CheckFalse(LFeatures.HasV, 'weak extensions key should not treat metadata-like a55 as vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv extensions = rv64i2p1_zve32x1p0' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv extensions key should be recognized');
  CheckTrue(LFeatures.HasV, 'riscv extensions key should parse vector subset tokens');
  CheckFalse(LFeatures.HasD, 'riscv extensions sample should not imply D when absent');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv isa extensions = rv64i_zve32x' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv isa extensions key should be recognized');
  CheckTrue(LFeatures.HasV, 'riscv isa extensions key should parse vector subset tokens');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,isa extensions = rv64i_zvkb' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv,isa extensions key should be recognized');
  CheckTrue(LFeatures.HasV, 'riscv,isa extensions key should parse vector subset tokens');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv_isa_ext=rv64i_m_a_f_d_c' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv_isa_ext key should be recognized');
  CheckTrue(LFeatures.HasM, 'riscv_isa_ext key should set M');
  CheckTrue(LFeatures.HasA, 'riscv_isa_ext key should set A');
  CheckTrue(LFeatures.HasF, 'riscv_isa_ext key should set F');
  CheckTrue(LFeatures.HasD, 'riscv_isa_ext key should set D');
  CheckTrue(LFeatures.HasC, 'riscv_isa_ext key should set C');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa_ext=rv64i_m_a_f_d_c' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'isa_ext key should be recognized');
  CheckTrue(LFeatures.HasM, 'isa_ext key should set M');
  CheckTrue(LFeatures.HasA, 'isa_ext key should set A');
  CheckTrue(LFeatures.HasF, 'isa_ext key should set F');
  CheckTrue(LFeatures.HasD, 'isa_ext key should set D');
  CheckTrue(LFeatures.HasC, 'isa_ext key should set C');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,isa = "rv64imafdcv_zicsr_zifencei"' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv,isa key should be recognized');
  CheckTrue(LFeatures.HasM, 'quoted ISA value should set M');
  CheckTrue(LFeatures.HasA, 'quoted ISA value should set A');
  CheckTrue(LFeatures.HasF, 'quoted ISA value should set F');
  CheckTrue(LFeatures.HasD, 'quoted ISA value should set D');
  CheckTrue(LFeatures.HasC, 'quoted ISA value should set C');
  CheckTrue(LFeatures.HasV, 'quoted ISA value should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,isa = ''rv64imafdcv_zicsr_zifencei''' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'single-quoted ISA value should set RV64I');
  CheckTrue(LFeatures.HasM, 'single-quoted ISA value should set M');
  CheckTrue(LFeatures.HasA, 'single-quoted ISA value should set A');
  CheckTrue(LFeatures.HasF, 'single-quoted ISA value should set F');
  CheckTrue(LFeatures.HasD, 'single-quoted ISA value should set D');
  CheckTrue(LFeatures.HasC, 'single-quoted ISA value should set C');
  CheckTrue(LFeatures.HasV, 'single-quoted ISA value should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'vendor_id : rise' + LineEnding +
    'uarch : boom' + LineEnding +
    'mmu : sv39' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'non-ISA keys should not imply RV64I');
  CheckFalse(LFeatures.HasM, 'non-ISA keys should not imply M');
  CheckFalse(LFeatures.HasV, 'non-ISA keys should not imply V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zmmul_zicsr' + LineEnding
  );
  CheckFalse(LFeatures.HasM, 'zmmul token should not be treated as full M extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    '   ISA EXTENSIONS	:	RV64I M A F D C V   ' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'mixed-case ISA key should be normalized');
  CheckTrue(LFeatures.HasM, 'mixed-case ISA key should parse M extension');
  CheckTrue(LFeatures.HasA, 'mixed-case ISA key should parse A extension');
  CheckTrue(LFeatures.HasF, 'mixed-case ISA key should parse F extension');
  CheckTrue(LFeatures.HasD, 'mixed-case ISA key should parse D extension');
  CheckTrue(LFeatures.HasC, 'mixed-case ISA key should parse C extension');
  CheckTrue(LFeatures.HasV, 'mixed-case ISA key should parse V extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa : rv64imafdcv' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'misa key should not be treated as ISA field');
  CheckFalse(LFeatures.HasV, 'misa key should not imply vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa : 0x800000000020112d' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'numeric misa bitmask should set RV64I');
  CheckFalse(LFeatures.HasRV32I, 'numeric misa rv64 sample should not set RV32I');
  CheckTrue(LFeatures.HasM, 'numeric misa bitmask should set M');
  CheckTrue(LFeatures.HasA, 'numeric misa bitmask should set A');
  CheckTrue(LFeatures.HasF, 'numeric misa bitmask should set F');
  CheckTrue(LFeatures.HasD, 'numeric misa bitmask should set D');
  CheckTrue(LFeatures.HasC, 'numeric misa bitmask should set C');
  CheckTrue(LFeatures.HasV, 'numeric misa bitmask should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'csr misa = 0x4020112d' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'numeric csr misa rv32 sample should not set RV64I');
  CheckTrue(LFeatures.HasRV32I, 'numeric csr misa rv32 sample should set RV32I');
  CheckTrue(LFeatures.HasM, 'numeric csr misa rv32 sample should set M');
  CheckTrue(LFeatures.HasA, 'numeric csr misa rv32 sample should set A');
  CheckTrue(LFeatures.HasF, 'numeric csr misa rv32 sample should set F');
  CheckTrue(LFeatures.HasD, 'numeric csr misa rv32 sample should set D');
  CheckTrue(LFeatures.HasC, 'numeric csr misa rv32 sample should set C');
  CheckTrue(LFeatures.HasV, 'numeric csr misa rv32 sample should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,misa : $800000000020112d' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv,misa key should be recognized for numeric misa');
  CheckTrue(LFeatures.HasV, 'riscv,misa key should set vector extension bit');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa register = 0x8000_0000_0020_112d' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'misa register key should support underscore-separated hex');
  CheckTrue(LFeatures.HasM, 'underscore-separated misa should set M extension');
  CheckTrue(LFeatures.HasA, 'underscore-separated misa should set A extension');
  CheckTrue(LFeatures.HasF, 'underscore-separated misa should set F extension');
  CheckTrue(LFeatures.HasD, 'underscore-separated misa should set D extension');
  CheckTrue(LFeatures.HasC, 'underscore-separated misa should set C extension');
  CheckTrue(LFeatures.HasV, 'underscore-separated misa should set V extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa csr : 1075847469' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'decimal misa rv32 sample should not set RV64I');
  CheckTrue(LFeatures.HasRV32I, 'decimal misa rv32 sample should set RV32I');
  CheckTrue(LFeatures.HasV, 'decimal misa rv32 sample should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa : -1' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'negative misa should be rejected (no RV64I)');
  CheckFalse(LFeatures.HasRV32I, 'negative misa should be rejected (no RV32I)');
  CheckFalse(LFeatures.HasV, 'negative misa should be rejected (no V)');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'march : rv64imafdcv_zicsr' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'march key should be treated as ISA field');
  CheckTrue(LFeatures.HasM, 'march key should set M');
  CheckTrue(LFeatures.HasA, 'march key should set A');
  CheckTrue(LFeatures.HasF, 'march key should set F');
  CheckTrue(LFeatures.HasD, 'march key should set D');
  CheckTrue(LFeatures.HasC, 'march key should set C');
  CheckTrue(LFeatures.HasV, 'march key should set V');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,march = rv64i_zvbb' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv,march key should be treated as ISA field');
  CheckTrue(LFeatures.HasV, 'riscv,march key should parse vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv march : rv64i_zve32x' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'riscv march key should be treated as ISA field');
  CheckTrue(LFeatures.HasV, 'riscv march key should parse vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'marchid : 0x8000000000000007' + LineEnding
  );
  CheckFalse(LFeatures.HasRV64I, 'marchid key should not be treated as ISA field');
  CheckFalse(LFeatures.HasV, 'marchid key should not imply vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_svinval_zicbom' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'non-vector extension sample should keep RV64I');
  CheckFalse(LFeatures.HasV, 'svinval/zicbom should not imply vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i' + LineEnding +
    'isa extensions = m a f d c' + LineEnding +
    'hart isa : rv64i_zvbb' + LineEnding
  );
  CheckTrue(LFeatures.HasRV64I, 'multiple ISA keys should merge RV64I');
  CheckTrue(LFeatures.HasM, 'multiple ISA keys should merge M');
  CheckTrue(LFeatures.HasA, 'multiple ISA keys should merge A');
  CheckTrue(LFeatures.HasF, 'multiple ISA keys should merge F');
  CheckTrue(LFeatures.HasD, 'multiple ISA keys should merge D');
  CheckTrue(LFeatures.HasC, 'multiple ISA keys should merge C');
  CheckTrue(LFeatures.HasV, 'multiple ISA keys should merge vector extension');

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv32imafdc' + LineEnding +
    'hart isa : rv64i_zvbb' + LineEnding
  );
  {$IFDEF CPURISCV32}
  CheckTrue(LFeatures.HasRV32I, 'conflicting parser sample should normalize to rv32 baseline on riscv32 build');
  CheckFalse(LFeatures.HasRV64I, 'conflicting parser sample should clear rv64 baseline on riscv32 build');
  {$ELSE}
  CheckTrue(LFeatures.HasRV64I, 'conflicting parser sample should normalize to rv64 baseline on non-riscv32 builds');
  CheckFalse(LFeatures.HasRV32I, 'conflicting parser sample should clear rv32 baseline on non-riscv32 builds');
  {$ENDIF}
  CheckTrue(LFeatures.HasM, 'conflicting parser sample should keep merged M extension');
  CheckTrue(LFeatures.HasA, 'conflicting parser sample should keep merged A extension');
  CheckTrue(LFeatures.HasF, 'conflicting parser sample should keep merged F extension');
  CheckTrue(LFeatures.HasD, 'conflicting parser sample should keep merged D extension');
  CheckTrue(LFeatures.HasC, 'conflicting parser sample should keep merged C extension');
  CheckTrue(LFeatures.HasV, 'conflicting parser sample should keep merged vector extension');
  {$ELSE}
  Skip('RISC-V ISA parser samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_RISCVISASelectionSamples;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LISA: string;
  LFeatures: TRISCVFeatures;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  CheckTrue(ExtractBestRISCVISAFromCpuInfo( 'extensions : m a f d c v' + LineEnding + 'isa : rv64imafdc' + LineEnding, LISA, LFeatures ), 'ISA candidate with RV base should win over extension-only candidate');
  CheckEqual('rv64imafdc', LISA, 'base ISA candidate should be selected');
  CheckTrue(LFeatures.HasRV64I, 'selected ISA should include RV64I');
  CheckTrue(LFeatures.HasM, 'selected ISA should include M extension');
  CheckTrue(LFeatures.HasD, 'selected ISA should include D extension');
  CheckFalse(LFeatures.HasV, 'selected ISA sample should not imply vector extension');

  CheckTrue(ExtractBestRISCVISAFromCpuInfo( 'riscv extensions = rv64i_zve32x_zvl128b' + LineEnding + 'riscv,isa = rv64imafdc' + LineEnding, LISA, LFeatures ), 'explicit riscv,isa key should win over weaker extensions key');
  CheckEqual('rv64imafdc', LISA, 'riscv,isa key should be preferred when both candidates have RV base');
  CheckTrue(LFeatures.HasRV64I, 'riscv,isa preferred sample should keep RV64I');
  CheckFalse(LFeatures.HasV, 'riscv,isa preferred sample should not force vector extension');

  CheckTrue(ExtractBestRISCVISAFromCpuInfo( 'processor : 0' + LineEnding + 'misa : 0x800000000020112d' + LineEnding, LISA, LFeatures ), 'numeric misa should synthesize ISA when explicit ISA key is missing');
  CheckEqual('rv64imafdcv', LISA, 'numeric misa should synthesize canonical rv64 ISA string');
  CheckTrue(LFeatures.HasRV64I, 'numeric misa synthesized ISA should include RV64I');
  CheckTrue(LFeatures.HasV, 'numeric misa synthesized ISA should include V');

  CheckTrue(ExtractBestRISCVISAFromCpuInfo( 'isa extensions : m a f d c v' + LineEnding + 'csr misa : 0x800000000020112d' + LineEnding, LISA, LFeatures ), 'numeric misa should backfill base ISA for extension-only ISA key');
  CheckEqual('rv64imafdcv', LISA, 'misa should backfill extension-only ISA key to canonical rv64 ISA');
  CheckTrue(LFeatures.HasRV64I, 'backfilled ISA should include RV64I');
  CheckTrue(LFeatures.HasV, 'backfilled ISA should include V');

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'isa : unknown' + LineEnding, LISA, LFeatures ), 'invalid ISA text without parseable tokens should be rejected');
  CheckEqual('', LISA, 'invalid ISA text should not produce ISA output');

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'isa : rva23u64' + LineEnding, LISA, LFeatures ), 'profile-style rv token without rv32/rv64 baseline should be rejected');
  CheckEqual('', LISA, 'profile-style token should not produce ISA output');

  CheckTrue(ExtractBestRISCVISAFromCpuInfo( 'isa : unknown' + LineEnding + 'misa : 0x800000000020112d' + LineEnding, LISA, LFeatures ), 'numeric misa should recover from invalid ISA text');
  CheckEqual('rv64imafdcv', LISA, 'misa should synthesize canonical ISA when textual ISA is invalid');

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'extensions : m a f d c v' + LineEnding, LISA, LFeatures ), 'extension-only ISA evidence without RV base/misa should be rejected');
  CheckEqual('', LISA, 'extension-only ISA evidence should not emit ISA string');

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'extensions : a55' + LineEnding, LISA, LFeatures ), 'weak extensions metadata-like token should not produce ISA result');
  CheckEqual('', LISA, 'weak extensions metadata-like token should not emit ISA string');

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'extensions : rv64i m a board-v2' + LineEnding, LISA, LFeatures ), 'weak extensions key with mixed ISA+metadata tokens should not produce ISA result');
  CheckEqual('', LISA, 'weak extensions mixed ISA+metadata tokens should not emit ISA string');

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'isa : rv128imafdc' + LineEnding, LISA, LFeatures ), 'unsupported rv128 textual ISA without rv32/rv64 baseline should be rejected');
  CheckEqual('', LISA, 'unsupported rv128 textual ISA should not emit ISA string');

  CheckTrue(ExtractBestRISCVISAFromCpuInfo( 'isa : rv32imafdc' + LineEnding + 'misa : 0x800000000020112d' + LineEnding, LISA, LFeatures ), 'conflicting rv32 textual ISA and rv64 misa should normalize to target baseline');
  {$IFDEF CPURISCV64}
  CheckEqual('rv64imafdcv', LISA, 'riscv64 build should normalize conflicting ISA evidence to rv64 baseline');
  CheckTrue(LFeatures.HasRV64I, 'riscv64 build should keep RV64I baseline');
  CheckFalse(LFeatures.HasRV32I, 'riscv64 build should clear conflicting RV32I baseline');
  {$ELSE}
  CheckEqual('rv32imafdcv', LISA, 'riscv32 build should normalize conflicting ISA evidence to rv32 baseline');
  CheckTrue(LFeatures.HasRV32I, 'riscv32 build should keep RV32I baseline');
  CheckFalse(LFeatures.HasRV64I, 'riscv32 build should clear conflicting RV64I baseline');
  {$ENDIF}

  CheckFalse(ExtractBestRISCVISAFromCpuInfo( 'misa : rv64imafdc' + LineEnding, LISA, LFeatures ), 'non-numeric misa without ISA keys should not produce ISA result');
  CheckEqual('', LISA, 'failed ISA extraction should keep ISA output empty');
  {$ELSE}
  Skip('RISC-V ISA selection samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_RISCVHWCAPMergeSamples;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LFeatures: TRISCVFeatures;
  LHWCAP: QWord;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  {$IFDEF LINUX}
  LHWCAP := (QWord(1) shl (Ord('I') - Ord('A'))) or
            (QWord(1) shl (Ord('M') - Ord('A'))) or
            (QWord(1) shl (Ord('A') - Ord('A'))) or
            (QWord(1) shl (Ord('F') - Ord('A'))) or
            (QWord(1) shl (Ord('D') - Ord('A'))) or
            (QWord(1) shl (Ord('C') - Ord('A'))) or
            (QWord(1) shl (Ord('V') - Ord('A')));

  LFeatures := Default(TRISCVFeatures);
  MergeRISCVFeaturesFromLinuxHWCAP(LFeatures, LHWCAP, 0);
  {$IFDEF CPURISCV64}
  CheckTrue(LFeatures.HasRV64I, 'RISC-V HWCAP I bit should set RV64I on riscv64 build');
  {$ELSE}
  CheckTrue(LFeatures.HasRV32I, 'RISC-V HWCAP I bit should set RV32I on riscv32 build');
  {$ENDIF}
  CheckTrue(LFeatures.HasM, 'RISC-V HWCAP M bit should set M');
  CheckTrue(LFeatures.HasA, 'RISC-V HWCAP A bit should set A');
  CheckTrue(LFeatures.HasF, 'RISC-V HWCAP F bit should set F');
  CheckTrue(LFeatures.HasD, 'RISC-V HWCAP D bit should set D');
  CheckTrue(LFeatures.HasC, 'RISC-V HWCAP C bit should set C');
  CheckTrue(LFeatures.HasV, 'RISC-V HWCAP V bit should set V');
  CheckTrue(LFeatures.LinuxHWCAP = LHWCAP, 'RISC-V HWCAP raw bits should be preserved');
  CheckTrue(LFeatures.LinuxHWCAP2 = QWord(0), 'RISC-V HWCAP2 raw bits should stay zero when omitted');

  LFeatures := Default(TRISCVFeatures);
  MergeRISCVFeaturesFromLinuxHWCAP(LFeatures, 0, QWord(1));
  CheckFalse(LFeatures.HasV, 'Unmapped HWCAP2-only sample should not imply RVV');
  CheckTrue(LFeatures.LinuxHWCAP = QWord(0), 'HWCAP2-only sample should keep raw HWCAP empty');
  CheckTrue(LFeatures.LinuxHWCAP2 = QWord(1), 'HWCAP2-only sample should preserve raw HWCAP2 bits');
  {$ELSE}
  Skip('RISC-V HWCAP merge samples skipped on non-Linux');
  Exit;
  {$ENDIF}
  {$ELSE}
  Skip('RISC-V HWCAP merge samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_RISCVVendorModelParserSamples;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LVendor: string;
  LModel: string;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'vendor_id : "SiFive"' + LineEnding + 'model name : ''U74-MC''' + LineEnding, LVendor, LModel ), 'vendor/model parser should accept vendor_id + model name');
  CheckEqual('SiFive', LVendor, 'quoted vendor_id should be normalized');
  CheckEqual('U74-MC', LModel, 'quoted model name should be normalized');

  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'processor : 0' + LineEnding + 'processor : 1' + LineEnding + 'soc : T-HEAD' + LineEnding + 'uarch : Xuantie C910' + LineEnding, LVendor, LModel ), 'vendor/model parser should ignore numeric processor index and keep stronger uarch');
  CheckEqual('T-HEAD', LVendor, 'soc should be used as vendor candidate when vendor_id is missing');
  CheckEqual('Xuantie C910', LModel, 'uarch should win over numeric processor index');

  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'processor : 0x0' + LineEnding + 'processor : $1' + LineEnding + 'vendor_id : StarFive' + LineEnding, LVendor, LModel ), 'vendor/model parser should ignore hex/$ processor indexes and keep vendor-only identity');
  CheckEqual('StarFive', LVendor, 'vendor_id should still be parsed with hex/$ processor indexes');
  CheckEqual('', LModel, 'hex/$ processor indexes should not be promoted as model');

  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'vendor=sifive' + LineEnding + 'cpu model=FU740' + LineEnding, LVendor, LModel ), 'vendor/model parser should support key=value format');
  CheckEqual('sifive', LVendor, 'key=value vendor should be parsed');
  CheckEqual('FU740', LModel, 'key=value cpu model should be parsed');

  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'soc : generic-soc' + LineEnding + 'vendor_id : VendorStrong' + LineEnding + 'model : WeakModel' + LineEnding + 'model name : StrongModel' + LineEnding + 'processor : 0' + LineEnding, LVendor, LModel ), 'strong identity keys should override weaker candidates');
  CheckEqual('VendorStrong', LVendor, 'vendor_id should override soc vendor candidate');
  CheckEqual('StrongModel', LModel, 'model name should override weak model/processor candidates');

  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'vendor_id : FirstVendor' + LineEnding + 'vendor : SecondVendor' + LineEnding + 'model name : FirstModel' + LineEnding + 'cpu model : SecondModel' + LineEnding, LVendor, LModel ), 'same-priority identity keys should keep first non-empty candidate');
  CheckEqual('FirstVendor', LVendor, 'first same-priority vendor should be kept');
  CheckEqual('FirstModel', LModel, 'first same-priority model should be kept');

  CheckTrue(ParseRISCVVendorModelFromCpuInfo( 'processor : "JH7110 CPU"' + LineEnding, LVendor, LModel ), 'non-numeric processor value can be used as weak model fallback');
  CheckEqual('', LVendor, 'weak processor fallback should not produce vendor');
  CheckEqual('JH7110 CPU', LModel, 'non-numeric processor fallback should produce model');

  CheckFalse(ParseRISCVVendorModelFromCpuInfo( 'processor : 0' + LineEnding + 'processor : 1' + LineEnding + 'processor : 0x2' + LineEnding + 'processor : $3' + LineEnding + 'isa : rv64imafdc' + LineEnding, LVendor, LModel ), 'non-identity cpuinfo lines should not produce vendor/model');
  CheckEqual('', LVendor, 'vendor should stay empty when no identity key exists');
  CheckEqual('', LModel, 'model should stay empty when no identity key exists');
  {$ELSE}
  Skip('RISC-V vendor/model parser samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_RISCVProcessorInfoBasic;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LInfo: TRISCVProcessorInfo;
  LParsed: TRISCVFeatures;
  LDetected: TRISCVFeatures;
  LISA: string;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  LInfo := GetRISCVProcessorInfo;
  CheckTrue(LInfo.Architecture <> '', 'RISC-V processor architecture should not be empty');
  CheckTrue(LInfo.ISA <> '', 'RISC-V processor ISA should not be empty');
  CheckTrue(LInfo.XLEN > 0, 'RISC-V XLEN should be positive');
  LISA := LowerCase(Trim(LInfo.ISA));

  if LInfo.Architecture = 'RV64' then
  begin
    CheckEqual(64, LInfo.XLEN, 'RV64 architecture should map to XLEN=64');
    CheckTrue(Copy(LISA, 1, 4) = 'rv64', 'RV64 architecture should expose rv64 ISA baseline');
  end
  else if LInfo.Architecture = 'RV32' then
  begin
    CheckEqual(32, LInfo.XLEN, 'RV32 architecture should map to XLEN=32');
    CheckTrue(Copy(LISA, 1, 4) = 'rv32', 'RV32 architecture should expose rv32 ISA baseline');
  end;

  LParsed := ParseRISCVFeaturesFromCpuInfo('isa : ' + LInfo.ISA + LineEnding);
  if LInfo.Architecture = 'RV64' then
    CheckTrue(LParsed.HasRV64I, 'RISCVProcessorInfo ISA should be consistent with RV64 architecture');
  else if LInfo.Architecture = 'RV32' then
    CheckTrue(LParsed.HasRV32I, 'RISCVProcessorInfo ISA should be consistent with RV32 architecture');

  LDetected := GetRISCVCPUInfo;
  {$IFDEF CPURISCV64}
  CheckTrue(LDetected.HasRV64I, 'Detected RISC-V feature set should keep RV64I baseline');
  CheckFalse(LDetected.HasRV32I, 'Detected RISC-V feature set should not keep conflicting RV32I baseline on riscv64 build');
  {$ELSE}
  CheckTrue(LDetected.HasRV32I, 'Detected RISC-V feature set should keep RV32I baseline');
  CheckFalse(LDetected.HasRV64I, 'Detected RISC-V feature set should not keep conflicting RV64I baseline on riscv32 build');
  {$ENDIF}

  if LDetected.HasM then
    CheckTrue(LParsed.HasM, 'RISCVProcessorInfo ISA should include M when detected');
  if LDetected.HasA then
    CheckTrue(LParsed.HasA, 'RISCVProcessorInfo ISA should include A when detected');
  if LDetected.HasF then
    CheckTrue(LParsed.HasF, 'RISCVProcessorInfo ISA should include F when detected');
  if LDetected.HasD then
    CheckTrue(LParsed.HasD, 'RISCVProcessorInfo ISA should include D when detected');
  if LDetected.HasC then
    CheckTrue(LParsed.HasC, 'RISCVProcessorInfo ISA should include C when detected');
  if LDetected.HasV then
    CheckTrue(LParsed.HasV, 'RISCVProcessorInfo ISA should include V when detected');
  {$ELSE}
  Skip('RISC-V processor info test skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_PlatformSpecific.Test_FeatureHierarchy;
var
  cpuInfo: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  
  {$IFDEF SIMD_X86_AVAILABLE}
  // 验证 x86 特性层次结构
  if cpuInfo.X86.HasSSE2 then
    CheckTrue(cpuInfo.X86.HasSSE, 'SSE2 requires SSE');
    
  if cpuInfo.X86.HasSSE3 then
    CheckTrue(cpuInfo.X86.HasSSE2, 'SSE3 requires SSE2');
    
  if cpuInfo.X86.HasSSSE3 then
    CheckTrue(cpuInfo.X86.HasSSE3, 'SSSE3 requires SSE3');
    
  if cpuInfo.X86.HasSSE41 then
    CheckTrue(cpuInfo.X86.HasSSSE3, 'SSE4.1 requires SSSE3');
    
  if cpuInfo.X86.HasSSE42 then
    CheckTrue(cpuInfo.X86.HasSSE41, 'SSE4.2 requires SSE4.1');
    
  if cpuInfo.X86.HasAVX2 then
    CheckTrue(cpuInfo.X86.HasAVX, 'AVX2 requires AVX');
    
  if IsBackendSupportedOnCPU(sbAVX512) then
    CheckTrue(cpuInfo.X86.HasAVX2, 'AVX512 backend requires AVX2 backend prerequisite');
  {$ENDIF}
end;

// === TTestFixture_ErrorHandling ===

procedure TTestFixture_ErrorHandling.Test_InvalidBackend;
var
  info: TSimdBackendInfo;
  invalidIndex: Integer;
  invalidBackend: TSimdBackend;
begin
  // 测试无效的后端值
  invalidIndex := Ord(High(TSimdBackend)) + 1;
  invalidBackend := TSimdBackend(invalidIndex);
  try
    info := GetBackendInfo(invalidBackend);
    // 兼容两种语义：抛出 RangeError 或返回不可用描述。
    CheckFalse(info.Available, 'Invalid backend should not be available');
  except
    on ERangeError do
      Exit;
  end;
end;

procedure TTestFixture_ErrorHandling.Test_ExceptionHandling;
var
  cpuInfo: TCPUInfo;
begin
  // 测试在异常情况下的行为
  try
    cpuInfo := GetCPUInfo;
    // 正常情况下不应该抛出异常
    CheckTrue(cpuInfo.Vendor <> '', 'GetCPUInfo should not throw exceptions');
  except
    on E: Exception do
      Fail('GetCPUInfo should not throw exceptions: ' + E.Message);
  end;
end;

end.
