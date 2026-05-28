unit nextpas.core.simd.cpuinfo.x86.base;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.cpuinfo.base;

{ Shared x86 helpers.
  - Holds pure Pascal CPUID bit normalization and OS gating logic.
  - Architecture-specific CPUID/XGETBV entrypoints come from x86.i386/x86.x86_64.
}

// Helper gates for AVX / AVX-512 OS enablement via XCR0.
function XCR0HasAVX(xcr0: UInt64): Boolean; inline;
function XCR0HasAVX512(xcr0: UInt64): Boolean; inline;

type
  TX86CPUIDRegs = record
    EAX: DWord;
    EBX: DWord;
    ECX: DWord;
    EDX: DWord;
  end;

function MakeX86CPUIDRegs(aEAX, aEBX, aECX, aEDX: DWord): TX86CPUIDRegs; inline;
function X86VendorStringFromLeaf0(constref aLeaf0: TX86CPUIDRegs): string;
function X86BrandStringFromExtendedLeaves(const aVendor: string; aMaxExtLeaf: DWord;
  constref aLeaf80000002, aLeaf80000003, aLeaf80000004: TX86CPUIDRegs): string;
function X86FeaturesFromCPUID(aMaxLeaf, aMaxExtLeaf: DWord;
  constref aLeaf1, aLeaf7, aExtLeaf1: TX86CPUIDRegs; aXCR0: UInt64): TX86Features;

implementation

function MakeX86CPUIDRegs(aEAX, aEBX, aECX, aEDX: DWord): TX86CPUIDRegs; inline;
begin
  Result.EAX := aEAX;
  Result.EBX := aEBX;
  Result.ECX := aECX;
  Result.EDX := aEDX;
end;

function XCR0HasAVX(xcr0: UInt64): Boolean; inline;
begin
  Result := (xcr0 and $06) = $06;
end;

function XCR0HasAVX512(xcr0: UInt64): Boolean; inline;
begin
  Result := (xcr0 and $00000000000000E6) = $00000000000000E6;
end;

function X86VendorStringFromLeaf0(constref aLeaf0: TX86CPUIDRegs): string;
var
  LLeaf0: TX86CPUIDRegs;
  LResult: string;
begin
  LLeaf0 := aLeaf0;
  LResult := '';
  SetLength(LResult, 12);
  Move(LLeaf0.EBX, LResult[1], 4);
  Move(LLeaf0.EDX, LResult[5], 4);
  Move(LLeaf0.ECX, LResult[9], 4);
  Result := LResult;
end;

function X86BrandStringFromExtendedLeaves(const aVendor: string; aMaxExtLeaf: DWord;
  constref aLeaf80000002, aLeaf80000003, aLeaf80000004: TX86CPUIDRegs): string;
var
  LLeaf2: TX86CPUIDRegs;
  LLeaf3: TX86CPUIDRegs;
  LLeaf4: TX86CPUIDRegs;
  LResult: string;
