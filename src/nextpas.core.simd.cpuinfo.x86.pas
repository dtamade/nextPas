unit nextpas.core.simd.cpuinfo.x86;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo.x86.base;

{$IFDEF SIMD_X86_AVAILABLE}

// x86/x64 CPU feature detection facade
// Provides unified interface for x86 CPUID functionality

function HasCPUID: Boolean; inline;
procedure CPUID(EAX: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord); inline;
procedure CPUIDEX(EAX, ECX_In: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord); inline;
function ReadXCR0: UInt64; inline;

function DetectX86Features: TX86Features; inline;
procedure DetectX86VendorAndModel(var cpuInfo: TCPUInfo); inline;
function GetX86CacheInfo: TX86CacheInfo; inline;
function IsAVXSupportedByOS: Boolean; inline;

// Backward-compat convenience wrappers (used by legacy tests)
function HasSSE: Boolean; inline;
function HasSSE2: Boolean; inline;
function HasAVX: Boolean; inline;
function HasAVX2: Boolean; inline;
function GetVendorString: string; inline;
function GetBrandString: string; inline;

{$ENDIF SIMD_X86_AVAILABLE}

implementation

{$IFDEF SIMD_X86_AVAILABLE}

uses
  {$IF defined(CPUX86_64)}
  nextpas.core.simd.cpuinfo.x86.x86_64
  {$ELSEIF defined(CPUI386)}
  nextpas.core.simd.cpuinfo.x86.i386
  {$ENDIF};

// Forward calls to architecture-specific implementation

function HasCPUID: Boolean; inline;
begin
  {$IF defined(CPUX86_64)}
  Result := nextpas.core.simd.cpuinfo.x86.x86_64.HasCPUID;
  {$ELSEIF DEFINED(CPUI386)}
  Result := nextpas.core.simd.cpuinfo.x86.i386.HasCPUID;
  {$ENDIF}
end;

procedure CPUID(EAX: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord); inline;
begin
  {$IF defined(CPUX86_64)}
  nextpas.core.simd.cpuinfo.x86.x86_64.CPUID(EAX, EAX_Out, EBX_Out, ECX_Out, EDX_Out);
  {$ELSEIF DEFINED(CPUI386)}
  nextpas.core.simd.cpuinfo.x86.i386.CPUID(EAX, EAX_Out, EBX_Out, ECX_Out, EDX_Out);
  {$ENDIF}
end;

procedure CPUIDEX(EAX, ECX_In: DWord; var EAX_Out, EBX_Out, ECX_Out, EDX_Out: DWord); inline;
begin
  {$IF defined(CPUX86_64)}
  nextpas.core.simd.cpuinfo.x86.x86_64.CPUIDEX(EAX, ECX_In, EAX_Out, EBX_Out, ECX_Out, EDX_Out);
  {$ELSEIF DEFINED(CPUI386)}
  nextpas.core.simd.cpuinfo.x86.i386.CPUIDEX(EAX, ECX_In, EAX_Out, EBX_Out, ECX_Out, EDX_Out);
  {$ENDIF}
end;

function ReadXCR0: UInt64; inline;
begin
  {$IF defined(CPUX86_64)}
  Result := nextpas.core.simd.cpuinfo.x86.x86_64.ReadXCR0;
  {$ELSEIF DEFINED(CPUI386)}
  Result := nextpas.core.simd.cpuinfo.x86.i386.ReadXCR0;
  {$ENDIF}
end;

function DetectX86Features: TX86Features; inline;
begin
  {$IF defined(CPUX86_64)}
  Result := nextpas.core.simd.cpuinfo.x86.x86_64.DetectX86Features;
  {$ELSEIF DEFINED(CPUI386)}
  Result := nextpas.core.simd.cpuinfo.x86.i386.DetectX86Features;
  {$ENDIF}
end;

procedure DetectX86VendorAndModel(var cpuInfo: TCPUInfo); inline;
begin
  {$IF defined(CPUX86_64)}
  nextpas.core.simd.cpuinfo.x86.x86_64.DetectX86VendorAndModel(cpuInfo);
  {$ELSEIF DEFINED(CPUI386)}
  nextpas.core.simd.cpuinfo.x86.i386.DetectX86VendorAndModel(cpuInfo);
  {$ENDIF}
end;

function GetX86CacheInfo: TX86CacheInfo; inline;
begin
  {$IF defined(CPUX86_64)}
  Result := nextpas.core.simd.cpuinfo.x86.x86_64.GetX86CacheInfo;
  {$ELSEIF DEFINED(CPUI386)}
  Result := nextpas.core.simd.cpuinfo.x86.i386.GetX86CacheInfo;
  {$ENDIF}
end;

function IsAVXSupportedByOS: Boolean; inline;
begin
  {$IF defined(CPUX86_64)}
  Result := nextpas.core.simd.cpuinfo.x86.x86_64.IsAVXSupportedByOS;
  {$ELSEIF DEFINED(CPUI386)}
  Result := nextpas.core.simd.cpuinfo.x86.i386.IsAVXSupportedByOS;
  {$ENDIF}
end;

// Backward-compat wrappers
function HasSSE: Boolean; inline;
var F: TX86Features;
begin
  F := DetectX86Features;
  Result := F.HasSSE;
end;

function HasSSE2: Boolean; inline;
var F: TX86Features;
begin
  F := DetectX86Features;
  Result := F.HasSSE2;
end;

function HasAVX: Boolean; inline;
var F: TX86Features;
begin
  F := DetectX86Features;
  Result := F.HasAVX;
end;

function HasAVX2: Boolean; inline;
var F: TX86Features;
begin
  F := DetectX86Features;
  Result := F.HasAVX2;
end;

function GetVendorString: string; inline;
var
  LEax: DWord;
  LEbx: DWord;
  LEcx: DWord;
  LEdx: DWord;
  LLeaf0: TX86CPUIDRegs;
begin
  LEax := 0;
  LEbx := 0;
  LEcx := 0;
  LEdx := 0;

  CPUID(0, LEax, LEbx, LEcx, LEdx);
  LLeaf0 := MakeX86CPUIDRegs(LEax, LEbx, LEcx, LEdx);
  Result := X86VendorStringFromLeaf0(LLeaf0);
end;

function GetBrandString: string; inline;
var
  LEax: DWord;
  LEbx: DWord;
  LEcx: DWord;
  LEdx: DWord;
  LMaxExtLeaf: DWord;
  LLeaf2: TX86CPUIDRegs;
  LLeaf3: TX86CPUIDRegs;
  LLeaf4: TX86CPUIDRegs;
  LVendor: string;
begin
  LEax := 0;
  LEbx := 0;
  LEcx := 0;
  LEdx := 0;
  LMaxExtLeaf := 0;
  LLeaf2 := MakeX86CPUIDRegs(0, 0, 0, 0);
  LLeaf3 := MakeX86CPUIDRegs(0, 0, 0, 0);
  LLeaf4 := MakeX86CPUIDRegs(0, 0, 0, 0);

  LVendor := GetVendorString;
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

  Result := X86BrandStringFromExtendedLeaves(LVendor, LMaxExtLeaf, LLeaf2, LLeaf3, LLeaf4);
end;

{$ENDIF SIMD_X86_AVAILABLE}

end.
