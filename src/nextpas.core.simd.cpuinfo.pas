unit nextpas.core.simd.cpuinfo;


{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.atomic
  {$IFDEF WINDOWS}
  , nextpas.core.simd.cpuinfo.windows
  {$ELSE}
    {$IFDEF DARWIN}
    , nextpas.core.simd.cpuinfo.darwin
    {$ELSE}
      {$IFDEF UNIX}
      , nextpas.core.simd.cpuinfo.unix
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
  ;

// === CPU Feature Detection Facade ===
// 纯门面模式：委托给平台特定的实现模块

type
  // Compatibility re-export: the shared backend-list container now lives in
  // nextpas.core.simd.base so cpuinfo/runtime can return the same canonical type
  // without making cpuinfo the owner of this shared container symbol.
  TSimdBackendArray = nextpas.core.simd.base.TSimdBackendArray;

// === 公共门面 API ===

// Get comprehensive CPU information (thread-safe)
function GetCPUInfo: TCPUInfo;

// Architecture detection helpers
function DetectCPUArchitecture: TCPUArch;

// Feature query helpers (quick checks)
function HasFeature(feature: TGenericFeature): Boolean;
function IsBackendSupportedOnCPU(aBackend: TSimdBackend): Boolean;
function GetSupportedBackendList: TSimdBackendArray; // preferred canonical name
function GetSupportedBackends: TSimdBackendArray; // compatibility alias; new code/docs use GetSupportedBackendList
function GetAvailableBackends: TSimdBackendArray; // compatibility alias; still means supported_on_cpu, not runtime dispatchable; new code/docs use GetSupportedBackendList

// Get best backend allowed by current CPU/OS capabilities.
function GetBestSupportedBackend: TSimdBackend; // preferred canonical name
function GetBestBackendOnCPU: TSimdBackend; // compatibility alias; new code/docs use GetBestSupportedBackend
function GetBestBackend: TSimdBackend; // compatibility alias; new code/docs use GetBestSupportedBackend

// Cache and lifecycle helpers
procedure ResetCPUInfo; // safe reset for re-initialization

// Quick feature detection (commonly used)
function HasSSE2: Boolean;
function HasSSE3: Boolean;
function HasSSSE3: Boolean;
function HasSSE41: Boolean;
function HasSSE42: Boolean;
function HasAVX2: Boolean;
function HasAVX512: Boolean;
function HasNEON: Boolean;
function HasSVE: Boolean;
function HasSVE2: Boolean;
function HasRISCVV: Boolean;
function HasLASX: Boolean;

{$IFDEF SIMD_X86_AVAILABLE}
function GetX86CPUInfo: TX86Features;
{$ENDIF}

{$IFDEF SIMD_ARM_AVAILABLE}
function GetARMCPUInfo: TARMFeatures;
{$ENDIF}

{$IFDEF SIMD_RISCV_AVAILABLE}
function GetRISCVCPUInfo: TRISCVFeatures;
{$ENDIF}

{$IFDEF SIMD_LOONGARCH_AVAILABLE}
function GetLoongArchCPUInfo: TLoongArchFeatures;
{$ENDIF}

implementation

// Platform-specific imports
{$IF DEFINED(SIMD_X86_AVAILABLE) OR DEFINED(SIMD_ARM_AVAILABLE) OR DEFINED(SIMD_RISCV_AVAILABLE) OR DEFINED(SIMD_LOONGARCH_AVAILABLE)}
uses
  nextpas.core.simd.backend.priority,
  {$IFDEF SIMD_X86_AVAILABLE}
  nextpas.core.simd.cpuinfo.x86
    {$IF DEFINED(SIMD_ARM_AVAILABLE) OR DEFINED(SIMD_RISCV_AVAILABLE) OR DEFINED(SIMD_LOONGARCH_AVAILABLE)}
    ,
    {$ENDIF}
  {$ENDIF}
  {$IFDEF SIMD_ARM_AVAILABLE}
  nextpas.core.simd.cpuinfo.arm
    {$IF DEFINED(SIMD_RISCV_AVAILABLE) OR DEFINED(SIMD_LOONGARCH_AVAILABLE)}
    ,
    {$ENDIF}
  {$ENDIF}
  {$IFDEF SIMD_RISCV_AVAILABLE}
  nextpas.core.simd.cpuinfo.riscv
    {$IFDEF SIMD_LOONGARCH_AVAILABLE}
    ,
    {$ENDIF}
  {$ENDIF}
  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  nextpas.core.simd.cpuinfo.loongarch
  {$ENDIF}
  ;
{$ENDIF}

var
  // Global CPU info cache
  G_CPUInfo: TCPUInfo;
  // Initialization state: 0=uninitialized, 1=initializing, 2=initialized
  G_InitState: Int32 = 0;

function X86_XCR0_EnablesAVX: Boolean; inline;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := ((G_CPUInfo.XCR0 and (UInt64(1) shl 1)) <> 0) {XMM}
            and ((G_CPUInfo.XCR0 and (UInt64(1) shl 2)) <> 0); {YMM}
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function X86_XCR0_EnablesAVX512: Boolean; inline;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := X86_XCR0_EnablesAVX and
            ((G_CPUInfo.XCR0 and (UInt64(1) shl 5)) <> 0) and {opmask}
            ((G_CPUInfo.XCR0 and (UInt64(1) shl 6)) <> 0) and {ZMM_Hi256}
            ((G_CPUInfo.XCR0 and (UInt64(1) shl 7)) <> 0);   {Hi16_ZMM}
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

{$IFDEF SIMD_X86_AVAILABLE}
function DetectX86Architecture: TCPUArch;
begin
  // All x86 variants map to caX86 in this simplified enum
  Result := caX86;
end;
{$ENDIF}

// Detect CPU architecture dynamically
function DetectCPUArchitecture: TCPUArch;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := DetectX86Architecture;
  {$ELSE}
    {$IFDEF SIMD_ARM_AVAILABLE}
    Result := caARM;
    {$ELSE}
      {$IFDEF SIMD_RISCV_AVAILABLE}
      Result := caRISCV;
      {$ELSE}
        {$IFDEF SIMD_LOONGARCH_AVAILABLE}
        Result := caLoongArch;
        {$ELSE}
        Result := caUnknown;
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
end;

// Cross-platform core count detection dispatcher via platform-specific units
function DetectCoreCountsPortable(out Physical, Logical: LongInt): Boolean;
begin
  Physical := 0;
  Logical := 0;
  {$IFDEF WINDOWS}
  Result := nextpas.core.simd.cpuinfo.windows.DetectCoreCounts(Physical, Logical);
  {$ELSE}
    {$IFDEF DARWIN}
    Result := nextpas.core.simd.cpuinfo.darwin.DetectCoreCounts(Physical, Logical);
    {$ELSE}
      {$IFDEF UNIX}
      Result := nextpas.core.simd.cpuinfo.unix.DetectCoreCounts(Physical, Logical);
      {$ELSE}
      Result := False;
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
  if Physical < 1 then Physical := 1;
  if Logical < 1 then Logical := 1;
end;

{$IFDEF LINUX}
function ReadFirstLineTrimmed(const aPath: string): string;
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

function ParseSizeToKB(const aText: string): Integer;
begin
  Result := ParseCacheSizeTextToKB(aText);
end;

function IsLinuxCpuDirectoryName(const aName: string): Boolean;
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

procedure FillCacheInfoFromLinuxSysfs(var aCache: TCacheInfo);
var
  LCpuBase: string;
  LCpuCacheBase: string;
  LCpuRec: TSearchRec;
  LIndexRec: TSearchRec;
  LDir: string;
  LTypeText: string;
  LLevelText: string;
  LSizeText: string;
  LLineSizeText: string;
  LLevel: Integer;
  LSizeKB: Integer;
  LLineSize: Integer;
begin
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
      if not IsLinuxCpuDirectoryName(LCpuRec.Name) then
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
          LTypeText := LowerCase(ReadFirstLineTrimmed(LDir + '/type'));
          LLevelText := ReadFirstLineTrimmed(LDir + '/level');
          LSizeText := ReadFirstLineTrimmed(LDir + '/size');
          LLineSizeText := ReadFirstLineTrimmed(LDir + '/coherency_line_size');

          LLevel := StrToIntDef(LLevelText, 0);
          LSizeKB := ParseSizeToKB(LSizeText);
          LLineSize := StrToIntDef(LLineSizeText, 0);

          if LLineSize > aCache.LineSize then
            aCache.LineSize := LLineSize;

          if (LLevel <= 0) or (LSizeKB <= 0) then
            Continue;

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
end;
{$ENDIF}

// Internal initialization worker (no concurrency guards)
procedure InitializeCPUInfoInternal;
{$IFDEF SIMD_X86_AVAILABLE}
var
  CacheInfo: TX86CacheInfo;
  eax, ebx, ecx, edx: DWord;
{$ENDIF}
var
  PhysC, LogC: LongInt;
begin
  // 设定架构
  G_CPUInfo.Arch := DetectCPUArchitecture;
  
  // 委托给平台特定的检测模块
  {$IFDEF SIMD_X86_AVAILABLE}
  if G_CPUInfo.Arch = caX86 then
  begin
    nextpas.core.simd.cpuinfo.x86.DetectX86VendorAndModel(G_CPUInfo);
    G_CPUInfo.X86 := nextpas.core.simd.cpuinfo.x86.DetectX86Features;

    // OSXSAVE / XCR0 (precise detection)
    // Initialize locals to keep the compiler happy (CPUID is implemented in asm).
    eax := 0; ebx := 0; ecx := 0; edx := 0;
    CPUID($00000001, eax, ebx, ecx, edx);
    G_CPUInfo.OSXSAVE := ((ecx and (1 shl 27)) <> 0);
    if G_CPUInfo.OSXSAVE then
      G_CPUInfo.XCR0 := nextpas.core.simd.cpuinfo.x86.ReadXCR0
    else
      G_CPUInfo.XCR0 := 0;
    
    // Convert x86 cache info to generic format
    CacheInfo := nextpas.core.simd.cpuinfo.x86.GetX86CacheInfo;
    G_CPUInfo.Cache.L1DataKB := CacheInfo.L1DataCache;
    G_CPUInfo.Cache.L1InstrKB := CacheInfo.L1InstructionCache;
    G_CPUInfo.Cache.L2KB := CacheInfo.L2Cache;
    G_CPUInfo.Cache.L3KB := CacheInfo.L3Cache;
    G_CPUInfo.Cache.LineSize := CacheInfo.CacheLineSize;
  end;
  {$ENDIF}
  
  {$IFDEF SIMD_ARM_AVAILABLE}
  if G_CPUInfo.Arch = caARM then
  begin
    nextpas.core.simd.cpuinfo.arm.DetectARMVendorAndModel(G_CPUInfo);
    G_CPUInfo.ARM := nextpas.core.simd.cpuinfo.arm.DetectARMFeatures;

    {$IFDEF LINUX}
    FillCacheInfoFromLinuxSysfs(G_CPUInfo.Cache);
    {$ENDIF}

    if G_CPUInfo.Cache.LineSize = 0 then
      G_CPUInfo.Cache.LineSize := 64;
  end;
  {$ENDIF}
  
  {$IFDEF SIMD_RISCV_AVAILABLE}
  if G_CPUInfo.Arch = caRISCV then
  begin
    nextpas.core.simd.cpuinfo.riscv.DetectRISCVVendorAndModel(G_CPUInfo);
    G_CPUInfo.RISCV := nextpas.core.simd.cpuinfo.riscv.DetectRISCVFeatures;

    {$IFDEF LINUX}
    FillCacheInfoFromLinuxSysfs(G_CPUInfo.Cache);
    {$ENDIF}

    if G_CPUInfo.Cache.LineSize = 0 then
      G_CPUInfo.Cache.LineSize := 64;
  end;
  {$ENDIF}

  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  if G_CPUInfo.Arch = caLoongArch then
  begin
    nextpas.core.simd.cpuinfo.loongarch.DetectLoongArchVendorAndModel(G_CPUInfo);
    G_CPUInfo.LoongArch := nextpas.core.simd.cpuinfo.loongarch.DetectLoongArchFeatures;

    {$IFDEF LINUX}
    FillCacheInfoFromLinuxSysfs(G_CPUInfo.Cache);
    {$ENDIF}

    if G_CPUInfo.Cache.LineSize = 0 then
      G_CPUInfo.Cache.LineSize := 64;
  end;
  {$ENDIF}
  
  // Fallback for unknown architectures
  if G_CPUInfo.Arch = caUnknown then
  begin
    G_CPUInfo.Vendor := 'Unknown';
    G_CPUInfo.Model := 'Unknown CPU';
    G_CPUInfo.PhysicalCores := 1;
    G_CPUInfo.LogicalCores := 1;
    G_CPUInfo.Cache.LineSize := 64;
  end;
  
  // Core count detection (cross-platform best effort)
  if DetectCoreCountsPortable(PhysC, LogC) then
  begin
    G_CPUInfo.PhysicalCores := PhysC;
    G_CPUInfo.LogicalCores := LogC;
  end
  else
  begin
    if G_CPUInfo.LogicalCores = 0 then
    begin
      G_CPUInfo.PhysicalCores := 1;
      G_CPUInfo.LogicalCores := 1;
    end;
  end;

  // Populate GenericRaw / GenericUsable
  G_CPUInfo.GenericRaw := [];
  G_CPUInfo.GenericUsable := [];
  case G_CPUInfo.Arch of
    {$IFDEF SIMD_X86_AVAILABLE}
    caX86:
      begin
        if G_CPUInfo.X86.HasSSE2 then Include(G_CPUInfo.GenericRaw, gfSimd128);
        if G_CPUInfo.X86.HasAVX or G_CPUInfo.X86.HasAVX2 then Include(G_CPUInfo.GenericRaw, gfSimd256);
        if G_CPUInfo.X86.HasAVX512F then Include(G_CPUInfo.GenericRaw, gfSimd512);
        if G_CPUInfo.X86.HasAES then Include(G_CPUInfo.GenericRaw, gfAES);
        if G_CPUInfo.X86.HasFMA then Include(G_CPUInfo.GenericRaw, gfFMA);
        if G_CPUInfo.X86.HasSHA then Include(G_CPUInfo.GenericRaw, gfSHA);
        // OS usable checks
        if G_CPUInfo.X86.HasSSE2 then Include(G_CPUInfo.GenericUsable, gfSimd128);
        if (G_CPUInfo.X86.HasAVX or G_CPUInfo.X86.HasAVX2) and (nextpas.core.simd.cpuinfo.x86.IsAVXSupportedByOS) and X86_XCR0_EnablesAVX then Include(G_CPUInfo.GenericUsable, gfSimd256);
        if G_CPUInfo.X86.HasAVX512F and (nextpas.core.simd.cpuinfo.x86.IsAVXSupportedByOS) and X86_XCR0_EnablesAVX512 then Include(G_CPUInfo.GenericUsable, gfSimd512);
        if G_CPUInfo.X86.HasAES then Include(G_CPUInfo.GenericUsable, gfAES);
        if G_CPUInfo.X86.HasFMA and (nextpas.core.simd.cpuinfo.x86.IsAVXSupportedByOS) and X86_XCR0_EnablesAVX then Include(G_CPUInfo.GenericUsable, gfFMA);
        if G_CPUInfo.X86.HasSHA then Include(G_CPUInfo.GenericUsable, gfSHA);
      end;
    {$ENDIF}
    {$IFDEF SIMD_ARM_AVAILABLE}
    caARM:
      begin
        if G_CPUInfo.ARM.HasNEON then Include(G_CPUInfo.GenericRaw, gfSimd128);
        if G_CPUInfo.ARM.HasSVE then
        begin
          Include(G_CPUInfo.GenericRaw, gfSimd256);
          Include(G_CPUInfo.GenericRaw, gfSimd512);
        end;
        if G_CPUInfo.ARM.HasCrypto then
        begin
          Include(G_CPUInfo.GenericRaw, gfAES);
          Include(G_CPUInfo.GenericRaw, gfSHA);
        end;
        // ARM: assume OS usability aligns with hardware availability for NEON/SVE in user space
        G_CPUInfo.GenericUsable := G_CPUInfo.GenericRaw;
      end;
    {$ENDIF}
    {$IFDEF SIMD_RISCV_AVAILABLE}
    caRISCV:
      begin
        if G_CPUInfo.RISCV.HasV then
        begin
          Include(G_CPUInfo.GenericRaw, gfSimd128);
          Include(G_CPUInfo.GenericRaw, gfSimd256);
          Include(G_CPUInfo.GenericRaw, gfSimd512);
        end;
        G_CPUInfo.GenericUsable := G_CPUInfo.GenericRaw;
      end;
    {$ENDIF}
    {$IFDEF SIMD_LOONGARCH_AVAILABLE}
    caLoongArch:
      begin
        if G_CPUInfo.LoongArch.HasLASX then
          Include(G_CPUInfo.GenericRaw, gfSimd256);
        G_CPUInfo.GenericUsable := G_CPUInfo.GenericRaw;
      end;
    {$ENDIF}
  else
    ;
  end;
end;

// Single-time initialization with atomic state machine
function AtomicCAS(var Target: Int32; Expected, Desired: Int32): Boolean; inline;
var
  Exp: Int32;
begin
  Exp := Expected;
  Result := atomic_compare_exchange(Target, Exp, Desired);
end;

procedure EnsureCPUInfoInitialized;
var
  LState: Int32;
begin
  while True do
  begin
    LState := G_InitState;
    if LState = 2 then
      Exit;

    // Try to become initializer when state is uninitialized.
    if LState = 0 then
    begin
      if AtomicCAS(G_InitState, 0, 1) then
      begin
        try
          InitializeCPUInfoInternal;
          atomic_thread_fence(mo_seq_cst); // Ensure visibility of G_CPUInfo writes
          G_InitState := 2;
          Exit;
        except
          // Roll back to uninitialized and let callers retry.
          atomic_thread_fence(mo_seq_cst);
          G_InitState := 0;
          raise;
        end;
      end;
      Continue;
    end;

    // Another thread is initializing (state=1): wait until it publishes 2 or rolls back to 0.
    if LState = 1 then
    begin
      atomic_thread_fence(mo_seq_cst);
      ThreadSwitch;
      Continue;
    end;

    // Defensive: unknown state, retry after yielding.
    atomic_thread_fence(mo_seq_cst);
    ThreadSwitch;
  end;
end;

// Main CPU info getter (thread-safe)
function GetCPUInfo: TCPUInfo;
begin
  if G_InitState <> 2 then
    EnsureCPUInfoInitialized;
  Result := G_CPUInfo;
end;

// Quick feature checker（基于“可用”能力，而非仅硬件）
function HasFeature(feature: TGenericFeature): Boolean;
var
  LCPUInfo: TCPUInfo;
begin
  LCPUInfo := GetCPUInfo;
  Result := feature in LCPUInfo.GenericUsable;
end;

function IsBackendSupportedOnCPU(aBackend: TSimdBackend): Boolean;
var
  LCPUInfo: TCPUInfo;
  LHasSimd128: Boolean;
  LHasSimd256: Boolean;
  LHasSimd512: Boolean;
begin
  if aBackend = sbScalar then
    Exit(True);

  LCPUInfo := GetCPUInfo;
  LHasSimd128 := gfSimd128 in LCPUInfo.GenericUsable;
  LHasSimd256 := gfSimd256 in LCPUInfo.GenericUsable;
  LHasSimd512 := gfSimd512 in LCPUInfo.GenericUsable;

  case aBackend of
    sbSSE2: Result := (LCPUInfo.Arch = caX86) and LHasSimd128;
    sbSSE3:
      begin
        {$IFDEF SIMD_X86_AVAILABLE}
        Result := (LCPUInfo.Arch = caX86) and LHasSimd128 and LCPUInfo.X86.HasSSE3;
        {$ELSE}
        Result := False;
        {$ENDIF}
      end;
    sbSSSE3:
      begin
        {$IFDEF SIMD_X86_AVAILABLE}
        Result := (LCPUInfo.Arch = caX86) and LHasSimd128 and LCPUInfo.X86.HasSSSE3;
        {$ELSE}
        Result := False;
        {$ENDIF}
      end;
    sbSSE41:
      begin
        {$IFDEF SIMD_X86_AVAILABLE}
        Result := (LCPUInfo.Arch = caX86) and LHasSimd128 and LCPUInfo.X86.HasSSE41;
        {$ELSE}
        Result := False;
        {$ENDIF}
      end;
    sbSSE42:
      begin
        {$IFDEF SIMD_X86_AVAILABLE}
        Result := (LCPUInfo.Arch = caX86) and LHasSimd128 and LCPUInfo.X86.HasSSE42;
        {$ELSE}
        Result := False;
        {$ENDIF}
      end;
    sbAVX2:
      begin
        {$IFDEF SIMD_X86_AVAILABLE}
        Result := (LCPUInfo.Arch = caX86) and LHasSimd256 and LCPUInfo.X86.HasAVX2;
        {$ELSE}
        Result := False;
        {$ENDIF}
      end;
    sbAVX512:
      begin
        {$IFDEF SIMD_X86_AVAILABLE}
        Result := (LCPUInfo.Arch = caX86) and
                  X86SupportsAVX512BackendOnCPU(LCPUInfo.X86, LHasSimd512);
        {$ELSE}
        Result := False;
        {$ENDIF}
      end;
    sbNEON: Result := (LCPUInfo.Arch = caARM) and LHasSimd128;
    sbRISCVV: Result := (LCPUInfo.Arch = caRISCV) and (LHasSimd128 or LHasSimd256 or LHasSimd512);
  else
    Result := False;
  end;
end;

{$I nextpas.core.simd.cpuinfo.backends.impl.inc}


{$IFDEF SIMD_X86_AVAILABLE}
function GetX86CPUInfo: TX86Features;
var
  cpuInfo: TCPUInfo;
begin
  Result := Default(TX86Features);
  cpuInfo := GetCPUInfo;
  if cpuInfo.Arch = caX86 then
    Result := cpuInfo.X86;
end;
{$ENDIF}

{$IFDEF SIMD_ARM_AVAILABLE}
function GetARMCPUInfo: TARMFeatures;
var
  cpuInfo: TCPUInfo;
begin
  cpuInfo := GetCPUInfo;
  if cpuInfo.Arch = caARM then
    Result := cpuInfo.ARM
  else
    Result := Default(TARMFeatures);
end;
{$ENDIF}

{$IFDEF SIMD_RISCV_AVAILABLE}
function GetRISCVCPUInfo: TRISCVFeatures;
var
  cpuInfo: TCPUInfo;
begin
  Result := Default(TRISCVFeatures);
  cpuInfo := GetCPUInfo;
  if cpuInfo.Arch = caRISCV then
    Result := cpuInfo.RISCV;
end;
{$ENDIF}

{$IFDEF SIMD_LOONGARCH_AVAILABLE}
function GetLoongArchCPUInfo: TLoongArchFeatures;
var
  LCPUInfo: TCPUInfo;
begin
  Result := Default(TLoongArchFeatures);
  LCPUInfo := GetCPUInfo;
  if LCPUInfo.Arch = caLoongArch then
    Result := LCPUInfo.LoongArch;
end;
{$ENDIF}


// Safe reset to force re-detection on next query
procedure ResetCPUInfo;
begin
  // Clear structure
  FillChar(G_CPUInfo, SizeOf(G_CPUInfo), 0);
  atomic_thread_fence(mo_seq_cst);
  // Reset init state
  G_InitState := 0;
end;

// === Quick feature detection ===

function HasSSE2: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasSSE2;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasSSE3: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasSSE3;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasSSSE3: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasSSSE3;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasSSE41: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasSSE41;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasSSE42: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasSSE42;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasAVX2: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasAVX2 and (gfSimd256 in cpuInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasAVX512: Boolean;
{$IFDEF SIMD_X86_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  cpuInfo := GetCPUInfo;
  // AVX-512 requires: AVX512F + OS support (XCR0 bits 5,6,7 for opmask, ZMM_Hi256, Hi16_ZMM)
  Result := (cpuInfo.Arch = caX86) and cpuInfo.X86.HasAVX512F and (gfSimd512 in cpuInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasNEON: Boolean;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caARM) and cpuInfo.ARM.HasNEON;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasSVE: Boolean;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caARM) and cpuInfo.ARM.HasSVE and
            ((gfSimd256 in cpuInfo.GenericUsable) or (gfSimd512 in cpuInfo.GenericUsable));
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasSVE2: Boolean;
{$IFDEF SIMD_ARM_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_ARM_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caARM) and cpuInfo.ARM.HasSVE2 and cpuInfo.ARM.HasSVE and
            ((gfSimd256 in cpuInfo.GenericUsable) or (gfSimd512 in cpuInfo.GenericUsable));
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasRISCVV: Boolean;
{$IFDEF SIMD_RISCV_AVAILABLE}
var
  cpuInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_RISCV_AVAILABLE}
  cpuInfo := GetCPUInfo;
  Result := (cpuInfo.Arch = caRISCV) and cpuInfo.RISCV.HasV;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function HasLASX: Boolean;
{$IFDEF SIMD_LOONGARCH_AVAILABLE}
var
  LCPUInfo: TCPUInfo;
{$ENDIF}
begin
  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caLoongArch) and LCPUInfo.LoongArch.HasLASX and
            (gfSimd256 in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

end.
