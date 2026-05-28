unit nextpas.core.simd.api.v2.testcase;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  SysUtils, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.api.v2;

type
  TTestCase_PublicApiV2Facade = class(TTestCase)
  published
    procedure Test_BoundApiV2_IsAvailable;
    procedure Test_FacadeMemEqual_Uses_V2_DataPlane;
    procedure Test_FacadeSnapshotFlags_Match_BoundTable_And_CurrentSemantics;
    procedure Test_FacadeOperations_Stay_Aligned_With_BoundTable;
  end;

implementation

procedure TTestCase_PublicApiV2Facade.Test_BoundApiV2_IsAvailable;
var
  LApi: PFafafaSimdPublicApiV2;
begin
  LApi := GetBoundPublicApiV2;
  AssertNotNull('Bound v2 public api should not be nil', LApi);
  AssertTrue('Snapshot generation should be positive', GetSnapshotGeneration > 0);
end;

procedure TTestCase_PublicApiV2Facade.Test_FacadeMemEqual_Uses_V2_DataPlane;
var
  LA, LB: array[0..15] of Byte;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LA) do
  begin
    LA[LIndex] := Byte((LIndex * 5) and $FF);
    LB[LIndex] := LA[LIndex];
  end;

  AssertTrue('v2 MemEqual should agree on equal buffers',
    MemEqual(@LA[0], @LB[0], Length(LA)));
end;

procedure TTestCase_PublicApiV2Facade.Test_FacadeSnapshotFlags_Match_BoundTable_And_CurrentSemantics;
var
  LApi: PFafafaSimdPublicApiV2;
  LDirectFlagSet: Boolean;
begin
  LApi := GetBoundPublicApiV2;
  AssertNotNull('Bound v2 public api should not be nil', LApi);

  AssertEquals('Facade snapshot generation should mirror the bound table',
    LApi^.SnapshotGeneration, GetSnapshotGeneration);
  AssertEquals('Facade snapshot flags should mirror the bound table',
    LApi^.SnapshotFlags, GetSnapshotFlags);

  LDirectFlagSet := (GetSnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE) <> 0;
  AssertEquals('SupportsDirectDataPlane should mirror the direct-data-plane flag',
    Ord(LDirectFlagSet), Ord(SupportsDirectDataPlane));
  AssertEquals('Current v2 wrapper should keep direct-data-plane semantics unset',
    0, Ord(SupportsDirectDataPlane));
  AssertTrue('Current v2 wrapper should keep snapshot-bound semantics set',
    (GetSnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND) <> 0);
  AssertTrue('Current v2 wrapper should keep v1 compatibility semantics set',
    (GetSnapshotFlags and FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1) <> 0);
end;

procedure TTestCase_PublicApiV2Facade.Test_FacadeOperations_Stay_Aligned_With_BoundTable;
var
  LApi: PFafafaSimdPublicApiV2;
  LA, LB, LCopyFacade, LCopyBound: array[0..31] of Byte;
  LSetFacade, LSetBound: array[0..15] of Byte;
  LLowerFacade, LLowerBound: array[0..8] of Byte;
  LUpperFacade, LUpperBound: array[0..8] of Byte;
  LReverseFacade, LReverseBound: array[0..7] of Byte;
  LNeedle: array[0..2] of Byte;
  LFirstFacade, LLastFacade: SizeUInt;
  LFirstBound, LLastBound: SizeUInt;
  LMinFacade, LMaxFacade: Byte;
  LMinBound, LMaxBound: Byte;
  LIndex: Integer;
const
  CText = 'simd-publicapi-v2';
  CMixedAscii = 'AbCdEf012';
