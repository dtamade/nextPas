program nextpas.core.simd.cpuinfo_dump;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.cpuinfo.base;

type
  TCPUIDResult = record
    eax, ebx, ecx, edx: UInt32;
  end;

function CPUID_Call(leaf, subleaf: UInt32): TCPUIDResult;
var
  ra, rb, rc, rd: UInt32;
begin
  ra := 0; rb := 0; rc := 0; rd := 0;
  asm
    push rbx
    mov eax, leaf
    mov ecx, subleaf
    cpuid
    mov ra, eax
    mov rb, ebx
    mov rc, ecx
    mov rd, edx
    pop rbx
  end;
  Result.eax := ra;
  Result.ebx := rb;
  Result.ecx := rc;
  Result.edx := rd;
end;

function XGETBV_Call: UInt32;
var
  ra: UInt32;
begin
  ra := 0;
  asm
    push rbx
    xor ecx, ecx
    db $0F, $01, $D0
    mov ra, eax
    pop rbx
  end;
  Result := ra;
end;

function YN(b: Boolean): string;
begin
  if b then Result := 'YES' else Result := 'no';
end;

var
  r: TCPUIDResult;
  xcr0: UInt32;
  osxsave: Boolean;
  vendor: array[0..12] of Char;

begin
  WriteLn('+--------------------------------------------------+');
  WriteLn('|  nextpas.core.simd CPU Feature Diagnostic Tool     |');
  WriteLn('+--------------------------------------------------+');
  WriteLn('');
  {$IFDEF WINDOWS}
  WriteLn('Platform: Windows x86_64');
  {$ELSE}
  WriteLn('Platform: Linux x86_64');
  {$ENDIF}
  WriteLn('');

  WriteLn('=== Raw CPUID Dump ===');
  WriteLn('');

  // Leaf 0: Vendor
  r := CPUID_Call(0, 0);
  Move(r.ebx, vendor[0], 4);
  Move(r.edx, vendor[4], 4);
  Move(r.ecx, vendor[8], 4);
  vendor[12] := #0;
  WriteLn('--- CPUID.0 (Vendor) ---');
  WriteLn('  Vendor: ', vendor);
  WriteLn('  Max leaf: ', r.eax);
  WriteLn('');

  // Leaf 1: Features
  r := CPUID_Call(1, 0);
  WriteLn('--- CPUID.1 (Processor Info + Features) ---');
  WriteLn('  Family:   ', ((r.eax shr 8) and $F) + ((r.eax shr 20) and $FF));
  WriteLn('  Model:    ', ((r.eax shr 4) and $F) + (((r.eax shr 16) and $F) shl 4));
  WriteLn('  Stepping: ', r.eax and $F);
  WriteLn('  ECX:');
  WriteLn('    SSE3:      ', YN((r.ecx and (1 shl 0)) <> 0));
  WriteLn('    SSSE3:     ', YN((r.ecx and (1 shl 9)) <> 0));
  WriteLn('    FMA3:      ', YN((r.ecx and (1 shl 12)) <> 0));
  WriteLn('    SSE4.1:    ', YN((r.ecx and (1 shl 19)) <> 0));
  WriteLn('    SSE4.2:    ', YN((r.ecx and (1 shl 20)) <> 0));
  WriteLn('    POPCNT:    ', YN((r.ecx and (1 shl 23)) <> 0));
  WriteLn('    AES-NI:    ', YN((r.ecx and (1 shl 25)) <> 0));
  WriteLn('    OSXSAVE:   ', YN((r.ecx and (1 shl 27)) <> 0));
  WriteLn('    AVX:       ', YN((r.ecx and (1 shl 28)) <> 0));
  WriteLn('    F16C:      ', YN((r.ecx and (1 shl 29)) <> 0));
  WriteLn('  EDX:');
  WriteLn('    SSE:       ', YN((r.edx and (1 shl 25)) <> 0));
  WriteLn('    SSE2:      ', YN((r.edx and (1 shl 26)) <> 0));
  osxsave := (r.ecx and (1 shl 27)) <> 0;
  WriteLn('');

  // Leaf 7: Extended features
  r := CPUID_Call(7, 0);
  WriteLn('--- CPUID.7.0 (Extended Features) ---');
  WriteLn('  EBX:');
  WriteLn('    BMI1:        ', YN((r.ebx and (1 shl 3)) <> 0));
  WriteLn('    AVX2:        ', YN((r.ebx and (1 shl 5)) <> 0));
  WriteLn('    BMI2:        ', YN((r.ebx and (1 shl 8)) <> 0));
  WriteLn('    AVX-512F:    ', YN((r.ebx and (1 shl 16)) <> 0));
  WriteLn('    AVX-512DQ:   ', YN((r.ebx and (1 shl 17)) <> 0));
  WriteLn('    AVX-512IFMA: ', YN((r.ebx and (1 shl 21)) <> 0));
  WriteLn('    AVX-512CD:   ', YN((r.ebx and (1 shl 28)) <> 0));
  WriteLn('    AVX-512BW:   ', YN((r.ebx and (1 shl 30)) <> 0));
  WriteLn('    AVX-512VL:   ', YN((r.ebx and (1 shl 31)) <> 0));
  WriteLn('  ECX:');
  WriteLn('    AVX-512VBMI:   ', YN((r.ecx and (1 shl 1)) <> 0));
  WriteLn('    AVX-512VBMI2:  ', YN((r.ecx and (1 shl 6)) <> 0));
  WriteLn('    AVX-512VNNI:   ', YN((r.ecx and (1 shl 11)) <> 0));
  WriteLn('    AVX-512BITALG: ', YN((r.ecx and (1 shl 12)) <> 0));
  WriteLn('    AVX-512VPOPCNT:', YN((r.ecx and (1 shl 14)) <> 0));
  WriteLn('  EDX:');
  WriteLn('    AVX-512VP2INTERSECT:', YN((r.edx and (1 shl 8)) <> 0));
  WriteLn('    AVX-512FP16:   ', YN((r.edx and (1 shl 23)) <> 0));
  WriteLn('');

  // Leaf 7, subleaf 1
  r := CPUID_Call(7, 1);
  WriteLn('--- CPUID.7.1 (Extended Features sub1) ---');
  WriteLn('  EAX:');
  WriteLn('    AVX-VNNI:    ', YN((r.eax and (1 shl 4)) <> 0));
  WriteLn('    AVX-512BF16: ', YN((r.eax and (1 shl 5)) <> 0));
  WriteLn('    AVX-IFMA:    ', YN((r.eax and (1 shl 23)) <> 0));
  WriteLn('');

  // XCR0
  WriteLn('--- XCR0 (OS XSAVE State) ---');
  if not osxsave then
  begin
    WriteLn('  OSXSAVE not supported - cannot read XCR0');
    xcr0 := 0;
  end
  else
  begin
    xcr0 := XGETBV_Call;
    WriteLn('  XCR0 = 0x', HexStr(xcr0, 8));
    WriteLn('    bit 0 (x87):           ', YN((xcr0 and 1) <> 0));
    WriteLn('    bit 1 (SSE/XMM):       ', YN((xcr0 and 2) <> 0));
    WriteLn('    bit 2 (AVX/YMM):       ', YN((xcr0 and 4) <> 0));
    WriteLn('    bit 5 (AVX-512 opmask):', YN((xcr0 and 32) <> 0));
    WriteLn('    bit 6 (AVX-512 ZMM_Hi):', YN((xcr0 and 64) <> 0));
    WriteLn('    bit 7 (AVX-512 Hi16):  ', YN((xcr0 and 128) <> 0));
  end;
  WriteLn('');

  // Verdict
  WriteLn('=== AVX-512 Verdict ===');
  r := CPUID_Call(7, 0);
  if (r.ebx and (1 shl 16)) = 0 then
    WriteLn('  CPU: AVX-512F NOT supported (CPUID.7.EBX bit 16 = 0)')
  else
  begin
    WriteLn('  CPU: AVX-512F supported (CPUID.7.EBX bit 16 = 1)');
    if not osxsave then
      WriteLn('  OS:  Cannot check (OSXSAVE not available)')
    else if (xcr0 and $E0) = $E0 then
      WriteLn('  OS:  AVX-512 state enabled (XCR0 bits 5,6,7 = 1,1,1)')
    else
      WriteLn('  OS:  AVX-512 state NOT enabled (XCR0 bits 5,6,7 = ',
        (xcr0 shr 5) and 1, ',', (xcr0 shr 6) and 1, ',', (xcr0 shr 7) and 1, ')');
  end;
  WriteLn('');

  WriteLn('=== Framework Backend Status ===');
  WriteLn('  Active:  ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('  Scalar:  ', YN(IsBackendRegistered(sbScalar)));
  WriteLn('  SSE2:    ', YN(IsBackendRegistered(sbSSE2)));
  WriteLn('  AVX2:    ', YN(IsBackendRegistered(sbAVX2)));
  WriteLn('  AVX-512: ', YN(IsBackendRegistered(sbAVX512)));
  WriteLn('');
  WriteLn('=== Done ===');
end.
