unit nextpas.core.simd.dispatchslots.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd.testcase,
  nextpas.core.simd.base, nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.iface, nextpas.core.simd.backend.adapter;

type
  // Full dispatch contract: every function slot must be bound on each selectable backend.
  TTestCase_DispatchAllSlots = class(TSimdBackendStatefulTestCase)
  private
    procedure AssertAllDispatchSlotsAssigned(const aBackend: TSimdBackend; const aDispatch: PSimdDispatchTable);
  published
    procedure Test_AllSelectableBackends_AllDispatchSlots_Assigned;
    procedure Test_BackendAdapter_EmptyOps_Fallback_AllDispatchSlots_Assigned;
    procedure Test_BackendAdapter_ActiveBackend_RoundTrip_NoNilAndCorePointersStable;
    procedure Test_BackendAdapter_UnregisteredBackendOps_PreserveCanonicalMetadata;
    procedure Test_BackendAdapter_RegisteredBackendOps_PreserveCanonicalTextMetadata_After_ReRegister;
    procedure Test_SSE42_Inherits_SSE41_DispatchSlots;
  end;

implementation

function DispatchSlotsBackendName(const aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

procedure TTestCase_DispatchAllSlots.AssertAllDispatchSlotsAssigned(const aBackend: TSimdBackend; const aDispatch: PSimdDispatchTable);
var
  LBackendSlotPrefix: string;
begin
  CheckNotNil(aDispatch, 'Dispatch table should be available');
  LBackendSlotPrefix := 'Backend=' + DispatchSlotsBackendName(aBackend) + ' slot ';

  CheckTrue(Assigned(aDispatch^.AddF32x4), LBackendSlotPrefix + 'AddF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubF32x4), LBackendSlotPrefix + 'SubF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulF32x4), LBackendSlotPrefix + 'MulF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.DivF32x4), LBackendSlotPrefix + 'DivF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddF32x8), LBackendSlotPrefix + 'AddF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubF32x8), LBackendSlotPrefix + 'SubF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulF32x8), LBackendSlotPrefix + 'MulF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.DivF32x8), LBackendSlotPrefix + 'DivF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddF64x2), LBackendSlotPrefix + 'AddF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubF64x2), LBackendSlotPrefix + 'SubF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulF64x2), LBackendSlotPrefix + 'MulF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.DivF64x2), LBackendSlotPrefix + 'DivF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI32x4), LBackendSlotPrefix + 'AddI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI32x4), LBackendSlotPrefix + 'SubI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulI32x4), LBackendSlotPrefix + 'MulI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI32x4), LBackendSlotPrefix + 'AndI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI32x4), LBackendSlotPrefix + 'OrI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI32x4), LBackendSlotPrefix + 'XorI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI32x4), LBackendSlotPrefix + 'NotI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI32x4), LBackendSlotPrefix + 'AndNotI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI32x4), LBackendSlotPrefix + 'ShiftLeftI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI32x4), LBackendSlotPrefix + 'ShiftRightI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightArithI32x4), LBackendSlotPrefix + 'ShiftRightArithI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI32x4), LBackendSlotPrefix + 'CmpEqI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI32x4), LBackendSlotPrefix + 'CmpLtI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI32x4), LBackendSlotPrefix + 'CmpGtI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI32x4), LBackendSlotPrefix + 'CmpLeI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI32x4), LBackendSlotPrefix + 'CmpGeI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI32x4), LBackendSlotPrefix + 'CmpNeI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI32x4), LBackendSlotPrefix + 'MinI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI32x4), LBackendSlotPrefix + 'MaxI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI64x2), LBackendSlotPrefix + 'AddI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI64x2), LBackendSlotPrefix + 'SubI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI64x2), LBackendSlotPrefix + 'AndI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI64x2), LBackendSlotPrefix + 'OrI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI64x2), LBackendSlotPrefix + 'XorI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI64x2), LBackendSlotPrefix + 'NotI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI64x2), LBackendSlotPrefix + 'AndNotI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI64x2), LBackendSlotPrefix + 'ShiftLeftI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI64x2), LBackendSlotPrefix + 'ShiftRightI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightArithI64x2), LBackendSlotPrefix + 'ShiftRightArithI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI64x2), LBackendSlotPrefix + 'CmpEqI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI64x2), LBackendSlotPrefix + 'CmpLtI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI64x2), LBackendSlotPrefix + 'CmpGtI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI64x2), LBackendSlotPrefix + 'CmpLeI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI64x2), LBackendSlotPrefix + 'CmpGeI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI64x2), LBackendSlotPrefix + 'CmpNeI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI64x2), LBackendSlotPrefix + 'MinI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI64x2), LBackendSlotPrefix + 'MaxI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU64x2), LBackendSlotPrefix + 'AddU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU64x2), LBackendSlotPrefix + 'SubU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU64x2), LBackendSlotPrefix + 'AndU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU64x2), LBackendSlotPrefix + 'OrU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU64x2), LBackendSlotPrefix + 'XorU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU64x2), LBackendSlotPrefix + 'NotU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotU64x2), LBackendSlotPrefix + 'AndNotU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU64x2), LBackendSlotPrefix + 'CmpEqU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU64x2), LBackendSlotPrefix + 'CmpLtU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU64x2), LBackendSlotPrefix + 'CmpGtU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU64x2), LBackendSlotPrefix + 'MinU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU64x2), LBackendSlotPrefix + 'MaxU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddF64x4), LBackendSlotPrefix + 'AddF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubF64x4), LBackendSlotPrefix + 'SubF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulF64x4), LBackendSlotPrefix + 'MulF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.DivF64x4), LBackendSlotPrefix + 'DivF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI32x8), LBackendSlotPrefix + 'AddI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI32x8), LBackendSlotPrefix + 'SubI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulI32x8), LBackendSlotPrefix + 'MulI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI32x8), LBackendSlotPrefix + 'AndI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI32x8), LBackendSlotPrefix + 'OrI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI32x8), LBackendSlotPrefix + 'XorI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI32x8), LBackendSlotPrefix + 'NotI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI32x8), LBackendSlotPrefix + 'AndNotI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI32x8), LBackendSlotPrefix + 'ShiftLeftI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI32x8), LBackendSlotPrefix + 'ShiftRightI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightArithI32x8), LBackendSlotPrefix + 'ShiftRightArithI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI32x8), LBackendSlotPrefix + 'CmpEqI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI32x8), LBackendSlotPrefix + 'CmpLtI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI32x8), LBackendSlotPrefix + 'CmpGtI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI32x8), LBackendSlotPrefix + 'CmpLeI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI32x8), LBackendSlotPrefix + 'CmpGeI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI32x8), LBackendSlotPrefix + 'CmpNeI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI32x8), LBackendSlotPrefix + 'MinI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI32x8), LBackendSlotPrefix + 'MaxI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI64x4), LBackendSlotPrefix + 'AddI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI64x4), LBackendSlotPrefix + 'SubI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI64x4), LBackendSlotPrefix + 'AndI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI64x4), LBackendSlotPrefix + 'OrI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI64x4), LBackendSlotPrefix + 'XorI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI64x4), LBackendSlotPrefix + 'NotI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI64x4), LBackendSlotPrefix + 'AndNotI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI64x4), LBackendSlotPrefix + 'ShiftLeftI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI64x4), LBackendSlotPrefix + 'ShiftRightI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI64x4), LBackendSlotPrefix + 'CmpEqI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI64x4), LBackendSlotPrefix + 'CmpLtI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI64x4), LBackendSlotPrefix + 'CmpGtI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI64x4), LBackendSlotPrefix + 'CmpLeI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI64x4), LBackendSlotPrefix + 'CmpGeI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI64x4), LBackendSlotPrefix + 'CmpNeI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadI64x4), LBackendSlotPrefix + 'LoadI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreI64x4), LBackendSlotPrefix + 'StoreI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatI64x4), LBackendSlotPrefix + 'SplatI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroI64x4), LBackendSlotPrefix + 'ZeroI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU32x8), LBackendSlotPrefix + 'AddU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU32x8), LBackendSlotPrefix + 'SubU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulU32x8), LBackendSlotPrefix + 'MulU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU32x8), LBackendSlotPrefix + 'AndU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU32x8), LBackendSlotPrefix + 'OrU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU32x8), LBackendSlotPrefix + 'XorU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU32x8), LBackendSlotPrefix + 'NotU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotU32x8), LBackendSlotPrefix + 'AndNotU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftU32x8), LBackendSlotPrefix + 'ShiftLeftU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightU32x8), LBackendSlotPrefix + 'ShiftRightU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU32x8), LBackendSlotPrefix + 'CmpEqU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU32x8), LBackendSlotPrefix + 'CmpLtU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU32x8), LBackendSlotPrefix + 'CmpGtU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU32x8), LBackendSlotPrefix + 'CmpLeU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU32x8), LBackendSlotPrefix + 'CmpGeU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeU32x8), LBackendSlotPrefix + 'CmpNeU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU32x8), LBackendSlotPrefix + 'MinU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU32x8), LBackendSlotPrefix + 'MaxU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU64x4), LBackendSlotPrefix + 'AddU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU64x4), LBackendSlotPrefix + 'SubU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU64x4), LBackendSlotPrefix + 'AndU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU64x4), LBackendSlotPrefix + 'OrU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU64x4), LBackendSlotPrefix + 'XorU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU64x4), LBackendSlotPrefix + 'NotU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftU64x4), LBackendSlotPrefix + 'ShiftLeftU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightU64x4), LBackendSlotPrefix + 'ShiftRightU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU64x4), LBackendSlotPrefix + 'CmpEqU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU64x4), LBackendSlotPrefix + 'CmpLtU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU64x4), LBackendSlotPrefix + 'CmpGtU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU64x4), LBackendSlotPrefix + 'CmpLeU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU64x4), LBackendSlotPrefix + 'CmpGeU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeU64x4), LBackendSlotPrefix + 'CmpNeU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.RcpF64x4), LBackendSlotPrefix + 'RcpF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI32x16), LBackendSlotPrefix + 'AddI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI32x16), LBackendSlotPrefix + 'SubI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulI32x16), LBackendSlotPrefix + 'MulI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI32x16), LBackendSlotPrefix + 'AndI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI32x16), LBackendSlotPrefix + 'OrI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI32x16), LBackendSlotPrefix + 'XorI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI32x16), LBackendSlotPrefix + 'NotI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI32x16), LBackendSlotPrefix + 'AndNotI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI32x16), LBackendSlotPrefix + 'ShiftLeftI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI32x16), LBackendSlotPrefix + 'ShiftRightI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightArithI32x16), LBackendSlotPrefix + 'ShiftRightArithI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI32x16), LBackendSlotPrefix + 'CmpEqI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI32x16), LBackendSlotPrefix + 'CmpLtI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI32x16), LBackendSlotPrefix + 'CmpGtI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI32x16), LBackendSlotPrefix + 'CmpLeI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI32x16), LBackendSlotPrefix + 'CmpGeI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI32x16), LBackendSlotPrefix + 'CmpNeI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI32x16), LBackendSlotPrefix + 'MinI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI32x16), LBackendSlotPrefix + 'MaxI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI64x8), LBackendSlotPrefix + 'AddI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI64x8), LBackendSlotPrefix + 'SubI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI64x8), LBackendSlotPrefix + 'AndI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI64x8), LBackendSlotPrefix + 'OrI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI64x8), LBackendSlotPrefix + 'XorI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI64x8), LBackendSlotPrefix + 'NotI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI64x8), LBackendSlotPrefix + 'CmpEqI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI64x8), LBackendSlotPrefix + 'CmpLtI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI64x8), LBackendSlotPrefix + 'CmpGtI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI64x8), LBackendSlotPrefix + 'CmpLeI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI64x8), LBackendSlotPrefix + 'CmpGeI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI64x8), LBackendSlotPrefix + 'CmpNeI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU32x16), LBackendSlotPrefix + 'AddU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU32x16), LBackendSlotPrefix + 'SubU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulU32x16), LBackendSlotPrefix + 'MulU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU32x16), LBackendSlotPrefix + 'AndU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU32x16), LBackendSlotPrefix + 'OrU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU32x16), LBackendSlotPrefix + 'XorU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU32x16), LBackendSlotPrefix + 'NotU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotU32x16), LBackendSlotPrefix + 'AndNotU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftU32x16), LBackendSlotPrefix + 'ShiftLeftU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightU32x16), LBackendSlotPrefix + 'ShiftRightU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU32x16), LBackendSlotPrefix + 'CmpEqU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU32x16), LBackendSlotPrefix + 'CmpLtU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU32x16), LBackendSlotPrefix + 'CmpGtU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU32x16), LBackendSlotPrefix + 'CmpLeU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU32x16), LBackendSlotPrefix + 'CmpGeU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeU32x16), LBackendSlotPrefix + 'CmpNeU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU32x16), LBackendSlotPrefix + 'MinU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU32x16), LBackendSlotPrefix + 'MaxU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU64x8), LBackendSlotPrefix + 'AddU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU64x8), LBackendSlotPrefix + 'SubU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU64x8), LBackendSlotPrefix + 'AndU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU64x8), LBackendSlotPrefix + 'OrU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU64x8), LBackendSlotPrefix + 'XorU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU64x8), LBackendSlotPrefix + 'NotU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftU64x8), LBackendSlotPrefix + 'ShiftLeftU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightU64x8), LBackendSlotPrefix + 'ShiftRightU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU64x8), LBackendSlotPrefix + 'CmpEqU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU64x8), LBackendSlotPrefix + 'CmpLtU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU64x8), LBackendSlotPrefix + 'CmpGtU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU64x8), LBackendSlotPrefix + 'CmpLeU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU64x8), LBackendSlotPrefix + 'CmpGeU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeU64x8), LBackendSlotPrefix + 'CmpNeU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI16x32), LBackendSlotPrefix + 'AddI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI16x32), LBackendSlotPrefix + 'SubI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI16x32), LBackendSlotPrefix + 'AndI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI16x32), LBackendSlotPrefix + 'OrI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI16x32), LBackendSlotPrefix + 'XorI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI16x32), LBackendSlotPrefix + 'NotI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI16x32), LBackendSlotPrefix + 'AndNotI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI16x32), LBackendSlotPrefix + 'ShiftLeftI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI16x32), LBackendSlotPrefix + 'ShiftRightI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightArithI16x32), LBackendSlotPrefix + 'ShiftRightArithI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI16x32), LBackendSlotPrefix + 'CmpEqI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI16x32), LBackendSlotPrefix + 'CmpLtI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI16x32), LBackendSlotPrefix + 'CmpGtI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI16x32), LBackendSlotPrefix + 'MinI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI16x32), LBackendSlotPrefix + 'MaxI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI8x64), LBackendSlotPrefix + 'AddI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI8x64), LBackendSlotPrefix + 'SubI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI8x64), LBackendSlotPrefix + 'AndI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI8x64), LBackendSlotPrefix + 'OrI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI8x64), LBackendSlotPrefix + 'XorI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI8x64), LBackendSlotPrefix + 'NotI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI8x64), LBackendSlotPrefix + 'AndNotI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI8x64), LBackendSlotPrefix + 'CmpEqI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI8x64), LBackendSlotPrefix + 'CmpLtI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI8x64), LBackendSlotPrefix + 'CmpGtI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI8x64), LBackendSlotPrefix + 'MinI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI8x64), LBackendSlotPrefix + 'MaxI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU8x64), LBackendSlotPrefix + 'AddU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU8x64), LBackendSlotPrefix + 'SubU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU8x64), LBackendSlotPrefix + 'AndU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU8x64), LBackendSlotPrefix + 'OrU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU8x64), LBackendSlotPrefix + 'XorU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU8x64), LBackendSlotPrefix + 'NotU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU8x64), LBackendSlotPrefix + 'CmpEqU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU8x64), LBackendSlotPrefix + 'CmpLtU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU8x64), LBackendSlotPrefix + 'CmpGtU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU8x64), LBackendSlotPrefix + 'MinU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU8x64), LBackendSlotPrefix + 'MaxU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddF32x16), LBackendSlotPrefix + 'AddF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubF32x16), LBackendSlotPrefix + 'SubF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulF32x16), LBackendSlotPrefix + 'MulF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.DivF32x16), LBackendSlotPrefix + 'DivF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddF64x8), LBackendSlotPrefix + 'AddF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubF64x8), LBackendSlotPrefix + 'SubF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulF64x8), LBackendSlotPrefix + 'MulF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.DivF64x8), LBackendSlotPrefix + 'DivF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqF32x4), LBackendSlotPrefix + 'CmpEqF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtF32x4), LBackendSlotPrefix + 'CmpLtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeF32x4), LBackendSlotPrefix + 'CmpLeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtF32x4), LBackendSlotPrefix + 'CmpGtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeF32x4), LBackendSlotPrefix + 'CmpGeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeF32x4), LBackendSlotPrefix + 'CmpNeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqF64x2), LBackendSlotPrefix + 'CmpEqF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtF64x2), LBackendSlotPrefix + 'CmpLtF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeF64x2), LBackendSlotPrefix + 'CmpLeF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtF64x2), LBackendSlotPrefix + 'CmpGtF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeF64x2), LBackendSlotPrefix + 'CmpGeF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeF64x2), LBackendSlotPrefix + 'CmpNeF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqF32x16), LBackendSlotPrefix + 'CmpEqF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtF32x16), LBackendSlotPrefix + 'CmpLtF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeF32x16), LBackendSlotPrefix + 'CmpLeF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtF32x16), LBackendSlotPrefix + 'CmpGtF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeF32x16), LBackendSlotPrefix + 'CmpGeF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeF32x16), LBackendSlotPrefix + 'CmpNeF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqF64x8), LBackendSlotPrefix + 'CmpEqF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtF64x8), LBackendSlotPrefix + 'CmpLtF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeF64x8), LBackendSlotPrefix + 'CmpLeF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtF64x8), LBackendSlotPrefix + 'CmpGtF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeF64x8), LBackendSlotPrefix + 'CmpGeF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeF64x8), LBackendSlotPrefix + 'CmpNeF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqF32x8), LBackendSlotPrefix + 'CmpEqF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtF32x8), LBackendSlotPrefix + 'CmpLtF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeF32x8), LBackendSlotPrefix + 'CmpLeF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtF32x8), LBackendSlotPrefix + 'CmpGtF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeF32x8), LBackendSlotPrefix + 'CmpGeF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeF32x8), LBackendSlotPrefix + 'CmpNeF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqF64x4), LBackendSlotPrefix + 'CmpEqF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtF64x4), LBackendSlotPrefix + 'CmpLtF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeF64x4), LBackendSlotPrefix + 'CmpLeF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtF64x4), LBackendSlotPrefix + 'CmpGtF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeF64x4), LBackendSlotPrefix + 'CmpGeF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeF64x4), LBackendSlotPrefix + 'CmpNeF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AbsF32x4), LBackendSlotPrefix + 'AbsF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SqrtF32x4), LBackendSlotPrefix + 'SqrtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinF32x4), LBackendSlotPrefix + 'MinF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxF32x4), LBackendSlotPrefix + 'MaxF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.FmaF32x4), LBackendSlotPrefix + 'FmaF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.RcpF32x4), LBackendSlotPrefix + 'RcpF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.RsqrtF32x4), LBackendSlotPrefix + 'RsqrtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.FloorF32x4), LBackendSlotPrefix + 'FloorF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CeilF32x4), LBackendSlotPrefix + 'CeilF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.RoundF32x4), LBackendSlotPrefix + 'RoundF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.TruncF32x4), LBackendSlotPrefix + 'TruncF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ClampF32x4), LBackendSlotPrefix + 'ClampF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.FmaF64x2), LBackendSlotPrefix + 'FmaF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.FloorF64x2), LBackendSlotPrefix + 'FloorF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CeilF64x2), LBackendSlotPrefix + 'CeilF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.RoundF64x2), LBackendSlotPrefix + 'RoundF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.TruncF64x2), LBackendSlotPrefix + 'TruncF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.AbsF64x2), LBackendSlotPrefix + 'AbsF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.SqrtF64x2), LBackendSlotPrefix + 'SqrtF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinF64x2), LBackendSlotPrefix + 'MinF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxF64x2), LBackendSlotPrefix + 'MaxF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ClampF64x2), LBackendSlotPrefix + 'ClampF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.FmaF32x8), LBackendSlotPrefix + 'FmaF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.FloorF32x8), LBackendSlotPrefix + 'FloorF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CeilF32x8), LBackendSlotPrefix + 'CeilF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.RoundF32x8), LBackendSlotPrefix + 'RoundF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.TruncF32x8), LBackendSlotPrefix + 'TruncF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AbsF32x8), LBackendSlotPrefix + 'AbsF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SqrtF32x8), LBackendSlotPrefix + 'SqrtF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinF32x8), LBackendSlotPrefix + 'MinF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxF32x8), LBackendSlotPrefix + 'MaxF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ClampF32x8), LBackendSlotPrefix + 'ClampF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.FmaF64x4), LBackendSlotPrefix + 'FmaF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.FloorF64x4), LBackendSlotPrefix + 'FloorF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CeilF64x4), LBackendSlotPrefix + 'CeilF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.RoundF64x4), LBackendSlotPrefix + 'RoundF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.TruncF64x4), LBackendSlotPrefix + 'TruncF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.FmaF32x16), LBackendSlotPrefix + 'FmaF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.FloorF32x16), LBackendSlotPrefix + 'FloorF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CeilF32x16), LBackendSlotPrefix + 'CeilF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.RoundF32x16), LBackendSlotPrefix + 'RoundF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.TruncF32x16), LBackendSlotPrefix + 'TruncF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.FmaF64x8), LBackendSlotPrefix + 'FmaF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.FloorF64x8), LBackendSlotPrefix + 'FloorF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CeilF64x8), LBackendSlotPrefix + 'CeilF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.RoundF64x8), LBackendSlotPrefix + 'RoundF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.TruncF64x8), LBackendSlotPrefix + 'TruncF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AbsF64x4), LBackendSlotPrefix + 'AbsF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SqrtF64x4), LBackendSlotPrefix + 'SqrtF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinF64x4), LBackendSlotPrefix + 'MinF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxF64x4), LBackendSlotPrefix + 'MaxF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ClampF64x4), LBackendSlotPrefix + 'ClampF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AbsF32x16), LBackendSlotPrefix + 'AbsF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SqrtF32x16), LBackendSlotPrefix + 'SqrtF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinF32x16), LBackendSlotPrefix + 'MinF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxF32x16), LBackendSlotPrefix + 'MaxF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ClampF32x16), LBackendSlotPrefix + 'ClampF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AbsF64x8), LBackendSlotPrefix + 'AbsF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SqrtF64x8), LBackendSlotPrefix + 'SqrtF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinF64x8), LBackendSlotPrefix + 'MinF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxF64x8), LBackendSlotPrefix + 'MaxF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ClampF64x8), LBackendSlotPrefix + 'ClampF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.DotF32x4), LBackendSlotPrefix + 'DotF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.DotF32x3), LBackendSlotPrefix + 'DotF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.CrossF32x3), LBackendSlotPrefix + 'CrossF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.LengthF32x4), LBackendSlotPrefix + 'LengthF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.LengthF32x3), LBackendSlotPrefix + 'LengthF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.NormalizeF32x4), LBackendSlotPrefix + 'NormalizeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.NormalizeF32x3), LBackendSlotPrefix + 'NormalizeF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.DotF32x8), LBackendSlotPrefix + 'DotF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.DotF64x2), LBackendSlotPrefix + 'DotF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.DotF64x4), LBackendSlotPrefix + 'DotF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceAddF32x4), LBackendSlotPrefix + 'ReduceAddF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMinF32x4), LBackendSlotPrefix + 'ReduceMinF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMaxF32x4), LBackendSlotPrefix + 'ReduceMaxF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMulF32x4), LBackendSlotPrefix + 'ReduceMulF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceAddF64x2), LBackendSlotPrefix + 'ReduceAddF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMinF64x2), LBackendSlotPrefix + 'ReduceMinF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMaxF64x2), LBackendSlotPrefix + 'ReduceMaxF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMulF64x2), LBackendSlotPrefix + 'ReduceMulF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceAddF32x8), LBackendSlotPrefix + 'ReduceAddF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMinF32x8), LBackendSlotPrefix + 'ReduceMinF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMaxF32x8), LBackendSlotPrefix + 'ReduceMaxF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMulF32x8), LBackendSlotPrefix + 'ReduceMulF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceAddF64x4), LBackendSlotPrefix + 'ReduceAddF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMinF64x4), LBackendSlotPrefix + 'ReduceMinF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMaxF64x4), LBackendSlotPrefix + 'ReduceMaxF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMulF64x4), LBackendSlotPrefix + 'ReduceMulF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceAddF32x16), LBackendSlotPrefix + 'ReduceAddF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMinF32x16), LBackendSlotPrefix + 'ReduceMinF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMaxF32x16), LBackendSlotPrefix + 'ReduceMaxF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMulF32x16), LBackendSlotPrefix + 'ReduceMulF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceAddF64x8), LBackendSlotPrefix + 'ReduceAddF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMinF64x8), LBackendSlotPrefix + 'ReduceMinF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMaxF64x8), LBackendSlotPrefix + 'ReduceMaxF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ReduceMulF64x8), LBackendSlotPrefix + 'ReduceMulF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF32x4), LBackendSlotPrefix + 'LoadF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF32x4Aligned), LBackendSlotPrefix + 'LoadF32x4Aligned should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF32x4), LBackendSlotPrefix + 'StoreF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF32x4Aligned), LBackendSlotPrefix + 'StoreF32x4Aligned should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatF32x4), LBackendSlotPrefix + 'SplatF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroF32x4), LBackendSlotPrefix + 'ZeroF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectF32x4), LBackendSlotPrefix + 'SelectF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractF32x4), LBackendSlotPrefix + 'ExtractF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertF32x4), LBackendSlotPrefix + 'InsertF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractF64x2), LBackendSlotPrefix + 'ExtractF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertF64x2), LBackendSlotPrefix + 'InsertF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractI32x4), LBackendSlotPrefix + 'ExtractI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertI32x4), LBackendSlotPrefix + 'InsertI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractI64x2), LBackendSlotPrefix + 'ExtractI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertI64x2), LBackendSlotPrefix + 'InsertI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractF32x8), LBackendSlotPrefix + 'ExtractF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertF32x8), LBackendSlotPrefix + 'InsertF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractF64x4), LBackendSlotPrefix + 'ExtractF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertF64x4), LBackendSlotPrefix + 'InsertF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractI32x8), LBackendSlotPrefix + 'ExtractI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertI32x8), LBackendSlotPrefix + 'InsertI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractI64x4), LBackendSlotPrefix + 'ExtractI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertI64x4), LBackendSlotPrefix + 'InsertI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractF32x16), LBackendSlotPrefix + 'ExtractF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertF32x16), LBackendSlotPrefix + 'InsertF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ExtractI32x16), LBackendSlotPrefix + 'ExtractI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.InsertI32x16), LBackendSlotPrefix + 'InsertI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF64x2), LBackendSlotPrefix + 'LoadF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF64x2), LBackendSlotPrefix + 'StoreF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatF64x2), LBackendSlotPrefix + 'SplatF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroF64x2), LBackendSlotPrefix + 'ZeroF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF32x8), LBackendSlotPrefix + 'LoadF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF32x8), LBackendSlotPrefix + 'StoreF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatF32x8), LBackendSlotPrefix + 'SplatF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroF32x8), LBackendSlotPrefix + 'ZeroF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF64x4), LBackendSlotPrefix + 'LoadF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF64x4), LBackendSlotPrefix + 'StoreF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatF64x4), LBackendSlotPrefix + 'SplatF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroF64x4), LBackendSlotPrefix + 'ZeroF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF32x16), LBackendSlotPrefix + 'LoadF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF32x16), LBackendSlotPrefix + 'StoreF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatF32x16), LBackendSlotPrefix + 'SplatF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroF32x16), LBackendSlotPrefix + 'ZeroF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.LoadF64x8), LBackendSlotPrefix + 'LoadF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.StoreF64x8), LBackendSlotPrefix + 'StoreF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SplatF64x8), LBackendSlotPrefix + 'SplatF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ZeroF64x8), LBackendSlotPrefix + 'ZeroF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MemEqual), LBackendSlotPrefix + 'MemEqual should be assigned');
  CheckTrue(Assigned(aDispatch^.MemFindByte), LBackendSlotPrefix + 'MemFindByte should be assigned');
  CheckTrue(Assigned(aDispatch^.MemDiffRange), LBackendSlotPrefix + 'MemDiffRange should be assigned');
  CheckTrue(Assigned(aDispatch^.MemCopy), LBackendSlotPrefix + 'MemCopy should be assigned');
  CheckTrue(Assigned(aDispatch^.MemSet), LBackendSlotPrefix + 'MemSet should be assigned');
  CheckTrue(Assigned(aDispatch^.MemReverse), LBackendSlotPrefix + 'MemReverse should be assigned');
  CheckTrue(Assigned(aDispatch^.SumBytes), LBackendSlotPrefix + 'SumBytes should be assigned');
  CheckTrue(Assigned(aDispatch^.MinMaxBytes), LBackendSlotPrefix + 'MinMaxBytes should be assigned');
  CheckTrue(Assigned(aDispatch^.CountByte), LBackendSlotPrefix + 'CountByte should be assigned');
  CheckTrue(Assigned(aDispatch^.Utf8Validate), LBackendSlotPrefix + 'Utf8Validate should be assigned');
  CheckTrue(Assigned(aDispatch^.AsciiIEqual), LBackendSlotPrefix + 'AsciiIEqual should be assigned');
  CheckTrue(Assigned(aDispatch^.ToLowerAscii), LBackendSlotPrefix + 'ToLowerAscii should be assigned');
  CheckTrue(Assigned(aDispatch^.ToUpperAscii), LBackendSlotPrefix + 'ToUpperAscii should be assigned');
  CheckTrue(Assigned(aDispatch^.BytesIndexOf), LBackendSlotPrefix + 'BytesIndexOf should be assigned');
  CheckTrue(Assigned(aDispatch^.BitsetPopCount), LBackendSlotPrefix + 'BitsetPopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.I8x16SatAdd), LBackendSlotPrefix + 'I8x16SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.I8x16SatSub), LBackendSlotPrefix + 'I8x16SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.I16x8SatAdd), LBackendSlotPrefix + 'I16x8SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.I16x8SatSub), LBackendSlotPrefix + 'I16x8SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.U8x16SatAdd), LBackendSlotPrefix + 'U8x16SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.U8x16SatSub), LBackendSlotPrefix + 'U8x16SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.U16x8SatAdd), LBackendSlotPrefix + 'U16x8SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.U16x8SatSub), LBackendSlotPrefix + 'U16x8SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI16x8), LBackendSlotPrefix + 'AddI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI16x8), LBackendSlotPrefix + 'SubI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulI16x8), LBackendSlotPrefix + 'MulI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI16x8), LBackendSlotPrefix + 'AndI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI16x8), LBackendSlotPrefix + 'OrI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI16x8), LBackendSlotPrefix + 'XorI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI16x8), LBackendSlotPrefix + 'NotI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI16x8), LBackendSlotPrefix + 'AndNotI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftI16x8), LBackendSlotPrefix + 'ShiftLeftI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightI16x8), LBackendSlotPrefix + 'ShiftRightI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightArithI16x8), LBackendSlotPrefix + 'ShiftRightArithI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI16x8), LBackendSlotPrefix + 'CmpEqI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI16x8), LBackendSlotPrefix + 'CmpLtI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI16x8), LBackendSlotPrefix + 'CmpGtI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI16x8), LBackendSlotPrefix + 'CmpLeI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI16x8), LBackendSlotPrefix + 'CmpGeI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI16x8), LBackendSlotPrefix + 'CmpNeI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI16x8), LBackendSlotPrefix + 'MinI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI16x8), LBackendSlotPrefix + 'MaxI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddI8x16), LBackendSlotPrefix + 'AddI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubI8x16), LBackendSlotPrefix + 'SubI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndI8x16), LBackendSlotPrefix + 'AndI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrI8x16), LBackendSlotPrefix + 'OrI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorI8x16), LBackendSlotPrefix + 'XorI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotI8x16), LBackendSlotPrefix + 'NotI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqI8x16), LBackendSlotPrefix + 'CmpEqI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtI8x16), LBackendSlotPrefix + 'CmpLtI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtI8x16), LBackendSlotPrefix + 'CmpGtI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeI8x16), LBackendSlotPrefix + 'CmpLeI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeI8x16), LBackendSlotPrefix + 'CmpGeI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeI8x16), LBackendSlotPrefix + 'CmpNeI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinI8x16), LBackendSlotPrefix + 'MinI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxI8x16), LBackendSlotPrefix + 'MaxI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU32x4), LBackendSlotPrefix + 'AddU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU32x4), LBackendSlotPrefix + 'SubU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulU32x4), LBackendSlotPrefix + 'MulU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU32x4), LBackendSlotPrefix + 'AndU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU32x4), LBackendSlotPrefix + 'OrU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU32x4), LBackendSlotPrefix + 'XorU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU32x4), LBackendSlotPrefix + 'NotU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotU32x4), LBackendSlotPrefix + 'AndNotU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftU32x4), LBackendSlotPrefix + 'ShiftLeftU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightU32x4), LBackendSlotPrefix + 'ShiftRightU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU32x4), LBackendSlotPrefix + 'CmpEqU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU32x4), LBackendSlotPrefix + 'CmpLtU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU32x4), LBackendSlotPrefix + 'CmpGtU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU32x4), LBackendSlotPrefix + 'CmpLeU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU32x4), LBackendSlotPrefix + 'CmpGeU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU32x4), LBackendSlotPrefix + 'MinU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU32x4), LBackendSlotPrefix + 'MaxU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU16x8), LBackendSlotPrefix + 'AddU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU16x8), LBackendSlotPrefix + 'SubU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MulU16x8), LBackendSlotPrefix + 'MulU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU16x8), LBackendSlotPrefix + 'AndU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU16x8), LBackendSlotPrefix + 'OrU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU16x8), LBackendSlotPrefix + 'XorU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU16x8), LBackendSlotPrefix + 'NotU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftLeftU16x8), LBackendSlotPrefix + 'ShiftLeftU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.ShiftRightU16x8), LBackendSlotPrefix + 'ShiftRightU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU16x8), LBackendSlotPrefix + 'CmpEqU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU16x8), LBackendSlotPrefix + 'CmpLtU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU16x8), LBackendSlotPrefix + 'CmpGtU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU16x8), LBackendSlotPrefix + 'CmpLeU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU16x8), LBackendSlotPrefix + 'CmpGeU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeU16x8), LBackendSlotPrefix + 'CmpNeU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU16x8), LBackendSlotPrefix + 'MinU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU16x8), LBackendSlotPrefix + 'MaxU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AddU8x16), LBackendSlotPrefix + 'AddU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SubU8x16), LBackendSlotPrefix + 'SubU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndU8x16), LBackendSlotPrefix + 'AndU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.OrU8x16), LBackendSlotPrefix + 'OrU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.XorU8x16), LBackendSlotPrefix + 'XorU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.NotU8x16), LBackendSlotPrefix + 'NotU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpEqU8x16), LBackendSlotPrefix + 'CmpEqU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLtU8x16), LBackendSlotPrefix + 'CmpLtU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGtU8x16), LBackendSlotPrefix + 'CmpGtU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpLeU8x16), LBackendSlotPrefix + 'CmpLeU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpGeU8x16), LBackendSlotPrefix + 'CmpGeU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CmpNeU8x16), LBackendSlotPrefix + 'CmpNeU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MinU8x16), LBackendSlotPrefix + 'MinU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.MaxU8x16), LBackendSlotPrefix + 'MaxU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask2All), LBackendSlotPrefix + 'Mask2All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask2Any), LBackendSlotPrefix + 'Mask2Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask2None), LBackendSlotPrefix + 'Mask2None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask2PopCount), LBackendSlotPrefix + 'Mask2PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask2FirstSet), LBackendSlotPrefix + 'Mask2FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask4All), LBackendSlotPrefix + 'Mask4All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask4Any), LBackendSlotPrefix + 'Mask4Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask4None), LBackendSlotPrefix + 'Mask4None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask4PopCount), LBackendSlotPrefix + 'Mask4PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask4FirstSet), LBackendSlotPrefix + 'Mask4FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask8All), LBackendSlotPrefix + 'Mask8All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask8Any), LBackendSlotPrefix + 'Mask8Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask8None), LBackendSlotPrefix + 'Mask8None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask8PopCount), LBackendSlotPrefix + 'Mask8PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask8FirstSet), LBackendSlotPrefix + 'Mask8FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask16All), LBackendSlotPrefix + 'Mask16All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask16Any), LBackendSlotPrefix + 'Mask16Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask16None), LBackendSlotPrefix + 'Mask16None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask16PopCount), LBackendSlotPrefix + 'Mask16PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask16FirstSet), LBackendSlotPrefix + 'Mask16FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectF64x2), LBackendSlotPrefix + 'SelectF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectF32x16), LBackendSlotPrefix + 'SelectF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectF64x8), LBackendSlotPrefix + 'SelectF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectI32x4), LBackendSlotPrefix + 'SelectI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectF32x8), LBackendSlotPrefix + 'SelectF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.SelectF64x4), LBackendSlotPrefix + 'SelectF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotI8x16), LBackendSlotPrefix + 'AndNotI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotU16x8), LBackendSlotPrefix + 'AndNotU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.AndNotU8x16), LBackendSlotPrefix + 'AndNotU8x16 should be assigned');

