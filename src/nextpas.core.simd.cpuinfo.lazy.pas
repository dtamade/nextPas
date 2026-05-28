unit nextpas.core.simd.cpuinfo.lazy;

{$mode objfpc}
{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.simd.cpuinfo.base;

type
  // Lazily loaded CPU information manager.
  TLazyCPUInfo = class
  private
    // Initialization state for each cached section.
    FBasicInitialized: Boolean;
    {$IFDEF SIMD_X86_AVAILABLE}
    FX86BasicInitialized: Boolean;
    {$ENDIF}
    FCacheInitialized: Boolean;
    FExtendedInitialized: Boolean;
    FAVXInitialized: Boolean;
    FAVX512Initialized: Boolean;
    
    // Layered CPU information caches.
    FBasicInfo: record
      Arch: TCPUArch;
      Vendor: string;
      Model: string;
      LogicalCores: Integer;
      PhysicalCores: Integer;
    end;
    
    FCacheInfo: TCacheInfo;
    
    {$IFDEF SIMD_X86_AVAILABLE}
    FX86Basic: record  // Common x86 feature subset
      HasSSE2: Boolean;
      HasSSE3: Boolean;
      HasSSSE3: Boolean;
      HasSSE41: Boolean;
      HasSSE42: Boolean;
    end;
    
    FX86AVX: record  // AVX 相关
      HasAVX: Boolean;
      HasAVX2: Boolean;
      HasFMA: Boolean;
      OSXSAVE: Boolean;
      XCR0: UInt64;
    end;
    
    FX86AVX512: record  // AVX-512 相关
      HasAVX512F: Boolean;
      HasAVX512DQ: Boolean;
      HasAVX512BW: Boolean;
      HasAVX512VL: Boolean;
      HasAVX512VBMI: Boolean;
    end;
    
    FX86Extended: TX86Features;  // 完整特性集
    {$ENDIF}
    
    // Synchronization guard
    FLock: Integer;
    
    // Initialization helpers
    procedure InitBasicInfo;
    procedure InitCacheInfo;
    {$IFDEF SIMD_X86_AVAILABLE}
    procedure InitX86Basic;
    procedure InitX86AVX;
    procedure InitX86AVX512;
    procedure InitX86Extended;
    {$ENDIF}
    
    // 属性访问器
    function GetArch: TCPUArch;
    function GetVendor: string;
    function GetModel: string;
    function GetLogicalCores: Integer;
    function GetCacheInfo: TCacheInfo;
    
    {$IFDEF SIMD_X86_AVAILABLE}
    function GetHasSSE2: Boolean;
    function GetHasAVX2: Boolean;
    function GetHasAVX512F: Boolean;
    function GetX86Features: TX86Features;
    {$ENDIF}
    
  public
    constructor Create;
    
    // Basic information (always cheap to load)
    property Arch: TCPUArch read GetArch;
    property Vendor: string read GetVendor;
    property Model: string read GetModel;
    property LogicalCores: Integer read GetLogicalCores;
    
    // Cache information (loaded on demand)
    property CacheInfo: TCacheInfo read GetCacheInfo;
    
    {$IFDEF SIMD_X86_AVAILABLE}
    // Common x86 features (loaded in layers)
    property HasSSE2: Boolean read GetHasSSE2;
    property HasAVX2: Boolean read GetHasAVX2;
    property HasAVX512F: Boolean read GetHasAVX512F;
    
    // 完整特性集（延迟加载）
    property X86Features: TX86Features read GetX86Features;
    {$ENDIF}
    
    // 预加载指定级别的信息
    procedure PreloadBasic;
    procedure PreloadCommon;  // 包含 SSE/AVX
    procedure PreloadAll;      // Load every cached section
    
    // 重置缓存
    procedure Reset;
    
    // 获取加载统计
    function GetLoadStatistics: string;
  end;

// 全局单例实例
function LazyCPUInfo: TLazyCPUInfo;

// Compatibility entrypoints
function GetCPUInfoLazy: TCPUInfo;
function HasFeatureLazy(f: TGenericFeature): Boolean;

implementation

uses
  Classes, SysUtils
  {$IFDEF DARWIN}
  , nextpas.core.simd.cpuinfo.darwin
  {$ELSE}
    {$IFDEF UNIX}
  , nextpas.core.simd.cpuinfo.unix
    {$ENDIF}
  {$ENDIF}
  {$IFDEF SIMD_X86_AVAILABLE}
  , nextpas.core.simd.cpuinfo.x86
  {$ENDIF}
  {$IFDEF SIMD_ARM_AVAILABLE}
  , nextpas.core.simd.cpuinfo.arm
  {$ENDIF}
  {$IFDEF SIMD_RISCV_AVAILABLE}
  , nextpas.core.simd.cpuinfo.riscv
  {$ENDIF}
  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  , nextpas.core.simd.cpuinfo.loongarch
  {$ENDIF}
  ;

var
  g_LazyCPUInfo: TLazyCPUInfo = nil;
  g_SingletonLock: Integer = 0;

{$IFDEF LINUX}
function ReadFirstLineTrimmedLazy(const aPath: string): string;
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

function ParseSizeToKBLazy(const aText: string): Integer;
begin
  Result := ParseCacheSizeTextToKB(aText);
end;

function IsLinuxCpuDirectoryNameLazy(const aName: string): Boolean;
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

procedure FillCacheInfoFromLinuxSysfsLazy(var aCache: TCacheInfo);
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
      if not IsLinuxCpuDirectoryNameLazy(LCpuRec.Name) then
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
          LTypeText := LowerCase(ReadFirstLineTrimmedLazy(LDir + '/type'));
          LLevelText := ReadFirstLineTrimmedLazy(LDir + '/level');
          LSizeText := ReadFirstLineTrimmedLazy(LDir + '/size');
          LLineSizeText := ReadFirstLineTrimmedLazy(LDir + '/coherency_line_size');

          LLevel := StrToIntDef(LLevelText, 0);
          LSizeKB := ParseSizeToKBLazy(LSizeText);
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

function LazyCPUInfo: TLazyCPUInfo;
var
  OldValue: Integer;
begin
  if g_LazyCPUInfo <> nil then
  begin
    Result := g_LazyCPUInfo;
    Exit;
  end;
  
  // Create the singleton via double-checked locking.
  repeat
    OldValue := InterlockedCompareExchange(g_SingletonLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if g_LazyCPUInfo = nil then
          g_LazyCPUInfo := TLazyCPUInfo.Create;
      finally
        InterlockedExchange(g_SingletonLock, 0);
      end;
      if g_LazyCPUInfo <> nil then
        Break;
    end
    else
    begin
      while (g_LazyCPUInfo = nil) and (g_SingletonLock <> 0) do
        ThreadSwitch;
      if g_LazyCPUInfo <> nil then
        Break;
    end;
  until False;
  
  Result := g_LazyCPUInfo;
end;

{ TLazyCPUInfo }

constructor TLazyCPUInfo.Create;
begin
  inherited;
  FLock := 0;
  FBasicInitialized := False;
  {$IFDEF SIMD_X86_AVAILABLE}
  FX86BasicInitialized := False;
  {$ENDIF}
  FCacheInitialized := False;
  FExtendedInitialized := False;
  FAVXInitialized := False;
  FAVX512Initialized := False;
end;

procedure TLazyCPUInfo.InitBasicInfo;
var
  OldValue: Integer;
  {$IFDEF WINDOWS}
  s: string;
  {$ENDIF}
  {$IFDEF SIMD_ARM_AVAILABLE}
  LARMInfo: TCPUInfo;
  {$ENDIF}
  {$IFDEF SIMD_RISCV_AVAILABLE}
  LRISCVInfo: TCPUInfo;
  {$ENDIF}
  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  LLoongArchInfo: TCPUInfo;
  {$ENDIF}
  {$IFDEF UNIX}
  LPhysCores: LongInt;
  LLogCores: LongInt;
  {$ENDIF}
begin
  if FBasicInitialized then Exit;
  
  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if not FBasicInitialized then
        begin
          try
            // Basic architecture detection.
            {$IFDEF CPUX86_64}
            FBasicInfo.Arch := caX86;
            {$ELSE}
              {$IFDEF CPUI386}
              FBasicInfo.Arch := caX86;
              {$ELSE}
                {$IFDEF CPUAARCH64}
                FBasicInfo.Arch := caARM;
                {$ELSE}
                  {$IFDEF CPUARM}
                  FBasicInfo.Arch := caARM;
                  {$ELSE}
                    {$IFDEF CPURISCV64}
                    FBasicInfo.Arch := caRISCV;
                    {$ELSE}
                    {$IFDEF CPURISCV32}
                    FBasicInfo.Arch := caRISCV;
                    {$ELSE}
                      {$IFDEF CPULOONGARCH64}
                      FBasicInfo.Arch := caLoongArch;
                      {$ELSE}
                      FBasicInfo.Arch := caUnknown;
                      {$ENDIF}
                      {$ENDIF}
                    {$ENDIF}
                  {$ENDIF}
                {$ENDIF}
              {$ENDIF}
            {$ENDIF}
            
            // 厂商和型号（快速检测）
            {$IFDEF SIMD_X86_AVAILABLE}
            FBasicInfo.Vendor := GetVendorString;
            FBasicInfo.Model := GetBrandString;
            {$ENDIF}

            {$IFDEF SIMD_ARM_AVAILABLE}
            if FBasicInfo.Arch = caARM then
            begin
              LARMInfo := Default(TCPUInfo);
              DetectARMVendorAndModel(LARMInfo);
              if LARMInfo.Vendor <> '' then
                FBasicInfo.Vendor := LARMInfo.Vendor
              else
                FBasicInfo.Vendor := 'ARM';
              if LARMInfo.Model <> '' then
                FBasicInfo.Model := LARMInfo.Model
              else
                FBasicInfo.Model := 'Unknown ARM Processor';
            end;
            {$ENDIF}

            {$IFDEF SIMD_RISCV_AVAILABLE}
            if FBasicInfo.Arch = caRISCV then
            begin
              LRISCVInfo := Default(TCPUInfo);
              DetectRISCVVendorAndModel(LRISCVInfo);
              if LRISCVInfo.Vendor <> '' then
                FBasicInfo.Vendor := LRISCVInfo.Vendor
              else
                FBasicInfo.Vendor := 'RISC-V';
              if LRISCVInfo.Model <> '' then
                FBasicInfo.Model := LRISCVInfo.Model
              else
                FBasicInfo.Model := 'RISC-V Processor';
            end;
            {$ENDIF}

            {$IFDEF SIMD_LOONGARCH_AVAILABLE}
            if FBasicInfo.Arch = caLoongArch then
            begin
              LLoongArchInfo := Default(TCPUInfo);
              DetectLoongArchVendorAndModel(LLoongArchInfo);
              if LLoongArchInfo.Vendor <> '' then
                FBasicInfo.Vendor := LLoongArchInfo.Vendor
              else
                FBasicInfo.Vendor := 'LoongArch';
              if LLoongArchInfo.Model <> '' then
                FBasicInfo.Model := LLoongArchInfo.Model
              else
                FBasicInfo.Model := 'Unknown LoongArch Processor';
            end;
            {$ENDIF}

            if FBasicInfo.Vendor = '' then
              FBasicInfo.Vendor := 'Unknown';
            if FBasicInfo.Model = '' then
              FBasicInfo.Model := 'Unknown Processor';

            // Core-count detection.
            {$IFDEF UNIX}
            LPhysCores := 0;
            LLogCores := 0;
            {$ENDIF}
            {$IFDEF WINDOWS}
            s := GetEnvironmentVariable('NUMBER_OF_PROCESSORS');
            FBasicInfo.LogicalCores := StrToIntDef(s, 1);
            {$ELSE}
              {$IFDEF UNIX}
            if DetectCoreCounts(LPhysCores, LLogCores) and (LLogCores > 0) then
              FBasicInfo.LogicalCores := LLogCores
            else
              FBasicInfo.LogicalCores := 1;
              {$ELSE}
            FBasicInfo.LogicalCores := 1;
              {$ENDIF}
            {$ENDIF}
            if FBasicInfo.LogicalCores < 1 then
              FBasicInfo.LogicalCores := 1;

            {$IFDEF UNIX}
            if (LPhysCores > 0) and (LPhysCores <= FBasicInfo.LogicalCores) then
              FBasicInfo.PhysicalCores := LPhysCores
            else
              FBasicInfo.PhysicalCores := FBasicInfo.LogicalCores;
            {$ELSE}
            FBasicInfo.PhysicalCores := FBasicInfo.LogicalCores;
            {$ENDIF}
          except
            FBasicInfo.Arch := caUnknown;
            FBasicInfo.Vendor := 'Unknown';
            FBasicInfo.Model := 'Unknown Processor';
            FBasicInfo.LogicalCores := 1;
            FBasicInfo.PhysicalCores := 1;
          end;
          
          WriteBarrier;
          FBasicInitialized := True;
        end;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end
    else
    begin
      while (not FBasicInitialized) and (FLock <> 0) do
        ThreadSwitch;
      if FBasicInitialized then
        Break;
    end;
  until False;
end;

procedure TLazyCPUInfo.InitCacheInfo;
var
  OldValue: Integer;
  {$IFDEF SIMD_X86_AVAILABLE}
  xc: TX86CacheInfo;
  {$ENDIF}
begin
  if FCacheInitialized then Exit;
  
  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if not FCacheInitialized then
        begin
          try
            {$IFDEF SIMD_X86_AVAILABLE}
            xc := GetX86CacheInfo;
            FCacheInfo.L1DataKB := xc.L1DataCache;
            FCacheInfo.L1InstrKB := xc.L1InstructionCache;
            FCacheInfo.L2KB := xc.L2Cache;
            FCacheInfo.L3KB := xc.L3Cache;
            FCacheInfo.LineSize := xc.CacheLineSize;
            {$ELSE}
            FillChar(FCacheInfo, SizeOf(FCacheInfo), 0);
            {$IFDEF LINUX}
            FillCacheInfoFromLinuxSysfsLazy(FCacheInfo);
            if FCacheInfo.LineSize = 0 then
              FCacheInfo.LineSize := 64;
            {$ENDIF}
            {$ENDIF}
          except
            FillChar(FCacheInfo, SizeOf(FCacheInfo), 0);
            {$IFDEF LINUX}
            FCacheInfo.LineSize := 64;
            {$ENDIF}
          end;
          
          WriteBarrier;
          FCacheInitialized := True;
        end;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end
    else
    begin
      while (not FCacheInitialized) and (FLock <> 0) do
        ThreadSwitch;
      if FCacheInitialized then
        Break;
    end;
  until False;
end;

{$IFDEF SIMD_X86_AVAILABLE}
procedure TLazyCPUInfo.InitX86Basic;
var
  OldValue: Integer;
  eax, ebx, ecx, edx: DWord;
begin
  if FX86BasicInitialized then Exit;
  
  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if not FX86BasicInitialized then
        begin
          try
            // Detect baseline SSE support.
            eax := 0;
            ebx := 0;
            ecx := 0;
            edx := 0;
            CPUID(1, eax, ebx, ecx, edx);
            
            FX86Basic.HasSSE2 := (edx and (1 shl 26)) <> 0;
            FX86Basic.HasSSE3 := (ecx and 1) <> 0;
            FX86Basic.HasSSSE3 := (ecx and (1 shl 9)) <> 0;
            FX86Basic.HasSSE41 := (ecx and (1 shl 19)) <> 0;
            FX86Basic.HasSSE42 := (ecx and (1 shl 20)) <> 0;
          except
            FillChar(FX86Basic, SizeOf(FX86Basic), 0);
          end;
          
          WriteBarrier;
          FX86BasicInitialized := True;
        end;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end
    else
    begin
      while (not FX86BasicInitialized) and (FLock <> 0) do
        ThreadSwitch;
      if FX86BasicInitialized then
        Break;
    end;
  until False;
end;

procedure TLazyCPUInfo.InitX86AVX;
var
  OldValue: Integer;
  eax, ebx, ecx, edx: DWord;
begin
  if FAVXInitialized then Exit;
  
  // Ensure baseline x86 feature information is loaded first.
  InitX86Basic;
  
  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if not FAVXInitialized then
        begin
          try
            FillChar(FX86AVX, SizeOf(FX86AVX), 0);

            // Detect AVX support.
            eax := 0;
            ebx := 0;
            ecx := 0;
            edx := 0;
            CPUID(1, eax, ebx, ecx, edx);
            FX86AVX.HasAVX := (ecx and (1 shl 28)) <> 0;
            FX86AVX.OSXSAVE := (ecx and (1 shl 27)) <> 0;
            FX86AVX.HasFMA := (ecx and (1 shl 12)) <> 0;
            
            // Detect AVX2.
            if FX86AVX.HasAVX and FX86AVX.OSXSAVE then
            begin
              FX86AVX.XCR0 := ReadXCR0;
              if (FX86AVX.XCR0 and 6) = 6 then  // YMM state enabled
              begin
                eax := 0;
                ebx := 0;
                ecx := 0;
                edx := 0;
                CPUIDEX(7, 0, eax, ebx, ecx, edx);
                FX86AVX.HasAVX2 := (ebx and (1 shl 5)) <> 0;
              end;
            end;
          except
            FillChar(FX86AVX, SizeOf(FX86AVX), 0);
          end;
          
          WriteBarrier;
          FAVXInitialized := True;
        end;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end
    else
    begin
      while (not FAVXInitialized) and (FLock <> 0) do
        ThreadSwitch;
      if FAVXInitialized then
        Break;
    end;
  until False;
end;

procedure TLazyCPUInfo.InitX86AVX512;
var
  OldValue: Integer;
  eax, ebx, ecx, edx: DWord;
begin
  if FAVX512Initialized then Exit;
  
  // Ensure AVX information is loaded first.
  InitX86AVX;
  
  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if not FAVX512Initialized then
        begin
          try
            FillChar(FX86AVX512, SizeOf(FX86AVX512), 0);

            // Detect AVX-512 only when the OS has enabled the required state.
            if FX86AVX.OSXSAVE and ((FX86AVX.XCR0 and $E6) = $E6) then
            begin
              eax := 0;
              ebx := 0;
              ecx := 0;
              edx := 0;
              CPUIDEX(7, 0, eax, ebx, ecx, edx);
              
              FX86AVX512.HasAVX512F := (ebx and (1 shl 16)) <> 0;
              FX86AVX512.HasAVX512DQ := (ebx and (1 shl 17)) <> 0;
              FX86AVX512.HasAVX512BW := (ebx and (1 shl 30)) <> 0;
              FX86AVX512.HasAVX512VL := (ebx and (1 shl 31)) <> 0;
              FX86AVX512.HasAVX512VBMI := (ecx and (1 shl 1)) <> 0;
            end;
          except
            FillChar(FX86AVX512, SizeOf(FX86AVX512), 0);
          end;
          
          WriteBarrier;
          FAVX512Initialized := True;
        end;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end
    else
    begin
      while (not FAVX512Initialized) and (FLock <> 0) do
        ThreadSwitch;
      if FAVX512Initialized then
        Break;
    end;
  until False;
end;

procedure TLazyCPUInfo.InitX86Extended;
var
  OldValue: Integer;
begin
  if FExtendedInitialized then Exit;
  
  // 确保所有基本信息已加载
  InitX86Basic;
  InitX86AVX;
  InitX86AVX512;

  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        if not FExtendedInitialized then
        begin
          try
            // 获取完整特性集
            FX86Extended := DetectX86Features;
          except
            FillChar(FX86Extended, SizeOf(FX86Extended), 0);
          end;

          WriteBarrier;
          FExtendedInitialized := True;
        end;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end;

    while (not FExtendedInitialized) and (FLock <> 0) do
      ThreadSwitch;
    if FExtendedInitialized then
      Break;
  until False;
end;
{$ENDIF}

function TLazyCPUInfo.GetArch: TCPUArch;
begin
  InitBasicInfo;
  Result := FBasicInfo.Arch;
end;

function TLazyCPUInfo.GetVendor: string;
begin
  InitBasicInfo;
  Result := FBasicInfo.Vendor;
end;

function TLazyCPUInfo.GetModel: string;
begin
  InitBasicInfo;
  Result := FBasicInfo.Model;
end;

function TLazyCPUInfo.GetLogicalCores: Integer;
begin
  InitBasicInfo;
  Result := FBasicInfo.LogicalCores;
end;

function TLazyCPUInfo.GetCacheInfo: TCacheInfo;
begin
  InitCacheInfo;
  Result := FCacheInfo;
end;

{$IFDEF SIMD_X86_AVAILABLE}
function TLazyCPUInfo.GetHasSSE2: Boolean;
begin
  InitX86Basic;
  Result := FX86Basic.HasSSE2;
end;

function TLazyCPUInfo.GetHasAVX2: Boolean;
begin
  InitX86AVX;
  Result := FX86AVX.HasAVX2;
end;

function TLazyCPUInfo.GetHasAVX512F: Boolean;
begin
  InitX86AVX512;
  Result := FX86AVX512.HasAVX512F;
end;

function TLazyCPUInfo.GetX86Features: TX86Features;
begin
  InitX86Extended;
  Result := FX86Extended;
end;
{$ENDIF}

procedure TLazyCPUInfo.PreloadBasic;
begin
  InitBasicInfo;
end;

procedure TLazyCPUInfo.PreloadCommon;
begin
  InitBasicInfo;
  {$IFDEF SIMD_X86_AVAILABLE}
  InitX86Basic;
  InitX86AVX;
  {$ENDIF}
end;

procedure TLazyCPUInfo.PreloadAll;
begin
  InitBasicInfo;
  InitCacheInfo;
  {$IFDEF SIMD_X86_AVAILABLE}
  InitX86Basic;
  InitX86AVX;
  InitX86AVX512;
  InitX86Extended;
  {$ENDIF}
end;

procedure TLazyCPUInfo.Reset;
var
  OldValue: Integer;
begin
  repeat
    OldValue := InterlockedCompareExchange(FLock, 1, 0);
    if OldValue = 0 then
    begin
      try
        FBasicInitialized := False;
        {$IFDEF SIMD_X86_AVAILABLE}
        FX86BasicInitialized := False;
        {$ENDIF}
        FCacheInitialized := False;
        FExtendedInitialized := False;
        FAVXInitialized := False;
        FAVX512Initialized := False;
      finally
        InterlockedExchange(FLock, 0);
      end;
      Break;
    end;

    while FLock <> 0 do
      ThreadSwitch;
  until False;
end;

function TLazyCPUInfo.GetLoadStatistics: string;
var
  Stats: TStringList;
begin
  Stats := TStringList.Create;
  try
    Stats.Add('=== Lazy Load Statistics ===');
    Stats.Add('Basic Info: ' + BoolToStr(FBasicInitialized, 'Loaded', 'Not Loaded'));
    Stats.Add('Cache Info: ' + BoolToStr(FCacheInitialized, 'Loaded', 'Not Loaded'));
    {$IFDEF SIMD_X86_AVAILABLE}
    Stats.Add('X86 Basic: ' + BoolToStr(FX86BasicInitialized, 'Loaded', 'Not Loaded'));
    Stats.Add('X86 AVX: ' + BoolToStr(FAVXInitialized, 'Loaded', 'Not Loaded'));
    Stats.Add('X86 AVX-512: ' + BoolToStr(FAVX512Initialized, 'Loaded', 'Not Loaded'));
    Stats.Add('X86 Extended: ' + BoolToStr(FExtendedInitialized, 'Loaded', 'Not Loaded'));
    {$ENDIF}
    Result := Stats.Text;
  finally
    Stats.Free;
  end;
end;

// Compatibility entrypoint implementations

{$IFDEF SIMD_X86_AVAILABLE}
function X86XCR0EnablesAVXLazy(const aXCR0: UInt64): Boolean; inline;
begin
  Result := ((aXCR0 and (UInt64(1) shl 1)) <> 0) and
            ((aXCR0 and (UInt64(1) shl 2)) <> 0);
end;

function X86XCR0EnablesAVX512Lazy(const aXCR0: UInt64): Boolean; inline;
begin
  Result := X86XCR0EnablesAVXLazy(aXCR0) and
            ((aXCR0 and (UInt64(1) shl 5)) <> 0) and
            ((aXCR0 and (UInt64(1) shl 6)) <> 0) and
            ((aXCR0 and (UInt64(1) shl 7)) <> 0);
end;
{$ENDIF}

function GetCPUInfoLazy: TCPUInfo;
var
  LLazy: TLazyCPUInfo;
  {$IFDEF SIMD_X86_AVAILABLE}
  LAVXSupportedByOS: Boolean;
  {$ENDIF}
begin
  LLazy := LazyCPUInfo;
  
  Result := Default(TCPUInfo);
  Result.Arch := LLazy.Arch;
  Result.Vendor := LLazy.Vendor;
  Result.Model := LLazy.Model;
  Result.LogicalCores := LLazy.LogicalCores;
  Result.PhysicalCores := LLazy.FBasicInfo.PhysicalCores;
  Result.Cache := LLazy.CacheInfo;
  Result.GenericRaw := [];
  Result.GenericUsable := [];
  
  {$IFDEF SIMD_X86_AVAILABLE}
  Result.X86 := LLazy.X86Features;
  LLazy.InitX86AVX;
  Result.OSXSAVE := LLazy.FX86AVX.OSXSAVE;
  Result.XCR0 := LLazy.FX86AVX.XCR0;
  LAVXSupportedByOS := nextpas.core.simd.cpuinfo.x86.IsAVXSupportedByOS;

  if Result.X86.HasSSE2 then Include(Result.GenericRaw, gfSimd128);
  if Result.X86.HasAVX or Result.X86.HasAVX2 then Include(Result.GenericRaw, gfSimd256);
  if Result.X86.HasAVX512F then Include(Result.GenericRaw, gfSimd512);
  if Result.X86.HasAES then Include(Result.GenericRaw, gfAES);
  if Result.X86.HasFMA then Include(Result.GenericRaw, gfFMA);
  if Result.X86.HasSHA then Include(Result.GenericRaw, gfSHA);

  if Result.X86.HasSSE2 then Include(Result.GenericUsable, gfSimd128);
  if (Result.X86.HasAVX or Result.X86.HasAVX2) and
     LAVXSupportedByOS and
     X86XCR0EnablesAVXLazy(Result.XCR0) then
    Include(Result.GenericUsable, gfSimd256);
  if Result.X86.HasAVX512F and
     LAVXSupportedByOS and
     X86XCR0EnablesAVX512Lazy(Result.XCR0) then
    Include(Result.GenericUsable, gfSimd512);
  if Result.X86.HasAES then Include(Result.GenericUsable, gfAES);
  if Result.X86.HasFMA and
     LAVXSupportedByOS and
     X86XCR0EnablesAVXLazy(Result.XCR0) then
    Include(Result.GenericUsable, gfFMA);
  if Result.X86.HasSHA then Include(Result.GenericUsable, gfSHA);
  {$ENDIF}

  {$IFDEF SIMD_ARM_AVAILABLE}
  if Result.Arch = caARM then
  begin
    Result.ARM := DetectARMFeatures;
    if Result.ARM.HasNEON then Include(Result.GenericRaw, gfSimd128);
    if Result.ARM.HasSVE then
    begin
      Include(Result.GenericRaw, gfSimd256);
      Include(Result.GenericRaw, gfSimd512);
    end;
    if Result.ARM.HasCrypto then
    begin
      Include(Result.GenericRaw, gfAES);
      Include(Result.GenericRaw, gfSHA);
    end;
    Result.GenericUsable := Result.GenericRaw;
  end;
  {$ENDIF}

  {$IFDEF SIMD_RISCV_AVAILABLE}
  if Result.Arch = caRISCV then
  begin
    Result.RISCV := DetectRISCVFeatures;
    if Result.RISCV.HasV then
    begin
      Include(Result.GenericRaw, gfSimd128);
      Include(Result.GenericRaw, gfSimd256);
      Include(Result.GenericRaw, gfSimd512);
    end;
    Result.GenericUsable := Result.GenericRaw;
  end;
  {$ENDIF}

  {$IFDEF SIMD_LOONGARCH_AVAILABLE}
  if Result.Arch = caLoongArch then
  begin
    Result.LoongArch := DetectLoongArchFeatures;
    if Result.LoongArch.HasLASX then
      Include(Result.GenericRaw, gfSimd256);
    Result.GenericUsable := Result.GenericRaw;
  end;
  {$ENDIF}
end;

function HasFeatureLazy(f: TGenericFeature): Boolean;
var
  LCPUInfo: TCPUInfo;
begin
  LCPUInfo := GetCPUInfoLazy;
  Result := f in LCPUInfo.GenericUsable;
end;

finalization
  if g_LazyCPUInfo <> nil then
  begin
    g_LazyCPUInfo.Free;
    g_LazyCPUInfo := nil;
  end;

end.


