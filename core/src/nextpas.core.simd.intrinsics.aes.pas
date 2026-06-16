unit nextpas.core.simd.intrinsics.aes;
// Disposition: EXPERIMENTAL — opt-in AES intrinsics frontier


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status:
  - Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS to opt in.
  - AES round/decrypt, AESIMC, and AESKEYGENASSIST standard-rcon helpers
    have guarded CPUX86_64 + AES-NI hardware paths.
  - aes_aeskeygenassist_si128 supports the AES key schedule rcon subset
    $00/$01/$02/$04/$08/$10/$20/$40/$80/$1B/$36 and fail-closes other Byte values.
  - This unit should remain opt-in across hosts.
  - By default, public APIs RunError(217) to avoid silent misuse.
}

// AES round operations
function aes_aesenc_si128(const data, round_key: TM128): TM128;
function aes_aesenclast_si128(const data, round_key: TM128): TM128;

// AES inverse round operations
function aes_aesdec_si128(const data, round_key: TM128): TM128;
function aes_aesdeclast_si128(const data, round_key: TM128): TM128;

// AES key schedule helper
function aes_aeskeygenassist_si128(const key: TM128; rcon: Byte): TM128;

// AES inverse mix columns
function aes_aesimc_si128(const data: TM128): TM128;

implementation

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base;

function simd_has_aes: Boolean; inline;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and LCPUInfo.X86.HasAES and
    (gfAES in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure EnsureExperimentalIntrinsicsEnabled(const aFunctionName: string); inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  RunError(217);
  {$ELSE}
  if aFunctionName = '' then
    ;
  {$ENDIF}
end;

procedure FailCloseForcedNonX86AESForTests; inline;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_FORCE_NONX86_AES_FAILCLOSE}
  // test-only non-x86 AES fail-close hook: lets x86 hosts exercise the guard path.
  RunError(217);
  {$ENDIF}
end;

