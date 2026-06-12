unit nextpas.core.simd.cpuinfo.testcase;

{$I nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  fpcunit, testregistry,
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

type
  // 全局函数测试
  TTestCase_Global = class(TTestCase)
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
  TTestCase_ThreadSafety = class(TTestCase)
  published
    procedure Test_GetCPUInfo_Consistency;
    procedure Test_GetCPUInfo_Performance;
  end;

  // 平台特定测试
  TTestCase_PlatformSpecific = class(TTestCase)
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
  TTestCase_ErrorHandling = class(TTestCase)
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

// === TTestCase_Global ===

procedure TTestCase_Global.Test_GetCPUInfo;
var
  cpuInfo: TCPUInfo;
  cpuInfo2: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  
  // 基本验证
  AssertTrue('CPU vendor should not be empty', cpuInfo.Vendor <> '');
  AssertTrue('CPU model should not be empty', cpuInfo.Model <> '');
  
  // 多次调用应该返回相同结果
  cpuInfo2 := GetCPUInfo;
  AssertEquals('Vendor should be consistent', cpuInfo.Vendor, cpuInfo2.Vendor);
  AssertEquals('Model should be consistent', cpuInfo.Model, cpuInfo2.Model);
end;

procedure TTestCase_Global.Test_IsBackendAvailable;
var
  sse2Available: Boolean;
  avx2Available: Boolean;
  neonAvailable: Boolean;
begin
  // Scalar 后端必须总是可用
  AssertTrue('Scalar backend must always be available', IsBackendAvailableOnCPU(sbScalar));
  
  // 测试其他后端
  sse2Available := IsBackendAvailableOnCPU(sbSSE2);
  avx2Available := IsBackendAvailableOnCPU(sbAVX2);
  neonAvailable := IsBackendAvailableOnCPU(sbNEON);
  
  // 记录结果用于调试
  WriteLn('SSE2 available: ', sse2Available);
  WriteLn('AVX2 available: ', avx2Available);
  WriteLn('NEON available: ', neonAvailable);
end;

procedure TTestCase_Global.Test_BackendSupportPredicateConsistency;
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

    AssertEquals(
      'cpuinfo predicate and dispatch predicate should agree for backend=' + IntToStr(Ord(LBackend)),
      LSupportedByCpuInfo,
      LAvailableByDispatch
    );
    AssertEquals(
      'cpuinfo predicate should match GetSupportedBackends membership for backend=' + IntToStr(Ord(LBackend)),
      LSupportedByCpuInfo,
      BackendInArray(LBackend, LBackends)
    );
  end;
end;

procedure TTestCase_Global.Test_GetAvailableBackends;
var
  backends: TSimdBackendArray;
  i: Integer;
  foundScalar: Boolean;
  info1: TSimdBackendInfo;
  info2: TSimdBackendInfo;
begin
  backends := GetAvailableBackends;
  
  // 至少应该有 Scalar 后端
  AssertTrue('Should have at least one backend', Length(backends) > 0);
  
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
  AssertTrue('Should include scalar backend', foundScalar);
  
  // 验证后端按优先级排序（高优先级在前）
  for i := 0 to Length(backends) - 2 do
  begin
    info1 := GetBackendInfo(backends[i]);
    info2 := GetBackendInfo(backends[i + 1]);
    AssertTrue('Backends should be sorted by priority', info1.Priority >= info2.Priority);
  end;
end;

procedure TTestCase_Global.Test_ClearSupportedAliases_PreserveCpuOnlySemantics;
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

  AssertEquals('GetSupportedBackendList length should match GetSupportedBackends',
    Length(LSupportedLegacy), Length(LSupportedAlias));
  AssertEquals('GetAvailableBackends length should match GetSupportedBackends',
    Length(LSupportedLegacy), Length(LAvailableLegacy));

  for LIndex := 0 to High(LSupportedLegacy) do
  begin
    AssertEquals('GetSupportedBackendList should preserve CPU-supported ordering',
      Ord(LSupportedLegacy[LIndex]), Ord(LSupportedAlias[LIndex]));
    AssertEquals('GetAvailableBackends should remain a compatibility alias for CPU-supported ordering',
      Ord(LSupportedLegacy[LIndex]), Ord(LAvailableLegacy[LIndex]));
  end;

  LBestLegacy := GetBestBackendOnCPU;
  LBestAlias := GetBestSupportedBackend;
  LBestCompat := GetBestBackend;

  AssertEquals('GetBestSupportedBackend should alias GetBestBackendOnCPU',
    Ord(LBestLegacy), Ord(LBestAlias));
  AssertEquals('GetBestBackend should remain a compatibility alias',
    Ord(LBestLegacy), Ord(LBestCompat));
end;

procedure TTestCase_Global.Test_GetBestBackend;
var
  bestBackend: TSimdBackend;
  backendInfo: TSimdBackendInfo;
begin
  InitializeDispatch;
  bestBackend := GetBestBackend;
  
  // 最佳后端必须可用
  AssertTrue('Best backend must be available', IsBackendAvailableOnCPU(bestBackend));
  
  // Dispatch 返回的是“已注册并激活”的后端信息；它不一定与 CPU 最优后端同一个枚举值。
  backendInfo := GetBackendInfo(GetActiveBackend);
  AssertTrue('Active backend info should be available', backendInfo.Available);
  AssertTrue('Active backend name should not be empty', backendInfo.Name <> '');
end;

procedure TTestCase_Global.Test_GetBestBackendOnCPU_IndependentFromActiveBackend;
var
  LBestCPU: TSimdBackend;
  LBestAlias: TSimdBackend;
  LOriginalActive: TSimdBackend;
  LBackends: TSimdBackendArray;
  LIndex: Integer;
begin
  LBestCPU := GetBestBackendOnCPU;
  LBestAlias := GetBestBackend;
  AssertEquals('GetBestBackend should alias GetBestBackendOnCPU', Ord(LBestCPU), Ord(LBestAlias));

  InitializeDispatch;
  LOriginalActive := GetActiveBackend;
  LBackends := GetAvailableBackends;

  if TrySetActiveBackend(sbScalar) then
    AssertEquals('CPU best backend should not depend on active backend (scalar)', Ord(LBestCPU), Ord(GetBestBackendOnCPU));

  for LIndex := 0 to High(LBackends) do
  begin
    if LBackends[LIndex] = GetActiveBackend then
      Continue;
    if TrySetActiveBackend(LBackends[LIndex]) then
    begin
      AssertEquals('CPU best backend should remain stable when active backend changes', Ord(LBestCPU), Ord(GetBestBackendOnCPU));
      Break;
    end;
  end;

  if not TrySetActiveBackend(LOriginalActive) then
    ResetToAutomaticBackend;
end;

procedure TTestCase_Global.Test_GetBackendInfo;
var
  info: TSimdBackendInfo;
begin
  InitializeDispatch;
  // 测试 Scalar 后端信息
  info := GetBackendInfo(sbScalar);
  AssertTrue('Scalar backend should be available', info.Available);
  AssertTrue('Scalar backend name should not be empty', info.Name <> '');
  AssertTrue('Scalar backend priority should be non-negative', info.Priority >= 0);
  
  // 测试其他后端
  info := GetBackendInfo(sbSSE2);
  if info.Available then
    AssertTrue('SSE2 backend name should not be empty when available', info.Name <> '');
  
  info := GetBackendInfo(sbAVX2);
  if info.Available then
    AssertTrue('AVX2 backend name should not be empty when available', info.Name <> '');
  
  info := GetBackendInfo(sbNEON);
  if info.Available then
    AssertTrue('NEON backend name should not be empty when available', info.Name <> '');
end;

procedure TTestCase_Global.Test_ResetCPUInfo;
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
  AssertEquals('Vendor should be same after reset', cpuInfo1.Vendor, cpuInfo2.Vendor);
  AssertEquals('Model should be same after reset', cpuInfo1.Model, cpuInfo2.Model);
end;

// === TTestCase_ThreadSafety ===

procedure TTestCase_ThreadSafety.Test_GetCPUInfo_Consistency;
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
    
    AssertEquals('Vendor should be consistent', cpuInfo1.Vendor, cpuInfo2.Vendor);
    AssertEquals('Model should be consistent', cpuInfo1.Model, cpuInfo2.Model);
    
    {$IFDEF SIMD_X86_AVAILABLE}
    AssertEquals('x86 SSE should be consistent', cpuInfo1.X86.HasSSE, cpuInfo2.X86.HasSSE);
    AssertEquals('x86 SSE2 should be consistent', cpuInfo1.X86.HasSSE2, cpuInfo2.X86.HasSSE2);
    AssertEquals('x86 AVX should be consistent', cpuInfo1.X86.HasAVX, cpuInfo2.X86.HasAVX);
    AssertEquals('x86 AVX2 should be consistent', cpuInfo1.X86.HasAVX2, cpuInfo2.X86.HasAVX2);
    {$ENDIF}
    
    {$IFDEF SIMD_ARM_AVAILABLE}
    AssertEquals('ARM NEON should be consistent', cpuInfo1.ARM.HasNEON, cpuInfo2.ARM.HasNEON);
    AssertEquals('ARM AdvSIMD should be consistent', cpuInfo1.ARM.HasAdvSIMD, cpuInfo2.ARM.HasAdvSIMD);
    {$ENDIF}
  end;
end;

procedure TTestCase_ThreadSafety.Test_GetCPUInfo_Performance;
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
  AssertTrue('GetCPUInfo should be fast (< 10μs)', avgTimeNs < 10000);
end;

// === TTestCase_PlatformSpecific ===

procedure TTestCase_PlatformSpecific.Test_X86Features;
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

procedure TTestCase_PlatformSpecific.Test_IntrinsicsAVXAvailability_Semantics;
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

  AssertEquals('simd_has_avx should follow AVX usable semantics', LExpectedAVX, simd_has_avx);
  AssertEquals('simd_has_avx2 should follow AVX2 usable semantics', LExpectedAVX2, simd_has_avx2);
  if simd_has_avx2 then
    AssertTrue('simd_has_avx2 implies simd_has_avx', simd_has_avx);
  {$ELSE}
  AssertFalse('simd_has_avx should be false when x86 cpuinfo is disabled', simd_has_avx);
  AssertFalse('simd_has_avx2 should be false when x86 cpuinfo is disabled', simd_has_avx2);
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_IntrinsicsFacade_FullConsistency;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    AssertEquals('simd_has_mmx should match x86 MMX flag', LCPUInfo.X86.HasMMX, simd_has_mmx);
    AssertEquals('simd_has_sse should match x86 SSE flag', LCPUInfo.X86.HasSSE, simd_has_sse);
    AssertEquals('simd_has_sse2 should match x86 SSE2 flag', LCPUInfo.X86.HasSSE2, simd_has_sse2);
    AssertEquals('simd_has_sse3 should match x86 SSE3 flag', LCPUInfo.X86.HasSSE3, simd_has_sse3);
    AssertEquals('simd_has_sse41 should match x86 SSE4.1 flag', LCPUInfo.X86.HasSSE41, simd_has_sse41);
    AssertEquals('simd_has_sse42 should match x86 SSE4.2 flag', LCPUInfo.X86.HasSSE42, simd_has_sse42);
    AssertEquals(
      'simd_has_avx should match AVX usable semantics',
      LCPUInfo.X86.HasAVX and (gfSimd256 in LCPUInfo.GenericUsable),
      simd_has_avx
    );
    AssertEquals(
      'simd_has_avx2 should match AVX2 usable semantics',
      LCPUInfo.X86.HasAVX2 and (gfSimd256 in LCPUInfo.GenericUsable),
      simd_has_avx2
    );
    AssertEquals(
      'simd_has_avx512f should match AVX512 usable semantics',
      LCPUInfo.X86.HasAVX512F and (gfSimd512 in LCPUInfo.GenericUsable),
      simd_has_avx512f
    );
    AssertEquals(
      'simd_has_aes should match AES usable semantics',
      LCPUInfo.X86.HasAES and (gfAES in LCPUInfo.GenericUsable),
      simd_has_aes
    );
    AssertEquals(
      'simd_has_sha should match SHA usable semantics',
      LCPUInfo.X86.HasSHA and (gfSHA in LCPUInfo.GenericUsable),
      simd_has_sha
    );
    AssertEquals(
      'simd_has_fma3 should match FMA usable semantics',
      LCPUInfo.X86.HasFMA and (gfFMA in LCPUInfo.GenericUsable),
      simd_has_fma3
    );
  end
  else
  begin
    AssertFalse('simd_has_mmx should be false on non-x86 arch', simd_has_mmx);
    AssertFalse('simd_has_sse should be false on non-x86 arch', simd_has_sse);
    AssertFalse('simd_has_sse2 should be false on non-x86 arch', simd_has_sse2);
    AssertFalse('simd_has_sse3 should be false on non-x86 arch', simd_has_sse3);
    AssertFalse('simd_has_sse41 should be false on non-x86 arch', simd_has_sse41);
    AssertFalse('simd_has_sse42 should be false on non-x86 arch', simd_has_sse42);
    AssertFalse('simd_has_avx should be false on non-x86 arch', simd_has_avx);
    AssertFalse('simd_has_avx2 should be false on non-x86 arch', simd_has_avx2);
    AssertFalse('simd_has_avx512f should be false on non-x86 arch', simd_has_avx512f);
    AssertFalse('simd_has_aes should be false on non-x86 arch', simd_has_aes);
    AssertFalse('simd_has_sha should be false on non-x86 arch', simd_has_sha);
    AssertFalse('simd_has_fma3 should be false on non-x86 arch', simd_has_fma3);
  end;
  {$ELSE}
  AssertFalse('simd_has_mmx should be false when x86 cpuinfo is disabled', simd_has_mmx);
  AssertFalse('simd_has_sse should be false when x86 cpuinfo is disabled', simd_has_sse);
  AssertFalse('simd_has_sse2 should be false when x86 cpuinfo is disabled', simd_has_sse2);
  AssertFalse('simd_has_sse3 should be false when x86 cpuinfo is disabled', simd_has_sse3);
  AssertFalse('simd_has_sse41 should be false when x86 cpuinfo is disabled', simd_has_sse41);
  AssertFalse('simd_has_sse42 should be false when x86 cpuinfo is disabled', simd_has_sse42);
  AssertFalse('simd_has_avx should be false when x86 cpuinfo is disabled', simd_has_avx);
  AssertFalse('simd_has_avx2 should be false when x86 cpuinfo is disabled', simd_has_avx2);
  AssertFalse('simd_has_avx512f should be false when x86 cpuinfo is disabled', simd_has_avx512f);
  AssertFalse('simd_has_aes should be false when x86 cpuinfo is disabled', simd_has_aes);
  AssertFalse('simd_has_sha should be false when x86 cpuinfo is disabled', simd_has_sha);
  AssertFalse('simd_has_fma3 should be false when x86 cpuinfo is disabled', simd_has_fma3);
  {$ENDIF}

  if simd_has_fma3 then
    AssertTrue('simd_has_fma3 implies simd_has_avx', simd_has_avx);
end;

procedure TTestCase_PlatformSpecific.Test_BackendFeatureBidirectionalConsistency;
var
  LCPUInfo: TCPUInfo;
  LBackends: TSimdBackendArray;
  LIndex: Integer;
  LExpectedAVX512Backend: Boolean;
begin
  LCPUInfo := GetCPUInfo;
  LBackends := GetSupportedBackends;

  AssertTrue('Supported backend list should include Scalar', BackendInArray(sbScalar, LBackends));

  // Direction A: backend list -> availability API must agree
  for LIndex := 0 to High(LBackends) do
    AssertTrue('Each listed backend must be available on CPU', IsBackendAvailableOnCPU(LBackends[LIndex]));

  {$IFDEF SIMD_X86_AVAILABLE}
  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedAVX512Backend := X86SupportsAVX512BackendOnCPU(LCPUInfo.X86, gfSimd512 in LCPUInfo.GenericUsable);

    // Direction B1: x86 intrinsics facade -> backend list
    AssertEquals('SSE2 backend presence should match simd_has_sse2', simd_has_sse2, BackendInArray(sbSSE2, LBackends));
    AssertEquals('AVX2 backend presence should match simd_has_avx2', simd_has_avx2, BackendInArray(sbAVX2, LBackends));
    AssertEquals('AVX512 backend presence should match backend-supported predicate, not raw simd_has_avx512f semantics',
      LExpectedAVX512Backend, BackendInArray(sbAVX512, LBackends));

    // Direction B2: backend list -> x86 intrinsics facade
    if BackendInArray(sbSSE2, LBackends) then
      AssertTrue('SSE2 backend listed implies simd_has_sse2', simd_has_sse2);
    if BackendInArray(sbAVX2, LBackends) then
      AssertTrue('AVX2 backend listed implies simd_has_avx2', simd_has_avx2);
    if BackendInArray(sbAVX512, LBackends) then
      AssertTrue('AVX512 backend listed implies backend-supported predicate',
        LExpectedAVX512Backend);
  end
  else
  begin
    AssertFalse('x86 SSE2 backend should not appear on non-x86 arch', BackendInArray(sbSSE2, LBackends));
    AssertFalse('x86 AVX2 backend should not appear on non-x86 arch', BackendInArray(sbAVX2, LBackends));
    AssertFalse('x86 AVX512 backend should not appear on non-x86 arch', BackendInArray(sbAVX512, LBackends));
  end;
  {$ELSE}
  AssertFalse('x86 SSE2 backend should not appear when x86 cpuinfo is disabled', BackendInArray(sbSSE2, LBackends));
  AssertFalse('x86 AVX2 backend should not appear when x86 cpuinfo is disabled', BackendInArray(sbAVX2, LBackends));
  AssertFalse('x86 AVX512 backend should not appear when x86 cpuinfo is disabled', BackendInArray(sbAVX512, LBackends));
  {$ENDIF}

  {$IFDEF SIMD_ARM_AVAILABLE}
  if LCPUInfo.Arch = caARM then
    AssertEquals('NEON backend presence should match HasNEON', HasNEON, BackendInArray(sbNEON, LBackends));
  {$ENDIF}

  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  if LCPUInfo.Arch = caRISCV then
    AssertEquals('RISCVV backend presence should match HasRISCVV', HasRISCVV, BackendInArray(sbRISCVV, LBackends));
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_X86RawAVX_RemainsVisible_When_OSXSAVE_Disabled;
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

  AssertTrue('raw AVX should remain visible without OSXSAVE', LFeatures.HasAVX);
  AssertTrue('raw AVX2 should remain visible without OSXSAVE', LFeatures.HasAVX2);
  AssertTrue('raw FMA should remain visible without OSXSAVE', LFeatures.HasFMA);
  AssertTrue('raw AVX512F should remain visible without OSXSAVE', LFeatures.HasAVX512F);
  AssertTrue('raw AVX512BW should remain visible without OSXSAVE', LFeatures.HasAVX512BW);
  {$if declared(X86GenericRawFeatures)}
  AssertTrue('GenericRaw should include SIMD-256 when raw AVX/AVX2 exists', gfSimd256 in LRaw);
  AssertTrue('GenericRaw should include SIMD-512 when raw AVX512F exists', gfSimd512 in LRaw);
  AssertTrue('GenericRaw should include FMA when raw FMA exists', gfFMA in LRaw);
  AssertFalse('GenericUsable should gate SIMD-256 without OSXSAVE', gfSimd256 in LUsable);
  AssertFalse('GenericUsable should gate SIMD-512 without OSXSAVE', gfSimd512 in LUsable);
  AssertFalse('GenericUsable should gate FMA without OSXSAVE', gfFMA in LUsable);
  {$endif}
  {$ELSE}
  Ignore('x86 raw AVX OSXSAVE fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_X86RawAVX_RemainsVisible_When_XCR0_Disabled;
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

  AssertTrue('raw AVX should remain visible when XCR0 lacks XMM/YMM', LFeatures.HasAVX);
  AssertTrue('raw AVX2 should remain visible when XCR0 lacks XMM/YMM', LFeatures.HasAVX2);
  AssertTrue('raw FMA should remain visible when XCR0 lacks XMM/YMM', LFeatures.HasFMA);
  AssertTrue('raw AVX512F should remain visible when XCR0 lacks ZMM state', LFeatures.HasAVX512F);
  {$if declared(X86GenericRawFeatures)}
  AssertTrue('GenericRaw should include SIMD-256 when XCR0 disables execution', gfSimd256 in LRaw);
  AssertTrue('GenericRaw should include SIMD-512 when XCR0 disables execution', gfSimd512 in LRaw);
  AssertTrue('GenericRaw should include FMA when XCR0 disables execution', gfFMA in LRaw);
  AssertFalse('GenericUsable should gate SIMD-256 when XCR0 lacks XMM/YMM', gfSimd256 in LUsable);
  AssertFalse('GenericUsable should gate SIMD-512 when XCR0 lacks ZMM state', gfSimd512 in LUsable);
  AssertFalse('GenericUsable should gate FMA when XCR0 lacks XMM/YMM', gfFMA in LUsable);
  {$endif}
  {$ELSE}
  Ignore('x86 raw AVX XCR0 fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_X86UsableAVX_FailCloses_When_AVX2_Without_AVX;
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

  AssertFalse('raw AVX should remain false in malformed AVX2-only CPUID fixture', LFeatures.HasAVX);
  AssertTrue('raw AVX2 should remain visible in malformed CPUID fixture', LFeatures.HasAVX2);
  AssertTrue('raw FMA should remain visible in malformed CPUID fixture', LFeatures.HasFMA);
  AssertTrue('GenericRaw should preserve SIMD-256 when raw AVX2 exists', gfSimd256 in LRaw);
  AssertTrue('GenericRaw should preserve FMA when raw FMA exists', gfFMA in LRaw);
  AssertFalse('GenericUsable should fail-close SIMD-256 when raw AVX prerequisite is missing', gfSimd256 in LUsable);
  AssertFalse('GenericUsable should fail-close FMA when raw AVX prerequisite is missing', gfFMA in LUsable);
  AssertFalse('AVX-512 backend helper should fail-close when only raw AVX prerequisite is missing',
    X86SupportsAVX512BackendOnCPU(LFeatures, True));
  {$ELSE}
  Ignore('x86 malformed AVX2-only fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_X86UsableAVX512_FailCloses_When_AVX512F_Without_AVX2;
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

  AssertTrue('raw AVX should remain visible in malformed AVX512F-only fixture', LFeatures.HasAVX);
  AssertFalse('raw AVX2 should remain false in malformed AVX512F-only fixture', LFeatures.HasAVX2);
  AssertTrue('raw AVX512F should remain visible in malformed AVX512F-only fixture', LFeatures.HasAVX512F);
  AssertTrue('GenericRaw should preserve SIMD-512 when raw AVX512F exists', gfSimd512 in LRaw);
  AssertFalse('GenericUsable should fail-close SIMD-512 when raw AVX2 prerequisite is missing', gfSimd512 in LUsable);
  AssertFalse('AVX-512 backend helper should fail-close when raw AVX2 prerequisite is missing',
    X86SupportsAVX512BackendOnCPU(LFeatures, True));
  {$ELSE}
  Ignore('x86 malformed AVX512F-only fixture skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_AVXUsable_XCR0Semantics;
var
  LCPUInfo: TCPUInfo;
  LExpectedUsable256: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedUsable256 := LCPUInfo.X86.HasAVX and LCPUInfo.OSXSAVE and XCR0EnablesAVX_Local(LCPUInfo);
    AssertEquals('gfSimd256 usable should follow AVX XCR0 semantics', LExpectedUsable256, gfSimd256 in LCPUInfo.GenericUsable);
    AssertEquals('HasAVX2 should match AVX2 usable semantics', LCPUInfo.X86.HasAVX2 and LExpectedUsable256, nextpas.core.simd.cpuinfo.HasAVX2);
    AssertEquals('legacy x86 HasAVX2 should match AVX2 usable semantics', LCPUInfo.X86.HasAVX2 and LExpectedUsable256, nextpas.core.simd.cpuinfo.x86.HasAVX2);
    AssertEquals('simd_has_avx should match AVX usable semantics', LCPUInfo.X86.HasAVX and LExpectedUsable256, simd_has_avx);
    AssertEquals('simd_has_avx2 should match AVX2 usable semantics', LCPUInfo.X86.HasAVX2 and LExpectedUsable256, simd_has_avx2);
  end
  else
  begin
    AssertFalse('HasAVX2 should be false on non-x86 arch', nextpas.core.simd.cpuinfo.HasAVX2);
    AssertFalse('simd_has_avx should be false on non-x86 arch', simd_has_avx);
    AssertFalse('simd_has_avx2 should be false on non-x86 arch', simd_has_avx2);
  end;
  {$ELSE}
  AssertFalse('HasAVX2 should be false when x86 cpuinfo is disabled', nextpas.core.simd.cpuinfo.HasAVX2);
  AssertFalse('simd_has_avx should be false when x86 cpuinfo is disabled', simd_has_avx);
  AssertFalse('simd_has_avx2 should be false when x86 cpuinfo is disabled', simd_has_avx2);
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_AVX512Usable_XCR0Semantics;
var
  LCPUInfo: TCPUInfo;
  LExpectedUsable: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;

  if LCPUInfo.Arch = caX86 then
  begin
    LExpectedUsable := LCPUInfo.X86.HasAVX and LCPUInfo.X86.HasAVX2 and LCPUInfo.X86.HasAVX512F and LCPUInfo.OSXSAVE and XCR0EnablesAVX512_Local(LCPUInfo);
    AssertEquals('gfSimd512 usable should follow AVX-512 XCR0 semantics', LExpectedUsable, gfSimd512 in LCPUInfo.GenericUsable);
    AssertEquals('HasAVX512 should match AVX-512 usable semantics', LExpectedUsable, nextpas.core.simd.cpuinfo.HasAVX512);
    AssertEquals('simd_has_avx512f should match AVX-512 usable semantics', LExpectedUsable, simd_has_avx512f);
  end
  else
  begin
    AssertFalse('HasAVX512 should be false on non-x86 arch', nextpas.core.simd.cpuinfo.HasAVX512);
    AssertFalse('simd_has_avx512f should be false on non-x86 arch', simd_has_avx512f);
  end;
  {$ELSE}
  AssertFalse('HasAVX512 should be false when x86 cpuinfo is disabled', nextpas.core.simd.cpuinfo.HasAVX512);
  AssertFalse('simd_has_avx512f should be false when x86 cpuinfo is disabled', simd_has_avx512f);
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_DiagnosticReport_UsableViewConsistency;
var
  LReport: TCPUInfoDiagnosticReport;
  LExpectedUsable256: Boolean;
  LExpectedUsable512: Boolean;
begin
  LReport := GenerateDiagnosticReport;

  AssertEquals('Diagnostic report validation should match ValidateCPUInfo', ValidateCPUInfo(LReport.CPUInfo), LReport.ValidationPassed);
  AssertEquals('HasFeature(gfSimd128) should match report GenericUsable', nextpas.core.simd.cpuinfo.HasFeature(gfSimd128), gfSimd128 in LReport.CPUInfo.GenericUsable);
  AssertEquals('HasFeature(gfSimd256) should match report GenericUsable', nextpas.core.simd.cpuinfo.HasFeature(gfSimd256), gfSimd256 in LReport.CPUInfo.GenericUsable);
  AssertEquals('HasFeature(gfSimd512) should match report GenericUsable', nextpas.core.simd.cpuinfo.HasFeature(gfSimd512), gfSimd512 in LReport.CPUInfo.GenericUsable);
  AssertEquals('HasFeature(gfAES) should match report GenericUsable', nextpas.core.simd.cpuinfo.HasFeature(gfAES), gfAES in LReport.CPUInfo.GenericUsable);
  AssertEquals('HasFeature(gfSHA) should match report GenericUsable', nextpas.core.simd.cpuinfo.HasFeature(gfSHA), gfSHA in LReport.CPUInfo.GenericUsable);
  AssertEquals('HasFeature(gfFMA) should match report GenericUsable', nextpas.core.simd.cpuinfo.HasFeature(gfFMA), gfFMA in LReport.CPUInfo.GenericUsable);

  {$IFDEF SIMD_X86_AVAILABLE}
  if LReport.CPUInfo.Arch = caX86 then
  begin
    LExpectedUsable256 := LReport.CPUInfo.X86.HasAVX and LReport.CPUInfo.OSXSAVE and XCR0EnablesAVX_Local(LReport.CPUInfo);
    LExpectedUsable512 := LReport.CPUInfo.X86.HasAVX and LReport.CPUInfo.X86.HasAVX2 and LReport.CPUInfo.X86.HasAVX512F and LReport.CPUInfo.OSXSAVE and XCR0EnablesAVX512_Local(LReport.CPUInfo);
    AssertEquals('Diagnostic report SIMD-256 usable should follow AVX XCR0 semantics', LExpectedUsable256, gfSimd256 in LReport.CPUInfo.GenericUsable);
    AssertEquals('Diagnostic report SIMD-512 usable should follow AVX-512 XCR0 semantics', LExpectedUsable512, gfSimd512 in LReport.CPUInfo.GenericUsable);
  end;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_ARMFeatures;
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
  AssertTrue('NEON should be available on AArch64', cpuInfo.ARM.HasNEON);
  AssertTrue('AdvSIMD should be available on AArch64', cpuInfo.ARM.HasAdvSIMD);
  {$ENDIF}

  if cpuInfo.Arch = caARM then
  begin
    AssertEquals(
      'ARM crypto capability should map to GenericRaw AES flag',
      cpuInfo.ARM.HasCrypto,
      gfAES in cpuInfo.GenericRaw
    );
    AssertEquals(
      'ARM crypto capability should map to GenericRaw SHA flag',
      cpuInfo.ARM.HasCrypto,
      gfSHA in cpuInfo.GenericRaw
    );
    AssertEquals(
      'ARM crypto capability should map to GenericUsable AES flag',
      cpuInfo.ARM.HasCrypto,
      gfAES in cpuInfo.GenericUsable
    );
    AssertEquals(
      'ARM crypto capability should map to GenericUsable SHA flag',
      cpuInfo.ARM.HasCrypto,
      gfSHA in cpuInfo.GenericUsable
    );
  end;
  {$ELSE}
  WriteLn('ARM features not available in this build');
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_LoongArchFeatures;
var
  LCPUInfo: TCPUInfo;
begin
  LCPUInfo := GetCPUInfo;

  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  if LCPUInfo.Arch = caLoongArch then
  begin
    WriteLn('LoongArch Features:');
    WriteLn('  LASX: ', LCPUInfo.LoongArch.HasLASX);
    AssertEquals('HasLASX should match cpuinfo record', LCPUInfo.LoongArch.HasLASX, HasLASX);
    AssertEquals(
      'LoongArch LASX capability should map to GenericUsable SIMD-256 flag',
      LCPUInfo.LoongArch.HasLASX,
      gfSimd256 in LCPUInfo.GenericUsable
    );
  end
  else
    AssertFalse('HasLASX should be false on non-LoongArch arch', HasLASX);
  {$ELSE}
  AssertFalse('HasLASX should be false when loongarch cpuinfo is disabled', HasLASX);
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_ARMFeatureParserSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LFeatures: TARMFeatures;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  LFeatures := ParseARMFeaturesFromCpuInfo(
    'Features : fp asimd sve aes sha1 sha2 crc32' + LineEnding
  );
  AssertTrue('Features key should set AdvSIMD through asimd', LFeatures.HasAdvSIMD);
  AssertTrue('Features key should set NEON through asimd', LFeatures.HasNEON);
  AssertTrue('Features key should set FP', LFeatures.HasFP);
  AssertTrue('Features key should set SVE', LFeatures.HasSVE);
  AssertTrue('Features key should set crypto from aes/sha*', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'flags = ASIMD,FP,SVE2,AES,SHA512' + LineEnding
  );
  AssertTrue('flags key should parse asimd', LFeatures.HasAdvSIMD);
  AssertTrue('flags key should parse fp', LFeatures.HasFP);
  AssertTrue('flags key should parse sve2 as SVE capability', LFeatures.HasSVE);
  AssertTrue('flags key should parse crypto tokens', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'cpu features : neon vfpv4 pmull' + LineEnding
  );
  AssertTrue('cpu features key should parse neon', LFeatures.HasNEON);
  AssertTrue('cpu features key should map neon to AdvSIMD', LFeatures.HasAdvSIMD);
  AssertTrue('cpu features key should parse vfpv4 as FP', LFeatures.HasFP);
  AssertTrue('cpu features key should parse pmull as crypto', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'extensions = asimdrdm sha256 aesce pmull2' + LineEnding
  );
  AssertTrue('extensions key should parse asimdrdm as AdvSIMD', LFeatures.HasAdvSIMD);
  AssertTrue('extensions key should map asimdrdm to NEON', LFeatures.HasNEON);
  AssertTrue('extensions key should parse sha*/aes*/pmull* as crypto', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'cpu feature(s) : asimd fp' + LineEnding +
    'isa extension(s) : sve sha256' + LineEnding
  );
  AssertTrue('cpu feature(s) key should parse asimd as AdvSIMD', LFeatures.HasAdvSIMD);
  AssertTrue('cpu feature(s) key should map asimd to NEON', LFeatures.HasNEON);
  AssertTrue('cpu feature(s) key should parse fp', LFeatures.HasFP);
  AssertTrue('isa extension(s) key should parse sve', LFeatures.HasSVE);
  AssertTrue('isa extension(s) key should parse crypto tokens', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'features : shaoxing shanghai' + LineEnding
  );
  AssertFalse('non-feature sha* words should not imply crypto', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'features : sha256sum sha3extra' + LineEnding
  );
  AssertFalse('prefix-only sha* tokens should not imply crypto', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'features : aesop pmuller' + LineEnding
  );
  AssertFalse('non-feature aes*/pmull* words should not imply crypto', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'isa_ext: asimddp fphp' + LineEnding
  );
  AssertTrue('isa_ext key should parse asimd* as AdvSIMD', LFeatures.HasAdvSIMD);
  AssertTrue('isa_ext key should map asimd* to NEON', LFeatures.HasNEON);
  AssertTrue('isa_ext key should parse fphp as FP', LFeatures.HasFP);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'cpu feature = asimdhp' + LineEnding
  );
  AssertTrue('cpu feature key should parse asimdhp as AdvSIMD', LFeatures.HasAdvSIMD);
  AssertTrue('cpu feature key should map asimdhp to NEON', LFeatures.HasNEON);
  AssertTrue('cpu feature key should parse asimdhp as FP', LFeatures.HasFP);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'model name : superfastprocessor' + LineEnding +
    'hardware : sample-board' + LineEnding
  );
  AssertFalse('non-feature keys should not imply NEON', LFeatures.HasNEON);
  AssertFalse('non-feature keys should not imply FP', LFeatures.HasFP);
  AssertFalse('non-feature keys should not imply SVE', LFeatures.HasSVE);
  AssertFalse('non-feature keys should not imply crypto', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'model name : Cortex-A55 sha256 edition' + LineEnding +
    'hardware : asimd fp board' + LineEnding
  );
  AssertFalse('metadata key values should not imply NEON in fallback mode', LFeatures.HasNEON);
  AssertFalse('metadata key values should not imply AdvSIMD in fallback mode', LFeatures.HasAdvSIMD);
  AssertFalse('metadata key values should not imply FP in fallback mode', LFeatures.HasFP);
  AssertFalse('metadata key values should not imply crypto in fallback mode', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'capabilities : asimd fp sve sha256 pmull2' + LineEnding
  );
  AssertTrue('capabilities key should parse as fallback feature-like key (asimd)', LFeatures.HasAdvSIMD);
  AssertTrue('capabilities key should map asimd to NEON', LFeatures.HasNEON);
  AssertTrue('capabilities key should parse fp', LFeatures.HasFP);
  AssertTrue('capabilities key should parse sve', LFeatures.HasSVE);
  AssertTrue('capabilities key should parse crypto tokens', LFeatures.HasCrypto);

  LFeatures := ParseARMFeaturesFromCpuInfo(
    'caps asimd fp' + LineEnding +
    'caps2 sve sha256 pmull' + LineEnding
  );
  AssertTrue('fallback text parser should handle multi-line asimd token', LFeatures.HasAdvSIMD);
  AssertTrue('fallback text parser should map asimd to NEON', LFeatures.HasNEON);
  AssertTrue('fallback text parser should parse FP token', LFeatures.HasFP);
  AssertTrue('fallback text parser should parse SVE token', LFeatures.HasSVE);
  AssertTrue('fallback text parser should parse crypto tokens', LFeatures.HasCrypto);
  {$ELSE}
  Ignore('ARM feature parser samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_ARMHWCAPMergeSamples;
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
  AssertTrue('AArch64 HWCAP FP bit should set FP', LFeatures.HasFP);
  AssertTrue('AArch64 HWCAP ASIMD bit should set NEON', LFeatures.HasNEON);
  AssertTrue('AArch64 HWCAP ASIMD bit should set AdvSIMD', LFeatures.HasAdvSIMD);

  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, QWord(1) shl 22, 0);
  AssertTrue('AArch64 HWCAP SVE bit should set SVE', LFeatures.HasSVE);

  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, QWord(1) shl 3, 0);
  AssertTrue('AArch64 HWCAP AES bit should set Crypto', LFeatures.HasCrypto);
  {$ELSE}
  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, (QWord(1) shl 6) or (QWord(1) shl 12), 0);
  AssertTrue('ARM32 HWCAP VFP bit should set FP', LFeatures.HasFP);
  AssertTrue('ARM32 HWCAP NEON bit should set NEON', LFeatures.HasNEON);
  AssertTrue('ARM32 HWCAP NEON bit should set AdvSIMD', LFeatures.HasAdvSIMD);

  LFeatures := Default(TARMFeatures);
  MergeARMFeaturesFromLinuxHWCAP(LFeatures, 0, (QWord(1) shl 0) or (QWord(1) shl 3));
  AssertTrue('ARM32 HWCAP2 AES/SHA2 bits should set Crypto', LFeatures.HasCrypto);
  {$ENDIF}
  {$ELSE}
  Ignore('ARM HWCAP merge samples skipped on non-Linux');
  Exit;
  {$ENDIF}
  {$ELSE}
  Ignore('ARM HWCAP merge samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_ARMVendorModelParserSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LVendor: string;
  LModel: string;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  AssertTrue(
    'ARM vendor/model parser should accept implementer + model name',
    ParseARMVendorFromCpuInfo(
      'CPU implementer : 0x41' + LineEnding +
      'model name : Cortex-A76' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('implementer should be parsed as vendor candidate', '0x41', LVendor);
  AssertEquals('model name should be parsed as model candidate', 'Cortex-A76', LModel);

  AssertTrue(
    'ARM vendor/model parser should ignore numeric processor index and keep stronger cpu model',
    ParseARMVendorFromCpuInfo(
      'processor : 0' + LineEnding +
      'processor : 1' + LineEnding +
      'vendor = Qualcomm' + LineEnding +
      'cpu model = Kryo 680' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor key should be parsed', 'Qualcomm', LVendor);
  AssertEquals('cpu model should win over numeric processor index', 'Kryo 680', LModel);

  AssertTrue(
    'ARM vendor/model parser should ignore hex/$ processor indexes and keep vendor-only identity',
    ParseARMVendorFromCpuInfo(
      'processor : 0x0' + LineEnding +
      'processor : $1' + LineEnding +
      'vendor : ARM-LAB' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor should still be parsed with hex/$ processor indexes', 'ARM-LAB', LVendor);
  AssertEquals('hex/$ processor indexes should not be promoted as model', '', LModel);

  AssertTrue(
    'same-priority ARM identity keys should keep first non-empty candidate',
    ParseARMVendorFromCpuInfo(
      'cpu implementer : 0x51' + LineEnding +
      'vendor : override-ignored' + LineEnding +
      'model name : FirstModel' + LineEnding +
      'cpu model : SecondModel' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('first same-priority vendor should be preserved', '0x51', LVendor);
  AssertEquals('first same-priority model should be preserved', 'FirstModel', LModel);

  AssertTrue(
    'non-numeric processor value can be used as weak model fallback',
    ParseARMVendorFromCpuInfo(
      'processor : ARMv7 Processor rev 3 (v7l)' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('processor fallback should not invent vendor', '', LVendor);
  AssertEquals('processor fallback should provide model text', 'ARMv7 Processor rev 3 (v7l)', LModel);

  AssertFalse(
    'numeric processor index variants alone should not produce ARM vendor/model',
    ParseARMVendorFromCpuInfo(
      'processor : 0' + LineEnding +
      'processor : 0x1' + LineEnding +
      'processor : $2' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor should stay empty when only numeric processor indexes exist', '', LVendor);
  AssertEquals('model should stay empty when only numeric processor indexes exist', '', LModel);

  AssertFalse(
    'non-identity cpuinfo lines should not produce ARM vendor/model',
    ParseARMVendorFromCpuInfo(
      'Features : fp asimd sve' + LineEnding +
      'BogoMIPS : 48.00' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor should stay empty without identity keys', '', LVendor);
  AssertEquals('model should stay empty without identity keys', '', LModel);
  {$ELSE}
  Ignore('ARM vendor/model parser samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_ARMProcessorInfoBasic;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LInfo: TARMProcessorInfo;
  LInstructionSet: string;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  LInfo := GetARMProcessorInfo;
  LInstructionSet := UpperCase(Trim(LInfo.InstructionSet));

  AssertTrue('ARM processor architecture should not be empty', Trim(LInfo.Architecture) <> '');
  AssertTrue('ARM processor instruction set should not be empty', LInstructionSet <> '');
  AssertTrue('ARM processor core type should not be empty', Trim(LInfo.CoreType) <> '');

  {$IFDEF CPUAARCH64}
  AssertEquals('AArch64 build should report AArch64 architecture', 'AArch64', LInfo.Architecture);
  AssertTrue('AArch64 build should report ARMv8+ instruction set', Pos('ARMV8', LInstructionSet) = 1);
  {$ELSE}
  AssertEquals('ARM32 build should report AArch32 architecture', 'AArch32', LInfo.Architecture);
  AssertTrue('ARM32 build should report ARMv* instruction set', Pos('ARMV', LInstructionSet) = 1);
  {$ENDIF}
  {$ELSE}
  Ignore('ARM processor info test skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_ARMProcessorInfoParserSamples;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  LInstructionSet: string;
  LCoreType: string;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  AssertTrue(
    'cpu architecture numeric value + model name should be parsed deterministically',
    ParseARMProcessorInfoFromCpuInfo(
      'cpu architecture : 8' + LineEnding +
      'model name : ARM Cortex-A72' + LineEnding,
      LInstructionSet, LCoreType
    )
  );
  AssertEquals('cpu architecture numeric value should map to ARMv8-A', 'ARMv8-A', LInstructionSet);
  AssertEquals('model name should map cortex-a family to Cortex-A', 'Cortex-A', LCoreType);

  AssertTrue(
    'isa string should drive instruction set and neoverse model should drive core type',
    ParseARMProcessorInfoFromCpuInfo(
      'isa : armv9-a+sve2' + LineEnding +
      'uarch : Neoverse-V2' + LineEnding,
      LInstructionSet, LCoreType
    )
  );
  AssertEquals('armv9 isa text should normalize to ARMv9-A', 'ARMv9-A', LInstructionSet);
  AssertEquals('neoverse text should normalize to Neoverse', 'Neoverse', LCoreType);

  AssertTrue(
    'model name should provide ARMv7 fallback when dedicated ISA keys are absent',
    ParseARMProcessorInfoFromCpuInfo(
      'model name : ARMv7 Processor rev 4 (v7l)' + LineEnding,
      LInstructionSet, LCoreType
    )
  );
  AssertEquals('ARMv7 model fallback should normalize to ARMv7-A', 'ARMv7-A', LInstructionSet);
  AssertEquals('model fallback without known core family should keep core type empty', '', LCoreType);

  AssertTrue(
    'key=value arch and cpu model should be parsed',
    ParseARMProcessorInfoFromCpuInfo(
      'arch=arm64' + LineEnding +
      'cpu model=Kryo 780' + LineEnding,
      LInstructionSet, LCoreType
    )
  );
  AssertEquals('arm64 arch should normalize to ARMv8-A', 'ARMv8-A', LInstructionSet);
  AssertEquals('kryo model should normalize to Kryo core type', 'Kryo', LCoreType);

  AssertTrue(
    'uarch-only Neoverse token should provide core type without inventing low ISA version',
    ParseARMProcessorInfoFromCpuInfo(
      'uarch : Neoverse-V2' + LineEnding,
      LInstructionSet, LCoreType
    )
  );
  AssertEquals('uarch-only Neoverse token should not invent ARMv2 ISA', '', LInstructionSet);
  AssertEquals('uarch-only Neoverse token should normalize core type', 'Neoverse', LCoreType);

  AssertFalse(
    'numeric processor index lines should not produce instruction set/core type alone',
    ParseARMProcessorInfoFromCpuInfo(
      'processor : 0' + LineEnding +
      'processor : 1' + LineEnding,
      LInstructionSet, LCoreType
    )
  );
  AssertEquals('numeric processor-only sample should keep instruction set empty', '', LInstructionSet);
  AssertEquals('numeric processor-only sample should keep core type empty', '', LCoreType);
  {$ELSE}
  Ignore('ARM processor info parser samples skipped when SIMD_ARM_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_CacheSizeParserSamples;
begin
  AssertEquals('empty text should parse to 0', 0, ParseCacheSizeTextToKB(''));
  AssertEquals('whitespace-only text should parse to 0', 0, ParseCacheSizeTextToKB('   '));
  AssertEquals('zero bytes should parse to 0', 0, ParseCacheSizeTextToKB('0'));
  AssertEquals('negative value should parse to 0', 0, ParseCacheSizeTextToKB('-1K'));
  AssertEquals('32K should parse to 32KB', 32, ParseCacheSizeTextToKB('32K'));
  AssertEquals('32KB should parse to 32KB', 32, ParseCacheSizeTextToKB('32KB'));
  AssertEquals('32KiB should parse to 32KB', 32, ParseCacheSizeTextToKB('32KiB'));
  AssertEquals('mixed-case KiB should parse to 64KB', 64, ParseCacheSizeTextToKB('64kIb'));
  AssertEquals('space-padded unit should parse to 64KB', 64, ParseCacheSizeTextToKB(' 64 KiB '));
  AssertEquals('1M should parse to 1024KB', 1024, ParseCacheSizeTextToKB('1M'));
  AssertEquals('1MiB should parse to 1024KB', 1024, ParseCacheSizeTextToKB('1MiB'));
  AssertEquals('space-padded MB should parse to 1024KB', 1024, ParseCacheSizeTextToKB('1 MB'));
  AssertEquals('1G should parse to 1048576KB', 1024 * 1024, ParseCacheSizeTextToKB('1G'));
  AssertEquals('1GiB should parse to 1048576KB', 1024 * 1024, ParseCacheSizeTextToKB('1GiB'));
  AssertEquals('bare number should be treated as bytes and ceil to KB', 2, ParseCacheSizeTextToKB('2048'));
  AssertEquals('32768 bytes should parse to 32KB', 32, ParseCacheSizeTextToKB('32768'));
  AssertEquals('32768B should parse to 32KB', 32, ParseCacheSizeTextToKB('32768B'));
  AssertEquals('1024B should parse to 1KB', 1, ParseCacheSizeTextToKB('1024B'));
  AssertEquals('1025B should ceil to 2KB', 2, ParseCacheSizeTextToKB('1025B'));
  AssertEquals('1536B should ceil to 2KB', 2, ParseCacheSizeTextToKB('1536B'));
  AssertEquals('invalid size should parse to 0', 0, ParseCacheSizeTextToKB('invalid'));
  AssertEquals('large K value should saturate to Integer max', High(Integer), ParseCacheSizeTextToKB('3000000000K'));
  AssertEquals('large M value should saturate to Integer max', High(Integer), ParseCacheSizeTextToKB('3000000M'));
  AssertEquals('large G value should saturate to Integer max', High(Integer), ParseCacheSizeTextToKB('5000G'));
  AssertEquals('huge byte value should saturate to Integer max', High(Integer), ParseCacheSizeTextToKB('9223372036854775807B'));
end;

procedure TTestCase_PlatformSpecific.Test_NonX86CacheInfoOnLinux;
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

  AssertTrue('Non-x86 cache line size should be positive', LCPUInfo.Cache.LineSize > 0);

  LHasSnapshot := ReadLinuxSysfsCacheSnapshot(LExpectedCache);
  if LHasSnapshot then
  begin
    if LExpectedCache.LineSize > 0 then
      AssertEquals('Non-x86 cache line size should match Linux sysfs snapshot', LExpectedCache.LineSize, LCPUInfo.Cache.LineSize);
    if LExpectedCache.L1DataKB > 0 then
      AssertEquals('Non-x86 L1 data cache should match Linux sysfs snapshot', LExpectedCache.L1DataKB, LCPUInfo.Cache.L1DataKB);
    if LExpectedCache.L1InstrKB > 0 then
      AssertEquals('Non-x86 L1 instruction cache should match Linux sysfs snapshot', LExpectedCache.L1InstrKB, LCPUInfo.Cache.L1InstrKB);
    if LExpectedCache.L2KB > 0 then
      AssertEquals('Non-x86 L2 cache should match Linux sysfs snapshot', LExpectedCache.L2KB, LCPUInfo.Cache.L2KB);
    if LExpectedCache.L3KB > 0 then
      AssertEquals('Non-x86 L3 cache should match Linux sysfs snapshot', LExpectedCache.L3KB, LCPUInfo.Cache.L3KB);
  end;

  LazyCPUInfo.Reset;
  LLazyCPUInfo := GetCPUInfoLazy;
  AssertEquals('Lazy/eager non-x86 vendor should match', LCPUInfo.Vendor, LLazyCPUInfo.Vendor);
  AssertEquals('Lazy/eager non-x86 model should match', LCPUInfo.Model, LLazyCPUInfo.Model);
  AssertEquals('Lazy/eager non-x86 cache line size should match', LCPUInfo.Cache.LineSize, LLazyCPUInfo.Cache.LineSize);
  AssertEquals('Lazy/eager non-x86 L1 data cache should match', LCPUInfo.Cache.L1DataKB, LLazyCPUInfo.Cache.L1DataKB);
  AssertEquals('Lazy/eager non-x86 L1 instruction cache should match', LCPUInfo.Cache.L1InstrKB, LLazyCPUInfo.Cache.L1InstrKB);
  AssertEquals('Lazy/eager non-x86 L2 cache should match', LCPUInfo.Cache.L2KB, LLazyCPUInfo.Cache.L2KB);
  AssertEquals('Lazy/eager non-x86 L3 cache should match', LCPUInfo.Cache.L3KB, LLazyCPUInfo.Cache.L3KB);
  {$ELSE}
  Ignore('Non-x86 cache Linux-specific validation skipped on non-Linux');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_RISCVISAParserSamples;
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
  AssertTrue('compact rv64 ISA should set RV64I', LFeatures.HasRV64I);
  AssertTrue('compact rv64 ISA should set M', LFeatures.HasM);
  AssertTrue('compact rv64 ISA should set A', LFeatures.HasA);
  AssertTrue('compact rv64 ISA should set F', LFeatures.HasF);
  AssertTrue('compact rv64 ISA should set D', LFeatures.HasD);
  AssertTrue('compact rv64 ISA should set C', LFeatures.HasC);
  AssertTrue('compact rv64 ISA should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0' + LineEnding
  );
  AssertTrue('versioned ISA should set RV64I', LFeatures.HasRV64I);
  AssertTrue('versioned ISA should set M', LFeatures.HasM);
  AssertTrue('versioned ISA should set A', LFeatures.HasA);
  AssertTrue('versioned ISA should set F', LFeatures.HasF);
  AssertTrue('versioned ISA should set D', LFeatures.HasD);
  AssertTrue('versioned ISA should set C', LFeatures.HasC);
  AssertTrue('versioned ISA should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa string : rv64g' + LineEnding
  );
  AssertTrue('rv64g should set RV64I', LFeatures.HasRV64I);
  AssertTrue('rv64g should include M', LFeatures.HasM);
  AssertTrue('rv64g should include A', LFeatures.HasA);
  AssertTrue('rv64g should include F', LFeatures.HasF);
  AssertTrue('rv64g should include D', LFeatures.HasD);
  AssertFalse('rv64g should not imply C', LFeatures.HasC);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rva23u64' + LineEnding
  );
  AssertFalse('profile-style rva token should not imply RV64I', LFeatures.HasRV64I);
  AssertFalse('profile-style rva token should not imply RV32I', LFeatures.HasRV32I);
  AssertFalse('profile-style rva token should not imply A extension', LFeatures.HasA);
  AssertFalse('profile-style rva token should not imply vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i rva23u64' + LineEnding
  );
  AssertTrue('rv64i should still set RV64I when profile token is present', LFeatures.HasRV64I);
  AssertFalse('profile token should not add A extension when compact ISA lacks A', LFeatures.HasA);
  AssertFalse('profile token should not imply vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i2p1_zve32x1p0_zvl128b1p0' + LineEnding
  );
  AssertTrue('zve* tokens should imply vector extension', LFeatures.HasV);
  AssertFalse('zve-only sample should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zve' + LineEnding
  );
  AssertFalse('incomplete zve token should not imply vector extension', LFeatures.HasV);
  AssertFalse('incomplete zve token should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvl' + LineEnding
  );
  AssertFalse('incomplete zvl token should not imply vector extension', LFeatures.HasV);
  AssertFalse('incomplete zvl token should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvefoo' + LineEnding
  );
  AssertFalse('malformed zve token without numeric width should not imply vector extension', LFeatures.HasV);
  AssertFalse('malformed zve token should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvlfoo' + LineEnding
  );
  AssertFalse('malformed zvl token without numeric width should not imply vector extension', LFeatures.HasV);
  AssertFalse('malformed zvl token should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zvbb1p0_zvkned1p0' + LineEnding
  );
  AssertTrue('zv* tokens should imply vector extension', LFeatures.HasV);
  AssertFalse('zv-only sample should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zv' + LineEnding
  );
  AssertFalse('incomplete zv token should not imply vector extension', LFeatures.HasV);
  AssertFalse('incomplete zv token should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zv-foo' + LineEnding
  );
  AssertFalse('malformed zv token with punctuation should not imply vector extension', LFeatures.HasV);
  AssertFalse('malformed zv token should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'hart isa : RV64I_XVENTANACONDOPS_ZVBC32E' + LineEnding
  );
  AssertTrue('hart isa key should be recognized', LFeatures.HasRV64I);
  AssertTrue('zv* tokens should imply vector extension even with vendor token noise', LFeatures.HasV);
  AssertFalse('xv/zv-only sample should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'hart isa : RV64I_XVENTANACONDOPS' + LineEnding
  );
  AssertTrue('hart isa key should keep RV64I from compact base token', LFeatures.HasRV64I);
  AssertFalse('xv*-only vendor token should not imply vector extension', LFeatures.HasV);
  AssertFalse('xv-only vendor sample should not imply M', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa extensions = rv64i m a f d c v' + LineEnding
  );
  AssertTrue('isa extensions key should be recognized', LFeatures.HasRV64I);
  AssertTrue('isa extensions should set M', LFeatures.HasM);
  AssertTrue('isa extensions should set A', LFeatures.HasA);
  AssertTrue('isa extensions should set F', LFeatures.HasF);
  AssertTrue('isa extensions should set D', LFeatures.HasD);
  AssertTrue('isa extensions should set C', LFeatures.HasC);
  AssertTrue('isa extensions should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : rv64i m a f d c v' + LineEnding
  );
  AssertTrue('extensions key should be recognized', LFeatures.HasRV64I);
  AssertTrue('extensions key should set M', LFeatures.HasM);
  AssertTrue('extensions key should set A', LFeatures.HasA);
  AssertTrue('extensions key should set F', LFeatures.HasF);
  AssertTrue('extensions key should set D', LFeatures.HasD);
  AssertTrue('extensions key should set C', LFeatures.HasC);
  AssertTrue('extensions key should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : alpha beta gamma' + LineEnding
  );
  AssertFalse('weak extensions key should ignore non-ISA free-form text (no RV64I)', LFeatures.HasRV64I);
  AssertFalse('weak extensions key should ignore non-ISA free-form text (no RV32I)', LFeatures.HasRV32I);
  AssertFalse('weak extensions key should ignore non-ISA free-form text (no M)', LFeatures.HasM);
  AssertFalse('weak extensions key should ignore non-ISA free-form text (no V)', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : a55 board-v2' + LineEnding
  );
  AssertFalse('weak extensions key should ignore mixed metadata tokens (no A)', LFeatures.HasA);
  AssertFalse('weak extensions key should ignore mixed metadata tokens (no V)', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : rv64i m a board-v2' + LineEnding
  );
  AssertFalse('weak extensions key should reject mixed ISA+metadata tokens (no RV64I)', LFeatures.HasRV64I);
  AssertFalse('weak extensions key should reject mixed ISA+metadata tokens (no RV32I)', LFeatures.HasRV32I);
  AssertFalse('weak extensions key should reject mixed ISA+metadata tokens (no M)', LFeatures.HasM);
  AssertFalse('weak extensions key should reject mixed ISA+metadata tokens (no A)', LFeatures.HasA);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'extensions : a55' + LineEnding
  );
  AssertFalse('weak extensions key should not treat metadata-like a55 as A extension', LFeatures.HasA);
  AssertFalse('weak extensions key should not treat metadata-like a55 as RV64I base', LFeatures.HasRV64I);
  AssertFalse('weak extensions key should not treat metadata-like a55 as RV32I base', LFeatures.HasRV32I);
  AssertFalse('weak extensions key should not treat metadata-like a55 as vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv extensions = rv64i2p1_zve32x1p0' + LineEnding
  );
  AssertTrue('riscv extensions key should be recognized', LFeatures.HasRV64I);
  AssertTrue('riscv extensions key should parse vector subset tokens', LFeatures.HasV);
  AssertFalse('riscv extensions sample should not imply D when absent', LFeatures.HasD);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv isa extensions = rv64i_zve32x' + LineEnding
  );
  AssertTrue('riscv isa extensions key should be recognized', LFeatures.HasRV64I);
  AssertTrue('riscv isa extensions key should parse vector subset tokens', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,isa extensions = rv64i_zvkb' + LineEnding
  );
  AssertTrue('riscv,isa extensions key should be recognized', LFeatures.HasRV64I);
  AssertTrue('riscv,isa extensions key should parse vector subset tokens', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv_isa_ext=rv64i_m_a_f_d_c' + LineEnding
  );
  AssertTrue('riscv_isa_ext key should be recognized', LFeatures.HasRV64I);
  AssertTrue('riscv_isa_ext key should set M', LFeatures.HasM);
  AssertTrue('riscv_isa_ext key should set A', LFeatures.HasA);
  AssertTrue('riscv_isa_ext key should set F', LFeatures.HasF);
  AssertTrue('riscv_isa_ext key should set D', LFeatures.HasD);
  AssertTrue('riscv_isa_ext key should set C', LFeatures.HasC);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa_ext=rv64i_m_a_f_d_c' + LineEnding
  );
  AssertTrue('isa_ext key should be recognized', LFeatures.HasRV64I);
  AssertTrue('isa_ext key should set M', LFeatures.HasM);
  AssertTrue('isa_ext key should set A', LFeatures.HasA);
  AssertTrue('isa_ext key should set F', LFeatures.HasF);
  AssertTrue('isa_ext key should set D', LFeatures.HasD);
  AssertTrue('isa_ext key should set C', LFeatures.HasC);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,isa = "rv64imafdcv_zicsr_zifencei"' + LineEnding
  );
  AssertTrue('riscv,isa key should be recognized', LFeatures.HasRV64I);
  AssertTrue('quoted ISA value should set M', LFeatures.HasM);
  AssertTrue('quoted ISA value should set A', LFeatures.HasA);
  AssertTrue('quoted ISA value should set F', LFeatures.HasF);
  AssertTrue('quoted ISA value should set D', LFeatures.HasD);
  AssertTrue('quoted ISA value should set C', LFeatures.HasC);
  AssertTrue('quoted ISA value should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,isa = ''rv64imafdcv_zicsr_zifencei''' + LineEnding
  );
  AssertTrue('single-quoted ISA value should set RV64I', LFeatures.HasRV64I);
  AssertTrue('single-quoted ISA value should set M', LFeatures.HasM);
  AssertTrue('single-quoted ISA value should set A', LFeatures.HasA);
  AssertTrue('single-quoted ISA value should set F', LFeatures.HasF);
  AssertTrue('single-quoted ISA value should set D', LFeatures.HasD);
  AssertTrue('single-quoted ISA value should set C', LFeatures.HasC);
  AssertTrue('single-quoted ISA value should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'vendor_id : rise' + LineEnding +
    'uarch : boom' + LineEnding +
    'mmu : sv39' + LineEnding
  );
  AssertFalse('non-ISA keys should not imply RV64I', LFeatures.HasRV64I);
  AssertFalse('non-ISA keys should not imply M', LFeatures.HasM);
  AssertFalse('non-ISA keys should not imply V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_zmmul_zicsr' + LineEnding
  );
  AssertFalse('zmmul token should not be treated as full M extension', LFeatures.HasM);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    '   ISA EXTENSIONS	:	RV64I M A F D C V   ' + LineEnding
  );
  AssertTrue('mixed-case ISA key should be normalized', LFeatures.HasRV64I);
  AssertTrue('mixed-case ISA key should parse M extension', LFeatures.HasM);
  AssertTrue('mixed-case ISA key should parse A extension', LFeatures.HasA);
  AssertTrue('mixed-case ISA key should parse F extension', LFeatures.HasF);
  AssertTrue('mixed-case ISA key should parse D extension', LFeatures.HasD);
  AssertTrue('mixed-case ISA key should parse C extension', LFeatures.HasC);
  AssertTrue('mixed-case ISA key should parse V extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa : rv64imafdcv' + LineEnding
  );
  AssertFalse('misa key should not be treated as ISA field', LFeatures.HasRV64I);
  AssertFalse('misa key should not imply vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa : 0x800000000020112d' + LineEnding
  );
  AssertTrue('numeric misa bitmask should set RV64I', LFeatures.HasRV64I);
  AssertFalse('numeric misa rv64 sample should not set RV32I', LFeatures.HasRV32I);
  AssertTrue('numeric misa bitmask should set M', LFeatures.HasM);
  AssertTrue('numeric misa bitmask should set A', LFeatures.HasA);
  AssertTrue('numeric misa bitmask should set F', LFeatures.HasF);
  AssertTrue('numeric misa bitmask should set D', LFeatures.HasD);
  AssertTrue('numeric misa bitmask should set C', LFeatures.HasC);
  AssertTrue('numeric misa bitmask should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'csr misa = 0x4020112d' + LineEnding
  );
  AssertFalse('numeric csr misa rv32 sample should not set RV64I', LFeatures.HasRV64I);
  AssertTrue('numeric csr misa rv32 sample should set RV32I', LFeatures.HasRV32I);
  AssertTrue('numeric csr misa rv32 sample should set M', LFeatures.HasM);
  AssertTrue('numeric csr misa rv32 sample should set A', LFeatures.HasA);
  AssertTrue('numeric csr misa rv32 sample should set F', LFeatures.HasF);
  AssertTrue('numeric csr misa rv32 sample should set D', LFeatures.HasD);
  AssertTrue('numeric csr misa rv32 sample should set C', LFeatures.HasC);
  AssertTrue('numeric csr misa rv32 sample should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,misa : $800000000020112d' + LineEnding
  );
  AssertTrue('riscv,misa key should be recognized for numeric misa', LFeatures.HasRV64I);
  AssertTrue('riscv,misa key should set vector extension bit', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa register = 0x8000_0000_0020_112d' + LineEnding
  );
  AssertTrue('misa register key should support underscore-separated hex', LFeatures.HasRV64I);
  AssertTrue('underscore-separated misa should set M extension', LFeatures.HasM);
  AssertTrue('underscore-separated misa should set A extension', LFeatures.HasA);
  AssertTrue('underscore-separated misa should set F extension', LFeatures.HasF);
  AssertTrue('underscore-separated misa should set D extension', LFeatures.HasD);
  AssertTrue('underscore-separated misa should set C extension', LFeatures.HasC);
  AssertTrue('underscore-separated misa should set V extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa csr : 1075847469' + LineEnding
  );
  AssertFalse('decimal misa rv32 sample should not set RV64I', LFeatures.HasRV64I);
  AssertTrue('decimal misa rv32 sample should set RV32I', LFeatures.HasRV32I);
  AssertTrue('decimal misa rv32 sample should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'misa : -1' + LineEnding
  );
  AssertFalse('negative misa should be rejected (no RV64I)', LFeatures.HasRV64I);
  AssertFalse('negative misa should be rejected (no RV32I)', LFeatures.HasRV32I);
  AssertFalse('negative misa should be rejected (no V)', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'march : rv64imafdcv_zicsr' + LineEnding
  );
  AssertTrue('march key should be treated as ISA field', LFeatures.HasRV64I);
  AssertTrue('march key should set M', LFeatures.HasM);
  AssertTrue('march key should set A', LFeatures.HasA);
  AssertTrue('march key should set F', LFeatures.HasF);
  AssertTrue('march key should set D', LFeatures.HasD);
  AssertTrue('march key should set C', LFeatures.HasC);
  AssertTrue('march key should set V', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv,march = rv64i_zvbb' + LineEnding
  );
  AssertTrue('riscv,march key should be treated as ISA field', LFeatures.HasRV64I);
  AssertTrue('riscv,march key should parse vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'riscv march : rv64i_zve32x' + LineEnding
  );
  AssertTrue('riscv march key should be treated as ISA field', LFeatures.HasRV64I);
  AssertTrue('riscv march key should parse vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'marchid : 0x8000000000000007' + LineEnding
  );
  AssertFalse('marchid key should not be treated as ISA field', LFeatures.HasRV64I);
  AssertFalse('marchid key should not imply vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i_svinval_zicbom' + LineEnding
  );
  AssertTrue('non-vector extension sample should keep RV64I', LFeatures.HasRV64I);
  AssertFalse('svinval/zicbom should not imply vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv64i' + LineEnding +
    'isa extensions = m a f d c' + LineEnding +
    'hart isa : rv64i_zvbb' + LineEnding
  );
  AssertTrue('multiple ISA keys should merge RV64I', LFeatures.HasRV64I);
  AssertTrue('multiple ISA keys should merge M', LFeatures.HasM);
  AssertTrue('multiple ISA keys should merge A', LFeatures.HasA);
  AssertTrue('multiple ISA keys should merge F', LFeatures.HasF);
  AssertTrue('multiple ISA keys should merge D', LFeatures.HasD);
  AssertTrue('multiple ISA keys should merge C', LFeatures.HasC);
  AssertTrue('multiple ISA keys should merge vector extension', LFeatures.HasV);

  LFeatures := ParseRISCVFeaturesFromCpuInfo(
    'isa : rv32imafdc' + LineEnding +
    'hart isa : rv64i_zvbb' + LineEnding
  );
  {$IFDEF CPURISCV32}
  AssertTrue('conflicting parser sample should normalize to rv32 baseline on riscv32 build', LFeatures.HasRV32I);
  AssertFalse('conflicting parser sample should clear rv64 baseline on riscv32 build', LFeatures.HasRV64I);
  {$ELSE}
  AssertTrue('conflicting parser sample should normalize to rv64 baseline on non-riscv32 builds', LFeatures.HasRV64I);
  AssertFalse('conflicting parser sample should clear rv32 baseline on non-riscv32 builds', LFeatures.HasRV32I);
  {$ENDIF}
  AssertTrue('conflicting parser sample should keep merged M extension', LFeatures.HasM);
  AssertTrue('conflicting parser sample should keep merged A extension', LFeatures.HasA);
  AssertTrue('conflicting parser sample should keep merged F extension', LFeatures.HasF);
  AssertTrue('conflicting parser sample should keep merged D extension', LFeatures.HasD);
  AssertTrue('conflicting parser sample should keep merged C extension', LFeatures.HasC);
  AssertTrue('conflicting parser sample should keep merged vector extension', LFeatures.HasV);
  {$ELSE}
  Ignore('RISC-V ISA parser samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_RISCVISASelectionSamples;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LISA: string;
  LFeatures: TRISCVFeatures;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  AssertTrue(
    'ISA candidate with RV base should win over extension-only candidate',
    ExtractBestRISCVISAFromCpuInfo(
      'extensions : m a f d c v' + LineEnding +
      'isa : rv64imafdc' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('base ISA candidate should be selected', 'rv64imafdc', LISA);
  AssertTrue('selected ISA should include RV64I', LFeatures.HasRV64I);
  AssertTrue('selected ISA should include M extension', LFeatures.HasM);
  AssertTrue('selected ISA should include D extension', LFeatures.HasD);
  AssertFalse('selected ISA sample should not imply vector extension', LFeatures.HasV);

  AssertTrue(
    'explicit riscv,isa key should win over weaker extensions key',
    ExtractBestRISCVISAFromCpuInfo(
      'riscv extensions = rv64i_zve32x_zvl128b' + LineEnding +
      'riscv,isa = rv64imafdc' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('riscv,isa key should be preferred when both candidates have RV base', 'rv64imafdc', LISA);
  AssertTrue('riscv,isa preferred sample should keep RV64I', LFeatures.HasRV64I);
  AssertFalse('riscv,isa preferred sample should not force vector extension', LFeatures.HasV);

  AssertTrue(
    'numeric misa should synthesize ISA when explicit ISA key is missing',
    ExtractBestRISCVISAFromCpuInfo(
      'processor : 0' + LineEnding +
      'misa : 0x800000000020112d' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('numeric misa should synthesize canonical rv64 ISA string', 'rv64imafdcv', LISA);
  AssertTrue('numeric misa synthesized ISA should include RV64I', LFeatures.HasRV64I);
  AssertTrue('numeric misa synthesized ISA should include V', LFeatures.HasV);

  AssertTrue(
    'numeric misa should backfill base ISA for extension-only ISA key',
    ExtractBestRISCVISAFromCpuInfo(
      'isa extensions : m a f d c v' + LineEnding +
      'csr misa : 0x800000000020112d' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('misa should backfill extension-only ISA key to canonical rv64 ISA', 'rv64imafdcv', LISA);
  AssertTrue('backfilled ISA should include RV64I', LFeatures.HasRV64I);
  AssertTrue('backfilled ISA should include V', LFeatures.HasV);

  AssertFalse(
    'invalid ISA text without parseable tokens should be rejected',
    ExtractBestRISCVISAFromCpuInfo(
      'isa : unknown' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('invalid ISA text should not produce ISA output', '', LISA);

  AssertFalse(
    'profile-style rv token without rv32/rv64 baseline should be rejected',
    ExtractBestRISCVISAFromCpuInfo(
      'isa : rva23u64' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('profile-style token should not produce ISA output', '', LISA);

  AssertTrue(
    'numeric misa should recover from invalid ISA text',
    ExtractBestRISCVISAFromCpuInfo(
      'isa : unknown' + LineEnding +
      'misa : 0x800000000020112d' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('misa should synthesize canonical ISA when textual ISA is invalid', 'rv64imafdcv', LISA);

  AssertFalse(
    'extension-only ISA evidence without RV base/misa should be rejected',
    ExtractBestRISCVISAFromCpuInfo(
      'extensions : m a f d c v' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('extension-only ISA evidence should not emit ISA string', '', LISA);

  AssertFalse(
    'weak extensions metadata-like token should not produce ISA result',
    ExtractBestRISCVISAFromCpuInfo(
      'extensions : a55' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('weak extensions metadata-like token should not emit ISA string', '', LISA);

  AssertFalse(
    'weak extensions key with mixed ISA+metadata tokens should not produce ISA result',
    ExtractBestRISCVISAFromCpuInfo(
      'extensions : rv64i m a board-v2' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('weak extensions mixed ISA+metadata tokens should not emit ISA string', '', LISA);

  AssertFalse(
    'unsupported rv128 textual ISA without rv32/rv64 baseline should be rejected',
    ExtractBestRISCVISAFromCpuInfo(
      'isa : rv128imafdc' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('unsupported rv128 textual ISA should not emit ISA string', '', LISA);

  AssertTrue(
    'conflicting rv32 textual ISA and rv64 misa should normalize to target baseline',
    ExtractBestRISCVISAFromCpuInfo(
      'isa : rv32imafdc' + LineEnding +
      'misa : 0x800000000020112d' + LineEnding,
      LISA,
      LFeatures
    )
  );
  {$IFDEF CPURISCV64}
  AssertEquals('riscv64 build should normalize conflicting ISA evidence to rv64 baseline', 'rv64imafdcv', LISA);
  AssertTrue('riscv64 build should keep RV64I baseline', LFeatures.HasRV64I);
  AssertFalse('riscv64 build should clear conflicting RV32I baseline', LFeatures.HasRV32I);
  {$ELSE}
  AssertEquals('riscv32 build should normalize conflicting ISA evidence to rv32 baseline', 'rv32imafdcv', LISA);
  AssertTrue('riscv32 build should keep RV32I baseline', LFeatures.HasRV32I);
  AssertFalse('riscv32 build should clear conflicting RV64I baseline', LFeatures.HasRV64I);
  {$ENDIF}

  AssertFalse(
    'non-numeric misa without ISA keys should not produce ISA result',
    ExtractBestRISCVISAFromCpuInfo(
      'misa : rv64imafdc' + LineEnding,
      LISA,
      LFeatures
    )
  );
  AssertEquals('failed ISA extraction should keep ISA output empty', '', LISA);
  {$ELSE}
  Ignore('RISC-V ISA selection samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_RISCVHWCAPMergeSamples;
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
  AssertTrue('RISC-V HWCAP I bit should set RV64I on riscv64 build', LFeatures.HasRV64I);
  {$ELSE}
  AssertTrue('RISC-V HWCAP I bit should set RV32I on riscv32 build', LFeatures.HasRV32I);
  {$ENDIF}
  AssertTrue('RISC-V HWCAP M bit should set M', LFeatures.HasM);
  AssertTrue('RISC-V HWCAP A bit should set A', LFeatures.HasA);
  AssertTrue('RISC-V HWCAP F bit should set F', LFeatures.HasF);
  AssertTrue('RISC-V HWCAP D bit should set D', LFeatures.HasD);
  AssertTrue('RISC-V HWCAP C bit should set C', LFeatures.HasC);
  AssertTrue('RISC-V HWCAP V bit should set V', LFeatures.HasV);
  AssertTrue('RISC-V HWCAP raw bits should be preserved', LFeatures.LinuxHWCAP = LHWCAP);
  AssertTrue('RISC-V HWCAP2 raw bits should stay zero when omitted', LFeatures.LinuxHWCAP2 = QWord(0));

  LFeatures := Default(TRISCVFeatures);
  MergeRISCVFeaturesFromLinuxHWCAP(LFeatures, 0, QWord(1));
  AssertFalse('Unmapped HWCAP2-only sample should not imply RVV', LFeatures.HasV);
  AssertTrue('HWCAP2-only sample should keep raw HWCAP empty', LFeatures.LinuxHWCAP = QWord(0));
  AssertTrue('HWCAP2-only sample should preserve raw HWCAP2 bits', LFeatures.LinuxHWCAP2 = QWord(1));
  {$ELSE}
  Ignore('RISC-V HWCAP merge samples skipped on non-Linux');
  Exit;
  {$ENDIF}
  {$ELSE}
  Ignore('RISC-V HWCAP merge samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_RISCVVendorModelParserSamples;
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
var
  LVendor: string;
  LModel: string;
{$ENDIF}
begin
  {$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  AssertTrue(
    'vendor/model parser should accept vendor_id + model name',
    ParseRISCVVendorModelFromCpuInfo(
      'vendor_id : "SiFive"' + LineEnding +
      'model name : ''U74-MC''' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('quoted vendor_id should be normalized', 'SiFive', LVendor);
  AssertEquals('quoted model name should be normalized', 'U74-MC', LModel);

  AssertTrue(
    'vendor/model parser should ignore numeric processor index and keep stronger uarch',
    ParseRISCVVendorModelFromCpuInfo(
      'processor : 0' + LineEnding +
      'processor : 1' + LineEnding +
      'soc : T-HEAD' + LineEnding +
      'uarch : Xuantie C910' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('soc should be used as vendor candidate when vendor_id is missing', 'T-HEAD', LVendor);
  AssertEquals('uarch should win over numeric processor index', 'Xuantie C910', LModel);

  AssertTrue(
    'vendor/model parser should ignore hex/$ processor indexes and keep vendor-only identity',
    ParseRISCVVendorModelFromCpuInfo(
      'processor : 0x0' + LineEnding +
      'processor : $1' + LineEnding +
      'vendor_id : StarFive' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor_id should still be parsed with hex/$ processor indexes', 'StarFive', LVendor);
  AssertEquals('hex/$ processor indexes should not be promoted as model', '', LModel);

  AssertTrue(
    'vendor/model parser should support key=value format',
    ParseRISCVVendorModelFromCpuInfo(
      'vendor=sifive' + LineEnding +
      'cpu model=FU740' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('key=value vendor should be parsed', 'sifive', LVendor);
  AssertEquals('key=value cpu model should be parsed', 'FU740', LModel);

  AssertTrue(
    'strong identity keys should override weaker candidates',
    ParseRISCVVendorModelFromCpuInfo(
      'soc : generic-soc' + LineEnding +
      'vendor_id : VendorStrong' + LineEnding +
      'model : WeakModel' + LineEnding +
      'model name : StrongModel' + LineEnding +
      'processor : 0' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor_id should override soc vendor candidate', 'VendorStrong', LVendor);
  AssertEquals('model name should override weak model/processor candidates', 'StrongModel', LModel);

  AssertTrue(
    'same-priority identity keys should keep first non-empty candidate',
    ParseRISCVVendorModelFromCpuInfo(
      'vendor_id : FirstVendor' + LineEnding +
      'vendor : SecondVendor' + LineEnding +
      'model name : FirstModel' + LineEnding +
      'cpu model : SecondModel' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('first same-priority vendor should be kept', 'FirstVendor', LVendor);
  AssertEquals('first same-priority model should be kept', 'FirstModel', LModel);

  AssertTrue(
    'non-numeric processor value can be used as weak model fallback',
    ParseRISCVVendorModelFromCpuInfo(
      'processor : "JH7110 CPU"' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('weak processor fallback should not produce vendor', '', LVendor);
  AssertEquals('non-numeric processor fallback should produce model', 'JH7110 CPU', LModel);

  AssertFalse(
    'non-identity cpuinfo lines should not produce vendor/model',
    ParseRISCVVendorModelFromCpuInfo(
      'processor : 0' + LineEnding +
      'processor : 1' + LineEnding +
      'processor : 0x2' + LineEnding +
      'processor : $3' + LineEnding +
      'isa : rv64imafdc' + LineEnding,
      LVendor, LModel
    )
  );
  AssertEquals('vendor should stay empty when no identity key exists', '', LVendor);
  AssertEquals('model should stay empty when no identity key exists', '', LModel);
  {$ELSE}
  Ignore('RISC-V vendor/model parser samples skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_RISCVProcessorInfoBasic;
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
  AssertTrue('RISC-V processor architecture should not be empty', LInfo.Architecture <> '');
  AssertTrue('RISC-V processor ISA should not be empty', LInfo.ISA <> '');
  AssertTrue('RISC-V XLEN should be positive', LInfo.XLEN > 0);
  LISA := LowerCase(Trim(LInfo.ISA));

  if LInfo.Architecture = 'RV64' then
  begin
    AssertEquals('RV64 architecture should map to XLEN=64', 64, LInfo.XLEN);
    AssertTrue('RV64 architecture should expose rv64 ISA baseline', Copy(LISA, 1, 4) = 'rv64');
  end
  else if LInfo.Architecture = 'RV32' then
  begin
    AssertEquals('RV32 architecture should map to XLEN=32', 32, LInfo.XLEN);
    AssertTrue('RV32 architecture should expose rv32 ISA baseline', Copy(LISA, 1, 4) = 'rv32');
  end;

  LParsed := ParseRISCVFeaturesFromCpuInfo('isa : ' + LInfo.ISA + LineEnding);
  if LInfo.Architecture = 'RV64' then
    AssertTrue('RISCVProcessorInfo ISA should be consistent with RV64 architecture', LParsed.HasRV64I)
  else if LInfo.Architecture = 'RV32' then
    AssertTrue('RISCVProcessorInfo ISA should be consistent with RV32 architecture', LParsed.HasRV32I);

  LDetected := GetRISCVCPUInfo;
  {$IFDEF CPURISCV64}
  AssertTrue('Detected RISC-V feature set should keep RV64I baseline', LDetected.HasRV64I);
  AssertFalse('Detected RISC-V feature set should not keep conflicting RV32I baseline on riscv64 build', LDetected.HasRV32I);
  {$ELSE}
  AssertTrue('Detected RISC-V feature set should keep RV32I baseline', LDetected.HasRV32I);
  AssertFalse('Detected RISC-V feature set should not keep conflicting RV64I baseline on riscv32 build', LDetected.HasRV64I);
  {$ENDIF}

  if LDetected.HasM then
    AssertTrue('RISCVProcessorInfo ISA should include M when detected', LParsed.HasM);
  if LDetected.HasA then
    AssertTrue('RISCVProcessorInfo ISA should include A when detected', LParsed.HasA);
  if LDetected.HasF then
    AssertTrue('RISCVProcessorInfo ISA should include F when detected', LParsed.HasF);
  if LDetected.HasD then
    AssertTrue('RISCVProcessorInfo ISA should include D when detected', LParsed.HasD);
  if LDetected.HasC then
    AssertTrue('RISCVProcessorInfo ISA should include C when detected', LParsed.HasC);
  if LDetected.HasV then
    AssertTrue('RISCVProcessorInfo ISA should include V when detected', LParsed.HasV);
  {$ELSE}
  Ignore('RISC-V processor info test skipped when SIMD_RISCV_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_PlatformSpecific.Test_FeatureHierarchy;
var
  cpuInfo: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  
  {$IFDEF SIMD_X86_AVAILABLE}
  // 验证 x86 特性层次结构
  if cpuInfo.X86.HasSSE2 then
    AssertTrue('SSE2 requires SSE', cpuInfo.X86.HasSSE);
    
  if cpuInfo.X86.HasSSE3 then
    AssertTrue('SSE3 requires SSE2', cpuInfo.X86.HasSSE2);
    
  if cpuInfo.X86.HasSSSE3 then
    AssertTrue('SSSE3 requires SSE3', cpuInfo.X86.HasSSE3);
    
  if cpuInfo.X86.HasSSE41 then
    AssertTrue('SSE4.1 requires SSSE3', cpuInfo.X86.HasSSSE3);
    
  if cpuInfo.X86.HasSSE42 then
    AssertTrue('SSE4.2 requires SSE4.1', cpuInfo.X86.HasSSE41);
    
  if cpuInfo.X86.HasAVX2 then
    AssertTrue('AVX2 requires AVX', cpuInfo.X86.HasAVX);
    
  if IsBackendSupportedOnCPU(sbAVX512) then
    AssertTrue('AVX512 backend requires AVX2 backend prerequisite', cpuInfo.X86.HasAVX2);
  {$ENDIF}
end;

// === TTestCase_ErrorHandling ===

procedure TTestCase_ErrorHandling.Test_InvalidBackend;
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
    AssertFalse('Invalid backend should not be available', info.Available);
  except
    on ERangeError do
      Exit;
  end;
end;

procedure TTestCase_ErrorHandling.Test_ExceptionHandling;
var
  cpuInfo: TCPUInfo;
begin
  // 测试在异常情况下的行为
  try
    cpuInfo := GetCPUInfo;
    // 正常情况下不应该抛出异常
    AssertTrue('GetCPUInfo should not throw exceptions', cpuInfo.Vendor <> '');
  except
    on E: Exception do
      Fail('GetCPUInfo should not throw exceptions: ' + E.Message);
  end;
end;

initialization
  RegisterTest(TTestCase_Global);
  RegisterTest(TTestCase_ThreadSafety);
  RegisterTest(TTestCase_PlatformSpecific);
  RegisterTest(TTestCase_ErrorHandling);

end.
