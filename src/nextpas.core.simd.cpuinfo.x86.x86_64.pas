unit nextpas.core.simd.cpuinfo.x86.x86_64;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$ASMMODE INTEL}

interface

uses
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo.x86.base;

// x86_64 platform implementation that exports the shared x86 facade API.

function HasCPUID: Boolean;
procedure CPUID(EAX: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord);
procedure CPUIDEX(EAX, ECX_In: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord);
function ReadXCR0: UInt64;

function DetectX86Features: TX86Features;
procedure DetectX86VendorAndModel(var cpuInfo: TCPUInfo);
function GetX86CacheInfo: TX86CacheInfo;
function IsAVXSupportedByOS: Boolean;

implementation

type
  TCPUIDResult = array[0..3] of DWord;

function HasCPUID: Boolean;
begin
  // CPUID is always available on x86-64
  Result := True;
end;

function ActualCPUID(leaf: DWord): TCPUIDResult;
var
  result_eax, result_ebx, result_ecx, result_edx: DWord;
begin
  asm
    push rbx
    mov eax, leaf
    cpuid
    mov result_eax, eax
    mov result_ebx, ebx
    mov result_ecx, ecx
    mov result_edx, edx
    pop rbx
  end;
  Result[0] := result_eax;
  Result[1] := result_ebx;
  Result[2] := result_ecx;
  Result[3] := result_edx;
end;

procedure CPUID(EAX: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord);
var
  r: TCPUIDResult;
begin
  r := ActualCPUID(EAX);
  EAX_Out := r[0];
  EBX_Out := r[1];
  ECX_Out := r[2];
  EDX_Out := r[3];
end;

function ActualCPUIDEX(leaf, ecx_in: DWord): TCPUIDResult;
var
  result_eax, result_ebx, result_ecx, result_edx: DWord;
begin
  asm
    push rbx
    mov eax, leaf
    mov ecx, ecx_in
    cpuid
    mov result_eax, eax
    mov result_ebx, ebx
    mov result_ecx, ecx
    mov result_edx, edx
    pop rbx
  end;
  Result[0] := result_eax;
  Result[1] := result_ebx;
  Result[2] := result_ecx;
  Result[3] := result_edx;
end;

procedure CPUIDEX(EAX, ECX_In: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord);
var
  r: TCPUIDResult;
begin
  r := ActualCPUIDEX(EAX, ECX_In);
  EAX_Out := r[0];
  EBX_Out := r[1];
  ECX_Out := r[2];
  EDX_Out := r[3];
end;

function ReadXCR0: UInt64;
var
  result_eax, result_edx: DWord;
begin
  try
    asm
      mov ecx, 0
      xgetbv
      mov result_eax, eax
      mov result_edx, edx
    end;
    Result := (UInt64(result_edx) shl 32) or result_eax;
  except
    Result := 0;
  end;
end;

function IsAVXSupportedByOS: Boolean;
var
  eax, ebx, ecx, edx: DWord;
  xcr0: UInt64;
begin
  Result := False;
  eax := 0; ebx := 0; ecx := 0; edx := 0;
  CPUID(1, eax, ebx, ecx, edx);
  if (ecx and (1 shl 27)) = 0 then Exit; // OSXSAVE
  xcr0 := ReadXCR0;
  Result := XCR0HasAVX(xcr0);
end;

function DetectX86Features: TX86Features;
var
  LEax: DWord;
  LEbx: DWord;
  LEcx: DWord;
  LEdx: DWord;
  LMaxLeaf: DWord;
  LMaxExtLeaf: DWord;
  LXCR0: UInt64;
  LLeaf1: TX86CPUIDRegs;
  LLeaf7: TX86CPUIDRegs;
  LExtLeaf1: TX86CPUIDRegs;
