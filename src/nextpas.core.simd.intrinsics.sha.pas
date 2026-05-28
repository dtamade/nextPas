unit nextpas.core.simd.intrinsics.sha;
// Disposition: STABLE — foundational intrinsics


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status:
  - This unit intentionally does NOT provide hardware-accurate SHA extension semantics.
  - By default, public APIs raise ENotSupportedException to avoid silent misuse.
  - Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS to opt-in placeholder behavior.
  - Even with NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS defined, placeholder semantics remain opt-in across hosts.
  - This unit intentionally does not add the x86-only runtime fail-close used by other hold x86 families.
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

function sha_sha1msg1_epu32(const a, b: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha1msg1_epu32');
  Result.m128i_u32[0] := a.m128i_u32[0] xor b.m128i_u32[0];
  Result.m128i_u32[1] := a.m128i_u32[1] xor b.m128i_u32[1];
  Result.m128i_u32[2] := a.m128i_u32[2] xor b.m128i_u32[2];
  Result.m128i_u32[3] := a.m128i_u32[3] xor b.m128i_u32[3];
end;

function sha_sha1msg2_epu32(const a, b: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha1msg2_epu32');
  Result.m128i_u32[0] := a.m128i_u32[0] + b.m128i_u32[0];
  Result.m128i_u32[1] := a.m128i_u32[1] + b.m128i_u32[1];
  Result.m128i_u32[2] := a.m128i_u32[2] + b.m128i_u32[2];
  Result.m128i_u32[3] := a.m128i_u32[3] + b.m128i_u32[3];
end;

function sha_sha1nexte_epu32(const a, b: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha1nexte_epu32');
  Result := a;
  Result.m128i_u32[0] := Result.m128i_u32[0] + b.m128i_u32[3];
end;

function sha_sha1rnds4_epu32(const a, b: TM128; func: Byte): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha1rnds4_epu32');
  Result.m128i_u32[0] := a.m128i_u32[0] + b.m128i_u32[0] + func;
  Result.m128i_u32[1] := a.m128i_u32[1] + b.m128i_u32[1] + func;
  Result.m128i_u32[2] := a.m128i_u32[2] + b.m128i_u32[2] + func;
  Result.m128i_u32[3] := a.m128i_u32[3] + b.m128i_u32[3] + func;
end;

function sha_sha256msg1_epu32(const a, b: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha256msg1_epu32');
  Result.m128i_u32[0] := a.m128i_u32[0] + b.m128i_u32[0];
  Result.m128i_u32[1] := a.m128i_u32[1] + b.m128i_u32[1];
  Result.m128i_u32[2] := a.m128i_u32[2] + b.m128i_u32[2];
  Result.m128i_u32[3] := a.m128i_u32[3] + b.m128i_u32[3];
end;

function sha_sha256msg2_epu32(const a, b: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha256msg2_epu32');
  Result.m128i_u32[0] := a.m128i_u32[0] xor b.m128i_u32[0];
  Result.m128i_u32[1] := a.m128i_u32[1] xor b.m128i_u32[1];
  Result.m128i_u32[2] := a.m128i_u32[2] xor b.m128i_u32[2];
  Result.m128i_u32[3] := a.m128i_u32[3] xor b.m128i_u32[3];
end;

function sha_sha256rnds2_epu32(const a, b, k: TM128): TM128;
begin
  EnsureExperimentalIntrinsicsEnabled('sha_sha256rnds2_epu32');
  Result.m128i_u32[0] := a.m128i_u32[0] + b.m128i_u32[0] + k.m128i_u32[0];
  Result.m128i_u32[1] := a.m128i_u32[1] + b.m128i_u32[1] + k.m128i_u32[1];
  Result.m128i_u32[2] := a.m128i_u32[2] + b.m128i_u32[2] + k.m128i_u32[2];
  Result.m128i_u32[3] := a.m128i_u32[3] + b.m128i_u32[3] + k.m128i_u32[3];
end;

end.
