unit nextpas.core.simd.intrinsics.msa;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.msa ===
  MIPS MSA intrinsics surface.

  This unit provides MIPS MSA (MIPS SIMD Architecture) intrinsics
  for the nextpas.core.simd dispatch system.

  MSA provides:
  - 32 x 128-bit vector registers (W0-W31)
  - Integer and floating-point operations
  - Saturating arithmetic
  - Load/Store with alignment hints

  Status: EXPERIMENTAL - Requires MIPS hardware
  Compatibility: MIPS Release 5 and newer processors
}

interface

{$IFDEF CPUMIPS64}

uses
  nextpas.core.simd.intrinsics.base;

// === MSA Types ===
type
  // MSA 128-bit vector types
  TMSAVector = record
    case Integer of
      0: (msa_u32: array[0..3] of UInt32);   // 4 x 32-bit lanes
      1: (msa_i32: array[0..3] of LongInt);
      2: (msa_f32: array[0..3] of Single);
      3: (msa_u64: array[0..1] of UInt64);   // 2 x 64-bit lanes
      4: (msa_i64: array[0..1] of Int64);
      5: (msa_f64: array[0..1] of Double);
      6: (msa_u16: array[0..7] of UInt16);   // 8 x 16-bit lanes
      7: (msa_i16: array[0..7] of SmallInt);
      8: (msa_u8: array[0..15] of UInt8);    // 16 x 8-bit lanes
      9: (msa_i8: array[0..15] of ShortInt);
  end;
  PMSAVector = ^TMSAVector;

// === MSA Intrinsics ===

// Load/Store
function msa_ld_b(const Ptr: Pointer): TMSAVector;
procedure msa_st_b(Ptr: Pointer; const Value: TMSAVector);

// Arithmetic f32x4
function msa_fadd_w(const a, b: TMSAVector): TMSAVector;
function msa_fsub_w(const a, b: TMSAVector): TMSAVector;
function msa_fmul_w(const a, b: TMSAVector): TMSAVector;
function msa_fdiv_w(const a, b: TMSAVector): TMSAVector;

// Arithmetic f64x2
function msa_fadd_d(const a, b: TMSAVector): TMSAVector;
function msa_fsub_d(const a, b: TMSAVector): TMSAVector;
function msa_fmul_d(const a, b: TMSAVector): TMSAVector;
function msa_fdiv_d(const a, b: TMSAVector): TMSAVector;

// Comparison
function msa_fmin_w(const a, b: TMSAVector): TMSAVector;
function msa_fmax_w(const a, b: TMSAVector): TMSAVector;
function msa_fmin_d(const a, b: TMSAVector): TMSAVector;
function msa_fmax_d(const a, b: TMSAVector): TMSAVector;

{$ENDIF}

implementation

{$IFDEF CPUMIPS64}

// === MSA Implementation ===
// Note: These are scalar fallbacks. Real MSA would use asm intrinsics.

function msa_ld_b(const Ptr: Pointer): TMSAVector;
begin
  Move(Ptr^, Result, SizeOf(TMSAVector));
end;

procedure msa_st_b(Ptr: Pointer; const Value: TMSAVector);
begin
  Move(Value, Ptr^, SizeOf(TMSAVector));
end;

function msa_fadd_w(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.msa_f32[i] := a.msa_f32[i] + b.msa_f32[i];
end;

function msa_fsub_w(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.msa_f32[i] := a.msa_f32[i] - b.msa_f32[i];
end;

function msa_fmul_w(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.msa_f32[i] := a.msa_f32[i] * b.msa_f32[i];
end;

function msa_fdiv_w(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.msa_f32[i] := a.msa_f32[i] / b.msa_f32[i];
end;

function msa_fadd_d(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.msa_f64[i] := a.msa_f64[i] + b.msa_f64[i];
end;

function msa_fsub_d(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.msa_f64[i] := a.msa_f64[i] - b.msa_f64[i];
end;

function msa_fmul_d(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.msa_f64[i] := a.msa_f64[i] * b.msa_f64[i];
end;

function msa_fdiv_d(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.msa_f64[i] := a.msa_f64[i] / b.msa_f64[i];
end;

function msa_fmin_w(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.msa_f32[i] < b.msa_f32[i] then
      Result.msa_f32[i] := a.msa_f32[i]
    else
      Result.msa_f32[i] := b.msa_f32[i];
end;

function msa_fmax_w(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.msa_f32[i] > b.msa_f32[i] then
      Result.msa_f32[i] := a.msa_f32[i]
    else
      Result.msa_f32[i] := b.msa_f32[i];
end;

function msa_fmin_d(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 1 do
    if a.msa_f64[i] < b.msa_f64[i] then
      Result.msa_f64[i] := a.msa_f64[i]
    else
      Result.msa_f64[i] := b.msa_f64[i];
end;

function msa_fmax_d(const a, b: TMSAVector): TMSAVector;
var
  i: Integer;
begin
  for i := 0 to 1 do
    if a.msa_f64[i] > b.msa_f64[i] then
      Result.msa_f64[i] := a.msa_f64[i]
    else
      Result.msa_f64[i] := b.msa_f64[i];
end;

{$ENDIF}

end.