end;

procedure TTestCase_DispatchAllSlots.Test_AllSelectableBackends_AllDispatchSlots_Assigned;
const
  BACKENDS: array[0..9] of TSimdBackend = (
    sbScalar, sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42, sbAVX2, sbAVX512, sbNEON, sbRISCVV
  );
var
  LBackend: TSimdBackend;
  LChecked: Integer;
  LDispatch: PSimdDispatchTable;
begin
  LChecked := 0;
  for LBackend in BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    LDispatch := GetDispatchTable;
    CheckEqual(Ord(LBackend), Ord(GetActiveBackend), 'Active backend mismatch');
    AssertAllDispatchSlotsAssigned(LBackend, LDispatch);
    Inc(LChecked);
  end;

  CheckTrue(LChecked > 0, 'At least one backend should be checked');
end;

procedure TTestCase_DispatchAllSlots.Test_BackendAdapter_EmptyOps_Fallback_AllDispatchSlots_Assigned;
var
  LOps: TSimdBackendOps;
  LTable: TSimdDispatchTable;
begin
  LOps := Default(TSimdBackendOps);
  ClearBackendOps(LOps);
  BackendOpsToDispatchTable(LOps, LTable);
  AssertAllDispatchSlotsAssigned(sbScalar, @LTable);
end;

