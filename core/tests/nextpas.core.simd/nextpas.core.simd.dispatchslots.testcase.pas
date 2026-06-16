unit nextpas.core.simd.dispatchslots.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, fpcunit, testregistry,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.iface,
  nextpas.core.simd.backend.adapter;

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
  AssertNotNull('Dispatch table should be available', aDispatch);
  LBackendSlotPrefix := 'Backend=' + DispatchSlotsBackendName(aBackend) + ' slot ';

  AssertTrue(LBackendSlotPrefix + 'AddF32x4 should be assigned', Assigned(aDispatch^.AddF32x4));
  AssertTrue(LBackendSlotPrefix + 'SubF32x4 should be assigned', Assigned(aDispatch^.SubF32x4));
  AssertTrue(LBackendSlotPrefix + 'MulF32x4 should be assigned', Assigned(aDispatch^.MulF32x4));
  AssertTrue(LBackendSlotPrefix + 'DivF32x4 should be assigned', Assigned(aDispatch^.DivF32x4));
  AssertTrue(LBackendSlotPrefix + 'AddF32x8 should be assigned', Assigned(aDispatch^.AddF32x8));
  AssertTrue(LBackendSlotPrefix + 'SubF32x8 should be assigned', Assigned(aDispatch^.SubF32x8));
  AssertTrue(LBackendSlotPrefix + 'MulF32x8 should be assigned', Assigned(aDispatch^.MulF32x8));
  AssertTrue(LBackendSlotPrefix + 'DivF32x8 should be assigned', Assigned(aDispatch^.DivF32x8));
  AssertTrue(LBackendSlotPrefix + 'AddF64x2 should be assigned', Assigned(aDispatch^.AddF64x2));
  AssertTrue(LBackendSlotPrefix + 'SubF64x2 should be assigned', Assigned(aDispatch^.SubF64x2));
  AssertTrue(LBackendSlotPrefix + 'MulF64x2 should be assigned', Assigned(aDispatch^.MulF64x2));
  AssertTrue(LBackendSlotPrefix + 'DivF64x2 should be assigned', Assigned(aDispatch^.DivF64x2));
  AssertTrue(LBackendSlotPrefix + 'AddI32x4 should be assigned', Assigned(aDispatch^.AddI32x4));
  AssertTrue(LBackendSlotPrefix + 'SubI32x4 should be assigned', Assigned(aDispatch^.SubI32x4));
  AssertTrue(LBackendSlotPrefix + 'MulI32x4 should be assigned', Assigned(aDispatch^.MulI32x4));
  AssertTrue(LBackendSlotPrefix + 'AndI32x4 should be assigned', Assigned(aDispatch^.AndI32x4));
  AssertTrue(LBackendSlotPrefix + 'OrI32x4 should be assigned', Assigned(aDispatch^.OrI32x4));
  AssertTrue(LBackendSlotPrefix + 'XorI32x4 should be assigned', Assigned(aDispatch^.XorI32x4));
  AssertTrue(LBackendSlotPrefix + 'NotI32x4 should be assigned', Assigned(aDispatch^.NotI32x4));
  AssertTrue(LBackendSlotPrefix + 'AndNotI32x4 should be assigned', Assigned(aDispatch^.AndNotI32x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI32x4 should be assigned', Assigned(aDispatch^.ShiftLeftI32x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI32x4 should be assigned', Assigned(aDispatch^.ShiftRightI32x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightArithI32x4 should be assigned', Assigned(aDispatch^.ShiftRightArithI32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI32x4 should be assigned', Assigned(aDispatch^.CmpEqI32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI32x4 should be assigned', Assigned(aDispatch^.CmpLtI32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI32x4 should be assigned', Assigned(aDispatch^.CmpGtI32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI32x4 should be assigned', Assigned(aDispatch^.CmpLeI32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI32x4 should be assigned', Assigned(aDispatch^.CmpGeI32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI32x4 should be assigned', Assigned(aDispatch^.CmpNeI32x4));
  AssertTrue(LBackendSlotPrefix + 'MinI32x4 should be assigned', Assigned(aDispatch^.MinI32x4));
  AssertTrue(LBackendSlotPrefix + 'MaxI32x4 should be assigned', Assigned(aDispatch^.MaxI32x4));
  AssertTrue(LBackendSlotPrefix + 'AddI64x2 should be assigned', Assigned(aDispatch^.AddI64x2));
  AssertTrue(LBackendSlotPrefix + 'SubI64x2 should be assigned', Assigned(aDispatch^.SubI64x2));
  AssertTrue(LBackendSlotPrefix + 'AndI64x2 should be assigned', Assigned(aDispatch^.AndI64x2));
  AssertTrue(LBackendSlotPrefix + 'OrI64x2 should be assigned', Assigned(aDispatch^.OrI64x2));
  AssertTrue(LBackendSlotPrefix + 'XorI64x2 should be assigned', Assigned(aDispatch^.XorI64x2));
  AssertTrue(LBackendSlotPrefix + 'NotI64x2 should be assigned', Assigned(aDispatch^.NotI64x2));
  AssertTrue(LBackendSlotPrefix + 'AndNotI64x2 should be assigned', Assigned(aDispatch^.AndNotI64x2));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI64x2 should be assigned', Assigned(aDispatch^.ShiftLeftI64x2));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI64x2 should be assigned', Assigned(aDispatch^.ShiftRightI64x2));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightArithI64x2 should be assigned', Assigned(aDispatch^.ShiftRightArithI64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI64x2 should be assigned', Assigned(aDispatch^.CmpEqI64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI64x2 should be assigned', Assigned(aDispatch^.CmpLtI64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI64x2 should be assigned', Assigned(aDispatch^.CmpGtI64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI64x2 should be assigned', Assigned(aDispatch^.CmpLeI64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI64x2 should be assigned', Assigned(aDispatch^.CmpGeI64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI64x2 should be assigned', Assigned(aDispatch^.CmpNeI64x2));
  AssertTrue(LBackendSlotPrefix + 'MinI64x2 should be assigned', Assigned(aDispatch^.MinI64x2));
  AssertTrue(LBackendSlotPrefix + 'MaxI64x2 should be assigned', Assigned(aDispatch^.MaxI64x2));
  AssertTrue(LBackendSlotPrefix + 'AddU64x2 should be assigned', Assigned(aDispatch^.AddU64x2));
  AssertTrue(LBackendSlotPrefix + 'SubU64x2 should be assigned', Assigned(aDispatch^.SubU64x2));
  AssertTrue(LBackendSlotPrefix + 'AndU64x2 should be assigned', Assigned(aDispatch^.AndU64x2));
  AssertTrue(LBackendSlotPrefix + 'OrU64x2 should be assigned', Assigned(aDispatch^.OrU64x2));
  AssertTrue(LBackendSlotPrefix + 'XorU64x2 should be assigned', Assigned(aDispatch^.XorU64x2));
  AssertTrue(LBackendSlotPrefix + 'NotU64x2 should be assigned', Assigned(aDispatch^.NotU64x2));
  AssertTrue(LBackendSlotPrefix + 'AndNotU64x2 should be assigned', Assigned(aDispatch^.AndNotU64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU64x2 should be assigned', Assigned(aDispatch^.CmpEqU64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU64x2 should be assigned', Assigned(aDispatch^.CmpLtU64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU64x2 should be assigned', Assigned(aDispatch^.CmpGtU64x2));
  AssertTrue(LBackendSlotPrefix + 'MinU64x2 should be assigned', Assigned(aDispatch^.MinU64x2));
  AssertTrue(LBackendSlotPrefix + 'MaxU64x2 should be assigned', Assigned(aDispatch^.MaxU64x2));
  AssertTrue(LBackendSlotPrefix + 'AddF64x4 should be assigned', Assigned(aDispatch^.AddF64x4));
  AssertTrue(LBackendSlotPrefix + 'SubF64x4 should be assigned', Assigned(aDispatch^.SubF64x4));
  AssertTrue(LBackendSlotPrefix + 'MulF64x4 should be assigned', Assigned(aDispatch^.MulF64x4));
  AssertTrue(LBackendSlotPrefix + 'DivF64x4 should be assigned', Assigned(aDispatch^.DivF64x4));
  AssertTrue(LBackendSlotPrefix + 'AddI32x8 should be assigned', Assigned(aDispatch^.AddI32x8));
  AssertTrue(LBackendSlotPrefix + 'SubI32x8 should be assigned', Assigned(aDispatch^.SubI32x8));
  AssertTrue(LBackendSlotPrefix + 'MulI32x8 should be assigned', Assigned(aDispatch^.MulI32x8));
  AssertTrue(LBackendSlotPrefix + 'AndI32x8 should be assigned', Assigned(aDispatch^.AndI32x8));
  AssertTrue(LBackendSlotPrefix + 'OrI32x8 should be assigned', Assigned(aDispatch^.OrI32x8));
  AssertTrue(LBackendSlotPrefix + 'XorI32x8 should be assigned', Assigned(aDispatch^.XorI32x8));
  AssertTrue(LBackendSlotPrefix + 'NotI32x8 should be assigned', Assigned(aDispatch^.NotI32x8));
  AssertTrue(LBackendSlotPrefix + 'AndNotI32x8 should be assigned', Assigned(aDispatch^.AndNotI32x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI32x8 should be assigned', Assigned(aDispatch^.ShiftLeftI32x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI32x8 should be assigned', Assigned(aDispatch^.ShiftRightI32x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightArithI32x8 should be assigned', Assigned(aDispatch^.ShiftRightArithI32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI32x8 should be assigned', Assigned(aDispatch^.CmpEqI32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI32x8 should be assigned', Assigned(aDispatch^.CmpLtI32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI32x8 should be assigned', Assigned(aDispatch^.CmpGtI32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI32x8 should be assigned', Assigned(aDispatch^.CmpLeI32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI32x8 should be assigned', Assigned(aDispatch^.CmpGeI32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI32x8 should be assigned', Assigned(aDispatch^.CmpNeI32x8));
  AssertTrue(LBackendSlotPrefix + 'MinI32x8 should be assigned', Assigned(aDispatch^.MinI32x8));
  AssertTrue(LBackendSlotPrefix + 'MaxI32x8 should be assigned', Assigned(aDispatch^.MaxI32x8));
  AssertTrue(LBackendSlotPrefix + 'AddI64x4 should be assigned', Assigned(aDispatch^.AddI64x4));
  AssertTrue(LBackendSlotPrefix + 'SubI64x4 should be assigned', Assigned(aDispatch^.SubI64x4));
  AssertTrue(LBackendSlotPrefix + 'AndI64x4 should be assigned', Assigned(aDispatch^.AndI64x4));
  AssertTrue(LBackendSlotPrefix + 'OrI64x4 should be assigned', Assigned(aDispatch^.OrI64x4));
  AssertTrue(LBackendSlotPrefix + 'XorI64x4 should be assigned', Assigned(aDispatch^.XorI64x4));
  AssertTrue(LBackendSlotPrefix + 'NotI64x4 should be assigned', Assigned(aDispatch^.NotI64x4));
  AssertTrue(LBackendSlotPrefix + 'AndNotI64x4 should be assigned', Assigned(aDispatch^.AndNotI64x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI64x4 should be assigned', Assigned(aDispatch^.ShiftLeftI64x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI64x4 should be assigned', Assigned(aDispatch^.ShiftRightI64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI64x4 should be assigned', Assigned(aDispatch^.CmpEqI64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI64x4 should be assigned', Assigned(aDispatch^.CmpLtI64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI64x4 should be assigned', Assigned(aDispatch^.CmpGtI64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI64x4 should be assigned', Assigned(aDispatch^.CmpLeI64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI64x4 should be assigned', Assigned(aDispatch^.CmpGeI64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI64x4 should be assigned', Assigned(aDispatch^.CmpNeI64x4));
  AssertTrue(LBackendSlotPrefix + 'LoadI64x4 should be assigned', Assigned(aDispatch^.LoadI64x4));
  AssertTrue(LBackendSlotPrefix + 'StoreI64x4 should be assigned', Assigned(aDispatch^.StoreI64x4));
  AssertTrue(LBackendSlotPrefix + 'SplatI64x4 should be assigned', Assigned(aDispatch^.SplatI64x4));
  AssertTrue(LBackendSlotPrefix + 'ZeroI64x4 should be assigned', Assigned(aDispatch^.ZeroI64x4));
  AssertTrue(LBackendSlotPrefix + 'AddU32x8 should be assigned', Assigned(aDispatch^.AddU32x8));
  AssertTrue(LBackendSlotPrefix + 'SubU32x8 should be assigned', Assigned(aDispatch^.SubU32x8));
  AssertTrue(LBackendSlotPrefix + 'MulU32x8 should be assigned', Assigned(aDispatch^.MulU32x8));
  AssertTrue(LBackendSlotPrefix + 'AndU32x8 should be assigned', Assigned(aDispatch^.AndU32x8));
  AssertTrue(LBackendSlotPrefix + 'OrU32x8 should be assigned', Assigned(aDispatch^.OrU32x8));
  AssertTrue(LBackendSlotPrefix + 'XorU32x8 should be assigned', Assigned(aDispatch^.XorU32x8));
  AssertTrue(LBackendSlotPrefix + 'NotU32x8 should be assigned', Assigned(aDispatch^.NotU32x8));
  AssertTrue(LBackendSlotPrefix + 'AndNotU32x8 should be assigned', Assigned(aDispatch^.AndNotU32x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftU32x8 should be assigned', Assigned(aDispatch^.ShiftLeftU32x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightU32x8 should be assigned', Assigned(aDispatch^.ShiftRightU32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU32x8 should be assigned', Assigned(aDispatch^.CmpEqU32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU32x8 should be assigned', Assigned(aDispatch^.CmpLtU32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU32x8 should be assigned', Assigned(aDispatch^.CmpGtU32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU32x8 should be assigned', Assigned(aDispatch^.CmpLeU32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU32x8 should be assigned', Assigned(aDispatch^.CmpGeU32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeU32x8 should be assigned', Assigned(aDispatch^.CmpNeU32x8));
  AssertTrue(LBackendSlotPrefix + 'MinU32x8 should be assigned', Assigned(aDispatch^.MinU32x8));
  AssertTrue(LBackendSlotPrefix + 'MaxU32x8 should be assigned', Assigned(aDispatch^.MaxU32x8));
  AssertTrue(LBackendSlotPrefix + 'AddU64x4 should be assigned', Assigned(aDispatch^.AddU64x4));
  AssertTrue(LBackendSlotPrefix + 'SubU64x4 should be assigned', Assigned(aDispatch^.SubU64x4));
  AssertTrue(LBackendSlotPrefix + 'AndU64x4 should be assigned', Assigned(aDispatch^.AndU64x4));
  AssertTrue(LBackendSlotPrefix + 'OrU64x4 should be assigned', Assigned(aDispatch^.OrU64x4));
  AssertTrue(LBackendSlotPrefix + 'XorU64x4 should be assigned', Assigned(aDispatch^.XorU64x4));
  AssertTrue(LBackendSlotPrefix + 'NotU64x4 should be assigned', Assigned(aDispatch^.NotU64x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftU64x4 should be assigned', Assigned(aDispatch^.ShiftLeftU64x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightU64x4 should be assigned', Assigned(aDispatch^.ShiftRightU64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU64x4 should be assigned', Assigned(aDispatch^.CmpEqU64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU64x4 should be assigned', Assigned(aDispatch^.CmpLtU64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU64x4 should be assigned', Assigned(aDispatch^.CmpGtU64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU64x4 should be assigned', Assigned(aDispatch^.CmpLeU64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU64x4 should be assigned', Assigned(aDispatch^.CmpGeU64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpNeU64x4 should be assigned', Assigned(aDispatch^.CmpNeU64x4));
  AssertTrue(LBackendSlotPrefix + 'RcpF64x4 should be assigned', Assigned(aDispatch^.RcpF64x4));
  AssertTrue(LBackendSlotPrefix + 'AddI32x16 should be assigned', Assigned(aDispatch^.AddI32x16));
  AssertTrue(LBackendSlotPrefix + 'SubI32x16 should be assigned', Assigned(aDispatch^.SubI32x16));
  AssertTrue(LBackendSlotPrefix + 'MulI32x16 should be assigned', Assigned(aDispatch^.MulI32x16));
  AssertTrue(LBackendSlotPrefix + 'AndI32x16 should be assigned', Assigned(aDispatch^.AndI32x16));
  AssertTrue(LBackendSlotPrefix + 'OrI32x16 should be assigned', Assigned(aDispatch^.OrI32x16));
  AssertTrue(LBackendSlotPrefix + 'XorI32x16 should be assigned', Assigned(aDispatch^.XorI32x16));
  AssertTrue(LBackendSlotPrefix + 'NotI32x16 should be assigned', Assigned(aDispatch^.NotI32x16));
  AssertTrue(LBackendSlotPrefix + 'AndNotI32x16 should be assigned', Assigned(aDispatch^.AndNotI32x16));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI32x16 should be assigned', Assigned(aDispatch^.ShiftLeftI32x16));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI32x16 should be assigned', Assigned(aDispatch^.ShiftRightI32x16));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightArithI32x16 should be assigned', Assigned(aDispatch^.ShiftRightArithI32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI32x16 should be assigned', Assigned(aDispatch^.CmpEqI32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI32x16 should be assigned', Assigned(aDispatch^.CmpLtI32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI32x16 should be assigned', Assigned(aDispatch^.CmpGtI32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI32x16 should be assigned', Assigned(aDispatch^.CmpLeI32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI32x16 should be assigned', Assigned(aDispatch^.CmpGeI32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI32x16 should be assigned', Assigned(aDispatch^.CmpNeI32x16));
  AssertTrue(LBackendSlotPrefix + 'MinI32x16 should be assigned', Assigned(aDispatch^.MinI32x16));
  AssertTrue(LBackendSlotPrefix + 'MaxI32x16 should be assigned', Assigned(aDispatch^.MaxI32x16));
  AssertTrue(LBackendSlotPrefix + 'AddI64x8 should be assigned', Assigned(aDispatch^.AddI64x8));
  AssertTrue(LBackendSlotPrefix + 'SubI64x8 should be assigned', Assigned(aDispatch^.SubI64x8));
  AssertTrue(LBackendSlotPrefix + 'AndI64x8 should be assigned', Assigned(aDispatch^.AndI64x8));
  AssertTrue(LBackendSlotPrefix + 'OrI64x8 should be assigned', Assigned(aDispatch^.OrI64x8));
  AssertTrue(LBackendSlotPrefix + 'XorI64x8 should be assigned', Assigned(aDispatch^.XorI64x8));
  AssertTrue(LBackendSlotPrefix + 'NotI64x8 should be assigned', Assigned(aDispatch^.NotI64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI64x8 should be assigned', Assigned(aDispatch^.CmpEqI64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI64x8 should be assigned', Assigned(aDispatch^.CmpLtI64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI64x8 should be assigned', Assigned(aDispatch^.CmpGtI64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI64x8 should be assigned', Assigned(aDispatch^.CmpLeI64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI64x8 should be assigned', Assigned(aDispatch^.CmpGeI64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI64x8 should be assigned', Assigned(aDispatch^.CmpNeI64x8));
  AssertTrue(LBackendSlotPrefix + 'AddU32x16 should be assigned', Assigned(aDispatch^.AddU32x16));
  AssertTrue(LBackendSlotPrefix + 'SubU32x16 should be assigned', Assigned(aDispatch^.SubU32x16));
  AssertTrue(LBackendSlotPrefix + 'MulU32x16 should be assigned', Assigned(aDispatch^.MulU32x16));
  AssertTrue(LBackendSlotPrefix + 'AndU32x16 should be assigned', Assigned(aDispatch^.AndU32x16));
  AssertTrue(LBackendSlotPrefix + 'OrU32x16 should be assigned', Assigned(aDispatch^.OrU32x16));
  AssertTrue(LBackendSlotPrefix + 'XorU32x16 should be assigned', Assigned(aDispatch^.XorU32x16));
  AssertTrue(LBackendSlotPrefix + 'NotU32x16 should be assigned', Assigned(aDispatch^.NotU32x16));
  AssertTrue(LBackendSlotPrefix + 'AndNotU32x16 should be assigned', Assigned(aDispatch^.AndNotU32x16));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftU32x16 should be assigned', Assigned(aDispatch^.ShiftLeftU32x16));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightU32x16 should be assigned', Assigned(aDispatch^.ShiftRightU32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU32x16 should be assigned', Assigned(aDispatch^.CmpEqU32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU32x16 should be assigned', Assigned(aDispatch^.CmpLtU32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU32x16 should be assigned', Assigned(aDispatch^.CmpGtU32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU32x16 should be assigned', Assigned(aDispatch^.CmpLeU32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU32x16 should be assigned', Assigned(aDispatch^.CmpGeU32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpNeU32x16 should be assigned', Assigned(aDispatch^.CmpNeU32x16));
  AssertTrue(LBackendSlotPrefix + 'MinU32x16 should be assigned', Assigned(aDispatch^.MinU32x16));
  AssertTrue(LBackendSlotPrefix + 'MaxU32x16 should be assigned', Assigned(aDispatch^.MaxU32x16));
  AssertTrue(LBackendSlotPrefix + 'AddU64x8 should be assigned', Assigned(aDispatch^.AddU64x8));
  AssertTrue(LBackendSlotPrefix + 'SubU64x8 should be assigned', Assigned(aDispatch^.SubU64x8));
  AssertTrue(LBackendSlotPrefix + 'AndU64x8 should be assigned', Assigned(aDispatch^.AndU64x8));
  AssertTrue(LBackendSlotPrefix + 'OrU64x8 should be assigned', Assigned(aDispatch^.OrU64x8));
  AssertTrue(LBackendSlotPrefix + 'XorU64x8 should be assigned', Assigned(aDispatch^.XorU64x8));
  AssertTrue(LBackendSlotPrefix + 'NotU64x8 should be assigned', Assigned(aDispatch^.NotU64x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftU64x8 should be assigned', Assigned(aDispatch^.ShiftLeftU64x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightU64x8 should be assigned', Assigned(aDispatch^.ShiftRightU64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU64x8 should be assigned', Assigned(aDispatch^.CmpEqU64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU64x8 should be assigned', Assigned(aDispatch^.CmpLtU64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU64x8 should be assigned', Assigned(aDispatch^.CmpGtU64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU64x8 should be assigned', Assigned(aDispatch^.CmpLeU64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU64x8 should be assigned', Assigned(aDispatch^.CmpGeU64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeU64x8 should be assigned', Assigned(aDispatch^.CmpNeU64x8));
  AssertTrue(LBackendSlotPrefix + 'AddI16x32 should be assigned', Assigned(aDispatch^.AddI16x32));
  AssertTrue(LBackendSlotPrefix + 'SubI16x32 should be assigned', Assigned(aDispatch^.SubI16x32));
  AssertTrue(LBackendSlotPrefix + 'AndI16x32 should be assigned', Assigned(aDispatch^.AndI16x32));
  AssertTrue(LBackendSlotPrefix + 'OrI16x32 should be assigned', Assigned(aDispatch^.OrI16x32));
  AssertTrue(LBackendSlotPrefix + 'XorI16x32 should be assigned', Assigned(aDispatch^.XorI16x32));
  AssertTrue(LBackendSlotPrefix + 'NotI16x32 should be assigned', Assigned(aDispatch^.NotI16x32));
  AssertTrue(LBackendSlotPrefix + 'AndNotI16x32 should be assigned', Assigned(aDispatch^.AndNotI16x32));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI16x32 should be assigned', Assigned(aDispatch^.ShiftLeftI16x32));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI16x32 should be assigned', Assigned(aDispatch^.ShiftRightI16x32));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightArithI16x32 should be assigned', Assigned(aDispatch^.ShiftRightArithI16x32));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI16x32 should be assigned', Assigned(aDispatch^.CmpEqI16x32));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI16x32 should be assigned', Assigned(aDispatch^.CmpLtI16x32));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI16x32 should be assigned', Assigned(aDispatch^.CmpGtI16x32));
  AssertTrue(LBackendSlotPrefix + 'MinI16x32 should be assigned', Assigned(aDispatch^.MinI16x32));
  AssertTrue(LBackendSlotPrefix + 'MaxI16x32 should be assigned', Assigned(aDispatch^.MaxI16x32));
  AssertTrue(LBackendSlotPrefix + 'AddI8x64 should be assigned', Assigned(aDispatch^.AddI8x64));
  AssertTrue(LBackendSlotPrefix + 'SubI8x64 should be assigned', Assigned(aDispatch^.SubI8x64));
  AssertTrue(LBackendSlotPrefix + 'AndI8x64 should be assigned', Assigned(aDispatch^.AndI8x64));
  AssertTrue(LBackendSlotPrefix + 'OrI8x64 should be assigned', Assigned(aDispatch^.OrI8x64));
  AssertTrue(LBackendSlotPrefix + 'XorI8x64 should be assigned', Assigned(aDispatch^.XorI8x64));
  AssertTrue(LBackendSlotPrefix + 'NotI8x64 should be assigned', Assigned(aDispatch^.NotI8x64));
  AssertTrue(LBackendSlotPrefix + 'AndNotI8x64 should be assigned', Assigned(aDispatch^.AndNotI8x64));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI8x64 should be assigned', Assigned(aDispatch^.CmpEqI8x64));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI8x64 should be assigned', Assigned(aDispatch^.CmpLtI8x64));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI8x64 should be assigned', Assigned(aDispatch^.CmpGtI8x64));
  AssertTrue(LBackendSlotPrefix + 'MinI8x64 should be assigned', Assigned(aDispatch^.MinI8x64));
  AssertTrue(LBackendSlotPrefix + 'MaxI8x64 should be assigned', Assigned(aDispatch^.MaxI8x64));
  AssertTrue(LBackendSlotPrefix + 'AddU8x64 should be assigned', Assigned(aDispatch^.AddU8x64));
  AssertTrue(LBackendSlotPrefix + 'SubU8x64 should be assigned', Assigned(aDispatch^.SubU8x64));
  AssertTrue(LBackendSlotPrefix + 'AndU8x64 should be assigned', Assigned(aDispatch^.AndU8x64));
  AssertTrue(LBackendSlotPrefix + 'OrU8x64 should be assigned', Assigned(aDispatch^.OrU8x64));
  AssertTrue(LBackendSlotPrefix + 'XorU8x64 should be assigned', Assigned(aDispatch^.XorU8x64));
  AssertTrue(LBackendSlotPrefix + 'NotU8x64 should be assigned', Assigned(aDispatch^.NotU8x64));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU8x64 should be assigned', Assigned(aDispatch^.CmpEqU8x64));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU8x64 should be assigned', Assigned(aDispatch^.CmpLtU8x64));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU8x64 should be assigned', Assigned(aDispatch^.CmpGtU8x64));
  AssertTrue(LBackendSlotPrefix + 'MinU8x64 should be assigned', Assigned(aDispatch^.MinU8x64));
  AssertTrue(LBackendSlotPrefix + 'MaxU8x64 should be assigned', Assigned(aDispatch^.MaxU8x64));
  AssertTrue(LBackendSlotPrefix + 'AddF32x16 should be assigned', Assigned(aDispatch^.AddF32x16));
  AssertTrue(LBackendSlotPrefix + 'SubF32x16 should be assigned', Assigned(aDispatch^.SubF32x16));
  AssertTrue(LBackendSlotPrefix + 'MulF32x16 should be assigned', Assigned(aDispatch^.MulF32x16));
  AssertTrue(LBackendSlotPrefix + 'DivF32x16 should be assigned', Assigned(aDispatch^.DivF32x16));
  AssertTrue(LBackendSlotPrefix + 'AddF64x8 should be assigned', Assigned(aDispatch^.AddF64x8));
  AssertTrue(LBackendSlotPrefix + 'SubF64x8 should be assigned', Assigned(aDispatch^.SubF64x8));
  AssertTrue(LBackendSlotPrefix + 'MulF64x8 should be assigned', Assigned(aDispatch^.MulF64x8));
  AssertTrue(LBackendSlotPrefix + 'DivF64x8 should be assigned', Assigned(aDispatch^.DivF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqF32x4 should be assigned', Assigned(aDispatch^.CmpEqF32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLtF32x4 should be assigned', Assigned(aDispatch^.CmpLtF32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLeF32x4 should be assigned', Assigned(aDispatch^.CmpLeF32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGtF32x4 should be assigned', Assigned(aDispatch^.CmpGtF32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGeF32x4 should be assigned', Assigned(aDispatch^.CmpGeF32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpNeF32x4 should be assigned', Assigned(aDispatch^.CmpNeF32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpEqF64x2 should be assigned', Assigned(aDispatch^.CmpEqF64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpLtF64x2 should be assigned', Assigned(aDispatch^.CmpLtF64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpLeF64x2 should be assigned', Assigned(aDispatch^.CmpLeF64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpGtF64x2 should be assigned', Assigned(aDispatch^.CmpGtF64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpGeF64x2 should be assigned', Assigned(aDispatch^.CmpGeF64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpNeF64x2 should be assigned', Assigned(aDispatch^.CmpNeF64x2));
  AssertTrue(LBackendSlotPrefix + 'CmpEqF32x16 should be assigned', Assigned(aDispatch^.CmpEqF32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLtF32x16 should be assigned', Assigned(aDispatch^.CmpLtF32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLeF32x16 should be assigned', Assigned(aDispatch^.CmpLeF32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGtF32x16 should be assigned', Assigned(aDispatch^.CmpGtF32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGeF32x16 should be assigned', Assigned(aDispatch^.CmpGeF32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpNeF32x16 should be assigned', Assigned(aDispatch^.CmpNeF32x16));
  AssertTrue(LBackendSlotPrefix + 'CmpEqF64x8 should be assigned', Assigned(aDispatch^.CmpEqF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtF64x8 should be assigned', Assigned(aDispatch^.CmpLtF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeF64x8 should be assigned', Assigned(aDispatch^.CmpLeF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtF64x8 should be assigned', Assigned(aDispatch^.CmpGtF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeF64x8 should be assigned', Assigned(aDispatch^.CmpGeF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeF64x8 should be assigned', Assigned(aDispatch^.CmpNeF64x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqF32x8 should be assigned', Assigned(aDispatch^.CmpEqF32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtF32x8 should be assigned', Assigned(aDispatch^.CmpLtF32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeF32x8 should be assigned', Assigned(aDispatch^.CmpLeF32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtF32x8 should be assigned', Assigned(aDispatch^.CmpGtF32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeF32x8 should be assigned', Assigned(aDispatch^.CmpGeF32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeF32x8 should be assigned', Assigned(aDispatch^.CmpNeF32x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqF64x4 should be assigned', Assigned(aDispatch^.CmpEqF64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLtF64x4 should be assigned', Assigned(aDispatch^.CmpLtF64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLeF64x4 should be assigned', Assigned(aDispatch^.CmpLeF64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGtF64x4 should be assigned', Assigned(aDispatch^.CmpGtF64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGeF64x4 should be assigned', Assigned(aDispatch^.CmpGeF64x4));
  AssertTrue(LBackendSlotPrefix + 'CmpNeF64x4 should be assigned', Assigned(aDispatch^.CmpNeF64x4));
  AssertTrue(LBackendSlotPrefix + 'AbsF32x4 should be assigned', Assigned(aDispatch^.AbsF32x4));
  AssertTrue(LBackendSlotPrefix + 'SqrtF32x4 should be assigned', Assigned(aDispatch^.SqrtF32x4));
  AssertTrue(LBackendSlotPrefix + 'MinF32x4 should be assigned', Assigned(aDispatch^.MinF32x4));
  AssertTrue(LBackendSlotPrefix + 'MaxF32x4 should be assigned', Assigned(aDispatch^.MaxF32x4));
  AssertTrue(LBackendSlotPrefix + 'FmaF32x4 should be assigned', Assigned(aDispatch^.FmaF32x4));
  AssertTrue(LBackendSlotPrefix + 'RcpF32x4 should be assigned', Assigned(aDispatch^.RcpF32x4));
  AssertTrue(LBackendSlotPrefix + 'RsqrtF32x4 should be assigned', Assigned(aDispatch^.RsqrtF32x4));
  AssertTrue(LBackendSlotPrefix + 'FloorF32x4 should be assigned', Assigned(aDispatch^.FloorF32x4));
  AssertTrue(LBackendSlotPrefix + 'CeilF32x4 should be assigned', Assigned(aDispatch^.CeilF32x4));
  AssertTrue(LBackendSlotPrefix + 'RoundF32x4 should be assigned', Assigned(aDispatch^.RoundF32x4));
  AssertTrue(LBackendSlotPrefix + 'TruncF32x4 should be assigned', Assigned(aDispatch^.TruncF32x4));
  AssertTrue(LBackendSlotPrefix + 'ClampF32x4 should be assigned', Assigned(aDispatch^.ClampF32x4));
  AssertTrue(LBackendSlotPrefix + 'FmaF64x2 should be assigned', Assigned(aDispatch^.FmaF64x2));
  AssertTrue(LBackendSlotPrefix + 'FloorF64x2 should be assigned', Assigned(aDispatch^.FloorF64x2));
  AssertTrue(LBackendSlotPrefix + 'CeilF64x2 should be assigned', Assigned(aDispatch^.CeilF64x2));
  AssertTrue(LBackendSlotPrefix + 'RoundF64x2 should be assigned', Assigned(aDispatch^.RoundF64x2));
  AssertTrue(LBackendSlotPrefix + 'TruncF64x2 should be assigned', Assigned(aDispatch^.TruncF64x2));
  AssertTrue(LBackendSlotPrefix + 'AbsF64x2 should be assigned', Assigned(aDispatch^.AbsF64x2));
  AssertTrue(LBackendSlotPrefix + 'SqrtF64x2 should be assigned', Assigned(aDispatch^.SqrtF64x2));
  AssertTrue(LBackendSlotPrefix + 'MinF64x2 should be assigned', Assigned(aDispatch^.MinF64x2));
  AssertTrue(LBackendSlotPrefix + 'MaxF64x2 should be assigned', Assigned(aDispatch^.MaxF64x2));
  AssertTrue(LBackendSlotPrefix + 'ClampF64x2 should be assigned', Assigned(aDispatch^.ClampF64x2));
  AssertTrue(LBackendSlotPrefix + 'FmaF32x8 should be assigned', Assigned(aDispatch^.FmaF32x8));
  AssertTrue(LBackendSlotPrefix + 'FloorF32x8 should be assigned', Assigned(aDispatch^.FloorF32x8));
  AssertTrue(LBackendSlotPrefix + 'CeilF32x8 should be assigned', Assigned(aDispatch^.CeilF32x8));
  AssertTrue(LBackendSlotPrefix + 'RoundF32x8 should be assigned', Assigned(aDispatch^.RoundF32x8));
  AssertTrue(LBackendSlotPrefix + 'TruncF32x8 should be assigned', Assigned(aDispatch^.TruncF32x8));
  AssertTrue(LBackendSlotPrefix + 'AbsF32x8 should be assigned', Assigned(aDispatch^.AbsF32x8));
  AssertTrue(LBackendSlotPrefix + 'SqrtF32x8 should be assigned', Assigned(aDispatch^.SqrtF32x8));
  AssertTrue(LBackendSlotPrefix + 'MinF32x8 should be assigned', Assigned(aDispatch^.MinF32x8));
  AssertTrue(LBackendSlotPrefix + 'MaxF32x8 should be assigned', Assigned(aDispatch^.MaxF32x8));
  AssertTrue(LBackendSlotPrefix + 'ClampF32x8 should be assigned', Assigned(aDispatch^.ClampF32x8));
  AssertTrue(LBackendSlotPrefix + 'FmaF64x4 should be assigned', Assigned(aDispatch^.FmaF64x4));
  AssertTrue(LBackendSlotPrefix + 'FloorF64x4 should be assigned', Assigned(aDispatch^.FloorF64x4));
  AssertTrue(LBackendSlotPrefix + 'CeilF64x4 should be assigned', Assigned(aDispatch^.CeilF64x4));
  AssertTrue(LBackendSlotPrefix + 'RoundF64x4 should be assigned', Assigned(aDispatch^.RoundF64x4));
  AssertTrue(LBackendSlotPrefix + 'TruncF64x4 should be assigned', Assigned(aDispatch^.TruncF64x4));
  AssertTrue(LBackendSlotPrefix + 'FmaF32x16 should be assigned', Assigned(aDispatch^.FmaF32x16));
  AssertTrue(LBackendSlotPrefix + 'FloorF32x16 should be assigned', Assigned(aDispatch^.FloorF32x16));
  AssertTrue(LBackendSlotPrefix + 'CeilF32x16 should be assigned', Assigned(aDispatch^.CeilF32x16));
  AssertTrue(LBackendSlotPrefix + 'RoundF32x16 should be assigned', Assigned(aDispatch^.RoundF32x16));
  AssertTrue(LBackendSlotPrefix + 'TruncF32x16 should be assigned', Assigned(aDispatch^.TruncF32x16));
  AssertTrue(LBackendSlotPrefix + 'FmaF64x8 should be assigned', Assigned(aDispatch^.FmaF64x8));
  AssertTrue(LBackendSlotPrefix + 'FloorF64x8 should be assigned', Assigned(aDispatch^.FloorF64x8));
  AssertTrue(LBackendSlotPrefix + 'CeilF64x8 should be assigned', Assigned(aDispatch^.CeilF64x8));
  AssertTrue(LBackendSlotPrefix + 'RoundF64x8 should be assigned', Assigned(aDispatch^.RoundF64x8));
  AssertTrue(LBackendSlotPrefix + 'TruncF64x8 should be assigned', Assigned(aDispatch^.TruncF64x8));
  AssertTrue(LBackendSlotPrefix + 'AbsF64x4 should be assigned', Assigned(aDispatch^.AbsF64x4));
  AssertTrue(LBackendSlotPrefix + 'SqrtF64x4 should be assigned', Assigned(aDispatch^.SqrtF64x4));
  AssertTrue(LBackendSlotPrefix + 'MinF64x4 should be assigned', Assigned(aDispatch^.MinF64x4));
  AssertTrue(LBackendSlotPrefix + 'MaxF64x4 should be assigned', Assigned(aDispatch^.MaxF64x4));
  AssertTrue(LBackendSlotPrefix + 'ClampF64x4 should be assigned', Assigned(aDispatch^.ClampF64x4));
  AssertTrue(LBackendSlotPrefix + 'AbsF32x16 should be assigned', Assigned(aDispatch^.AbsF32x16));
  AssertTrue(LBackendSlotPrefix + 'SqrtF32x16 should be assigned', Assigned(aDispatch^.SqrtF32x16));
  AssertTrue(LBackendSlotPrefix + 'MinF32x16 should be assigned', Assigned(aDispatch^.MinF32x16));
  AssertTrue(LBackendSlotPrefix + 'MaxF32x16 should be assigned', Assigned(aDispatch^.MaxF32x16));
  AssertTrue(LBackendSlotPrefix + 'ClampF32x16 should be assigned', Assigned(aDispatch^.ClampF32x16));
  AssertTrue(LBackendSlotPrefix + 'AbsF64x8 should be assigned', Assigned(aDispatch^.AbsF64x8));
  AssertTrue(LBackendSlotPrefix + 'SqrtF64x8 should be assigned', Assigned(aDispatch^.SqrtF64x8));
  AssertTrue(LBackendSlotPrefix + 'MinF64x8 should be assigned', Assigned(aDispatch^.MinF64x8));
  AssertTrue(LBackendSlotPrefix + 'MaxF64x8 should be assigned', Assigned(aDispatch^.MaxF64x8));
  AssertTrue(LBackendSlotPrefix + 'ClampF64x8 should be assigned', Assigned(aDispatch^.ClampF64x8));
  AssertTrue(LBackendSlotPrefix + 'DotF32x4 should be assigned', Assigned(aDispatch^.DotF32x4));
  AssertTrue(LBackendSlotPrefix + 'DotF32x3 should be assigned', Assigned(aDispatch^.DotF32x3));
  AssertTrue(LBackendSlotPrefix + 'CrossF32x3 should be assigned', Assigned(aDispatch^.CrossF32x3));
  AssertTrue(LBackendSlotPrefix + 'LengthF32x4 should be assigned', Assigned(aDispatch^.LengthF32x4));
  AssertTrue(LBackendSlotPrefix + 'LengthF32x3 should be assigned', Assigned(aDispatch^.LengthF32x3));
  AssertTrue(LBackendSlotPrefix + 'NormalizeF32x4 should be assigned', Assigned(aDispatch^.NormalizeF32x4));
  AssertTrue(LBackendSlotPrefix + 'NormalizeF32x3 should be assigned', Assigned(aDispatch^.NormalizeF32x3));
  AssertTrue(LBackendSlotPrefix + 'DotF32x8 should be assigned', Assigned(aDispatch^.DotF32x8));
  AssertTrue(LBackendSlotPrefix + 'DotF64x2 should be assigned', Assigned(aDispatch^.DotF64x2));
  AssertTrue(LBackendSlotPrefix + 'DotF64x4 should be assigned', Assigned(aDispatch^.DotF64x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceAddF32x4 should be assigned', Assigned(aDispatch^.ReduceAddF32x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceMinF32x4 should be assigned', Assigned(aDispatch^.ReduceMinF32x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceMaxF32x4 should be assigned', Assigned(aDispatch^.ReduceMaxF32x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceMulF32x4 should be assigned', Assigned(aDispatch^.ReduceMulF32x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceAddF64x2 should be assigned', Assigned(aDispatch^.ReduceAddF64x2));
  AssertTrue(LBackendSlotPrefix + 'ReduceMinF64x2 should be assigned', Assigned(aDispatch^.ReduceMinF64x2));
  AssertTrue(LBackendSlotPrefix + 'ReduceMaxF64x2 should be assigned', Assigned(aDispatch^.ReduceMaxF64x2));
  AssertTrue(LBackendSlotPrefix + 'ReduceMulF64x2 should be assigned', Assigned(aDispatch^.ReduceMulF64x2));
  AssertTrue(LBackendSlotPrefix + 'ReduceAddF32x8 should be assigned', Assigned(aDispatch^.ReduceAddF32x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceMinF32x8 should be assigned', Assigned(aDispatch^.ReduceMinF32x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceMaxF32x8 should be assigned', Assigned(aDispatch^.ReduceMaxF32x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceMulF32x8 should be assigned', Assigned(aDispatch^.ReduceMulF32x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceAddF64x4 should be assigned', Assigned(aDispatch^.ReduceAddF64x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceMinF64x4 should be assigned', Assigned(aDispatch^.ReduceMinF64x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceMaxF64x4 should be assigned', Assigned(aDispatch^.ReduceMaxF64x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceMulF64x4 should be assigned', Assigned(aDispatch^.ReduceMulF64x4));
  AssertTrue(LBackendSlotPrefix + 'ReduceAddF32x16 should be assigned', Assigned(aDispatch^.ReduceAddF32x16));
  AssertTrue(LBackendSlotPrefix + 'ReduceMinF32x16 should be assigned', Assigned(aDispatch^.ReduceMinF32x16));
  AssertTrue(LBackendSlotPrefix + 'ReduceMaxF32x16 should be assigned', Assigned(aDispatch^.ReduceMaxF32x16));
  AssertTrue(LBackendSlotPrefix + 'ReduceMulF32x16 should be assigned', Assigned(aDispatch^.ReduceMulF32x16));
  AssertTrue(LBackendSlotPrefix + 'ReduceAddF64x8 should be assigned', Assigned(aDispatch^.ReduceAddF64x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceMinF64x8 should be assigned', Assigned(aDispatch^.ReduceMinF64x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceMaxF64x8 should be assigned', Assigned(aDispatch^.ReduceMaxF64x8));
  AssertTrue(LBackendSlotPrefix + 'ReduceMulF64x8 should be assigned', Assigned(aDispatch^.ReduceMulF64x8));
  AssertTrue(LBackendSlotPrefix + 'LoadF32x4 should be assigned', Assigned(aDispatch^.LoadF32x4));
  AssertTrue(LBackendSlotPrefix + 'LoadF32x4Aligned should be assigned', Assigned(aDispatch^.LoadF32x4Aligned));
  AssertTrue(LBackendSlotPrefix + 'StoreF32x4 should be assigned', Assigned(aDispatch^.StoreF32x4));
  AssertTrue(LBackendSlotPrefix + 'StoreF32x4Aligned should be assigned', Assigned(aDispatch^.StoreF32x4Aligned));
  AssertTrue(LBackendSlotPrefix + 'SplatF32x4 should be assigned', Assigned(aDispatch^.SplatF32x4));
  AssertTrue(LBackendSlotPrefix + 'ZeroF32x4 should be assigned', Assigned(aDispatch^.ZeroF32x4));
  AssertTrue(LBackendSlotPrefix + 'SelectF32x4 should be assigned', Assigned(aDispatch^.SelectF32x4));
  AssertTrue(LBackendSlotPrefix + 'ExtractF32x4 should be assigned', Assigned(aDispatch^.ExtractF32x4));
  AssertTrue(LBackendSlotPrefix + 'InsertF32x4 should be assigned', Assigned(aDispatch^.InsertF32x4));
  AssertTrue(LBackendSlotPrefix + 'ExtractF64x2 should be assigned', Assigned(aDispatch^.ExtractF64x2));
  AssertTrue(LBackendSlotPrefix + 'InsertF64x2 should be assigned', Assigned(aDispatch^.InsertF64x2));
  AssertTrue(LBackendSlotPrefix + 'ExtractI32x4 should be assigned', Assigned(aDispatch^.ExtractI32x4));
  AssertTrue(LBackendSlotPrefix + 'InsertI32x4 should be assigned', Assigned(aDispatch^.InsertI32x4));
  AssertTrue(LBackendSlotPrefix + 'ExtractI64x2 should be assigned', Assigned(aDispatch^.ExtractI64x2));
  AssertTrue(LBackendSlotPrefix + 'InsertI64x2 should be assigned', Assigned(aDispatch^.InsertI64x2));
  AssertTrue(LBackendSlotPrefix + 'ExtractF32x8 should be assigned', Assigned(aDispatch^.ExtractF32x8));
  AssertTrue(LBackendSlotPrefix + 'InsertF32x8 should be assigned', Assigned(aDispatch^.InsertF32x8));
  AssertTrue(LBackendSlotPrefix + 'ExtractF64x4 should be assigned', Assigned(aDispatch^.ExtractF64x4));
  AssertTrue(LBackendSlotPrefix + 'InsertF64x4 should be assigned', Assigned(aDispatch^.InsertF64x4));
  AssertTrue(LBackendSlotPrefix + 'ExtractI32x8 should be assigned', Assigned(aDispatch^.ExtractI32x8));
  AssertTrue(LBackendSlotPrefix + 'InsertI32x8 should be assigned', Assigned(aDispatch^.InsertI32x8));
  AssertTrue(LBackendSlotPrefix + 'ExtractI64x4 should be assigned', Assigned(aDispatch^.ExtractI64x4));
  AssertTrue(LBackendSlotPrefix + 'InsertI64x4 should be assigned', Assigned(aDispatch^.InsertI64x4));
  AssertTrue(LBackendSlotPrefix + 'ExtractF32x16 should be assigned', Assigned(aDispatch^.ExtractF32x16));
  AssertTrue(LBackendSlotPrefix + 'InsertF32x16 should be assigned', Assigned(aDispatch^.InsertF32x16));
  AssertTrue(LBackendSlotPrefix + 'ExtractI32x16 should be assigned', Assigned(aDispatch^.ExtractI32x16));
  AssertTrue(LBackendSlotPrefix + 'InsertI32x16 should be assigned', Assigned(aDispatch^.InsertI32x16));
  AssertTrue(LBackendSlotPrefix + 'LoadF64x2 should be assigned', Assigned(aDispatch^.LoadF64x2));
  AssertTrue(LBackendSlotPrefix + 'StoreF64x2 should be assigned', Assigned(aDispatch^.StoreF64x2));
  AssertTrue(LBackendSlotPrefix + 'SplatF64x2 should be assigned', Assigned(aDispatch^.SplatF64x2));
  AssertTrue(LBackendSlotPrefix + 'ZeroF64x2 should be assigned', Assigned(aDispatch^.ZeroF64x2));
  AssertTrue(LBackendSlotPrefix + 'LoadF32x8 should be assigned', Assigned(aDispatch^.LoadF32x8));
  AssertTrue(LBackendSlotPrefix + 'StoreF32x8 should be assigned', Assigned(aDispatch^.StoreF32x8));
  AssertTrue(LBackendSlotPrefix + 'SplatF32x8 should be assigned', Assigned(aDispatch^.SplatF32x8));
  AssertTrue(LBackendSlotPrefix + 'ZeroF32x8 should be assigned', Assigned(aDispatch^.ZeroF32x8));
  AssertTrue(LBackendSlotPrefix + 'LoadF64x4 should be assigned', Assigned(aDispatch^.LoadF64x4));
  AssertTrue(LBackendSlotPrefix + 'StoreF64x4 should be assigned', Assigned(aDispatch^.StoreF64x4));
  AssertTrue(LBackendSlotPrefix + 'SplatF64x4 should be assigned', Assigned(aDispatch^.SplatF64x4));
  AssertTrue(LBackendSlotPrefix + 'ZeroF64x4 should be assigned', Assigned(aDispatch^.ZeroF64x4));
  AssertTrue(LBackendSlotPrefix + 'LoadF32x16 should be assigned', Assigned(aDispatch^.LoadF32x16));
  AssertTrue(LBackendSlotPrefix + 'StoreF32x16 should be assigned', Assigned(aDispatch^.StoreF32x16));
  AssertTrue(LBackendSlotPrefix + 'SplatF32x16 should be assigned', Assigned(aDispatch^.SplatF32x16));
  AssertTrue(LBackendSlotPrefix + 'ZeroF32x16 should be assigned', Assigned(aDispatch^.ZeroF32x16));
  AssertTrue(LBackendSlotPrefix + 'LoadF64x8 should be assigned', Assigned(aDispatch^.LoadF64x8));
  AssertTrue(LBackendSlotPrefix + 'StoreF64x8 should be assigned', Assigned(aDispatch^.StoreF64x8));
  AssertTrue(LBackendSlotPrefix + 'SplatF64x8 should be assigned', Assigned(aDispatch^.SplatF64x8));
  AssertTrue(LBackendSlotPrefix + 'ZeroF64x8 should be assigned', Assigned(aDispatch^.ZeroF64x8));
  AssertTrue(LBackendSlotPrefix + 'MemEqual should be assigned', Assigned(aDispatch^.MemEqual));
  AssertTrue(LBackendSlotPrefix + 'MemFindByte should be assigned', Assigned(aDispatch^.MemFindByte));
  AssertTrue(LBackendSlotPrefix + 'MemDiffRange should be assigned', Assigned(aDispatch^.MemDiffRange));
  AssertTrue(LBackendSlotPrefix + 'MemCopy should be assigned', Assigned(aDispatch^.MemCopy));
  AssertTrue(LBackendSlotPrefix + 'MemSet should be assigned', Assigned(aDispatch^.MemSet));
  AssertTrue(LBackendSlotPrefix + 'MemReverse should be assigned', Assigned(aDispatch^.MemReverse));
  AssertTrue(LBackendSlotPrefix + 'SumBytes should be assigned', Assigned(aDispatch^.SumBytes));
  AssertTrue(LBackendSlotPrefix + 'MinMaxBytes should be assigned', Assigned(aDispatch^.MinMaxBytes));
  AssertTrue(LBackendSlotPrefix + 'CountByte should be assigned', Assigned(aDispatch^.CountByte));
  AssertTrue(LBackendSlotPrefix + 'Utf8Validate should be assigned', Assigned(aDispatch^.Utf8Validate));
  AssertTrue(LBackendSlotPrefix + 'AsciiIEqual should be assigned', Assigned(aDispatch^.AsciiIEqual));
  AssertTrue(LBackendSlotPrefix + 'ToLowerAscii should be assigned', Assigned(aDispatch^.ToLowerAscii));
  AssertTrue(LBackendSlotPrefix + 'ToUpperAscii should be assigned', Assigned(aDispatch^.ToUpperAscii));
  AssertTrue(LBackendSlotPrefix + 'BytesIndexOf should be assigned', Assigned(aDispatch^.BytesIndexOf));
  AssertTrue(LBackendSlotPrefix + 'BitsetPopCount should be assigned', Assigned(aDispatch^.BitsetPopCount));
  AssertTrue(LBackendSlotPrefix + 'I8x16SatAdd should be assigned', Assigned(aDispatch^.I8x16SatAdd));
  AssertTrue(LBackendSlotPrefix + 'I8x16SatSub should be assigned', Assigned(aDispatch^.I8x16SatSub));
  AssertTrue(LBackendSlotPrefix + 'I16x8SatAdd should be assigned', Assigned(aDispatch^.I16x8SatAdd));
  AssertTrue(LBackendSlotPrefix + 'I16x8SatSub should be assigned', Assigned(aDispatch^.I16x8SatSub));
  AssertTrue(LBackendSlotPrefix + 'U8x16SatAdd should be assigned', Assigned(aDispatch^.U8x16SatAdd));
  AssertTrue(LBackendSlotPrefix + 'U8x16SatSub should be assigned', Assigned(aDispatch^.U8x16SatSub));
  AssertTrue(LBackendSlotPrefix + 'U16x8SatAdd should be assigned', Assigned(aDispatch^.U16x8SatAdd));
  AssertTrue(LBackendSlotPrefix + 'U16x8SatSub should be assigned', Assigned(aDispatch^.U16x8SatSub));
  AssertTrue(LBackendSlotPrefix + 'AddI16x8 should be assigned', Assigned(aDispatch^.AddI16x8));
  AssertTrue(LBackendSlotPrefix + 'SubI16x8 should be assigned', Assigned(aDispatch^.SubI16x8));
  AssertTrue(LBackendSlotPrefix + 'MulI16x8 should be assigned', Assigned(aDispatch^.MulI16x8));
  AssertTrue(LBackendSlotPrefix + 'AndI16x8 should be assigned', Assigned(aDispatch^.AndI16x8));
  AssertTrue(LBackendSlotPrefix + 'OrI16x8 should be assigned', Assigned(aDispatch^.OrI16x8));
  AssertTrue(LBackendSlotPrefix + 'XorI16x8 should be assigned', Assigned(aDispatch^.XorI16x8));
  AssertTrue(LBackendSlotPrefix + 'NotI16x8 should be assigned', Assigned(aDispatch^.NotI16x8));
  AssertTrue(LBackendSlotPrefix + 'AndNotI16x8 should be assigned', Assigned(aDispatch^.AndNotI16x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftI16x8 should be assigned', Assigned(aDispatch^.ShiftLeftI16x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightI16x8 should be assigned', Assigned(aDispatch^.ShiftRightI16x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightArithI16x8 should be assigned', Assigned(aDispatch^.ShiftRightArithI16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI16x8 should be assigned', Assigned(aDispatch^.CmpEqI16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI16x8 should be assigned', Assigned(aDispatch^.CmpLtI16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI16x8 should be assigned', Assigned(aDispatch^.CmpGtI16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI16x8 should be assigned', Assigned(aDispatch^.CmpLeI16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI16x8 should be assigned', Assigned(aDispatch^.CmpGeI16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI16x8 should be assigned', Assigned(aDispatch^.CmpNeI16x8));
  AssertTrue(LBackendSlotPrefix + 'MinI16x8 should be assigned', Assigned(aDispatch^.MinI16x8));
  AssertTrue(LBackendSlotPrefix + 'MaxI16x8 should be assigned', Assigned(aDispatch^.MaxI16x8));
  AssertTrue(LBackendSlotPrefix + 'AddI8x16 should be assigned', Assigned(aDispatch^.AddI8x16));
  AssertTrue(LBackendSlotPrefix + 'SubI8x16 should be assigned', Assigned(aDispatch^.SubI8x16));
  AssertTrue(LBackendSlotPrefix + 'AndI8x16 should be assigned', Assigned(aDispatch^.AndI8x16));
  AssertTrue(LBackendSlotPrefix + 'OrI8x16 should be assigned', Assigned(aDispatch^.OrI8x16));
  AssertTrue(LBackendSlotPrefix + 'XorI8x16 should be assigned', Assigned(aDispatch^.XorI8x16));
  AssertTrue(LBackendSlotPrefix + 'NotI8x16 should be assigned', Assigned(aDispatch^.NotI8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpEqI8x16 should be assigned', Assigned(aDispatch^.CmpEqI8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLtI8x16 should be assigned', Assigned(aDispatch^.CmpLtI8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGtI8x16 should be assigned', Assigned(aDispatch^.CmpGtI8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLeI8x16 should be assigned', Assigned(aDispatch^.CmpLeI8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGeI8x16 should be assigned', Assigned(aDispatch^.CmpGeI8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpNeI8x16 should be assigned', Assigned(aDispatch^.CmpNeI8x16));
  AssertTrue(LBackendSlotPrefix + 'MinI8x16 should be assigned', Assigned(aDispatch^.MinI8x16));
  AssertTrue(LBackendSlotPrefix + 'MaxI8x16 should be assigned', Assigned(aDispatch^.MaxI8x16));
  AssertTrue(LBackendSlotPrefix + 'AddU32x4 should be assigned', Assigned(aDispatch^.AddU32x4));
  AssertTrue(LBackendSlotPrefix + 'SubU32x4 should be assigned', Assigned(aDispatch^.SubU32x4));
  AssertTrue(LBackendSlotPrefix + 'MulU32x4 should be assigned', Assigned(aDispatch^.MulU32x4));
  AssertTrue(LBackendSlotPrefix + 'AndU32x4 should be assigned', Assigned(aDispatch^.AndU32x4));
  AssertTrue(LBackendSlotPrefix + 'OrU32x4 should be assigned', Assigned(aDispatch^.OrU32x4));
  AssertTrue(LBackendSlotPrefix + 'XorU32x4 should be assigned', Assigned(aDispatch^.XorU32x4));
  AssertTrue(LBackendSlotPrefix + 'NotU32x4 should be assigned', Assigned(aDispatch^.NotU32x4));
  AssertTrue(LBackendSlotPrefix + 'AndNotU32x4 should be assigned', Assigned(aDispatch^.AndNotU32x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftU32x4 should be assigned', Assigned(aDispatch^.ShiftLeftU32x4));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightU32x4 should be assigned', Assigned(aDispatch^.ShiftRightU32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU32x4 should be assigned', Assigned(aDispatch^.CmpEqU32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU32x4 should be assigned', Assigned(aDispatch^.CmpLtU32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU32x4 should be assigned', Assigned(aDispatch^.CmpGtU32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU32x4 should be assigned', Assigned(aDispatch^.CmpLeU32x4));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU32x4 should be assigned', Assigned(aDispatch^.CmpGeU32x4));
  AssertTrue(LBackendSlotPrefix + 'MinU32x4 should be assigned', Assigned(aDispatch^.MinU32x4));
  AssertTrue(LBackendSlotPrefix + 'MaxU32x4 should be assigned', Assigned(aDispatch^.MaxU32x4));
  AssertTrue(LBackendSlotPrefix + 'AddU16x8 should be assigned', Assigned(aDispatch^.AddU16x8));
  AssertTrue(LBackendSlotPrefix + 'SubU16x8 should be assigned', Assigned(aDispatch^.SubU16x8));
  AssertTrue(LBackendSlotPrefix + 'MulU16x8 should be assigned', Assigned(aDispatch^.MulU16x8));
  AssertTrue(LBackendSlotPrefix + 'AndU16x8 should be assigned', Assigned(aDispatch^.AndU16x8));
  AssertTrue(LBackendSlotPrefix + 'OrU16x8 should be assigned', Assigned(aDispatch^.OrU16x8));
  AssertTrue(LBackendSlotPrefix + 'XorU16x8 should be assigned', Assigned(aDispatch^.XorU16x8));
  AssertTrue(LBackendSlotPrefix + 'NotU16x8 should be assigned', Assigned(aDispatch^.NotU16x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftLeftU16x8 should be assigned', Assigned(aDispatch^.ShiftLeftU16x8));
  AssertTrue(LBackendSlotPrefix + 'ShiftRightU16x8 should be assigned', Assigned(aDispatch^.ShiftRightU16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU16x8 should be assigned', Assigned(aDispatch^.CmpEqU16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU16x8 should be assigned', Assigned(aDispatch^.CmpLtU16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU16x8 should be assigned', Assigned(aDispatch^.CmpGtU16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU16x8 should be assigned', Assigned(aDispatch^.CmpLeU16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU16x8 should be assigned', Assigned(aDispatch^.CmpGeU16x8));
  AssertTrue(LBackendSlotPrefix + 'CmpNeU16x8 should be assigned', Assigned(aDispatch^.CmpNeU16x8));
  AssertTrue(LBackendSlotPrefix + 'MinU16x8 should be assigned', Assigned(aDispatch^.MinU16x8));
  AssertTrue(LBackendSlotPrefix + 'MaxU16x8 should be assigned', Assigned(aDispatch^.MaxU16x8));
  AssertTrue(LBackendSlotPrefix + 'AddU8x16 should be assigned', Assigned(aDispatch^.AddU8x16));
  AssertTrue(LBackendSlotPrefix + 'SubU8x16 should be assigned', Assigned(aDispatch^.SubU8x16));
  AssertTrue(LBackendSlotPrefix + 'AndU8x16 should be assigned', Assigned(aDispatch^.AndU8x16));
  AssertTrue(LBackendSlotPrefix + 'OrU8x16 should be assigned', Assigned(aDispatch^.OrU8x16));
  AssertTrue(LBackendSlotPrefix + 'XorU8x16 should be assigned', Assigned(aDispatch^.XorU8x16));
  AssertTrue(LBackendSlotPrefix + 'NotU8x16 should be assigned', Assigned(aDispatch^.NotU8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpEqU8x16 should be assigned', Assigned(aDispatch^.CmpEqU8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLtU8x16 should be assigned', Assigned(aDispatch^.CmpLtU8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGtU8x16 should be assigned', Assigned(aDispatch^.CmpGtU8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpLeU8x16 should be assigned', Assigned(aDispatch^.CmpLeU8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpGeU8x16 should be assigned', Assigned(aDispatch^.CmpGeU8x16));
  AssertTrue(LBackendSlotPrefix + 'CmpNeU8x16 should be assigned', Assigned(aDispatch^.CmpNeU8x16));
  AssertTrue(LBackendSlotPrefix + 'MinU8x16 should be assigned', Assigned(aDispatch^.MinU8x16));
  AssertTrue(LBackendSlotPrefix + 'MaxU8x16 should be assigned', Assigned(aDispatch^.MaxU8x16));
  AssertTrue(LBackendSlotPrefix + 'Mask2All should be assigned', Assigned(aDispatch^.Mask2All));
  AssertTrue(LBackendSlotPrefix + 'Mask2Any should be assigned', Assigned(aDispatch^.Mask2Any));
  AssertTrue(LBackendSlotPrefix + 'Mask2None should be assigned', Assigned(aDispatch^.Mask2None));
  AssertTrue(LBackendSlotPrefix + 'Mask2PopCount should be assigned', Assigned(aDispatch^.Mask2PopCount));
  AssertTrue(LBackendSlotPrefix + 'Mask2FirstSet should be assigned', Assigned(aDispatch^.Mask2FirstSet));
  AssertTrue(LBackendSlotPrefix + 'Mask4All should be assigned', Assigned(aDispatch^.Mask4All));
  AssertTrue(LBackendSlotPrefix + 'Mask4Any should be assigned', Assigned(aDispatch^.Mask4Any));
  AssertTrue(LBackendSlotPrefix + 'Mask4None should be assigned', Assigned(aDispatch^.Mask4None));
  AssertTrue(LBackendSlotPrefix + 'Mask4PopCount should be assigned', Assigned(aDispatch^.Mask4PopCount));
  AssertTrue(LBackendSlotPrefix + 'Mask4FirstSet should be assigned', Assigned(aDispatch^.Mask4FirstSet));
  AssertTrue(LBackendSlotPrefix + 'Mask8All should be assigned', Assigned(aDispatch^.Mask8All));
  AssertTrue(LBackendSlotPrefix + 'Mask8Any should be assigned', Assigned(aDispatch^.Mask8Any));
  AssertTrue(LBackendSlotPrefix + 'Mask8None should be assigned', Assigned(aDispatch^.Mask8None));
  AssertTrue(LBackendSlotPrefix + 'Mask8PopCount should be assigned', Assigned(aDispatch^.Mask8PopCount));
  AssertTrue(LBackendSlotPrefix + 'Mask8FirstSet should be assigned', Assigned(aDispatch^.Mask8FirstSet));
  AssertTrue(LBackendSlotPrefix + 'Mask16All should be assigned', Assigned(aDispatch^.Mask16All));
  AssertTrue(LBackendSlotPrefix + 'Mask16Any should be assigned', Assigned(aDispatch^.Mask16Any));
  AssertTrue(LBackendSlotPrefix + 'Mask16None should be assigned', Assigned(aDispatch^.Mask16None));
  AssertTrue(LBackendSlotPrefix + 'Mask16PopCount should be assigned', Assigned(aDispatch^.Mask16PopCount));
  AssertTrue(LBackendSlotPrefix + 'Mask16FirstSet should be assigned', Assigned(aDispatch^.Mask16FirstSet));
  AssertTrue(LBackendSlotPrefix + 'SelectF64x2 should be assigned', Assigned(aDispatch^.SelectF64x2));
  AssertTrue(LBackendSlotPrefix + 'SelectF32x16 should be assigned', Assigned(aDispatch^.SelectF32x16));
  AssertTrue(LBackendSlotPrefix + 'SelectF64x8 should be assigned', Assigned(aDispatch^.SelectF64x8));
  AssertTrue(LBackendSlotPrefix + 'SelectI32x4 should be assigned', Assigned(aDispatch^.SelectI32x4));
  AssertTrue(LBackendSlotPrefix + 'SelectF32x8 should be assigned', Assigned(aDispatch^.SelectF32x8));
  AssertTrue(LBackendSlotPrefix + 'SelectF64x4 should be assigned', Assigned(aDispatch^.SelectF64x4));
  AssertTrue(LBackendSlotPrefix + 'AndNotI8x16 should be assigned', Assigned(aDispatch^.AndNotI8x16));
  AssertTrue(LBackendSlotPrefix + 'AndNotU16x8 should be assigned', Assigned(aDispatch^.AndNotU16x8));
  AssertTrue(LBackendSlotPrefix + 'AndNotU8x16 should be assigned', Assigned(aDispatch^.AndNotU8x16));

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
    AssertEquals('Active backend mismatch', Ord(LBackend), Ord(GetActiveBackend));
    AssertAllDispatchSlotsAssigned(LBackend, LDispatch);
    Inc(LChecked);
  end;

  AssertTrue('At least one backend should be checked', LChecked > 0);
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
    AssertNotNull('Dispatch table should be available', LDispatch);
    AssertEquals('Active backend mismatch', Ord(LBackend), Ord(GetActiveBackend));

    LSourceTable := LDispatch^;
    LOps := Default(TSimdBackendOps);
    DispatchTableToBackendOps(LSourceTable, LOps);
    BackendOpsToDispatchTable(LOps, LRoundTripTable);
    AssertAllDispatchSlotsAssigned(LBackend, @LRoundTripTable);

    AssertEquals('Roundtrip backend field mismatch', Ord(LSourceTable.Backend), Ord(LRoundTripTable.Backend));
    AssertEquals('Roundtrip BackendInfo.Backend mismatch', Ord(LSourceTable.BackendInfo.Backend), Ord(LRoundTripTable.BackendInfo.Backend));
    AssertEquals('Roundtrip BackendInfo.Name mismatch', LSourceTable.BackendInfo.Name, LRoundTripTable.BackendInfo.Name);
    AssertEquals('Roundtrip BackendInfo.Description mismatch', LSourceTable.BackendInfo.Description, LRoundTripTable.BackendInfo.Description);
    AssertEquals('Roundtrip BackendInfo.Available mismatch',
      LSourceTable.BackendInfo.Available, LRoundTripTable.BackendInfo.Available);
    AssertEquals('Roundtrip BackendInfo.Priority mismatch',
      LSourceTable.BackendInfo.Priority, LRoundTripTable.BackendInfo.Priority);
    AssertTrue('Roundtrip BackendInfo.Capabilities mismatch',
      LSourceTable.BackendInfo.Capabilities = LRoundTripTable.BackendInfo.Capabilities);
    AssertTrue('BackendInfo.Name should stay non-empty for registered backend',
      LRoundTripTable.BackendInfo.Name <> '');

    // Contract smoke: representative core slots must keep exact function-pointer identity.
    AssertTrue('AddF32x4 pointer changed after roundtrip', LSourceTable.AddF32x4 = LRoundTripTable.AddF32x4);
    AssertTrue('MulF32x4 pointer changed after roundtrip', LSourceTable.MulF32x4 = LRoundTripTable.MulF32x4);
    AssertTrue('RoundF32x4 pointer changed after roundtrip', LSourceTable.RoundF32x4 = LRoundTripTable.RoundF32x4);
    AssertTrue('TruncF32x4 pointer changed after roundtrip', LSourceTable.TruncF32x4 = LRoundTripTable.TruncF32x4);
    AssertTrue('AddI32x4 pointer changed after roundtrip', LSourceTable.AddI32x4 = LRoundTripTable.AddI32x4);
    AssertTrue('AndI32x4 pointer changed after roundtrip', LSourceTable.AndI32x4 = LRoundTripTable.AndI32x4);
    AssertTrue('LoadF32x4 pointer changed after roundtrip', LSourceTable.LoadF32x4 = LRoundTripTable.LoadF32x4);
    AssertTrue('StoreF32x4 pointer changed after roundtrip', LSourceTable.StoreF32x4 = LRoundTripTable.StoreF32x4);
    AssertTrue('MemEqual pointer changed after roundtrip', LSourceTable.MemEqual = LRoundTripTable.MemEqual);
    AssertTrue('BitsetPopCount pointer changed after roundtrip', LSourceTable.BitsetPopCount = LRoundTripTable.BitsetPopCount);

    Inc(LChecked);
  end;

  AssertTrue('At least one backend should be checked', LChecked > 0);
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

    AssertEquals('GetBackendOps should preserve the requested backend id for unregistered backend=' + LBackendName,
      Ord(LBackend), Ord(LOps.Backend));
    AssertEquals('GetBackendOps should preserve BackendInfo.Backend for unregistered backend=' + LBackendName,
      Ord(LExpectedInfo.Backend), Ord(LOps.BackendInfo.Backend));
    AssertEquals('GetBackendOps should preserve canonical priority for unregistered backend=' + LBackendName,
      LExpectedInfo.Priority, LOps.BackendInfo.Priority);
    AssertEquals('GetBackendOps should preserve canonical availability for unregistered backend=' + LBackendName,
      LExpectedInfo.Available, LOps.BackendInfo.Available);
    AssertTrue('GetBackendOps should preserve empty capability set for unregistered backend=' + LBackendName,
      LOps.BackendInfo.Capabilities = LExpectedInfo.Capabilities);
  end;

  AssertTrue('At least one unregistered backend should exist for adapter metadata coverage',
    LFoundUnregistered);
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

  AssertTrue('Current backend should be registered for adapter canonical text test',
    TryGetRegisteredBackendDispatchTable(LBackend, LOriginalTable));

  LModifiedTable := LOriginalTable;
  LModifiedTable.BackendInfo.Name := '';
  LModifiedTable.BackendInfo.Description := '';
  RegisterBackend(LBackend, LModifiedTable);
  try
    LOps := GetBackendOps(LBackend);
    LCanonicalInfo := GetBackendInfo(LBackend);

    AssertEquals('GetBackendOps should preserve the requested backend id after re-register',
      Ord(LBackend), Ord(LOps.Backend));
    AssertEquals('GetBackendOps should preserve BackendInfo.Backend after re-register',
      Ord(LBackend), Ord(LOps.BackendInfo.Backend));
    AssertTrue('GetBackendOps should preserve non-empty name for registered backend after re-register',
      LOps.BackendInfo.Name <> '');
    AssertTrue('GetBackendOps should preserve non-empty description for registered backend after re-register',
      LOps.BackendInfo.Description <> '');
    AssertEquals('GetBackendOps should stay aligned with canonical backend name after re-register',
      LCanonicalInfo.Name, LOps.BackendInfo.Name);
    AssertEquals('GetBackendOps should stay aligned with canonical backend description after re-register',
      LCanonicalInfo.Description, LOps.BackendInfo.Description);
    AssertEquals('GetBackendOps should preserve current availability state after re-register',
      LModifiedTable.BackendInfo.Available, LOps.BackendInfo.Available);
    AssertTrue('GetBackendOps should preserve current capability set after re-register',
      LOps.BackendInfo.Capabilities = LModifiedTable.BackendInfo.Capabilities);
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

  AssertEquals('SSE4.2 should inherit SSE4.1 MulI32x4',
    PtrUInt(LSSE41.MulI32x4), PtrUInt(LSSE42.MulI32x4));
  AssertEquals('SSE4.2 should inherit SSE4.1 DotF32x4',
    PtrUInt(LSSE41.DotF32x4), PtrUInt(LSSE42.DotF32x4));
  AssertEquals('SSE4.2 should inherit SSE4.1 RoundF32x4',
    PtrUInt(LSSE41.RoundF32x4), PtrUInt(LSSE42.RoundF32x4));
  AssertEquals('SSE4.2 should inherit SSE4.1 SelectF32x4',
    PtrUInt(LSSE41.SelectF32x4), PtrUInt(LSSE42.SelectF32x4));
end;

initialization
  RegisterTest(TTestCase_DispatchAllSlots);

end.
