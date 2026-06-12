unit nextpas.core.simd.intrinsics.sve;
// Disposition: Experimental Isolated — SVE stub intrinsics for opt-in bring-up

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.sve ===
  Stub ARM SVE intrinsics surface for isolated experimental bring-up.
  SVE adds scalable vector-length programming to AArch64 targets.
  ISA qualification only: this raw leaf documents SVE capability shape for
  opt-in experiments, not a stable public backend.
  It is only qualified on AArch64 targets whose cpuinfo reports SVE.
  Opt-in gate: NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS.
  Highlights:
  - scalable vector lengths (128-2048 bits)
  - predicate registers
  - vector-length-agnostic programming
  - richer wide-vector operations
  Compatibility: ARMv8.2-A and newer ARM processors.
}

interface

uses
  nextpas.core.simd.intrinsics.base,
  nextpas.core.simd.intrinsics.sve.base;

{$IFDEF CPUAARCH64}

// === SVE placeholder primitives ===
function sve_ptrue_b32: TSVEPredicate;
function sve_pfalse_b: TSVEPredicate;
function sve_ld1_u32(const pred: TSVEPredicate; const Ptr: Pointer): TSVEVector;
procedure sve_st1_u32(const pred: TSVEPredicate; var Dest; const Src: TSVEVector);
function sve_add_u32_z(const pred: TSVEPredicate; const a, b: TSVEVector): TSVEVector;
function sve_mul_u32_z(const pred: TSVEPredicate; const a, b: TSVEVector): TSVEVector;

{$ENDIF} // CPUAARCH64

implementation

uses
  nextpas.core.simd.cpuinfo;

procedure EnsureExperimentalIntrinsicsEnabled; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  
  RunError(217);  {$ELSE}
  if not HasSVE then
    
  {$ENDIF}
end;

{$IFDEF CPUAARCH64}

// === Simplified SVE placeholder implementations ===
function sve_ptrue_b32: TSVEPredicate;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.pred_mask[i] := True;
end;

function sve_pfalse_b: TSVEPredicate;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.pred_mask[i] := False;
end;

function sve_ld1_u32(const pred: TSVEPredicate; const Ptr: Pointer): TSVEVector;
var
  i: Integer;
  src: PUInt32;
begin
  src := PUInt32(Ptr);
  for i := 0 to 15 do
    if pred.pred_mask[i] then
      Result.sve_u32[i] := src[i]
    else
      Result.sve_u32[i] := 0;
end;

procedure sve_st1_u32(const pred: TSVEPredicate; var Dest; const Src: TSVEVector);
var
  i: Integer;
  dst: PUInt32;
begin
  dst := PUInt32(@Dest);
  for i := 0 to 15 do
    if pred.pred_mask[i] then
      dst[i] := Src.sve_u32[i];
end;

function sve_add_u32_z(const pred: TSVEPredicate; const a, b: TSVEVector): TSVEVector;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if pred.pred_mask[i] then
      Result.sve_u32[i] := a.sve_u32[i] + b.sve_u32[i]
    else
      Result.sve_u32[i] := 0;
end;

function sve_mul_u32_z(const pred: TSVEPredicate; const a, b: TSVEVector): TSVEVector;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if pred.pred_mask[i] then
      Result.sve_u32[i] := a.sve_u32[i] * b.sve_u32[i]
    else
      Result.sve_u32[i] := 0;
end;

{$ELSE}
// Non-AArch64 platforms keep stub implementations only.
{$ENDIF} // CPUAARCH64

initialization
  EnsureExperimentalIntrinsicsEnabled;

end.


