unit nextpas.core.simd.mips;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.mips ===
  MIPS MSA backend — STUB (FPC MIPS64 codegen 限制)

  Status: STUB — FPC mips64el 后端 InternalError(2002122101)，
  RTL 编译失败。等待 nextpas 编译器实现 MIPS 后端后启用。

  MSA provides (未来):
  - 32 x 128-bit vector registers (W0-W31)
  - Integer and floating-point operations
  - Saturating arithmetic
  - Load/Store with alignment hints
}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.cpuinfo;

procedure RegisterMSABackend;

{$IFDEF CPUMIPS64}
// === MSA Backend Functions ===

// Load/Store
function MSALoadF32x4(const Ptr: Pointer): TVecF32x4;
procedure MSAStoreF32x4(Ptr: Pointer; const Value: TVecF32x4);
function MSALoadF64x2(const Ptr: Pointer): TVecF64x2;
procedure MSAStoreF64x2(Ptr: Pointer; const Value: TVecF64x2);

// Arithmetic F32x4
function MSAAddF32x4(const a, b: TVecF32x4): TVecF32x4;
function MSASubF32x4(const a, b: TVecF32x4): TVecF32x4;
function MSAMulF32x4(const a, b: TVecF32x4): TVecF32x4;
function MSADivF32x4(const a, b: TVecF32x4): TVecF32x4;

// Arithmetic F64x2
function MSAAddF64x2(const a, b: TVecF64x2): TVecF64x2;
function MSASubF64x2(const a, b: TVecF64x2): TVecF64x2;
function MSAMulF64x2(const a, b: TVecF64x2): TVecF64x2;
function MSADivF64x2(const a, b: TVecF64x2): TVecF64x2;

// Comparison
function MSAMinF32x4(const a, b: TVecF32x4): TVecF32x4;
function MSAMaxF32x4(const a, b: TVecF32x4): TVecF32x4;
function MSAMinF64x2(const a, b: TVecF64x2): TVecF64x2;
function MSAMaxF64x2(const a, b: TVecF64x2): TVecF64x2;

{$ENDIF}

implementation

uses
  nextpas.core.simd.intrinsics.msa;

{$IFDEF CPUMIPS64}

// === MSA Backend Implementation ===

function MSALoadF32x4(const Ptr: Pointer): TVecF32x4;
var
  MV: TMSAVector;
begin
  MV := msa_ld_b(Ptr);
  Move(MV, Result, SizeOf(TVecF32x4));
end;

procedure MSAStoreF32x4(Ptr: Pointer; const Value: TVecF32x4);
var
  MV: TMSAVector;
begin
  Move(Value, MV, SizeOf(TMSAVector));
  msa_st_b(Ptr, MV);
end;

function MSALoadF64x2(const Ptr: Pointer): TVecF64x2;
var
  MV: TMSAVector;
begin
  MV := msa_ld_b(Ptr);
  Move(MV, Result, SizeOf(TVecF64x2));
end;

procedure MSAStoreF64x2(Ptr: Pointer; const Value: TVecF64x2);
var
  MV: TMSAVector;
begin
  Move(Value, MV, SizeOf(TMSAVector));
  msa_st_b(Ptr, MV);
end;

function MSAAddF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fadd_w(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF32x4));
end;

function MSASubF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fsub_w(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF32x4));
end;

function MSAMulF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fmul_w(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF32x4));
end;

function MSADivF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fdiv_w(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF32x4));
end;

function MSAAddF64x2(const a, b: TVecF64x2): TVecF64x2;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fadd_d(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF64x2));
end;

function MSASubF64x2(const a, b: TVecF64x2): TVecF64x2;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fsub_d(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF64x2));
end;

function MSAMulF64x2(const a, b: TVecF64x2): TVecF64x2;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fmul_d(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF64x2));
end;

function MSADivF64x2(const a, b: TVecF64x2): TVecF64x2;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fdiv_d(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF64x2));
end;

function MSAMinF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fmin_w(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF32x4));
end;

function MSAMaxF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fmax_w(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF32x4));
end;

function MSAMinF64x2(const a, b: TVecF64x2): TVecF64x2;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fmin_d(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF64x2));
end;

function MSAMaxF64x2(const a, b: TVecF64x2): TVecF64x2;
var
  Ma, Mb, Mr: TMSAVector;
begin
  Move(a, Ma, SizeOf(TMSAVector));
  Move(b, Mb, SizeOf(TMSAVector));
  Mr := msa_fmax_d(Ma, Mb);
  Move(Mr, Result, SizeOf(TVecF64x2));
end;

{$ENDIF}

procedure RegisterMSABackend;
begin
  {$IFDEF CPUMIPS64}
  {$NOTE SIMD-MSA: MSA backend registration deferred — blocked on FPC MIPS compiler support}
  {$ENDIF}
end;

end.
