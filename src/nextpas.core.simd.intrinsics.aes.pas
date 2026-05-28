unit nextpas.core.simd.intrinsics.aes;
// Disposition: STABLE — foundational intrinsics

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status:
  - This unit intentionally does NOT provide hardware-accurate AES-NI semantics.
  - By default, public APIs raise ENotSupportedException to avoid silent misuse.
  - Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS to opt-in placeholder behavior.
  - Even with NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS defined, placeholder semantics remain opt-in across hosts.
  - This unit intentionally does not add the x86-only runtime fail-close used by other hold x86 families.
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
  SysUtils;

procedure EnsureExperimentalIntrinsicsEnabled(const aFunctionName: string); inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  raise ENotSupportedException.CreateFmt(
    '%s is experimental placeholder semantics. Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS to opt in.',
    [aFunctionName]
  );
  {$ELSE}
  if aFunctionName = '' then
    ;
  {$ENDIF}
end;

function aes_aesenc_si128(const data, round_key: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesenc_si128');
  Result.m128i_u64[0] := data.m128i_u64[0] xor round_key.m128i_u64[0];
  Result.m128i_u64[1] := data.m128i_u64[1] xor round_key.m128i_u64[1];
end;

function aes_aesenclast_si128(const data, round_key: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesenclast_si128');
  Result.m128i_u64[0] := data.m128i_u64[0] xor round_key.m128i_u64[0];
  Result.m128i_u64[1] := data.m128i_u64[1] xor round_key.m128i_u64[1];
end;

function aes_aesdec_si128(const data, round_key: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesdec_si128');
  Result.m128i_u64[0] := data.m128i_u64[0] xor round_key.m128i_u64[0];
  Result.m128i_u64[1] := data.m128i_u64[1] xor round_key.m128i_u64[1];
end;

function aes_aesdeclast_si128(const data, round_key: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesdeclast_si128');
  Result.m128i_u64[0] := data.m128i_u64[0] xor round_key.m128i_u64[0];
  Result.m128i_u64[1] := data.m128i_u64[1] xor round_key.m128i_u64[1];
end;

function aes_aeskeygenassist_si128(const key: TM128; rcon: Byte): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aeskeygenassist_si128');
  Result := key;
  Result.m128i_u8[0] := Result.m128i_u8[0] xor rcon;
end;

function aes_aesimc_si128(const data: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('aes_aesimc_si128');
  Result := data;
end;

end.
