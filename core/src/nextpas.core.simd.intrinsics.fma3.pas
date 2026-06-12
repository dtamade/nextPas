unit nextpas.core.simd.intrinsics.fma3;
// Disposition: STABLE — low-level intrinsics, used by dispatch backends

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.fma3 ===
  Placeholder FMA3 intrinsics surface for isolated experimental bring-up.
  FMA3 adds fused multiply-add and fused multiply-subtract forms.
  Highlights:
  - fused multiply-add (a * b + c)
  - fused multiply-subtract (a * b - c)
  - fused negative multiply-add
  - fused negative multiply-subtract
  - single-precision and double-precision variants
  Compatibility: Intel Haswell (2013) and newer processors.
}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status (2026-05-17):
  - This unit remains on the experimental x86 intrinsics lane.
  - It must not be treated as a default stable raw leaf.
  - Non-x86 branches remain compile scaffolding; runtime fail-close is intentional.
  - This raw leaf is only qualified on x86/x86_64 targets.
}

// === FMA3 single-precision primitives ===
// Fused Multiply-Add: a * b + c
function fma3_fmadd_ps(const a, b, c: TM128): TM128;
function fma3_fmadd_ss(const a, b, c: TM128): TM128;
function fma3_fmadd_ps256(const a, b, c: TM256): TM256;

// Fused Multiply-Sub: a * b - c
function fma3_fmsub_ps(const a, b, c: TM128): TM128;
function fma3_fmsub_ss(const a, b, c: TM128): TM128;
function fma3_fmsub_ps256(const a, b, c: TM256): TM256;

// Fused Negative Multiply-Add: -(a * b) + c
function fma3_fnmadd_ps(const a, b, c: TM128): TM128;
function fma3_fnmadd_ss(const a, b, c: TM128): TM128;
function fma3_fnmadd_ps256(const a, b, c: TM256): TM256;

// Fused Negative Multiply-Sub: -(a * b) - c
function fma3_fnmsub_ps(const a, b, c: TM128): TM128;
function fma3_fnmsub_ss(const a, b, c: TM128): TM128;
function fma3_fnmsub_ps256(const a, b, c: TM256): TM256;

// === FMA3 double-precision primitives ===
// Fused Multiply-Add: a * b + c
function fma3_fmadd_pd(const a, b, c: TM128): TM128;
function fma3_fmadd_sd(const a, b, c: TM128): TM128;
function fma3_fmadd_pd256(const a, b, c: TM256): TM256;

// Fused Multiply-Sub: a * b - c
function fma3_fmsub_pd(const a, b, c: TM128): TM128;
function fma3_fmsub_sd(const a, b, c: TM128): TM128;
function fma3_fmsub_pd256(const a, b, c: TM256): TM256;

// Fused Negative Multiply-Add: -(a * b) + c
function fma3_fnmadd_pd(const a, b, c: TM128): TM128;
function fma3_fnmadd_sd(const a, b, c: TM128): TM128;
function fma3_fnmadd_pd256(const a, b, c: TM256): TM256;

// Fused Negative Multiply-Sub: -(a * b) - c
function fma3_fnmsub_pd(const a, b, c: TM128): TM128;
function fma3_fnmsub_sd(const a, b, c: TM128): TM128;
function fma3_fnmsub_pd256(const a, b, c: TM256): TM256;

// === FMA3 alternating forms (operand-order variants) ===
// Fused Add-Multiply: c + a * b
function fma3_fmaddsub_ps(const a, b, c: TM128): TM128;
function fma3_fmaddsub_pd(const a, b, c: TM128): TM128;
function fma3_fmaddsub_ps256(const a, b, c: TM256): TM256;
function fma3_fmaddsub_pd256(const a, b, c: TM256): TM256;

// Fused Sub-Multiply: c - a * b
function fma3_fmsubadd_ps(const a, b, c: TM128): TM128;
function fma3_fmsubadd_pd(const a, b, c: TM128): TM128;
function fma3_fmsubadd_ps256(const a, b, c: TM256): TM256;
function fma3_fmsubadd_pd256(const a, b, c: TM256): TM256;

implementation

uses

procedure EnsureExperimentalIntrinsicsEnabled; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  
  RunError(217);  {$ENDIF}
end;

procedure EnsureExperimentalFma3TargetSupported; inline;
begin
  {$IFNDEF CPUX86_64}
  {$IFNDEF CPUX86}
  
  RunError(217);  {$ENDIF}
  {$ENDIF}
end;

// === 128-bit single-precision implementations ===
function fma3_fmadd_ps(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i] + c.m128_f32[i];
end;