procedure TTestCase_DispatchAllSlots.Test_BackendAdapter_ActiveBackend_RoundTrip_NoNilAndCorePointersStable;
const
  BACKENDS: array[0..9] of TSimdBackend = (
    sbScalar, sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42, sbAVX2, sbAVX512, sbNEON, sbRISCVV
  );
var
  LBackend: TSimdBackend;
  LChecked: Integer;
  LDispatch: PSimdDispatchTable;
  LSourceTable: TSimdDispatchTable;
  LRoundTripTable: TSimdDispatchTable;
  LOps: TSimdBackendOps;
begin
  LChecked := 0;
  for LBackend in BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    LDispatch := GetDispatchTable;
    CheckNotNil(LDispatch, 'Dispatch table should be available');
    CheckEqual(Ord(LBackend), Ord(GetActiveBackend), 'Active backend mismatch');

    LSourceTable := LDispatch^;
    LOps := Default(TSimdBackendOps);
    DispatchTableToBackendOps(LSourceTable, LOps);
    BackendOpsToDispatchTable(LOps, LRoundTripTable);
    AssertAllDispatchSlotsAssigned(LBackend, @LRoundTripTable);

    CheckEqual(Ord(LSourceTable.Backend), Ord(LRoundTripTable.Backend), 'Roundtrip backend field mismatch');
    CheckEqual(Ord(LSourceTable.BackendInfo.Backend), Ord(LRoundTripTable.BackendInfo.Backend), 'Roundtrip BackendInfo.Backend mismatch');
    CheckEqual(LSourceTable.BackendInfo.Name, LRoundTripTable.BackendInfo.Name, 'Roundtrip BackendInfo.Name mismatch');
    CheckEqual(LSourceTable.BackendInfo.Description, LRoundTripTable.BackendInfo.Description, 'Roundtrip BackendInfo.Description mismatch');
    CheckEqual(LSourceTable.BackendInfo.Available, LRoundTripTable.BackendInfo.Available, 'Roundtrip BackendInfo.Available mismatch');
    CheckEqual(LSourceTable.BackendInfo.Priority, LRoundTripTable.BackendInfo.Priority, 'Roundtrip BackendInfo.Priority mismatch');
    CheckTrue(LSourceTable.BackendInfo.Capabilities = LRoundTripTable.BackendInfo.Capabilities, 'Roundtrip BackendInfo.Capabilities mismatch');
    CheckTrue(LRoundTripTable.BackendInfo.Name <> '', 'BackendInfo.Name should stay non-empty for registered backend');

    // Contract smoke: representative core slots must keep exact function-pointer identity.
    CheckTrue(LSourceTable.AddF32x4 = LRoundTripTable.AddF32x4, 'AddF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.MulF32x4 = LRoundTripTable.MulF32x4, 'MulF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.RoundF32x4 = LRoundTripTable.RoundF32x4, 'RoundF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.TruncF32x4 = LRoundTripTable.TruncF32x4, 'TruncF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.AddI32x4 = LRoundTripTable.AddI32x4, 'AddI32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.AndI32x4 = LRoundTripTable.AndI32x4, 'AndI32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.LoadF32x4 = LRoundTripTable.LoadF32x4, 'LoadF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.StoreF32x4 = LRoundTripTable.StoreF32x4, 'StoreF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.MemEqual = LRoundTripTable.MemEqual, 'MemEqual pointer changed after roundtrip');
    CheckTrue(LSourceTable.BitsetPopCount = LRoundTripTable.BitsetPopCount, 'BitsetPopCount pointer changed after roundtrip');

    Inc(LChecked);
  end;

  CheckTrue(LChecked > 0, 'At least one backend should be checked');
