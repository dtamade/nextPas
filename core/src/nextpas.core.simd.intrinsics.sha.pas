unit nextpas.core.simd.intrinsics.sha;
// Disposition: STABLE — foundational intrinsics


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.intrinsics.base;

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

{$IFDEF CPUX86_64}
{$ASMMODE ATT}

function sha_sha1msg1_epu32(const a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha1msg1 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
end;

function sha_sha1msg2_epu32(const a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha1msg2 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
end;

function sha_sha1nexte_epu32(const a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha1nexte %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
end;
function sha_sha1rnds4_epu32(const a, b: TM128; func: Byte): TM128; assembler; nostackframe;
asm
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
.Lfunc0:
  sha1rnds4 $0, %xmm1, %xmm0
  jmp     .Ldone
.Lfunc1:
  sha1rnds4 $1, %xmm1, %xmm0
  jmp     .Ldone
.Lfunc2:
  sha1rnds4 $2, %xmm1, %xmm0
.Ldone:
  movdqu  %xmm0, (%rcx)
end;

function sha_sha256msg1_epu32(const a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha256msg1 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
end;

function sha_sha256msg2_epu32(const a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  sha256msg2 %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
end;

function sha_sha256rnds2_epu32(const a, b, k: TM128): TM128; assembler; nostackframe;
asm
  movdqu  (%rdx), %xmm0
  movdqu  (%rdi), %xmm1
  movdqu  (%rsi), %xmm2
  sha256rnds2 %xmm2, %xmm1
  movdqu  %xmm1, (%rcx)
end;

{$ELSE}

// Fallback: scalar simulation for non-x86_64 platforms
// These raise runtime error if called without SHA-NI support

function sha_sha1msg1_epu32(const a, b: TM128): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

function sha_sha1msg2_epu32(const a, b: TM128): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

function sha_sha1nexte_epu32(const a, b: TM128): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

function sha_sha1rnds4_epu32(const a, b: TM128; func: Byte): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

function sha_sha256msg1_epu32(const a, b: TM128): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

function sha_sha256msg2_epu32(const a, b: TM128): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

function sha_sha256rnds2_epu32(const a, b, k: TM128): TM128;
begin
  RunError(217);
  Result := Default(TM128);
end;

{$ENDIF}

end.