begin
  if aMaxExtLeaf < $80000004 then
    Exit(aVendor + ' Processor');

  LLeaf2 := aLeaf80000002;
  LLeaf3 := aLeaf80000003;
  LLeaf4 := aLeaf80000004;
  LResult := '';
  SetLength(LResult, 48);
  Move(LLeaf2.EAX, LResult[1], 4);
  Move(LLeaf2.EBX, LResult[5], 4);
  Move(LLeaf2.ECX, LResult[9], 4);
  Move(LLeaf2.EDX, LResult[13], 4);
  Move(LLeaf3.EAX, LResult[17], 4);
  Move(LLeaf3.EBX, LResult[21], 4);
  Move(LLeaf3.ECX, LResult[25], 4);
  Move(LLeaf3.EDX, LResult[29], 4);
  Move(LLeaf4.EAX, LResult[33], 4);
  Move(LLeaf4.EBX, LResult[37], 4);
  Move(LLeaf4.ECX, LResult[41], 4);
  Move(LLeaf4.EDX, LResult[45], 4);
  Result := nextpas.core.simd.cpuinfo.base.RemoveChars(LResult, #0);
  if Result = '' then
    Result := aVendor + ' Processor';
end;

function X86FeaturesFromCPUID(aMaxLeaf, aMaxExtLeaf: DWord;
  constref aLeaf1, aLeaf7, aExtLeaf1: TX86CPUIDRegs; aXCR0: UInt64): TX86Features;
var
  LOSXSAVE: Boolean;
  LXCR0: UInt64;
begin
  Result := Default(TX86Features);
  if aMaxLeaf < 1 then
    Exit;

  Result.HasMMX := (aLeaf1.EDX and (1 shl 23)) <> 0;
  Result.HasSSE := (aLeaf1.EDX and (1 shl 25)) <> 0;
  Result.HasSSE2 := (aLeaf1.EDX and (1 shl 26)) <> 0;
  Result.HasSSE3 := (aLeaf1.ECX and (1 shl 0)) <> 0;
  Result.HasPCLMULQDQ := (aLeaf1.ECX and (1 shl 1)) <> 0;
  Result.HasSSSE3 := (aLeaf1.ECX and (1 shl 9)) <> 0;
  Result.HasFMA := (aLeaf1.ECX and (1 shl 12)) <> 0;
  Result.HasSSE41 := (aLeaf1.ECX and (1 shl 19)) <> 0;
  Result.HasSSE42 := (aLeaf1.ECX and (1 shl 20)) <> 0;
  Result.HasPOPCNT := (aLeaf1.ECX and (1 shl 23)) <> 0;
  Result.HasAES := (aLeaf1.ECX and (1 shl 25)) <> 0;
  Result.HasAVX := (aLeaf1.ECX and (1 shl 28)) <> 0;
  Result.HasF16C := (aLeaf1.ECX and (1 shl 29)) <> 0;
  Result.HasRDRAND := (aLeaf1.ECX and (1 shl 30)) <> 0;

  LOSXSAVE := (aLeaf1.ECX and (1 shl 27)) <> 0;
  if LOSXSAVE then
    LXCR0 := aXCR0
  else
    LXCR0 := 0;

  if Result.HasAVX then
    Result.HasAVX := XCR0HasAVX(LXCR0);

  if aMaxLeaf >= 7 then
  begin
    Result.HasBMI1 := (aLeaf7.EBX and (1 shl 3)) <> 0;
    Result.HasAVX2 := (aLeaf7.EBX and (1 shl 5)) <> 0;
    Result.HasBMI2 := (aLeaf7.EBX and (1 shl 8)) <> 0;
    Result.HasAVX512F := (aLeaf7.EBX and (1 shl 16)) <> 0;
    Result.HasAVX512DQ := (aLeaf7.EBX and (1 shl 17)) <> 0;
    Result.HasAVX512BW := (aLeaf7.EBX and (1 shl 30)) <> 0;
    Result.HasAVX512VL := (aLeaf7.EBX and (1 shl 31)) <> 0;
    Result.HasAVX512VBMI := (aLeaf7.ECX and (1 shl 1)) <> 0;
    Result.HasSHA := (aLeaf7.EBX and (1 shl 29)) <> 0;
    Result.HasRDSEED := (aLeaf7.ECX and (1 shl 18)) <> 0;

    if not Result.HasAVX then
    begin
      Result.HasAVX2 := False;
      Result.HasFMA := False;
    end;

    if not Result.HasAVX2 then
    begin
      Result.HasAVX512F := False;
      Result.HasAVX512DQ := False;
      Result.HasAVX512BW := False;
      Result.HasAVX512VL := False;
      Result.HasAVX512VBMI := False;
    end;

    if not XCR0HasAVX512(LXCR0) then
    begin
      Result.HasAVX512F := False;
      Result.HasAVX512DQ := False;
      Result.HasAVX512BW := False;
      Result.HasAVX512VL := False;
      Result.HasAVX512VBMI := False;
    end;
  end;

  if aMaxExtLeaf >= $80000001 then
    Result.HasFMA4 := (aExtLeaf1.ECX and (1 shl 16)) <> 0;
end;

end.