function fma3_fmadd_ss(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128_f32[0] := a.m128_f32[0] * b.m128_f32[0] + c.m128_f32[0];
end;

function fma3_fmsub_ps(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i] - c.m128_f32[i];
end;

function fma3_fmsub_ss(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128_f32[0] := a.m128_f32[0] * b.m128_f32[0] - c.m128_f32[0];
end;

function fma3_fnmadd_ps(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := -(a.m128_f32[i] * b.m128_f32[i]) + c.m128_f32[i];
end;

function fma3_fnmadd_ss(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128_f32[0] := -(a.m128_f32[0] * b.m128_f32[0]) + c.m128_f32[0];
end;

function fma3_fnmsub_ps(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := -(a.m128_f32[i] * b.m128_f32[i]) - c.m128_f32[i];
end;

function fma3_fnmsub_ss(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128_f32[0] := -(a.m128_f32[0] * b.m128_f32[0]) - c.m128_f32[0];
end;

// === 128-bit double-precision implementations ===
function fma3_fmadd_pd(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i] + c.m128d_f64[i];
end;

function fma3_fmadd_sd(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128d_f64[0] := a.m128d_f64[0] * b.m128d_f64[0] + c.m128d_f64[0];
end;

function fma3_fmsub_pd(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i] - c.m128d_f64[i];
end;

function fma3_fmsub_sd(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128d_f64[0] := a.m128d_f64[0] * b.m128d_f64[0] - c.m128d_f64[0];
end;

function fma3_fnmadd_pd(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := -(a.m128d_f64[i] * b.m128d_f64[i]) + c.m128d_f64[i];
end;

function fma3_fnmadd_sd(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128d_f64[0] := -(a.m128d_f64[0] * b.m128d_f64[0]) + c.m128d_f64[0];
end;

function fma3_fnmsub_pd(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := -(a.m128d_f64[i] * b.m128d_f64[i]) - c.m128d_f64[i];
end;

function fma3_fnmsub_sd(const a, b, c: TM128): TM128;
begin
  Result := a;
  Result.m128d_f64[0] := -(a.m128d_f64[0] * b.m128d_f64[0]) - c.m128d_f64[0];
end;

// === 256-bit single-precision implementations ===
function fma3_fmadd_ps256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i] + c.m256_f32[i];
end;

function fma3_fmsub_ps256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i] - c.m256_f32[i];
end;

function fma3_fnmadd_ps256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := -(a.m256_f32[i] * b.m256_f32[i]) + c.m256_f32[i];
end;

function fma3_fnmsub_ps256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := -(a.m256_f32[i] * b.m256_f32[i]) - c.m256_f32[i];
end;

// === 256-bit double-precision implementations ===
function fma3_fmadd_pd256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i] + c.m256_f64[i];
end;

function fma3_fmsub_pd256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i] - c.m256_f64[i];
end;

function fma3_fnmadd_pd256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := -(a.m256_f64[i] * b.m256_f64[i]) + c.m256_f64[i];
end;

function fma3_fnmsub_pd256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := -(a.m256_f64[i] * b.m256_f64[i]) - c.m256_f64[i];
end;

// === 交替形式实现 ===
function fma3_fmaddsub_ps(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if (i and 1) = 0 then
      Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i] - c.m128_f32[i]
    else
      Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i] + c.m128_f32[i];
end;

function fma3_fmaddsub_pd(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    if (i and 1) = 0 then
      Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i] - c.m128d_f64[i]
    else
      Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i] + c.m128d_f64[i];
end;

function fma3_fmaddsub_ps256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if (i and 1) = 0 then
      Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i] - c.m256_f32[i]
    else
      Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i] + c.m256_f32[i];
end;

function fma3_fmaddsub_pd256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if (i and 1) = 0 then
      Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i] - c.m256_f64[i]
    else
      Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i] + c.m256_f64[i];
end;

function fma3_fmsubadd_ps(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if (i and 1) = 0 then
      Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i] + c.m128_f32[i]
    else
      Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i] - c.m128_f32[i];
end;

function fma3_fmsubadd_pd(const a, b, c: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    if (i and 1) = 0 then
      Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i] + c.m128d_f64[i]
    else
      Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i] - c.m128d_f64[i];
end;

function fma3_fmsubadd_ps256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if (i and 1) = 0 then
      Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i] + c.m256_f32[i]
    else
      Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i] - c.m256_f32[i];
end;

function fma3_fmsubadd_pd256(const a, b, c: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if (i and 1) = 0 then
      Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i] + c.m256_f64[i]
    else
      Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i] - c.m256_f64[i];
end;

initialization
  EnsureExperimentalIntrinsicsEnabled;
  EnsureExperimentalFma3TargetSupported;

end.


