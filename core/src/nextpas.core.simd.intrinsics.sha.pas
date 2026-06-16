unit nextpas.core.simd.intrinsics.sha;
// Disposition: STABLE — foundational intrinsics


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status:
  - Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS for hardware-only SHA-NI bring-up.
  - Public wrappers fail-close unless CPUX86_64 and usable SHA support are both true.
  - This unit should remain opt-in across hosts.
  - Current tests are smoke-only availability checks, not SHA semantic vectors.
}

// SHA-1 intrinsics
function sha_sha1msg1_epu32(const a, b: TM128): TM128;
function sha_sha1msg2_epu32(const a, b: TM128): TM128;
function sha_sha1nexte_epu32(const a, b: TM128): TM128;
function sha_sha1rnds4_epu32(const a, b: TM128; func: Byte): TM128;

// SHA-256 intrinsics
function sha_sha256msg1_epu32(const a, b: TM128): TM128;
function sha_sha256msg2_epu32(const a, b: TM128): TM128;
function sha_sha256rnds2_epu32(const a, b, k: TM128): TM128;

implementation

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base;

function simd_has_sha: Boolean; inline;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and LCPUInfo.X86.HasSHA and
    (gfSHA in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure EnsureExperimentalSHAIntrinsicsAvailable; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  RunError(217);
  {$ELSE}
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_sha then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

{$IFDEF CPUX86_64}
{$ASMMODE ATT}

procedure RawSHA1Msg1Epu32(constref a, b: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  sha1msg1 %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha1msg1 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawSHA1Msg2Epu32(constref a, b: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  sha1msg2 %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha1msg2 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawSHA1NextEEpu32(constref a, b: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  sha1nexte %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha1nexte %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawSHA1Rnds4Epu32(constref a, b: TM128; func: Byte; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  // sha1rnds4 requires immediate; dispatch by func value
  cmpb    $0, %r8b
  je      .Lfunc0
  cmpb    $1, %r8b
  je      .Lfunc1
  cmpb    $2, %r8b
  je      .Lfunc2
  // default: func=3
  sha1rnds4 $3, %xmm1, %xmm0
  jmp     .Ldone
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  // sha1rnds4 requires immediate; dispatch by func value
  cmpb    $0, %dl
  je      .Lfunc0
  cmpb    $1, %dl
  je      .Lfunc1
  cmpb    $2, %dl
  je      .Lfunc2
  // default: func=3
  sha1rnds4 $3, %xmm1, %xmm0
  jmp     .Ldone
  {$ENDIF}
.Lfunc0:
  sha1rnds4 $0, %xmm1, %xmm0
  jmp     .Ldone
.Lfunc1:
  sha1rnds4 $1, %xmm1, %xmm0
  jmp     .Ldone
.Lfunc2:
  sha1rnds4 $2, %xmm1, %xmm0
.Ldone:
  {$IFDEF WINDOWS}
  movdqu  %xmm0, (%r9)
  {$ELSE}
  movdqu  %xmm0, (%rcx)
  {$ENDIF}
end;

procedure RawSHA256Msg1Epu32(constref a, b: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  sha256msg1 %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha256msg1 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawSHA256Msg2Epu32(constref a, b: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  sha256msg2 %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha256msg2 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawSHA256Rnds2Epu32(constref a, b, k: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%r8), %xmm0
  movdqu  (%rcx), %xmm1
  movdqu  (%rdx), %xmm2
  sha256rnds2 %xmm2, %xmm1
  movdqu  %xmm1, (%r9)
  {$ELSE}
  movdqu  (%rdx), %xmm0
  movdqu  (%rdi), %xmm1
  movdqu  (%rsi), %xmm2
  sha256rnds2 %xmm2, %xmm1
  movdqu  %xmm1, (%rcx)
  {$ENDIF}
end;

{$ENDIF}

function sha_sha1msg1_epu32(const a, b: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA1Msg1Epu32(a, b, Result);
  {$ENDIF}
end;

function sha_sha1msg2_epu32(const a, b: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA1Msg2Epu32(a, b, Result);
  {$ENDIF}
end;

function sha_sha1nexte_epu32(const a, b: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA1NextEEpu32(a, b, Result);
  {$ENDIF}
end;

function sha_sha1rnds4_epu32(const a, b: TM128; func: Byte): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA1Rnds4Epu32(a, b, func, Result);
  {$ENDIF}
end;

function sha_sha256msg1_epu32(const a, b: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA256Msg1Epu32(a, b, Result);
  {$ENDIF}
end;

function sha_sha256msg2_epu32(const a, b: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA256Msg2Epu32(a, b, Result);
  {$ENDIF}
end;

function sha_sha256rnds2_epu32(const a, b, k: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureExperimentalSHAIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawSHA256Rnds2Epu32(a, b, k, Result);
  {$ENDIF}
end;

end.
