unit nextpas.core.simd.intrinsics.avx512;
// Disposition: STABLE — low-level intrinsics, used by dispatch backends


{$I nextpas.core.settings.inc}

{
  === nextpas.core.simd.intrinsics.avx512 ===
  Placeholder AVX-512 intrinsics surface for isolated experimental bring-up.
  AVX-512 expands SIMD vectors to 512 bits and adds mask-driven execution.
  Highlights:
  - 512-bit vector registers (zmm0-zmm31)
  - mask registers (k0-k7)
  - masked execution and embedded rounding controls
  - conflict-detection style helpers
  Compatibility: Intel Xeon Phi (2016) and selected server processors.
}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status (2026-05-17):
  - This unit remains on the experimental x86 intrinsics lane.
  - It must not be treated as a default stable raw leaf.
  - Non-x86 branches remain compile scaffolding; runtime fail-close is intentional.
}

// === AVX-512 placeholder primitives ===
// Load/Store
function avx512_load_ps512(const Ptr: Pointer): TM512;
function avx512_loadu_ps512(const Ptr: Pointer): TM512;
procedure avx512_store_ps512(var Dest; const Src: TM512);
procedure avx512_storeu_ps512(var Dest; const Src: TM512);

// Set/Zero
function avx512_setzero_ps512: TM512;
function avx512_set1_ps512(Value: Single): TM512;

// Arithmetic
function avx512_add_ps512(const a, b: TM512): TM512;
function avx512_sub_ps512(const a, b: TM512): TM512;
function avx512_mul_ps512(const a, b: TM512): TM512;
function avx512_div_ps512(const a, b: TM512): TM512;

// Mask operations (simplified placeholders)
function avx512_mask_add_ps512(const src, a, b: TM512; mask: UInt16): TM512;
function avx512_maskz_add_ps512(const a, b: TM512; mask: UInt16): TM512;

implementation

uses
  SysUtils;

type
  TAVX512F32x16BinaryOp = (avx512OpAdd, avx512OpSub, avx512OpMul, avx512OpDiv);

procedure EnsureExperimentalIntrinsicsEnabled; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  raise ENotSupportedException.Create(
    'nextpas.core.simd.intrinsics.avx512 is experimental placeholder semantics. ' +
    'Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS to opt in.'
  );
  {$ENDIF}
end;

procedure EnsureExperimentalAvx512TargetSupported; inline;
begin
  {$IFNDEF CPUX86_64}
  {$IFNDEF CPUX86}
  raise ENotSupportedException.Create(
    'nextpas.core.simd.intrinsics.avx512 experimental runtime is only qualified on x86/x86_64. ' +
    'The non-x86 branch remains compile scaffolding, not executable semantics.'
  );
  {$ENDIF}
  {$ENDIF}
end;

function AVX512LoadF32x16(const Ptr: Pointer): TM512; inline;
begin
  Result := PTM512(Ptr)^;
end;

procedure AVX512StoreF32x16(var aDest; const aSrc: TM512); inline;
begin
  PTM512(@aDest)^ := aSrc;
end;

procedure AVX512SetF32x16(var aResult: TM512; const aValue: Single); inline;
var
  i: Integer;
begin
  for i := 0 to 15 do
    aResult.m512_f32[i] := aValue;
end;

procedure AVX512ApplyF32x16Binary(var aResult: TM512; const a, b: TM512; const aOp: TAVX512F32x16BinaryOp); inline;
var
  i: Integer;
begin
  case aOp of
    avx512OpAdd:
      for i := 0 to 15 do
        aResult.m512_f32[i] := a.m512_f32[i] + b.m512_f32[i];
    avx512OpSub:
      for i := 0 to 15 do
        aResult.m512_f32[i] := a.m512_f32[i] - b.m512_f32[i];
    avx512OpMul:
      for i := 0 to 15 do
        aResult.m512_f32[i] := a.m512_f32[i] * b.m512_f32[i];
    avx512OpDiv:
      for i := 0 to 15 do
        aResult.m512_f32[i] := a.m512_f32[i] / b.m512_f32[i];
  end;
end;

procedure AVX512ApplyF32x16MaskAdd(var aResult: TM512; const src, a, b: TM512; const mask: UInt16; const aUseSourceForUnmasked: Boolean); inline;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if (mask and (1 shl i)) <> 0 then
      aResult.m512_f32[i] := a.m512_f32[i] + b.m512_f32[i]
    else if aUseSourceForUnmasked then
      aResult.m512_f32[i] := src.m512_f32[i]
    else
      aResult.m512_f32[i] := 0.0;
end;

// === 基础函数实现 (Pascal 版本) ===
function avx512_load_ps512(const Ptr: Pointer): TM512;
begin
  Result := AVX512LoadF32x16(Ptr);
end;

function avx512_loadu_ps512(const Ptr: Pointer): TM512;
begin
  Result := AVX512LoadF32x16(Ptr);
end;

procedure avx512_store_ps512(var Dest; const Src: TM512);
begin
  AVX512StoreF32x16(Dest, Src);
end;

procedure avx512_storeu_ps512(var Dest; const Src: TM512);
begin
  AVX512StoreF32x16(Dest, Src);
end;

function avx512_setzero_ps512: TM512;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function avx512_set1_ps512(Value: Single): TM512;
begin
  AVX512SetF32x16(Result, Value);
end;

function avx512_add_ps512(const a, b: TM512): TM512;
begin
  AVX512ApplyF32x16Binary(Result, a, b, avx512OpAdd);
end;

function avx512_sub_ps512(const a, b: TM512): TM512;
begin
  AVX512ApplyF32x16Binary(Result, a, b, avx512OpSub);
end;

function avx512_mul_ps512(const a, b: TM512): TM512;
begin
  AVX512ApplyF32x16Binary(Result, a, b, avx512OpMul);
end;

function avx512_div_ps512(const a, b: TM512): TM512;
begin
  AVX512ApplyF32x16Binary(Result, a, b, avx512OpDiv);
end;

function avx512_mask_add_ps512(const src, a, b: TM512; mask: UInt16): TM512;
begin
  AVX512ApplyF32x16MaskAdd(Result, src, a, b, mask, True);
end;

function avx512_maskz_add_ps512(const a, b: TM512; mask: UInt16): TM512;
begin
  AVX512ApplyF32x16MaskAdd(Result, Default(TM512), a, b, mask, False);
end;

initialization
  EnsureExperimentalIntrinsicsEnabled;
  EnsureExperimentalAvx512TargetSupported;

end.