begin
  LEax := 0;
  LEbx := 0;
  LEcx := 0;
  LEdx := 0;
  LMaxLeaf := 0;
  LMaxExtLeaf := 0;
  LLeaf1 := MakeX86CPUIDRegs(0, 0, 0, 0);
  LLeaf7 := MakeX86CPUIDRegs(0, 0, 0, 0);
  LExtLeaf1 := MakeX86CPUIDRegs(0, 0, 0, 0);

  CPUID(0, LMaxLeaf, LEbx, LEcx, LEdx);
  if LMaxLeaf >= 1 then
  begin
    LEax := 0;
    LEbx := 0;
    LEcx := 0;
    LEdx := 0;
    CPUID(1, LEax, LEbx, LEcx, LEdx);
    LLeaf1 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
    if (LLeaf1.ECX and (1 shl 27)) <> 0 then
      LXCR0 := ReadXCR0
    else
      LXCR0 := 0;
  end
  else
    LXCR0 := 0;

  if LMaxLeaf >= 7 then
  begin
    LEax := 0;
    LEbx := 0;
    LEcx := 0;
    LEdx := 0;
    CPUIDEX(7, 0, LEax, LEbx, LEcx, LEdx);
    LLeaf7 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  end;

  LEbx := 0;
  LEcx := 0;
  LEdx := 0;
  CPUID($80000000, LMaxExtLeaf, LEbx, LEcx, LEdx);
  if LMaxExtLeaf >= $80000001 then
  begin
    LEax := 0;
    LEbx := 0;
    LEcx := 0;
    LEdx := 0;
    CPUID($80000001, LEax, LEbx, LEcx, LEdx);
    LExtLeaf1 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  end;

  Result := X86FeaturesFromCPUID(LMaxLeaf, LMaxExtLeaf, LLeaf1, LLeaf7, LExtLeaf1, LXCR0);
end;

procedure DetectX86VendorAndModel(var cpuInfo: TCPUInfo);
var
  LEax: DWord;
  LEbx: DWord;
  LEcx: DWord;
  LEdx: DWord;
  LMaxExtLeaf: DWord;
  LLeaf0: TX86CPUIDRegs;
  LLeaf2: TX86CPUIDRegs;
  LLeaf3: TX86CPUIDRegs;
  LLeaf4: TX86CPUIDRegs;
begin
  LEax := 0;
  LEbx := 0;
  LEcx := 0;
  LEdx := 0;
  LMaxExtLeaf := 0;
  LLeaf2 := MakeX86CPUIDRegs(0, 0, 0, 0);
  LLeaf3 := MakeX86CPUIDRegs(0, 0, 0, 0);
  LLeaf4 := MakeX86CPUIDRegs(0, 0, 0, 0);

  CPUID(0, LEax, LEbx, LEcx, LEdx);
  LLeaf0 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  cpuInfo.Vendor := X86VendorStringFromLeaf0(LLeaf0);

  LEax := 0;
  LEbx := 0;
  LEcx := 0;
  LEdx := 0;
  CPUID(1, LEax, LEbx, LEcx, LEdx);
  cpuInfo.OSXSAVE := (LEcx and (1 shl 27)) <> 0;
  if cpuInfo.OSXSAVE then
    cpuInfo.XCR0 := ReadXCR0
  else
    cpuInfo.XCR0 := 0;

  LEax := 0;
  LEbx := 0;
  LEcx := 0;
  LEdx := 0;
  CPUID($80000000, LMaxExtLeaf, LEbx, LEcx, LEdx);
  if LMaxExtLeaf >= $80000002 then
  begin
    LEax := 0;
    LEbx := 0;
    LEcx := 0;
    LEdx := 0;
    CPUID($80000002, LEax, LEbx, LEcx, LEdx);
    LLeaf2 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  end;
  if LMaxExtLeaf >= $80000003 then
  begin
    LEax := 0;
    LEbx := 0;
    LEcx := 0;
    LEdx := 0;
    CPUID($80000003, LEax, LEbx, LEcx, LEdx);
    LLeaf3 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  end;
  if LMaxExtLeaf >= $80000004 then
  begin
    LEax := 0;
    LEbx := 0;
    LEcx := 0;
    LEdx := 0;
    CPUID($80000004, LEax, LEbx, LEcx, LEdx);
    LLeaf4 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  end;

  cpuInfo.Model := X86BrandStringFromExtendedLeaves(cpuInfo.Vendor, LMaxExtLeaf, LLeaf2, LLeaf3, LLeaf4);
  if cpuInfo.Model = '' then
    cpuInfo.Model := cpuInfo.Vendor + ' Processor';