end;

procedure TTestCase_DispatchAllSlots.Test_BackendAdapter_UnregisteredBackendOps_PreserveCanonicalMetadata;
var
  LBackend: TSimdBackend;
  LBackendName: string;
  LOps: TSimdBackendOps;
  LExpectedInfo: TSimdBackendInfo;
  LFoundUnregistered: Boolean;
begin
  LFoundUnregistered := False;
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if IsBackendRegistered(LBackend) then
      Continue;

    LFoundUnregistered := True;
    LBackendName := DispatchSlotsBackendName(LBackend);
    LExpectedInfo := GetBackendInfo(LBackend);
    LOps := GetBackendOps(LBackend);

    CheckEqual(Ord(LBackend), Ord(LOps.Backend), 'GetBackendOps should preserve the requested backend id for unregistered backend=' + LBackendName);
    CheckEqual(Ord(LExpectedInfo.Backend), Ord(LOps.BackendInfo.Backend), 'GetBackendOps should preserve BackendInfo.Backend for unregistered backend=' + LBackendName);
    CheckEqual(LExpectedInfo.Priority, LOps.BackendInfo.Priority, 'GetBackendOps should preserve canonical priority for unregistered backend=' + LBackendName);
    CheckEqual(LExpectedInfo.Available, LOps.BackendInfo.Available, 'GetBackendOps should preserve canonical availability for unregistered backend=' + LBackendName);
    CheckTrue(LOps.BackendInfo.Capabilities = LExpectedInfo.Capabilities, 'GetBackendOps should preserve empty capability set for unregistered backend=' + LBackendName);
  end;

  CheckTrue(LFoundUnregistered, 'At least one unregistered backend should exist for adapter metadata coverage');
