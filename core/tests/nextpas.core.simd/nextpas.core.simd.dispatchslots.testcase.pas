unit nextpas.core.simd.dispatchslots.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd.testcase,
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

  CheckTrue(Assigned(aDispatch^.CoreVectors.AddF32x4), LBackendSlotPrefix + 'AddF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubF32x4), LBackendSlotPrefix + 'SubF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulF32x4), LBackendSlotPrefix + 'MulF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DivF32x4), LBackendSlotPrefix + 'DivF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddF32x8), LBackendSlotPrefix + 'AddF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubF32x8), LBackendSlotPrefix + 'SubF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulF32x8), LBackendSlotPrefix + 'MulF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DivF32x8), LBackendSlotPrefix + 'DivF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddF64x2), LBackendSlotPrefix + 'AddF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubF64x2), LBackendSlotPrefix + 'SubF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulF64x2), LBackendSlotPrefix + 'MulF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DivF64x2), LBackendSlotPrefix + 'DivF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI32x4), LBackendSlotPrefix + 'AddI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI32x4), LBackendSlotPrefix + 'SubI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulI32x4), LBackendSlotPrefix + 'MulI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI32x4), LBackendSlotPrefix + 'AndI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI32x4), LBackendSlotPrefix + 'OrI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI32x4), LBackendSlotPrefix + 'XorI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI32x4), LBackendSlotPrefix + 'NotI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI32x4), LBackendSlotPrefix + 'AndNotI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI32x4), LBackendSlotPrefix + 'ShiftLeftI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI32x4), LBackendSlotPrefix + 'ShiftRightI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightArithI32x4), LBackendSlotPrefix + 'ShiftRightArithI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI32x4), LBackendSlotPrefix + 'CmpEqI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI32x4), LBackendSlotPrefix + 'CmpLtI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI32x4), LBackendSlotPrefix + 'CmpGtI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI32x4), LBackendSlotPrefix + 'CmpLeI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI32x4), LBackendSlotPrefix + 'CmpGeI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI32x4), LBackendSlotPrefix + 'CmpNeI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI32x4), LBackendSlotPrefix + 'MinI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI32x4), LBackendSlotPrefix + 'MaxI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI64x2), LBackendSlotPrefix + 'AddI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI64x2), LBackendSlotPrefix + 'SubI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI64x2), LBackendSlotPrefix + 'AndI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI64x2), LBackendSlotPrefix + 'OrI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI64x2), LBackendSlotPrefix + 'XorI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI64x2), LBackendSlotPrefix + 'NotI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI64x2), LBackendSlotPrefix + 'AndNotI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI64x2), LBackendSlotPrefix + 'ShiftLeftI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI64x2), LBackendSlotPrefix + 'ShiftRightI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightArithI64x2), LBackendSlotPrefix + 'ShiftRightArithI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI64x2), LBackendSlotPrefix + 'CmpEqI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI64x2), LBackendSlotPrefix + 'CmpLtI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI64x2), LBackendSlotPrefix + 'CmpGtI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI64x2), LBackendSlotPrefix + 'CmpLeI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI64x2), LBackendSlotPrefix + 'CmpGeI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI64x2), LBackendSlotPrefix + 'CmpNeI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI64x2), LBackendSlotPrefix + 'MinI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI64x2), LBackendSlotPrefix + 'MaxI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU64x2), LBackendSlotPrefix + 'AddU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU64x2), LBackendSlotPrefix + 'SubU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU64x2), LBackendSlotPrefix + 'AndU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU64x2), LBackendSlotPrefix + 'OrU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU64x2), LBackendSlotPrefix + 'XorU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU64x2), LBackendSlotPrefix + 'NotU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotU64x2), LBackendSlotPrefix + 'AndNotU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU64x2), LBackendSlotPrefix + 'CmpEqU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU64x2), LBackendSlotPrefix + 'CmpLtU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU64x2), LBackendSlotPrefix + 'CmpGtU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU64x2), LBackendSlotPrefix + 'MinU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU64x2), LBackendSlotPrefix + 'MaxU64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddF64x4), LBackendSlotPrefix + 'AddF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubF64x4), LBackendSlotPrefix + 'SubF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulF64x4), LBackendSlotPrefix + 'MulF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DivF64x4), LBackendSlotPrefix + 'DivF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI32x8), LBackendSlotPrefix + 'AddI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI32x8), LBackendSlotPrefix + 'SubI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulI32x8), LBackendSlotPrefix + 'MulI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI32x8), LBackendSlotPrefix + 'AndI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI32x8), LBackendSlotPrefix + 'OrI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI32x8), LBackendSlotPrefix + 'XorI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI32x8), LBackendSlotPrefix + 'NotI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI32x8), LBackendSlotPrefix + 'AndNotI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI32x8), LBackendSlotPrefix + 'ShiftLeftI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI32x8), LBackendSlotPrefix + 'ShiftRightI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightArithI32x8), LBackendSlotPrefix + 'ShiftRightArithI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI32x8), LBackendSlotPrefix + 'CmpEqI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI32x8), LBackendSlotPrefix + 'CmpLtI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI32x8), LBackendSlotPrefix + 'CmpGtI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI32x8), LBackendSlotPrefix + 'CmpLeI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI32x8), LBackendSlotPrefix + 'CmpGeI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI32x8), LBackendSlotPrefix + 'CmpNeI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI32x8), LBackendSlotPrefix + 'MinI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI32x8), LBackendSlotPrefix + 'MaxI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI64x4), LBackendSlotPrefix + 'AddI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI64x4), LBackendSlotPrefix + 'SubI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI64x4), LBackendSlotPrefix + 'AndI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI64x4), LBackendSlotPrefix + 'OrI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI64x4), LBackendSlotPrefix + 'XorI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI64x4), LBackendSlotPrefix + 'NotI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI64x4), LBackendSlotPrefix + 'AndNotI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI64x4), LBackendSlotPrefix + 'ShiftLeftI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI64x4), LBackendSlotPrefix + 'ShiftRightI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI64x4), LBackendSlotPrefix + 'CmpEqI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI64x4), LBackendSlotPrefix + 'CmpLtI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI64x4), LBackendSlotPrefix + 'CmpGtI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI64x4), LBackendSlotPrefix + 'CmpLeI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI64x4), LBackendSlotPrefix + 'CmpGeI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI64x4), LBackendSlotPrefix + 'CmpNeI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadI64x4), LBackendSlotPrefix + 'LoadI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreI64x4), LBackendSlotPrefix + 'StoreI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatI64x4), LBackendSlotPrefix + 'SplatI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroI64x4), LBackendSlotPrefix + 'ZeroI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU32x8), LBackendSlotPrefix + 'AddU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU32x8), LBackendSlotPrefix + 'SubU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulU32x8), LBackendSlotPrefix + 'MulU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU32x8), LBackendSlotPrefix + 'AndU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU32x8), LBackendSlotPrefix + 'OrU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU32x8), LBackendSlotPrefix + 'XorU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU32x8), LBackendSlotPrefix + 'NotU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotU32x8), LBackendSlotPrefix + 'AndNotU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftU32x8), LBackendSlotPrefix + 'ShiftLeftU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightU32x8), LBackendSlotPrefix + 'ShiftRightU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU32x8), LBackendSlotPrefix + 'CmpEqU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU32x8), LBackendSlotPrefix + 'CmpLtU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU32x8), LBackendSlotPrefix + 'CmpGtU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU32x8), LBackendSlotPrefix + 'CmpLeU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU32x8), LBackendSlotPrefix + 'CmpGeU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeU32x8), LBackendSlotPrefix + 'CmpNeU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU32x8), LBackendSlotPrefix + 'MinU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU32x8), LBackendSlotPrefix + 'MaxU32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU64x4), LBackendSlotPrefix + 'AddU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU64x4), LBackendSlotPrefix + 'SubU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU64x4), LBackendSlotPrefix + 'AndU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU64x4), LBackendSlotPrefix + 'OrU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU64x4), LBackendSlotPrefix + 'XorU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU64x4), LBackendSlotPrefix + 'NotU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftU64x4), LBackendSlotPrefix + 'ShiftLeftU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightU64x4), LBackendSlotPrefix + 'ShiftRightU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU64x4), LBackendSlotPrefix + 'CmpEqU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU64x4), LBackendSlotPrefix + 'CmpLtU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU64x4), LBackendSlotPrefix + 'CmpGtU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU64x4), LBackendSlotPrefix + 'CmpLeU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU64x4), LBackendSlotPrefix + 'CmpGeU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeU64x4), LBackendSlotPrefix + 'CmpNeU64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RcpF64x4), LBackendSlotPrefix + 'RcpF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI32x16), LBackendSlotPrefix + 'AddI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI32x16), LBackendSlotPrefix + 'SubI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulI32x16), LBackendSlotPrefix + 'MulI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI32x16), LBackendSlotPrefix + 'AndI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI32x16), LBackendSlotPrefix + 'OrI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI32x16), LBackendSlotPrefix + 'XorI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI32x16), LBackendSlotPrefix + 'NotI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI32x16), LBackendSlotPrefix + 'AndNotI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI32x16), LBackendSlotPrefix + 'ShiftLeftI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI32x16), LBackendSlotPrefix + 'ShiftRightI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightArithI32x16), LBackendSlotPrefix + 'ShiftRightArithI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI32x16), LBackendSlotPrefix + 'CmpEqI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI32x16), LBackendSlotPrefix + 'CmpLtI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI32x16), LBackendSlotPrefix + 'CmpGtI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI32x16), LBackendSlotPrefix + 'CmpLeI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI32x16), LBackendSlotPrefix + 'CmpGeI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI32x16), LBackendSlotPrefix + 'CmpNeI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI32x16), LBackendSlotPrefix + 'MinI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI32x16), LBackendSlotPrefix + 'MaxI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI64x8), LBackendSlotPrefix + 'AddI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI64x8), LBackendSlotPrefix + 'SubI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI64x8), LBackendSlotPrefix + 'AndI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI64x8), LBackendSlotPrefix + 'OrI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI64x8), LBackendSlotPrefix + 'XorI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI64x8), LBackendSlotPrefix + 'NotI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI64x8), LBackendSlotPrefix + 'CmpEqI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI64x8), LBackendSlotPrefix + 'CmpLtI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI64x8), LBackendSlotPrefix + 'CmpGtI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI64x8), LBackendSlotPrefix + 'CmpLeI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI64x8), LBackendSlotPrefix + 'CmpGeI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI64x8), LBackendSlotPrefix + 'CmpNeI64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU32x16), LBackendSlotPrefix + 'AddU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU32x16), LBackendSlotPrefix + 'SubU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulU32x16), LBackendSlotPrefix + 'MulU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU32x16), LBackendSlotPrefix + 'AndU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU32x16), LBackendSlotPrefix + 'OrU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU32x16), LBackendSlotPrefix + 'XorU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU32x16), LBackendSlotPrefix + 'NotU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotU32x16), LBackendSlotPrefix + 'AndNotU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftU32x16), LBackendSlotPrefix + 'ShiftLeftU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightU32x16), LBackendSlotPrefix + 'ShiftRightU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU32x16), LBackendSlotPrefix + 'CmpEqU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU32x16), LBackendSlotPrefix + 'CmpLtU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU32x16), LBackendSlotPrefix + 'CmpGtU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU32x16), LBackendSlotPrefix + 'CmpLeU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU32x16), LBackendSlotPrefix + 'CmpGeU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeU32x16), LBackendSlotPrefix + 'CmpNeU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU32x16), LBackendSlotPrefix + 'MinU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU32x16), LBackendSlotPrefix + 'MaxU32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU64x8), LBackendSlotPrefix + 'AddU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU64x8), LBackendSlotPrefix + 'SubU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU64x8), LBackendSlotPrefix + 'AndU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU64x8), LBackendSlotPrefix + 'OrU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU64x8), LBackendSlotPrefix + 'XorU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU64x8), LBackendSlotPrefix + 'NotU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftU64x8), LBackendSlotPrefix + 'ShiftLeftU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightU64x8), LBackendSlotPrefix + 'ShiftRightU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU64x8), LBackendSlotPrefix + 'CmpEqU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU64x8), LBackendSlotPrefix + 'CmpLtU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU64x8), LBackendSlotPrefix + 'CmpGtU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU64x8), LBackendSlotPrefix + 'CmpLeU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU64x8), LBackendSlotPrefix + 'CmpGeU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeU64x8), LBackendSlotPrefix + 'CmpNeU64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI16x32), LBackendSlotPrefix + 'AddI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI16x32), LBackendSlotPrefix + 'SubI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI16x32), LBackendSlotPrefix + 'AndI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI16x32), LBackendSlotPrefix + 'OrI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI16x32), LBackendSlotPrefix + 'XorI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI16x32), LBackendSlotPrefix + 'NotI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI16x32), LBackendSlotPrefix + 'AndNotI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI16x32), LBackendSlotPrefix + 'ShiftLeftI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI16x32), LBackendSlotPrefix + 'ShiftRightI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightArithI16x32), LBackendSlotPrefix + 'ShiftRightArithI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI16x32), LBackendSlotPrefix + 'CmpEqI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI16x32), LBackendSlotPrefix + 'CmpLtI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI16x32), LBackendSlotPrefix + 'CmpGtI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI16x32), LBackendSlotPrefix + 'MinI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI16x32), LBackendSlotPrefix + 'MaxI16x32 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI8x64), LBackendSlotPrefix + 'AddI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI8x64), LBackendSlotPrefix + 'SubI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI8x64), LBackendSlotPrefix + 'AndI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI8x64), LBackendSlotPrefix + 'OrI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI8x64), LBackendSlotPrefix + 'XorI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI8x64), LBackendSlotPrefix + 'NotI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI8x64), LBackendSlotPrefix + 'AndNotI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI8x64), LBackendSlotPrefix + 'CmpEqI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI8x64), LBackendSlotPrefix + 'CmpLtI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI8x64), LBackendSlotPrefix + 'CmpGtI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI8x64), LBackendSlotPrefix + 'MinI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI8x64), LBackendSlotPrefix + 'MaxI8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU8x64), LBackendSlotPrefix + 'AddU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU8x64), LBackendSlotPrefix + 'SubU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU8x64), LBackendSlotPrefix + 'AndU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU8x64), LBackendSlotPrefix + 'OrU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU8x64), LBackendSlotPrefix + 'XorU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU8x64), LBackendSlotPrefix + 'NotU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU8x64), LBackendSlotPrefix + 'CmpEqU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU8x64), LBackendSlotPrefix + 'CmpLtU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU8x64), LBackendSlotPrefix + 'CmpGtU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU8x64), LBackendSlotPrefix + 'MinU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU8x64), LBackendSlotPrefix + 'MaxU8x64 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddF32x16), LBackendSlotPrefix + 'AddF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubF32x16), LBackendSlotPrefix + 'SubF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulF32x16), LBackendSlotPrefix + 'MulF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DivF32x16), LBackendSlotPrefix + 'DivF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddF64x8), LBackendSlotPrefix + 'AddF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubF64x8), LBackendSlotPrefix + 'SubF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulF64x8), LBackendSlotPrefix + 'MulF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DivF64x8), LBackendSlotPrefix + 'DivF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqF32x4), LBackendSlotPrefix + 'CmpEqF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtF32x4), LBackendSlotPrefix + 'CmpLtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeF32x4), LBackendSlotPrefix + 'CmpLeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtF32x4), LBackendSlotPrefix + 'CmpGtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeF32x4), LBackendSlotPrefix + 'CmpGeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeF32x4), LBackendSlotPrefix + 'CmpNeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqF64x2), LBackendSlotPrefix + 'CmpEqF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtF64x2), LBackendSlotPrefix + 'CmpLtF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeF64x2), LBackendSlotPrefix + 'CmpLeF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtF64x2), LBackendSlotPrefix + 'CmpGtF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeF64x2), LBackendSlotPrefix + 'CmpGeF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeF64x2), LBackendSlotPrefix + 'CmpNeF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqF32x16), LBackendSlotPrefix + 'CmpEqF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtF32x16), LBackendSlotPrefix + 'CmpLtF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeF32x16), LBackendSlotPrefix + 'CmpLeF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtF32x16), LBackendSlotPrefix + 'CmpGtF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeF32x16), LBackendSlotPrefix + 'CmpGeF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeF32x16), LBackendSlotPrefix + 'CmpNeF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqF64x8), LBackendSlotPrefix + 'CmpEqF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtF64x8), LBackendSlotPrefix + 'CmpLtF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeF64x8), LBackendSlotPrefix + 'CmpLeF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtF64x8), LBackendSlotPrefix + 'CmpGtF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeF64x8), LBackendSlotPrefix + 'CmpGeF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeF64x8), LBackendSlotPrefix + 'CmpNeF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqF32x8), LBackendSlotPrefix + 'CmpEqF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtF32x8), LBackendSlotPrefix + 'CmpLtF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeF32x8), LBackendSlotPrefix + 'CmpLeF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtF32x8), LBackendSlotPrefix + 'CmpGtF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeF32x8), LBackendSlotPrefix + 'CmpGeF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeF32x8), LBackendSlotPrefix + 'CmpNeF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqF64x4), LBackendSlotPrefix + 'CmpEqF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtF64x4), LBackendSlotPrefix + 'CmpLtF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeF64x4), LBackendSlotPrefix + 'CmpLeF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtF64x4), LBackendSlotPrefix + 'CmpGtF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeF64x4), LBackendSlotPrefix + 'CmpGeF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeF64x4), LBackendSlotPrefix + 'CmpNeF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AbsF32x4), LBackendSlotPrefix + 'AbsF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SqrtF32x4), LBackendSlotPrefix + 'SqrtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinF32x4), LBackendSlotPrefix + 'MinF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxF32x4), LBackendSlotPrefix + 'MaxF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FmaF32x4), LBackendSlotPrefix + 'FmaF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RcpF32x4), LBackendSlotPrefix + 'RcpF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RsqrtF32x4), LBackendSlotPrefix + 'RsqrtF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FloorF32x4), LBackendSlotPrefix + 'FloorF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CeilF32x4), LBackendSlotPrefix + 'CeilF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RoundF32x4), LBackendSlotPrefix + 'RoundF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.TruncF32x4), LBackendSlotPrefix + 'TruncF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ClampF32x4), LBackendSlotPrefix + 'ClampF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FmaF64x2), LBackendSlotPrefix + 'FmaF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FloorF64x2), LBackendSlotPrefix + 'FloorF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CeilF64x2), LBackendSlotPrefix + 'CeilF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RoundF64x2), LBackendSlotPrefix + 'RoundF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.TruncF64x2), LBackendSlotPrefix + 'TruncF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AbsF64x2), LBackendSlotPrefix + 'AbsF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SqrtF64x2), LBackendSlotPrefix + 'SqrtF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinF64x2), LBackendSlotPrefix + 'MinF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxF64x2), LBackendSlotPrefix + 'MaxF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ClampF64x2), LBackendSlotPrefix + 'ClampF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FmaF32x8), LBackendSlotPrefix + 'FmaF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FloorF32x8), LBackendSlotPrefix + 'FloorF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CeilF32x8), LBackendSlotPrefix + 'CeilF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RoundF32x8), LBackendSlotPrefix + 'RoundF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.TruncF32x8), LBackendSlotPrefix + 'TruncF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AbsF32x8), LBackendSlotPrefix + 'AbsF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SqrtF32x8), LBackendSlotPrefix + 'SqrtF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinF32x8), LBackendSlotPrefix + 'MinF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxF32x8), LBackendSlotPrefix + 'MaxF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ClampF32x8), LBackendSlotPrefix + 'ClampF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FmaF64x4), LBackendSlotPrefix + 'FmaF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FloorF64x4), LBackendSlotPrefix + 'FloorF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CeilF64x4), LBackendSlotPrefix + 'CeilF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RoundF64x4), LBackendSlotPrefix + 'RoundF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.TruncF64x4), LBackendSlotPrefix + 'TruncF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FmaF32x16), LBackendSlotPrefix + 'FmaF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FloorF32x16), LBackendSlotPrefix + 'FloorF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CeilF32x16), LBackendSlotPrefix + 'CeilF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RoundF32x16), LBackendSlotPrefix + 'RoundF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.TruncF32x16), LBackendSlotPrefix + 'TruncF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FmaF64x8), LBackendSlotPrefix + 'FmaF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.FloorF64x8), LBackendSlotPrefix + 'FloorF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CeilF64x8), LBackendSlotPrefix + 'CeilF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.RoundF64x8), LBackendSlotPrefix + 'RoundF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.TruncF64x8), LBackendSlotPrefix + 'TruncF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AbsF64x4), LBackendSlotPrefix + 'AbsF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SqrtF64x4), LBackendSlotPrefix + 'SqrtF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinF64x4), LBackendSlotPrefix + 'MinF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxF64x4), LBackendSlotPrefix + 'MaxF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ClampF64x4), LBackendSlotPrefix + 'ClampF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AbsF32x16), LBackendSlotPrefix + 'AbsF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SqrtF32x16), LBackendSlotPrefix + 'SqrtF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinF32x16), LBackendSlotPrefix + 'MinF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxF32x16), LBackendSlotPrefix + 'MaxF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ClampF32x16), LBackendSlotPrefix + 'ClampF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AbsF64x8), LBackendSlotPrefix + 'AbsF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SqrtF64x8), LBackendSlotPrefix + 'SqrtF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinF64x8), LBackendSlotPrefix + 'MinF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxF64x8), LBackendSlotPrefix + 'MaxF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ClampF64x8), LBackendSlotPrefix + 'ClampF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DotF32x4), LBackendSlotPrefix + 'DotF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DotF32x3), LBackendSlotPrefix + 'DotF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CrossF32x3), LBackendSlotPrefix + 'CrossF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LengthF32x4), LBackendSlotPrefix + 'LengthF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LengthF32x3), LBackendSlotPrefix + 'LengthF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NormalizeF32x4), LBackendSlotPrefix + 'NormalizeF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NormalizeF32x3), LBackendSlotPrefix + 'NormalizeF32x3 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DotF32x8), LBackendSlotPrefix + 'DotF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DotF64x2), LBackendSlotPrefix + 'DotF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.DotF64x4), LBackendSlotPrefix + 'DotF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceAddF32x4), LBackendSlotPrefix + 'ReduceAddF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMinF32x4), LBackendSlotPrefix + 'ReduceMinF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMaxF32x4), LBackendSlotPrefix + 'ReduceMaxF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMulF32x4), LBackendSlotPrefix + 'ReduceMulF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceAddF64x2), LBackendSlotPrefix + 'ReduceAddF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMinF64x2), LBackendSlotPrefix + 'ReduceMinF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMaxF64x2), LBackendSlotPrefix + 'ReduceMaxF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMulF64x2), LBackendSlotPrefix + 'ReduceMulF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceAddF32x8), LBackendSlotPrefix + 'ReduceAddF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMinF32x8), LBackendSlotPrefix + 'ReduceMinF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMaxF32x8), LBackendSlotPrefix + 'ReduceMaxF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMulF32x8), LBackendSlotPrefix + 'ReduceMulF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceAddF64x4), LBackendSlotPrefix + 'ReduceAddF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMinF64x4), LBackendSlotPrefix + 'ReduceMinF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMaxF64x4), LBackendSlotPrefix + 'ReduceMaxF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMulF64x4), LBackendSlotPrefix + 'ReduceMulF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceAddF32x16), LBackendSlotPrefix + 'ReduceAddF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMinF32x16), LBackendSlotPrefix + 'ReduceMinF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMaxF32x16), LBackendSlotPrefix + 'ReduceMaxF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMulF32x16), LBackendSlotPrefix + 'ReduceMulF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceAddF64x8), LBackendSlotPrefix + 'ReduceAddF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMinF64x8), LBackendSlotPrefix + 'ReduceMinF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMaxF64x8), LBackendSlotPrefix + 'ReduceMaxF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ReduceMulF64x8), LBackendSlotPrefix + 'ReduceMulF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF32x4), LBackendSlotPrefix + 'LoadF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF32x4Aligned), LBackendSlotPrefix + 'LoadF32x4Aligned should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF32x4), LBackendSlotPrefix + 'StoreF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF32x4Aligned), LBackendSlotPrefix + 'StoreF32x4Aligned should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatF32x4), LBackendSlotPrefix + 'SplatF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroF32x4), LBackendSlotPrefix + 'ZeroF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectF32x4), LBackendSlotPrefix + 'SelectF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractF32x4), LBackendSlotPrefix + 'ExtractF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertF32x4), LBackendSlotPrefix + 'InsertF32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractF64x2), LBackendSlotPrefix + 'ExtractF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertF64x2), LBackendSlotPrefix + 'InsertF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractI32x4), LBackendSlotPrefix + 'ExtractI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertI32x4), LBackendSlotPrefix + 'InsertI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractI64x2), LBackendSlotPrefix + 'ExtractI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertI64x2), LBackendSlotPrefix + 'InsertI64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractF32x8), LBackendSlotPrefix + 'ExtractF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertF32x8), LBackendSlotPrefix + 'InsertF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractF64x4), LBackendSlotPrefix + 'ExtractF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertF64x4), LBackendSlotPrefix + 'InsertF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractI32x8), LBackendSlotPrefix + 'ExtractI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertI32x8), LBackendSlotPrefix + 'InsertI32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractI64x4), LBackendSlotPrefix + 'ExtractI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertI64x4), LBackendSlotPrefix + 'InsertI64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractF32x16), LBackendSlotPrefix + 'ExtractF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertF32x16), LBackendSlotPrefix + 'InsertF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ExtractI32x16), LBackendSlotPrefix + 'ExtractI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.InsertI32x16), LBackendSlotPrefix + 'InsertI32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF64x2), LBackendSlotPrefix + 'LoadF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF64x2), LBackendSlotPrefix + 'StoreF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatF64x2), LBackendSlotPrefix + 'SplatF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroF64x2), LBackendSlotPrefix + 'ZeroF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF32x8), LBackendSlotPrefix + 'LoadF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF32x8), LBackendSlotPrefix + 'StoreF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatF32x8), LBackendSlotPrefix + 'SplatF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroF32x8), LBackendSlotPrefix + 'ZeroF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF64x4), LBackendSlotPrefix + 'LoadF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF64x4), LBackendSlotPrefix + 'StoreF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatF64x4), LBackendSlotPrefix + 'SplatF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroF64x4), LBackendSlotPrefix + 'ZeroF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF32x16), LBackendSlotPrefix + 'LoadF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF32x16), LBackendSlotPrefix + 'StoreF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatF32x16), LBackendSlotPrefix + 'SplatF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroF32x16), LBackendSlotPrefix + 'ZeroF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.LoadF64x8), LBackendSlotPrefix + 'LoadF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.StoreF64x8), LBackendSlotPrefix + 'StoreF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SplatF64x8), LBackendSlotPrefix + 'SplatF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ZeroF64x8), LBackendSlotPrefix + 'ZeroF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.Equal), LBackendSlotPrefix + 'MemEqual should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.FindByte), LBackendSlotPrefix + 'MemFindByte should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.DiffRange), LBackendSlotPrefix + 'MemDiffRange should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.Copy), LBackendSlotPrefix + 'MemCopy should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.Fill), LBackendSlotPrefix + 'MemSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.Reverse), LBackendSlotPrefix + 'MemReverse should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.SumBytes), LBackendSlotPrefix + 'SumBytes should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.MinMaxBytes), LBackendSlotPrefix + 'MinMaxBytes should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.CountByte), LBackendSlotPrefix + 'CountByte should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.Utf8Validate), LBackendSlotPrefix + 'Utf8Validate should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.AsciiIEqual), LBackendSlotPrefix + 'AsciiIEqual should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.ToLowerAscii), LBackendSlotPrefix + 'ToLowerAscii should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.ToUpperAscii), LBackendSlotPrefix + 'ToUpperAscii should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.BytesIndexOf), LBackendSlotPrefix + 'BytesIndexOf should be assigned');
  CheckTrue(Assigned(aDispatch^.Memory.BitsetPopCount), LBackendSlotPrefix + 'BitsetPopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.I8x16SatAdd), LBackendSlotPrefix + 'I8x16SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.I8x16SatSub), LBackendSlotPrefix + 'I8x16SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.I16x8SatAdd), LBackendSlotPrefix + 'I16x8SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.I16x8SatSub), LBackendSlotPrefix + 'I16x8SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.U8x16SatAdd), LBackendSlotPrefix + 'U8x16SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.U8x16SatSub), LBackendSlotPrefix + 'U8x16SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.U16x8SatAdd), LBackendSlotPrefix + 'U16x8SatAdd should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.U16x8SatSub), LBackendSlotPrefix + 'U16x8SatSub should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI16x8), LBackendSlotPrefix + 'AddI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI16x8), LBackendSlotPrefix + 'SubI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulI16x8), LBackendSlotPrefix + 'MulI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI16x8), LBackendSlotPrefix + 'AndI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI16x8), LBackendSlotPrefix + 'OrI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI16x8), LBackendSlotPrefix + 'XorI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI16x8), LBackendSlotPrefix + 'NotI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI16x8), LBackendSlotPrefix + 'AndNotI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftI16x8), LBackendSlotPrefix + 'ShiftLeftI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightI16x8), LBackendSlotPrefix + 'ShiftRightI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightArithI16x8), LBackendSlotPrefix + 'ShiftRightArithI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI16x8), LBackendSlotPrefix + 'CmpEqI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI16x8), LBackendSlotPrefix + 'CmpLtI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI16x8), LBackendSlotPrefix + 'CmpGtI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI16x8), LBackendSlotPrefix + 'CmpLeI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI16x8), LBackendSlotPrefix + 'CmpGeI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI16x8), LBackendSlotPrefix + 'CmpNeI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI16x8), LBackendSlotPrefix + 'MinI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI16x8), LBackendSlotPrefix + 'MaxI16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddI8x16), LBackendSlotPrefix + 'AddI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubI8x16), LBackendSlotPrefix + 'SubI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndI8x16), LBackendSlotPrefix + 'AndI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrI8x16), LBackendSlotPrefix + 'OrI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorI8x16), LBackendSlotPrefix + 'XorI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotI8x16), LBackendSlotPrefix + 'NotI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqI8x16), LBackendSlotPrefix + 'CmpEqI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtI8x16), LBackendSlotPrefix + 'CmpLtI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtI8x16), LBackendSlotPrefix + 'CmpGtI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeI8x16), LBackendSlotPrefix + 'CmpLeI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeI8x16), LBackendSlotPrefix + 'CmpGeI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeI8x16), LBackendSlotPrefix + 'CmpNeI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinI8x16), LBackendSlotPrefix + 'MinI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxI8x16), LBackendSlotPrefix + 'MaxI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU32x4), LBackendSlotPrefix + 'AddU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU32x4), LBackendSlotPrefix + 'SubU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulU32x4), LBackendSlotPrefix + 'MulU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU32x4), LBackendSlotPrefix + 'AndU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU32x4), LBackendSlotPrefix + 'OrU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU32x4), LBackendSlotPrefix + 'XorU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU32x4), LBackendSlotPrefix + 'NotU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotU32x4), LBackendSlotPrefix + 'AndNotU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftU32x4), LBackendSlotPrefix + 'ShiftLeftU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightU32x4), LBackendSlotPrefix + 'ShiftRightU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU32x4), LBackendSlotPrefix + 'CmpEqU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU32x4), LBackendSlotPrefix + 'CmpLtU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU32x4), LBackendSlotPrefix + 'CmpGtU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU32x4), LBackendSlotPrefix + 'CmpLeU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU32x4), LBackendSlotPrefix + 'CmpGeU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU32x4), LBackendSlotPrefix + 'MinU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU32x4), LBackendSlotPrefix + 'MaxU32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU16x8), LBackendSlotPrefix + 'AddU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU16x8), LBackendSlotPrefix + 'SubU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MulU16x8), LBackendSlotPrefix + 'MulU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU16x8), LBackendSlotPrefix + 'AndU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU16x8), LBackendSlotPrefix + 'OrU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU16x8), LBackendSlotPrefix + 'XorU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU16x8), LBackendSlotPrefix + 'NotU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftLeftU16x8), LBackendSlotPrefix + 'ShiftLeftU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.ShiftRightU16x8), LBackendSlotPrefix + 'ShiftRightU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU16x8), LBackendSlotPrefix + 'CmpEqU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU16x8), LBackendSlotPrefix + 'CmpLtU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU16x8), LBackendSlotPrefix + 'CmpGtU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU16x8), LBackendSlotPrefix + 'CmpLeU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU16x8), LBackendSlotPrefix + 'CmpGeU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeU16x8), LBackendSlotPrefix + 'CmpNeU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU16x8), LBackendSlotPrefix + 'MinU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU16x8), LBackendSlotPrefix + 'MaxU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AddU8x16), LBackendSlotPrefix + 'AddU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SubU8x16), LBackendSlotPrefix + 'SubU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndU8x16), LBackendSlotPrefix + 'AndU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.OrU8x16), LBackendSlotPrefix + 'OrU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.XorU8x16), LBackendSlotPrefix + 'XorU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.NotU8x16), LBackendSlotPrefix + 'NotU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpEqU8x16), LBackendSlotPrefix + 'CmpEqU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLtU8x16), LBackendSlotPrefix + 'CmpLtU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGtU8x16), LBackendSlotPrefix + 'CmpGtU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpLeU8x16), LBackendSlotPrefix + 'CmpLeU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpGeU8x16), LBackendSlotPrefix + 'CmpGeU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.CmpNeU8x16), LBackendSlotPrefix + 'CmpNeU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MinU8x16), LBackendSlotPrefix + 'MinU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.MaxU8x16), LBackendSlotPrefix + 'MaxU8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask2All), LBackendSlotPrefix + 'Mask2All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask2Any), LBackendSlotPrefix + 'Mask2Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask2None), LBackendSlotPrefix + 'Mask2None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask2PopCount), LBackendSlotPrefix + 'Mask2PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask2FirstSet), LBackendSlotPrefix + 'Mask2FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask4All), LBackendSlotPrefix + 'Mask4All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask4Any), LBackendSlotPrefix + 'Mask4Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask4None), LBackendSlotPrefix + 'Mask4None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask4PopCount), LBackendSlotPrefix + 'Mask4PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask4FirstSet), LBackendSlotPrefix + 'Mask4FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask8All), LBackendSlotPrefix + 'Mask8All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask8Any), LBackendSlotPrefix + 'Mask8Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask8None), LBackendSlotPrefix + 'Mask8None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask8PopCount), LBackendSlotPrefix + 'Mask8PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask8FirstSet), LBackendSlotPrefix + 'Mask8FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask16All), LBackendSlotPrefix + 'Mask16All should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask16Any), LBackendSlotPrefix + 'Mask16Any should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask16None), LBackendSlotPrefix + 'Mask16None should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask16PopCount), LBackendSlotPrefix + 'Mask16PopCount should be assigned');
  CheckTrue(Assigned(aDispatch^.Mask.Mask16FirstSet), LBackendSlotPrefix + 'Mask16FirstSet should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectF64x2), LBackendSlotPrefix + 'SelectF64x2 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectF32x16), LBackendSlotPrefix + 'SelectF32x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectF64x8), LBackendSlotPrefix + 'SelectF64x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectI32x4), LBackendSlotPrefix + 'SelectI32x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectF32x8), LBackendSlotPrefix + 'SelectF32x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.SelectF64x4), LBackendSlotPrefix + 'SelectF64x4 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotI8x16), LBackendSlotPrefix + 'AndNotI8x16 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotU16x8), LBackendSlotPrefix + 'AndNotU16x8 should be assigned');
  CheckTrue(Assigned(aDispatch^.CoreVectors.AndNotU8x16), LBackendSlotPrefix + 'AndNotU8x16 should be assigned');

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
    CheckTrue(LSourceTable.CoreVectors.AddF32x4 = LRoundTripTable.CoreVectors.AddF32x4, 'AddF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.MulF32x4 = LRoundTripTable.CoreVectors.MulF32x4, 'MulF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.RoundF32x4 = LRoundTripTable.CoreVectors.RoundF32x4, 'RoundF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.TruncF32x4 = LRoundTripTable.CoreVectors.TruncF32x4, 'TruncF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.AddI32x4 = LRoundTripTable.CoreVectors.AddI32x4, 'AddI32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.AndI32x4 = LRoundTripTable.CoreVectors.AndI32x4, 'AndI32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.LoadF32x4 = LRoundTripTable.CoreVectors.LoadF32x4, 'LoadF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.CoreVectors.StoreF32x4 = LRoundTripTable.CoreVectors.StoreF32x4, 'StoreF32x4 pointer changed after roundtrip');
    CheckTrue(LSourceTable.Memory.Equal = LRoundTripTable.Memory.Equal, 'MemEqual pointer changed after roundtrip');
    CheckTrue(LSourceTable.Memory.BitsetPopCount = LRoundTripTable.Memory.BitsetPopCount, 'BitsetPopCount pointer changed after roundtrip');

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

  CheckEqual(PtrUInt(LSSE41.CoreVectors.MulI32x4), PtrUInt(LSSE42.CoreVectors.MulI32x4), 'SSE4.2 should inherit SSE4.1 MulI32x4');
  CheckEqual(PtrUInt(LSSE41.CoreVectors.DotF32x4), PtrUInt(LSSE42.CoreVectors.DotF32x4), 'SSE4.2 should inherit SSE4.1 DotF32x4');
  CheckEqual(PtrUInt(LSSE41.CoreVectors.RoundF32x4), PtrUInt(LSSE42.CoreVectors.RoundF32x4), 'SSE4.2 should inherit SSE4.1 RoundF32x4');
  CheckEqual(PtrUInt(LSSE41.CoreVectors.SelectF32x4), PtrUInt(LSSE42.CoreVectors.SelectF32x4), 'SSE4.2 should inherit SSE4.1 SelectF32x4');
end;


end.