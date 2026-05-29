unit nextpas.core.simd.concurrent.testcase;

{**
  @abstract(SIMD 多线程并发测试)

  验证 SIMD 模块在多线程环境下的正确性:
  1. Dispatch table 的并发访问安全性
  2. 多线程同时使用 SIMD 操作时的正确性
  3. 不同向量宽度混合并发测试
  4. 高负载压力测试

  @author(nextpas.core Team)
  @created(2026-02-05)
*}

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, Math,
  fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.backend.adapter,
  nextpas.core.simd.runtime,
  nextpas.core.simd.dispatch;

type
  TSimdStatefulTestCase = class(TSimdVectorAsmStatefulTestCase)
  end;

  {** @abstract(SIMD 并发测试套件) *}
  TTestCase_SimdConcurrent = class(TSimdStatefulTestCase)
  published
    // === 并发计算正确性测试 ===
    {** 多线程并发 F32x4 加法正确性 *}
    procedure Test_Concurrent_F32x4_Add;
    {** 多线程并发 F32x4 乘法正确性 *}
    procedure Test_Concurrent_F32x4_Mul;
    {** 多线程并发 F64x2 操作正确性 *}
    procedure Test_Concurrent_F64x2_Operations;
    {** 多线程并发复合运算正确性 *}
    procedure Test_Concurrent_Compound_Operations;

    // === Dispatch Table 并发访问测试 ===
    {** 多线程同时访问 dispatch table *}
    procedure Test_Concurrent_Dispatch_Access;
    {** 并发查询后端信息 *}
    procedure Test_Concurrent_Backend_Query;
    {** vector-asm 开关与 dispatch 并发读写保护 *}
    procedure Test_Concurrent_VectorAsmToggle_DispatchRead;
    {** 多 writer 竞争下的 vector-asm 开关并发安全 *}
    procedure Test_Concurrent_VectorAsmToggle_MultiWriter_DispatchRead;
    {** public ABI table 与 vector-asm 重绑并发读写保护 *}
    procedure Test_Concurrent_PublicApiToggle_ReadConsistency;
    {** SetActiveBackend/Reset/GetDispatchTable/SetVectorAsmEnabled 混合并发控制 *}
    procedure Test_Concurrent_DispatchMixed_ControlPlane;

    // === 混合操作并发测试 ===
    {** 混合数学运算并发操作 *}
    procedure Test_Concurrent_Mixed_MathOps;
    {** 归约操作并发测试 *}
    procedure Test_Concurrent_Reduction_Operations;

    // === 高负载压力测试 ===
    {** 16 线程密集 SIMD 计算压力测试 *}
    procedure Test_Stress_Concurrent_SIMD;
    {** 长时间运行稳定性测试 *}
    procedure Test_Stress_LongRunning;
    {** 快速线程创建销毁测试 *}
    procedure Test_Stress_RapidThreadCreation;
    {** 大数据量并发处理测试 *}
    procedure Test_Stress_LargeData_Concurrent;
  end;

  {** @abstract(public ABI 并发回归套件) *}
  TTestCase_SimdConcurrentPublicAbi = class(TSimdStatefulTestCase)
  published
    {** public ABI backend text getter 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_PublicAbiBackendText_RegisterBackend_ReadConsistency;
    {** public ABI backend pod info 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_PublicAbiPodInfo_RegisterBackend_ReadConsistency;
    {** current active backend pod info 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_PublicAbiPodInfo_CurrentBackend_RegisterBackend_ReadConsistency;
    {** public API active metadata 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_PublicApiActiveMetadata_RegisterBackend_ReadConsistency;
    {** public API active metadata 与 vector-asm toggle 并发读写保护 *}
    procedure Test_Concurrent_PublicApiActiveMetadata_VectorAsmToggle_ReadConsistency;
  end;

  {** @abstract(framework active metadata 并发回归套件) *}
  TTestCase_SimdConcurrentFramework = class(TSimdStatefulTestCase)
  published
    {** backend adapter ops 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_BackendOps_RegisterBackend_ReadConsistency;
    {** current backend 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_CurrentBackend_RegisterBackend_ReadConsistency;
    {** current backend 与 vector-asm toggle 并发读写保护 *}
    procedure Test_Concurrent_CurrentBackend_VectorAsmToggle_ReadConsistency;
    {** current backend info 与 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_CurrentBackendInfo_RegisterBackend_ReadConsistency;
    {** current runtime snapshot 与 vector-asm toggle 并发读写保护 *}
    procedure Test_Concurrent_RuntimeSnapshot_VectorAsmToggle_ReadConsistency;
    {** dispatchable helper 与 vector-asm toggle 并发读写保护 *}
    procedure Test_Concurrent_DispatchableHelpers_VectorAsmToggle_ReadConsistency;
    {** current backend info 与 vector-asm toggle 并发读写保护 *}
    procedure Test_Concurrent_CurrentBackendInfo_VectorAsmToggle_ReadConsistency;
  end;

  {** @abstract(首次注册路径的并发回归套件) *}
  TTestCase_SimdConcurrentRegistration = class(TSimdStatefulTestCase)
  published
    {** registered backend list 与首次 RegisterBackend 并发读写保护 *}
    procedure Test_Concurrent_RegisteredBackendList_FirstRegistration_ReadConsistency;
  end;

  TSimdDispatchTableArray = array of TSimdDispatchTable;
  TSimdBackendArrayStates = array of TSimdBackendArray;

  // === Worker Thread Classes ===

  {** F32x4 加法工作线程 *}
  TF32x4AddWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** F32x4 乘法工作线程 *}
  TF32x4MulWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** F64x2 操作工作线程 *}
  TF64x2OpsWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** Dispatch Table 访问工作线程 *}
  TDispatchAccessWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 混合数学运算工作线程 *}
  TMixedMathWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 归约操作工作线程 *}
  TReductionWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 复合运算工作线程 *}
  TCompoundOpsWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 压力测试工作线程 *}
  TStressWorker = class(TThread)
  private
    FWorkerIndex: Integer;
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
    FOperationsCompleted: Int64;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex, AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
    property OperationsCompleted: Int64 read FOperationsCompleted;
  end;

  {** 后端查询工作线程 *}
  TBackendQueryThread = class(TThread)
  private
    FWorkerIndex: Integer;
    FResult: TSimdBackend;
    FSuccess: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex: Integer);
    property Result: TSimdBackend read FResult;
    property Success: Boolean read FSuccess;
  end;

  {** vector-asm 开关写线程 *}
  TVectorAsmToggleWorker = class(TThread)
  private
    FIterations: Integer;
    FInitialValue: Boolean;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AIterations: Integer; AInitialValue: Boolean);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 多 writer 场景下的 vector-asm 开关写线程 *}
  TVectorAsmMultiToggleWorker = class(TThread)
  private
    FIterations: Integer;
    FWriterPhase: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AIterations, AWriterPhase: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** dispatch 只读工作线程（与开关写线程并发） *}
  TVectorAsmReadWorker = class(TThread)
  private
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** public ABI 只读工作线程（与重绑写线程并发） *}
  TPublicApiReadWorker = class(TThread)
  private
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** RegisterBackend 可用性切换写线程（用于 public ABI pod info 并发回归） *}
  TBackendRegisterToggleWorker = class(TThread)
  private
    FIterations: Integer;
    FBackend: TSimdBackend;
    FTableEnabled: TSimdDispatchTable;
    FTableDisabled: TSimdDispatchTable;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; aBackend: TSimdBackend;
      const aTableEnabled, aTableDisabled: TSimdDispatchTable);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** public ABI backend pod info 只读线程（与 RegisterBackend 写线程并发） *}
  TPublicAbiPodInfoReadWorker = class(TThread)
  private
    FIterations: Integer;
    FBackend: TSimdBackend;
    FExpectedCapsA: UInt64;
    FExpectedCapsB: UInt64;
    FExpectedFlagsA: TNextPasSimdAbiFlags;
    FExpectedFlagsB: TNextPasSimdAbiFlags;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; aBackend: TSimdBackend;
      aExpectedCapsA, aExpectedCapsB: UInt64;
      aExpectedFlagsA, aExpectedFlagsB: TNextPasSimdAbiFlags);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** public ABI backend text getter 只读线程（与 RegisterBackend 写线程并发） *}
  TPublicAbiBackendTextReadWorker = class(TThread)
  private
    FIterations: Integer;
    FBackend: TSimdBackend;
    FExpectedNameA: AnsiString;
    FExpectedNameB: AnsiString;
    FExpectedDescriptionA: AnsiString;
    FExpectedDescriptionB: AnsiString;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; aBackend: TSimdBackend;
      const aExpectedNameA, aExpectedNameB, aExpectedDescriptionA,
      aExpectedDescriptionB: AnsiString);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** current backend pod info 只读线程（允许 enabled-active / enabled-inactive / disabled-inactive 三态） *}
  TCurrentBackendPodInfoReadWorker = class(TThread)
  private
    FIterations: Integer;
    FBackend: TSimdBackend;
    FExpectedCapsEnabled: UInt64;
    FExpectedCapsDisabled: UInt64;
    FExpectedFlagsEnabledActive: TNextPasSimdAbiFlags;
    FExpectedFlagsEnabledInactive: TNextPasSimdAbiFlags;
    FExpectedFlagsDisabledInactive: TNextPasSimdAbiFlags;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; aBackend: TSimdBackend;
      aExpectedCapsEnabled, aExpectedCapsDisabled: UInt64;
      aExpectedFlagsEnabledActive, aExpectedFlagsEnabledInactive,
      aExpectedFlagsDisabledInactive: TNextPasSimdAbiFlags);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** current backend info 只读线程（与 RegisterBackend 写线程并发） *}
  TCurrentBackendReadWorker = class(TThread)
  private
    FIterations: Integer;
    FExpectedBackendA: TSimdBackend;
    FExpectedBackendB: TSimdBackend;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer;
      aExpectedBackendA, aExpectedBackendB: TSimdBackend);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** current backend info 只读线程（与 RegisterBackend 写线程并发） *}
  TCurrentBackendInfoReadWorker = class(TThread)
  private
    FIterations: Integer;
    FExpectedInfoA: TSimdBackendInfo;
    FExpectedInfoB: TSimdBackendInfo;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer;
      const aExpectedInfoA, aExpectedInfoB: TSimdBackendInfo);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** current runtime snapshot 只读线程（与 vector-asm toggle 写线程并发） *}
  TCurrentRuntimeSnapshotReadWorker = class(TThread)
  private
    FIterations: Integer;
    FExpectedSnapshotA: TSimdRuntimeSnapshot;
    FExpectedSnapshotB: TSimdRuntimeSnapshot;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer;
      const aExpectedSnapshotA, aExpectedSnapshotB: TSimdRuntimeSnapshot);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** backend adapter ops 只读线程（与 RegisterBackend 写线程并发） *}
  TBackendOpsReadWorker = class(TThread)
  private
    FIterations: Integer;
    FBackend: TSimdBackend;
    FExpectedTableA: TSimdDispatchTable;
    FExpectedTableB: TSimdDispatchTable;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; aBackend: TSimdBackend;
      const aExpectedTableA, aExpectedTableB: TSimdDispatchTable);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** dispatchable helper 只读线程（与 vector-asm toggle 写线程并发） *}
  TDispatchableHelpersReadWorker = class(TThread)
  private
    FIterations: Integer;
    FExpectedListEnabled: TSimdBackendArray;
    FExpectedListDisabled: TSimdBackendArray;
    FExpectedBestEnabled: TSimdBackend;
    FExpectedBestDisabled: TSimdBackend;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer;
      const aExpectedListEnabled, aExpectedListDisabled: TSimdBackendArray;
      aExpectedBestEnabled, aExpectedBestDisabled: TSimdBackend);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** public API active metadata 只读线程（与 RegisterBackend 写线程并发） *}
  TPublicApiActiveMetadataReadWorker = class(TThread)
  private
    FIterations: Integer;
    FExpectedBackendA: TSimdBackend;
    FExpectedBackendB: TSimdBackend;
    FExpectedFlagsA: TNextPasSimdAbiFlags;
    FExpectedFlagsB: TNextPasSimdAbiFlags;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; aExpectedBackendA, aExpectedBackendB: TSimdBackend;
      aExpectedFlagsA, aExpectedFlagsB: TNextPasSimdAbiFlags);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 首次注册序列写线程（按给定顺序把 previously-unregistered backend 注册进 binary） *}
  TBackendFirstRegisterSequenceWorker = class(TThread)
  private
    FBackends: TSimdBackendArray;
    FTables: TSimdDispatchTableArray;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const aBackends: TSimdBackendArray;
      const aTables: TSimdDispatchTableArray);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** registered backend list 只读线程（与首次 RegisterBackend 写线程并发） *}
  TRegisteredBackendListReadWorker = class(TThread)
  private
    FIterations: Integer;
    FExpectedStates: TSimdBackendArrayStates;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer; const aExpectedStates: TSimdBackendArrayStates);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** dispatch 控制面混合并发线程 *}
  TDispatchMixedControlWorker = class(TThread)
  private
    FIterations: Integer;
    FWorkerPhase: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AIterations, AWorkerPhase: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  {** 大数据处理工作线程 *}
  TLargeDataThread = class(TThread)
  private
    FWorkerIndex: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkerIndex: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