end;

procedure TTestCase_DispatchAllSlots.Test_BackendAdapter_RegisteredBackendOps_PreserveCanonicalTextMetadata_After_ReRegister;
var
  LBackend: TSimdBackend;
  LOriginalTable: TSimdDispatchTable;
  LModifiedTable: TSimdDispatchTable;
  LOps: TSimdBackendOps;
  LCanonicalInfo: TSimdBackendInfo;
begin
  ResetToAutomaticBackend;
  LBackend := GetActiveBackend;

  CheckTrue(TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable), 'Current backend should be registered for adapter canonical text test');

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Name := '';
  LModifiedTable.BackendInfo.Description := '';
  RegisterBackend(LBackend, LModifiedTable);
  try
    LOps := GetBackendOps(LBackend);
    LCanonicalInfo := GetBackendInfo(LBackend);

    CheckEqual(Ord(LBackend), Ord(LOps.Backend), 'GetBackendOps should preserve the requested backend id after re-register');
    CheckEqual(Ord(LBackend), Ord(LOps.BackendInfo.Backend), 'GetBackendOps should preserve BackendInfo.Backend after re-register');
    CheckTrue(LOps.BackendInfo.Name <> '', 'GetBackendOps should preserve non-empty name for registered backend after re-register');
    CheckTrue(LOps.BackendInfo.Description <> '', 'GetBackendOps should preserve non-empty description for registered backend after re-register');
    CheckEqual(LCanonicalInfo.Name, LOps.BackendInfo.Name, 'GetBackendOps should stay aligned with canonical backend name after re-register');
    CheckEqual(LCanonicalInfo.Description, LOps.BackendInfo.Description, 'GetBackendOps should stay aligned with canonical backend description after re-register');
    CheckEqual(LModifiedTable.BackendInfo.Available, LOps.BackendInfo.Available, 'GetBackendOps should preserve current availability state after re-register');
    CheckTrue(LOps.BackendInfo.Capabilities = LModifiedTable.BackendInfo.Capabilities, 'GetBackendOps should preserve current capability set after re-register');
  finally
    RegisterBackend(LBackend, LOriginalTable);
  end;
end;

procedure TTestCase_DispatchAllSlots.Test_SSE42_Inherits_SSE41_DispatchSlots;
var
  LSSE41: TSimdDispatchTable;
  LSSE42: TSimdDispatchTable;
begin
  if not TryGetRegisteredBackendDispatchTable(sbSSE41, LSSE41) then
    Exit;
  if not TryGetRegisteredBackendDispatchTable(sbSSE42, LSSE42) then
    Exit;

  CheckEqual(PtrUInt(LSSE41.MulI32x4), PtrUInt(LSSE42.MulI32x4), 'SSE4.2 should inherit SSE4.1 MulI32x4');
  CheckEqual(PtrUInt(LSSE41.DotF32x4), PtrUInt(LSSE42.DotF32x4), 'SSE4.2 should inherit SSE4.1 DotF32x4');
  CheckEqual(PtrUInt(LSSE41.RoundF32x4), PtrUInt(LSSE42.RoundF32x4), 'SSE4.2 should inherit SSE4.1 RoundF32x4');
  CheckEqual(PtrUInt(LSSE41.SelectF32x4), PtrUInt(LSSE42.SelectF32x4), 'SSE4.2 should inherit SSE4.1 SelectF32x4');
end;


end.