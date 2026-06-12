unit nextpas.core.simd.intrinsics.sse3;
// Disposition: STABLE — low-level intrinsics, used by dispatch backends

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.sse3 ===
  Placeholder SSE3 intrinsics surface for isolated experimental bring-up.
  SSE3 adds horizontal arithmetic, complex-style add/sub forms, and extra load helpers.
  Highlights:
  - horizontal add/sub instructions
  - complex add/sub support
  - special load instructions
  - monitor/mwait stubs
  Compatibility: most modern x86/x64 processors.
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

// === SSE3 水平运算 ===
// Horizontal Add/Sub (single precision)
function sse3_hadd_ps(const a, b: TM128): TM128;
function sse3_hsub_ps(const a, b: TM128): TM128;

// Horizontal Add/Sub (double precision)
function sse3_hadd_pd(const a, b: TM128): TM128;
function sse3_hsub_pd(const a, b: TM128): TM128;

// === SSE3 复数运算 ===
// Add/Sub (交替加减)
function sse3_addsub_ps(const a, b: TM128): TM128;
function sse3_addsub_pd(const a, b: TM128): TM128;

// === SSE3 特殊加载指令 ===
// Load Unaligned Integer (更快的未对齐加载)
function sse3_lddqu_si128(const Ptr: Pointer): TM128;

// Move and Duplicate
function sse3_movehdup_ps(const a: TM128): TM128;  // 复制高位元素
function sse3_moveldup_ps(const a: TM128): TM128;  // 复制低位元素
function sse3_movddup_pd(const a: TM128): TM128;   // duplicate a double-precision lane
// Load and Duplicate
function sse3_loaddup_pd(const Ptr: Pointer): TM128;

// === SSE3 thread-sync stubs ===
procedure sse3_monitor(const Ptr: Pointer; extensions, hints: Cardinal);
procedure sse3_mwait(extensions, hints: Cardinal);

implementation

uses

procedure EnsureExperimentalIntrinsicsEnabled; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  
  RunError(217);  {$ENDIF}
end;

procedure EnsureExperimentalSse3TargetSupported; inline;
begin
  {$IFNDEF CPUX86_64}
  {$IFNDEF CPUX86}
  
  RunError(217);  {$ENDIF}
  {$ENDIF}
end;

// === 水平运算实现 ===
function sse3_hadd_ps(const a, b: TM128): TM128;
begin
  // 水平加法：[a1+a0, a3+a2, b1+b0, b3+b2]
  Result.m128_f32[0] := a.m128_f32[0] + a.m128_f32[1];
  Result.m128_f32[1] := a.m128_f32[2] + a.m128_f32[3];
  Result.m128_f32[2] := b.m128_f32[0] + b.m128_f32[1];
  Result.m128_f32[3] := b.m128_f32[2] + b.m128_f32[3];
end;

function sse3_hsub_ps(const a, b: TM128): TM128;
begin
  // 水平减法：[a1-a0, a3-a2, b1-b0, b3-b2]
  Result.m128_f32[0] := a.m128_f32[1] - a.m128_f32[0];
  Result.m128_f32[1] := a.m128_f32[3] - a.m128_f32[2];
  Result.m128_f32[2] := b.m128_f32[1] - b.m128_f32[0];
  Result.m128_f32[3] := b.m128_f32[3] - b.m128_f32[2];
end;

function sse3_hadd_pd(const a, b: TM128): TM128;
begin
  // 双精度水平加法：[a1+a0, b1+b0]
  Result.m128d_f64[0] := a.m128d_f64[0] + a.m128d_f64[1];
  Result.m128d_f64[1] := b.m128d_f64[0] + b.m128d_f64[1];
end;

function sse3_hsub_pd(const a, b: TM128): TM128;
begin
  // 双精度水平减法：[a1-a0, b1-b0]
  Result.m128d_f64[0] := a.m128d_f64[1] - a.m128d_f64[0];
  Result.m128d_f64[1] := b.m128d_f64[1] - b.m128d_f64[0];
end;

// === 复数运算实现 ===
function sse3_addsub_ps(const a, b: TM128): TM128;
begin
  // 交替加减：[a0-b0, a1+b1, a2-b2, a3+b3]
  Result.m128_f32[0] := a.m128_f32[0] - b.m128_f32[0];
  Result.m128_f32[1] := a.m128_f32[1] + b.m128_f32[1];
  Result.m128_f32[2] := a.m128_f32[2] - b.m128_f32[2];
  Result.m128_f32[3] := a.m128_f32[3] + b.m128_f32[3];
end;

function sse3_addsub_pd(const a, b: TM128): TM128;
begin
  // 双精度交替加减：[a0-b0, a1+b1]
  Result.m128d_f64[0] := a.m128d_f64[0] - b.m128d_f64[0];
  Result.m128d_f64[1] := a.m128d_f64[1] + b.m128d_f64[1];
end;

// === 特殊加载指令实现 ===
function sse3_lddqu_si128(const Ptr: Pointer): TM128;
begin
  // 未对齐整数加载（在这个实现中与普通加载相同）
  Result := PTM128(Ptr)^;
end;

function sse3_movehdup_ps(const a: TM128): TM128;
begin
  // 复制高位元素：[a1, a1, a3, a3]
  Result.m128_f32[0] := a.m128_f32[1];
  Result.m128_f32[1] := a.m128_f32[1];
  Result.m128_f32[2] := a.m128_f32[3];
  Result.m128_f32[3] := a.m128_f32[3];
end;

function sse3_moveldup_ps(const a: TM128): TM128;
begin
  // 复制低位元素：[a0, a0, a2, a2]
  Result.m128_f32[0] := a.m128_f32[0];
  Result.m128_f32[1] := a.m128_f32[0];
  Result.m128_f32[2] := a.m128_f32[2];
  Result.m128_f32[3] := a.m128_f32[2];
end;

function sse3_movddup_pd(const a: TM128): TM128;
begin
  // 复制双精度元素：[a0, a0]
  Result.m128d_f64[0] := a.m128d_f64[0];
  Result.m128d_f64[1] := a.m128d_f64[0];
end;

function sse3_loaddup_pd(const Ptr: Pointer): TM128;
var
  value: Double;
begin
  // 加载并复制双精度
  value := PDouble(Ptr)^;
  Result.m128d_f64[0] := value;
  Result.m128d_f64[1] := value;
end;

// === Thread-sync stub implementations ===
procedure sse3_monitor(const Ptr: Pointer; extensions, hints: Cardinal);
begin
  // MONITOR 指令的占位符实现
  // In a real implementation this would execute MONITOR.
end;

procedure sse3_mwait(extensions, hints: Cardinal);
begin
  // MWAIT 指令的占位符实现
  // In a real implementation this would execute MWAIT.
end;

initialization
  EnsureExperimentalIntrinsicsEnabled;
  EnsureExperimentalSse3TargetSupported;

end.


