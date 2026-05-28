unit nextpas.core.simd.direct;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.dispatch,
  nextpas.core.simd.dataplane;

// =============================================================
// Direct Dispatch (direct pointer)
//
// 目的：避免每次门面调用都重复走 dispatch getter 逻辑，
// 直接读取当前 data-plane snapshot 中已发布的 dispatch table 指针。
//
// 设计：
// - dispatch 仍然是“控制面真相来源”（后端注册/选择/切换）。
// - data-plane 维护当前已发布 snapshot；direct 只是读取这份 snapshot。
// =============================================================

// Returns the bound direct dispatch table.
// The returned pointer remains valid for the lifetime of the process.
function GetDirectDispatchTable: PSimdDispatchTable; inline;

// Rebinds the direct dispatch table to the currently active dispatch table.
// Call this after runtime control-plane switching
// (e.g., SetCurrentBackend/ResetCurrentBackendSelection).
procedure RebindDirectDispatch;

implementation

function GetDirectDispatchTable: PSimdDispatchTable; inline;
begin
  Result := GetCurrentSimdDataPlaneDispatch;
end;

procedure RebindDirectDispatch;
begin
  RebindSimdDataPlane;
end;

end.