implementation

const
  // 默认并发参数
  DEFAULT_THREAD_COUNT = 8;
  DEFAULT_ITERATIONS = 10000;
  STRESS_THREAD_COUNT = 16;
  STRESS_ITERATIONS = 50000;
  LONG_RUNNING_SECONDS = 2;
  FLOAT_EPSILON: Single = 1e-4;
  DOUBLE_EPSILON: Double = 1e-9;

// === Helper Functions ===

function MakeSplatF32x4(value: Single): TVecF32x4;
begin
  Result := VecF32x4Splat(value);
end;

function MakeSplatF64x2(value: Double): TVecF64x2;
begin
  Result := VecF64x2Splat(value);
end;

function CapabilitiesToAbiBitsLocal(const aCaps: TSimdCapabilities): UInt64;
var
  LCap: TSimdCapability;
begin
  Result := 0;
  for LCap := Low(TSimdCapability) to High(TSimdCapability) do
    if LCap in aCaps then
      Result := Result or (UInt64(1) shl Ord(LCap));
end;

function BuildExpectedAbiFlagsLocal(const aBackend: TSimdBackend;
  const aSupportedOnCPU, aRegistered, aDispatchable, aActive: Boolean): TNextPasSimdAbiFlags;
begin
  Result := 0;
  if aSupportedOnCPU then
    Result := Result or FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU;
  if aRegistered then
    Result := Result or FAF_SIMD_ABI_FLAG_REGISTERED;
  if aDispatchable then
    Result := Result or FAF_SIMD_ABI_FLAG_DISPATCHABLE;
  if aActive then
    Result := Result or FAF_SIMD_ABI_FLAG_ACTIVE;
  if aBackend = sbRISCVV then
    Result := Result or FAF_SIMD_ABI_FLAG_EXPERIMENTAL;
end;

function BackendInfoMatchesLocal(const aInfo, aExpected: TSimdBackendInfo): Boolean;
begin
  Result := (aInfo.Backend = aExpected.Backend) and
    (aInfo.Name = aExpected.Name) and
    (aInfo.Description = aExpected.Description) and
    (aInfo.Capabilities = aExpected.Capabilities) and
    (aInfo.Available = aExpected.Available) and
    (aInfo.Priority = aExpected.Priority);
end;

