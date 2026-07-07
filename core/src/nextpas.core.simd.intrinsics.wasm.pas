unit nextpas.core.simd.intrinsics.wasm;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.wasm ===
  WebAssembly SIMD128 intrinsics surface.

  This unit provides WebAssembly SIMD128 intrinsics for the nextpas.core.simd
  dispatch system.

  WASM SIMD128 provides:
  - 128-bit vector registers
  - Integer and floating-point operations
  - Saturating arithmetic
  - Load/Store with alignment hints

  Status: EXPERIMENTAL - Requires WASM runtime support
  Compatibility: All WASM runtimes with SIMD support (Chrome 91+, Firefox 89+, Node.js 16.4+)
}

interface

{$IFDEF CPUWASM64}

uses
  nextpas.core.simd.intrinsics.base;

// === WASM SIMD128 Types ===
type
  // WASM 128-bit vector types
  TWasmV128 = record
    case Integer of
      0: (wasm_u32: array[0..3] of UInt32);   // 4 x 32-bit lanes
      1: (wasm_i32: array[0..3] of LongInt);
      2: (wasm_f32: array[0..3] of Single);
      3: (wasm_u64: array[0..1] of UInt64);   // 2 x 64-bit lanes
      4: (wasm_i64: array[0..1] of Int64);
      5: (wasm_f64: array[0..1] of Double);
      6: (wasm_u16: array[0..7] of UInt16);   // 8 x 16-bit lanes
      7: (wasm_i16: array[0..7] of SmallInt);
      8: (wasm_u8: array[0..15] of UInt8);    // 16 x 8-bit lanes
      9: (wasm_i8: array[0..15] of ShortInt);
  end;
  PWasmV128 = ^TWasmV128;

// === WASM SIMD128 Intrinsics ===

// Load/Store
function wasm_v128_load(const Ptr: Pointer): TWasmV128;
procedure wasm_v128_store(Ptr: Pointer; const Value: TWasmV128);

// Constants
function wasm_i32x4_splat(Value: UInt32): TWasmV128;
function wasm_f32x4_splat(Value: Single): TWasmV128;
function wasm_i64x2_splat(Value: UInt64): TWasmV128;
function wasm_f64x2_splat(Value: Double): TWasmV128;

// Arithmetic i32x4
function wasm_i32x4_add(const a, b: TWasmV128): TWasmV128;
function wasm_i32x4_sub(const a, b: TWasmV128): TWasmV128;
function wasm_i32x4_mul(const a, b: TWasmV128): TWasmV128;

// Arithmetic f32x4
function wasm_f32x4_add(const a, b: TWasmV128): TWasmV128;
function wasm_f32x4_sub(const a, b: TWasmV128): TWasmV128;
function wasm_f32x4_mul(const a, b: TWasmV128): TWasmV128;
function wasm_f32x4_div(const a, b: TWasmV128): TWasmV128;

// Arithmetic f64x2
function wasm_f64x2_add(const a, b: TWasmV128): TWasmV128;
function wasm_f64x2_sub(const a, b: TWasmV128): TWasmV128;
function wasm_f64x2_mul(const a, b: TWasmV128): TWasmV128;
function wasm_f64x2_div(const a, b: TWasmV128): TWasmV128;

// Comparison
function wasm_f32x4_min(const a, b: TWasmV128): TWasmV128;
function wasm_f32x4_max(const a, b: TWasmV128): TWasmV128;
function wasm_f64x2_min(const a, b: TWasmV128): TWasmV128;
function wasm_f64x2_max(const a, b: TWasmV128): TWasmV128;

// Bitwise
function wasm_v128_and(const a, b: TWasmV128): TWasmV128;
function wasm_v128_or(const a, b: TWasmV128): TWasmV128;
function wasm_v128_xor(const a, b: TWasmV128): TWasmV128;
function wasm_v128_not(const a: TWasmV128): TWasmV128;

{$ENDIF}

implementation

{$IFDEF CPUWASM64}

// === WASM SIMD128 Implementation ===
// Note: These are scalar fallbacks. Real WASM SIMD would use wasm intrinsics.

function wasm_v128_load(const Ptr: Pointer): TWasmV128;
begin
  Move(Ptr^, Result, SizeOf(TWasmV128));
end;

procedure wasm_v128_store(Ptr: Pointer; const Value: TWasmV128);
begin
  Move(Value, Ptr^, SizeOf(TWasmV128));
end;

function wasm_i32x4_splat(Value: UInt32): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := Value;
end;

function wasm_f32x4_splat(Value: Single): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_f32[i] := Value;
end;

function wasm_i64x2_splat(Value: UInt64): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.wasm_u64[i] := Value;
end;

function wasm_f64x2_splat(Value: Double): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.wasm_f64[i] := Value;
end;

function wasm_i32x4_add(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := a.wasm_u32[i] + b.wasm_u32[i];
end;

function wasm_i32x4_sub(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := a.wasm_u32[i] - b.wasm_u32[i];
end;

function wasm_i32x4_mul(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := a.wasm_u32[i] * b.wasm_u32[i];
end;

function wasm_f32x4_add(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_f32[i] := a.wasm_f32[i] + b.wasm_f32[i];
end;

function wasm_f32x4_sub(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_f32[i] := a.wasm_f32[i] - b.wasm_f32[i];
end;

function wasm_f32x4_mul(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_f32[i] := a.wasm_f32[i] * b.wasm_f32[i];
end;

function wasm_f32x4_div(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_f32[i] := a.wasm_f32[i] / b.wasm_f32[i];
end;

function wasm_f64x2_add(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.wasm_f64[i] := a.wasm_f64[i] + b.wasm_f64[i];
end;

function wasm_f64x2_sub(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.wasm_f64[i] := a.wasm_f64[i] - b.wasm_f64[i];
end;

function wasm_f64x2_mul(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.wasm_f64[i] := a.wasm_f64[i] * b.wasm_f64[i];
end;

function wasm_f64x2_div(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.wasm_f64[i] := a.wasm_f64[i] / b.wasm_f64[i];
end;

function wasm_f32x4_min(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.wasm_f32[i] < b.wasm_f32[i] then
      Result.wasm_f32[i] := a.wasm_f32[i]
    else
      Result.wasm_f32[i] := b.wasm_f32[i];
end;

function wasm_f32x4_max(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.wasm_f32[i] > b.wasm_f32[i] then
      Result.wasm_f32[i] := a.wasm_f32[i]
    else
      Result.wasm_f32[i] := b.wasm_f32[i];
end;

function wasm_f64x2_min(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    if a.wasm_f64[i] < b.wasm_f64[i] then
      Result.wasm_f64[i] := a.wasm_f64[i]
    else
      Result.wasm_f64[i] := b.wasm_f64[i];
end;

function wasm_f64x2_max(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    if a.wasm_f64[i] > b.wasm_f64[i] then
      Result.wasm_f64[i] := a.wasm_f64[i]
    else
      Result.wasm_f64[i] := b.wasm_f64[i];
end;

function wasm_v128_and(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := a.wasm_u32[i] and b.wasm_u32[i];
end;

function wasm_v128_or(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := a.wasm_u32[i] or b.wasm_u32[i];
end;

function wasm_v128_xor(const a, b: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := a.wasm_u32[i] xor b.wasm_u32[i];
end;

function wasm_v128_not(const a: TWasmV128): TWasmV128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.wasm_u32[i] := not a.wasm_u32[i];
end;

{$ENDIF}

end.
