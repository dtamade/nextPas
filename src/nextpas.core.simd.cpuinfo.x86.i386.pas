unit nextpas.core.simd.cpuinfo.x86.i386;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$ASMMODE INTEL}

interface

uses
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo.x86.base;

// i386 platform implementation that exports the shared x86 facade API.

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

function HasCPUID: Boolean; assembler; nostackframe;
asm
  pushfd
  pop eax
  mov ecx, eax
  xor eax, $200000
  push eax
  popfd
  pushfd
  pop eax
  xor eax, ecx
  shr eax, 21
  and eax, 1
  push ecx
  popfd
end;

function ActualCPUID(leaf: DWord): TCPUIDResult;
var
  result_eax, result_ebx, result_ecx, result_edx: DWord;
begin
  asm
    push ebx
    push edi
    mov eax, leaf
    cpuid
    mov result_eax, eax
    mov result_ebx, ebx
    mov result_ecx, ecx
    mov result_edx, edx
    pop edi
    pop ebx
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
    push ebx
    push edi
    mov eax, leaf
    mov ecx, ecx_in
    cpuid
    mov result_eax, eax
    mov result_ebx, ebx
    mov result_ecx, ecx
    mov result_edx, edx
    pop edi
    pop ebx
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

  if not HasCPUID then
  begin
    Result := Default(TX86Features);
    Exit;
  end;

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
  eax, ebx, ecx, edx: DWord;
  vendorString: array[0..12] of AnsiChar;
  brandString: array[0..48] of AnsiChar;
begin
  if not HasCPUID then
  begin
    cpuInfo.Vendor := 'Unknown x86';
    cpuInfo.Model := 'Unknown x86 Processor';
    Exit;
  end;

  eax := 0; ebx := 0; ecx := 0; edx := 0;
  vendorString[0] := #0;
  brandString[0] := #0;
  FillChar(vendorString, SizeOf(vendorString), 0);
  FillChar(brandString, SizeOf(brandString), 0);

  CPUID(0, eax, ebx, ecx, edx);
  Move(ebx, vendorString[0], 4);
  Move(edx, vendorString[4], 4);
  Move(ecx, vendorString[8], 4);
  vendorString[12] := #0;
  cpuInfo.Vendor := string(vendorString);

  eax := 0; ebx := 0; ecx := 0; edx := 0;
  CPUID($80000000, eax, ebx, ecx, edx);
  if eax >= $80000004 then
  begin
    CPUID($80000002, eax, ebx, ecx, edx);
    Move(eax, brandString[0], 4);
    Move(ebx, brandString[4], 4);
    Move(ecx, brandString[8], 4);
    Move(edx, brandString[12], 4);
    CPUID($80000003, eax, ebx, ecx, edx);
    Move(eax, brandString[16], 4);
    Move(ebx, brandString[20], 4);
    Move(ecx, brandString[24], 4);
    Move(edx, brandString[28], 4);
    CPUID($80000004, eax, ebx, ecx, edx);
    Move(eax, brandString[32], 4);
    Move(ebx, brandString[36], 4);
    Move(ecx, brandString[40], 4);
    Move(edx, brandString[44], 4);
    cpuInfo.Model := string(brandString);
  end
  else
  begin
    cpuInfo.Model := cpuInfo.Vendor + ' Processor';
  end;
  if cpuInfo.Model = '' then
    cpuInfo.Model := cpuInfo.Vendor + ' Processor';
end;

function GetX86CacheInfo: TX86CacheInfo;
var
  eax, ebx, ecx, edx: DWord;
begin
  Result := Default(TX86CacheInfo);
  if not HasCPUID then Exit;

  eax := 0; ebx := 0; ecx := 0; edx := 0;
  CPUID(0, eax, ebx, ecx, edx);
  if eax >= 2 then
  begin
    eax := 0; ebx := 0; ecx := 0; edx := 0;
    CPUID(2, eax, ebx, ecx, edx);
    Result.L1DataCache := 32;
    Result.L1InstructionCache := 32;
    Result.L2Cache := 256;
    Result.L3Cache := 0;
  end;
  eax := 0; ebx := 0; ecx := 0; edx := 0;
  CPUID($80000000, eax, ebx, ecx, edx);
  if eax >= $80000006 then
  begin
    eax := 0; ebx := 0; ecx := 0; edx := 0;
    CPUID($80000006, eax, ebx, ecx, edx);
    Result.L2Cache := (ecx shr 16) and $FFFF;
    Result.L3Cache := ((edx shr 18) and $3FFF) * 512;
  end;
end;

end.