begin
  LApi := GetBoundPublicApiV2;
  AssertNotNull('Bound v2 public api should not be nil', LApi);

  for LIndex := 0 to High(LA) do
  begin
    LA[LIndex] := Byte((LIndex * 7) and $FF);
    LB[LIndex] := LA[LIndex];
  end;
  LB[17] := $AA;

  AssertTrue('Bound table MemEqual should succeed on identical input',
    LApi^.MemEqual(@LA[0], @LA[0], Length(LA)));
  AssertTrue('Facade MemEqual should succeed on identical input',
    MemEqual(@LA[0], @LA[0], Length(LA)));
  AssertEquals('MemFindByte facade should match the bound table',
    LApi^.MemFindByte(@LB[0], Length(LB), $AA),
    MemFindByte(@LB[0], Length(LB), $AA));

  AssertTrue('Bound table MemDiffRange should detect the mismatch',
    LApi^.MemDiffRange(@LA[0], @LB[0], Length(LA), LFirstBound, LLastBound));
  AssertTrue('Facade MemDiffRange should detect the mismatch',
    MemDiffRange(@LA[0], @LB[0], Length(LA), LFirstFacade, LLastFacade));
  AssertEquals('MemDiffRange first-diff should match the bound table',
    LFirstBound, LFirstFacade);
  AssertEquals('MemDiffRange last-diff should match the bound table',
    LLastBound, LLastFacade);

  AssertEquals('SumBytes facade should match the bound table',
    LApi^.SumBytes(@LA[0], Length(LA)),
    SumBytes(@LA[0], Length(LA)));
  AssertEquals('CountByte facade should match the bound table',
    LApi^.CountByte(@LB[0], Length(LB), $AA),
    CountByte(@LB[0], Length(LB), $AA));
  AssertEquals('BitsetPopCount facade should match the bound table',
    LApi^.BitsetPopCount(@LA[0], Length(LA)),
    BitsetPopCount(@LA[0], Length(LA)));
  AssertTrue('Bound table Utf8Validate should accept valid UTF-8',
    LApi^.Utf8Validate(PChar(CText), Length(CText)));
  AssertTrue('Facade Utf8Validate should accept valid UTF-8',
    Utf8Validate(PChar(CText), Length(CText)));
  AssertTrue('Bound table AsciiIEqual should accept case-insensitive equality',
    LApi^.AsciiIEqual(PChar('AbCd'), PChar('aBcD'), 4));
  AssertTrue('Facade AsciiIEqual should accept case-insensitive equality',
    AsciiIEqual(PChar('AbCd'), PChar('aBcD'), 4));

  LNeedle[0] := LA[7];
  LNeedle[1] := LA[8];
  LNeedle[2] := LA[9];
  AssertEquals('BytesIndexOf facade should match the bound table',
    LApi^.BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle)),
    BytesIndexOf(@LA[0], Length(LA), @LNeedle[0], Length(LNeedle)));

  FillChar(LCopyFacade, SizeOf(LCopyFacade), 0);
  FillChar(LCopyBound, SizeOf(LCopyBound), 0);
  MemCopy(@LA[0], @LCopyFacade[0], Length(LA));
  LApi^.MemCopy(@LA[0], @LCopyBound[0], Length(LA));
  AssertEquals('MemCopy facade result should match the bound table',
    0, CompareByte(LCopyFacade[0], LCopyBound[0], Length(LA)));

  MemSet(@LSetFacade[0], Length(LSetFacade), $5A);
  LApi^.MemSet(@LSetBound[0], Length(LSetBound), $5A);
  AssertEquals('MemSet facade result should match the bound table',
    0, CompareByte(LSetFacade[0], LSetBound[0], Length(LSetFacade)));

  Move(CMixedAscii[1], LLowerFacade[0], Length(LLowerFacade));
  Move(CMixedAscii[1], LLowerBound[0], Length(LLowerBound));
  ToLowerAscii(@LLowerFacade[0], Length(LLowerFacade));
  LApi^.ToLowerAscii(@LLowerBound[0], Length(LLowerBound));
  AssertEquals('ToLowerAscii facade result should match the bound table',
    0, CompareByte(LLowerFacade[0], LLowerBound[0], Length(LLowerFacade)));

  Move(CMixedAscii[1], LUpperFacade[0], Length(LUpperFacade));
  Move(CMixedAscii[1], LUpperBound[0], Length(LUpperBound));
  ToUpperAscii(@LUpperFacade[0], Length(LUpperFacade));
  LApi^.ToUpperAscii(@LUpperBound[0], Length(LUpperBound));
  AssertEquals('ToUpperAscii facade result should match the bound table',
    0, CompareByte(LUpperFacade[0], LUpperBound[0], Length(LUpperFacade)));

  for LIndex := 0 to High(LReverseFacade) do
  begin
    LReverseFacade[LIndex] := Byte(LIndex + 1);
    LReverseBound[LIndex] := LReverseFacade[LIndex];
  end;
  MemReverse(@LReverseFacade[0], Length(LReverseFacade));
  LApi^.MemReverse(@LReverseBound[0], Length(LReverseBound));
  AssertEquals('MemReverse facade result should match the bound table',
    0, CompareByte(LReverseFacade[0], LReverseBound[0], Length(LReverseFacade)));

  MinMaxBytes(@LB[0], Length(LB), LMinFacade, LMaxFacade);
  LApi^.MinMaxBytes(@LB[0], Length(LB), LMinBound, LMaxBound);
  AssertEquals('MinMaxBytes min should match the bound table',
    Integer(LMinBound), Integer(LMinFacade));
  AssertEquals('MinMaxBytes max should match the bound table',
    Integer(LMaxBound), Integer(LMaxFacade));
end;

initialization
  RegisterTest(TTestCase_PublicApiV2Facade);

end.