function ConcurrentBackendName(const aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

function DescribeBackendInfoLocal(const aInfo: TSimdBackendInfo): string;
begin
  Result := Format('backend=%s available=%s caps=%d priority=%d name=%s',
    [ConcurrentBackendName(aInfo.Backend), BoolToStr(aInfo.Available, True),
     CapabilitiesToAbiBitsLocal(aInfo.Capabilities), aInfo.Priority, aInfo.Name]);
end;

function DispatchTableRepresentativeSliceMatchesLocal(const aTable,
  aExpected: TSimdDispatchTable): Boolean;
begin
  Result := (aTable.Backend = aExpected.Backend) and
    BackendInfoMatchesLocal(aTable.BackendInfo, aExpected.BackendInfo) and
    (Pointer(aTable.AddF32x4) = Pointer(aExpected.AddF32x4)) and
    (Pointer(aTable.MulF32x4) = Pointer(aExpected.MulF32x4)) and
    (Pointer(aTable.AddI32x4) = Pointer(aExpected.AddI32x4)) and
    (Pointer(aTable.SelectF32x4) = Pointer(aExpected.SelectF32x4));
end;

function SameBackendArrayLocal(const aLeft, aRight: TSimdBackendArray): Boolean;
var
  LIndex: Integer;
begin
  if Length(aLeft) <> Length(aRight) then
    Exit(False);

  for LIndex := 0 to High(aLeft) do
    if aLeft[LIndex] <> aRight[LIndex] then
      Exit(False);

  Result := True;
end;

function DescribeBackendArrayLocal(const aBackends: TSimdBackendArray): string;
var
  LIndex: Integer;
begin
  Result := '[';
  for LIndex := 0 to High(aBackends) do
  begin
    if LIndex > 0 then
      Result := Result + ',';
    Result := Result + ConcurrentBackendName(aBackends[LIndex]);
  end;
  Result := Result + ']';
end;

function RuntimeSnapshotMatchesLocal(const aSnapshot,
  aExpected: TSimdRuntimeSnapshot): Boolean;
begin
  Result := (aSnapshot.CurrentBackend = aExpected.CurrentBackend) and
    BackendInfoMatchesLocal(aSnapshot.CurrentBackendInfo, aExpected.CurrentBackendInfo) and
    SameBackendArrayLocal(aSnapshot.RegisteredBackends, aExpected.RegisteredBackends) and
    SameBackendArrayLocal(aSnapshot.DispatchableBackends, aExpected.DispatchableBackends) and
    (aSnapshot.BestDispatchableBackend = aExpected.BestDispatchableBackend);
end;

function DescribeRuntimeSnapshotLocal(const aSnapshot: TSimdRuntimeSnapshot): string;
begin
  Result := Format(
    'backend=%s info=(%s) registered=%s dispatchable=%s best=%s',
    [ConcurrentBackendName(aSnapshot.CurrentBackend),
     DescribeBackendInfoLocal(aSnapshot.CurrentBackendInfo),
     DescribeBackendArrayLocal(aSnapshot.RegisteredBackends),
     DescribeBackendArrayLocal(aSnapshot.DispatchableBackends),
     ConcurrentBackendName(aSnapshot.BestDispatchableBackend)]);
end;

function DescribeBackendArrayStatesLocal(const aStates: TSimdBackendArrayStates): string;
var
  LIndex: Integer;
begin
  Result := '{';
  for LIndex := 0 to High(aStates) do
  begin
    if LIndex > 0 then
      Result := Result + ' | ';
    Result := Result + DescribeBackendArrayLocal(aStates[LIndex]);
  end;
  Result := Result + '}';
end;

function BuildRegisteredBackendSnapshotLocal(const aBaseRegistered,
  aRegistrationOrder: TSimdBackendArray; aRegisteredCount: Integer): TSimdBackendArray;
var
  LPresent: array[TSimdBackend] of Boolean;
  LBackend: TSimdBackend;
  LIndex: Integer;
  LCount: Integer;
begin
  FillChar(LPresent, SizeOf(LPresent), 0);
  for LIndex := 0 to High(aBaseRegistered) do
    LPresent[aBaseRegistered[LIndex]] := True;
  for LIndex := 0 to aRegisteredCount - 1 do
    LPresent[aRegistrationOrder[LIndex]] := True;

  LCount := 0;
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    if LPresent[LBackend] then
      Inc(LCount);

  SetLength(Result, LCount);
  LCount := 0;
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    if LPresent[LBackend] then
    begin
      Result[LCount] := LBackend;
      Inc(LCount);
    end;
end;

function TryFindInactiveSupportedBackendForPodInfoMutation(out aBackend: TSimdBackend;
  out aDispatchTable: TSimdDispatchTable): Boolean;
var
  LBackend: TSimdBackend;
  LActiveBackend: TSimdBackend;
begin
  Result := False;
  aBackend := sbScalar;
  aDispatchTable := Default(TSimdDispatchTable);
  LActiveBackend := GetActiveBackend;

  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if (LBackend = sbScalar) or (LBackend = LActiveBackend) then
      Continue;
    if not IsBackendAvailableOnCPU(LBackend) then
      Continue;
    if not TryGetRegisteredBackendDispatchTable(LBackend, aDispatchTable) then
      Continue;
    if not aDispatchTable.BackendInfo.Available then
      Continue;
    if aDispatchTable.BackendInfo.Capabilities = [] then
      Continue;
    aBackend := LBackend;
    Exit(True);
  end;
end;

// === TF32x4AddWorker ===

constructor TF32x4AddWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TF32x4AddWorker.Execute;
var
  i: Integer;
  a, b, c: TVecF32x4;
  expected, actual: Single;
  baseVal: Single;
begin
  try
    // 每个线程使用不同的基础值避免缓存效应
    baseVal := FWorkerIndex * 100.0;

    for i := 0 to FIterations - 1 do
    begin
      // 创建向量
      a := MakeSplatF32x4(baseVal + i);
      b := MakeSplatF32x4(i * 0.5);

      // 执行 SIMD 加法
      c := VecF32x4Add(a, b);

      // 验证结果
      expected := (baseVal + i) + (i * 0.5);
      actual := VecF32x4Extract(c, 0);

      if Abs(actual - expected) > FLOAT_EPSILON * Max(1.0, Abs(expected)) then
      begin
        FErrorMsg := Format('Worker %d, iter %d: expected %.6f, got %.6f',
                           [FWorkerIndex, i, expected, actual]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TF32x4MulWorker ===

constructor TF32x4MulWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TF32x4MulWorker.Execute;
var
  i: Integer;
  a, b, c: TVecF32x4;
  expected, actual: Single;
  baseVal: Single;
begin
  try
    baseVal := (FWorkerIndex + 1) * 10.0;

    for i := 0 to FIterations - 1 do
    begin
      a := MakeSplatF32x4(baseVal);
      b := MakeSplatF32x4((i mod 100 + 1) * 0.01);

      c := VecF32x4Mul(a, b);

      expected := baseVal * ((i mod 100 + 1) * 0.01);
      actual := VecF32x4Extract(c, 0);

      if Abs(actual - expected) > FLOAT_EPSILON * Max(1.0, Abs(expected)) then
      begin
        FErrorMsg := Format('Worker %d, iter %d: expected %.6f, got %.6f',
                           [FWorkerIndex, i, expected, actual]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TF64x2OpsWorker ===

constructor TF64x2OpsWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TF64x2OpsWorker.Execute;
var
  i: Integer;
  a, b, c: TVecF64x2;
  expected, actual: Double;
  baseVal: Double;
begin
  try
    baseVal := FWorkerIndex * 10000.0;

    for i := 0 to FIterations - 1 do
    begin
      a := MakeSplatF64x2(baseVal + i);
      b := MakeSplatF64x2((i mod 1000 + 1) * 0.001);

      // 测试乘法
      c := VecF64x2Mul(a, b);

      expected := (baseVal + i) * ((i mod 1000 + 1) * 0.001);
      actual := c.d[0];

      if Abs(actual - expected) > DOUBLE_EPSILON * Abs(expected) + DOUBLE_EPSILON then
      begin
        FErrorMsg := Format('Worker %d, iter %d: expected %.10f, got %.10f',
                           [FWorkerIndex, i, expected, actual]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TDispatchAccessWorker ===

constructor TDispatchAccessWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TDispatchAccessWorker.Execute;
var
  i: Integer;
  backend: TSimdBackend;
  dt: PSimdDispatchTable;
  a, b, c: TVecF32x4;
begin
  try
    for i := 0 to FIterations - 1 do
    begin
      // 并发访问 dispatch table
      backend := GetActiveBackend;
      dt := GetDispatchTable;

      // 验证 dispatch table 有效
      if dt = nil then
      begin
        FErrorMsg := Format('Worker %d, iter %d: dispatch table is nil', [FWorkerIndex, i]);
        Exit;
      end;

      // 验证后端一致性
      if dt^.Backend <> backend then
      begin
        FErrorMsg := Format('Worker %d, iter %d: backend mismatch (table=%d, active=%d)',
                           [FWorkerIndex, i, Ord(dt^.Backend), Ord(backend)]);
        Exit;
      end;

      // 验证函数指针有效
      if not Assigned(dt^.AddF32x4) then
      begin
        FErrorMsg := Format('Worker %d, iter %d: AddF32x4 not assigned', [FWorkerIndex, i]);
        Exit;
      end;

      // 执行实际操作验证功能正常
      a := MakeSplatF32x4(1.0);
      b := MakeSplatF32x4(2.0);
      c := dt^.AddF32x4(a, b);

      if Abs(VecF32x4Extract(c, 0) - 3.0) > FLOAT_EPSILON then
      begin
        FErrorMsg := Format('Worker %d, iter %d: operation result incorrect', [FWorkerIndex, i]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TMixedMathWorker ===

constructor TMixedMathWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TMixedMathWorker.Execute;
var
  i: Integer;
  a, b, c, d: TVecF32x4;
  expected, actual: Single;
  baseVal: Single;
begin
  try
    baseVal := (FWorkerIndex + 1) * 50.0;

    for i := 0 to FIterations - 1 do
    begin
      // 执行一系列混合操作
      a := MakeSplatF32x4(baseVal);
      b := MakeSplatF32x4(i mod 50 + 1);

      // c = a + b
      c := VecF32x4Add(a, b);
      // d = c * a - b
      d := VecF32x4Sub(VecF32x4Mul(c, a), b);

      expected := (baseVal + (i mod 50 + 1)) * baseVal - (i mod 50 + 1);
      actual := VecF32x4Extract(d, 0);

      if Abs(actual - expected) > FLOAT_EPSILON * Max(1.0, Abs(expected)) then
      begin
        FErrorMsg := Format('Worker %d, iter %d: expected %.6f, got %.6f',
                           [FWorkerIndex, i, expected, actual]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TReductionWorker ===

constructor TReductionWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TReductionWorker.Execute;
var
  i: Integer;
  a: TVecF32x4;
  expected, actual: Single;
  baseVal: Single;
begin
  try
    baseVal := FWorkerIndex + 1;

    for i := 0 to FIterations - 1 do
    begin
      // 创建包含不同值的向量并进行归约
      a := MakeSplatF32x4(baseVal * (i mod 100 + 1));

      // 测试归约加法
      actual := VecF32x4ReduceAdd(a);
      expected := baseVal * (i mod 100 + 1) * 4;  // 4个相同的元素相加

      if Abs(actual - expected) > FLOAT_EPSILON * Max(1.0, Abs(expected)) then
      begin
        FErrorMsg := Format('Worker %d, iter %d: expected %.6f, got %.6f',
                           [FWorkerIndex, i, expected, actual]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TCompoundOpsWorker ===

constructor TCompoundOpsWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TCompoundOpsWorker.Execute;
var
  i, j: Integer;
  a, b, c: TVecF32x4;
  sum: Single;
  baseVal: Single;
begin
  try
    baseVal := (FWorkerIndex + 1) * 10.0;

    for i := 0 to FIterations - 1 do
    begin
      // 执行多次迭代的复合运算
      a := MakeSplatF32x4(baseVal);
      b := MakeSplatF32x4(0.1);

      for j := 0 to 9 do
      begin
        c := VecF32x4Add(a, b);
        a := VecF32x4Mul(c, MakeSplatF32x4(0.99));
      end;

      // 验证结果不是 NaN 或 Inf
      sum := VecF32x4ReduceAdd(a);
      if IsNan(sum) or IsInfinite(sum) then
      begin
        FErrorMsg := Format('Worker %d, iter %d: invalid result', [FWorkerIndex, i]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TStressWorker ===

constructor TStressWorker.Create(AWorkerIndex, AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
  FOperationsCompleted := 0;
end;

procedure TStressWorker.Execute;
var
  i, j: Integer;
  a4, b4, c4: TVecF32x4;
  checksum: Single;
  baseVal: Single;
begin
  try
    baseVal := FWorkerIndex * 10000.0;
    checksum := 0;

    for i := 0 to FIterations - 1 do
    begin
      // 执行多种 SIMD 操作
      a4 := MakeSplatF32x4(baseVal + i);
      b4 := MakeSplatF32x4(0.001);

      for j := 0 to 9 do
      begin
        c4 := VecF32x4Add(a4, b4);
        a4 := VecF32x4Mul(c4, b4);
        Inc(FOperationsCompleted, 2);
      end;

      checksum := checksum + VecF32x4Extract(a4, 0);

      // 防止编译器优化掉计算
      if IsNan(checksum) or IsInfinite(checksum) then
      begin
        // 重置checksum但继续测试
        checksum := 0;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Worker %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TBackendQueryThread ===

constructor TBackendQueryThread.Create(AWorkerIndex: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FSuccess := False;
end;

procedure TBackendQueryThread.Execute;
var
  k: Integer;
begin
  try
    for k := 0 to 999 do
      FResult := GetActiveBackend;
    FSuccess := True;
  except
    FSuccess := False;
  end;
end;

// === TVectorAsmToggleWorker ===

constructor TVectorAsmToggleWorker.Create(AIterations: Integer; AInitialValue: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := AIterations;
  FInitialValue := AInitialValue;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TVectorAsmToggleWorker.Execute;
var
  LIndex: Integer;
  LExpected: Boolean;
  LCurrent: Boolean;
  LDispatch: PSimdDispatchTable;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 1) = 0 then
        LExpected := not FInitialValue
      else
        LExpected := FInitialValue;

      SetVectorAsmEnabled(LExpected);
      LCurrent := IsVectorAsmEnabled;
      if LCurrent <> LExpected then
      begin
        FErrorMsg := Format('toggle mismatch at iter %d: expected=%s got=%s',
          [LIndex, BoolToStr(LExpected, True), BoolToStr(LCurrent, True)]);
        Exit;
      end;

      LDispatch := GetDispatchTable;
      if (LDispatch = nil) or (not Assigned(LDispatch^.AddF32x4)) then
      begin
        FErrorMsg := Format('dispatch unavailable at iter %d', [LIndex]);
        Exit;
      end;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'toggle worker exception: ' + E.Message;
  end;
end;

// === TVectorAsmMultiToggleWorker ===

constructor TVectorAsmMultiToggleWorker.Create(AIterations, AWriterPhase: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := AIterations;
  FWriterPhase := AWriterPhase;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TVectorAsmMultiToggleWorker.Execute;
var
  LIndex: Integer;
  LTargetEnabled: Boolean;
  LDispatch: PSimdDispatchTable;
  LA, LB, LC: TVecF32x4;
  LValue: Single;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      LTargetEnabled := ((LIndex + FWriterPhase) and 1) = 0;
      SetVectorAsmEnabled(LTargetEnabled);

      LDispatch := GetDispatchTable;
      if (LDispatch = nil) or (not Assigned(LDispatch^.SubF32x4)) then
      begin
        FErrorMsg := Format('multi-writer dispatch unavailable at iter %d', [LIndex]);
        Exit;
      end;

      LA := MakeSplatF32x4(4.0);
      LB := MakeSplatF32x4(-1.0);
      LC := LDispatch^.SubF32x4(LA, LB);
      LValue := VecF32x4Extract(LC, 0);
      if Abs(LValue - 5.0) > FLOAT_EPSILON then
      begin
        FErrorMsg := Format('multi-writer dispatch sub mismatch at iter %d: %.6f', [LIndex, LValue]);
        Exit;
      end;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'multi-writer toggle exception: ' + E.Message;
  end;
end;

// === TVectorAsmReadWorker ===

constructor TVectorAsmReadWorker.Create(AIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := AIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TVectorAsmReadWorker.Execute;
var
  LIndex: Integer;
  LA, LB, LC: TVecF32x4;
  LDispatch: PSimdDispatchTable;
  LValue: Single;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      LDispatch := GetDispatchTable;
      if (LDispatch = nil) or (not Assigned(LDispatch^.AddF32x4)) then
      begin
        FErrorMsg := Format('dispatch unavailable at iter %d', [LIndex]);
        Exit;
      end;

      LA := MakeSplatF32x4(1.0);
      LB := MakeSplatF32x4(2.0);
      LC := LDispatch^.AddF32x4(LA, LB);
      LValue := VecF32x4Extract(LC, 0);
      if Abs(LValue - 3.0) > FLOAT_EPSILON then
      begin
        FErrorMsg := Format('dispatch add mismatch at iter %d: %.6f', [LIndex, LValue]);
        Exit;
      end;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'reader worker exception: ' + E.Message;
  end;
end;

// === TDispatchMixedControlWorker ===

constructor TPublicApiReadWorker.Create(aIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TPublicApiReadWorker.Execute;
var
  LIndex: Integer;
  LApi: PNextPasSimdPublicApi;
  LExpectedFlags: TNextPasSimdAbiFlags;
  LExpectedAbiMajor: UInt16;
  LExpectedAbiMinor: UInt16;
  LExpectedSigHi: UInt64;
  LExpectedSigLo: UInt64;
  LBufA: array[0..31] of Byte;
  LBufB: array[0..31] of Byte;
begin
  try
    FillChar(LBufA, SizeOf(LBufA), $5A);
    FillChar(LBufB, SizeOf(LBufB), $5A);
    LExpectedFlags := FAF_SIMD_ABI_FLAG_REGISTERED or
      FAF_SIMD_ABI_FLAG_DISPATCHABLE or FAF_SIMD_ABI_FLAG_ACTIVE;
    LExpectedAbiMajor := GetSimdAbiVersionMajor;
    LExpectedAbiMinor := GetSimdAbiVersionMinor;
    GetSimdAbiSignature(LExpectedSigHi, LExpectedSigLo);

    for LIndex := 0 to FIterations - 1 do
    begin
      LApi := GetSimdPublicApi;
      if LApi = nil then
      begin
        FErrorMsg := Format('public api table is nil at iter %d', [LIndex]);
        Exit;
      end;
      if LApi^.StructSize <> SizeOf(TNextPasSimdPublicApi) then
      begin
        FErrorMsg := Format('public api StructSize torn at iter %d: expected=%d got=%d',
          [LIndex, SizeOf(TNextPasSimdPublicApi), LApi^.StructSize]);
        Exit;
      end;
      if LApi^.AbiVersionMajor <> LExpectedAbiMajor then
      begin
        FErrorMsg := Format('public api AbiVersionMajor torn at iter %d: expected=%d got=%d',
          [LIndex, LExpectedAbiMajor, LApi^.AbiVersionMajor]);
        Exit;
      end;
      if LApi^.AbiVersionMinor <> LExpectedAbiMinor then
      begin
        FErrorMsg := Format('public api AbiVersionMinor torn at iter %d: expected=%d got=%d',
          [LIndex, LExpectedAbiMinor, LApi^.AbiVersionMinor]);
        Exit;
      end;
      if (LApi^.AbiSignatureHi <> LExpectedSigHi) or (LApi^.AbiSignatureLo <> LExpectedSigLo) then
      begin
        FErrorMsg := Format('public api signature torn at iter %d', [LIndex]);
        Exit;
      end;
      if LApi^.ActiveBackendId > UInt32(Ord(High(TSimdBackend))) then
      begin
        FErrorMsg := Format('public api ActiveBackendId out of range at iter %d: %d',
          [LIndex, LApi^.ActiveBackendId]);
        Exit;
      end;
      if (LApi^.ActiveFlags and LExpectedFlags) <> LExpectedFlags then
      begin
        FErrorMsg := Format('public api ActiveFlags missing registered/dispatchable/active bits at iter %d: %d',
          [LIndex, LApi^.ActiveFlags]);
        Exit;
      end;
      if (not Assigned(LApi^.MemEqual)) or
         (not Assigned(LApi^.MemFindByte)) or
         (not Assigned(LApi^.MemCopy)) or
         (not Assigned(LApi^.MinMaxBytes)) then
      begin
        FErrorMsg := Format('public api shim pointer torn at iter %d', [LIndex]);
        Exit;
      end;
      if not LApi^.MemEqual(@LBufA[0], @LBufB[0], SizeUInt(Length(LBufA))) then
      begin
        FErrorMsg := Format('public api MemEqual parity mismatch at iter %d', [LIndex]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'public api reader exception: ' + E.Message;
  end;
end;

constructor TBackendRegisterToggleWorker.Create(aIterations: Integer; aBackend: TSimdBackend;
  const aTableEnabled, aTableDisabled: TSimdDispatchTable);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FBackend := aBackend;
  FTableEnabled := aTableEnabled;
  FTableDisabled := aTableDisabled;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TBackendRegisterToggleWorker.Execute;
var
  LIndex: Integer;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 1) = 0 then
        RegisterBackend(FBackend, FTableEnabled)
      else
        RegisterBackend(FBackend, FTableDisabled);
      if (LIndex and 7) = 0 then
        ThreadSwitch;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'register toggle worker exception: ' + E.Message;
  end;
end;

constructor TPublicAbiPodInfoReadWorker.Create(aIterations: Integer; aBackend: TSimdBackend;
  aExpectedCapsA, aExpectedCapsB: UInt64;
  aExpectedFlagsA, aExpectedFlagsB: TNextPasSimdAbiFlags);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FBackend := aBackend;
  FExpectedCapsA := aExpectedCapsA;
  FExpectedCapsB := aExpectedCapsB;
  FExpectedFlagsA := aExpectedFlagsA;
  FExpectedFlagsB := aExpectedFlagsB;
  FSuccess := False;
  FErrorMsg := '';
end;

constructor TPublicAbiBackendTextReadWorker.Create(aIterations: Integer; aBackend: TSimdBackend;
  const aExpectedNameA, aExpectedNameB, aExpectedDescriptionA,
  aExpectedDescriptionB: AnsiString);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FBackend := aBackend;
  FExpectedNameA := aExpectedNameA;
  FExpectedNameB := aExpectedNameB;
  FExpectedDescriptionA := aExpectedDescriptionA;
  FExpectedDescriptionB := aExpectedDescriptionB;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TPublicAbiPodInfoReadWorker.Execute;
var
  LIndex: Integer;
  LInfo: TNextPasSimdBackendPodInfo;
  LMatchesA: Boolean;
  LMatchesB: Boolean;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;
      if not TryGetSimdBackendPodInfo(FBackend, LInfo) then
      begin
        FErrorMsg := Format('backend pod info query failed at iter %d', [LIndex]);
        Exit;
      end;
      if LInfo.StructSize <> SizeOf(TNextPasSimdBackendPodInfo) then
      begin
        FErrorMsg := Format('backend pod info StructSize torn at iter %d: expected=%d got=%d',
          [LIndex, SizeOf(TNextPasSimdBackendPodInfo), LInfo.StructSize]);
        Exit;
      end;
      if LInfo.BackendId <> UInt32(Ord(FBackend)) then
      begin
        FErrorMsg := Format('backend pod info BackendId torn at iter %d: expected=%d got=%d',
          [LIndex, Ord(FBackend), LInfo.BackendId]);
        Exit;
      end;

      LMatchesA := (LInfo.CapabilityBits = FExpectedCapsA) and
        (LInfo.Flags = FExpectedFlagsA);
      LMatchesB := (LInfo.CapabilityBits = FExpectedCapsB) and
        (LInfo.Flags = FExpectedFlagsB);
      if (not LMatchesA) and (not LMatchesB) then
      begin
        FErrorMsg := Format(
          'backend pod info mixed snapshot at iter %d: caps=%d flags=%d expectedA=(%d,%d) expectedB=(%d,%d)',
          [LIndex, LInfo.CapabilityBits, LInfo.Flags, FExpectedCapsA, FExpectedFlagsA,
           FExpectedCapsB, FExpectedFlagsB]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'backend pod info reader exception: ' + E.Message;
  end;
end;

procedure TPublicAbiBackendTextReadWorker.Execute;
var
  LIndex: Integer;
  LNamePtr: PAnsiChar;
  LDescriptionPtr: PAnsiChar;
  LNameText: AnsiString;
  LDescriptionText: AnsiString;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      LNamePtr := GetSimdBackendNamePtr(FBackend);
      if Pointer(LNamePtr) = nil then
      begin
        FErrorMsg := Format('backend text getter returned nil name pointer at iter %d', [LIndex]);
        Exit;
      end;

      if (LIndex and 1) = 0 then
        ThreadSwitch;

      LNameText := AnsiString(StrPas(LNamePtr));
      if (LNameText <> FExpectedNameA) and (LNameText <> FExpectedNameB) then
      begin
        FErrorMsg := Format(
          'backend text getter mixed name snapshot at iter %d: got=%s expectedA=%s expectedB=%s',
          [LIndex, string(LNameText), string(FExpectedNameA), string(FExpectedNameB)]);
        Exit;
      end;

      LDescriptionPtr := GetSimdBackendDescriptionPtr(FBackend);
      if Pointer(LDescriptionPtr) = nil then
      begin
        FErrorMsg := Format('backend text getter returned nil description pointer at iter %d', [LIndex]);
        Exit;
      end;

      if (LIndex and 1) = 0 then
        ThreadSwitch;

      LDescriptionText := AnsiString(StrPas(LDescriptionPtr));
      if (LDescriptionText <> FExpectedDescriptionA) and
         (LDescriptionText <> FExpectedDescriptionB) then
      begin
        FErrorMsg := Format(
          'backend text getter mixed description snapshot at iter %d: got=%s expectedA=%s expectedB=%s',
          [LIndex, string(LDescriptionText), string(FExpectedDescriptionA),
           string(FExpectedDescriptionB)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'backend text reader exception: ' + E.Message;
  end;
end;

constructor TCurrentBackendInfoReadWorker.Create(aIterations: Integer;
  const aExpectedInfoA, aExpectedInfoB: TSimdBackendInfo);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FExpectedInfoA := aExpectedInfoA;
  FExpectedInfoB := aExpectedInfoB;
  FSuccess := False;
  FErrorMsg := '';
end;

constructor TCurrentBackendReadWorker.Create(aIterations: Integer;
  aExpectedBackendA, aExpectedBackendB: TSimdBackend);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FExpectedBackendA := aExpectedBackendA;
  FExpectedBackendB := aExpectedBackendB;
  FSuccess := False;
  FErrorMsg := '';
end;

constructor TCurrentRuntimeSnapshotReadWorker.Create(aIterations: Integer;
  const aExpectedSnapshotA, aExpectedSnapshotB: TSimdRuntimeSnapshot);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FExpectedSnapshotA := aExpectedSnapshotA;
  FExpectedSnapshotB := aExpectedSnapshotB;
  FSuccess := False;
  FErrorMsg := '';
end;

constructor TBackendOpsReadWorker.Create(aIterations: Integer; aBackend: TSimdBackend;
  const aExpectedTableA, aExpectedTableB: TSimdDispatchTable);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FBackend := aBackend;
  FExpectedTableA := aExpectedTableA;
  FExpectedTableB := aExpectedTableB;
  FSuccess := False;
  FErrorMsg := '';
end;

constructor TCurrentBackendPodInfoReadWorker.Create(aIterations: Integer; aBackend: TSimdBackend;
  aExpectedCapsEnabled, aExpectedCapsDisabled: UInt64;
  aExpectedFlagsEnabledActive, aExpectedFlagsEnabledInactive,
  aExpectedFlagsDisabledInactive: TNextPasSimdAbiFlags);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FBackend := aBackend;
  FExpectedCapsEnabled := aExpectedCapsEnabled;
  FExpectedCapsDisabled := aExpectedCapsDisabled;
  FExpectedFlagsEnabledActive := aExpectedFlagsEnabledActive;
  FExpectedFlagsEnabledInactive := aExpectedFlagsEnabledInactive;
  FExpectedFlagsDisabledInactive := aExpectedFlagsDisabledInactive;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TCurrentBackendReadWorker.Execute;
var
  LIndex: Integer;
  LBackend: TSimdBackend;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      LBackend := GetCurrentBackend;
      if (LBackend <> FExpectedBackendA) and
         (LBackend <> FExpectedBackendB) then
      begin
        FErrorMsg := Format(
          'current backend mixed snapshot at iter %d: got=%s expectedA=%s expectedB=%s',
          [LIndex, ConcurrentBackendName(LBackend),
           ConcurrentBackendName(FExpectedBackendA),
           ConcurrentBackendName(FExpectedBackendB)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'current backend reader exception: ' + E.Message;
  end;
end;

procedure TCurrentBackendInfoReadWorker.Execute;
var
  LIndex: Integer;
  LInfo: TSimdBackendInfo;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      LInfo := GetCurrentBackendInfo;
      if (not BackendInfoMatchesLocal(LInfo, FExpectedInfoA)) and
         (not BackendInfoMatchesLocal(LInfo, FExpectedInfoB)) then
      begin
        FErrorMsg := Format('current backend info mixed snapshot at iter %d: got=(%s) expectedA=(%s) expectedB=(%s)',
          [LIndex, DescribeBackendInfoLocal(LInfo),
           DescribeBackendInfoLocal(FExpectedInfoA),
           DescribeBackendInfoLocal(FExpectedInfoB)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'current backend info reader exception: ' + E.Message;
  end;
end;

procedure TCurrentRuntimeSnapshotReadWorker.Execute;
var
  LIndex: Integer;
  LSnapshot: TSimdRuntimeSnapshot;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      LSnapshot := nextpas.core.simd.GetCurrentRuntimeSnapshot;
      if (not RuntimeSnapshotMatchesLocal(LSnapshot, FExpectedSnapshotA)) and
         (not RuntimeSnapshotMatchesLocal(LSnapshot, FExpectedSnapshotB)) then
      begin
        FErrorMsg := Format(
          'runtime snapshot mixed snapshot at iter %d: got=(%s) expectedA=(%s) expectedB=(%s)',
          [LIndex,
           DescribeRuntimeSnapshotLocal(LSnapshot),
           DescribeRuntimeSnapshotLocal(FExpectedSnapshotA),
           DescribeRuntimeSnapshotLocal(FExpectedSnapshotB)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'runtime snapshot reader exception: ' + E.Message;
  end;
end;

procedure TBackendOpsReadWorker.Execute;
var
  LIndex: Integer;
  LObservedTable: TSimdDispatchTable;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      BackendOpsToDispatchTable(GetBackendOps(FBackend), LObservedTable);
      if (not DispatchTableRepresentativeSliceMatchesLocal(LObservedTable, FExpectedTableA)) and
         (not DispatchTableRepresentativeSliceMatchesLocal(LObservedTable, FExpectedTableB)) then
      begin
        FErrorMsg := Format(
          'backend ops mixed snapshot at iter %d: info=(%s) add=[A:%s B:%s] mul=[A:%s B:%s] addi=[A:%s B:%s] select=[A:%s B:%s]',
          [LIndex,
           DescribeBackendInfoLocal(LObservedTable.BackendInfo),
           BoolToStr(Pointer(LObservedTable.AddF32x4) = Pointer(FExpectedTableA.AddF32x4), True),
           BoolToStr(Pointer(LObservedTable.AddF32x4) = Pointer(FExpectedTableB.AddF32x4), True),
           BoolToStr(Pointer(LObservedTable.MulF32x4) = Pointer(FExpectedTableA.MulF32x4), True),
           BoolToStr(Pointer(LObservedTable.MulF32x4) = Pointer(FExpectedTableB.MulF32x4), True),
           BoolToStr(Pointer(LObservedTable.AddI32x4) = Pointer(FExpectedTableA.AddI32x4), True),
           BoolToStr(Pointer(LObservedTable.AddI32x4) = Pointer(FExpectedTableB.AddI32x4), True),
           BoolToStr(Pointer(LObservedTable.SelectF32x4) = Pointer(FExpectedTableA.SelectF32x4), True),
           BoolToStr(Pointer(LObservedTable.SelectF32x4) = Pointer(FExpectedTableB.SelectF32x4), True)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'backend ops reader exception: ' + E.Message;
  end;
end;

procedure TCurrentBackendPodInfoReadWorker.Execute;
var
  LIndex: Integer;
  LInfo: TNextPasSimdBackendPodInfo;
  LMatchesEnabledActive: Boolean;
  LMatchesEnabledInactive: Boolean;
  LMatchesDisabledInactive: Boolean;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      if not TryGetSimdBackendPodInfo(FBackend, LInfo) then
      begin
        FErrorMsg := Format('current backend pod info query failed at iter %d', [LIndex]);
        Exit;
      end;
      if LInfo.StructSize <> SizeOf(TNextPasSimdBackendPodInfo) then
      begin
        FErrorMsg := Format('current backend pod info StructSize torn at iter %d: expected=%d got=%d',
          [LIndex, SizeOf(TNextPasSimdBackendPodInfo), LInfo.StructSize]);
        Exit;
      end;
      if LInfo.BackendId <> UInt32(Ord(FBackend)) then
      begin
        FErrorMsg := Format('current backend pod info BackendId torn at iter %d: expected=%d got=%d',
          [LIndex, Ord(FBackend), LInfo.BackendId]);
        Exit;
      end;

      LMatchesEnabledActive := (LInfo.CapabilityBits = FExpectedCapsEnabled) and
        (LInfo.Flags = FExpectedFlagsEnabledActive);
      LMatchesEnabledInactive := (LInfo.CapabilityBits = FExpectedCapsEnabled) and
        (LInfo.Flags = FExpectedFlagsEnabledInactive);
      LMatchesDisabledInactive := (LInfo.CapabilityBits = FExpectedCapsDisabled) and
        (LInfo.Flags = FExpectedFlagsDisabledInactive);
      if (not LMatchesEnabledActive) and
         (not LMatchesEnabledInactive) and
         (not LMatchesDisabledInactive) then
      begin
        FErrorMsg := Format(
          'current backend pod info mixed snapshot at iter %d: caps=%d flags=%d expected={enabled-active=(%d,%d) | enabled-inactive=(%d,%d) | disabled-inactive=(%d,%d)}',
          [LIndex, LInfo.CapabilityBits, LInfo.Flags,
           FExpectedCapsEnabled, FExpectedFlagsEnabledActive,
           FExpectedCapsEnabled, FExpectedFlagsEnabledInactive,
           FExpectedCapsDisabled, FExpectedFlagsDisabledInactive]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'current backend pod info reader exception: ' + E.Message;
  end;
end;

constructor TDispatchableHelpersReadWorker.Create(aIterations: Integer;
  const aExpectedListEnabled, aExpectedListDisabled: TSimdBackendArray;
  aExpectedBestEnabled, aExpectedBestDisabled: TSimdBackend);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FExpectedListEnabled := Copy(aExpectedListEnabled);
  FExpectedListDisabled := Copy(aExpectedListDisabled);
  FExpectedBestEnabled := aExpectedBestEnabled;
  FExpectedBestDisabled := aExpectedBestDisabled;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TDispatchableHelpersReadWorker.Execute;
var
  LIndex: Integer;
  LDispatchableView: TSimdBackendArray;
  LAvailableView: TSimdBackendArray;
  LBestBackend: TSimdBackend;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      LDispatchableView := nextpas.core.simd.GetDispatchableBackendList;
      LAvailableView := nextpas.core.simd.GetAvailableBackendList;
      LBestBackend := nextpas.core.simd.GetBestDispatchableBackend;

      if (not SameBackendArrayLocal(LDispatchableView, FExpectedListEnabled)) and
         (not SameBackendArrayLocal(LDispatchableView, FExpectedListDisabled)) then
      begin
        FErrorMsg := Format(
          'dispatchable helper mixed snapshot at iter %d: got=%s expectedEnabled=%s expectedDisabled=%s',
          [LIndex, DescribeBackendArrayLocal(LDispatchableView),
           DescribeBackendArrayLocal(FExpectedListEnabled),
           DescribeBackendArrayLocal(FExpectedListDisabled)]);
        Exit;
      end;

      if (not SameBackendArrayLocal(LAvailableView, FExpectedListEnabled)) and
         (not SameBackendArrayLocal(LAvailableView, FExpectedListDisabled)) then
      begin
        FErrorMsg := Format(
          'available helper mixed snapshot at iter %d: got=%s expectedEnabled=%s expectedDisabled=%s',
          [LIndex, DescribeBackendArrayLocal(LAvailableView),
           DescribeBackendArrayLocal(FExpectedListEnabled),
           DescribeBackendArrayLocal(FExpectedListDisabled)]);
        Exit;
      end;

      if (LBestBackend <> FExpectedBestEnabled) and (LBestBackend <> FExpectedBestDisabled) then
      begin
        FErrorMsg := Format(
          'best dispatchable backend mixed snapshot at iter %d: got=%d expectedEnabled=%d expectedDisabled=%d',
          [LIndex, Ord(LBestBackend), Ord(FExpectedBestEnabled), Ord(FExpectedBestDisabled)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'dispatchable helper reader exception: ' + E.Message;
  end;
end;

constructor TPublicApiActiveMetadataReadWorker.Create(aIterations: Integer;
  aExpectedBackendA, aExpectedBackendB: TSimdBackend;
  aExpectedFlagsA, aExpectedFlagsB: TNextPasSimdAbiFlags);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FExpectedBackendA := aExpectedBackendA;
  FExpectedBackendB := aExpectedBackendB;
  FExpectedFlagsA := aExpectedFlagsA;
  FExpectedFlagsB := aExpectedFlagsB;
  FSuccess := False;
  FErrorMsg := '';
end;

constructor TBackendFirstRegisterSequenceWorker.Create(const aBackends: TSimdBackendArray;
  const aTables: TSimdDispatchTableArray);
var
  LIndex: Integer;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  SetLength(FBackends, Length(aBackends));
  for LIndex := 0 to High(aBackends) do
    FBackends[LIndex] := aBackends[LIndex];
  SetLength(FTables, Length(aTables));
  for LIndex := 0 to High(aTables) do
    FTables[LIndex] := aTables[LIndex];
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TBackendFirstRegisterSequenceWorker.Execute;
var
  LIndex: Integer;
begin
  try
    for LIndex := 0 to High(FBackends) do
    begin
      RegisterBackend(FBackends[LIndex], FTables[LIndex]);
      ThreadSwitch;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'first-register sequence worker exception: ' + E.Message;
  end;
end;

constructor TRegisteredBackendListReadWorker.Create(aIterations: Integer;
  const aExpectedStates: TSimdBackendArrayStates);
var
  LIndex: Integer;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  SetLength(FExpectedStates, Length(aExpectedStates));
  for LIndex := 0 to High(aExpectedStates) do
    FExpectedStates[LIndex] := Copy(aExpectedStates[LIndex]);
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TRegisteredBackendListReadWorker.Execute;
var
  LIndex: Integer;
  LStateIndex: Integer;
  LRegistered: TSimdBackendArray;
  LMatchesState: Boolean;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      LRegistered := nextpas.core.simd.GetRegisteredBackendList;
      LMatchesState := False;
      for LStateIndex := 0 to High(FExpectedStates) do
        if SameBackendArrayLocal(LRegistered, FExpectedStates[LStateIndex]) then
        begin
          LMatchesState := True;
          Break;
        end;

      if not LMatchesState then
      begin
        FErrorMsg := Format(
          'registered backend list mixed snapshot at iter %d: got=%s expectedStates=%s',
          [LIndex, DescribeBackendArrayLocal(LRegistered),
           DescribeBackendArrayStatesLocal(FExpectedStates)]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'registered backend list reader exception: ' + E.Message;
  end;
end;

procedure TPublicApiActiveMetadataReadWorker.Execute;
var
  LIndex: Integer;
  LApi: PNextPasSimdPublicApi;
  LMatchesA: Boolean;
  LMatchesB: Boolean;
  LBufA: array[0..31] of Byte;
  LBufB: array[0..31] of Byte;
begin
  try
    FillChar(LBufA, SizeOf(LBufA), $3C);
    FillChar(LBufB, SizeOf(LBufB), $3C);

    for LIndex := 0 to FIterations - 1 do
    begin
      if (LIndex and 3) = 0 then
        ThreadSwitch;

      LApi := GetSimdPublicApi;
      if LApi = nil then
      begin
        FErrorMsg := Format('public api table is nil at iter %d', [LIndex]);
        Exit;
      end;
      if LApi^.StructSize <> SizeOf(TNextPasSimdPublicApi) then
      begin
        FErrorMsg := Format('public api StructSize torn at iter %d: expected=%d got=%d',
          [LIndex, SizeOf(TNextPasSimdPublicApi), LApi^.StructSize]);
        Exit;
      end;

      LMatchesA := (LApi^.ActiveBackendId = UInt32(Ord(FExpectedBackendA))) and
        (LApi^.ActiveFlags = FExpectedFlagsA);
      LMatchesB := (LApi^.ActiveBackendId = UInt32(Ord(FExpectedBackendB))) and
        (LApi^.ActiveFlags = FExpectedFlagsB);
      if (not LMatchesA) and (not LMatchesB) then
      begin
        FErrorMsg := Format(
          'public api active metadata mixed snapshot at iter %d: id=%d flags=%d expectedA=(%d,%d) expectedB=(%d,%d)',
          [LIndex, LApi^.ActiveBackendId, LApi^.ActiveFlags,
           Ord(FExpectedBackendA), FExpectedFlagsA, Ord(FExpectedBackendB), FExpectedFlagsB]);
        Exit;
      end;

      if (not Assigned(LApi^.MemEqual)) or
         (not LApi^.MemEqual(@LBufA[0], @LBufB[0], SizeUInt(Length(LBufA)))) then
      begin
        FErrorMsg := Format('public api active metadata MemEqual parity mismatch at iter %d', [LIndex]);
        Exit;
      end;
    end;

    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'public api active metadata reader exception: ' + E.Message;
  end;
end;

// === TDispatchMixedControlWorker ===

constructor TDispatchMixedControlWorker.Create(AIterations, AWorkerPhase: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := AIterations;
  FWorkerPhase := AWorkerPhase;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TDispatchMixedControlWorker.Execute;
var
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;
  LA, LB, LC, LProbe: TVecF32x4;
  LValue: Single;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      case ((LIndex + FWorkerPhase) mod 5) of
        0:
          SetVectorAsmEnabled(((LIndex + FWorkerPhase) and 1) = 0);
        1:
          SetActiveBackend(sbScalar);
        2:
          if IsBackendRegistered(sbSSE2) then
            SetActiveBackend(sbSSE2)
          else
            ResetToAutomaticBackend;
        3:
          if IsBackendRegistered(sbAVX2) then
            SetActiveBackend(sbAVX2)
          else
            ResetToAutomaticBackend;
      else
        ResetToAutomaticBackend;
      end;

      LDispatch := GetDispatchTable;
      if (LDispatch = nil) or (not Assigned(LDispatch^.AddF32x4)) then
      begin
        FErrorMsg := Format('mixed-control dispatch unavailable at iter %d', [LIndex]);
        Exit;
      end;
      if (not Assigned(LDispatch^.RoundF32x4)) or (not Assigned(LDispatch^.TruncF32x4)) then
      begin
        FErrorMsg := Format('mixed-control round/trunc unavailable at iter %d', [LIndex]);
        Exit;
      end;

      LA := MakeSplatF32x4(1.0);
      LB := MakeSplatF32x4(2.0);
      LC := LDispatch^.AddF32x4(LA, LB);
      LValue := VecF32x4Extract(LC, 0);
      if Abs(LValue - 3.0) > FLOAT_EPSILON then
      begin
        FErrorMsg := Format('mixed-control AddF32x4 mismatch at iter %d: %.6f', [LIndex, LValue]);
        Exit;
      end;

      LProbe := MakeSplatF32x4(-1.75);
      LC := LDispatch^.RoundF32x4(LProbe);
      LValue := VecF32x4Extract(LC, 0);
      if Abs(LValue - (-2.0)) > FLOAT_EPSILON then
      begin
        FErrorMsg := Format('mixed-control RoundF32x4 mismatch at iter %d: %.6f', [LIndex, LValue]);
        Exit;
      end;

      LC := LDispatch^.TruncF32x4(LProbe);
      LValue := VecF32x4Extract(LC, 0);
      if Abs(LValue - (-1.0)) > FLOAT_EPSILON then
      begin
        FErrorMsg := Format('mixed-control TruncF32x4 mismatch at iter %d: %.6f', [LIndex, LValue]);
        Exit;
      end;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'mixed-control worker exception: ' + E.Message;
  end;
end;

// === TLargeDataThread ===

constructor TLargeDataThread.Create(AWorkerIndex: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWorkerIndex := AWorkerIndex;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TLargeDataThread.Execute;
const
  DATA_SIZE = 10000;
var
  data: array of Single;
  i: Integer;
  a, b, c: TVecF32x4;
  sum: Single;
begin
  try
    data := nil;
    SetLength(data, DATA_SIZE);

    // 初始化数据
    for i := 0 to DATA_SIZE - 1 do
      data[i] := FWorkerIndex * 1000.0 + i;

    // 处理数据（每次 4 个元素）
    sum := 0;
    i := 0;
    while i + 3 < DATA_SIZE do
    begin
      a := VecF32x4Load(@data[i]);
      b := MakeSplatF32x4(2.0);
      c := VecF32x4Mul(a, b);
      sum := sum + VecF32x4ReduceAdd(c);
      Inc(i, 4);
    end;

    // 验证结果
    if IsNan(sum) or IsInfinite(sum) then
      FErrorMsg := Format('Thread %d: invalid sum', [FWorkerIndex])
    else
      FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := Format('Thread %d exception: %s', [FWorkerIndex, E.Message]);
  end;
end;

// === TTestCase_SimdConcurrent ===

procedure TTestCase_SimdConcurrent.Test_Concurrent_F32x4_Add;
var
  workers: array of TF32x4AddWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  // 创建并启动所有线程
  for i := 0 to High(workers) do
    workers[i] := TF32x4AddWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  // 等待所有线程完成
  for i := 0 to High(workers) do
    workers[i].WaitFor;

  // 检查结果
  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent F32x4 Add failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_F32x4_Mul;
var
  workers: array of TF32x4MulWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TF32x4MulWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent F32x4 Mul failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_F64x2_Operations;
var
  workers: array of TF64x2OpsWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TF64x2OpsWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent F64x2 Operations failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_Compound_Operations;
var
  workers: array of TCompoundOpsWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TCompoundOpsWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent Compound Operations failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_Dispatch_Access;
var
  workers: array of TDispatchAccessWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TDispatchAccessWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent Dispatch Access failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_Backend_Query;
var
  threads: array of TBackendQueryThread;
  i: Integer;
  expectedBackend: TSimdBackend;
  allSuccess: Boolean;
begin
  // 获取预期后端
  expectedBackend := GetActiveBackend;

  threads := nil;
  SetLength(threads, DEFAULT_THREAD_COUNT);

  // 创建线程
  for i := 0 to High(threads) do
    threads[i] := TBackendQueryThread.Create(i);

  // 启动所有线程
  for i := 0 to High(threads) do
    threads[i].Start;

  // 等待完成
  for i := 0 to High(threads) do
    threads[i].WaitFor;

  // 验证所有结果一致
  allSuccess := True;
  for i := 0 to High(threads) do
  begin
    if not threads[i].Success then
      allSuccess := False
    else if threads[i].Result <> expectedBackend then
      allSuccess := False;
    threads[i].Free;
  end;

  AssertTrue('Concurrent backend query failed', allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_VectorAsmToggle_DispatchRead;
const
  TOGGLE_ITERATIONS = 2000;
  READER_THREADS = 4;
  READER_ITERATIONS = 5000;
var
  LToggleWorker: TVectorAsmToggleWorker;
  LReaders: array of TVectorAsmReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LToggleWorker := TVectorAsmToggleWorker.Create(TOGGLE_ITERATIONS, LOldVectorAsm);
  LReaders := nil;
  SetLength(LReaders, READER_THREADS);

  for LIndex := 0 to High(LReaders) do
    LReaders[LIndex] := TVectorAsmReadWorker.Create(READER_ITERATIONS);

  try
    LToggleWorker.Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    LToggleWorker.WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := LToggleWorker.Success;
    LErrorMsgs := '';
    if not LToggleWorker.Success then
      LErrorMsgs := LErrorMsgs + LToggleWorker.ErrorMsg + '; ';

    for LIndex := 0 to High(LReaders) do
    begin
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;
    end;

    AssertTrue('Concurrent VectorAsm toggle/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
    LToggleWorker.Free;
  end;
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_VectorAsmToggle_MultiWriter_DispatchRead;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 2500;
  READER_THREADS = 4;
  READER_ITERATIONS = 5000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TVectorAsmReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  SetLength(LWriters, WRITER_THREADS);
  SetLength(LReaders, READER_THREADS);

  for LIndex := 0 to High(LWriters) do
    LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
  for LIndex := 0 to High(LReaders) do
    LReaders[LIndex] := TVectorAsmReadWorker.Create(READER_ITERATIONS);

  try
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;

    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent VectorAsm multi-writer/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_PublicApiToggle_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 4000;
  READER_THREADS = 6;
  READER_ITERATIONS = 30000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TPublicApiReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  SetLength(LWriters, WRITER_THREADS);
  SetLength(LReaders, READER_THREADS);

  for LIndex := 0 to High(LWriters) do
    LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
  for LIndex := 0 to High(LReaders) do
    LReaders[LIndex] := TPublicApiReadWorker.Create(READER_ITERATIONS);

  try
    GetSimdPublicApi;
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;

    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent public API toggle/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentPublicAbi.Test_Concurrent_PublicAbiPodInfo_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 600;
  READER_THREADS = 6;
  READER_ITERATIONS = 12000;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TPublicAbiPodInfoReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LDisabledTable: TSimdDispatchTable;
  LSupportedOnCPU: Boolean;
  LExpectedCapsEnabled: UInt64;
  LExpectedCapsDisabled: UInt64;
  LExpectedFlagsEnabled: TNextPasSimdAbiFlags;
  LExpectedFlagsDisabled: TNextPasSimdAbiFlags;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LOriginalTable := Default(TSimdDispatchTable);
  LDisabledTable := Default(TSimdDispatchTable);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;

    if not TryFindInactiveSupportedBackendForPodInfoMutation(LBackend, LOriginalTable) then
      Exit;

    LDisabledTable := LOriginalTable;
    LDisabledTable.BackendInfo.Available := False;
    LDisabledTable.BackendInfo.Capabilities := [];

    LSupportedOnCPU := IsBackendAvailableOnCPU(LBackend);
    LExpectedCapsEnabled := CapabilitiesToAbiBitsLocal(LOriginalTable.BackendInfo.Capabilities);
    LExpectedCapsDisabled := CapabilitiesToAbiBitsLocal(LDisabledTable.BackendInfo.Capabilities);
    LExpectedFlagsEnabled := BuildExpectedAbiFlagsLocal(
      LBackend, LSupportedOnCPU, True, LSupportedOnCPU and LOriginalTable.BackendInfo.Available, False);
    LExpectedFlagsDisabled := BuildExpectedAbiFlagsLocal(
      LBackend, LSupportedOnCPU, True, False, False);

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TPublicAbiPodInfoReadWorker.Create(
        READER_ITERATIONS, LBackend, LExpectedCapsEnabled, LExpectedCapsDisabled,
        LExpectedFlagsEnabled, LExpectedFlagsDisabled);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent public ABI backend pod info/register read failed: ' + LErrorMsgs,
      LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_SimdConcurrentPublicAbi.Test_Concurrent_PublicAbiBackendText_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 800;
  READER_THREADS = 6;
  READER_ITERATIONS = 16000;
  NAME_LEN = 1024;
  DESCRIPTION_LEN = 2048;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TPublicAbiBackendTextReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LRestoreTable: TSimdDispatchTable;
  LTextTableA: TSimdDispatchTable;
  LTextTableB: TSimdDispatchTable;
  LNameA: AnsiString;
  LNameB: AnsiString;
  LDescriptionA: AnsiString;
  LDescriptionB: AnsiString;

  function BuildFixedLengthText(const aPrefix: AnsiString; const aFill: Char;
    const aTargetLen: Integer): AnsiString;
  var
    LFillLen: Integer;
  begin
    Result := aPrefix;
    if Length(Result) < aTargetLen then
    begin
      LFillLen := aTargetLen - Length(Result);
      Result := Result + AnsiString(StringOfChar(aFill, LFillLen));
    end
    else
      SetLength(Result, aTargetLen);
  end;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LRestoreTable := Default(TSimdDispatchTable);
  LTextTableA := Default(TSimdDispatchTable);
  LTextTableB := Default(TSimdDispatchTable);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;

    if not TryFindInactiveSupportedBackendForPodInfoMutation(LBackend, LRestoreTable) then
      Exit;

    LNameA := BuildFixedLengthText('ConcurrentPublicAbiName_A_', 'A', NAME_LEN);
    LNameB := BuildFixedLengthText('ConcurrentPublicAbiName_B_', 'B', NAME_LEN);
    LDescriptionA := BuildFixedLengthText('ConcurrentPublicAbiDescription_A_', 'a', DESCRIPTION_LEN);
    LDescriptionB := BuildFixedLengthText('ConcurrentPublicAbiDescription_B_', 'b', DESCRIPTION_LEN);

    LTextTableA := LRestoreTable;
    LTextTableA.BackendInfo.Name := string(LNameA);
    LTextTableA.BackendInfo.Description := string(LDescriptionA);

    LTextTableB := LRestoreTable;
    LTextTableB.BackendInfo.Name := string(LNameB);
    LTextTableB.BackendInfo.Description := string(LDescriptionB);

    RegisterBackend(LBackend, LTextTableA);

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LTextTableA, LTextTableB);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TPublicAbiBackendTextReadWorker.Create(
        READER_ITERATIONS, LBackend, LNameA, LNameB, LDescriptionA, LDescriptionB);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent public ABI backend text/register read failed: ' + LErrorMsgs,
      LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LRestoreTable);
  end;
end;

procedure TTestCase_SimdConcurrentPublicAbi.Test_Concurrent_PublicApiActiveMetadata_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 2;
  WRITER_ITERATIONS = 160;
  READER_THREADS = 3;
  READER_ITERATIONS = 4000;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TPublicApiActiveMetadataReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LFallbackBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LDisabledTable: TSimdDispatchTable;
  LFallbackInfo: TSimdBackendInfo;
  LExpectedFlagsEnabled: TNextPasSimdAbiFlags;
  LExpectedFlagsDisabled: TNextPasSimdAbiFlags;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LFallbackBackend := sbScalar;
  LOriginalTable := Default(TSimdDispatchTable);
  LDisabledTable := Default(TSimdDispatchTable);
  LFallbackInfo := Default(TSimdBackendInfo);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LBackend := GetCurrentBackend;
    if LBackend = sbScalar then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable) then
      Exit;
    if (not LOriginalTable.BackendInfo.Available) or
       (LOriginalTable.BackendInfo.Capabilities = []) then
      Exit;

    LDisabledTable := LOriginalTable;
    LDisabledTable.BackendInfo.Available := False;
    LDisabledTable.BackendInfo.Capabilities := [];

    LExpectedFlagsEnabled := BuildExpectedAbiFlagsLocal(
      LBackend, IsBackendAvailableOnCPU(LBackend), True, True, True);

    RegisterBackend(LBackend, LDisabledTable);
    LFallbackBackend := GetCurrentBackend;
    LFallbackInfo := GetCurrentBackendInfo;
    AssertTrue('Disabled current backend should reselect away from the mutated backend',
      LFallbackBackend <> LBackend);
    LExpectedFlagsDisabled := BuildExpectedAbiFlagsLocal(
      LFallbackBackend, IsBackendAvailableOnCPU(LFallbackBackend), True,
      LFallbackInfo.Available and IsBackendAvailableOnCPU(LFallbackBackend), True);

    RegisterBackend(LBackend, LOriginalTable);
    AssertEquals('Restored backend should become current again',
      Ord(LBackend), Ord(GetCurrentBackend));

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TPublicApiActiveMetadataReadWorker.Create(
        READER_ITERATIONS, LBackend, LFallbackBackend,
        LExpectedFlagsEnabled, LExpectedFlagsDisabled);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent public-api-active-metadata register/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LOriginalTable);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentPublicAbi.Test_Concurrent_PublicApiActiveMetadata_VectorAsmToggle_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 4000;
  READER_THREADS = 6;
  READER_ITERATIONS = 30000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TPublicApiActiveMetadataReadWorker;
  LExpectedEnabledBackend: TSimdBackend;
  LExpectedDisabledBackend: TSimdBackend;
  LExpectedEnabledFlags: TNextPasSimdAbiFlags;
  LExpectedDisabledFlags: TNextPasSimdAbiFlags;
  LCurrentInfo: TSimdBackendInfo;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LExpectedEnabledBackend := sbScalar;
  LExpectedDisabledBackend := sbScalar;
  LExpectedEnabledFlags := 0;
  LExpectedDisabledFlags := 0;
  LCurrentInfo := Default(TSimdBackendInfo);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LExpectedEnabledBackend := GetCurrentBackend;
    LCurrentInfo := GetCurrentBackendInfo;
    LExpectedEnabledFlags := BuildExpectedAbiFlagsLocal(
      LExpectedEnabledBackend, IsBackendAvailableOnCPU(LExpectedEnabledBackend), True,
      LCurrentInfo.Available and IsBackendAvailableOnCPU(LExpectedEnabledBackend), True);

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LExpectedDisabledBackend := GetCurrentBackend;
    LCurrentInfo := GetCurrentBackendInfo;
    LExpectedDisabledFlags := BuildExpectedAbiFlagsLocal(
      LExpectedDisabledBackend, IsBackendAvailableOnCPU(LExpectedDisabledBackend), True,
      LCurrentInfo.Available and IsBackendAvailableOnCPU(LExpectedDisabledBackend), True);

    if (LExpectedEnabledBackend = LExpectedDisabledBackend) and
       (LExpectedEnabledFlags = LExpectedDisabledFlags) then
      Exit;

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TPublicApiActiveMetadataReadWorker.Create(
        READER_ITERATIONS, LExpectedEnabledBackend, LExpectedDisabledBackend,
        LExpectedEnabledFlags, LExpectedDisabledFlags);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent public-api-active-metadata toggle/read failed: ' + LErrorMsgs,
      LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentPublicAbi.Test_Concurrent_PublicAbiPodInfo_CurrentBackend_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 2;
  WRITER_ITERATIONS = 160;
  READER_THREADS = 3;
  READER_ITERATIONS = 4000;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TCurrentBackendPodInfoReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LDisabledTable: TSimdDispatchTable;
  LExpectedCapsEnabled: UInt64;
  LExpectedCapsDisabled: UInt64;
  LExpectedFlagsEnabledActive: TNextPasSimdAbiFlags;
  LExpectedFlagsEnabledInactive: TNextPasSimdAbiFlags;
  LExpectedFlagsDisabledInactive: TNextPasSimdAbiFlags;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LOriginalTable := Default(TSimdDispatchTable);
  LDisabledTable := Default(TSimdDispatchTable);
  LExpectedCapsEnabled := 0;
  LExpectedCapsDisabled := 0;
  LExpectedFlagsEnabledActive := 0;
  LExpectedFlagsEnabledInactive := 0;
  LExpectedFlagsDisabledInactive := 0;

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LBackend := GetCurrentBackend;
    if LBackend = sbScalar then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable) then
      Exit;
    if (not LOriginalTable.BackendInfo.Available) or
       (LOriginalTable.BackendInfo.Capabilities = []) then
      Exit;

    LDisabledTable := LOriginalTable;
    LDisabledTable.BackendInfo.Available := False;
    LDisabledTable.BackendInfo.Capabilities := [];

    LExpectedCapsEnabled := CapabilitiesToAbiBitsLocal(LOriginalTable.BackendInfo.Capabilities);
    LExpectedCapsDisabled := CapabilitiesToAbiBitsLocal(LDisabledTable.BackendInfo.Capabilities);
    LExpectedFlagsEnabledActive := BuildExpectedAbiFlagsLocal(
      LBackend, IsBackendAvailableOnCPU(LBackend), True, True, True);
    LExpectedFlagsEnabledInactive := BuildExpectedAbiFlagsLocal(
      LBackend, IsBackendAvailableOnCPU(LBackend), True, True, False);
    LExpectedFlagsDisabledInactive := BuildExpectedAbiFlagsLocal(
      LBackend, IsBackendAvailableOnCPU(LBackend), True, False, False);

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TCurrentBackendPodInfoReadWorker.Create(
        READER_ITERATIONS, LBackend, LExpectedCapsEnabled, LExpectedCapsDisabled,
        LExpectedFlagsEnabledActive, LExpectedFlagsEnabledInactive,
        LExpectedFlagsDisabledInactive);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent current-backend public ABI pod info/register read failed: ' + LErrorMsgs,
      LAllSuccess);
  finally
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LOriginalTable);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_CurrentBackend_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 2;
  WRITER_ITERATIONS = 160;
  READER_THREADS = 3;
  READER_ITERATIONS = 4000;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TCurrentBackendReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LExpectedDisabledBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LDisabledTable: TSimdDispatchTable;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LExpectedDisabledBackend := sbScalar;
  LOriginalTable := Default(TSimdDispatchTable);
  LDisabledTable := Default(TSimdDispatchTable);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LBackend := GetCurrentBackend;
    if LBackend = sbScalar then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable) then
      Exit;
    if (not LOriginalTable.BackendInfo.Available) or
       (LOriginalTable.BackendInfo.Capabilities = []) then
      Exit;

    LDisabledTable := LOriginalTable;
    LDisabledTable.BackendInfo.Available := False;
    LDisabledTable.BackendInfo.Capabilities := [];

    RegisterBackend(LBackend, LDisabledTable);
    LExpectedDisabledBackend := GetCurrentBackend;
    AssertTrue('Disabled current backend should reselect away from the mutated backend',
      LExpectedDisabledBackend <> LBackend);

    RegisterBackend(LBackend, LOriginalTable);
    AssertEquals('Restored backend should become current again',
      Ord(LBackend), Ord(GetCurrentBackend));

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TCurrentBackendReadWorker.Create(
        READER_ITERATIONS, LBackend, LExpectedDisabledBackend);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent current-backend register/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LOriginalTable);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_CurrentBackendInfo_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 2;
  WRITER_ITERATIONS = 160;
  READER_THREADS = 3;
  READER_ITERATIONS = 4000;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TCurrentBackendInfoReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LDisabledTable: TSimdDispatchTable;
  LExpectedEnabledInfo: TSimdBackendInfo;
  LExpectedDisabledInfo: TSimdBackendInfo;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LOriginalTable := Default(TSimdDispatchTable);
  LDisabledTable := Default(TSimdDispatchTable);
  LExpectedEnabledInfo := Default(TSimdBackendInfo);
  LExpectedDisabledInfo := Default(TSimdBackendInfo);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LBackend := GetCurrentBackend;
    if LBackend = sbScalar then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable) then
      Exit;
    if (not LOriginalTable.BackendInfo.Available) or
       (LOriginalTable.BackendInfo.Capabilities = []) then
      Exit;

    LExpectedEnabledInfo := LOriginalTable.BackendInfo;
    LDisabledTable := LOriginalTable;
    LDisabledTable.BackendInfo.Available := False;
    LDisabledTable.BackendInfo.Capabilities := [];

    RegisterBackend(LBackend, LDisabledTable);
    LExpectedDisabledInfo := GetCurrentBackendInfo;
    AssertTrue('Disabled current backend should reselect away from the mutated backend',
      LExpectedDisabledInfo.Backend <> LBackend);

    RegisterBackend(LBackend, LOriginalTable);
    AssertEquals('Restored backend should become current again',
      Ord(LBackend), Ord(GetCurrentBackend));

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TCurrentBackendInfoReadWorker.Create(
        READER_ITERATIONS, LExpectedEnabledInfo, LExpectedDisabledInfo);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent current-backend-info register/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LOriginalTable);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_BackendOps_RegisterBackend_ReadConsistency;
const
  WRITER_THREADS = 2;
  WRITER_ITERATIONS = 160;
  READER_THREADS = 3;
  READER_ITERATIONS = 4000;
var
  LWriters: array of TBackendRegisterToggleWorker;
  LReaders: array of TBackendOpsReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LDisabledTable: TSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;

  function IsScalarBackedForRepresentativeSlots(const aBackendTable,
    aScalarTable: TSimdDispatchTable): Boolean;
  begin
    Result :=
      (Pointer(aBackendTable.AddF32x4) = Pointer(aScalarTable.AddF32x4)) and
      (Pointer(aBackendTable.MulF32x4) = Pointer(aScalarTable.MulF32x4)) and
      (Pointer(aBackendTable.AddI32x4) = Pointer(aScalarTable.AddI32x4)) and
      (Pointer(aBackendTable.SelectF32x4) = Pointer(aScalarTable.SelectF32x4));
  end;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LBackend := sbScalar;
  LOriginalTable := Default(TSimdDispatchTable);
  LDisabledTable := Default(TSimdDispatchTable);
  LScalarTable := Default(TSimdDispatchTable);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LBackend := GetCurrentBackend;
    if LBackend = sbScalar then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable) then
      Exit;
    if not TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable) then
      Exit;
    if IsScalarBackedForRepresentativeSlots(LOriginalTable, LScalarTable) then
      Exit;

    LDisabledTable := LOriginalTable;
    LDisabledTable.BackendInfo.Available := False;
    LDisabledTable.BackendInfo.Capabilities := [];
    LDisabledTable.AddF32x4 := LScalarTable.AddF32x4;
    LDisabledTable.MulF32x4 := LScalarTable.MulF32x4;
    LDisabledTable.AddI32x4 := LScalarTable.AddI32x4;
    LDisabledTable.SelectF32x4 := LScalarTable.SelectF32x4;

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TBackendRegisterToggleWorker.Create(
        WRITER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TBackendOpsReadWorker.Create(
        READER_ITERATIONS, LBackend, LOriginalTable, LDisabledTable);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent backend-ops register/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    if LBackend <> sbScalar then
      RegisterBackend(LBackend, LOriginalTable);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_CurrentBackendInfo_VectorAsmToggle_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 4000;
  READER_THREADS = 6;
  READER_ITERATIONS = 30000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TCurrentBackendInfoReadWorker;
  LExpectedEnabledInfo: TSimdBackendInfo;
  LExpectedDisabledInfo: TSimdBackendInfo;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LExpectedEnabledInfo := Default(TSimdBackendInfo);
  LExpectedDisabledInfo := Default(TSimdBackendInfo);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LExpectedEnabledInfo := GetCurrentBackendInfo;

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LExpectedDisabledInfo := GetCurrentBackendInfo;

    if BackendInfoMatchesLocal(LExpectedEnabledInfo, LExpectedDisabledInfo) then
      Exit;

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TCurrentBackendInfoReadWorker.Create(
        READER_ITERATIONS, LExpectedEnabledInfo, LExpectedDisabledInfo);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent current-backend-info toggle/read failed: ' + LErrorMsgs,
      LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_CurrentBackend_VectorAsmToggle_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 4000;
  READER_THREADS = 6;
  READER_ITERATIONS = 30000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TCurrentBackendReadWorker;
  LExpectedEnabledBackend: TSimdBackend;
  LExpectedDisabledBackend: TSimdBackend;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LExpectedEnabledBackend := sbScalar;
  LExpectedDisabledBackend := sbScalar;

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LExpectedEnabledBackend := GetCurrentBackend;

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LExpectedDisabledBackend := GetCurrentBackend;

    if LExpectedEnabledBackend = LExpectedDisabledBackend then
      Exit;

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TCurrentBackendReadWorker.Create(
        READER_ITERATIONS, LExpectedEnabledBackend, LExpectedDisabledBackend);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent current-backend toggle/read failed: ' + LErrorMsgs,
      LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_DispatchableHelpers_VectorAsmToggle_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 4000;
  READER_THREADS = 6;
  READER_ITERATIONS = 30000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TDispatchableHelpersReadWorker;
  LExpectedEnabledList: TSimdBackendArray;
  LExpectedDisabledList: TSimdBackendArray;
  LExpectedEnabledBest: TSimdBackend;
  LExpectedDisabledBest: TSimdBackend;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LExpectedEnabledList := nil;
  LExpectedDisabledList := nil;

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LExpectedEnabledList := nextpas.core.simd.GetDispatchableBackendList;
    LExpectedEnabledBest := nextpas.core.simd.GetBestDispatchableBackend;

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LExpectedDisabledList := nextpas.core.simd.GetDispatchableBackendList;
    LExpectedDisabledBest := nextpas.core.simd.GetBestDispatchableBackend;

    if SameBackendArrayLocal(LExpectedEnabledList, LExpectedDisabledList) and
       (LExpectedEnabledBest = LExpectedDisabledBest) then
      Exit;

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TDispatchableHelpersReadWorker.Create(
        READER_ITERATIONS, LExpectedEnabledList, LExpectedDisabledList,
        LExpectedEnabledBest, LExpectedDisabledBest);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent dispatchable helper toggle/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentFramework.Test_Concurrent_RuntimeSnapshot_VectorAsmToggle_ReadConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 4000;
  READER_THREADS = 6;
  READER_ITERATIONS = 30000;
var
  LWriters: array of TVectorAsmMultiToggleWorker;
  LReaders: array of TCurrentRuntimeSnapshotReadWorker;
  LExpectedEnabledSnapshot: TSimdRuntimeSnapshot;
  LExpectedDisabledSnapshot: TSimdRuntimeSnapshot;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWriters := nil;
  LReaders := nil;
  LExpectedEnabledSnapshot := Default(TSimdRuntimeSnapshot);
  LExpectedDisabledSnapshot := Default(TSimdRuntimeSnapshot);

  try
    SetVectorAsmEnabled(True);
    ResetToAutomaticBackend;
    LExpectedEnabledSnapshot := nextpas.core.simd.GetCurrentRuntimeSnapshot;

    SetVectorAsmEnabled(False);
    ResetToAutomaticBackend;
    LExpectedDisabledSnapshot := nextpas.core.simd.GetCurrentRuntimeSnapshot;

    if RuntimeSnapshotMatchesLocal(LExpectedEnabledSnapshot, LExpectedDisabledSnapshot) then
      Exit;

    SetLength(LWriters, WRITER_THREADS);
    SetLength(LReaders, READER_THREADS);
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex] := TVectorAsmMultiToggleWorker.Create(WRITER_ITERATIONS, LIndex);
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex] := TCurrentRuntimeSnapshotReadWorker.Create(
        READER_ITERATIONS, LExpectedEnabledSnapshot, LExpectedDisabledSnapshot);

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent runtime-snapshot toggle/read failed: ' + LErrorMsgs, LAllSuccess);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrentRegistration.Test_Concurrent_RegisteredBackendList_FirstRegistration_ReadConsistency;
const
  READER_THREADS = 8;
  READER_ITERATIONS = 1000000;
var
  LReaders: array of TRegisteredBackendListReadWorker;
  LWriter: TBackendFirstRegisterSequenceWorker;
  LBaseRegistered: TSimdBackendArray;
  LRegistrationOrder: TSimdBackendArray;
  LExpectedStates: TSimdBackendArrayStates;
  LRegisterTables: TSimdDispatchTableArray;
  LSeedTable: TSimdDispatchTable;
  LBackend: TSimdBackend;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
begin
  LReaders := nil;
  LWriter := nil;
  LBaseRegistered := nextpas.core.simd.GetRegisteredBackendList;
  LRegistrationOrder := nil;
  LExpectedStates := nil;
  LRegisterTables := nil;
  LSeedTable := Default(TSimdDispatchTable);

  for LBackend := High(TSimdBackend) downto Low(TSimdBackend) do
    if not IsBackendRegisteredInBinary(LBackend) then
    begin
      SetLength(LRegistrationOrder, Length(LRegistrationOrder) + 1);
      LRegistrationOrder[High(LRegistrationOrder)] := LBackend;
    end;

  if Length(LRegistrationOrder) < 2 then
    Exit;

  AssertTrue('Scalar backend should be registered before first-registration concurrent test',
    TryGetRegisteredBackendDispatchTable(sbScalar, LSeedTable));
  LSeedTable.BackendInfo.Available := False;
  LSeedTable.BackendInfo.Capabilities := [];

  SetLength(LRegisterTables, Length(LRegistrationOrder));
  for LIndex := 0 to High(LRegistrationOrder) do
  begin
    LRegisterTables[LIndex] := LSeedTable;
    LRegisterTables[LIndex].BackendInfo.Name := 'ConcurrentFirstRegister_' +
      ConcurrentBackendName(LRegistrationOrder[LIndex]);
    LRegisterTables[LIndex].BackendInfo.Description := 'Synthetic first-registration state for backend ' +
      ConcurrentBackendName(LRegistrationOrder[LIndex]);
  end;

  SetLength(LExpectedStates, Length(LRegistrationOrder) + 1);
  for LIndex := 0 to High(LExpectedStates) do
    LExpectedStates[LIndex] := BuildRegisteredBackendSnapshotLocal(
      LBaseRegistered, LRegistrationOrder, LIndex);

  SetLength(LReaders, READER_THREADS);
  for LIndex := 0 to High(LReaders) do
    LReaders[LIndex] := TRegisteredBackendListReadWorker.Create(
      READER_ITERATIONS, LExpectedStates);
  LWriter := TBackendFirstRegisterSequenceWorker.Create(LRegistrationOrder, LRegisterTables);

  try
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;
    LWriter.Start;

    LWriter.WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';
    if not LWriter.Success then
    begin
      LAllSuccess := False;
      LErrorMsgs := LErrorMsgs + LWriter.ErrorMsg + '; ';
    end;
    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    AssertTrue('Concurrent registered-backend-list first-register/read failed: ' + LErrorMsgs,
      LAllSuccess);
    AssertTrue('Final registered backend list should reach the fully registered state after first registrations',
      SameBackendArrayLocal(nextpas.core.simd.GetRegisteredBackendList,
        LExpectedStates[High(LExpectedStates)]));
  finally
    LWriter.Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_DispatchMixed_ControlPlane;
const
  ROUNDS = 4;
  WORKER_THREADS = 8;
  READER_THREADS = 4;
  WORKER_ITERATIONS = 3000;
  READER_ITERATIONS = 4500;
var
  LRound, LIndex: Integer;
  LWorkers: array of TDispatchMixedControlWorker;
  LReaders: array of TVectorAsmReadWorker;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
  LOldVectorAsm: Boolean;
  LDispatch: PSimdDispatchTable;
  LA, LB, LC, LProbe: TVecF32x4;
  LValue: Single;
begin
  LOldVectorAsm := IsVectorAsmEnabled;
  LWorkers := nil;
  LReaders := nil;

  try
    for LRound := 1 to ROUNDS do
    begin
      SetLength(LWorkers, WORKER_THREADS);
      SetLength(LReaders, READER_THREADS);
      for LIndex := 0 to High(LWorkers) do
        LWorkers[LIndex] := TDispatchMixedControlWorker.Create(WORKER_ITERATIONS, LRound + LIndex);
      for LIndex := 0 to High(LReaders) do
        LReaders[LIndex] := TVectorAsmReadWorker.Create(READER_ITERATIONS);

      for LIndex := 0 to High(LWorkers) do
        LWorkers[LIndex].Start;
      for LIndex := 0 to High(LReaders) do
        LReaders[LIndex].Start;
      for LIndex := 0 to High(LWorkers) do
        LWorkers[LIndex].WaitFor;
      for LIndex := 0 to High(LReaders) do
        LReaders[LIndex].WaitFor;

      LAllSuccess := True;
      LErrorMsgs := '';
      for LIndex := 0 to High(LWorkers) do
      begin
        if not LWorkers[LIndex].Success then
        begin
          LAllSuccess := False;
          LErrorMsgs := LErrorMsgs + LWorkers[LIndex].ErrorMsg + '; ';
        end;
        LWorkers[LIndex].Free;
        LWorkers[LIndex] := nil;
      end;
      for LIndex := 0 to High(LReaders) do
      begin
        if not LReaders[LIndex].Success then
        begin
          LAllSuccess := False;
          LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
        end;
        LReaders[LIndex].Free;
        LReaders[LIndex] := nil;
      end;

      AssertTrue('Dispatch mixed control round ' + IntToStr(LRound) + ' failed: ' + LErrorMsgs, LAllSuccess);

      ResetToAutomaticBackend;
      LDispatch := GetDispatchTable;
      AssertTrue('Post-round dispatch should be available',
        (LDispatch <> nil) and Assigned(LDispatch^.AddF32x4) and
        Assigned(LDispatch^.RoundF32x4) and Assigned(LDispatch^.TruncF32x4));

      LA := MakeSplatF32x4(1.0);
      LB := MakeSplatF32x4(2.0);
      LC := LDispatch^.AddF32x4(LA, LB);
      LValue := VecF32x4Extract(LC, 0);
      AssertTrue('Post-round AddF32x4 sanity mismatch on round ' + IntToStr(LRound),
        Abs(LValue - 3.0) <= FLOAT_EPSILON);

      LProbe := MakeSplatF32x4(-1.75);
      LC := LDispatch^.RoundF32x4(LProbe);
      LValue := VecF32x4Extract(LC, 0);
      AssertTrue('Post-round RoundF32x4 sanity mismatch on round ' + IntToStr(LRound),
        Abs(LValue - (-2.0)) <= FLOAT_EPSILON);
      LC := LDispatch^.TruncF32x4(LProbe);
      LValue := VecF32x4Extract(LC, 0);
      AssertTrue('Post-round TruncF32x4 sanity mismatch on round ' + IntToStr(LRound),
        Abs(LValue - (-1.0)) <= FLOAT_EPSILON);

      SetLength(LWorkers, 0);
      SetLength(LReaders, 0);
    end;
  finally
    for LIndex := 0 to High(LWorkers) do
      if Assigned(LWorkers[LIndex]) then
        LWorkers[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      if Assigned(LReaders[LIndex]) then
        LReaders[LIndex].Free;
  end;
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_Mixed_MathOps;
var
  workers: array of TMixedMathWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TMixedMathWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent Mixed MathOps failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Concurrent_Reduction_Operations;
var
  workers: array of TReductionWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  workers := nil;
  SetLength(workers, DEFAULT_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TReductionWorker.Create(i, DEFAULT_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    workers[i].Free;
  end;

  AssertTrue('Concurrent Reduction Operations failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Stress_Concurrent_SIMD;
var
  workers: array of TStressWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
  totalOps: Int64;
begin
  workers := nil;
  SetLength(workers, STRESS_THREAD_COUNT);

  for i := 0 to High(workers) do
    workers[i] := TStressWorker.Create(i, STRESS_ITERATIONS);

  for i := 0 to High(workers) do
    workers[i].Start;

  for i := 0 to High(workers) do
    workers[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  totalOps := 0;
  for i := 0 to High(workers) do
  begin
    if not workers[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
    end;
    totalOps := totalOps + workers[i].OperationsCompleted;
    workers[i].Free;
  end;

  WriteLn(Format('  Stress test completed: %d threads, %d total SIMD operations',
                [STRESS_THREAD_COUNT, totalOps]));

  AssertTrue('Stress Concurrent SIMD failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Stress_LongRunning;
var
  workers: array of TStressWorker;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
  startTime: QWord;
  iterations: Integer;
begin
  startTime := GetTickCount64;
  iterations := 0;

  // 运行直到达到时间限制
  while (GetTickCount64 - startTime) < QWord(LONG_RUNNING_SECONDS * 1000) do
  begin
    workers := nil;
    SetLength(workers, 4);  // 使用较少线程以便快速迭代

    for i := 0 to High(workers) do
      workers[i] := TStressWorker.Create(i, 1000);

    for i := 0 to High(workers) do
      workers[i].Start;

    for i := 0 to High(workers) do
      workers[i].WaitFor;

    allSuccess := True;
    errorMsgs := '';
    for i := 0 to High(workers) do
    begin
      if not workers[i].Success then
      begin
        allSuccess := False;
        errorMsgs := errorMsgs + workers[i].ErrorMsg + '; ';
      end;
      workers[i].Free;
    end;

    if not allSuccess then
      Break;

    Inc(iterations);
  end;

  WriteLn(Format('  Long-running test: %d iterations in %d seconds',
                [iterations, LONG_RUNNING_SECONDS]));

  AssertTrue('Long-running stress test failed: ' + errorMsgs, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Stress_RapidThreadCreation;
var
  i: Integer;
  worker: TF32x4AddWorker;
  allSuccess: Boolean;
  errorMsg: string;
const
  RAPID_ITERATIONS = 100;
  OPS_PER_THREAD = 100;
begin
  allSuccess := True;
  errorMsg := '';

  for i := 0 to RAPID_ITERATIONS - 1 do
  begin
    worker := TF32x4AddWorker.Create(i, OPS_PER_THREAD);
    try
      worker.Start;
      worker.WaitFor;

      if not worker.Success then
      begin
        allSuccess := False;
        errorMsg := Format('Iteration %d: %s', [i, worker.ErrorMsg]);
        Break;
      end;
    finally
      worker.Free;
    end;
  end;

  WriteLn(Format('  Rapid thread creation: %d threads created/destroyed', [RAPID_ITERATIONS]));

  AssertTrue('Rapid thread creation failed: ' + errorMsg, allSuccess);
end;

procedure TTestCase_SimdConcurrent.Test_Stress_LargeData_Concurrent;
var
  threads: array of TLargeDataThread;
  i: Integer;
  allSuccess: Boolean;
  errorMsgs: string;
begin
  threads := nil;
  SetLength(threads, DEFAULT_THREAD_COUNT);

  for i := 0 to High(threads) do
    threads[i] := TLargeDataThread.Create(i);

  for i := 0 to High(threads) do
    threads[i].Start;

  for i := 0 to High(threads) do
    threads[i].WaitFor;

  allSuccess := True;
  errorMsgs := '';
  for i := 0 to High(threads) do
  begin
    if not threads[i].Success then
    begin
      allSuccess := False;
      errorMsgs := errorMsgs + threads[i].ErrorMsg + '; ';
    end;
    threads[i].Free;
  end;

  AssertTrue('Large data concurrent processing failed: ' + errorMsgs, allSuccess);
end;

initialization
  RegisterTest(TTestCase_SimdConcurrent);
  RegisterTest(TTestCase_SimdConcurrentPublicAbi);
  RegisterTest(TTestCase_SimdConcurrentFramework);
  RegisterTest(TTestCase_SimdConcurrentRegistration);

end.