end;

function GetX86CacheInfo: TX86CacheInfo;
var
  eax, ebx, ecx, edx: DWord;
  maxLeaf: DWord;
  subleaf: Integer;
  cacheType, cacheLevel, cacheSets: DWord;
  cacheLineSize, cachePartitions, cacheWays: DWord;
  cacheSize: DWord;
begin
  Result := Default(TX86CacheInfo);

  eax := 0; ebx := 0; ecx := 0; edx := 0;
  maxLeaf := 0;
  
  // First, try to get cache info from leaf 4 (Deterministic Cache Parameters)
  CPUID(0, maxLeaf, ebx, ecx, edx);
  if maxLeaf >= 4 then
  begin
    subleaf := 0;
    repeat
      eax := 0; ebx := 0; ecx := 0; edx := 0;
      CPUIDEX(4, subleaf, eax, ebx, ecx, edx);
      cacheType := eax and $1F;
      
      if cacheType <> 0 then  // 0 = No more caches
      begin
        cacheLevel := (eax shr 5) and $07;
        cacheLineSize := (ebx and $FFF) + 1;
        cachePartitions := ((ebx shr 12) and $3FF) + 1;
        cacheWays := ((ebx shr 22) and $3FF) + 1;
        cacheSets := ecx + 1;
        
        // Calculate cache size in KB
        cacheSize := (cacheWays * cachePartitions * cacheLineSize * cacheSets) div 1024;
        
        case cacheLevel of
          1: // L1 cache
            begin
              if cacheType = 1 then  // Data cache
                Result.L1DataCache := cacheSize
              else if cacheType = 2 then  // Instruction cache
                Result.L1InstructionCache := cacheSize;
            end;
          2: // L2 cache
            Result.L2Cache := cacheSize;
          3: // L3 cache
            Result.L3Cache := cacheSize;
        end;
      end;
      
      Inc(subleaf);
    until (cacheType = 0) or (subleaf > 10);  // Safety limit
    
    // Get cache line size from the first valid cache
    if Result.CacheLineSize = 0 then
    begin
      eax := 0; ebx := 0; ecx := 0; edx := 0;
      CPUIDEX(4, 0, eax, ebx, ecx, edx);
      if (eax and $1F) <> 0 then
        Result.CacheLineSize := (ebx and $FFF) + 1;
    end;
  end;
  
  // Fallback to extended CPUID leaves if leaf 4 didn't work or as supplement
  ebx := 0; ecx := 0; edx := 0;
  CPUID($80000000, maxLeaf, ebx, ecx, edx);
  
  // Get L1 cache info from leaf $80000005 if available and not already set
  if (maxLeaf >= $80000005) and (Result.L1DataCache = 0) then
  begin
    eax := 0; ebx := 0; ecx := 0; edx := 0;
    CPUID($80000005, eax, ebx, ecx, edx);
    if Result.L1DataCache = 0 then
      Result.L1DataCache := (ecx shr 24) and $FF;  // L1 D-cache size in KB
    if Result.L1InstructionCache = 0 then  
      Result.L1InstructionCache := (edx shr 24) and $FF;  // L1 I-cache size in KB
    if Result.CacheLineSize = 0 then
      Result.CacheLineSize := ecx and $FF;  // L1 D-cache line size
  end;
  
  // Get L2/L3 cache info from leaf $80000006
  if maxLeaf >= $80000006 then
  begin
    eax := 0; ebx := 0; ecx := 0; edx := 0;
    CPUID($80000006, eax, ebx, ecx, edx);
    if Result.L2Cache = 0 then
      Result.L2Cache := (ecx shr 16) and $FFFF;  // L2 cache size in KB
    if Result.L3Cache = 0 then
    begin
      // L3 cache size: bits 31-18 contain the size in 512KB units
      Result.L3Cache := ((edx shr 18) and $3FFF) * 512;  // Convert to KB
    end;
    if Result.CacheLineSize = 0 then
      Result.CacheLineSize := ecx and $FF;  // L2 cache line size
  end;
  
  // Default values if detection failed
  if Result.CacheLineSize = 0 then
    Result.CacheLineSize := 64;  // Common default
end;

end.