procedure EnsureAESENCIntrinsicsAvailable; inline;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesenc_si128');
  {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  FailCloseForcedNonX86AESForTests;
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_aes then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

procedure EnsureAESENCLASTIntrinsicsAvailable; inline;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesenclast_si128');
  {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  FailCloseForcedNonX86AESForTests;
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_aes then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

procedure EnsureAESDECIntrinsicsAvailable; inline;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesdec_si128');
  {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  FailCloseForcedNonX86AESForTests;
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_aes then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

procedure EnsureAESDECLASTIntrinsicsAvailable; inline;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesdeclast_si128');
  {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  FailCloseForcedNonX86AESForTests;
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_aes then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

procedure EnsureAESKEYGENASSISTIntrinsicsAvailable; inline;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aeskeygenassist_si128');
  {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  FailCloseForcedNonX86AESForTests;
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_aes then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

procedure EnsureAESIMCIntrinsicsAvailable; inline;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesimc_si128');
  {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  FailCloseForcedNonX86AESForTests;
  {$IFNDEF CPUX86_64}
  RunError(217);
  {$ELSE}
  if not simd_has_aes then
    RunError(217);
  {$ENDIF}
  {$ENDIF}
end;

function IsAESKEYGENASSISTRconSupported(const rcon: Byte): Boolean; inline;
begin
  case rcon of
    $00, $01, $02, $04, $08, $10, $20, $40, $80, $1B, $36:
      Result := True;
  else
    Result := False;
  end;
end;

{$IFDEF CPUX86_64}
{$ASMMODE ATT}

procedure RawAESENCSi128(constref data, round_key: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  aesenc  %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  aesenc  %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawAESENCLASTSi128(constref data, round_key: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu      (%rcx), %xmm0
  movdqu      (%rdx), %xmm1
  aesenclast  %xmm1, %xmm0
  movdqu      %xmm0, (%r8)
  {$ELSE}
  movdqu      (%rdi), %xmm0
  movdqu      (%rsi), %xmm1
  aesenclast  %xmm1, %xmm0
  movdqu      %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawAESDECSi128(constref data, round_key: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  movdqu  (%rdx), %xmm1
  aesdec  %xmm1, %xmm0
  movdqu  %xmm0, (%r8)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  movdqu  (%rsi), %xmm1
  aesdec  %xmm1, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawAESDECLASTSi128(constref data, round_key: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu      (%rcx), %xmm0
  movdqu      (%rdx), %xmm1
  aesdeclast  %xmm1, %xmm0
  movdqu      %xmm0, (%r8)
  {$ELSE}
  movdqu      (%rdi), %xmm0
  movdqu      (%rsi), %xmm1
  aesdeclast  %xmm1, %xmm0
  movdqu      %xmm0, (%rdx)
  {$ENDIF}
end;

procedure RawAESKEYGENASSISTSi128(constref key: TM128; rcon: Byte; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  cmpb    $0x00, %dl
  je      .Laeskeygenassist00
  cmpb    $0x01, %dl
  je      .Laeskeygenassist01
  cmpb    $0x02, %dl
  je      .Laeskeygenassist02
  cmpb    $0x04, %dl
  je      .Laeskeygenassist04
  cmpb    $0x08, %dl
  je      .Laeskeygenassist08
  cmpb    $0x10, %dl
  je      .Laeskeygenassist10
  cmpb    $0x20, %dl
  je      .Laeskeygenassist20
  cmpb    $0x40, %dl
  je      .Laeskeygenassist40
  cmpb    $0x80, %dl
  je      .Laeskeygenassist80
  cmpb    $0x1b, %dl
  je      .Laeskeygenassist1b
  jmp     .Laeskeygenassist36
  {$ELSE}
  movdqu  (%rdi), %xmm0
  cmpb    $0x00, %sil
  je      .Laeskeygenassist00
  cmpb    $0x01, %sil
  je      .Laeskeygenassist01
  cmpb    $0x02, %sil
  je      .Laeskeygenassist02
  cmpb    $0x04, %sil
  je      .Laeskeygenassist04
  cmpb    $0x08, %sil
  je      .Laeskeygenassist08
  cmpb    $0x10, %sil
  je      .Laeskeygenassist10
  cmpb    $0x20, %sil
  je      .Laeskeygenassist20
  cmpb    $0x40, %sil
  je      .Laeskeygenassist40
  cmpb    $0x80, %sil
  je      .Laeskeygenassist80
  cmpb    $0x1b, %sil
  je      .Laeskeygenassist1b
  jmp     .Laeskeygenassist36
  {$ENDIF}
.Laeskeygenassist00:
  aeskeygenassist $0x00, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist01:
  aeskeygenassist $0x01, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist02:
  aeskeygenassist $0x02, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist04:
  aeskeygenassist $0x04, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist08:
  aeskeygenassist $0x08, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist10:
  aeskeygenassist $0x10, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist20:
  aeskeygenassist $0x20, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist40:
  aeskeygenassist $0x40, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist80:
  aeskeygenassist $0x80, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist1b:
  aeskeygenassist $0x1b, %xmm0, %xmm1
  jmp     .Laeskeygenassistdone
.Laeskeygenassist36:
  aeskeygenassist $0x36, %xmm0, %xmm1
.Laeskeygenassistdone:
  {$IFDEF WINDOWS}
  movdqu  %xmm1, (%r8)
  {$ELSE}
  movdqu  %xmm1, (%rdx)
  {$ENDIF}
end;

procedure RawAESIMCSi128(constref data: TM128; var outValue: TM128); assembler; nostackframe;
asm
  {$IFDEF WINDOWS}
  movdqu  (%rcx), %xmm0
  aesimc  %xmm0, %xmm0
  movdqu  %xmm0, (%rdx)
  {$ELSE}
  movdqu  (%rdi), %xmm0
  aesimc  %xmm0, %xmm0
  movdqu  %xmm0, (%rsi)
  {$ENDIF}
end;

{$ENDIF}

function aes_aesenc_si128(const data, round_key: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureAESENCIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawAESENCSi128(data, round_key, Result);
  {$ENDIF}
end;

function aes_aesenclast_si128(const data, round_key: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureAESENCLASTIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawAESENCLASTSi128(data, round_key, Result);
  {$ENDIF}
end;

function aes_aesdec_si128(const data, round_key: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureAESDECIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawAESDECSi128(data, round_key, Result);
  {$ENDIF}
end;

function aes_aesdeclast_si128(const data, round_key: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureAESDECLASTIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawAESDECLASTSi128(data, round_key, Result);
  {$ENDIF}
end;

function aes_aeskeygenassist_si128(const key: TM128; rcon: Byte): TM128;
begin
  Result := Default(TM128);
  EnsureAESKEYGENASSISTIntrinsicsAvailable;
  if not IsAESKEYGENASSISTRconSupported(rcon) then
    RunError(217);
  {$IFDEF CPUX86_64}
  RawAESKEYGENASSISTSi128(key, rcon, Result);
  {$ENDIF}
end;

function aes_aesimc_si128(const data: TM128): TM128;
begin
  Result := Default(TM128);
  EnsureAESIMCIntrinsicsAvailable;
  {$IFDEF CPUX86_64}
  RawAESIMCSi128(data, Result);
  {$ENDIF}
end;

end.
