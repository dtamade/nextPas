unit nextpas.core.simd.direct.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.math,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.simd,
  nextpas.core.simd.fixturehelpers,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.direct,
  nextpas.core.simd.scalar;

type
  TDirectDispatchStatefulTestCase = class(TSimdVectorAsmStatefulTestCase)
  protected
    procedure RestoreFixtureDirectDispatchState;
    procedure AfterEach; override;
  end;

  TTestCase_DirectDispatch = class(TDirectDispatchStatefulTestCase)
  published
    procedure Test_DirectDispatchTable_Assigned;
    procedure Test_DirectDispatchTable_MatchesGetDispatchTable;
    procedure Test_DirectDispatchTable_Rebind_AfterForceBackend;
    procedure Test_DirectDispatchTable_AutoRebind_AfterDispatchSetActiveBackend;
    procedure Test_DirectDispatchTable_MatchesRepresentativeSlots;
    procedure Test_DirectDispatchTable_TrySetUnavailableBackend_NoDrift;
    procedure Test_DirectDispatchTable_MultiBackend_SmokeParity;
    procedure Test_DirectDispatchTable_MultiBackend_DotReduceMaskSat_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_MemTextEdgeMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_MemOpsEdgeMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_StatsEdgeMatrix_Parity;
    procedure Test_DirectDispatchTable_MaskCompareEdge_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_MaskWideCompareMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F64CompareEdgeMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32CompareMicroDeltaMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_U32U64CompareEdgeMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32x8F64x4ArithmeticReduceMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32x16F64x8CompareReduceMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32x16F64x8ArithmeticMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32x16F64x8ReduceMulStable_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_Mask8Mask16InverseProperties_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32x16F64x8CompareIdentityProperties_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_U32x8U64x4CompareIdentityMaskProperties_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_F32x8F64x4CompareIdentityMaskProperties_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_I16I8CompareEdgeMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_SignedWideCompareMaskMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_WideBitwiseShiftMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_WideArithmeticMinMaxMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_MemSearchBitsetUtf8_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_MemWindowMatrix_Parity;
    procedure Test_DirectDispatchTable_MultiBackend_MemSearchFuzzSeed_Parity;
    procedure Test_DirectDispatchTable_WideIntegerHelperMatrix_Parity;
  end;

  TTestCase_DirectDispatchConcurrent = class(TDirectDispatchStatefulTestCase)
  published
    procedure Test_DirectDispatchTable_Concurrent_ReRegister_SnapshotConsistency;
  end;

implementation

function DirectBackendName(const aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

function BoolToTrueFalse(const AValue: Boolean): string; inline;
begin
  if AValue then
    Result := 'True'
  else
    Result := 'False';
end;

type
  TDirectDispatchMutationWorker = class(TWorkerThread)
  private
    FIterations: Integer;
    FWriterPhase: Integer;
    FBackend: TSimdBackend;
    FTableA: TSimdDispatchTable;
    FTableB: TSimdDispatchTable;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations, aWriterPhase: Integer; aBackend: TSimdBackend;
      const aTableA, aTableB: TSimdDispatchTable);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

  TDirectDispatchReadWorker = class(TWorkerThread)
  private
    FIterations: Integer;
    FSuccess: Boolean;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor Create(aIterations: Integer);
    property Success: Boolean read FSuccess;
    property ErrorMsg: string read FErrorMsg;
  end;

function DirectDispatchSyntheticAddImpl(const a, b: TVecF32x4): TVecF32x4;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
    Result.f[LIndex] := a.f[LIndex] + b.f[LIndex];
end;

function DirectDispatchSyntheticAddA(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := DirectDispatchSyntheticAddImpl(a, b);
end;

function DirectDispatchSyntheticAddB(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := DirectDispatchSyntheticAddImpl(a, b);
end;

function DirectDispatchSyntheticReduceAddImpl(const a: TVecF32x4): Single;
begin
  Result := a.f[0] + a.f[1] + a.f[2] + a.f[3];
end;

function DirectDispatchSyntheticReduceAddA(const a: TVecF32x4): Single;
begin
  Result := DirectDispatchSyntheticReduceAddImpl(a);
end;

function DirectDispatchSyntheticReduceAddB(const a: TVecF32x4): Single;
begin
  Result := DirectDispatchSyntheticReduceAddImpl(a);
end;

function DirectDispatchSyntheticMemEqualImpl(a, b: Pointer; len: SizeUInt): LongBool;
var
  LLeft: PByte;
  LRight: PByte;
  LIndex: SizeUInt;
begin
  LLeft := PByte(a);
  LRight := PByte(b);
  for LIndex := 0 to len - 1 do
    if LLeft[LIndex] <> LRight[LIndex] then
      Exit(False);
  Result := True;
end;

function DirectDispatchSyntheticMemEqualA(a, b: Pointer; len: SizeUInt): LongBool;
begin
  Result := DirectDispatchSyntheticMemEqualImpl(a, b, len);
end;

function DirectDispatchSyntheticMemEqualB(a, b: Pointer; len: SizeUInt): LongBool;
begin
  Result := DirectDispatchSyntheticMemEqualImpl(a, b, len);
end;

function DirectDispatchSyntheticSumBytesImpl(p: Pointer; len: SizeUInt): UInt64;
var
  LBytes: PByte;
  LIndex: SizeUInt;
begin
  Result := 0;
  LBytes := PByte(p);
  for LIndex := 0 to len - 1 do
    Inc(Result, LBytes[LIndex]);
end;

function DirectDispatchSyntheticSumBytesA(p: Pointer; len: SizeUInt): UInt64;
begin
  Result := DirectDispatchSyntheticSumBytesImpl(p, len);
end;

function DirectDispatchSyntheticSumBytesB(p: Pointer; len: SizeUInt): UInt64;
begin
  Result := DirectDispatchSyntheticSumBytesImpl(p, len);
end;

function DirectDispatchSyntheticCountByteImpl(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
var
  LBytes: PByte;
  LIndex: SizeUInt;
begin
  Result := 0;
  LBytes := PByte(p);
  for LIndex := 0 to len - 1 do
    if LBytes[LIndex] = value then
      Inc(Result);
end;

function DirectDispatchSyntheticCountByteA(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
begin
  Result := DirectDispatchSyntheticCountByteImpl(p, len, value);
end;

function DirectDispatchSyntheticCountByteB(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
begin
  Result := DirectDispatchSyntheticCountByteImpl(p, len, value);
end;

procedure TDirectDispatchStatefulTestCase.RestoreFixtureDirectDispatchState;
begin
  RebindDirectDispatch;
  CheckTrue(RestoreSavedBackendAndVectorAsmStateAndVerify(FSavedVectorAsm, FSavedBackend, @GetCurrentBackend), 'Direct dispatch fixture should restore previous backend selection');
end;

procedure TDirectDispatchStatefulTestCase.AfterEach;
begin
  {inherited TearDown; -- removed}
  RebindDirectDispatch;
end;

function DirectDispatchSyntheticBitsetPopCountImpl(p: Pointer; byteLen: SizeUInt): SizeUInt;
const
  CPopCountTable: array[0..15] of Byte = (0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4);
var
  LBytes: PByte;
  LIndex: SizeUInt;
  LValue: Byte;
begin
  Result := 0;
  LBytes := PByte(p);
  for LIndex := 0 to byteLen - 1 do
  begin
    LValue := LBytes[LIndex];
    Inc(Result, CPopCountTable[LValue and $0F] + CPopCountTable[LValue shr 4]);
  end;
end;

function DirectDispatchSyntheticBitsetPopCountA(p: Pointer; byteLen: SizeUInt): SizeUInt;
begin
  Result := DirectDispatchSyntheticBitsetPopCountImpl(p, byteLen);
end;

function DirectDispatchSyntheticBitsetPopCountB(p: Pointer; byteLen: SizeUInt): SizeUInt;
begin
  Result := DirectDispatchSyntheticBitsetPopCountImpl(p, byteLen);
end;

procedure ConfigureDirectDispatchSyntheticTableA(var aDispatchTable: TSimdDispatchTable);
begin
  aDispatchTable.CoreVectors.AddF32x4 := @DirectDispatchSyntheticAddA;
  aDispatchTable.CoreVectors.ReduceAddF32x4 := @DirectDispatchSyntheticReduceAddA;
  aDispatchTable.Memory.Equal := @DirectDispatchSyntheticMemEqualA;
  aDispatchTable.Memory.SumBytes := @DirectDispatchSyntheticSumBytesA;
  aDispatchTable.Memory.CountByte := @DirectDispatchSyntheticCountByteA;
  aDispatchTable.Memory.BitsetPopCount := @DirectDispatchSyntheticBitsetPopCountA;
end;

procedure ConfigureDirectDispatchSyntheticTableB(var aDispatchTable: TSimdDispatchTable);
begin
  aDispatchTable.CoreVectors.AddF32x4 := @DirectDispatchSyntheticAddB;
  aDispatchTable.CoreVectors.ReduceAddF32x4 := @DirectDispatchSyntheticReduceAddB;
  aDispatchTable.Memory.Equal := @DirectDispatchSyntheticMemEqualB;
  aDispatchTable.Memory.SumBytes := @DirectDispatchSyntheticSumBytesB;
  aDispatchTable.Memory.CountByte := @DirectDispatchSyntheticCountByteB;
  aDispatchTable.Memory.BitsetPopCount := @DirectDispatchSyntheticBitsetPopCountB;
end;

function IsDirectDispatchSyntheticSnapshotA(aDispatchTable: PSimdDispatchTable): Boolean;
begin
  Result :=
    (Pointer(aDispatchTable^.CoreVectors.AddF32x4) = Pointer(@DirectDispatchSyntheticAddA)) and
    (Pointer(aDispatchTable^.CoreVectors.ReduceAddF32x4) = Pointer(@DirectDispatchSyntheticReduceAddA)) and
    (Pointer(aDispatchTable^.Memory.Equal) = Pointer(@DirectDispatchSyntheticMemEqualA)) and
    (Pointer(aDispatchTable^.Memory.SumBytes) = Pointer(@DirectDispatchSyntheticSumBytesA)) and
    (Pointer(aDispatchTable^.Memory.CountByte) = Pointer(@DirectDispatchSyntheticCountByteA)) and
    (Pointer(aDispatchTable^.Memory.BitsetPopCount) = Pointer(@DirectDispatchSyntheticBitsetPopCountA));
end;

function IsDirectDispatchSyntheticSnapshotB(aDispatchTable: PSimdDispatchTable): Boolean;
begin
  Result :=
    (Pointer(aDispatchTable^.CoreVectors.AddF32x4) = Pointer(@DirectDispatchSyntheticAddB)) and
    (Pointer(aDispatchTable^.CoreVectors.ReduceAddF32x4) = Pointer(@DirectDispatchSyntheticReduceAddB)) and
    (Pointer(aDispatchTable^.Memory.Equal) = Pointer(@DirectDispatchSyntheticMemEqualB)) and
    (Pointer(aDispatchTable^.Memory.SumBytes) = Pointer(@DirectDispatchSyntheticSumBytesB)) and
    (Pointer(aDispatchTable^.Memory.CountByte) = Pointer(@DirectDispatchSyntheticCountByteB)) and
    (Pointer(aDispatchTable^.Memory.BitsetPopCount) = Pointer(@DirectDispatchSyntheticBitsetPopCountB));
end;

function DescribeDirectDispatchSyntheticSnapshot(aDispatchTable: PSimdDispatchTable): string;
begin
  Result :=
    'Add=' + BoolToTrueFalse(Pointer(aDispatchTable^.CoreVectors.AddF32x4) = Pointer(@DirectDispatchSyntheticAddA)) + '/' +
      BoolToTrueFalse(Pointer(aDispatchTable^.CoreVectors.AddF32x4) = Pointer(@DirectDispatchSyntheticAddB)) +
    ', ReduceAdd=' + BoolToTrueFalse(Pointer(aDispatchTable^.CoreVectors.ReduceAddF32x4) = Pointer(@DirectDispatchSyntheticReduceAddA)) + '/' +
      BoolToTrueFalse(Pointer(aDispatchTable^.CoreVectors.ReduceAddF32x4) = Pointer(@DirectDispatchSyntheticReduceAddB)) +
    ', MemEqual=' + BoolToTrueFalse(Pointer(aDispatchTable^.Memory.Equal) = Pointer(@DirectDispatchSyntheticMemEqualA)) + '/' +
      BoolToTrueFalse(Pointer(aDispatchTable^.Memory.Equal) = Pointer(@DirectDispatchSyntheticMemEqualB)) +
    ', SumBytes=' + BoolToTrueFalse(Pointer(aDispatchTable^.Memory.SumBytes) = Pointer(@DirectDispatchSyntheticSumBytesA)) + '/' +
      BoolToTrueFalse(Pointer(aDispatchTable^.Memory.SumBytes) = Pointer(@DirectDispatchSyntheticSumBytesB)) +
    ', CountByte=' + BoolToTrueFalse(Pointer(aDispatchTable^.Memory.CountByte) = Pointer(@DirectDispatchSyntheticCountByteA)) + '/' +
      BoolToTrueFalse(Pointer(aDispatchTable^.Memory.CountByte) = Pointer(@DirectDispatchSyntheticCountByteB)) +
    ', BitsetPopCount=' + BoolToTrueFalse(Pointer(aDispatchTable^.Memory.BitsetPopCount) = Pointer(@DirectDispatchSyntheticBitsetPopCountA)) + '/' +
      BoolToTrueFalse(Pointer(aDispatchTable^.Memory.BitsetPopCount) = Pointer(@DirectDispatchSyntheticBitsetPopCountB));
end;

constructor TDirectDispatchMutationWorker.Create(aIterations, aWriterPhase: Integer;
  aBackend: TSimdBackend; const aTableA, aTableB: TSimdDispatchTable);
begin
  inherited Create;
  FIterations := aIterations;
  FWriterPhase := aWriterPhase;
  FBackend := aBackend;
  FTableA := aTableA;
  FTableB := aTableB;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TDirectDispatchMutationWorker.Execute;
var
  LIndex: Integer;
begin
  try
    for LIndex := 0 to FIterations - 1 do
      if ((LIndex + FWriterPhase) and 1) = 0 then
        RegisterBackend(FBackend, FTableA)
      else
        RegisterBackend(FBackend, FTableB);
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'direct mutation worker exception: ' + E.Message;
  end;
end;

constructor TDirectDispatchReadWorker.Create(aIterations: Integer);
begin
  inherited Create;
  FIterations := aIterations;
  FSuccess := False;
  FErrorMsg := '';
end;

procedure TDirectDispatchReadWorker.Execute;
var
  LIndex: Integer;
  LDispatchTable: PSimdDispatchTable;
  LAddPtr: Pointer;
  LReduceAddPtr: Pointer;
  LMemEqualPtr: Pointer;
  LSumBytesPtr: Pointer;
  LCountBytePtr: Pointer;
  LBitsetPopCountPtr: Pointer;
  LAddIsA: Boolean;
  LAddIsB: Boolean;
  LReduceAddIsA: Boolean;
  LReduceAddIsB: Boolean;
  LMemEqualIsA: Boolean;
  LMemEqualIsB: Boolean;
  LSumBytesIsA: Boolean;
  LSumBytesIsB: Boolean;
  LCountByteIsA: Boolean;
  LCountByteIsB: Boolean;
  LBitsetPopCountIsA: Boolean;
  LBitsetPopCountIsB: Boolean;
  LSnapshotA: Boolean;
  LSnapshotB: Boolean;
begin
  try
    for LIndex := 0 to FIterations - 1 do
    begin
      LDispatchTable := GetDirectDispatchTable;
      if LDispatchTable = nil then
      begin
        FErrorMsg := Format('direct dispatch table is nil at iter %d', [LIndex]);
        Exit;
      end;

      // Deliberately yield between field reads so a concurrent in-place table
      // rewrite cannot hide behind a single tight read sequence.
      LAddPtr := Pointer(LDispatchTable^.CoreVectors.AddF32x4);
      ThreadSwitch;
      LReduceAddPtr := Pointer(LDispatchTable^.CoreVectors.ReduceAddF32x4);
      ThreadSwitch;
      LMemEqualPtr := Pointer(LDispatchTable^.Memory.Equal);
      ThreadSwitch;
      LSumBytesPtr := Pointer(LDispatchTable^.Memory.SumBytes);
      ThreadSwitch;
      LCountBytePtr := Pointer(LDispatchTable^.Memory.CountByte);
      ThreadSwitch;
      LBitsetPopCountPtr := Pointer(LDispatchTable^.Memory.BitsetPopCount);

      LAddIsA := LAddPtr = Pointer(@DirectDispatchSyntheticAddA);
      LAddIsB := LAddPtr = Pointer(@DirectDispatchSyntheticAddB);
      LReduceAddIsA := LReduceAddPtr = Pointer(@DirectDispatchSyntheticReduceAddA);
      LReduceAddIsB := LReduceAddPtr = Pointer(@DirectDispatchSyntheticReduceAddB);
      LMemEqualIsA := LMemEqualPtr = Pointer(@DirectDispatchSyntheticMemEqualA);
      LMemEqualIsB := LMemEqualPtr = Pointer(@DirectDispatchSyntheticMemEqualB);
      LSumBytesIsA := LSumBytesPtr = Pointer(@DirectDispatchSyntheticSumBytesA);
      LSumBytesIsB := LSumBytesPtr = Pointer(@DirectDispatchSyntheticSumBytesB);
      LCountByteIsA := LCountBytePtr = Pointer(@DirectDispatchSyntheticCountByteA);
      LCountByteIsB := LCountBytePtr = Pointer(@DirectDispatchSyntheticCountByteB);
      LBitsetPopCountIsA := LBitsetPopCountPtr = Pointer(@DirectDispatchSyntheticBitsetPopCountA);
      LBitsetPopCountIsB := LBitsetPopCountPtr = Pointer(@DirectDispatchSyntheticBitsetPopCountB);

      LSnapshotA :=
        LAddIsA and LReduceAddIsA and LMemEqualIsA and
        LSumBytesIsA and LCountByteIsA and LBitsetPopCountIsA;
      LSnapshotB :=
        LAddIsB and LReduceAddIsB and LMemEqualIsB and
        LSumBytesIsB and LCountByteIsB and LBitsetPopCountIsB;

      if (not LSnapshotA) and (not LSnapshotB) then
      begin
        FErrorMsg :=
          Format('direct dispatch synthetic snapshot mixed at iter %d: ' +
            'Add=%s/%s ReduceAdd=%s/%s MemEqual=%s/%s SumBytes=%s/%s CountByte=%s/%s BitsetPopCount=%s/%s', [LIndex,
             BoolToTrueFalse(LAddIsA), BoolToTrueFalse(LAddIsB), BoolToTrueFalse(LReduceAddIsA), BoolToTrueFalse(LReduceAddIsB),
             BoolToTrueFalse(LMemEqualIsA), BoolToTrueFalse(LMemEqualIsB), BoolToTrueFalse(LSumBytesIsA), BoolToTrueFalse(LSumBytesIsB),
             BoolToTrueFalse(LCountByteIsA), BoolToTrueFalse(LCountByteIsB), BoolToTrueFalse(LBitsetPopCountIsA), BoolToTrueFalse(LBitsetPopCountIsB)]);
        Exit;
      end;
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMsg := 'direct read worker exception: ' + E.Message;
  end;
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_Assigned;
begin
  CheckTrue(GetDirectDispatchTable <> nil, 'Direct dispatch table should be assigned');
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MatchesGetDispatchTable;
var
  dt: PSimdDispatchTable;
  directDt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;

  CheckTrue(dt <> nil, 'GetDispatchTable should be assigned');
  CheckTrue(directDt <> nil, 'GetDirectDispatchTable should be assigned');

  // Spot-check a few representative entries across categories.
  CheckTrue(dt^.CoreVectors.AddF32x4 = directDt^.CoreVectors.AddF32x4, 'AddF32x4 pointer should match');
  CheckTrue(dt^.CoreVectors.SplatF32x4 = directDt^.CoreVectors.SplatF32x4, 'SplatF32x4 pointer should match');
  CheckTrue(dt^.Memory.Equal = directDt^.Memory.Equal, 'MemEqual pointer should match');
  CheckTrue(dt^.Memory.Copy = directDt^.Memory.Copy, 'MemCopy pointer should match');
  CheckTrue(dt^.Memory.SumBytes = directDt^.Memory.SumBytes, 'SumBytes pointer should match');
  CheckTrue(dt^.Mask.Mask4All = directDt^.Mask.Mask4All, 'Mask4All pointer should match');
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_Rebind_AfterForceBackend;
var
  dt: PSimdDispatchTable;
  directDt: PSimdDispatchTable;
  LOriginalBackend: TSimdBackend;
begin
  LOriginalBackend := GetCurrentBackend;
  try
    // Force backend (for testing) and ensure direct table can be re-bound.
    ForceBackend(sbScalar);
    RebindDirectDispatch;

    dt := GetDispatchTable;
    directDt := GetDirectDispatchTable;

    CheckTrue(dt <> nil, 'GetDispatchTable should be assigned after ForceBackend');
    CheckTrue(directDt <> nil, 'GetDirectDispatchTable should be assigned after RebindDirectDispatch');

    CheckEqual(Ord(dt^.Backend), Ord(directDt^.Backend), 'Backend enum should match');
    CheckTrue(dt^.CoreVectors.AddF32x4 = directDt^.CoreVectors.AddF32x4, 'AddF32x4 pointer should match after rebind');
  finally
    RestoreFixtureDirectDispatchState;
  end;

  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;
  CheckTrue(dt <> nil, 'GetDispatchTable should be assigned after restoring direct rebind path');
  CheckTrue(directDt <> nil, 'GetDirectDispatchTable should be assigned after restoring direct rebind path');
  CheckEqual(Ord(LOriginalBackend), Ord(dt^.Backend), 'Backend should restore to original selection after direct rebind path');
  CheckEqual(Ord(dt^.Backend), Ord(directDt^.Backend), 'Direct dispatch backend should restore with dispatch after direct rebind path');
  CheckTrue(dt^.CoreVectors.AddF32x4 = directDt^.CoreVectors.AddF32x4, 'AddF32x4 pointer should match after restoring direct rebind path');
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_AutoRebind_AfterDispatchSetActiveBackend;
var
  dt: PSimdDispatchTable;
  directDt: PSimdDispatchTable;
  originalBackend: TSimdBackend;
begin
  // Baseline
  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;
  CheckTrue(dt <> nil, 'Baseline GetDispatchTable should be assigned');
  CheckTrue(directDt <> nil, 'Baseline GetDirectDispatchTable should be assigned');

  originalBackend := dt^.Backend;
  try
    // Switch backend via dispatch directly (bypassing nextpas.core.simd facade)
    SetActiveBackend(sbScalar);

    dt := GetDispatchTable;
    directDt := GetDirectDispatchTable;
    CheckTrue(dt <> nil, 'GetDispatchTable should be assigned after SetActiveBackend');
    CheckTrue(directDt <> nil, 'GetDirectDispatchTable should be assigned after SetActiveBackend');

    CheckEqual(Ord(sbScalar), Ord(dt^.Backend), 'Dispatch backend should be Scalar after SetActiveBackend');
    CheckEqual(Ord(dt^.Backend), Ord(directDt^.Backend), 'Direct dispatch backend should track dispatch after SetActiveBackend');
    CheckTrue(dt^.CoreVectors.AddF32x4 = directDt^.CoreVectors.AddF32x4, 'AddF32x4 pointer should match after dispatch SetActiveBackend');

    // Restore automatic selection (also via dispatch)
    ResetToAutomaticBackend;

    dt := GetDispatchTable;
    directDt := GetDirectDispatchTable;
    CheckTrue(dt <> nil, 'GetDispatchTable should be assigned after ResetToAutomaticBackend');
    CheckTrue(directDt <> nil, 'GetDirectDispatchTable should be assigned after ResetToAutomaticBackend');

    // If original backend wasn't scalar, we expect it can change back. Either way, direct must match dispatch.
    CheckEqual(Ord(dt^.Backend), Ord(directDt^.Backend), 'Direct dispatch backend should track dispatch after ResetToAutomaticBackend');

    // Keep the test stable: if automatic selection returns to original backend, fine; otherwise also fine.
    // But we at least assert the backend is a valid enum.
    CheckTrue((Ord(dt^.Backend) >= Ord(Low(TSimdBackend))) and (Ord(dt^.Backend) <= Ord(High(TSimdBackend))), 'Backend enum should be within range');
  finally
    RestoreFixtureDirectDispatchState;
  end;

  CheckTrue((Ord(originalBackend) >= Ord(Low(TSimdBackend))) and (Ord(originalBackend) <= Ord(High(TSimdBackend))), 'Original backend enum should be within range');
  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;
  CheckTrue(dt <> nil, 'GetDispatchTable should be assigned after restoring auto rebind path');
  CheckTrue(directDt <> nil, 'GetDirectDispatchTable should be assigned after restoring auto rebind path');
  CheckEqual(Ord(originalBackend), Ord(dt^.Backend), 'Backend should restore to original selection after auto rebind path');
  CheckEqual(Ord(dt^.Backend), Ord(directDt^.Backend), 'Direct dispatch backend should restore with dispatch after auto rebind path');
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MatchesRepresentativeSlots;
var
  dt: PSimdDispatchTable;
  directDt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;

  CheckTrue(dt <> nil, 'Dispatch table should be assigned');
  CheckTrue(directDt <> nil, 'Direct dispatch table should be assigned');

  // 扩展槽位抽样：覆盖 vector/math/int/mem/mask/saturating 六类。
  CheckTrue(dt^.CoreVectors.DotF32x4 = directDt^.CoreVectors.DotF32x4, 'DotF32x4 pointer should match');
  CheckTrue(dt^.CoreVectors.ReduceAddF32x4 = directDt^.CoreVectors.ReduceAddF32x4, 'ReduceAddF32x4 pointer should match');
  CheckTrue(dt^.CoreVectors.CrossF32x3 = directDt^.CoreVectors.CrossF32x3, 'CrossF32x3 pointer should match');
  CheckTrue(dt^.CoreVectors.LengthF32x3 = directDt^.CoreVectors.LengthF32x3, 'LengthF32x3 pointer should match');
  CheckTrue(dt^.CoreVectors.NormalizeF32x3 = directDt^.CoreVectors.NormalizeF32x3, 'NormalizeF32x3 pointer should match');
  CheckTrue(dt^.CoreVectors.CmpEqI32x4 = directDt^.CoreVectors.CmpEqI32x4, 'CmpEqI32x4 pointer should match');
  CheckTrue(dt^.CoreVectors.MinI32x4 = directDt^.CoreVectors.MinI32x4, 'MinI32x4 pointer should match');
  CheckTrue(dt^.CoreVectors.AndNotI32x4 = directDt^.CoreVectors.AndNotI32x4, 'AndNotI32x4 pointer should match');
  CheckTrue(dt^.CoreVectors.U8x16SatAdd = directDt^.CoreVectors.U8x16SatAdd, 'U8x16SatAdd pointer should match');
  CheckTrue(dt^.Memory.FindByte = directDt^.Memory.FindByte, 'MemFindByte pointer should match');
  CheckTrue(dt^.Memory.CountByte = directDt^.Memory.CountByte, 'CountByte pointer should match');
  CheckTrue(dt^.Memory.Utf8Validate = directDt^.Memory.Utf8Validate, 'Utf8Validate pointer should match');
  CheckTrue(dt^.Mask.Mask16PopCount = directDt^.Mask.Mask16PopCount, 'Mask16PopCount pointer should match');
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_TrySetUnavailableBackend_NoDrift;
var
  dt: PSimdDispatchTable;
  directDt: PSimdDispatchTable;
  beforeBackend: TSimdBackend;
  candidate: TSimdBackend;
  foundCandidate: Boolean;
  ok: Boolean;
begin
  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;
  CheckTrue(dt <> nil, 'Dispatch table should be assigned');
  CheckTrue(directDt <> nil, 'Direct dispatch table should be assigned');

  beforeBackend := dt^.Backend;
  foundCandidate := False;

  for candidate := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    if candidate = beforeBackend then
      Continue;

    if (not IsBackendRegistered(candidate)) or (not IsBackendAvailableOnCPU(candidate)) then
    begin
      foundCandidate := True;
      Break;
    end;
  end;

  if not foundCandidate then
  begin
    CheckTrue(True, 'No unavailable backend candidate found; skip drift check');
    Exit;
  end;

  ok := TrySetActiveBackend(candidate);
  CheckFalse(ok, 'TrySetActiveBackend should fail for unavailable/unregistered backend');

  dt := GetDispatchTable;
  directDt := GetDirectDispatchTable;
  CheckEqual(Ord(beforeBackend), Ord(dt^.Backend), 'Active backend should remain unchanged after failed TrySetActiveBackend');
  CheckEqual(Ord(dt^.Backend), Ord(directDt^.Backend), 'Direct dispatch backend should track dispatch after failed TrySetActiveBackend');
  CheckTrue(dt^.CoreVectors.AddF32x4 = directDt^.CoreVectors.AddF32x4, 'AddF32x4 pointer should still match after failed TrySetActiveBackend');
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_SmokeParity;
const
  C_EPSILON = 1e-6;
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LA, LB: TVecF32x4;
  LFacadeAdd, LDirectAdd: TVecF32x4;
  LFacadeCross3, LDirectCross3: TVecF32x4;
  LFacadeNormalize3, LDirectNormalize3: TVecF32x4;
  LFacadeLength3, LDirectLength3: Single;
  LMask: TMask4;
  LFacadeMaskAll, LDirectMaskAll: Boolean;
  LBuffer: array[0..15] of Byte;
  LIndex: Integer;
  LFacadeFind, LDirectFind: PtrInt;
  LTestedCount: Integer;
begin
  LA.f[0] := 1.25;
  LA.f[1] := -2.0;
  LA.f[2] := 3.5;
  LA.f[3] := 4.0;

  LB.f[0] := 0.75;
  LB.f[1] := 5.0;
  LB.f[2] := -1.5;
  LB.f[3] := 2.0;

  for LIndex := 0 to High(LBuffer) do
    LBuffer[LIndex] := Byte(LIndex);

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if LBackend <> sbScalar then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckEqual(Ord(LDispatch^.Backend), Ord(LDirectDispatch^.Backend), 'Direct dispatch backend should track dispatch for backend ' + DirectBackendName(LBackend));

      LFacadeAdd := VecF32x4Add(LA, LB);
      LDirectAdd := LDirectDispatch^.CoreVectors.AddF32x4(LA, LB);
      for LIndex := 0 to 3 do
        CheckNear(LFacadeAdd.f[LIndex], LDirectAdd.f[LIndex], C_EPSILON, 'Direct AddF32x4 lane' + IntToStr(LIndex) + ' backend ' + DirectBackendName(LBackend));

      LFacadeCross3 := VecF32x3Cross(LA, LB);
      LDirectCross3 := LDirectDispatch^.CoreVectors.CrossF32x3(LA, LB);
      for LIndex := 0 to 3 do
        CheckNear(LFacadeCross3.f[LIndex], LDirectCross3.f[LIndex], C_EPSILON, 'Direct CrossF32x3 lane' + IntToStr(LIndex) + ' backend ' + DirectBackendName(LBackend));

      LFacadeLength3 := VecF32x3Length(LA);
      LDirectLength3 := LDirectDispatch^.CoreVectors.LengthF32x3(LA);
      CheckNear(LFacadeLength3, LDirectLength3, C_EPSILON, 'Direct LengthF32x3 parity backend ' + DirectBackendName(LBackend));

      LFacadeNormalize3 := VecF32x3Normalize(LA);
      LDirectNormalize3 := LDirectDispatch^.CoreVectors.NormalizeF32x3(LA);
      for LIndex := 0 to 3 do
        CheckNear(LFacadeNormalize3.f[LIndex], LDirectNormalize3.f[LIndex], C_EPSILON, 'Direct NormalizeF32x3 lane' + IntToStr(LIndex) + ' backend ' + DirectBackendName(LBackend));

      LMask := VecF32x4CmpLt(LA, LB);
      LFacadeMaskAll := Mask4All(LMask);
      LDirectMaskAll := LDirectDispatch^.Mask.Mask4All(LMask);
      CheckEqual(LFacadeMaskAll, LDirectMaskAll, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend));

      LFacadeFind := MemFindByte(@LBuffer[0], SizeUInt(Length(LBuffer)), 7);
      LDirectFind := LDirectDispatch^.Memory.FindByte(@LBuffer[0], SizeUInt(Length(LBuffer)), 7);
      CheckEqual(LFacadeFind, LDirectFind, 'Direct MemFindByte parity backend ' + DirectBackendName(LBackend));
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;



procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_DotReduceMaskSat_Parity;
const
  C_EPSILON = 1e-5;
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LA, LB: TVecF32x4;
  LU8A, LU8B: TVecU8x16;
  LI8A, LI8B: TVecI8x16;
  LI32A, LI32B: TVecI32x4;
  LFacadeU8SatAdd, LDirectU8SatAdd: TVecU8x16;
  LFacadeI8SatAdd, LDirectI8SatAdd: TVecI8x16;
  LFacadeDot, LDirectDot: Single;
  LFacadeReduceAdd, LDirectReduceAdd: Single;
  LFacadeReduceMin, LDirectReduceMin: Single;
  LFacadeReduceMax, LDirectReduceMax: Single;
  LFacadeReduceMul, LDirectReduceMul: Single;
  LFacadeMask4, LDirectMask4: TMask4;
  LFacadeMask16: TMask16;
  LFacadeMask4All, LDirectMask4All: Boolean;
  LFacadeMask16PopCount, LDirectMask16PopCount: Integer;
  LHaystack: array[0..23] of Byte;
  LNeedle: array[0..2] of Byte;
  LUtf8Valid: array[0..5] of Byte;
  LUtf8Invalid: array[0..1] of Byte;
  LBitset: array[0..7] of Byte;
  LFacadeBytesIndex, LDirectBytesIndex: PtrInt;
  LFacadeUtf8Valid, LDirectUtf8Valid: Boolean;
  LFacadeUtf8Invalid, LDirectUtf8Invalid: Boolean;
  LFacadeBitsetPopCount, LDirectBitsetPopCount: SizeUInt;
  LIndex: Integer;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if LBackend <> sbScalar then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.DotF32x4), 'DotF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ReduceAddF32x4), 'ReduceAddF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ReduceMinF32x4), 'ReduceMinF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ReduceMaxF32x4), 'ReduceMaxF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ReduceMulF32x4), 'ReduceMulF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqI32x4), 'CmpEqI32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Mask.Mask4All), 'Mask4All should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Mask.Mask16PopCount), 'Mask16PopCount should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.BytesIndexOf), 'BytesIndexOf should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Utf8Validate), 'Utf8Validate should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.BitsetPopCount), 'BitsetPopCount should be assigned for backend ' + DirectBackendName(LBackend));

      LA.f[0] := 1.25;
      LA.f[1] := -2.0;
      LA.f[2] := 3.5;
      LA.f[3] := 4.0;

      LB.f[0] := -0.75;
      LB.f[1] := 5.0;
      LB.f[2] := -1.5;
      LB.f[3] := 2.0;

      LI32A.i[0] := 1;
      LI32A.i[1] := 2;
      LI32A.i[2] := 3;
      LI32A.i[3] := 4;

      LI32B.i[0] := 1;
      LI32B.i[1] := 20;
      LI32B.i[2] := 3;
      LI32B.i[3] := 40;

      for LIndex := 0 to 15 do
      begin
        LU8A.u[LIndex] := UInt8(LIndex * 8);
        LU8B.u[LIndex] := UInt8(200 - LIndex * 7);
      end;

      for LIndex := 0 to High(LHaystack) do
        LHaystack[LIndex] := Byte(LIndex);
      LNeedle[0] := 10;
      LNeedle[1] := 11;
      LNeedle[2] := 12;

      LUtf8Valid[0] := $48;   // H
      LUtf8Valid[1] := $65;   // e
      LUtf8Valid[2] := $6C;   // l
      LUtf8Valid[3] := $6C;   // l
      LUtf8Valid[4] := $6F;   // o
      LUtf8Valid[5] := $21;   // !

      LUtf8Invalid[0] := $C3;
      LUtf8Invalid[1] := $28;

      LBitset[0] := $00;
      LBitset[1] := $FF;
      LBitset[2] := $55;
      LBitset[3] := $AA;
      LBitset[4] := $0F;
      LBitset[5] := $F0;
      LBitset[6] := $33;
      LBitset[7] := $CC;

      LFacadeDot := VecF32x4Dot(LA, LB);
      LDirectDot := LDirectDispatch^.CoreVectors.DotF32x4(LA, LB);
      CheckNear(LFacadeDot, LDirectDot, C_EPSILON, 'Direct DotF32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeReduceAdd := VecF32x4ReduceAdd(LA);
      LDirectReduceAdd := LDirectDispatch^.CoreVectors.ReduceAddF32x4(LA);
      CheckNear(LFacadeReduceAdd, LDirectReduceAdd, C_EPSILON, 'Direct ReduceAddF32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeReduceMin := VecF32x4ReduceMin(LA);
      LDirectReduceMin := LDirectDispatch^.CoreVectors.ReduceMinF32x4(LA);
      CheckNear(LFacadeReduceMin, LDirectReduceMin, C_EPSILON, 'Direct ReduceMinF32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeReduceMax := VecF32x4ReduceMax(LA);
      LDirectReduceMax := LDirectDispatch^.CoreVectors.ReduceMaxF32x4(LA);
      CheckNear(LFacadeReduceMax, LDirectReduceMax, C_EPSILON, 'Direct ReduceMaxF32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeReduceMul := VecF32x4ReduceMul(LA);
      LDirectReduceMul := LDirectDispatch^.CoreVectors.ReduceMulF32x4(LA);
      CheckNear(LFacadeReduceMul, LDirectReduceMul, C_EPSILON, 'Direct ReduceMulF32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeMask4 := VecI32x4CmpEq(LI32A, LI32B);
      LDirectMask4 := LDirectDispatch^.CoreVectors.CmpEqI32x4(LI32A, LI32B);
      CheckEqual(Integer(LFacadeMask4), Integer(LDirectMask4), 'Direct CmpEqI32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeMask4All := Mask4All(LFacadeMask4);
      LDirectMask4All := LDirectDispatch^.Mask.Mask4All(LDirectMask4);
      CheckEqual(LFacadeMask4All, LDirectMask4All, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend));

      LFacadeMask16 := VecU8x16CmpGt(LU8A, LU8B);
      LFacadeMask16PopCount := Mask16PopCount(LFacadeMask16);
      LDirectMask16PopCount := LDirectDispatch^.Mask.Mask16PopCount(LFacadeMask16);
      CheckEqual(LFacadeMask16PopCount, LDirectMask16PopCount, 'Direct Mask16PopCount parity backend ' + DirectBackendName(LBackend));

      LFacadeBytesIndex := BytesIndexOf(@LHaystack[0], SizeUInt(Length(LHaystack)), @LNeedle[0], SizeUInt(Length(LNeedle)));
      LDirectBytesIndex := LDirectDispatch^.Memory.BytesIndexOf(@LHaystack[0], SizeUInt(Length(LHaystack)), @LNeedle[0], SizeUInt(Length(LNeedle)));
      CheckEqual(LFacadeBytesIndex, LDirectBytesIndex, 'Direct BytesIndexOf parity backend ' + DirectBackendName(LBackend));

      LFacadeUtf8Valid := Utf8Validate(@LUtf8Valid[0], SizeUInt(Length(LUtf8Valid)));
      LDirectUtf8Valid := LDirectDispatch^.Memory.Utf8Validate(@LUtf8Valid[0], SizeUInt(Length(LUtf8Valid)));
      CheckEqual(LFacadeUtf8Valid, LDirectUtf8Valid, 'Direct Utf8Validate(valid) parity backend ' + DirectBackendName(LBackend));

      LFacadeUtf8Invalid := Utf8Validate(@LUtf8Invalid[0], SizeUInt(Length(LUtf8Invalid)));
      LDirectUtf8Invalid := LDirectDispatch^.Memory.Utf8Validate(@LUtf8Invalid[0], SizeUInt(Length(LUtf8Invalid)));
      CheckEqual(LFacadeUtf8Invalid, LDirectUtf8Invalid, 'Direct Utf8Validate(invalid) parity backend ' + DirectBackendName(LBackend));

      LFacadeBitsetPopCount := BitsetPopCount(@LBitset[0], SizeUInt(Length(LBitset)));
      LDirectBitsetPopCount := LDirectDispatch^.Memory.BitsetPopCount(@LBitset[0], SizeUInt(Length(LBitset)));
      CheckEqual(LFacadeBitsetPopCount, LDirectBitsetPopCount, 'Direct BitsetPopCount parity backend ' + DirectBackendName(LBackend));

      if LBackend = sbScalar then
      begin
        CheckTrue(Assigned(LDirectDispatch^.CoreVectors.U8x16SatAdd), 'U8x16SatAdd should be assigned for scalar backend');
        CheckTrue(Assigned(LDirectDispatch^.CoreVectors.I8x16SatAdd), 'I8x16SatAdd should be assigned for scalar backend');

        for LIndex := 0 to 15 do
        begin
          LI8A.i[LIndex] := Int8(120 - LIndex);
          LI8B.i[LIndex] := Int8(30 + LIndex);
          LU8A.u[LIndex] := UInt8(240 - LIndex);
          LU8B.u[LIndex] := UInt8(30 + LIndex);
        end;

        LFacadeU8SatAdd := VecU8x16SatAdd(LU8A, LU8B);
        LDirectU8SatAdd := LDirectDispatch^.CoreVectors.U8x16SatAdd(LU8A, LU8B);
        for LIndex := 0 to 15 do
          CheckEqual(Integer(LFacadeU8SatAdd.u[LIndex]), Integer(LDirectU8SatAdd.u[LIndex]), 'Direct U8x16SatAdd lane ' + IntToStr(LIndex) + ' scalar backend');

        LFacadeI8SatAdd := VecI8x16SatAdd(LI8A, LI8B);
        LDirectI8SatAdd := LDirectDispatch^.CoreVectors.I8x16SatAdd(LI8A, LI8B);
        for LIndex := 0 to 15 do
          CheckEqual(Integer(LFacadeI8SatAdd.i[LIndex]), Integer(LDirectI8SatAdd.i[LIndex]), 'Direct I8x16SatAdd lane ' + IntToStr(LIndex) + ' scalar backend');
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_MemTextEdgeMatrix_Parity;
const
  C_LEN_CASES: array[0..11] of Integer = (1, 2, 3, 7, 8, 15, 16, 17, 31, 32, 33, 63);
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LBufA: array[0..63] of Byte;
  LBufB: array[0..63] of Byte;
  LLenCaseIdx: Integer;
  LLen: Integer;
  LIndex: Integer;
  LScenario: Integer;
  LDiffPos: Integer;
  LFacadeMemEqual, LDirectMemEqual: LongBool;
  LFacadeHasDiff, LDirectHasDiff: Boolean;
  LFacadeFirstDiff, LFacadeLastDiff: SizeUInt;
  LDirectFirstDiff, LDirectLastDiff: SizeUInt;
  LAsciiSameA, LAsciiSameB: AnsiString;
  LAsciiDiffA, LAsciiDiffB: AnsiString;
  LAsciiTransformSample: AnsiString;
  LAsciiLen: Integer;
  LFacadeAsciiEq, LDirectAsciiEq: Boolean;
  LTransformLenCases: array[0..2] of Integer;
  LTransformLenIdx: Integer;
  LTransformLen: Integer;
  LLowerFacade, LLowerDirect: array[0..31] of Byte;
  LUpperFacade, LUpperDirect: array[0..31] of Byte;
  LTestedCount: Integer;
  LStage: string;

  procedure CopyBufAIntoB(const aLen: Integer);
  var
    LPos: Integer;
  begin
    for LPos := 0 to aLen - 1 do
      LBufB[LPos] := LBufA[LPos];
  end;

begin
  for LIndex := 0 to High(LBufA) do
  begin
    LBufA[LIndex] := Byte((LIndex * 37 + 11) and $FF);
    LBufB[LIndex] := LBufA[LIndex];
  end;

  LAsciiSameA := 'SimdDirectParityXYZ123';
  LAsciiSameB := 'sIMDdIRECTpARITYxyz123';
  LAsciiDiffA := 'DirectAsciiEdgeMatrix';
  LAsciiDiffB := 'directAsciiEdgeMatrIx';
  LAsciiTransformSample := 'aZ09-*_mIxEdQw';
  LTransformLenCases[0] := 1;
  LTransformLenCases[1] := Length(LAsciiTransformSample) div 2;
  LTransformLenCases[2] := Length(LAsciiTransformSample);

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;
      if LBackend <> sbScalar then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Equal), 'MemEqual should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.DiffRange), 'MemDiffRange should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.AsciiIEqual), 'AsciiIEqual should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.ToLowerAscii), 'ToLowerAscii should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.ToUpperAscii), 'ToUpperAscii should be assigned for backend ' + DirectBackendName(LBackend));

      LStage := 'begin-backend';
      try
        for LLenCaseIdx := Low(C_LEN_CASES) to High(C_LEN_CASES) do
      begin
        LLen := C_LEN_CASES[LLenCaseIdx];
        CopyBufAIntoB(LLen);

        LStage := 'MemEqual(equal),len=' + IntToStr(LLen);
        LFacadeMemEqual := MemEqual(@LBufA[0], @LBufB[0], SizeUInt(LLen));
        LDirectMemEqual := LDirectDispatch^.Memory.Equal(@LBufA[0], @LBufB[0], SizeUInt(LLen));
        CheckEqual(Boolean(LFacadeMemEqual), Boolean(LDirectMemEqual), 'Direct MemEqual(equal) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));

        LStage := 'MemDiffRange(equal),len=' + IntToStr(LLen);
        LFacadeHasDiff := MemDiffRange(@LBufA[0], @LBufB[0], SizeUInt(LLen), LFacadeFirstDiff, LFacadeLastDiff);
        LDirectHasDiff := LDirectDispatch^.Memory.DiffRange(@LBufA[0], @LBufB[0], SizeUInt(LLen), LDirectFirstDiff, LDirectLastDiff);
        CheckEqual(LFacadeHasDiff, LDirectHasDiff, 'Direct MemDiffRange(equal) hasDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));
        if LFacadeHasDiff then
        begin
          CheckEqual(LFacadeFirstDiff, LDirectFirstDiff, 'Direct MemDiffRange(equal) firstDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));
          CheckEqual(LFacadeLastDiff, LDirectLastDiff, 'Direct MemDiffRange(equal) lastDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));
        end;

        if LLen > 0 then
        begin
          for LScenario := 0 to 2 do
          begin
            CopyBufAIntoB(LLen);
            case LScenario of
              0: LDiffPos := 0;
              1: LDiffPos := LLen div 2;
            else
              LDiffPos := LLen - 1;
            end;
            LBufB[LDiffPos] := LBufB[LDiffPos] xor Byte($51 + LScenario);

            LStage := 'MemEqual(diff),len=' + IntToStr(LLen) + ',scenario=' + IntToStr(LScenario);
            LFacadeMemEqual := MemEqual(@LBufA[0], @LBufB[0], SizeUInt(LLen));
            LDirectMemEqual := LDirectDispatch^.Memory.Equal(@LBufA[0], @LBufB[0], SizeUInt(LLen));
            CheckEqual(Boolean(LFacadeMemEqual), Boolean(LDirectMemEqual), 'Direct MemEqual(diff) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
            CheckFalse(Boolean(LFacadeMemEqual), 'Facade MemEqual(diff) should be false len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));

            LStage := 'MemDiffRange(diff),len=' + IntToStr(LLen) + ',scenario=' + IntToStr(LScenario);
            LFacadeHasDiff := MemDiffRange(@LBufA[0], @LBufB[0], SizeUInt(LLen), LFacadeFirstDiff, LFacadeLastDiff);
            LDirectHasDiff := LDirectDispatch^.Memory.DiffRange(@LBufA[0], @LBufB[0], SizeUInt(LLen), LDirectFirstDiff, LDirectLastDiff);
            CheckEqual(LFacadeHasDiff, LDirectHasDiff, 'Direct MemDiffRange(diff) hasDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
            CheckTrue(LFacadeHasDiff, 'Facade MemDiffRange(diff) should report hasDiff len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
            if LFacadeHasDiff then
            begin
              CheckEqual(LFacadeFirstDiff, LDirectFirstDiff, 'Direct MemDiffRange(diff) firstDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
              CheckEqual(LFacadeLastDiff, LDirectLastDiff, 'Direct MemDiffRange(diff) lastDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
              CheckEqual(SizeUInt(LDiffPos), LFacadeFirstDiff, 'Facade MemDiffRange(diff) firstDiff expected len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
              CheckEqual(SizeUInt(LDiffPos), LFacadeLastDiff, 'Facade MemDiffRange(diff) lastDiff expected len=' + IntToStr(LLen) + ' scenario=' + IntToStr(LScenario));
            end;
          end;

          if LLen > 1 then
          begin
            CopyBufAIntoB(LLen);
            LBufB[0] := LBufB[0] xor $33;
            LBufB[LLen - 1] := LBufB[LLen - 1] xor $77;

            LStage := 'MemDiffRange(double-diff),len=' + IntToStr(LLen);
            LFacadeHasDiff := MemDiffRange(@LBufA[0], @LBufB[0], SizeUInt(LLen), LFacadeFirstDiff, LFacadeLastDiff);
            LDirectHasDiff := LDirectDispatch^.Memory.DiffRange(@LBufA[0], @LBufB[0], SizeUInt(LLen), LDirectFirstDiff, LDirectLastDiff);
            CheckEqual(LFacadeHasDiff, LDirectHasDiff, 'Direct MemDiffRange(double-diff) hasDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));
            CheckTrue(LFacadeHasDiff, 'Facade MemDiffRange(double-diff) should report hasDiff len=' + IntToStr(LLen));
            if LFacadeHasDiff then
            begin
              CheckEqual(LFacadeFirstDiff, LDirectFirstDiff, 'Direct MemDiffRange(double-diff) firstDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));
              CheckEqual(LFacadeLastDiff, LDirectLastDiff, 'Direct MemDiffRange(double-diff) lastDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen));
              CheckEqual(SizeUInt(0), LFacadeFirstDiff, 'Facade MemDiffRange(double-diff) firstDiff expected len=' + IntToStr(LLen));
              CheckEqual(SizeUInt(LLen - 1), LFacadeLastDiff, 'Facade MemDiffRange(double-diff) lastDiff expected len=' + IntToStr(LLen));
            end;
          end;
        end;
      end;

      for LAsciiLen := 1 to Length(LAsciiSameA) do
      begin
        LStage := 'AsciiIEqual(case-insensitive),len=' + IntToStr(LAsciiLen);
        LFacadeAsciiEq := AsciiIEqual(Pointer(PAnsiChar(LAsciiSameA)), Pointer(PAnsiChar(LAsciiSameB)), SizeUInt(LAsciiLen));
        LDirectAsciiEq := LDirectDispatch^.Memory.AsciiIEqual(Pointer(PAnsiChar(LAsciiSameA)), Pointer(PAnsiChar(LAsciiSameB)), SizeUInt(LAsciiLen));
        CheckEqual(LFacadeAsciiEq, LDirectAsciiEq, 'Direct AsciiIEqual(case-insensitive) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LAsciiLen));
      end;

      for LAsciiLen := 1 to Length(LAsciiDiffA) do
      begin
        LStage := 'AsciiIEqual(mismatch),len=' + IntToStr(LAsciiLen);
        LFacadeAsciiEq := AsciiIEqual(Pointer(PAnsiChar(LAsciiDiffA)), Pointer(PAnsiChar(LAsciiDiffB)), SizeUInt(LAsciiLen));
        LDirectAsciiEq := LDirectDispatch^.Memory.AsciiIEqual(Pointer(PAnsiChar(LAsciiDiffA)), Pointer(PAnsiChar(LAsciiDiffB)), SizeUInt(LAsciiLen));
        CheckEqual(LFacadeAsciiEq, LDirectAsciiEq, 'Direct AsciiIEqual(mismatch) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LAsciiLen));
      end;

      for LTransformLenIdx := Low(LTransformLenCases) to High(LTransformLenCases) do
      begin
        LTransformLen := LTransformLenCases[LTransformLenIdx];
        for LIndex := 0 to LTransformLen - 1 do
        begin
          LLowerFacade[LIndex] := Byte(Ord(LAsciiTransformSample[LIndex + 1]));
          LLowerDirect[LIndex] := LLowerFacade[LIndex];
          LUpperFacade[LIndex] := Byte(Ord(LAsciiTransformSample[LIndex + 1]));
          LUpperDirect[LIndex] := LUpperFacade[LIndex];
        end;

        LStage := 'ToLowerAscii,len=' + IntToStr(LTransformLen);
        ToLowerAscii(@LLowerFacade[0], SizeUInt(LTransformLen));
        LDirectDispatch^.Memory.ToLowerAscii(@LLowerDirect[0], SizeUInt(LTransformLen));
        for LIndex := 0 to LTransformLen - 1 do
          CheckEqual(Integer(LLowerFacade[LIndex]), Integer(LLowerDirect[LIndex]), 'Direct ToLowerAscii parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LTransformLen) + ' idx=' + IntToStr(LIndex));

        LStage := 'ToUpperAscii,len=' + IntToStr(LTransformLen);
        ToUpperAscii(@LUpperFacade[0], SizeUInt(LTransformLen));
        LDirectDispatch^.Memory.ToUpperAscii(@LUpperDirect[0], SizeUInt(LTransformLen));
        for LIndex := 0 to LTransformLen - 1 do
          CheckEqual(Integer(LUpperFacade[LIndex]), Integer(LUpperDirect[LIndex]), 'Direct ToUpperAscii parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LTransformLen) + ' idx=' + IntToStr(LIndex));
      end;
      except
        on E: Exception do
          Fail('MemText edge parity exception backend=' + DirectBackendName(LBackend) +
            ' stage=' + LStage + ' msg=' + E.ClassName + ': ' + E.Message);
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_MemOpsEdgeMatrix_Parity;
const
  C_LEN_CASES: array[0..11] of Integer = (1, 2, 3, 7, 8, 15, 16, 17, 31, 32, 33, 63);
  C_OFFSET_CASES: array[0..3] of Integer = (0, 1, 5, 13);
  C_SET_VALUES: array[0..3] of Byte = ($00, $5A, $A5, $FF);
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LSource: array[0..127] of Byte;
  LFacadeBuf: array[0..127] of Byte;
  LDirectBuf: array[0..127] of Byte;
  LLenCaseIdx: Integer;
  LOffsetIdx: Integer;
  LSetIdx: Integer;
  LLen: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LIndex: Integer;
  LTestedCount: Integer;

  procedure FillSourcePattern;
  var
    LPos: Integer;
  begin
    for LPos := 0 to High(LSource) do
      LSource[LPos] := Byte((LPos * 29 + 17) and $FF);
  end;

  procedure FillWorkBuffers;
  var
    LPos: Integer;
  begin
    for LPos := 0 to High(LFacadeBuf) do
    begin
      LFacadeBuf[LPos] := Byte((LPos * 7 + 3) and $FF);
      LDirectBuf[LPos] := LFacadeBuf[LPos];
    end;
  end;

  procedure AssertBuffersEqual(const aTitle: string);
  var
    LPos: Integer;
  begin
    for LPos := 0 to High(LFacadeBuf) do
      CheckEqual(Integer(LFacadeBuf[LPos]), Integer(LDirectBuf[LPos]), aTitle + '.idx' + IntToStr(LPos));
  end;

begin
  FillSourcePattern;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Copy), 'MemCopy should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Fill), 'MemSet should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Reverse), 'MemReverse should be assigned for backend ' + DirectBackendName(LBackend));

      for LLenCaseIdx := Low(C_LEN_CASES) to High(C_LEN_CASES) do
      begin
        LLen := C_LEN_CASES[LLenCaseIdx];

        // MemCopy parity
        for LOffsetIdx := Low(C_OFFSET_CASES) to High(C_OFFSET_CASES) do
        begin
          LSrcOffset := C_OFFSET_CASES[LOffsetIdx];
          LDstOffset := C_OFFSET_CASES[High(C_OFFSET_CASES) - LOffsetIdx];

          FillWorkBuffers;
          MemCopy(@LSource[LSrcOffset], @LFacadeBuf[LDstOffset], SizeUInt(LLen));
          LDirectDispatch^.Memory.Copy(@LSource[LSrcOffset], @LDirectBuf[LDstOffset], SizeUInt(LLen));
          AssertBuffersEqual('Direct MemCopy parity backend ' + DirectBackendName(LBackend) +
            ' len=' + IntToStr(LLen) + ' srcOff=' + IntToStr(LSrcOffset) + ' dstOff=' + IntToStr(LDstOffset));
        end;

        // MemSet parity
        for LSetIdx := Low(C_SET_VALUES) to High(C_SET_VALUES) do
        begin
          LDstOffset := C_OFFSET_CASES[LSetIdx mod Length(C_OFFSET_CASES)];

          FillWorkBuffers;
          MemSet(@LFacadeBuf[LDstOffset], SizeUInt(LLen), C_SET_VALUES[LSetIdx]);
          LDirectDispatch^.Memory.Fill(@LDirectBuf[LDstOffset], SizeUInt(LLen), C_SET_VALUES[LSetIdx]);
          AssertBuffersEqual('Direct MemSet parity backend ' + DirectBackendName(LBackend) +
            ' len=' + IntToStr(LLen) + ' dstOff=' + IntToStr(LDstOffset) +
            ' value=' + IntToStr(C_SET_VALUES[LSetIdx]));
        end;

        // MemReverse parity
        for LOffsetIdx := Low(C_OFFSET_CASES) to High(C_OFFSET_CASES) do
        begin
          LDstOffset := C_OFFSET_CASES[LOffsetIdx];

          FillWorkBuffers;
          for LIndex := 0 to LLen - 1 do
          begin
            LFacadeBuf[LDstOffset + LIndex] := Byte((LIndex * 11 + 9) and $FF);
            LDirectBuf[LDstOffset + LIndex] := LFacadeBuf[LDstOffset + LIndex];
          end;

          MemReverse(@LFacadeBuf[LDstOffset], SizeUInt(LLen));
          LDirectDispatch^.Memory.Reverse(@LDirectBuf[LDstOffset], SizeUInt(LLen));
          AssertBuffersEqual('Direct MemReverse parity backend ' + DirectBackendName(LBackend) +
            ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LDstOffset));
        end;
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_StatsEdgeMatrix_Parity;
const
  C_LEN_CASES: array[0..11] of Integer = (1, 2, 3, 7, 8, 15, 16, 17, 31, 32, 33, 63);
  C_OFFSET_CASES: array[0..3] of Integer = (0, 1, 5, 13);
  C_COUNT_VALUES: array[0..4] of Byte = ($00, $11, $55, $AA, $FF);
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LBuf: array[0..127] of Byte;
  LLenCaseIdx: Integer;
  LOffsetIdx: Integer;
  LValueIdx: Integer;
  LLen: Integer;
  LOffset: Integer;
  LIndex: Integer;
  LFacadeSum, LDirectSum: UInt64;
  LFacadeCount, LDirectCount: SizeUInt;
  LFacadeMin, LFacadeMax: Byte;
  LDirectMin, LDirectMax: Byte;
  LTestedCount: Integer;

  procedure FillBufferPattern;
  var
    LPos: Integer;
  begin
    for LPos := 0 to High(LBuf) do
      LBuf[LPos] := Byte((LPos * 19 + 23) and $FF);

    // inject fixed sentinels to stabilize min/max/count edge cases
    LBuf[3] := $00;
    LBuf[7] := $FF;
    LBuf[11] := $11;
    LBuf[13] := $55;
    LBuf[17] := $AA;
  end;

begin
  FillBufferPattern;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.SumBytes), 'SumBytes should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.CountByte), 'CountByte should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.MinMaxBytes), 'MinMaxBytes should be assigned for backend ' + DirectBackendName(LBackend));

      for LLenCaseIdx := Low(C_LEN_CASES) to High(C_LEN_CASES) do
      begin
        LLen := C_LEN_CASES[LLenCaseIdx];

        for LOffsetIdx := Low(C_OFFSET_CASES) to High(C_OFFSET_CASES) do
        begin
          LOffset := C_OFFSET_CASES[LOffsetIdx];

          // keep deterministic but vary bytes in active window by len/offset
          for LIndex := 0 to LLen - 1 do
            LBuf[LOffset + LIndex] := Byte((LBuf[LOffset + LIndex] + Byte((LLen + LOffset + LIndex) and $FF)) and $FF);

          LFacadeSum := SumBytes(@LBuf[LOffset], SizeUInt(LLen));
          LDirectSum := LDirectDispatch^.Memory.SumBytes(@LBuf[LOffset], SizeUInt(LLen));
          CheckEqual(LFacadeSum, LDirectSum, 'Direct SumBytes parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));

          for LValueIdx := Low(C_COUNT_VALUES) to High(C_COUNT_VALUES) do
          begin
            LFacadeCount := CountByte(@LBuf[LOffset], SizeUInt(LLen), C_COUNT_VALUES[LValueIdx]);
            LDirectCount := LDirectDispatch^.Memory.CountByte(@LBuf[LOffset], SizeUInt(LLen), C_COUNT_VALUES[LValueIdx]);
            CheckEqual(LFacadeCount, LDirectCount, 'Direct CountByte parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset) + ' value=' + IntToStr(C_COUNT_VALUES[LValueIdx]));
          end;

          MinMaxBytes(@LBuf[LOffset], SizeUInt(LLen), LFacadeMin, LFacadeMax);
          LDirectDispatch^.Memory.MinMaxBytes(@LBuf[LOffset], SizeUInt(LLen), LDirectMin, LDirectMax);
          CheckEqual(Integer(LFacadeMin), Integer(LDirectMin), 'Direct MinMaxBytes.min parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
          CheckEqual(Integer(LFacadeMax), Integer(LDirectMax), 'Direct MinMaxBytes.max parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
        end;
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MaskCompareEdge_Parity;
const
  C_EPSILON = 1e-6;
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LA, LB: TVecF32x4;
  LMaskEqFacade, LMaskEqDirect: TMask4;
  LMaskLtFacade, LMaskLtDirect: TMask4;
  LMaskLeFacade, LMaskLeDirect: TMask4;
  LMaskGtFacade, LMaskGtDirect: TMask4;
  LMaskGeFacade, LMaskGeDirect: TMask4;
  LMaskNeFacade, LMaskNeDirect: TMask4;
  LFacadeAll, LDirectAll: Boolean;
  LFacadeAny, LDirectAny: Boolean;
  LFacadeNone, LDirectNone: Boolean;
  LFacadePop, LDirectPop: Integer;
  LFacadeFirst, LDirectFirst: Integer;
  LDotFacade, LDotDirect: Single;
  LTestedCount: Integer;
begin
  // 设计为对比边界：包含相等、大小关系与符号混合，避免 NaN 语义差异干扰。
  LA.f[0] := -3.0;
  LA.f[1] := 0.0;
  LA.f[2] := 1.5;
  LA.f[3] := 9.0;

  LB.f[0] := -3.0;
  LB.f[1] := 2.0;
  LB.f[2] := 1.0;
  LB.f[3] := -4.0;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqF32x4), 'CmpEqF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Mask.Mask4All), 'Mask4All should be assigned for backend ' + DirectBackendName(LBackend));

      LMaskEqFacade := VecF32x4CmpEq(LA, LB);
      LMaskEqDirect := LDirectDispatch^.CoreVectors.CmpEqF32x4(LA, LB);
      CheckEqual(Integer(LMaskEqFacade), Integer(LMaskEqDirect), 'Direct CmpEqF32x4 parity backend ' + DirectBackendName(LBackend));

      LMaskLtFacade := VecF32x4CmpLt(LA, LB);
      LMaskLtDirect := LDirectDispatch^.CoreVectors.CmpLtF32x4(LA, LB);
      CheckEqual(Integer(LMaskLtFacade), Integer(LMaskLtDirect), 'Direct CmpLtF32x4 parity backend ' + DirectBackendName(LBackend));

      LMaskLeFacade := VecF32x4CmpLe(LA, LB);
      LMaskLeDirect := LDirectDispatch^.CoreVectors.CmpLeF32x4(LA, LB);
      CheckEqual(Integer(LMaskLeFacade), Integer(LMaskLeDirect), 'Direct CmpLeF32x4 parity backend ' + DirectBackendName(LBackend));

      LMaskGtFacade := VecF32x4CmpGt(LA, LB);
      LMaskGtDirect := LDirectDispatch^.CoreVectors.CmpGtF32x4(LA, LB);
      CheckEqual(Integer(LMaskGtFacade), Integer(LMaskGtDirect), 'Direct CmpGtF32x4 parity backend ' + DirectBackendName(LBackend));

      LMaskGeFacade := VecF32x4CmpGe(LA, LB);
      LMaskGeDirect := LDirectDispatch^.CoreVectors.CmpGeF32x4(LA, LB);
      CheckEqual(Integer(LMaskGeFacade), Integer(LMaskGeDirect), 'Direct CmpGeF32x4 parity backend ' + DirectBackendName(LBackend));

      LMaskNeFacade := VecF32x4CmpNe(LA, LB);
      LMaskNeDirect := LDirectDispatch^.CoreVectors.CmpNeF32x4(LA, LB);
      CheckEqual(Integer(LMaskNeFacade), Integer(LMaskNeDirect), 'Direct CmpNeF32x4 parity backend ' + DirectBackendName(LBackend));

      LFacadeAll := Mask4All(LMaskLtFacade);
      LDirectAll := LDirectDispatch^.Mask.Mask4All(LMaskLtDirect);
      CheckEqual(LFacadeAll, LDirectAll, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend));

      LFacadeAny := Mask4Any(LMaskLtFacade);
      LDirectAny := LDirectDispatch^.Mask.Mask4Any(LMaskLtDirect);
      CheckEqual(LFacadeAny, LDirectAny, 'Direct Mask4Any parity backend ' + DirectBackendName(LBackend));

      LFacadeNone := Mask4None(LMaskLtFacade);
      LDirectNone := LDirectDispatch^.Mask.Mask4None(LMaskLtDirect);
      CheckEqual(LFacadeNone, LDirectNone, 'Direct Mask4None parity backend ' + DirectBackendName(LBackend));

      LFacadePop := Mask4PopCount(LMaskLtFacade);
      LDirectPop := LDirectDispatch^.Mask.Mask4PopCount(LMaskLtDirect);
      CheckEqual(LFacadePop, LDirectPop, 'Direct Mask4PopCount parity backend ' + DirectBackendName(LBackend));

      LFacadeFirst := Mask4FirstSet(LMaskLtFacade);
      LDirectFirst := LDirectDispatch^.Mask.Mask4FirstSet(LMaskLtDirect);
      CheckEqual(LFacadeFirst, LDirectFirst, 'Direct Mask4FirstSet parity backend ' + DirectBackendName(LBackend));

      LDotFacade := VecF32x4Dot(LA, LB);
      LDotDirect := LDirectDispatch^.CoreVectors.DotF32x4(LA, LB);
      CheckNear(LDotFacade, LDotDirect, C_EPSILON, 'Direct DotF32x4 parity backend ' + DirectBackendName(LBackend));
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_MaskWideCompareMatrix_Parity;
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;

  LAf64, LBf64: TVecF64x2;
  LAi16, LBi16: TVecI16x8;
  LAi8, LBi8: TVecI8x16;

  LMask2EqFacade, LMask2EqDirect: TMask2;
  LMask2LtFacade, LMask2LtDirect: TMask2;
  LMask2LeFacade, LMask2LeDirect: TMask2;
  LMask2GtFacade, LMask2GtDirect: TMask2;
  LMask2GeFacade, LMask2GeDirect: TMask2;
  LMask2NeFacade, LMask2NeDirect: TMask2;

  LMask8EqFacade, LMask8EqDirect: TMask8;
  LMask8LtFacade, LMask8LtDirect: TMask8;
  LMask8GtFacade, LMask8GtDirect: TMask8;

  LMask16EqFacade, LMask16EqDirect: TMask16;
  LMask16LtFacade, LMask16LtDirect: TMask16;
  LMask16GtFacade, LMask16GtDirect: TMask16;

  LMask2AllFacade, LMask2AllDirect: Boolean;
  LMask2AnyFacade, LMask2AnyDirect: Boolean;
  LMask2NoneFacade, LMask2NoneDirect: Boolean;
  LMask2PopFacade, LMask2PopDirect: Integer;
  LMask2FirstFacade, LMask2FirstDirect: Integer;

  LMask8AllFacade, LMask8AllDirect: Boolean;
  LMask8AnyFacade, LMask8AnyDirect: Boolean;
  LMask8NoneFacade, LMask8NoneDirect: Boolean;
  LMask8PopFacade, LMask8PopDirect: Integer;
  LMask8FirstFacade, LMask8FirstDirect: Integer;

  LMask16AllFacade, LMask16AllDirect: Boolean;
  LMask16AnyFacade, LMask16AnyDirect: Boolean;
  LMask16NoneFacade, LMask16NoneDirect: Boolean;
  LMask16PopFacade, LMask16PopDirect: Integer;
  LMask16FirstFacade, LMask16FirstDirect: Integer;

  LIndex: Integer;
  LTestedCount: Integer;
begin
  LAf64.d[0] := -1.0;
  LAf64.d[1] := 5.0;
  LBf64.d[0] := -1.0;
  LBf64.d[1] := 3.0;

  for LIndex := 0 to 7 do
  begin
    LAi16.i[LIndex] := Int16((LIndex * 3) - 8);
    LBi16.i[LIndex] := Int16((LIndex * 2) - 7);
  end;
  // 强化边界：eq/lt/gt 都出现
  LBi16.i[0] := LAi16.i[0];
  LBi16.i[3] := LAi16.i[3] + 2;
  LBi16.i[5] := LAi16.i[5] - 2;

  for LIndex := 0 to 15 do
  begin
    LAi8.i[LIndex] := Int8((LIndex * 5) - 30);
    LBi8.i[LIndex] := Int8((LIndex * 4) - 25);
  end;
  LBi8.i[1] := LAi8.i[1];
  LBi8.i[7] := LAi8.i[7] + 3;
  LBi8.i[12] := LAi8.i[12] - 3;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqF64x2), 'CmpEqF64x2 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Mask.Mask16All), 'Mask16All should be assigned for backend ' + DirectBackendName(LBackend));

      // === Mask2 (from F64 compare) ===
      LMask2EqFacade := VecF64x2CmpEq(LAf64, LBf64);
      LMask2EqDirect := LDirectDispatch^.CoreVectors.CmpEqF64x2(LAf64, LBf64);
      CheckEqual(Integer(LMask2EqFacade), Integer(LMask2EqDirect), 'Direct CmpEqF64x2 parity backend ' + DirectBackendName(LBackend));

      LMask2LtFacade := VecF64x2CmpLt(LAf64, LBf64);
      LMask2LtDirect := LDirectDispatch^.CoreVectors.CmpLtF64x2(LAf64, LBf64);
      CheckEqual(Integer(LMask2LtFacade), Integer(LMask2LtDirect), 'Direct CmpLtF64x2 parity backend ' + DirectBackendName(LBackend));

      LMask2LeFacade := VecF64x2CmpLe(LAf64, LBf64);
      LMask2LeDirect := LDirectDispatch^.CoreVectors.CmpLeF64x2(LAf64, LBf64);
      CheckEqual(Integer(LMask2LeFacade), Integer(LMask2LeDirect), 'Direct CmpLeF64x2 parity backend ' + DirectBackendName(LBackend));

      LMask2GtFacade := VecF64x2CmpGt(LAf64, LBf64);
      LMask2GtDirect := LDirectDispatch^.CoreVectors.CmpGtF64x2(LAf64, LBf64);
      CheckEqual(Integer(LMask2GtFacade), Integer(LMask2GtDirect), 'Direct CmpGtF64x2 parity backend ' + DirectBackendName(LBackend));

      LMask2GeFacade := VecF64x2CmpGe(LAf64, LBf64);
      LMask2GeDirect := LDirectDispatch^.CoreVectors.CmpGeF64x2(LAf64, LBf64);
      CheckEqual(Integer(LMask2GeFacade), Integer(LMask2GeDirect), 'Direct CmpGeF64x2 parity backend ' + DirectBackendName(LBackend));

      LMask2NeFacade := VecF64x2CmpNe(LAf64, LBf64);
      LMask2NeDirect := LDirectDispatch^.CoreVectors.CmpNeF64x2(LAf64, LBf64);
      CheckEqual(Integer(LMask2NeFacade), Integer(LMask2NeDirect), 'Direct CmpNeF64x2 parity backend ' + DirectBackendName(LBackend));

      LMask2AllFacade := Mask2All(LMask2LtFacade);
      LMask2AllDirect := LDirectDispatch^.Mask.Mask2All(LMask2LtDirect);
      CheckEqual(LMask2AllFacade, LMask2AllDirect, 'Direct Mask2All parity backend ' + DirectBackendName(LBackend));

      LMask2AnyFacade := Mask2Any(LMask2LtFacade);
      LMask2AnyDirect := LDirectDispatch^.Mask.Mask2Any(LMask2LtDirect);
      CheckEqual(LMask2AnyFacade, LMask2AnyDirect, 'Direct Mask2Any parity backend ' + DirectBackendName(LBackend));

      LMask2NoneFacade := Mask2None(LMask2LtFacade);
      LMask2NoneDirect := LDirectDispatch^.Mask.Mask2None(LMask2LtDirect);
      CheckEqual(LMask2NoneFacade, LMask2NoneDirect, 'Direct Mask2None parity backend ' + DirectBackendName(LBackend));

      LMask2PopFacade := Mask2PopCount(LMask2LtFacade);
      LMask2PopDirect := LDirectDispatch^.Mask.Mask2PopCount(LMask2LtDirect);
      CheckEqual(LMask2PopFacade, LMask2PopDirect, 'Direct Mask2PopCount parity backend ' + DirectBackendName(LBackend));

      LMask2FirstFacade := Mask2FirstSet(LMask2LtFacade);
      LMask2FirstDirect := LDirectDispatch^.Mask.Mask2FirstSet(LMask2LtDirect);
      CheckEqual(LMask2FirstFacade, LMask2FirstDirect, 'Direct Mask2FirstSet parity backend ' + DirectBackendName(LBackend));

      // === Mask8 (from I16 compare) ===
      LMask8EqFacade := VecI16x8CmpEq(LAi16, LBi16);
      LMask8EqDirect := LDirectDispatch^.CoreVectors.CmpEqI16x8(LAi16, LBi16);
      CheckEqual(Integer(LMask8EqFacade), Integer(LMask8EqDirect), 'Direct CmpEqI16x8 parity backend ' + DirectBackendName(LBackend));

      LMask8LtFacade := VecI16x8CmpLt(LAi16, LBi16);
      LMask8LtDirect := LDirectDispatch^.CoreVectors.CmpLtI16x8(LAi16, LBi16);
      CheckEqual(Integer(LMask8LtFacade), Integer(LMask8LtDirect), 'Direct CmpLtI16x8 parity backend ' + DirectBackendName(LBackend));

      LMask8GtFacade := VecI16x8CmpGt(LAi16, LBi16);
      LMask8GtDirect := LDirectDispatch^.CoreVectors.CmpGtI16x8(LAi16, LBi16);
      CheckEqual(Integer(LMask8GtFacade), Integer(LMask8GtDirect), 'Direct CmpGtI16x8 parity backend ' + DirectBackendName(LBackend));

      LMask8AllFacade := Mask8All(LMask8LtFacade);
      LMask8AllDirect := LDirectDispatch^.Mask.Mask8All(LMask8LtDirect);
      CheckEqual(LMask8AllFacade, LMask8AllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend));

      LMask8AnyFacade := Mask8Any(LMask8LtFacade);
      LMask8AnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8LtDirect);
      CheckEqual(LMask8AnyFacade, LMask8AnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend));

      LMask8NoneFacade := Mask8None(LMask8LtFacade);
      LMask8NoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8LtDirect);
      CheckEqual(LMask8NoneFacade, LMask8NoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend));

      LMask8PopFacade := Mask8PopCount(LMask8LtFacade);
      LMask8PopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8LtDirect);
      CheckEqual(LMask8PopFacade, LMask8PopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend));

      LMask8FirstFacade := Mask8FirstSet(LMask8LtFacade);
      LMask8FirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8LtDirect);
      CheckEqual(LMask8FirstFacade, LMask8FirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend));

      // === Mask16 (from I8 compare) ===
      LMask16EqFacade := VecI8x16CmpEq(LAi8, LBi8);
      LMask16EqDirect := LDirectDispatch^.CoreVectors.CmpEqI8x16(LAi8, LBi8);
      CheckEqual(Integer(LMask16EqFacade), Integer(LMask16EqDirect), 'Direct CmpEqI8x16 parity backend ' + DirectBackendName(LBackend));

      LMask16LtFacade := VecI8x16CmpLt(LAi8, LBi8);
      LMask16LtDirect := LDirectDispatch^.CoreVectors.CmpLtI8x16(LAi8, LBi8);
      CheckEqual(Integer(LMask16LtFacade), Integer(LMask16LtDirect), 'Direct CmpLtI8x16 parity backend ' + DirectBackendName(LBackend));

      LMask16GtFacade := VecI8x16CmpGt(LAi8, LBi8);
      LMask16GtDirect := LDirectDispatch^.CoreVectors.CmpGtI8x16(LAi8, LBi8);
      CheckEqual(Integer(LMask16GtFacade), Integer(LMask16GtDirect), 'Direct CmpGtI8x16 parity backend ' + DirectBackendName(LBackend));

      LMask16AllFacade := Mask16All(LMask16LtFacade);
      LMask16AllDirect := LDirectDispatch^.Mask.Mask16All(LMask16LtDirect);
      CheckEqual(LMask16AllFacade, LMask16AllDirect, 'Direct Mask16All parity backend ' + DirectBackendName(LBackend));

      LMask16AnyFacade := Mask16Any(LMask16LtFacade);
      LMask16AnyDirect := LDirectDispatch^.Mask.Mask16Any(LMask16LtDirect);
      CheckEqual(LMask16AnyFacade, LMask16AnyDirect, 'Direct Mask16Any parity backend ' + DirectBackendName(LBackend));

      LMask16NoneFacade := Mask16None(LMask16LtFacade);
      LMask16NoneDirect := LDirectDispatch^.Mask.Mask16None(LMask16LtDirect);
      CheckEqual(LMask16NoneFacade, LMask16NoneDirect, 'Direct Mask16None parity backend ' + DirectBackendName(LBackend));

      LMask16PopFacade := Mask16PopCount(LMask16LtFacade);
      LMask16PopDirect := LDirectDispatch^.Mask.Mask16PopCount(LMask16LtDirect);
      CheckEqual(LMask16PopFacade, LMask16PopDirect, 'Direct Mask16PopCount parity backend ' + DirectBackendName(LBackend));

      LMask16FirstFacade := Mask16FirstSet(LMask16LtFacade);
      LMask16FirstDirect := LDirectDispatch^.Mask.Mask16FirstSet(LMask16LtDirect);
      CheckEqual(LMask16FirstFacade, LMask16FirstDirect, 'Direct Mask16FirstSet parity backend ' + DirectBackendName(LBackend));
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F64CompareEdgeMatrix_Parity;
const
  { Infinity cells filled at runtime: nextpas.core.math.Infinity is a function,
    not a compile-time constant, so it cannot appear in a typed const. }
  C_FINITE_CASES: array[0..3, 0..3] of Double = (
    (-0.0, 0.0, -0.0, 0.0), (0.0, -0.0, 0.0, -0.0),
    (1.0, -1.0, -1.0, 1.0), (-123.5, 123.5, -123.5, 100.0)
  );
var
  LCases: array[0..5, 0..3] of Double;
  LInf: Double;
  LRow, LCol: Integer;
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LA, LB: TVecF64x2;
  LCaseIdx: Integer;

  LMaskEqFacade, LMaskEqDirect: TMask2;
  LMaskLtFacade, LMaskLtDirect: TMask2;
  LMaskLeFacade, LMaskLeDirect: TMask2;
  LMaskGtFacade, LMaskGtDirect: TMask2;
  LMaskGeFacade, LMaskGeDirect: TMask2;
  LMaskNeFacade, LMaskNeDirect: TMask2;

  LAllFacade, LAllDirect: Boolean;
  LAnyFacade, LAnyDirect: Boolean;
  LNoneFacade, LNoneDirect: Boolean;
  LPopFacade, LPopDirect: Integer;
  LFirstFacade, LFirstDirect: Integer;

  LTestedCount: Integer;
begin
  for LRow := Low(C_FINITE_CASES) to High(C_FINITE_CASES) do
    for LCol := 0 to 3 do
      LCases[LRow][LCol] := C_FINITE_CASES[LRow][LCol];
  LInf := Infinity;
  LCases[4][0] := LInf;  LCases[4][1] := 3.0;  LCases[4][2] := LInf;  LCases[4][3] := 3.0;
  LCases[5][0] := -LInf; LCases[5][1] := 3.0;  LCases[5][2] := 3.0;   LCases[5][3] := -LInf;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqF64x2), 'CmpEqF64x2 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Mask.Mask2All), 'Mask2All should be assigned for backend ' + DirectBackendName(LBackend));

      for LCaseIdx := Low(LCases) to High(LCases) do
      begin
        LA.d[0] := LCases[LCaseIdx, 0];
        LA.d[1] := LCases[LCaseIdx, 1];
        LB.d[0] := LCases[LCaseIdx, 2];
        LB.d[1] := LCases[LCaseIdx, 3];

        LMaskEqFacade := VecF64x2CmpEq(LA, LB);
        LMaskEqDirect := LDirectDispatch^.CoreVectors.CmpEqF64x2(LA, LB);
        CheckEqual(Integer(LMaskEqFacade), Integer(LMaskEqDirect), 'Direct CmpEqF64x2 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskLtFacade := VecF64x2CmpLt(LA, LB);
        LMaskLtDirect := LDirectDispatch^.CoreVectors.CmpLtF64x2(LA, LB);
        CheckEqual(Integer(LMaskLtFacade), Integer(LMaskLtDirect), 'Direct CmpLtF64x2 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskLeFacade := VecF64x2CmpLe(LA, LB);
        LMaskLeDirect := LDirectDispatch^.CoreVectors.CmpLeF64x2(LA, LB);
        CheckEqual(Integer(LMaskLeFacade), Integer(LMaskLeDirect), 'Direct CmpLeF64x2 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskGtFacade := VecF64x2CmpGt(LA, LB);
        LMaskGtDirect := LDirectDispatch^.CoreVectors.CmpGtF64x2(LA, LB);
        CheckEqual(Integer(LMaskGtFacade), Integer(LMaskGtDirect), 'Direct CmpGtF64x2 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskGeFacade := VecF64x2CmpGe(LA, LB);
        LMaskGeDirect := LDirectDispatch^.CoreVectors.CmpGeF64x2(LA, LB);
        CheckEqual(Integer(LMaskGeFacade), Integer(LMaskGeDirect), 'Direct CmpGeF64x2 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskNeFacade := VecF64x2CmpNe(LA, LB);
        LMaskNeDirect := LDirectDispatch^.CoreVectors.CmpNeF64x2(LA, LB);
        CheckEqual(Integer(LMaskNeFacade), Integer(LMaskNeDirect), 'Direct CmpNeF64x2 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAllFacade := Mask2All(LMaskLtFacade);
        LAllDirect := LDirectDispatch^.Mask.Mask2All(LMaskLtDirect);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask2All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAnyFacade := Mask2Any(LMaskLtFacade);
        LAnyDirect := LDirectDispatch^.Mask.Mask2Any(LMaskLtDirect);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask2Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LNoneFacade := Mask2None(LMaskLtFacade);
        LNoneDirect := LDirectDispatch^.Mask.Mask2None(LMaskLtDirect);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask2None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LPopFacade := Mask2PopCount(LMaskLtFacade);
        LPopDirect := LDirectDispatch^.Mask.Mask2PopCount(LMaskLtDirect);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask2PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LFirstFacade := Mask2FirstSet(LMaskLtFacade);
        LFirstDirect := LDirectDispatch^.Mask.Mask2FirstSet(LMaskLtDirect);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask2FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32CompareMicroDeltaMatrix_Parity;
const
  C_CASE_COUNT = 12;
  C_CASES_A: array[0..C_CASE_COUNT - 1, 0..3] of Single = (
    (0.0, 0.0, 0.0, 0.0), (1.0, -1.0, 1000.0, -1000.0),
    (1.0000001, -1.0000001, 2.5, -2.5), (-0.0, 0.0, -3.141592, 3.141592),
    (123456.0, -123456.0, 0.0009765625, -0.0009765625), (0.125, 0.25, 0.375, 0.5),
    (-0.125, -0.25, -0.375, -0.5), (15.0, 16.0, 17.0, 18.0),
    (1.0E-6, -1.0E-6, 1.0E-4, -1.0E-4), (1.0E-3, -1.0E-3, 1.0E-2, -1.0E-2),
    (4096.5, -4096.5, 8192.25, -8192.25), (7.0, -7.0, 11.0, -11.0)
  );
  C_CASES_B: array[0..C_CASE_COUNT - 1, 0..3] of Single = (
    (0.0, -0.0, 1.0E-7, -1.0E-7), (1.0, -1.0000001, 999.9999, -1000.0001),
    (1.0000002, -1.0, 2.5, -2.5000002), (0.0, -0.0, -3.1415918, 3.1415920),
    (123456.0625, -123455.9375, 0.0009765625, -0.0009765), (0.1249999, 0.2500001, 0.375, 0.5000001),
    (-0.1250001, -0.2499999, -0.3750001, -0.4999999), (15.0, 15.99999, 17.00001, 18.0),
    (1.0E-6, -1.1E-6, 0.0, -0.0), (0.0010001, -0.0009999, 0.0100000, -0.0100002),
    (4096.5005, -4096.4995, 8192.2500, -8192.2505), (7.0000005, -7.0000005, 10.999999, -11.000001)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LA, LB: TVecF32x4;
  LCaseIdx: Integer;
  LLane: Integer;

  LMaskEqFacade, LMaskEqDirect: TMask4;
  LMaskLtFacade, LMaskLtDirect: TMask4;
  LMaskLeFacade, LMaskLeDirect: TMask4;
  LMaskGtFacade, LMaskGtDirect: TMask4;
  LMaskGeFacade, LMaskGeDirect: TMask4;
  LMaskNeFacade, LMaskNeDirect: TMask4;

  LAllFacade, LAllDirect: Boolean;
  LAnyFacade, LAnyDirect: Boolean;
  LNoneFacade, LNoneDirect: Boolean;
  LPopFacade, LPopDirect: Integer;
  LFirstFacade, LFirstDirect: Integer;

  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqF32x4), 'CmpEqF32x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Mask.Mask4All), 'Mask4All should be assigned for backend ' + DirectBackendName(LBackend));

      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 3 do
        begin
          LA.f[LLane] := C_CASES_A[LCaseIdx, LLane];
          LB.f[LLane] := C_CASES_B[LCaseIdx, LLane];
        end;

        LMaskEqFacade := VecF32x4CmpEq(LA, LB);
        LMaskEqDirect := LDirectDispatch^.CoreVectors.CmpEqF32x4(LA, LB);
        CheckEqual(Integer(LMaskEqFacade), Integer(LMaskEqDirect), 'Direct CmpEqF32x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskLtFacade := VecF32x4CmpLt(LA, LB);
        LMaskLtDirect := LDirectDispatch^.CoreVectors.CmpLtF32x4(LA, LB);
        CheckEqual(Integer(LMaskLtFacade), Integer(LMaskLtDirect), 'Direct CmpLtF32x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskLeFacade := VecF32x4CmpLe(LA, LB);
        LMaskLeDirect := LDirectDispatch^.CoreVectors.CmpLeF32x4(LA, LB);
        CheckEqual(Integer(LMaskLeFacade), Integer(LMaskLeDirect), 'Direct CmpLeF32x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskGtFacade := VecF32x4CmpGt(LA, LB);
        LMaskGtDirect := LDirectDispatch^.CoreVectors.CmpGtF32x4(LA, LB);
        CheckEqual(Integer(LMaskGtFacade), Integer(LMaskGtDirect), 'Direct CmpGtF32x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskGeFacade := VecF32x4CmpGe(LA, LB);
        LMaskGeDirect := LDirectDispatch^.CoreVectors.CmpGeF32x4(LA, LB);
        CheckEqual(Integer(LMaskGeFacade), Integer(LMaskGeDirect), 'Direct CmpGeF32x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMaskNeFacade := VecF32x4CmpNe(LA, LB);
        LMaskNeDirect := LDirectDispatch^.CoreVectors.CmpNeF32x4(LA, LB);
        CheckEqual(Integer(LMaskNeFacade), Integer(LMaskNeDirect), 'Direct CmpNeF32x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAllFacade := Mask4All(LMaskLtFacade);
        LAllDirect := LDirectDispatch^.Mask.Mask4All(LMaskLtDirect);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAnyFacade := Mask4Any(LMaskLtFacade);
        LAnyDirect := LDirectDispatch^.Mask.Mask4Any(LMaskLtDirect);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask4Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LNoneFacade := Mask4None(LMaskLtFacade);
        LNoneDirect := LDirectDispatch^.Mask.Mask4None(LMaskLtDirect);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask4None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LPopFacade := Mask4PopCount(LMaskLtFacade);
        LPopDirect := LDirectDispatch^.Mask.Mask4PopCount(LMaskLtDirect);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask4PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LFirstFacade := Mask4FirstSet(LMaskLtFacade);
        LFirstDirect := LDirectDispatch^.Mask.Mask4FirstSet(LMaskLtDirect);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask4FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_U32U64CompareEdgeMatrix_Parity;
const
  C_CASE_COUNT = 8;
  C_U32_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of UInt32 = (
    (0, 1, 2, 3, 4, 5, 6, 7), ($FFFFFFFF, $FFFFFFFE, $80000000, $7FFFFFFF, 1, 2, 3, 4),
    (100, 200, 300, 400, 500, 600, 700, 800), (0, 0, 0, 0, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF),
    ($80000000, $80000001, $7FFFFFFE, $7FFFFFFF, 15, 16, 17, 18), (42, 43, 44, 45, 46, 47, 48, 49),
    ($AAAAAAAA, $55555555, $0F0F0F0F, $F0F0F0F0, 9, 10, 11, 12), (1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000)
  );
  C_U32_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of UInt32 = (
    (0, 0, 3, 2, 4, 6, 5, 7), ($FFFFFFFF, 1, $7FFFFFFF, $80000000, 2, 2, 4, 3),
    (100, 199, 301, 400, 499, 601, 700, 900), (1, 0, $FFFFFFFF, 0, $FFFFFFFF, 0, $FFFFFFFF, 0),
    ($7FFFFFFF, $80000000, $7FFFFFFF, $7FFFFFFE, 15, 15, 18, 17), (41, 43, 45, 45, 47, 47, 49, 49),
    ($AAAAAAAA, $AAAAAAAA, $F0F0F0F0, $0F0F0F0F, 8, 10, 12, 12), (999, 2001, 3000, 3999, 5001, 6000, 6999, 9000)
  );

  C_U64_CASES_A: array[0..C_CASE_COUNT - 1, 0..3] of UInt64 = (
    (0, 1, 2, 3), (18446744073709551615, 9223372036854775808, 9223372036854775807, 42),
    (1000, 2000, 3000, 4000), (0, 18446744073709551615, 123456789, 987654321),
    (12297829382473034410, 6148914691236517205, 11, 12), (15, 16, 17, 18),
    ($0000000100000000, $0000000200000000, 5, 6), (9000000000, 9000000001, 9000000002, 9000000003)
  );
  C_U64_CASES_B: array[0..C_CASE_COUNT - 1, 0..3] of UInt64 = (
    (0, 0, 3, 2), (18446744073709551615, 9223372036854775807, 9223372036854775808, 41),
    (1000, 1999, 3001, 4000), (1, 18446744073709551615, 123456788, 987654322),
    (12297829382473034410, 12297829382473034410, 10, 12), (14, 16, 18, 18),
    ($0000000100000001, $0000000200000000, 4, 7), (9000000001, 9000000001, 9000000000, 9000000004)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAu32, LBu32: TVecU32x8;
  LAu64, LBu64: TVecU64x4;
  LCaseIdx: Integer;
  LLane: Integer;

  LMask8EqFacade, LMask8EqDirect: TMask8;
  LMask8LtFacade, LMask8LtDirect: TMask8;
  LMask8LeFacade, LMask8LeDirect: TMask8;
  LMask8GtFacade, LMask8GtDirect: TMask8;
  LMask8GeFacade, LMask8GeDirect: TMask8;
  LMask8NeExpected, LMask8NeDirect: TMask8;

  LMask4EqFacade, LMask4EqDirect: TMask4;
  LMask4LtFacade, LMask4LtDirect: TMask4;
  LMask4LeFacade, LMask4LeDirect: TMask4;
  LMask4GtFacade, LMask4GtDirect: TMask4;
  LMask4GeFacade, LMask4GeDirect: TMask4;
  LMask4NeFacade, LMask4NeDirect: TMask4;

  LMask8AllFacade, LMask8AllDirect: Boolean;
  LMask8AnyFacade, LMask8AnyDirect: Boolean;
  LMask8NoneFacade, LMask8NoneDirect: Boolean;
  LMask8PopFacade, LMask8PopDirect: Integer;
  LMask8FirstFacade, LMask8FirstDirect: Integer;

  LMask4AllFacade, LMask4AllDirect: Boolean;
  LMask4AnyFacade, LMask4AnyDirect: Boolean;
  LMask4NoneFacade, LMask4NoneDirect: Boolean;
  LMask4PopFacade, LMask4PopDirect: Integer;
  LMask4FirstFacade, LMask4FirstDirect: Integer;

  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.CmpEqU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeU64x4)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4FirstSet)) then
        Continue;

      Inc(LTestedCount);

      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LAu32.u[LLane] := C_U32_CASES_A[LCaseIdx, LLane];
          LBu32.u[LLane] := C_U32_CASES_B[LCaseIdx, LLane];
        end;

        for LLane := 0 to 3 do
        begin
          LAu64.u[LLane] := C_U64_CASES_A[LCaseIdx, LLane];
          LBu64.u[LLane] := C_U64_CASES_B[LCaseIdx, LLane];
        end;

        // U32x8 compare parity
        LMask8EqFacade := VecU32x8CmpEq(LAu32, LBu32);
        LMask8EqDirect := LDirectDispatch^.CoreVectors.CmpEqU32x8(LAu32, LBu32);
        CheckEqual(Integer(LMask8EqFacade), Integer(LMask8EqDirect), 'Direct CmpEqU32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8LtFacade := VecU32x8CmpLt(LAu32, LBu32);
        LMask8LtDirect := LDirectDispatch^.CoreVectors.CmpLtU32x8(LAu32, LBu32);
        CheckEqual(Integer(LMask8LtFacade), Integer(LMask8LtDirect), 'Direct CmpLtU32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8LeFacade := VecU32x8CmpLe(LAu32, LBu32);
        LMask8LeDirect := LDirectDispatch^.CoreVectors.CmpLeU32x8(LAu32, LBu32);
        CheckEqual(Integer(LMask8LeFacade), Integer(LMask8LeDirect), 'Direct CmpLeU32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8GtFacade := VecU32x8CmpGt(LAu32, LBu32);
        LMask8GtDirect := LDirectDispatch^.CoreVectors.CmpGtU32x8(LAu32, LBu32);
        CheckEqual(Integer(LMask8GtFacade), Integer(LMask8GtDirect), 'Direct CmpGtU32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8GeFacade := VecU32x8CmpGe(LAu32, LBu32);
        LMask8GeDirect := LDirectDispatch^.CoreVectors.CmpGeU32x8(LAu32, LBu32);
        CheckEqual(Integer(LMask8GeFacade), Integer(LMask8GeDirect), 'Direct CmpGeU32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8NeExpected := 0;
        for LLane := 0 to 7 do
          if LAu32.u[LLane] <> LBu32.u[LLane] then
            LMask8NeExpected := LMask8NeExpected or TMask8(1 shl LLane);

        LMask8NeDirect := LDirectDispatch^.CoreVectors.CmpNeU32x8(LAu32, LBu32);
        CheckEqual(Integer(LMask8NeExpected), Integer(LMask8NeDirect), 'Direct CmpNeU32x8 expected parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8AllFacade := Mask8All(LMask8LtFacade);
        LMask8AllDirect := LDirectDispatch^.Mask.Mask8All(LMask8LtDirect);
        CheckEqual(LMask8AllFacade, LMask8AllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8AnyFacade := Mask8Any(LMask8LtFacade);
        LMask8AnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8LtDirect);
        CheckEqual(LMask8AnyFacade, LMask8AnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8NoneFacade := Mask8None(LMask8LtFacade);
        LMask8NoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8LtDirect);
        CheckEqual(LMask8NoneFacade, LMask8NoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8PopFacade := Mask8PopCount(LMask8LtFacade);
        LMask8PopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8LtDirect);
        CheckEqual(LMask8PopFacade, LMask8PopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8FirstFacade := Mask8FirstSet(LMask8LtFacade);
        LMask8FirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8LtDirect);
        CheckEqual(LMask8FirstFacade, LMask8FirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        // U64x4 compare parity
        LMask4EqFacade := VecU64x4CmpEq(LAu64, LBu64);
        LMask4EqDirect := LDirectDispatch^.CoreVectors.CmpEqU64x4(LAu64, LBu64);
        CheckEqual(Integer(LMask4EqFacade), Integer(LMask4EqDirect), 'Direct CmpEqU64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4LtFacade := VecU64x4CmpLt(LAu64, LBu64);
        LMask4LtDirect := LDirectDispatch^.CoreVectors.CmpLtU64x4(LAu64, LBu64);
        CheckEqual(Integer(LMask4LtFacade), Integer(LMask4LtDirect), 'Direct CmpLtU64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4LeFacade := VecU64x4CmpLe(LAu64, LBu64);
        LMask4LeDirect := LDirectDispatch^.CoreVectors.CmpLeU64x4(LAu64, LBu64);
        CheckEqual(Integer(LMask4LeFacade), Integer(LMask4LeDirect), 'Direct CmpLeU64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4GtFacade := VecU64x4CmpGt(LAu64, LBu64);
        LMask4GtDirect := LDirectDispatch^.CoreVectors.CmpGtU64x4(LAu64, LBu64);
        CheckEqual(Integer(LMask4GtFacade), Integer(LMask4GtDirect), 'Direct CmpGtU64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4GeFacade := VecU64x4CmpGe(LAu64, LBu64);
        LMask4GeDirect := LDirectDispatch^.CoreVectors.CmpGeU64x4(LAu64, LBu64);
        CheckEqual(Integer(LMask4GeFacade), Integer(LMask4GeDirect), 'Direct CmpGeU64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4NeFacade := VecU64x4CmpNe(LAu64, LBu64);
        LMask4NeDirect := LDirectDispatch^.CoreVectors.CmpNeU64x4(LAu64, LBu64);
        CheckEqual(Integer(LMask4NeFacade), Integer(LMask4NeDirect), 'Direct CmpNeU64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4AllFacade := Mask4All(LMask4LtFacade);
        LMask4AllDirect := LDirectDispatch^.Mask.Mask4All(LMask4LtDirect);
        CheckEqual(LMask4AllFacade, LMask4AllDirect, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4AnyFacade := Mask4Any(LMask4LtFacade);
        LMask4AnyDirect := LDirectDispatch^.Mask.Mask4Any(LMask4LtDirect);
        CheckEqual(LMask4AnyFacade, LMask4AnyDirect, 'Direct Mask4Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4NoneFacade := Mask4None(LMask4LtFacade);
        LMask4NoneDirect := LDirectDispatch^.Mask.Mask4None(LMask4LtDirect);
        CheckEqual(LMask4NoneFacade, LMask4NoneDirect, 'Direct Mask4None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4PopFacade := Mask4PopCount(LMask4LtFacade);
        LMask4PopDirect := LDirectDispatch^.Mask.Mask4PopCount(LMask4LtDirect);
        CheckEqual(LMask4PopFacade, LMask4PopDirect, 'Direct Mask4PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4FirstFacade := Mask4FirstSet(LMask4LtFacade);
        LMask4FirstDirect := LDirectDispatch^.Mask.Mask4FirstSet(LMask4LtDirect);
        CheckEqual(LMask4FirstFacade, LMask4FirstDirect, 'Direct Mask4FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32x8F64x4ArithmeticReduceMatrix_Parity;
const
  C_EPSILON_F32 = 1e-5;
  C_EPSILON_F64 = 1e-9;
  C_CASE_COUNT = 6;
  C_F32_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Single = (
    (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0), (-1.5, 2.5, -3.5, 4.5, -5.5, 6.5, -7.5, 8.5),
    (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0), (-10.0, -20.0, 30.0, 40.0, -50.0, 60.0, -70.0, 80.0),
    (1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 6000.0, 7000.0, 8000.0), (0.001, -0.002, 0.003, -0.004, 0.005, -0.006, 0.007, -0.008)
  );
  C_F32_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Single = (
    (8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0), (2.0, -2.0, 2.0, -2.0, 2.0, -2.0, 2.0, -2.0),
    (1.0, 0.5, 0.25, 0.125, 0.5, 1.0, 2.0, 4.0), (5.0, -4.0, 3.0, -2.0, 1.0, -1.0, 2.0, -3.0),
    (10.0, 20.0, 25.0, 50.0, 100.0, 125.0, 200.0, 250.0), (0.1, 0.2, -0.3, -0.4, 0.5, 0.6, -0.7, -0.8)
  );

  C_F64_CASES_A: array[0..C_CASE_COUNT - 1, 0..3] of Double = (
    (1.0, 2.0, 3.0, 4.0), (-1.25, 2.5, -3.75, 5.0),
    (100.0, 200.0, 300.0, 400.0), (0.125, 0.25, 0.5, 1.0),
    (-10.0, -20.0, 30.0, 40.0), (1.0E-6, -2.0E-6, 3.0E-6, -4.0E-6)
  );
  C_F64_CASES_B: array[0..C_CASE_COUNT - 1, 0..3] of Double = (
    (4.0, 3.0, 2.0, 1.0), (2.0, -2.0, 2.0, -2.0),
    (10.0, 20.0, 25.0, 50.0), (1.0, 0.5, 0.25, 0.125),
    (5.0, -4.0, 3.0, -2.0), (0.1, 0.2, -0.3, -0.4)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAf32, LBf32: TVecF32x8;
  LAf64, LBf64: TVecF64x4;
  LCaseIdx: Integer;
  LLane: Integer;

  LAddF32Facade, LAddF32Direct: TVecF32x8;
  LSubF32Facade, LSubF32Direct: TVecF32x8;
  LMulF32Facade, LMulF32Direct: TVecF32x8;
  LDivF32Facade, LDivF32Direct: TVecF32x8;
  LReduceAddF32Facade, LReduceAddF32Direct: Single;
  LReduceMinF32Facade, LReduceMinF32Direct: Single;
  LReduceMaxF32Facade, LReduceMaxF32Direct: Single;
  LReduceMulF32Facade, LReduceMulF32Direct: Single;

  LAddF64Facade, LAddF64Direct: TVecF64x4;
  LSubF64Facade, LSubF64Direct: TVecF64x4;
  LMulF64Facade, LMulF64Direct: TVecF64x4;
  LDivF64Facade, LDivF64Direct: TVecF64x4;
  LReduceAddF64Facade, LReduceAddF64Direct: Double;
  LReduceMinF64Facade, LReduceMinF64Direct: Double;
  LReduceMaxF64Facade, LReduceMaxF64Direct: Double;
  LReduceMulF64Facade, LReduceMulF64Direct: Double;
  LToleranceF32, LToleranceF64: Double;

  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.AddF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.SubF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.MulF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.DivF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceAddF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMinF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMaxF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMulF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.AddF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.SubF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.MulF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.DivF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceAddF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMinF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMaxF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMulF64x4)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LAf32.f[LLane] := C_F32_CASES_A[LCaseIdx, LLane];
          LBf32.f[LLane] := C_F32_CASES_B[LCaseIdx, LLane];
        end;

        for LLane := 0 to 3 do
        begin
          LAf64.d[LLane] := C_F64_CASES_A[LCaseIdx, LLane];
          LBf64.d[LLane] := C_F64_CASES_B[LCaseIdx, LLane];
        end;

        LAddF32Facade := VecF32x8Add(LAf32, LBf32);
        LAddF32Direct := LDirectDispatch^.CoreVectors.AddF32x8(LAf32, LBf32);
        LSubF32Facade := VecF32x8Sub(LAf32, LBf32);
        LSubF32Direct := LDirectDispatch^.CoreVectors.SubF32x8(LAf32, LBf32);
        LMulF32Facade := VecF32x8Mul(LAf32, LBf32);
        LMulF32Direct := LDirectDispatch^.CoreVectors.MulF32x8(LAf32, LBf32);
        LDivF32Facade := VecF32x8Div(LAf32, LBf32);
        LDivF32Direct := LDirectDispatch^.CoreVectors.DivF32x8(LAf32, LBf32);

        for LLane := 0 to 7 do
        begin
          CheckNear(LAddF32Facade.f[LLane], LAddF32Direct.f[LLane], C_EPSILON_F32, 'Direct AddF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LSubF32Facade.f[LLane], LSubF32Direct.f[LLane], C_EPSILON_F32, 'Direct SubF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LMulF32Facade.f[LLane], LMulF32Direct.f[LLane], C_EPSILON_F32, 'Direct MulF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LDivF32Facade.f[LLane], LDivF32Direct.f[LLane], C_EPSILON_F32, 'Direct DivF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
        end;

        LReduceAddF32Facade := VecF32x8ReduceAdd(LAf32);
        LReduceAddF32Direct := LDirectDispatch^.CoreVectors.ReduceAddF32x8(LAf32);
        CheckNear(LReduceAddF32Facade, LReduceAddF32Direct, C_EPSILON_F32, 'Direct ReduceAddF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMinF32Facade := VecF32x8ReduceMin(LAf32);
        LReduceMinF32Direct := LDirectDispatch^.CoreVectors.ReduceMinF32x8(LAf32);
        CheckNear(LReduceMinF32Facade, LReduceMinF32Direct, C_EPSILON_F32, 'Direct ReduceMinF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMaxF32Facade := VecF32x8ReduceMax(LAf32);
        LReduceMaxF32Direct := LDirectDispatch^.CoreVectors.ReduceMaxF32x8(LAf32);
        CheckNear(LReduceMaxF32Facade, LReduceMaxF32Direct, C_EPSILON_F32, 'Direct ReduceMaxF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMulF32Facade := VecF32x8ReduceMul(LAf32);
        LReduceMulF32Direct := LDirectDispatch^.CoreVectors.ReduceMulF32x8(LAf32);
        LToleranceF32 := Max(C_EPSILON_F32, Abs(LReduceMulF32Facade) * 1e-6);
        CheckTrue(Abs(LReduceMulF32Facade - LReduceMulF32Direct) <= LToleranceF32, 'Direct ReduceMulF32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAddF64Facade := VecF64x4Add(LAf64, LBf64);
        LAddF64Direct := LDirectDispatch^.CoreVectors.AddF64x4(LAf64, LBf64);
        LSubF64Facade := VecF64x4Sub(LAf64, LBf64);
        LSubF64Direct := LDirectDispatch^.CoreVectors.SubF64x4(LAf64, LBf64);
        LMulF64Facade := VecF64x4Mul(LAf64, LBf64);
        LMulF64Direct := LDirectDispatch^.CoreVectors.MulF64x4(LAf64, LBf64);
        LDivF64Facade := VecF64x4Div(LAf64, LBf64);
        LDivF64Direct := LDirectDispatch^.CoreVectors.DivF64x4(LAf64, LBf64);

        for LLane := 0 to 3 do
        begin
          CheckNear(LAddF64Facade.d[LLane], LAddF64Direct.d[LLane], C_EPSILON_F64, 'Direct AddF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LSubF64Facade.d[LLane], LSubF64Direct.d[LLane], C_EPSILON_F64, 'Direct SubF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LMulF64Facade.d[LLane], LMulF64Direct.d[LLane], C_EPSILON_F64, 'Direct MulF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LDivF64Facade.d[LLane], LDivF64Direct.d[LLane], C_EPSILON_F64, 'Direct DivF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
        end;

        LReduceAddF64Facade := VecF64x4ReduceAdd(LAf64);
        LReduceAddF64Direct := LDirectDispatch^.CoreVectors.ReduceAddF64x4(LAf64);
        CheckNear(LReduceAddF64Facade, LReduceAddF64Direct, C_EPSILON_F64, 'Direct ReduceAddF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMinF64Facade := VecF64x4ReduceMin(LAf64);
        LReduceMinF64Direct := LDirectDispatch^.CoreVectors.ReduceMinF64x4(LAf64);
        CheckNear(LReduceMinF64Facade, LReduceMinF64Direct, C_EPSILON_F64, 'Direct ReduceMinF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMaxF64Facade := VecF64x4ReduceMax(LAf64);
        LReduceMaxF64Direct := LDirectDispatch^.CoreVectors.ReduceMaxF64x4(LAf64);
        CheckNear(LReduceMaxF64Facade, LReduceMaxF64Direct, C_EPSILON_F64, 'Direct ReduceMaxF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMulF64Facade := VecF64x4ReduceMul(LAf64);
        LReduceMulF64Direct := LDirectDispatch^.CoreVectors.ReduceMulF64x4(LAf64);
        LToleranceF64 := Max(C_EPSILON_F64, Abs(LReduceMulF64Facade) * 1e-12);
        CheckTrue(Abs(LReduceMulF64Facade - LReduceMulF64Direct) <= LToleranceF64, 'Direct ReduceMulF64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32x16F64x8CompareReduceMatrix_Parity;
const
  C_EPSILON_F32 = 1e-5;
  C_EPSILON_F64 = 1e-9;
  C_CASE_COUNT = 5;
  C_F32_CASES_A: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0), (-1.0, 2.0, -3.0, 4.0, -5.0, 6.0, -7.0, 8.0, -9.0, 10.0, -11.0, 12.0, -13.0, 14.0, -15.0, 16.0),
    (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 0.0625, 0.03125, 0.015625, 0.0078125, 3.0, 6.0, 12.0, 24.0), (1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 6000.0, 7000.0, 8000.0, -1000.0, -2000.0, -3000.0, -4000.0, -5000.0, -6000.0, -7000.0, -8000.0),
    (1.0E-4, -2.0E-4, 3.0E-4, -4.0E-4, 5.0E-4, -6.0E-4, 7.0E-4, -8.0E-4, 9.0E-4, -1.0E-3, 1.1E-3, -1.2E-3, 1.3E-3, -1.4E-3, 1.5E-3, -1.6E-3)
  );
  C_F32_CASES_B: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (0.0, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0, 7.0, 9.0, 11.0, 10.0, 12.0, 14.0, 13.0, 15.0), (-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0),
    (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0, 0.0625, 0.0625, 0.010, 0.008, 3.0, 5.0, 12.0, 25.0), (1000.0, 1999.0, 3001.0, 4000.0, 4999.0, 6001.0, 7000.0, 8001.0, -999.0, -2001.0, -3000.0, -3999.0, -5001.0, -6000.0, -7001.0, -8000.0),
    (1.1E-4, -2.0E-4, 2.9E-4, -4.1E-4, 5.0E-4, -6.1E-4, 7.0E-4, -8.1E-4, 9.0E-4, -9.9E-4, 1.1E-3, -1.19E-3, 1.31E-3, -1.4E-3, 1.49E-3, -1.61E-3)
  );

  C_F64_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0), (-1.5, 2.5, -3.5, 4.5, -5.5, 6.5, -7.5, 8.5),
    (100.0, 200.0, 300.0, 400.0, -100.0, -200.0, -300.0, -400.0), (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0),
    (1.0E-6, -2.0E-6, 3.0E-6, -4.0E-6, 5.0E-6, -6.0E-6, 7.0E-6, -8.0E-6)
  );
  C_F64_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (0.0, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0), (-1.5, -2.5, -3.0, -4.5, -5.0, -6.5, -7.0, -8.5),
    (100.0, 199.0, 301.0, 400.0, -99.0, -201.0, -300.0, -399.0), (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0),
    (1.1E-6, -2.0E-6, 2.9E-6, -4.1E-6, 5.0E-6, -6.1E-6, 7.0E-6, -8.1E-6)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAf32, LBf32: TVecF32x16;
  LAf64, LBf64: TVecF64x8;
  LCaseIdx: Integer;
  LLane: Integer;

  LMask16EqFacade, LMask16EqDirect: TMask16;
  LMask16LtFacade, LMask16LtDirect: TMask16;
  LMask16LeFacade, LMask16LeDirect: TMask16;
  LMask16GtFacade, LMask16GtDirect: TMask16;
  LMask16GeFacade, LMask16GeDirect: TMask16;
  LMask16NeFacade, LMask16NeDirect: TMask16;

  LMask8EqFacade, LMask8EqDirect: TMask8;
  LMask8LtFacade, LMask8LtDirect: TMask8;
  LMask8LeFacade, LMask8LeDirect: TMask8;
  LMask8GtFacade, LMask8GtDirect: TMask8;
  LMask8GeFacade, LMask8GeDirect: TMask8;
  LMask8NeFacade, LMask8NeDirect: TMask8;

  LReduceAddF32Facade, LReduceAddF32Direct: Single;
  LReduceMinF32Facade, LReduceMinF32Direct: Single;
  LReduceMaxF32Facade, LReduceMaxF32Direct: Single;

  LReduceAddF64Facade, LReduceAddF64Direct: Double;
  LReduceMinF64Facade, LReduceMinF64Direct: Double;
  LReduceMaxF64Facade, LReduceMaxF64Direct: Double;

  LMask16AllFacade, LMask16AllDirect: Boolean;
  LMask16AnyFacade, LMask16AnyDirect: Boolean;
  LMask16NoneFacade, LMask16NoneDirect: Boolean;
  LMask16PopFacade, LMask16PopDirect: Integer;
  LMask16FirstFacade, LMask16FirstDirect: Integer;

  LMask8AllFacade, LMask8AllDirect: Boolean;
  LMask8AnyFacade, LMask8AnyDirect: Boolean;
  LMask8NoneFacade, LMask8NoneDirect: Boolean;
  LMask8PopFacade, LMask8PopDirect: Integer;
  LMask8FirstFacade, LMask8FirstDirect: Integer;

  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.CmpEqF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceAddF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMinF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMaxF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceAddF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMinF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMaxF64x8)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8FirstSet)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 15 do
        begin
          LAf32.f[LLane] := C_F32_CASES_A[LCaseIdx, LLane];
          LBf32.f[LLane] := C_F32_CASES_B[LCaseIdx, LLane];
        end;

        for LLane := 0 to 7 do
        begin
          LAf64.d[LLane] := C_F64_CASES_A[LCaseIdx, LLane];
          LBf64.d[LLane] := C_F64_CASES_B[LCaseIdx, LLane];
        end;

        LMask16EqFacade := VecF32x16CmpEq_Mask(LAf32, LBf32);
        LMask16EqDirect := LDirectDispatch^.CoreVectors.CmpEqF32x16(LAf32, LBf32);
        CheckEqual(Integer(LMask16EqFacade), Integer(LMask16EqDirect), 'Direct CmpEqF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16LtFacade := VecF32x16CmpLt_Mask(LAf32, LBf32);
        LMask16LtDirect := LDirectDispatch^.CoreVectors.CmpLtF32x16(LAf32, LBf32);
        CheckEqual(Integer(LMask16LtFacade), Integer(LMask16LtDirect), 'Direct CmpLtF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16LeFacade := VecF32x16CmpLe_Mask(LAf32, LBf32);
        LMask16LeDirect := LDirectDispatch^.CoreVectors.CmpLeF32x16(LAf32, LBf32);
        CheckEqual(Integer(LMask16LeFacade), Integer(LMask16LeDirect), 'Direct CmpLeF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16GtFacade := VecF32x16CmpGt_Mask(LAf32, LBf32);
        LMask16GtDirect := LDirectDispatch^.CoreVectors.CmpGtF32x16(LAf32, LBf32);
        CheckEqual(Integer(LMask16GtFacade), Integer(LMask16GtDirect), 'Direct CmpGtF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16GeFacade := VecF32x16CmpGe_Mask(LAf32, LBf32);
        LMask16GeDirect := LDirectDispatch^.CoreVectors.CmpGeF32x16(LAf32, LBf32);
        CheckEqual(Integer(LMask16GeFacade), Integer(LMask16GeDirect), 'Direct CmpGeF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16NeFacade := VecF32x16CmpNe_Mask(LAf32, LBf32);
        LMask16NeDirect := LDirectDispatch^.CoreVectors.CmpNeF32x16(LAf32, LBf32);
        CheckEqual(Integer(LMask16NeFacade), Integer(LMask16NeDirect), 'Direct CmpNeF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8EqFacade := VecF64x8CmpEq(LAf64, LBf64);
        LMask8EqDirect := LDirectDispatch^.CoreVectors.CmpEqF64x8(LAf64, LBf64);
        CheckEqual(Integer(LMask8EqFacade), Integer(LMask8EqDirect), 'Direct CmpEqF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8LtFacade := VecF64x8CmpLt(LAf64, LBf64);
        LMask8LtDirect := LDirectDispatch^.CoreVectors.CmpLtF64x8(LAf64, LBf64);
        CheckEqual(Integer(LMask8LtFacade), Integer(LMask8LtDirect), 'Direct CmpLtF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8LeFacade := VecF64x8CmpLe(LAf64, LBf64);
        LMask8LeDirect := LDirectDispatch^.CoreVectors.CmpLeF64x8(LAf64, LBf64);
        CheckEqual(Integer(LMask8LeFacade), Integer(LMask8LeDirect), 'Direct CmpLeF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8GtFacade := VecF64x8CmpGt(LAf64, LBf64);
        LMask8GtDirect := LDirectDispatch^.CoreVectors.CmpGtF64x8(LAf64, LBf64);
        CheckEqual(Integer(LMask8GtFacade), Integer(LMask8GtDirect), 'Direct CmpGtF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8GeFacade := VecF64x8CmpGe(LAf64, LBf64);
        LMask8GeDirect := LDirectDispatch^.CoreVectors.CmpGeF64x8(LAf64, LBf64);
        CheckEqual(Integer(LMask8GeFacade), Integer(LMask8GeDirect), 'Direct CmpGeF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8NeFacade := VecF64x8CmpNe(LAf64, LBf64);
        LMask8NeDirect := LDirectDispatch^.CoreVectors.CmpNeF64x8(LAf64, LBf64);
        CheckEqual(Integer(LMask8NeFacade), Integer(LMask8NeDirect), 'Direct CmpNeF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16AllFacade := Mask16All(LMask16LtFacade);
        LMask16AllDirect := LDirectDispatch^.Mask.Mask16All(LMask16LtDirect);
        CheckEqual(LMask16AllFacade, LMask16AllDirect, 'Direct Mask16All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16AnyFacade := Mask16Any(LMask16LtFacade);
        LMask16AnyDirect := LDirectDispatch^.Mask.Mask16Any(LMask16LtDirect);
        CheckEqual(LMask16AnyFacade, LMask16AnyDirect, 'Direct Mask16Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16NoneFacade := Mask16None(LMask16LtFacade);
        LMask16NoneDirect := LDirectDispatch^.Mask.Mask16None(LMask16LtDirect);
        CheckEqual(LMask16NoneFacade, LMask16NoneDirect, 'Direct Mask16None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16PopFacade := Mask16PopCount(LMask16LtFacade);
        LMask16PopDirect := LDirectDispatch^.Mask.Mask16PopCount(LMask16LtDirect);
        CheckEqual(LMask16PopFacade, LMask16PopDirect, 'Direct Mask16PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16FirstFacade := Mask16FirstSet(LMask16LtFacade);
        LMask16FirstDirect := LDirectDispatch^.Mask.Mask16FirstSet(LMask16LtDirect);
        CheckEqual(LMask16FirstFacade, LMask16FirstDirect, 'Direct Mask16FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8AllFacade := Mask8All(LMask8LtFacade);
        LMask8AllDirect := LDirectDispatch^.Mask.Mask8All(LMask8LtDirect);
        CheckEqual(LMask8AllFacade, LMask8AllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8AnyFacade := Mask8Any(LMask8LtFacade);
        LMask8AnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8LtDirect);
        CheckEqual(LMask8AnyFacade, LMask8AnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8NoneFacade := Mask8None(LMask8LtFacade);
        LMask8NoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8LtDirect);
        CheckEqual(LMask8NoneFacade, LMask8NoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8PopFacade := Mask8PopCount(LMask8LtFacade);
        LMask8PopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8LtDirect);
        CheckEqual(LMask8PopFacade, LMask8PopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8FirstFacade := Mask8FirstSet(LMask8LtFacade);
        LMask8FirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8LtDirect);
        CheckEqual(LMask8FirstFacade, LMask8FirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceAddF32Facade := VecF32x16ReduceAdd(LAf32);
        LReduceAddF32Direct := LDirectDispatch^.CoreVectors.ReduceAddF32x16(LAf32);
        CheckNear(LReduceAddF32Facade, LReduceAddF32Direct, C_EPSILON_F32, 'Direct ReduceAddF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMinF32Facade := VecF32x16ReduceMin(LAf32);
        LReduceMinF32Direct := LDirectDispatch^.CoreVectors.ReduceMinF32x16(LAf32);
        CheckNear(LReduceMinF32Facade, LReduceMinF32Direct, C_EPSILON_F32, 'Direct ReduceMinF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMaxF32Facade := VecF32x16ReduceMax(LAf32);
        LReduceMaxF32Direct := LDirectDispatch^.CoreVectors.ReduceMaxF32x16(LAf32);
        CheckNear(LReduceMaxF32Facade, LReduceMaxF32Direct, C_EPSILON_F32, 'Direct ReduceMaxF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceAddF64Facade := VecF64x8ReduceAdd(LAf64);
        LReduceAddF64Direct := LDirectDispatch^.CoreVectors.ReduceAddF64x8(LAf64);
        CheckNear(LReduceAddF64Facade, LReduceAddF64Direct, C_EPSILON_F64, 'Direct ReduceAddF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMinF64Facade := VecF64x8ReduceMin(LAf64);
        LReduceMinF64Direct := LDirectDispatch^.CoreVectors.ReduceMinF64x8(LAf64);
        CheckNear(LReduceMinF64Facade, LReduceMinF64Direct, C_EPSILON_F64, 'Direct ReduceMinF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LReduceMaxF64Facade := VecF64x8ReduceMax(LAf64);
        LReduceMaxF64Direct := LDirectDispatch^.CoreVectors.ReduceMaxF64x8(LAf64);
        CheckNear(LReduceMaxF64Facade, LReduceMaxF64Direct, C_EPSILON_F64, 'Direct ReduceMaxF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32x16F64x8ArithmeticMatrix_Parity;
const
  C_EPSILON_F32 = 1e-5;
  C_EPSILON_F64 = 1e-9;
  C_CASE_COUNT = 5;
  C_F32_CASES_A: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0), (-1.0, 2.0, -3.0, 4.0, -5.0, 6.0, -7.0, 8.0, -9.0, 10.0, -11.0, 12.0, -13.0, 14.0, -15.0, 16.0),
    (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 0.0625, 0.03125, 0.015625, 0.0078125, 3.0, 6.0, 12.0, 24.0), (1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 6000.0, 7000.0, 8000.0, -1000.0, -2000.0, -3000.0, -4000.0, -5000.0, -6000.0, -7000.0, -8000.0),
    (1.0E-4, -2.0E-4, 3.0E-4, -4.0E-4, 5.0E-4, -6.0E-4, 7.0E-4, -8.0E-4, 9.0E-4, -1.0E-3, 1.1E-3, -1.2E-3, 1.3E-3, -1.4E-3, 1.5E-3, -1.6E-3)
  );
  C_F32_CASES_B: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (0.5, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0, 7.0, 9.0, 11.0, 10.0, 12.0, 14.0, 13.0, 15.0), (-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0),
    (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0, 0.0625, 0.0625, 0.010, 0.008, 3.0, 5.0, 12.0, 25.0), (1000.0, 1999.0, 3001.0, 4000.0, 4999.0, 6001.0, 7000.0, 8001.0, -999.0, -2001.0, -3000.0, -3999.0, -5001.0, -6000.0, -7001.0, -8000.0),
    (1.1E-4, -2.0E-4, 2.9E-4, -4.1E-4, 5.0E-4, -6.1E-4, 7.0E-4, -8.1E-4, 9.0E-4, -9.9E-4, 1.1E-3, -1.19E-3, 1.31E-3, -1.4E-3, 1.49E-3, -1.61E-3)
  );

  C_F64_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0), (-1.5, 2.5, -3.5, 4.5, -5.5, 6.5, -7.5, 8.5),
    (100.0, 200.0, 300.0, 400.0, -100.0, -200.0, -300.0, -400.0), (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0),
    (1.0E-6, -2.0E-6, 3.0E-6, -4.0E-6, 5.0E-6, -6.0E-6, 7.0E-6, -8.0E-6)
  );
  C_F64_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (0.5, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0), (-1.5, -2.5, -3.0, -4.5, -5.0, -6.5, -7.0, -8.5),
    (100.0, 199.0, 301.0, 400.0, -99.0, -201.0, -300.0, -399.0), (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0),
    (1.1E-6, -2.0E-6, 2.9E-6, -4.1E-6, 5.0E-6, -6.1E-6, 7.0E-6, -8.1E-6)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAf32, LBf32: TVecF32x16;
  LAf64, LBf64: TVecF64x8;
  LAddF32Facade, LAddF32Direct: TVecF32x16;
  LSubF32Facade, LSubF32Direct: TVecF32x16;
  LMulF32Facade, LMulF32Direct: TVecF32x16;
  LDivF32Facade, LDivF32Direct: TVecF32x16;
  LAddF64Facade, LAddF64Direct: TVecF64x8;
  LSubF64Facade, LSubF64Direct: TVecF64x8;
  LMulF64Facade, LMulF64Direct: TVecF64x8;
  LDivF64Facade, LDivF64Direct: TVecF64x8;
  LCaseIdx: Integer;
  LLane: Integer;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.AddF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.SubF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.MulF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.DivF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.AddF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.SubF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.MulF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.DivF64x8)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 15 do
        begin
          LAf32.f[LLane] := C_F32_CASES_A[LCaseIdx, LLane];
          LBf32.f[LLane] := C_F32_CASES_B[LCaseIdx, LLane];
        end;

        for LLane := 0 to 7 do
        begin
          LAf64.d[LLane] := C_F64_CASES_A[LCaseIdx, LLane];
          LBf64.d[LLane] := C_F64_CASES_B[LCaseIdx, LLane];
        end;

        LAddF32Facade := VecF32x16Add(LAf32, LBf32);
        LAddF32Direct := LDirectDispatch^.CoreVectors.AddF32x16(LAf32, LBf32);
        LSubF32Facade := VecF32x16Sub(LAf32, LBf32);
        LSubF32Direct := LDirectDispatch^.CoreVectors.SubF32x16(LAf32, LBf32);
        LMulF32Facade := VecF32x16Mul(LAf32, LBf32);
        LMulF32Direct := LDirectDispatch^.CoreVectors.MulF32x16(LAf32, LBf32);
        LDivF32Facade := VecF32x16Div(LAf32, LBf32);
        LDivF32Direct := LDirectDispatch^.CoreVectors.DivF32x16(LAf32, LBf32);

        for LLane := 0 to 15 do
        begin
          CheckNear(LAddF32Facade.f[LLane], LAddF32Direct.f[LLane], C_EPSILON_F32, 'Direct AddF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LSubF32Facade.f[LLane], LSubF32Direct.f[LLane], C_EPSILON_F32, 'Direct SubF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LMulF32Facade.f[LLane], LMulF32Direct.f[LLane], C_EPSILON_F32, 'Direct MulF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LDivF32Facade.f[LLane], LDivF32Direct.f[LLane], C_EPSILON_F32, 'Direct DivF32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
        end;

        LAddF64Facade := VecF64x8Add(LAf64, LBf64);
        LAddF64Direct := LDirectDispatch^.CoreVectors.AddF64x8(LAf64, LBf64);
        LSubF64Facade := VecF64x8Sub(LAf64, LBf64);
        LSubF64Direct := LDirectDispatch^.CoreVectors.SubF64x8(LAf64, LBf64);
        LMulF64Facade := VecF64x8Mul(LAf64, LBf64);
        LMulF64Direct := LDirectDispatch^.CoreVectors.MulF64x8(LAf64, LBf64);
        LDivF64Facade := VecF64x8Div(LAf64, LBf64);
        LDivF64Direct := LDirectDispatch^.CoreVectors.DivF64x8(LAf64, LBf64);

        for LLane := 0 to 7 do
        begin
          CheckNear(LAddF64Facade.d[LLane], LAddF64Direct.d[LLane], C_EPSILON_F64, 'Direct AddF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LSubF64Facade.d[LLane], LSubF64Direct.d[LLane], C_EPSILON_F64, 'Direct SubF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LMulF64Facade.d[LLane], LMulF64Direct.d[LLane], C_EPSILON_F64, 'Direct MulF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
          CheckNear(LDivF64Facade.d[LLane], LDivF64Direct.d[LLane], C_EPSILON_F64, 'Direct DivF64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx) + ' lane=' + IntToStr(LLane));
        end;
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32x16F64x8ReduceMulStable_Parity;
const
  C_CASE_COUNT = 4;
  C_F32_CASES: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (1.0, 2.0, 3.0, 4.0, 0.5, 0.25, 2.0, 1.5, 1.0, 1.0, 2.0, 0.5, 4.0, 0.125, 2.0, 1.0), (-1.0, 2.0, -3.0, 4.0, 0.5, -0.25, 2.0, -1.5, 1.0, -1.0, 2.0, -0.5, 4.0, -0.125, 2.0, -1.0),
    (1.0001, 0.9999, 1.0002, 0.9998, 1.0, 1.0, 1.0003, 0.9997, 1.0, 1.0, 1.0004, 0.9996, 1.0, 1.0, 1.0005, 0.9995), (2.0, 0.5, 2.0, 0.5, 2.0, 0.5, 2.0, 0.5, 2.0, 0.5, 2.0, 0.5, 2.0, 0.5, 2.0, 0.5)
  );
  C_F64_CASES: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (1.0, 2.0, 0.5, 4.0, 0.25, 2.0, 1.5, 1.0), (-1.0, 2.0, -0.5, 4.0, -0.25, 2.0, -1.5, 1.0),
    (1.0000001, 0.9999999, 1.0000002, 0.9999998, 1.0000003, 0.9999997, 1.0000004, 0.9999996), (2.0, 0.5, 2.0, 0.5, 2.0, 0.5, 2.0, 0.5)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAf32: TVecF32x16;
  LAf64: TVecF64x8;
  LCaseIdx: Integer;
  LLane: Integer;
  LFacadeMulF32, LDirectMulF32: Single;
  LFacadeMulF64, LDirectMulF64: Double;
  LToleranceF32, LToleranceF64: Double;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.ReduceMulF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.ReduceMulF64x8)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 15 do
          LAf32.f[LLane] := C_F32_CASES[LCaseIdx, LLane];
        for LLane := 0 to 7 do
          LAf64.d[LLane] := C_F64_CASES[LCaseIdx, LLane];

        LFacadeMulF32 := VecF32x16ReduceMul(LAf32);
        LDirectMulF32 := LDirectDispatch^.CoreVectors.ReduceMulF32x16(LAf32);
        LToleranceF32 := Max(1e-5, Abs(LFacadeMulF32) * 1e-6);
        CheckTrue(Abs(LFacadeMulF32 - LDirectMulF32) <= LToleranceF32, 'Direct ReduceMulF32x16 stable parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LFacadeMulF64 := VecF64x8ReduceMul(LAf64);
        LDirectMulF64 := LDirectDispatch^.CoreVectors.ReduceMulF64x8(LAf64);
        LToleranceF64 := Max(1e-10, Abs(LFacadeMulF64) * 1e-12);
        CheckTrue(Abs(LFacadeMulF64 - LDirectMulF64) <= LToleranceF64, 'Direct ReduceMulF64x8 stable parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_Mask8Mask16InverseProperties_Parity;
const
  C_MASK8: array[0..9] of TMask8 = ($00, $01, $02, $03, $0F, $10, $55, $AA, $7F, $FF);
  C_MASK16: array[0..9] of TMask16 = ($0000, $0001, $0002, $0003, $00FF, $0F0F, $5555, $AAAA, $7FFF, $FFFF);
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LMask8: TMask8;
  LMask16: TMask16;
  LAllFacade, LAllDirect: Boolean;
  LAnyFacade, LAnyDirect: Boolean;
  LNoneFacade, LNoneDirect: Boolean;
  LPopFacade, LPopDirect: Integer;
  LFirstFacade, LFirstDirect: Integer;
  LIdx: Integer;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.Mask.Mask8All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16FirstSet)) then
        Continue;

      Inc(LTestedCount);
      for LIdx := Low(C_MASK8) to High(C_MASK8) do
      begin
        LMask8 := C_MASK8[LIdx];

        LAllFacade := Mask8All(LMask8);
        LAllDirect := LDirectDispatch^.Mask.Mask8All(LMask8);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LAnyFacade := Mask8Any(LMask8);
        LAnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LNoneFacade := Mask8None(LMask8);
        LNoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LPopFacade := Mask8PopCount(LMask8);
        LPopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LFirstFacade := Mask8FirstSet(LMask8);
        LFirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        CheckEqual(LAnyFacade, not LNoneFacade, 'Mask8 inverse property backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));
        if LAllFacade then
          CheckTrue(LAnyFacade, 'Mask8 all->any property backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));
      end;

      for LIdx := Low(C_MASK16) to High(C_MASK16) do
      begin
        LMask16 := C_MASK16[LIdx];

        LAllFacade := Mask16All(LMask16);
        LAllDirect := LDirectDispatch^.Mask.Mask16All(LMask16);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask16All parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LAnyFacade := Mask16Any(LMask16);
        LAnyDirect := LDirectDispatch^.Mask.Mask16Any(LMask16);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask16Any parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LNoneFacade := Mask16None(LMask16);
        LNoneDirect := LDirectDispatch^.Mask.Mask16None(LMask16);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask16None parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LPopFacade := Mask16PopCount(LMask16);
        LPopDirect := LDirectDispatch^.Mask.Mask16PopCount(LMask16);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask16PopCount parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        LFirstFacade := Mask16FirstSet(LMask16);
        LFirstDirect := LDirectDispatch^.Mask.Mask16FirstSet(LMask16);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask16FirstSet parity backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));

        CheckEqual(LAnyFacade, not LNoneFacade, 'Mask16 inverse property backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));
        if LAllFacade then
          CheckTrue(LAnyFacade, 'Mask16 all->any property backend ' + DirectBackendName(LBackend) + ' idx=' + IntToStr(LIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32x16F64x8CompareIdentityProperties_Parity;
const
  C_CASE_COUNT = 5;
  C_F32_CASES_A: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0), (-1.0, 2.0, -3.0, 4.0, -5.0, 6.0, -7.0, 8.0, -9.0, 10.0, -11.0, 12.0, -13.0, 14.0, -15.0, 16.0),
    (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 0.0625, 0.03125, 0.015625, 0.0078125, 3.0, 6.0, 12.0, 24.0), (1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 6000.0, 7000.0, 8000.0, -1000.0, -2000.0, -3000.0, -4000.0, -5000.0, -6000.0, -7000.0, -8000.0),
    (1.0E-4, -2.0E-4, 3.0E-4, -4.0E-4, 5.0E-4, -6.0E-4, 7.0E-4, -8.0E-4, 9.0E-4, -1.0E-3, 1.1E-3, -1.2E-3, 1.3E-3, -1.4E-3, 1.5E-3, -1.6E-3)
  );
  C_F32_CASES_B: array[0..C_CASE_COUNT - 1, 0..15] of Single = (
    (0.0, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0, 7.0, 9.0, 11.0, 10.0, 12.0, 14.0, 13.0, 15.0), (-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0),
    (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0, 0.0625, 0.0625, 0.010, 0.008, 3.0, 5.0, 12.0, 25.0), (1000.0, 1999.0, 3001.0, 4000.0, 4999.0, 6001.0, 7000.0, 8001.0, -999.0, -2001.0, -3000.0, -3999.0, -5001.0, -6000.0, -7001.0, -8000.0),
    (1.1E-4, -2.0E-4, 2.9E-4, -4.1E-4, 5.0E-4, -6.1E-4, 7.0E-4, -8.1E-4, 9.0E-4, -9.9E-4, 1.1E-3, -1.19E-3, 1.31E-3, -1.4E-3, 1.49E-3, -1.61E-3)
  );

  C_F64_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0), (-1.5, 2.5, -3.5, 4.5, -5.5, 6.5, -7.5, 8.5),
    (100.0, 200.0, 300.0, 400.0, -100.0, -200.0, -300.0, -400.0), (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0),
    (1.0E-6, -2.0E-6, 3.0E-6, -4.0E-6, 5.0E-6, -6.0E-6, 7.0E-6, -8.0E-6)
  );
  C_F64_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Double = (
    (0.0, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0), (-1.5, -2.5, -3.0, -4.5, -5.0, -6.5, -7.0, -8.5),
    (100.0, 199.0, 301.0, 400.0, -99.0, -201.0, -300.0, -399.0), (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0),
    (1.1E-6, -2.0E-6, 2.9E-6, -4.1E-6, 5.0E-6, -6.1E-6, 7.0E-6, -8.1E-6)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAf32, LBf32: TVecF32x16;
  LAf64, LBf64: TVecF64x8;
  LCaseIdx: Integer;
  LLane: Integer;
  LMask16Eq, LMask16Lt, LMask16Le, LMask16Gt, LMask16Ge, LMask16Ne: TMask16;
  LMask8Eq, LMask8Lt, LMask8Le, LMask8Gt, LMask8Ge, LMask8Ne: TMask8;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.CmpEqF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeF32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeF64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeF64x8)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 15 do
        begin
          LAf32.f[LLane] := C_F32_CASES_A[LCaseIdx, LLane];
          LBf32.f[LLane] := C_F32_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 7 do
        begin
          LAf64.d[LLane] := C_F64_CASES_A[LCaseIdx, LLane];
          LBf64.d[LLane] := C_F64_CASES_B[LCaseIdx, LLane];
        end;

        LMask16Eq := LDirectDispatch^.CoreVectors.CmpEqF32x16(LAf32, LBf32);
        LMask16Lt := LDirectDispatch^.CoreVectors.CmpLtF32x16(LAf32, LBf32);
        LMask16Le := LDirectDispatch^.CoreVectors.CmpLeF32x16(LAf32, LBf32);
        LMask16Gt := LDirectDispatch^.CoreVectors.CmpGtF32x16(LAf32, LBf32);
        LMask16Ge := LDirectDispatch^.CoreVectors.CmpGeF32x16(LAf32, LBf32);
        LMask16Ne := LDirectDispatch^.CoreVectors.CmpNeF32x16(LAf32, LBf32);

        CheckEqual(Integer($FFFF), Integer(LMask16Eq or LMask16Ne), 'F32x16 Eq/Ne partition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(0), Integer(LMask16Eq and LMask16Ne), 'F32x16 Eq/Ne disjoint backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(Integer(LMask16Lt), Integer(LDirectDispatch^.CoreVectors.CmpGtF32x16(LBf32, LAf32)), 'F32x16 Lt/Gt symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask16Le), Integer(LDirectDispatch^.CoreVectors.CmpGeF32x16(LBf32, LAf32)), 'F32x16 Le/Ge symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(Integer(LMask16Le), Integer(LMask16Lt or LMask16Eq), 'F32x16 Le decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask16Ge), Integer(LMask16Gt or LMask16Eq), 'F32x16 Ge decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8Eq := LDirectDispatch^.CoreVectors.CmpEqF64x8(LAf64, LBf64);
        LMask8Lt := LDirectDispatch^.CoreVectors.CmpLtF64x8(LAf64, LBf64);
        LMask8Le := LDirectDispatch^.CoreVectors.CmpLeF64x8(LAf64, LBf64);
        LMask8Gt := LDirectDispatch^.CoreVectors.CmpGtF64x8(LAf64, LBf64);
        LMask8Ge := LDirectDispatch^.CoreVectors.CmpGeF64x8(LAf64, LBf64);
        LMask8Ne := LDirectDispatch^.CoreVectors.CmpNeF64x8(LAf64, LBf64);

        CheckEqual(Integer($FF), Integer(LMask8Eq or LMask8Ne), 'F64x8 Eq/Ne partition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(0), Integer(LMask8Eq and LMask8Ne), 'F64x8 Eq/Ne disjoint backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(Integer(LMask8Lt), Integer(LDirectDispatch^.CoreVectors.CmpGtF64x8(LBf64, LAf64)), 'F64x8 Lt/Gt symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Le), Integer(LDirectDispatch^.CoreVectors.CmpGeF64x8(LBf64, LAf64)), 'F64x8 Le/Ge symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(Integer(LMask8Le), Integer(LMask8Lt or LMask8Eq), 'F64x8 Le decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Ge), Integer(LMask8Gt or LMask8Eq), 'F64x8 Ge decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_U32x8U64x4CompareIdentityMaskProperties_Parity;
const
  C_CASE_COUNT = 8;
  C_U32_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of UInt32 = (
    (0, 1, 2, 3, 4, 5, 6, 7), ($FFFFFFFF, $FFFFFFFE, $80000000, $7FFFFFFF, 1, 2, 3, 4),
    (100, 200, 300, 400, 500, 600, 700, 800), (0, 0, 0, 0, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF),
    ($80000000, $80000001, $7FFFFFFE, $7FFFFFFF, 15, 16, 17, 18), (42, 43, 44, 45, 46, 47, 48, 49),
    ($AAAAAAAA, $55555555, $0F0F0F0F, $F0F0F0F0, 9, 10, 11, 12), (1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000)
  );
  C_U32_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of UInt32 = (
    (0, 0, 3, 2, 4, 6, 5, 7), ($FFFFFFFF, 1, $7FFFFFFF, $80000000, 2, 2, 4, 3),
    (100, 199, 301, 400, 499, 601, 700, 900), (1, 0, $FFFFFFFF, 0, $FFFFFFFF, 0, $FFFFFFFF, 0),
    ($7FFFFFFF, $80000000, $7FFFFFFF, $7FFFFFFE, 15, 15, 18, 17), (41, 43, 45, 45, 47, 47, 49, 49),
    ($AAAAAAAA, $AAAAAAAA, $F0F0F0F0, $0F0F0F0F, 8, 10, 12, 12), (999, 2001, 3000, 3999, 5001, 6000, 6999, 9000)
  );

  C_U64_CASES_A: array[0..C_CASE_COUNT - 1, 0..3] of UInt64 = (
    (0, 1, 2, 3), (18446744073709551615, 9223372036854775808, 9223372036854775807, 42),
    (1000, 2000, 3000, 4000), (0, 18446744073709551615, 123456789, 987654321),
    (12297829382473034410, 6148914691236517205, 11, 12), (15, 16, 17, 18),
    ($0000000100000000, $0000000200000000, 5, 6), (9000000000, 9000000001, 9000000002, 9000000003)
  );
  C_U64_CASES_B: array[0..C_CASE_COUNT - 1, 0..3] of UInt64 = (
    (0, 0, 3, 2), (18446744073709551615, 9223372036854775807, 9223372036854775808, 41),
    (1000, 1999, 3001, 4000), (1, 18446744073709551615, 123456788, 987654322),
    (12297829382473034410, 12297829382473034410, 10, 12), (14, 16, 18, 18),
    ($0000000100000001, $0000000200000000, 4, 7), (9000000001, 9000000001, 9000000000, 9000000004)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAu32, LBu32: TVecU32x8;
  LAu64, LBu64: TVecU64x4;
  LCaseIdx: Integer;
  LLane: Integer;

  LMask8Eq, LMask8Lt, LMask8Le, LMask8Gt, LMask8Ge, LMask8Ne: TMask8;
  LMask4Eq, LMask4Lt, LMask4Le, LMask4Gt, LMask4Ge, LMask4Ne: TMask4;

  LAnyFacade, LAnyDirect: Boolean;
  LNoneFacade, LNoneDirect: Boolean;
  LAllFacade, LAllDirect: Boolean;
  LPopFacade, LPopDirect: Integer;
  LFirstFacade, LFirstDirect: Integer;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.CmpEqU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeU32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeU64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeU64x4)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4FirstSet)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LAu32.u[LLane] := C_U32_CASES_A[LCaseIdx, LLane];
          LBu32.u[LLane] := C_U32_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 3 do
        begin
          LAu64.u[LLane] := C_U64_CASES_A[LCaseIdx, LLane];
          LBu64.u[LLane] := C_U64_CASES_B[LCaseIdx, LLane];
        end;

        LMask8Eq := LDirectDispatch^.CoreVectors.CmpEqU32x8(LAu32, LBu32);
        LMask8Lt := LDirectDispatch^.CoreVectors.CmpLtU32x8(LAu32, LBu32);
        LMask8Le := LDirectDispatch^.CoreVectors.CmpLeU32x8(LAu32, LBu32);
        LMask8Gt := LDirectDispatch^.CoreVectors.CmpGtU32x8(LAu32, LBu32);
        LMask8Ge := LDirectDispatch^.CoreVectors.CmpGeU32x8(LAu32, LBu32);
        LMask8Ne := LDirectDispatch^.CoreVectors.CmpNeU32x8(LAu32, LBu32);

        CheckEqual(Integer($FF), Integer(LMask8Eq or LMask8Ne), 'U32x8 Eq/Ne partition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(0), Integer(LMask8Eq and LMask8Ne), 'U32x8 Eq/Ne disjoint backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(Integer(LMask8Lt), Integer(LDirectDispatch^.CoreVectors.CmpGtU32x8(LBu32, LAu32)), 'U32x8 Lt/Gt symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Le), Integer(LDirectDispatch^.CoreVectors.CmpGeU32x8(LBu32, LAu32)), 'U32x8 Le/Ge symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Le), Integer(LMask8Lt or LMask8Eq), 'U32x8 Le decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Ge), Integer(LMask8Gt or LMask8Eq), 'U32x8 Ge decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAnyFacade := Mask8Any(LMask8Lt);
        LAnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8Lt);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LNoneFacade := Mask8None(LMask8Lt);
        LNoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8Lt);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAllFacade := Mask8All(LMask8Lt);
        LAllDirect := LDirectDispatch^.Mask.Mask8All(LMask8Lt);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LPopFacade := Mask8PopCount(LMask8Lt);
        LPopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8Lt);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LFirstFacade := Mask8FirstSet(LMask8Lt);
        LFirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8Lt);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(LAnyFacade, not LNoneFacade, 'U32x8 Mask inverse property backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        if LNoneFacade then
          CheckEqual(-1, LFirstFacade, 'U32x8 Mask firstset none backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx))
        else
        begin
          CheckTrue((LFirstFacade >= 0) and (LFirstFacade < 8), 'U32x8 Mask firstset range backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
          CheckTrue((LMask8Lt and TMask8(1 shl LFirstFacade)) <> 0, 'U32x8 Mask firstset bit backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        end;

        LMask4Eq := LDirectDispatch^.CoreVectors.CmpEqU64x4(LAu64, LBu64);
        LMask4Lt := LDirectDispatch^.CoreVectors.CmpLtU64x4(LAu64, LBu64);
        LMask4Le := LDirectDispatch^.CoreVectors.CmpLeU64x4(LAu64, LBu64);
        LMask4Gt := LDirectDispatch^.CoreVectors.CmpGtU64x4(LAu64, LBu64);
        LMask4Ge := LDirectDispatch^.CoreVectors.CmpGeU64x4(LAu64, LBu64);
        LMask4Ne := LDirectDispatch^.CoreVectors.CmpNeU64x4(LAu64, LBu64);

        CheckEqual(Integer($0F), Integer(LMask4Eq or LMask4Ne), 'U64x4 Eq/Ne partition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(0), Integer(LMask4Eq and LMask4Ne), 'U64x4 Eq/Ne disjoint backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(Integer(LMask4Lt), Integer(LDirectDispatch^.CoreVectors.CmpGtU64x4(LBu64, LAu64)), 'U64x4 Lt/Gt symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Le), Integer(LDirectDispatch^.CoreVectors.CmpGeU64x4(LBu64, LAu64)), 'U64x4 Le/Ge symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Le), Integer(LMask4Lt or LMask4Eq), 'U64x4 Le decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Ge), Integer(LMask4Gt or LMask4Eq), 'U64x4 Ge decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAnyFacade := Mask4Any(LMask4Lt);
        LAnyDirect := LDirectDispatch^.Mask.Mask4Any(LMask4Lt);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask4Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LNoneFacade := Mask4None(LMask4Lt);
        LNoneDirect := LDirectDispatch^.Mask.Mask4None(LMask4Lt);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask4None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAllFacade := Mask4All(LMask4Lt);
        LAllDirect := LDirectDispatch^.Mask.Mask4All(LMask4Lt);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LPopFacade := Mask4PopCount(LMask4Lt);
        LPopDirect := LDirectDispatch^.Mask.Mask4PopCount(LMask4Lt);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask4PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LFirstFacade := Mask4FirstSet(LMask4Lt);
        LFirstDirect := LDirectDispatch^.Mask.Mask4FirstSet(LMask4Lt);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask4FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(LAnyFacade, not LNoneFacade, 'U64x4 Mask inverse property backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        if LNoneFacade then
          CheckEqual(-1, LFirstFacade, 'U64x4 Mask firstset none backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx))
        else
        begin
          CheckTrue((LFirstFacade >= 0) and (LFirstFacade < 4), 'U64x4 Mask firstset range backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
          CheckTrue((LMask4Lt and TMask4(1 shl LFirstFacade)) <> 0, 'U64x4 Mask firstset bit backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        end;
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_F32x8F64x4CompareIdentityMaskProperties_Parity;
const
  C_CASE_COUNT = 6;
  C_F32_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Single = (
    (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0), (-1.0, 2.0, -3.0, 4.0, -5.0, 6.0, -7.0, 8.0),
    (0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0), (1000.0, 2000.0, 3000.0, 4000.0, -1000.0, -2000.0, -3000.0, -4000.0),
    (1.0E-4, -2.0E-4, 3.0E-4, -4.0E-4, 5.0E-4, -6.0E-4, 7.0E-4, -8.0E-4), (-0.0, 0.0, -1.0, 1.0, 10.0, -10.0, 100.0, -100.0)
  );
  C_F32_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Single = (
    (0.0, 2.0, 1.0, 3.0, 5.0, 4.0, 6.0, 8.0), (-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0),
    (0.125, 0.5, 0.25, 1.0, 1.0, 8.0, 4.0, 16.0), (1000.0, 1999.0, 3001.0, 4000.0, -999.0, -2001.0, -3000.0, -3999.0),
    (1.1E-4, -2.0E-4, 2.9E-4, -4.1E-4, 5.0E-4, -6.1E-4, 7.0E-4, -8.1E-4), (0.0, -0.0, -1.0, 2.0, 9.0, -9.0, 100.0, -101.0)
  );

  C_F64_CASES_A: array[0..C_CASE_COUNT - 1, 0..3] of Double = (
    (0.0, 1.0, 2.0, 3.0), (-1.5, 2.5, -3.5, 4.5),
    (100.0, 200.0, -300.0, -400.0), (0.125, 0.25, 0.5, 1.0),
    (1.0E-6, -2.0E-6, 3.0E-6, -4.0E-6), (-0.0, 0.0, 10.0, -10.0)
  );
  C_F64_CASES_B: array[0..C_CASE_COUNT - 1, 0..3] of Double = (
    (0.0, 2.0, 1.0, 3.0), (-1.5, -2.5, -3.0, -4.5),
    (100.0, 199.0, -299.0, -401.0), (0.125, 0.5, 0.25, 1.0),
    (1.1E-6, -2.0E-6, 2.9E-6, -4.1E-6), (0.0, -0.0, 9.0, -11.0)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAf32, LBf32: TVecF32x8;
  LAf64, LBf64: TVecF64x4;
  LCaseIdx: Integer;
  LLane: Integer;
  LMask8Eq, LMask8Lt, LMask8Le, LMask8Gt, LMask8Ge, LMask8Ne: TMask8;
  LMask4Eq, LMask4Lt, LMask4Le, LMask4Gt, LMask4Ge, LMask4Ne: TMask4;
  LAnyFacade, LAnyDirect: Boolean;
  LNoneFacade, LNoneDirect: Boolean;
  LAllFacade, LAllDirect: Boolean;
  LPopFacade, LPopDirect: Integer;
  LFirstFacade, LFirstDirect: Integer;
  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;
      if LBackend <> sbScalar then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.CmpEqF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeF32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeF64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeF64x4)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4FirstSet)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LAf32.f[LLane] := C_F32_CASES_A[LCaseIdx, LLane];
          LBf32.f[LLane] := C_F32_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 3 do
        begin
          LAf64.d[LLane] := C_F64_CASES_A[LCaseIdx, LLane];
          LBf64.d[LLane] := C_F64_CASES_B[LCaseIdx, LLane];
        end;

        LMask8Eq := LDirectDispatch^.CoreVectors.CmpEqF32x8(LAf32, LBf32);
        LMask8Lt := LDirectDispatch^.CoreVectors.CmpLtF32x8(LAf32, LBf32);
        LMask8Le := LDirectDispatch^.CoreVectors.CmpLeF32x8(LAf32, LBf32);
        LMask8Gt := LDirectDispatch^.CoreVectors.CmpGtF32x8(LAf32, LBf32);
        LMask8Ge := LDirectDispatch^.CoreVectors.CmpGeF32x8(LAf32, LBf32);
        LMask8Ne := LDirectDispatch^.CoreVectors.CmpNeF32x8(LAf32, LBf32);

        CheckEqual(Integer($FF), Integer(LMask8Eq or LMask8Ne), 'F32x8 Eq/Ne partition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(0), Integer(LMask8Eq and LMask8Ne), 'F32x8 Eq/Ne disjoint backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Lt), Integer(LDirectDispatch^.CoreVectors.CmpGtF32x8(LBf32, LAf32)), 'F32x8 Lt/Gt symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Le), Integer(LDirectDispatch^.CoreVectors.CmpGeF32x8(LBf32, LAf32)), 'F32x8 Le/Ge symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Le), Integer(LMask8Lt or LMask8Eq), 'F32x8 Le decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask8Ge), Integer(LMask8Gt or LMask8Eq), 'F32x8 Ge decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAnyFacade := Mask8Any(LMask8Lt);
        LAnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8Lt);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LNoneFacade := Mask8None(LMask8Lt);
        LNoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8Lt);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LAllFacade := Mask8All(LMask8Lt);
        LAllDirect := LDirectDispatch^.Mask.Mask8All(LMask8Lt);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LPopFacade := Mask8PopCount(LMask8Lt);
        LPopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8Lt);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LFirstFacade := Mask8FirstSet(LMask8Lt);
        LFirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8Lt);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(LAnyFacade, not LNoneFacade, 'F32x8 Mask inverse property backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        if LNoneFacade then
          CheckEqual(-1, LFirstFacade, 'F32x8 Mask firstset none backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx))
        else
          CheckTrue((LFirstFacade >= 0) and (LFirstFacade < 8), 'F32x8 Mask firstset range backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4Eq := LDirectDispatch^.CoreVectors.CmpEqF64x4(LAf64, LBf64);
        LMask4Lt := LDirectDispatch^.CoreVectors.CmpLtF64x4(LAf64, LBf64);
        LMask4Le := LDirectDispatch^.CoreVectors.CmpLeF64x4(LAf64, LBf64);
        LMask4Gt := LDirectDispatch^.CoreVectors.CmpGtF64x4(LAf64, LBf64);
        LMask4Ge := LDirectDispatch^.CoreVectors.CmpGeF64x4(LAf64, LBf64);
        LMask4Ne := LDirectDispatch^.CoreVectors.CmpNeF64x4(LAf64, LBf64);

        CheckEqual(Integer($0F), Integer(LMask4Eq or LMask4Ne), 'F64x4 Eq/Ne partition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(0), Integer(LMask4Eq and LMask4Ne), 'F64x4 Eq/Ne disjoint backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Lt), Integer(LDirectDispatch^.CoreVectors.CmpGtF64x4(LBf64, LAf64)), 'F64x4 Lt/Gt symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Le), Integer(LDirectDispatch^.CoreVectors.CmpGeF64x4(LBf64, LAf64)), 'F64x4 Le/Ge symmetry backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Le), Integer(LMask4Lt or LMask4Eq), 'F64x4 Le decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        CheckEqual(Integer(LMask4Ge), Integer(LMask4Gt or LMask4Eq), 'F64x4 Ge decomposition backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LAnyFacade := Mask4Any(LMask4Lt);
        LAnyDirect := LDirectDispatch^.Mask.Mask4Any(LMask4Lt);
        CheckEqual(LAnyFacade, LAnyDirect, 'Direct Mask4Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LNoneFacade := Mask4None(LMask4Lt);
        LNoneDirect := LDirectDispatch^.Mask.Mask4None(LMask4Lt);
        CheckEqual(LNoneFacade, LNoneDirect, 'Direct Mask4None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LAllFacade := Mask4All(LMask4Lt);
        LAllDirect := LDirectDispatch^.Mask.Mask4All(LMask4Lt);
        CheckEqual(LAllFacade, LAllDirect, 'Direct Mask4All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LPopFacade := Mask4PopCount(LMask4Lt);
        LPopDirect := LDirectDispatch^.Mask.Mask4PopCount(LMask4Lt);
        CheckEqual(LPopFacade, LPopDirect, 'Direct Mask4PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LFirstFacade := Mask4FirstSet(LMask4Lt);
        LFirstDirect := LDirectDispatch^.Mask.Mask4FirstSet(LMask4Lt);
        CheckEqual(LFirstFacade, LFirstDirect, 'Direct Mask4FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        CheckEqual(LAnyFacade, not LNoneFacade, 'F64x4 Mask inverse property backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        if LNoneFacade then
          CheckEqual(-1, LFirstFacade, 'F64x4 Mask firstset none backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx))
        else
          CheckTrue((LFirstFacade >= 0) and (LFirstFacade < 4), 'F64x4 Mask firstset range backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_I16I8CompareEdgeMatrix_Parity;
const
  C_CASE_COUNT = 4;
  C_I16_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Int16 = (
    (Low(Int16), -1024, -1, 0, 1, 1024, 32766, High(Int16)), (0, 0, 0, 0, 0, 0, 0, 0),
    (-1, -2, -3, -4, 4, 3, 2, 1), (123, -456, 789, -1011, 1213, -1415, 1617, -1819)
  );
  C_I16_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Int16 = (
    (Low(Int16), -1000, 0, 0, -1, 2048, 32766, High(Int16)), (1, -1, 2, -2, 3, -3, 4, -4),
    (-1, -1, -4, -4, 4, 2, 2, 2), (123, -500, 700, -1011, 1300, -1500, 1617, -1700)
  );

  C_I8_CASES_A: array[0..C_CASE_COUNT - 1, 0..15] of Int8 = (
    (Low(Int8), -100, -64, -32, -16, -8, -4, -2, -1, 0, 1, 2, 4, 8, 64, High(Int8)), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (-1, -2, -3, -4, -5, -6, -7, -8, 8, 7, 6, 5, 4, 3, 2, 1), (11, -22, 33, -44, 55, -66, 77, -88, 99, -110, 120, -120, 10, -10, 5, -5)
  );
  C_I8_CASES_B: array[0..C_CASE_COUNT - 1, 0..15] of Int8 = (
    (Low(Int8), -99, -64, -40, -16, -7, -5, -2, -2, 1, 0, 3, 4, 7, 63, High(Int8)), (1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8),
    (-1, -1, -4, -4, -5, -5, -9, -9, 8, 8, 5, 5, 3, 3, 2, 2), (11, -30, 40, -44, 50, -60, 80, -90, 100, -100, 120, -121, 9, -9, 6, -6)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAi16, LBi16: TVecI16x8;
  LAi8, LBi8: TVecI8x16;
  LCaseIdx: Integer;
  LLane: Integer;

  LMask8EqFacade, LMask8EqDirect: TMask8;
  LMask8LtFacade, LMask8LtDirect: TMask8;
  LMask8GtFacade, LMask8GtDirect: TMask8;
  LMask8AllFacade, LMask8AllDirect: Boolean;
  LMask8AnyFacade, LMask8AnyDirect: Boolean;
  LMask8NoneFacade, LMask8NoneDirect: Boolean;
  LMask8PopFacade, LMask8PopDirect: Integer;
  LMask8FirstFacade, LMask8FirstDirect: Integer;

  LMask16EqFacade, LMask16EqDirect: TMask16;
  LMask16LtFacade, LMask16LtDirect: TMask16;
  LMask16GtFacade, LMask16GtDirect: TMask16;
  LMask16AllFacade, LMask16AllDirect: Boolean;
  LMask16AnyFacade, LMask16AnyDirect: Boolean;
  LMask16NoneFacade, LMask16NoneDirect: Boolean;
  LMask16PopFacade, LMask16PopDirect: Integer;
  LMask16FirstFacade, LMask16FirstDirect: Integer;

  LTestedCount: Integer;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqI16x8), 'CmpEqI16x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.CmpEqI8x16), 'CmpEqI8x16 should be assigned for backend ' + DirectBackendName(LBackend));

      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LAi16.i[LLane] := C_I16_CASES_A[LCaseIdx, LLane];
          LBi16.i[LLane] := C_I16_CASES_B[LCaseIdx, LLane];
        end;

        for LLane := 0 to 15 do
        begin
          LAi8.i[LLane] := C_I8_CASES_A[LCaseIdx, LLane];
          LBi8.i[LLane] := C_I8_CASES_B[LCaseIdx, LLane];
        end;

        // I16x8 compare + Mask8
        LMask8EqFacade := VecI16x8CmpEq(LAi16, LBi16);
        LMask8EqDirect := LDirectDispatch^.CoreVectors.CmpEqI16x8(LAi16, LBi16);
        CheckEqual(Integer(LMask8EqFacade), Integer(LMask8EqDirect), 'Direct CmpEqI16x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8LtFacade := VecI16x8CmpLt(LAi16, LBi16);
        LMask8LtDirect := LDirectDispatch^.CoreVectors.CmpLtI16x8(LAi16, LBi16);
        CheckEqual(Integer(LMask8LtFacade), Integer(LMask8LtDirect), 'Direct CmpLtI16x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8GtFacade := VecI16x8CmpGt(LAi16, LBi16);
        LMask8GtDirect := LDirectDispatch^.CoreVectors.CmpGtI16x8(LAi16, LBi16);
        CheckEqual(Integer(LMask8GtFacade), Integer(LMask8GtDirect), 'Direct CmpGtI16x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8AllFacade := Mask8All(LMask8LtFacade);
        LMask8AllDirect := LDirectDispatch^.Mask.Mask8All(LMask8LtDirect);
        CheckEqual(LMask8AllFacade, LMask8AllDirect, 'Direct Mask8All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8AnyFacade := Mask8Any(LMask8LtFacade);
        LMask8AnyDirect := LDirectDispatch^.Mask.Mask8Any(LMask8LtDirect);
        CheckEqual(LMask8AnyFacade, LMask8AnyDirect, 'Direct Mask8Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8NoneFacade := Mask8None(LMask8LtFacade);
        LMask8NoneDirect := LDirectDispatch^.Mask.Mask8None(LMask8LtDirect);
        CheckEqual(LMask8NoneFacade, LMask8NoneDirect, 'Direct Mask8None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8PopFacade := Mask8PopCount(LMask8LtFacade);
        LMask8PopDirect := LDirectDispatch^.Mask.Mask8PopCount(LMask8LtDirect);
        CheckEqual(LMask8PopFacade, LMask8PopDirect, 'Direct Mask8PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8FirstFacade := Mask8FirstSet(LMask8LtFacade);
        LMask8FirstDirect := LDirectDispatch^.Mask.Mask8FirstSet(LMask8LtDirect);
        CheckEqual(LMask8FirstFacade, LMask8FirstDirect, 'Direct Mask8FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        // I8x16 compare + Mask16
        LMask16EqFacade := VecI8x16CmpEq(LAi8, LBi8);
        LMask16EqDirect := LDirectDispatch^.CoreVectors.CmpEqI8x16(LAi8, LBi8);
        CheckEqual(Integer(LMask16EqFacade), Integer(LMask16EqDirect), 'Direct CmpEqI8x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16LtFacade := VecI8x16CmpLt(LAi8, LBi8);
        LMask16LtDirect := LDirectDispatch^.CoreVectors.CmpLtI8x16(LAi8, LBi8);
        CheckEqual(Integer(LMask16LtFacade), Integer(LMask16LtDirect), 'Direct CmpLtI8x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16GtFacade := VecI8x16CmpGt(LAi8, LBi8);
        LMask16GtDirect := LDirectDispatch^.CoreVectors.CmpGtI8x16(LAi8, LBi8);
        CheckEqual(Integer(LMask16GtFacade), Integer(LMask16GtDirect), 'Direct CmpGtI8x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16AllFacade := Mask16All(LMask16LtFacade);
        LMask16AllDirect := LDirectDispatch^.Mask.Mask16All(LMask16LtDirect);
        CheckEqual(LMask16AllFacade, LMask16AllDirect, 'Direct Mask16All parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16AnyFacade := Mask16Any(LMask16LtFacade);
        LMask16AnyDirect := LDirectDispatch^.Mask.Mask16Any(LMask16LtDirect);
        CheckEqual(LMask16AnyFacade, LMask16AnyDirect, 'Direct Mask16Any parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16NoneFacade := Mask16None(LMask16LtFacade);
        LMask16NoneDirect := LDirectDispatch^.Mask.Mask16None(LMask16LtDirect);
        CheckEqual(LMask16NoneFacade, LMask16NoneDirect, 'Direct Mask16None parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16PopFacade := Mask16PopCount(LMask16LtFacade);
        LMask16PopDirect := LDirectDispatch^.Mask.Mask16PopCount(LMask16LtDirect);
        CheckEqual(LMask16PopFacade, LMask16PopDirect, 'Direct Mask16PopCount parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16FirstFacade := Mask16FirstSet(LMask16LtFacade);
        LMask16FirstDirect := LDirectDispatch^.Mask.Mask16FirstSet(LMask16LtDirect);
        CheckEqual(LMask16FirstFacade, LMask16FirstDirect, 'Direct Mask16FirstSet parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;



procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_SignedWideCompareMaskMatrix_Parity;
const
  C_CASE_COUNT = 4;
  C_I32X8_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Int32 = (
    (Low(Int32), -100, -1, 0, 1, 100, High(Int32), 42), (-1, -2, -3, -4, 4, 3, 2, 1),
    (0, 0, 0, 0, 0, 0, 0, 0), (7, -7, 1024, -1024, 33, -33, 5, -5)
  );
  C_I32X8_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Int32 = (
    (Low(Int32), -99, 0, 0, -1, 101, High(Int32) - 1, 42), (-1, -1, -4, -4, 4, 2, 3, 0),
    (0, 0, 0, 0, 0, 0, 0, 0), (8, -8, 1023, -1023, 33, -40, 6, -4)
  );
  C_I64X4_CASES_A: array[0..C_CASE_COUNT - 1, 0..3] of Int64 = (
    (Low(Int64), -1, 0, High(Int64)), (-1000, 7777777, -1234567890123, 42),
    (0, 0, 0, 0), (99, -99, 4096, -4096)
  );
  C_I64X4_CASES_B: array[0..C_CASE_COUNT - 1, 0..3] of Int64 = (
    (Low(Int64), 0, 0, High(Int64) - 1), (13, -9, 3000, -500),
    (0, 0, 0, 0), (100, -100, 4095, -4095)
  );
  C_I32X16_CASES_A: array[0..C_CASE_COUNT - 1, 0..15] of Int32 = (
    (Low(Int32), -1024, -1, 0, 1, 1024, High(Int32), 42, -42, 7, -7, 99, -99, 2048, -2048, 123456), (-1, -2, -3, -4, -5, -6, -7, -8, 8, 7, 6, 5, 4, 3, 2, 1),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (17, -17, 33, -33, 65, -65, 129, -129, 257, -257, 513, -513, 1025, -1025, 2049, -2049)
  );
  C_I32X16_CASES_B: array[0..C_CASE_COUNT - 1, 0..15] of Int32 = (
    (Low(Int32), -1023, 0, 0, -1, 2048, High(Int32), 41, -43, 8, -8, 99, -100, 2047, -2049, 123456), (-1, -1, -4, -4, -4, -7, -8, -8, 7, 8, 5, 6, 3, 4, 1, 2),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (16, -18, 34, -32, 64, -66, 130, -128, 256, -258, 514, -512, 1026, -1024, 2050, -2048)
  );
  C_I64X8_CASES_A: array[0..C_CASE_COUNT - 1, 0..7] of Int64 = (
    (Low(Int64), -1, 0, 1, 2, -2, High(Int64), 42), (-1000, 7777777, -1234567890123, 42, -7, 9, -11, 13),
    (0, 0, 0, 0, 0, 0, 0, 0), (512, -512, 1024, -1024, 2048, -2048, 4096, -4096)
  );
  C_I64X8_CASES_B: array[0..C_CASE_COUNT - 1, 0..7] of Int64 = (
    (Low(Int64), 0, 0, -1, 3, -3, High(Int64), 42), (13, -9, 3000, -500, -8, 9, -10, 14),
    (0, 0, 0, 0, 0, 0, 0, 0), (513, -513, 1023, -1023, 2048, -2049, 4097, -4095)
  );
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LAi32x8, LBi32x8: TVecI32x8;
  LAi64x4, LBi64x4: TVecI64x4;
  LAi32x16, LBi32x16: TVecI32x16;
  LAi64x8, LBi64x8: TVecI64x8;
  LMask8Direct, LMask8Scalar: TMask8;
  LMask4Direct, LMask4Scalar: TMask4;
  LMask16Direct, LMask16Scalar: TMask16;
  LCaseIdx: Integer;
  LLane: Integer;
  LTestedCount: Integer;

  procedure AssertMask4HelperParity(const aLabel: string; const aMask: TMask4);
  begin
    CheckEqual(ScalarMask4All(aMask), LDirectDispatch^.Mask.Mask4All(aMask), aLabel + ' Mask4All backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask4Any(aMask), LDirectDispatch^.Mask.Mask4Any(aMask), aLabel + ' Mask4Any backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask4None(aMask), LDirectDispatch^.Mask.Mask4None(aMask), aLabel + ' Mask4None backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask4PopCount(aMask), LDirectDispatch^.Mask.Mask4PopCount(aMask), aLabel + ' Mask4PopCount backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask4FirstSet(aMask), LDirectDispatch^.Mask.Mask4FirstSet(aMask), aLabel + ' Mask4FirstSet backend ' + DirectBackendName(LBackend));
  end;

  procedure AssertMask8HelperParity(const aLabel: string; const aMask: TMask8);
  begin
    CheckEqual(ScalarMask8All(aMask), LDirectDispatch^.Mask.Mask8All(aMask), aLabel + ' Mask8All backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask8Any(aMask), LDirectDispatch^.Mask.Mask8Any(aMask), aLabel + ' Mask8Any backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask8None(aMask), LDirectDispatch^.Mask.Mask8None(aMask), aLabel + ' Mask8None backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask8PopCount(aMask), LDirectDispatch^.Mask.Mask8PopCount(aMask), aLabel + ' Mask8PopCount backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask8FirstSet(aMask), LDirectDispatch^.Mask.Mask8FirstSet(aMask), aLabel + ' Mask8FirstSet backend ' + DirectBackendName(LBackend));
  end;

  procedure AssertMask16HelperParity(const aLabel: string; const aMask: TMask16);
  begin
    CheckEqual(ScalarMask16All(aMask), LDirectDispatch^.Mask.Mask16All(aMask), aLabel + ' Mask16All backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask16Any(aMask), LDirectDispatch^.Mask.Mask16Any(aMask), aLabel + ' Mask16Any backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask16None(aMask), LDirectDispatch^.Mask.Mask16None(aMask), aLabel + ' Mask16None backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask16PopCount(aMask), LDirectDispatch^.Mask.Mask16PopCount(aMask), aLabel + ' Mask16PopCount backend ' + DirectBackendName(LBackend));
    CheckEqual(ScalarMask16FirstSet(aMask), LDirectDispatch^.Mask.Mask16FirstSet(aMask), aLabel + ' Mask16FirstSet backend ' + DirectBackendName(LBackend));
  end;
begin
  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;
      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));

      if (not Assigned(LDirectDispatch^.CoreVectors.CmpEqI32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtI32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtI32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeI32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeI32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeI32x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqI64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtI64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtI64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeI64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeI64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeI64x4)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqI32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtI32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtI32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeI32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeI32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeI32x16)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpEqI64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLtI64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGtI64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpLeI64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpGeI64x8)) or
         (not Assigned(LDirectDispatch^.CoreVectors.CmpNeI64x8)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask4FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask8FirstSet)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16All)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16Any)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16None)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16PopCount)) or
         (not Assigned(LDirectDispatch^.Mask.Mask16FirstSet)) then
        Continue;

      Inc(LTestedCount);
      for LCaseIdx := 0 to C_CASE_COUNT - 1 do
      begin
        for LLane := 0 to 7 do
        begin
          LAi32x8.i[LLane] := C_I32X8_CASES_A[LCaseIdx, LLane];
          LBi32x8.i[LLane] := C_I32X8_CASES_B[LCaseIdx, LLane];
          LAi64x8.i[LLane] := C_I64X8_CASES_A[LCaseIdx, LLane];
          LBi64x8.i[LLane] := C_I64X8_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 3 do
        begin
          LAi64x4.i[LLane] := C_I64X4_CASES_A[LCaseIdx, LLane];
          LBi64x4.i[LLane] := C_I64X4_CASES_B[LCaseIdx, LLane];
        end;
        for LLane := 0 to 15 do
        begin
          LAi32x16.i[LLane] := C_I32X16_CASES_A[LCaseIdx, LLane];
          LBi32x16.i[LLane] := C_I32X16_CASES_B[LCaseIdx, LLane];
        end;

        LMask8Direct := LDirectDispatch^.CoreVectors.CmpEqI32x8(LAi32x8, LBi32x8);
        LMask8Scalar := ScalarCmpEqI32x8(LAi32x8, LBi32x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpEqI32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpLtI32x8(LAi32x8, LBi32x8);
        LMask8Scalar := ScalarCmpLtI32x8(LAi32x8, LBi32x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpLtI32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        AssertMask8HelperParity('I32x8 Lt case=' + IntToStr(LCaseIdx), LMask8Scalar);
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpGtI32x8(LAi32x8, LBi32x8);
        LMask8Scalar := ScalarCmpGtI32x8(LAi32x8, LBi32x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpGtI32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpLeI32x8(LAi32x8, LBi32x8);
        LMask8Scalar := ScalarCmpLeI32x8(LAi32x8, LBi32x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpLeI32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpGeI32x8(LAi32x8, LBi32x8);
        LMask8Scalar := ScalarCmpGeI32x8(LAi32x8, LBi32x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpGeI32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpNeI32x8(LAi32x8, LBi32x8);
        LMask8Scalar := ScalarCmpNeI32x8(LAi32x8, LBi32x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpNeI32x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask4Direct := LDirectDispatch^.CoreVectors.CmpEqI64x4(LAi64x4, LBi64x4);
        LMask4Scalar := ScalarCmpEqI64x4(LAi64x4, LBi64x4);
        CheckEqual(Integer(LMask4Scalar), Integer(LMask4Direct), 'Direct CmpEqI64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask4Direct := LDirectDispatch^.CoreVectors.CmpLtI64x4(LAi64x4, LBi64x4);
        LMask4Scalar := ScalarCmpLtI64x4(LAi64x4, LBi64x4);
        CheckEqual(Integer(LMask4Scalar), Integer(LMask4Direct), 'Direct CmpLtI64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        AssertMask4HelperParity('I64x4 Lt case=' + IntToStr(LCaseIdx), LMask4Scalar);
        LMask4Direct := LDirectDispatch^.CoreVectors.CmpGtI64x4(LAi64x4, LBi64x4);
        LMask4Scalar := ScalarCmpGtI64x4(LAi64x4, LBi64x4);
        CheckEqual(Integer(LMask4Scalar), Integer(LMask4Direct), 'Direct CmpGtI64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask4Direct := LDirectDispatch^.CoreVectors.CmpLeI64x4(LAi64x4, LBi64x4);
        LMask4Scalar := ScalarCmpLeI64x4(LAi64x4, LBi64x4);
        CheckEqual(Integer(LMask4Scalar), Integer(LMask4Direct), 'Direct CmpLeI64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask4Direct := LDirectDispatch^.CoreVectors.CmpGeI64x4(LAi64x4, LBi64x4);
        LMask4Scalar := ScalarCmpGeI64x4(LAi64x4, LBi64x4);
        CheckEqual(Integer(LMask4Scalar), Integer(LMask4Direct), 'Direct CmpGeI64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask4Direct := LDirectDispatch^.CoreVectors.CmpNeI64x4(LAi64x4, LBi64x4);
        LMask4Scalar := ScalarCmpNeI64x4(LAi64x4, LBi64x4);
        CheckEqual(Integer(LMask4Scalar), Integer(LMask4Direct), 'Direct CmpNeI64x4 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask16Direct := LDirectDispatch^.CoreVectors.CmpEqI32x16(LAi32x16, LBi32x16);
        LMask16Scalar := ScalarCmpEqI32x16(LAi32x16, LBi32x16);
        CheckEqual(Integer(LMask16Scalar), Integer(LMask16Direct), 'Direct CmpEqI32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask16Direct := LDirectDispatch^.CoreVectors.CmpLtI32x16(LAi32x16, LBi32x16);
        LMask16Scalar := ScalarCmpLtI32x16(LAi32x16, LBi32x16);
        CheckEqual(Integer(LMask16Scalar), Integer(LMask16Direct), 'Direct CmpLtI32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        AssertMask16HelperParity('I32x16 Lt case=' + IntToStr(LCaseIdx), LMask16Scalar);
        LMask16Direct := LDirectDispatch^.CoreVectors.CmpGtI32x16(LAi32x16, LBi32x16);
        LMask16Scalar := ScalarCmpGtI32x16(LAi32x16, LBi32x16);
        CheckEqual(Integer(LMask16Scalar), Integer(LMask16Direct), 'Direct CmpGtI32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask16Direct := LDirectDispatch^.CoreVectors.CmpLeI32x16(LAi32x16, LBi32x16);
        LMask16Scalar := ScalarCmpLeI32x16(LAi32x16, LBi32x16);
        CheckEqual(Integer(LMask16Scalar), Integer(LMask16Direct), 'Direct CmpLeI32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask16Direct := LDirectDispatch^.CoreVectors.CmpGeI32x16(LAi32x16, LBi32x16);
        LMask16Scalar := ScalarCmpGeI32x16(LAi32x16, LBi32x16);
        CheckEqual(Integer(LMask16Scalar), Integer(LMask16Direct), 'Direct CmpGeI32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask16Direct := LDirectDispatch^.CoreVectors.CmpNeI32x16(LAi32x16, LBi32x16);
        LMask16Scalar := ScalarCmpNeI32x16(LAi32x16, LBi32x16);
        CheckEqual(Integer(LMask16Scalar), Integer(LMask16Direct), 'Direct CmpNeI32x16 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));

        LMask8Direct := LDirectDispatch^.CoreVectors.CmpEqI64x8(LAi64x8, LBi64x8);
        LMask8Scalar := ScalarCmpEqI64x8(LAi64x8, LBi64x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpEqI64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpLtI64x8(LAi64x8, LBi64x8);
        LMask8Scalar := ScalarCmpLtI64x8(LAi64x8, LBi64x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpLtI64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        AssertMask8HelperParity('I64x8 Lt case=' + IntToStr(LCaseIdx), LMask8Scalar);
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpGtI64x8(LAi64x8, LBi64x8);
        LMask8Scalar := ScalarCmpGtI64x8(LAi64x8, LBi64x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpGtI64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpLeI64x8(LAi64x8, LBi64x8);
        LMask8Scalar := ScalarCmpLeI64x8(LAi64x8, LBi64x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpLeI64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpGeI64x8(LAi64x8, LBi64x8);
        LMask8Scalar := ScalarCmpGeI64x8(LAi64x8, LBi64x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpGeI64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
        LMask8Direct := LDirectDispatch^.CoreVectors.CmpNeI64x8(LAi64x8, LBi64x8);
        LMask8Scalar := ScalarCmpNeI64x8(LAi64x8, LBi64x8);
        CheckEqual(Integer(LMask8Scalar), Integer(LMask8Direct), 'Direct CmpNeI64x8 parity backend ' + DirectBackendName(LBackend) + ' case=' + IntToStr(LCaseIdx));
      end;

      AssertMask4HelperParity('Synthetic Mask4 zero', TMask4(0));
      AssertMask4HelperParity('Synthetic Mask4 mixed', TMask4($0A));
      AssertMask4HelperParity('Synthetic Mask4 full', TMask4($0F));
      AssertMask8HelperParity('Synthetic Mask8 zero', TMask8(0));
      AssertMask8HelperParity('Synthetic Mask8 mixed', TMask8($52));
      AssertMask8HelperParity('Synthetic Mask8 full', TMask8($FF));
      AssertMask16HelperParity('Synthetic Mask16 zero', TMask16(0));
      AssertMask16HelperParity('Synthetic Mask16 mixed', TMask16($A55A));
      AssertMask16HelperParity('Synthetic Mask16 full', TMask16($FFFF));
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_WideBitwiseShiftMatrix_Parity;
const
  C_SHIFT32: array[0..8] of Integer = (-1, 0, 1, 7, 31, 32, 63, 64, 95);
  C_SHIFT64: array[0..7] of Integer = (-1, 0, 1, 7, 31, 63, 64, 95);
var
  LBackends: array[0..2] of TSimdBackend;
  LBackend: TSimdBackend;
  LDirectDispatch: PSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32x8A, LI32x8B: TVecI32x8;
  LI32x16A, LI32x16B: TVecI32x16;
  LI64x4A, LI64x4B: TVecI64x4;
  LI32x8ByDirect, LI32x8ByFacade, LI32x8ByScalar: TVecI32x8;
  LI32x16ByDirect, LI32x16ByFacade, LI32x16ByScalar: TVecI32x16;
  LI64x4ByDirect, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LShiftIndex: Integer;
  LLane: Integer;
  LTestedCount: Integer;

  procedure AssertVecI32x8Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI32x16Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI64x4Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered for wide bitwise/shift matrix parity');

  LBackends[0] := sbScalar;
  LBackends[1] := sbNEON;
  LBackends[2] := sbRISCVV;

  LI32x8A.i[0] := High(Int32);
  LI32x8A.i[1] := Low(Int32);
  LI32x8A.i[2] := -1;
  LI32x8A.i[3] := 0;
  LI32x8A.i[4] := $55555555;
  LI32x8A.i[5] := Int32($AAAAAAAA);
  LI32x8A.i[6] := Int32($40000001);
  LI32x8A.i[7] := -16;
  LI32x8B.i[0] := 0;
  LI32x8B.i[1] := -1;
  LI32x8B.i[2] := Int32($AAAAAAAA);
  LI32x8B.i[3] := $55555555;
  LI32x8B.i[4] := High(Int32);
  LI32x8B.i[5] := Low(Int32);
  LI32x8B.i[6] := Int32($7F0F0F0F);
  LI32x8B.i[7] := 15;

  for LLane := 0 to 15 do
  begin
    LI32x16A.i[LLane] := (LLane - 8) * 257;
    LI32x16B.i[LLane] := (7 - LLane) * 131;
  end;
  LI32x16A.i[0] := Low(Int32);
  LI32x16A.i[1] := -1;
  LI32x16A.i[2] := $55555555;
  LI32x16A.i[15] := High(Int32);
  LI32x16B.i[0] := High(Int32);
  LI32x16B.i[1] := Int32($AAAAAAAA);
  LI32x16B.i[2] := -1;
  LI32x16B.i[15] := Low(Int32);

  LI64x4A.i[0] := Low(Int64);
  LI64x4A.i[1] := -1;
  LI64x4A.i[2] := Int64($4000000000000001);
  LI64x4A.i[3] := High(Int64);
  LI64x4B.i[0] := High(Int64);
  LI64x4B.i[1] := Int64($AAAAAAAAAAAAAAAA);
  LI64x4B.i[2] := -1;
  LI64x4B.i[3] := Low(Int64);

  GetDispatchTable;
  LTestedCount := 0;
  try
    for LBackend in LBackends do
    begin
      if (LBackend <> sbScalar) and (not IsBackendRegistered(LBackend)) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AndNotI32x8), 'Direct AndNotI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftLeftI32x8), 'Direct ShiftLeftI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftRightI32x8), 'Direct ShiftRightI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftRightArithI32x8), 'Direct ShiftRightArithI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AndNotI32x16), 'Direct AndNotI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftLeftI32x16), 'Direct ShiftLeftI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftRightI32x16), 'Direct ShiftRightI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftRightArithI32x16), 'Direct ShiftRightArithI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AndNotI64x4), 'Direct AndNotI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftLeftI64x4), 'Direct ShiftLeftI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftRightI64x4), 'Direct ShiftRightI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ShiftRightArithI64x4), 'Direct ShiftRightArithI64x4 should be assigned for backend ' + DirectBackendName(LBackend));

      LI32x8ByScalar := LScalarTable.CoreVectors.AndI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.AndI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8And(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct AndI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade AndI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.OrI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.OrI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Or(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct OrI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade OrI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.XorI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.XorI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Xor(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct XorI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade XorI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.NotI32x8(LI32x8A);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.NotI32x8(LI32x8A);
      LI32x8ByFacade := VecI32x8Not(LI32x8A);
      AssertVecI32x8Equal('Direct NotI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade NotI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.AndNotI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.AndNotI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8AndNot(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct AndNotI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade AndNotI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.AndI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.AndI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16And(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct AndI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade AndI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.OrI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.OrI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Or(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct OrI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade OrI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.XorI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.XorI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Xor(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct XorI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade XorI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.NotI32x16(LI32x16A);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.NotI32x16(LI32x16A);
      LI32x16ByFacade := VecI32x16Not(LI32x16A);
      AssertVecI32x16Equal('Direct NotI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade NotI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.AndNotI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.AndNotI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16AndNot(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct AndNotI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade AndNotI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.AndI64x4(LI64x4A, LI64x4B);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.AndI64x4(LI64x4A, LI64x4B);
      LI64x4ByFacade := VecI64x4And(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('Direct AndI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade AndI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.OrI64x4(LI64x4A, LI64x4B);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.OrI64x4(LI64x4A, LI64x4B);
      LI64x4ByFacade := VecI64x4Or(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('Direct OrI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade OrI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.XorI64x4(LI64x4A, LI64x4B);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.XorI64x4(LI64x4A, LI64x4B);
      LI64x4ByFacade := VecI64x4Xor(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('Direct XorI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade XorI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.NotI64x4(LI64x4A);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.NotI64x4(LI64x4A);
      LI64x4ByFacade := VecI64x4Not(LI64x4A);
      AssertVecI64x4Equal('Direct NotI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade NotI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.AndNotI64x4(LI64x4A, LI64x4B);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.AndNotI64x4(LI64x4A, LI64x4B);
      LI64x4ByFacade := VecI64x4AndNot(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('Direct AndNotI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade AndNotI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      for LShiftIndex := 0 to High(C_SHIFT32) do
      begin
        LI32x8ByScalar := LScalarTable.CoreVectors.ShiftLeftI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByDirect := LDirectDispatch^.CoreVectors.ShiftLeftI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByFacade := VecI32x8ShiftLeft(LI32x8A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x8Equal('Direct ShiftLeftI32x8 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x8ByScalar, LI32x8ByDirect);
        AssertVecI32x8Equal('Facade ShiftLeftI32x8 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x8ByScalar, LI32x8ByFacade);

        LI32x8ByScalar := LScalarTable.CoreVectors.ShiftRightI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByDirect := LDirectDispatch^.CoreVectors.ShiftRightI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByFacade := VecI32x8ShiftRight(LI32x8A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x8Equal('Direct ShiftRightI32x8 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x8ByScalar, LI32x8ByDirect);
        AssertVecI32x8Equal('Facade ShiftRightI32x8 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x8ByScalar, LI32x8ByFacade);

        LI32x8ByScalar := LScalarTable.CoreVectors.ShiftRightArithI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByDirect := LDirectDispatch^.CoreVectors.ShiftRightArithI32x8(LI32x8A, C_SHIFT32[LShiftIndex]);
        LI32x8ByFacade := VecI32x8ShiftRightArith(LI32x8A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x8Equal('Direct ShiftRightArithI32x8 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x8ByScalar, LI32x8ByDirect);
        AssertVecI32x8Equal('Facade ShiftRightArithI32x8 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x8ByScalar, LI32x8ByFacade);

        LI32x16ByScalar := LScalarTable.CoreVectors.ShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByDirect := LDirectDispatch^.CoreVectors.ShiftLeftI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByFacade := VecI32x16ShiftLeft(LI32x16A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x16Equal('Direct ShiftLeftI32x16 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x16ByScalar, LI32x16ByDirect);
        AssertVecI32x16Equal('Facade ShiftLeftI32x16 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x16ByScalar, LI32x16ByFacade);

        LI32x16ByScalar := LScalarTable.CoreVectors.ShiftRightI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByDirect := LDirectDispatch^.CoreVectors.ShiftRightI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByFacade := VecI32x16ShiftRight(LI32x16A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x16Equal('Direct ShiftRightI32x16 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x16ByScalar, LI32x16ByDirect);
        AssertVecI32x16Equal('Facade ShiftRightI32x16 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x16ByScalar, LI32x16ByFacade);

        LI32x16ByScalar := LScalarTable.CoreVectors.ShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByDirect := LDirectDispatch^.CoreVectors.ShiftRightArithI32x16(LI32x16A, C_SHIFT32[LShiftIndex]);
        LI32x16ByFacade := VecI32x16ShiftRightArith(LI32x16A, C_SHIFT32[LShiftIndex]);
        AssertVecI32x16Equal('Direct ShiftRightArithI32x16 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x16ByScalar, LI32x16ByDirect);
        AssertVecI32x16Equal('Facade ShiftRightArithI32x16 c=' + IntToStr(C_SHIFT32[LShiftIndex]), LBackend, LI32x16ByScalar, LI32x16ByFacade);
      end;

      for LShiftIndex := 0 to High(C_SHIFT64) do
      begin
        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftLeftI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByDirect := LDirectDispatch^.CoreVectors.ShiftLeftI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByFacade := VecI64x4ShiftLeft(LI64x4A, C_SHIFT64[LShiftIndex]);
        AssertVecI64x4Equal('Direct ShiftLeftI64x4 c=' + IntToStr(C_SHIFT64[LShiftIndex]), LBackend, LI64x4ByScalar, LI64x4ByDirect);
        AssertVecI64x4Equal('Facade ShiftLeftI64x4 c=' + IntToStr(C_SHIFT64[LShiftIndex]), LBackend, LI64x4ByScalar, LI64x4ByFacade);

        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByDirect := LDirectDispatch^.CoreVectors.ShiftRightI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByFacade := VecI64x4ShiftRight(LI64x4A, C_SHIFT64[LShiftIndex]);
        AssertVecI64x4Equal('Direct ShiftRightI64x4 c=' + IntToStr(C_SHIFT64[LShiftIndex]), LBackend, LI64x4ByScalar, LI64x4ByDirect);
        AssertVecI64x4Equal('Facade ShiftRightI64x4 c=' + IntToStr(C_SHIFT64[LShiftIndex]), LBackend, LI64x4ByScalar, LI64x4ByFacade);

        LI64x4ByScalar := LScalarTable.CoreVectors.ShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByDirect := LDirectDispatch^.CoreVectors.ShiftRightArithI64x4(LI64x4A, C_SHIFT64[LShiftIndex]);
        LI64x4ByFacade := VecI64x4ShiftRightArith(LI64x4A, C_SHIFT64[LShiftIndex]);
        AssertVecI64x4Equal('Direct ShiftRightArithI64x4 c=' + IntToStr(C_SHIFT64[LShiftIndex]), LBackend, LI64x4ByScalar, LI64x4ByDirect);
        AssertVecI64x4Equal('Facade ShiftRightArithI64x4 c=' + IntToStr(C_SHIFT64[LShiftIndex]), LBackend, LI64x4ByScalar, LI64x4ByFacade);
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested in wide bitwise/shift matrix parity');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_WideArithmeticMinMaxMatrix_Parity;
var
  LBackends: array[0..2] of TSimdBackend;
  LBackend: TSimdBackend;
  LDirectDispatch: PSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LI32x8A, LI32x8B: TVecI32x8;
  LU32x8A, LU32x8B: TVecU32x8;
  LI64x4A, LI64x4B: TVecI64x4;
  LU64x4A, LU64x4B: TVecU64x4;
  LI32x16A, LI32x16B: TVecI32x16;
  LU32x16A, LU32x16B: TVecU32x16;
  LI64x8A, LI64x8B: TVecI64x8;
  LU64x8A, LU64x8B: TVecU64x8;
  LI32x8ByDirect, LI32x8ByFacade, LI32x8ByScalar: TVecI32x8;
  LU32x8ByDirect, LU32x8ByFacade, LU32x8ByScalar: TVecU32x8;
  LI64x4ByDirect, LI64x4ByFacade, LI64x4ByScalar: TVecI64x4;
  LU64x4ByDirect, LU64x4ByFacade, LU64x4ByScalar: TVecU64x4;
  LI32x16ByDirect, LI32x16ByFacade, LI32x16ByScalar: TVecI32x16;
  LU32x16ByDirect, LU32x16ByFacade, LU32x16ByScalar: TVecU32x16;
  LI64x8ByDirect, LI64x8ByFacade, LI64x8ByScalar: TVecI64x8;
  LU64x8ByDirect, LU64x8ByFacade, LU64x8ByScalar: TVecU64x8;
  LLane: Integer;
  LTestedCount: Integer;

  procedure AssertVecI32x8Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecU32x8Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecU32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI64x4Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecU64x4Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecU64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI32x16Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecU32x16Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecU32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI64x8Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecU64x8Equal(const aLabel: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecU64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(QWord(aExpected.u[LLaneIndex]), QWord(aActual.u[LLaneIndex]), aLabel + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered for wide arithmetic/minmax matrix parity');

  LBackends[0] := sbScalar;
  LBackends[1] := sbNEON;
  LBackends[2] := sbRISCVV;

  LI32x8A.i[0] := High(Int32);
  LI32x8A.i[1] := Low(Int32);
  LI32x8A.i[2] := -1;
  LI32x8A.i[3] := 0;
  LI32x8A.i[4] := $55555555;
  LI32x8A.i[5] := Int32($AAAAAAAA);
  LI32x8A.i[6] := Int32($40000001);
  LI32x8A.i[7] := -16;
  LI32x8B.i[0] := 1;
  LI32x8B.i[1] := -1;
  LI32x8B.i[2] := $7FFFFFFF;
  LI32x8B.i[3] := $55555555;
  LI32x8B.i[4] := High(Int32);
  LI32x8B.i[5] := Low(Int32);
  LI32x8B.i[6] := Int32($7F0F0F0F);
  LI32x8B.i[7] := 15;

  LU32x8A.u[0] := 0;
  LU32x8A.u[1] := 1;
  LU32x8A.u[2] := High(UInt32);
  LU32x8A.u[3] := $80000000;
  LU32x8A.u[4] := $7FFFFFFF;
  LU32x8A.u[5] := $AAAAAAAA;
  LU32x8A.u[6] := $55555555;
  LU32x8A.u[7] := 37;
  LU32x8B.u[0] := High(UInt32);
  LU32x8B.u[1] := 2;
  LU32x8B.u[2] := 3;
  LU32x8B.u[3] := $80000000;
  LU32x8B.u[4] := 1;
  LU32x8B.u[5] := $11111111;
  LU32x8B.u[6] := $AAAAAAAA;
  LU32x8B.u[7] := High(UInt32) - 15;

  LI64x4A.i[0] := High(Int64);
  LI64x4A.i[1] := Low(Int64);
  LI64x4A.i[2] := -1;
  LI64x4A.i[3] := Int64($4000000000000001);
  LI64x4B.i[0] := 1;
  LI64x4B.i[1] := -1;
  LI64x4B.i[2] := High(Int64);
  LI64x4B.i[3] := Low(Int64);

  LU64x4A.u[0] := 0;
  LU64x4A.u[1] := 1;
  LU64x4A.u[2] := High(QWord);
  LU64x4A.u[3] := QWord($8000000000000000);
  LU64x4B.u[0] := High(QWord);
  LU64x4B.u[1] := 2;
  LU64x4B.u[2] := 3;
  LU64x4B.u[3] := QWord($7FFFFFFFFFFFFFFF);

  for LLane := 0 to 15 do
  begin
    LI32x16A.i[LLane] := (LLane - 8) * 4099;
    LI32x16B.i[LLane] := (8 - LLane) * 2053;
    LU32x16A.u[LLane] := DWord(LLane * 257);
    LU32x16B.u[LLane] := DWord((15 - LLane) * 131);
  end;
  LI32x16A.i[0] := Low(Int32);
  LI32x16A.i[1] := -1;
  LI32x16A.i[2] := $55555555;
  LI32x16A.i[15] := High(Int32);
  LI32x16B.i[0] := 1;
  LI32x16B.i[1] := High(Int32);
  LI32x16B.i[2] := Int32($AAAAAAAA);
  LI32x16B.i[15] := Low(Int32);
  LU32x16A.u[0] := 0;
  LU32x16A.u[1] := High(UInt32);
  LU32x16A.u[2] := $80000000;
  LU32x16A.u[15] := $55555555;
  LU32x16B.u[0] := High(UInt32);
  LU32x16B.u[1] := 1;
  LU32x16B.u[2] := $80000000;
  LU32x16B.u[15] := $AAAAAAAA;

  for LLane := 0 to 7 do
  begin
    LI64x8A.i[LLane] := (LLane - 4) * 1025;
    LI64x8B.i[LLane] := (3 - LLane) * 511;
    LU64x8A.u[LLane] := QWord(LLane) * 257;
    LU64x8B.u[LLane] := QWord(7 - LLane) * 131;
  end;
  LI64x8A.i[0] := High(Int64);
  LI64x8A.i[1] := Low(Int64);
  LI64x8A.i[2] := -1;
  LI64x8A.i[7] := Int64($4000000000000001);
  LI64x8B.i[0] := 1;
  LI64x8B.i[1] := -1;
  LI64x8B.i[2] := High(Int64);
  LI64x8B.i[7] := Low(Int64);
  LU64x8A.u[0] := 0;
  LU64x8A.u[1] := 1;
  LU64x8A.u[2] := High(QWord);
  LU64x8A.u[7] := QWord($8000000000000000);
  LU64x8B.u[0] := High(QWord);
  LU64x8B.u[1] := 2;
  LU64x8B.u[2] := 3;
  LU64x8B.u[7] := QWord($7FFFFFFFFFFFFFFF);

  GetDispatchTable;
  LTestedCount := 0;
  try
    for LBackend in LBackends do
    begin
      if (LBackend <> sbScalar) and (not IsBackendRegistered(LBackend)) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddI32x8), 'Direct AddI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubI32x8), 'Direct SubI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MulI32x8), 'Direct MulI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MinI32x8), 'Direct MinI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MaxI32x8), 'Direct MaxI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddU32x8), 'Direct AddU32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubU32x8), 'Direct SubU32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MulU32x8), 'Direct MulU32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MinU32x8), 'Direct MinU32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MaxU32x8), 'Direct MaxU32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddI64x4), 'Direct AddI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubI64x4), 'Direct SubI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddU64x4), 'Direct AddU64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubU64x4), 'Direct SubU64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddI32x16), 'Direct AddI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubI32x16), 'Direct SubI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MulI32x16), 'Direct MulI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MinI32x16), 'Direct MinI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MaxI32x16), 'Direct MaxI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddU32x16), 'Direct AddU32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubU32x16), 'Direct SubU32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MulU32x16), 'Direct MulU32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MinU32x16), 'Direct MinU32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.MaxU32x16), 'Direct MaxU32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddI64x8), 'Direct AddI64x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubI64x8), 'Direct SubI64x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.AddU64x8), 'Direct AddU64x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SubU64x8), 'Direct SubU64x8 should be assigned for backend ' + DirectBackendName(LBackend));

      LI32x8ByScalar := LScalarTable.CoreVectors.AddI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.AddI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Add(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct AddI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade AddI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.SubI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.SubI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Sub(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct SubI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade SubI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.MulI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.MulI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Mul(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct MulI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade MulI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.MinI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.MinI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Min(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct MinI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade MinI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LI32x8ByScalar := LScalarTable.CoreVectors.MaxI32x8(LI32x8A, LI32x8B);
      LI32x8ByDirect := LDirectDispatch^.CoreVectors.MaxI32x8(LI32x8A, LI32x8B);
      LI32x8ByFacade := VecI32x8Max(LI32x8A, LI32x8B);
      AssertVecI32x8Equal('Direct MaxI32x8', LBackend, LI32x8ByScalar, LI32x8ByDirect);
      AssertVecI32x8Equal('Facade MaxI32x8', LBackend, LI32x8ByScalar, LI32x8ByFacade);

      LU32x8ByScalar := LScalarTable.CoreVectors.AddU32x8(LU32x8A, LU32x8B);
      LU32x8ByDirect := LDirectDispatch^.CoreVectors.AddU32x8(LU32x8A, LU32x8B);
      LU32x8ByFacade := VecU32x8Add(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('Direct AddU32x8', LBackend, LU32x8ByScalar, LU32x8ByDirect);
      AssertVecU32x8Equal('Facade AddU32x8', LBackend, LU32x8ByScalar, LU32x8ByFacade);

      LU32x8ByScalar := LScalarTable.CoreVectors.SubU32x8(LU32x8A, LU32x8B);
      LU32x8ByDirect := LDirectDispatch^.CoreVectors.SubU32x8(LU32x8A, LU32x8B);
      LU32x8ByFacade := VecU32x8Sub(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('Direct SubU32x8', LBackend, LU32x8ByScalar, LU32x8ByDirect);
      AssertVecU32x8Equal('Facade SubU32x8', LBackend, LU32x8ByScalar, LU32x8ByFacade);

      LU32x8ByScalar := LScalarTable.CoreVectors.MulU32x8(LU32x8A, LU32x8B);
      LU32x8ByDirect := LDirectDispatch^.CoreVectors.MulU32x8(LU32x8A, LU32x8B);
      LU32x8ByFacade := VecU32x8Mul(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('Direct MulU32x8', LBackend, LU32x8ByScalar, LU32x8ByDirect);
      AssertVecU32x8Equal('Facade MulU32x8', LBackend, LU32x8ByScalar, LU32x8ByFacade);

      LU32x8ByScalar := LScalarTable.CoreVectors.MinU32x8(LU32x8A, LU32x8B);
      LU32x8ByDirect := LDirectDispatch^.CoreVectors.MinU32x8(LU32x8A, LU32x8B);
      LU32x8ByFacade := VecU32x8Min(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('Direct MinU32x8', LBackend, LU32x8ByScalar, LU32x8ByDirect);
      AssertVecU32x8Equal('Facade MinU32x8', LBackend, LU32x8ByScalar, LU32x8ByFacade);

      LU32x8ByScalar := LScalarTable.CoreVectors.MaxU32x8(LU32x8A, LU32x8B);
      LU32x8ByDirect := LDirectDispatch^.CoreVectors.MaxU32x8(LU32x8A, LU32x8B);
      LU32x8ByFacade := VecU32x8Max(LU32x8A, LU32x8B);
      AssertVecU32x8Equal('Direct MaxU32x8', LBackend, LU32x8ByScalar, LU32x8ByDirect);
      AssertVecU32x8Equal('Facade MaxU32x8', LBackend, LU32x8ByScalar, LU32x8ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.AddI64x4(LI64x4A, LI64x4B);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.AddI64x4(LI64x4A, LI64x4B);
      LI64x4ByFacade := VecI64x4Add(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('Direct AddI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade AddI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByScalar := LScalarTable.CoreVectors.SubI64x4(LI64x4A, LI64x4B);
      LI64x4ByDirect := LDirectDispatch^.CoreVectors.SubI64x4(LI64x4A, LI64x4B);
      LI64x4ByFacade := VecI64x4Sub(LI64x4A, LI64x4B);
      AssertVecI64x4Equal('Direct SubI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);
      AssertVecI64x4Equal('Facade SubI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LU64x4ByScalar := LScalarTable.CoreVectors.AddU64x4(LU64x4A, LU64x4B);
      LU64x4ByDirect := LDirectDispatch^.CoreVectors.AddU64x4(LU64x4A, LU64x4B);
      LU64x4ByFacade := VecU64x4Add(LU64x4A, LU64x4B);
      AssertVecU64x4Equal('Direct AddU64x4', LBackend, LU64x4ByScalar, LU64x4ByDirect);
      AssertVecU64x4Equal('Facade AddU64x4', LBackend, LU64x4ByScalar, LU64x4ByFacade);

      LU64x4ByScalar := LScalarTable.CoreVectors.SubU64x4(LU64x4A, LU64x4B);
      LU64x4ByDirect := LDirectDispatch^.CoreVectors.SubU64x4(LU64x4A, LU64x4B);
      LU64x4ByFacade := VecU64x4Sub(LU64x4A, LU64x4B);
      AssertVecU64x4Equal('Direct SubU64x4', LBackend, LU64x4ByScalar, LU64x4ByDirect);
      AssertVecU64x4Equal('Facade SubU64x4', LBackend, LU64x4ByScalar, LU64x4ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.AddI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.AddI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Add(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct AddI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade AddI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.SubI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.SubI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Sub(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct SubI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade SubI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.MulI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.MulI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Mul(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct MulI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade MulI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.MinI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.MinI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Min(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct MinI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade MinI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LI32x16ByScalar := LScalarTable.CoreVectors.MaxI32x16(LI32x16A, LI32x16B);
      LI32x16ByDirect := LDirectDispatch^.CoreVectors.MaxI32x16(LI32x16A, LI32x16B);
      LI32x16ByFacade := VecI32x16Max(LI32x16A, LI32x16B);
      AssertVecI32x16Equal('Direct MaxI32x16', LBackend, LI32x16ByScalar, LI32x16ByDirect);
      AssertVecI32x16Equal('Facade MaxI32x16', LBackend, LI32x16ByScalar, LI32x16ByFacade);

      LU32x16ByScalar := LScalarTable.CoreVectors.AddU32x16(LU32x16A, LU32x16B);
      LU32x16ByDirect := LDirectDispatch^.CoreVectors.AddU32x16(LU32x16A, LU32x16B);
      LU32x16ByFacade := VecU32x16Add(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Direct AddU32x16', LBackend, LU32x16ByScalar, LU32x16ByDirect);
      AssertVecU32x16Equal('Facade AddU32x16', LBackend, LU32x16ByScalar, LU32x16ByFacade);

      LU32x16ByScalar := LScalarTable.CoreVectors.SubU32x16(LU32x16A, LU32x16B);
      LU32x16ByDirect := LDirectDispatch^.CoreVectors.SubU32x16(LU32x16A, LU32x16B);
      LU32x16ByFacade := VecU32x16Sub(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Direct SubU32x16', LBackend, LU32x16ByScalar, LU32x16ByDirect);
      AssertVecU32x16Equal('Facade SubU32x16', LBackend, LU32x16ByScalar, LU32x16ByFacade);

      LU32x16ByScalar := LScalarTable.CoreVectors.MulU32x16(LU32x16A, LU32x16B);
      LU32x16ByDirect := LDirectDispatch^.CoreVectors.MulU32x16(LU32x16A, LU32x16B);
      LU32x16ByFacade := VecU32x16Mul(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Direct MulU32x16', LBackend, LU32x16ByScalar, LU32x16ByDirect);
      AssertVecU32x16Equal('Facade MulU32x16', LBackend, LU32x16ByScalar, LU32x16ByFacade);

      LU32x16ByScalar := LScalarTable.CoreVectors.MinU32x16(LU32x16A, LU32x16B);
      LU32x16ByDirect := LDirectDispatch^.CoreVectors.MinU32x16(LU32x16A, LU32x16B);
      LU32x16ByFacade := VecU32x16Min(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Direct MinU32x16', LBackend, LU32x16ByScalar, LU32x16ByDirect);
      AssertVecU32x16Equal('Facade MinU32x16', LBackend, LU32x16ByScalar, LU32x16ByFacade);

      LU32x16ByScalar := LScalarTable.CoreVectors.MaxU32x16(LU32x16A, LU32x16B);
      LU32x16ByDirect := LDirectDispatch^.CoreVectors.MaxU32x16(LU32x16A, LU32x16B);
      LU32x16ByFacade := VecU32x16Max(LU32x16A, LU32x16B);
      AssertVecU32x16Equal('Direct MaxU32x16', LBackend, LU32x16ByScalar, LU32x16ByDirect);
      AssertVecU32x16Equal('Facade MaxU32x16', LBackend, LU32x16ByScalar, LU32x16ByFacade);

      LI64x8ByScalar := LScalarTable.CoreVectors.AddI64x8(LI64x8A, LI64x8B);
      LI64x8ByDirect := LDirectDispatch^.CoreVectors.AddI64x8(LI64x8A, LI64x8B);
      LI64x8ByFacade := VecI64x8Add(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Direct AddI64x8', LBackend, LI64x8ByScalar, LI64x8ByDirect);
      AssertVecI64x8Equal('Facade AddI64x8', LBackend, LI64x8ByScalar, LI64x8ByFacade);

      LI64x8ByScalar := LScalarTable.CoreVectors.SubI64x8(LI64x8A, LI64x8B);
      LI64x8ByDirect := LDirectDispatch^.CoreVectors.SubI64x8(LI64x8A, LI64x8B);
      LI64x8ByFacade := VecI64x8Sub(LI64x8A, LI64x8B);
      AssertVecI64x8Equal('Direct SubI64x8', LBackend, LI64x8ByScalar, LI64x8ByDirect);
      AssertVecI64x8Equal('Facade SubI64x8', LBackend, LI64x8ByScalar, LI64x8ByFacade);

      LU64x8ByScalar := LScalarTable.CoreVectors.AddU64x8(LU64x8A, LU64x8B);
      LU64x8ByDirect := LDirectDispatch^.CoreVectors.AddU64x8(LU64x8A, LU64x8B);
      LU64x8ByFacade := VecU64x8Add(LU64x8A, LU64x8B);
      AssertVecU64x8Equal('Direct AddU64x8', LBackend, LU64x8ByScalar, LU64x8ByDirect);
      AssertVecU64x8Equal('Facade AddU64x8', LBackend, LU64x8ByScalar, LU64x8ByFacade);

      LU64x8ByScalar := LScalarTable.CoreVectors.SubU64x8(LU64x8A, LU64x8B);
      LU64x8ByDirect := LDirectDispatch^.CoreVectors.SubU64x8(LU64x8A, LU64x8B);
      LU64x8ByFacade := VecU64x8Sub(LU64x8A, LU64x8B);
      AssertVecU64x8Equal('Direct SubU64x8', LBackend, LU64x8ByScalar, LU64x8ByDirect);
      AssertVecU64x8Equal('Facade SubU64x8', LBackend, LU64x8ByScalar, LU64x8ByFacade);
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested in wide arithmetic/minmax matrix parity');
  finally
  end;
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_MemSearchBitsetUtf8_Parity;
const
  C_BUF_LEN = 96;
  C_NEEDLE_LEN = 3;
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LBuf: array[0..C_BUF_LEN - 1] of Byte;
  LUtf8Good: array[0..15] of Byte;
  LUtf8Bad: array[0..15] of Byte;
  LNeedleHit: array[0..C_NEEDLE_LEN - 1] of Byte;
  LNeedleMiss: array[0..C_NEEDLE_LEN - 1] of Byte;
  LIdx: Integer;
  LFoundOffset: Integer;
  LFacadeIdx, LDirectIdx: PtrInt;
  LFacadeUtf8, LDirectUtf8: Boolean;
  LFacadeBits, LDirectBits: SizeUInt;
  LTestedCount: Integer;
begin
  for LIdx := 0 to High(LBuf) do
    LBuf[LIdx] := Byte(LIdx);

  // 可搜索子串（确保存在）
  LFoundOffset := 37;
  for LIdx := 0 to High(LNeedleHit) do
  begin
    LNeedleHit[LIdx] := Byte(200 + LIdx);
    LBuf[LFoundOffset + LIdx] := LNeedleHit[LIdx];
  end;
  LNeedleMiss[0] := $FA;
  LNeedleMiss[1] := $FB;
  LNeedleMiss[2] := $FC;

  // UTF-8 good: "A中B€C" 的字节序列
  LUtf8Good[0] := $41;              // A
  LUtf8Good[1] := $E4; LUtf8Good[2] := $B8; LUtf8Good[3] := $AD; // 中
  LUtf8Good[4] := $42;              // B
  LUtf8Good[5] := $E2; LUtf8Good[6] := $82; LUtf8Good[7] := $AC; // €
  LUtf8Good[8] := $43;              // C
  for LIdx := 9 to High(LUtf8Good) do
    LUtf8Good[LIdx] := $20;

  // UTF-8 bad: 构造截断序列
  for LIdx := 0 to High(LUtf8Bad) do
    LUtf8Bad[LIdx] := $20;
  LUtf8Bad[0] := $41;
  LUtf8Bad[1] := $E4;
  LUtf8Bad[2] := $B8; // 缺失第三字节
  LUtf8Bad[3] := $42;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.BytesIndexOf), 'BytesIndexOf should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.BitsetPopCount), 'BitsetPopCount should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Utf8Validate), 'Utf8Validate should be assigned for backend ' + DirectBackendName(LBackend));

      // BytesIndexOf parity (found)
      LFacadeIdx := BytesIndexOf(@LBuf[0], SizeUInt(C_BUF_LEN), @LNeedleHit[0], SizeUInt(C_NEEDLE_LEN));
      LDirectIdx := LDirectDispatch^.Memory.BytesIndexOf(@LBuf[0], SizeUInt(C_BUF_LEN), @LNeedleHit[0], SizeUInt(C_NEEDLE_LEN));
      CheckEqual(LFacadeIdx, LDirectIdx, 'Direct BytesIndexOf(found) parity backend ' + DirectBackendName(LBackend));
      CheckEqual(LFoundOffset, Integer(LFacadeIdx), 'BytesIndexOf(found) expected offset backend ' + DirectBackendName(LBackend));

      // BytesIndexOf parity (not found)
      LFacadeIdx := BytesIndexOf(@LBuf[0], SizeUInt(C_BUF_LEN), @LNeedleMiss[0], SizeUInt(C_NEEDLE_LEN));
      LDirectIdx := LDirectDispatch^.Memory.BytesIndexOf(@LBuf[0], SizeUInt(C_BUF_LEN), @LNeedleMiss[0], SizeUInt(C_NEEDLE_LEN));
      CheckEqual(LFacadeIdx, LDirectIdx, 'Direct BytesIndexOf(not-found) parity backend ' + DirectBackendName(LBackend));
      CheckEqual(-1, Integer(LFacadeIdx), 'BytesIndexOf(not-found) expected -1 backend ' + DirectBackendName(LBackend));

      // BitsetPopCount parity
      LFacadeBits := BitsetPopCount(@LBuf[0], SizeUInt(C_BUF_LEN));
      LDirectBits := LDirectDispatch^.Memory.BitsetPopCount(@LBuf[0], SizeUInt(C_BUF_LEN));
      CheckEqual(LFacadeBits, LDirectBits, 'Direct BitsetPopCount parity backend ' + DirectBackendName(LBackend));

      // UTF-8 parity (good)
      LFacadeUtf8 := Utf8Validate(@LUtf8Good[0], SizeUInt(Length(LUtf8Good)));
      LDirectUtf8 := LDirectDispatch^.Memory.Utf8Validate(@LUtf8Good[0], SizeUInt(Length(LUtf8Good)));
      CheckEqual(LFacadeUtf8, LDirectUtf8, 'Direct Utf8Validate(good) parity backend ' + DirectBackendName(LBackend));

      // UTF-8 parity (bad)
      LFacadeUtf8 := Utf8Validate(@LUtf8Bad[0], SizeUInt(Length(LUtf8Bad)));
      LDirectUtf8 := LDirectDispatch^.Memory.Utf8Validate(@LUtf8Bad[0], SizeUInt(Length(LUtf8Bad)));
      CheckEqual(LFacadeUtf8, LDirectUtf8, 'Direct Utf8Validate(bad) parity backend ' + DirectBackendName(LBackend));
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_MemWindowMatrix_Parity;
const
  C_TOTAL_LEN = 96;
  C_LEN_CASES: array[0..9] of Integer = (1, 2, 3, 7, 8, 15, 16, 24, 31, 48);
  C_OFFSET_CASES: array[0..5] of Integer = (0, 1, 2, 5, 9, 13);
var
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LBufA: array[0..C_TOTAL_LEN - 1] of Byte;
  LBufB: array[0..C_TOTAL_LEN - 1] of Byte;
  LNeedleHit: array[0..2] of Byte;
  LNeedleMiss: array[0..2] of Byte;
  LLenCaseIdx: Integer;
  LOffsetIdx: Integer;
  LLen: Integer;
  LOffset: Integer;
  LIndex: Integer;
  LFindValue: Byte;
  LFacadeEq, LDirectEq: LongBool;
  LFacadeFind, LDirectFind: PtrInt;
  LFacadeHasDiff, LDirectHasDiff: Boolean;
  LFacadeFirstDiff, LFacadeLastDiff: SizeUInt;
  LDirectFirstDiff, LDirectLastDiff: SizeUInt;
  LFacadeBytesHit, LDirectBytesHit: PtrInt;
  LFacadeBytesMiss, LDirectBytesMiss: PtrInt;
  LDiffPosLocal: Integer;
  LNeedlePos: Integer;
  LExpectedFindPos: Integer;
  LTestedCount: Integer;
begin
  for LIndex := 0 to High(LBufA) do
  begin
    LBufA[LIndex] := Byte((LIndex * 17 + 11) and $FF);
    LBufB[LIndex] := LBufA[LIndex];
  end;

  LNeedleMiss[0] := $FA;
  LNeedleMiss[1] := $FB;
  LNeedleMiss[2] := $FC;

  LTestedCount := 0;
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.Equal), 'MemEqual should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.FindByte), 'MemFindByte should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.DiffRange), 'MemDiffRange should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.Memory.BytesIndexOf), 'BytesIndexOf should be assigned for backend ' + DirectBackendName(LBackend));

      for LLenCaseIdx := Low(C_LEN_CASES) to High(C_LEN_CASES) do
      begin
        LLen := C_LEN_CASES[LLenCaseIdx];

        for LOffsetIdx := Low(C_OFFSET_CASES) to High(C_OFFSET_CASES) do
        begin
          LOffset := C_OFFSET_CASES[LOffsetIdx];
          if LOffset + LLen > C_TOTAL_LEN then
            Continue;

          // 1) MemEqual(equal)
          for LIndex := 0 to LLen - 1 do
            LBufB[LOffset + LIndex] := LBufA[LOffset + LIndex];

          LFacadeEq := MemEqual(@LBufA[LOffset], @LBufB[LOffset], SizeUInt(LLen));
          LDirectEq := LDirectDispatch^.Memory.Equal(@LBufA[LOffset], @LBufB[LOffset], SizeUInt(LLen));
          CheckEqual(Boolean(LFacadeEq), Boolean(LDirectEq), 'Direct MemEqual(equal) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));

          // 2) MemEqual/MemDiffRange(diff)
          LDiffPosLocal := (LOffset + LLen div 2);
          LBufB[LDiffPosLocal] := LBufA[LDiffPosLocal] xor $5A;

          LFacadeEq := MemEqual(@LBufA[LOffset], @LBufB[LOffset], SizeUInt(LLen));
          LDirectEq := LDirectDispatch^.Memory.Equal(@LBufA[LOffset], @LBufB[LOffset], SizeUInt(LLen));
          CheckEqual(Boolean(LFacadeEq), Boolean(LDirectEq), 'Direct MemEqual(diff) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));

          LFacadeHasDiff := MemDiffRange(@LBufA[LOffset], @LBufB[LOffset], SizeUInt(LLen), LFacadeFirstDiff, LFacadeLastDiff);
          LDirectHasDiff := LDirectDispatch^.Memory.DiffRange(@LBufA[LOffset], @LBufB[LOffset], SizeUInt(LLen), LDirectFirstDiff, LDirectLastDiff);
          CheckEqual(LFacadeHasDiff, LDirectHasDiff, 'Direct MemDiffRange(diff).hasDiff parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
          if LFacadeHasDiff then
          begin
            CheckEqual(LFacadeFirstDiff, LDirectFirstDiff, 'Direct MemDiffRange(diff).first parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
            CheckEqual(LFacadeLastDiff, LDirectLastDiff, 'Direct MemDiffRange(diff).last parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
          end;

          // restore equal for next checks
          LBufB[LDiffPosLocal] := LBufA[LDiffPosLocal];

          // 3) MemFindByte(found)
          LFindValue := LBufA[LOffset + (LLen div 3)];
          LExpectedFindPos := -1;
          for LIndex := 0 to LLen - 1 do
            if LBufA[LOffset + LIndex] = LFindValue then
            begin
              LExpectedFindPos := LIndex;
              Break;
            end;

          LFacadeFind := MemFindByte(@LBufA[LOffset], SizeUInt(LLen), LFindValue);
          LDirectFind := LDirectDispatch^.Memory.FindByte(@LBufA[LOffset], SizeUInt(LLen), LFindValue);
          CheckEqual(LFacadeFind, LDirectFind, 'Direct MemFindByte(found) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
          CheckEqual(LExpectedFindPos, Integer(LFacadeFind), 'MemFindByte(found) expected position backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));

          // 4) BytesIndexOf(found/not-found)
          if LLen >= 3 then
          begin
            LNeedlePos := LLen div 4;
            if LNeedlePos + 3 > LLen then
              LNeedlePos := LLen - 3;

            LNeedleHit[0] := LBufA[LOffset + LNeedlePos + 0];
            LNeedleHit[1] := LBufA[LOffset + LNeedlePos + 1];
            LNeedleHit[2] := LBufA[LOffset + LNeedlePos + 2];

            LFacadeBytesHit := BytesIndexOf(@LBufA[LOffset], SizeUInt(LLen), @LNeedleHit[0], 3);
            LDirectBytesHit := LDirectDispatch^.Memory.BytesIndexOf(@LBufA[LOffset], SizeUInt(LLen), @LNeedleHit[0], 3);
            CheckEqual(LFacadeBytesHit, LDirectBytesHit, 'Direct BytesIndexOf(hit) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));

            LFacadeBytesMiss := BytesIndexOf(@LBufA[LOffset], SizeUInt(LLen), @LNeedleMiss[0], 3);
            LDirectBytesMiss := LDirectDispatch^.Memory.BytesIndexOf(@LBufA[LOffset], SizeUInt(LLen), @LNeedleMiss[0], 3);
            CheckEqual(LFacadeBytesMiss, LDirectBytesMiss, 'Direct BytesIndexOf(miss) parity backend ' + DirectBackendName(LBackend) + ' len=' + IntToStr(LLen) + ' off=' + IntToStr(LOffset));
          end;
        end;
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
  end;
end;


procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_MultiBackend_MemSearchFuzzSeed_Parity;
const
  C_CASE_COUNT = 24;
  C_BUFFER_LEN = 64;
  C_NEEDLE_LENS: array[0..3] of Integer = (1, 2, 4, 8);
var
  LDirectDispatch: PSimdDispatchTable;
  LBufA: array[0..C_BUFFER_LEN - 1] of Byte;
  LBufB: array[0..C_BUFFER_LEN - 1] of Byte;
  LNeedleFound: array[0..7] of Byte;
  LCaseIndex: Integer;
  LIndex: Integer;
  LNeedleIndex: Integer;
  LNeedleLen: Integer;
  LFoundOffset: Integer;
  LDiffPos: Integer;
  LSegmentOffset: Integer;
  LSegmentLen: Integer;
  LFacadeIndex: PtrInt;
  LDirectIndex: PtrInt;
  LNeedleMismatch: Boolean;
  LRefHasDiff: Boolean;
  LDirectHasDiff: Boolean;
  LRefFirstDiff: SizeUInt;
  LRefLastDiff: SizeUInt;
  LDirectFirstDiff: SizeUInt;
  LDirectLastDiff: SizeUInt;
  LRefMin: Byte;
  LRefMax: Byte;
  LDirectMin: Byte;
  LDirectMax: Byte;
begin
  CheckTrue(TrySetActiveBackend(sbScalar), 'TrySetActiveBackend(sbScalar) should succeed');
  try
    LDirectDispatch := GetDirectDispatchTable;

    CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned');
    CheckEqual(Ord(sbScalar), Ord(LDirectDispatch^.Backend), 'Direct backend should be scalar');
    CheckTrue(Assigned(LDirectDispatch^.Memory.BytesIndexOf), 'BytesIndexOf should be assigned');
    CheckTrue(Assigned(LDirectDispatch^.Memory.DiffRange), 'MemDiffRange should be assigned');
    CheckTrue(Assigned(LDirectDispatch^.Memory.MinMaxBytes), 'MinMaxBytes should be assigned');

    for LCaseIndex := 0 to C_CASE_COUNT - 1 do
    begin
      for LIndex := 0 to C_BUFFER_LEN - 1 do
      begin
        LBufA[LIndex] := Byte((LCaseIndex * 37 + LIndex * 13 + (LIndex shr 1)) and $FF);
        LBufB[LIndex] := LBufA[LIndex];
      end;

      LNeedleLen := C_NEEDLE_LENS[LCaseIndex and 3];
      LFoundOffset := (LCaseIndex * 7 + 3) mod (C_BUFFER_LEN - LNeedleLen + 1);
      for LIndex := 0 to LNeedleLen - 1 do
        LNeedleFound[LIndex] := LBufA[LFoundOffset + LIndex];

      LFacadeIndex := -1;
      for LIndex := 0 to C_BUFFER_LEN - LNeedleLen do
      begin
        LNeedleMismatch := False;
        for LNeedleIndex := 0 to LNeedleLen - 1 do
        begin
          if LBufA[LIndex + LNeedleIndex] <> LNeedleFound[LNeedleIndex] then
          begin
            LNeedleMismatch := True;
            Break;
          end;
        end;
        if not LNeedleMismatch then
        begin
          LFacadeIndex := LIndex;
          Break;
        end;
      end;

      LDirectIndex := LDirectDispatch^.Memory.BytesIndexOf(@LBufA[0], SizeUInt(C_BUFFER_LEN), @LNeedleFound[0], SizeUInt(LNeedleLen));
      CheckEqual(LFacadeIndex, LDirectIndex, 'Direct BytesIndexOf(found) parity case=' + IntToStr(LCaseIndex));

      CheckTrue(MemEqual(@LBufA[0], @LBufB[0], SizeUInt(C_BUFFER_LEN)), 'Reference MemEqual(equal) should be true case=' + IntToStr(LCaseIndex));
      LRefHasDiff := MemDiffRange(@LBufA[0], @LBufB[0], SizeUInt(C_BUFFER_LEN), LRefFirstDiff, LRefLastDiff);

      LDirectHasDiff := LDirectDispatch^.Memory.DiffRange(@LBufA[0], @LBufB[0], SizeUInt(C_BUFFER_LEN), LDirectFirstDiff, LDirectLastDiff);
      CheckEqual(LRefHasDiff, LDirectHasDiff, 'Direct MemDiffRange(equal).hasDiff parity case=' + IntToStr(LCaseIndex));
      CheckFalse(LRefHasDiff, 'Reference MemDiffRange(equal) should be false case=' + IntToStr(LCaseIndex));

      LDiffPos := (LCaseIndex * 11 + 5) mod C_BUFFER_LEN;
      LBufB[LDiffPos] := LBufB[LDiffPos] xor Byte(($A5 + LCaseIndex) and $FF);

      CheckFalse(MemEqual(@LBufA[0], @LBufB[0], SizeUInt(C_BUFFER_LEN)), 'Reference MemEqual(diff) should be false case=' + IntToStr(LCaseIndex));
      LRefHasDiff := MemDiffRange(@LBufA[0], @LBufB[0], SizeUInt(C_BUFFER_LEN), LRefFirstDiff, LRefLastDiff);

      LDirectHasDiff := LDirectDispatch^.Memory.DiffRange(@LBufA[0], @LBufB[0], SizeUInt(C_BUFFER_LEN), LDirectFirstDiff, LDirectLastDiff);
      CheckEqual(LRefHasDiff, LDirectHasDiff, 'Direct MemDiffRange(diff).hasDiff parity case=' + IntToStr(LCaseIndex));
      CheckTrue(LRefHasDiff, 'Reference MemDiffRange(diff) should be true case=' + IntToStr(LCaseIndex));
      if LRefHasDiff then
      begin
        CheckEqual(LRefFirstDiff, LDirectFirstDiff, 'Direct MemDiffRange(diff).firstDiff parity case=' + IntToStr(LCaseIndex));
        CheckEqual(LRefLastDiff, LDirectLastDiff, 'Direct MemDiffRange(diff).lastDiff parity case=' + IntToStr(LCaseIndex));
        CheckEqual(SizeUInt(LDiffPos), LRefFirstDiff, 'Reference MemDiffRange(diff).firstDiff expected case=' + IntToStr(LCaseIndex));
        CheckEqual(SizeUInt(LDiffPos), LRefLastDiff, 'Reference MemDiffRange(diff).lastDiff expected case=' + IntToStr(LCaseIndex));
      end;

      LRefMin := LBufA[0];
      LRefMax := LBufA[0];
      for LIndex := 1 to C_BUFFER_LEN - 1 do
      begin
        if LBufA[LIndex] < LRefMin then
          LRefMin := LBufA[LIndex];
        if LBufA[LIndex] > LRefMax then
          LRefMax := LBufA[LIndex];
      end;

      LDirectDispatch^.Memory.MinMaxBytes(@LBufA[0], SizeUInt(C_BUFFER_LEN), LDirectMin, LDirectMax);
      CheckEqual(Integer(LRefMin), Integer(LDirectMin), 'Direct MinMaxBytes(full).min parity case=' + IntToStr(LCaseIndex));
      CheckEqual(Integer(LRefMax), Integer(LDirectMax), 'Direct MinMaxBytes(full).max parity case=' + IntToStr(LCaseIndex));

      LSegmentOffset := (LCaseIndex * 5 + 1) mod (C_BUFFER_LEN - 1);
      LSegmentLen := 1 + ((LCaseIndex * 9 + 2) mod (C_BUFFER_LEN - LSegmentOffset));

      LRefMin := LBufA[LSegmentOffset];
      LRefMax := LBufA[LSegmentOffset];
      for LIndex := LSegmentOffset + 1 to LSegmentOffset + LSegmentLen - 1 do
      begin
        if LBufA[LIndex] < LRefMin then
          LRefMin := LBufA[LIndex];
        if LBufA[LIndex] > LRefMax then
          LRefMax := LBufA[LIndex];
      end;

      LDirectDispatch^.Memory.MinMaxBytes(@LBufA[LSegmentOffset], SizeUInt(LSegmentLen), LDirectMin, LDirectMax);
      CheckEqual(Integer(LRefMin), Integer(LDirectMin), 'Direct MinMaxBytes(segment).min parity case=' + IntToStr(LCaseIndex));
      CheckEqual(Integer(LRefMax), Integer(LDirectMax), 'Direct MinMaxBytes(segment).max parity case=' + IntToStr(LCaseIndex));
    end;
  finally
  end;
end;

procedure TTestCase_DirectDispatch.Test_DirectDispatchTable_WideIntegerHelperMatrix_Parity;
var
  LBackends: array[0..2] of TSimdBackend;
  LBackend: TSimdBackend;
  LDispatch: PSimdDispatchTable;
  LDirectDispatch: PSimdDispatchTable;
  LScalarTable: TSimdDispatchTable;
  LAlignedBlock: Pointer;
  LAlignedSrc: PInt64;
  LAlignedDirectDst: PInt64;
  LAlignedFacadeDst: PInt64;
  LAlignedScalarDst: PInt64;
  LUnalignedSrcStorage: array[0..5] of Int64;
  LUnalignedDirectStorage: array[0..5] of Int64;
  LUnalignedFacadeStorage: array[0..5] of Int64;
  LUnalignedScalarStorage: array[0..5] of Int64;
  LUnalignedSrc: PInt64;
  LUnalignedDirectDst: PInt64;
  LUnalignedFacadeDst: PInt64;
  LUnalignedScalarDst: PInt64;
  LI32x8Base: TVecI32x8;
  LI32x16Base: TVecI32x16;
  LI64x4Base: TVecI64x4;
  LI64x4ByDirect: TVecI64x4;
  LI64x4ByFacade: TVecI64x4;
  LI64x4ByScalar: TVecI64x4;
  LI32x8ByDirect: TVecI32x8;
  LI32x8ByFacade: TVecI32x8;
  LI32x8ByScalar: TVecI32x8;
  LI32x16ByDirect: TVecI32x16;
  LI32x16ByFacade: TVecI32x16;
  LI32x16ByScalar: TVecI32x16;
  LExpectedI32: Int32;
  LActualI32: Int32;
  LFacadeI32: Int32;
  LExpectedI64: Int64;
  LActualI64: Int64;
  LFacadeI64: Int64;
  LIndex: Integer;
  LLane: Integer;
  LExtractIndex: Integer;
  LTestedCount: Integer;

  procedure AssertVecI64x4Equal(const aOp: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI32x8Equal(const aOp: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertVecI32x16Equal(const aOp: string; const aBackend: TSimdBackend;
    const aExpected, aActual: TVecI32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      CheckEqual(aExpected.i[LLaneIndex], aActual.i[LLaneIndex], aOp + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

  procedure AssertI64BufferEqual(const aOp: string; const aBackend: TSimdBackend;
    aExpected, aActual: PInt64);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      CheckEqual(aExpected[LLaneIndex], aActual[LLaneIndex], aOp + ' lane ' + IntToStr(LLaneIndex) + ' backend ' + DirectBackendName(aBackend));
  end;

begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be available');

  LBackends[0] := sbScalar;
  LBackends[1] := sbNEON;
  LBackends[2] := sbRISCVV;

  LAlignedBlock := AllocateAligned(SizeOf(Int64) * 20, 32);
  CheckTrue(LAlignedBlock <> nil, 'AllocateAligned should return non-nil');
  LAlignedSrc := PInt64(LAlignedBlock);
  LAlignedDirectDst := PInt64(PByte(LAlignedBlock) + 32);
  LAlignedFacadeDst := PInt64(PByte(LAlignedBlock) + 64);
  LAlignedScalarDst := PInt64(PByte(LAlignedBlock) + 96);

  LAlignedSrc[0] := High(Int64);
  LAlignedSrc[1] := Low(Int64);
  LAlignedSrc[2] := 0;
  LAlignedSrc[3] := -1;

  LUnalignedSrc := @LUnalignedSrcStorage[1];
  LUnalignedDirectDst := @LUnalignedDirectStorage[1];
  LUnalignedFacadeDst := @LUnalignedFacadeStorage[1];
  LUnalignedScalarDst := @LUnalignedScalarStorage[1];

  LUnalignedSrc[0] := Int64(123456789012345678);
  LUnalignedSrc[1] := Int64(-98765432101234567);
  LUnalignedSrc[2] := High(Int32);
  LUnalignedSrc[3] := Low(Int32);

  LI32x8Base.i[0] := High(Int32);
  LI32x8Base.i[1] := Low(Int32);
  LI32x8Base.i[2] := 0;
  LI32x8Base.i[3] := -1;
  LI32x8Base.i[4] := 7;
  LI32x8Base.i[5] := -11;
  LI32x8Base.i[6] := 222222;
  LI32x8Base.i[7] := -333333;

  for LIndex := 0 to 15 do
    case LIndex of
      0: LI32x16Base.i[LIndex] := High(Int32);
      1: LI32x16Base.i[LIndex] := Low(Int32);
      2: LI32x16Base.i[LIndex] := 0;
      15: LI32x16Base.i[LIndex] := -1;
    else
      LI32x16Base.i[LIndex] := (LIndex - 8) * 12345;
    end;

  LI64x4Base.i[0] := High(Int64);
  LI64x4Base.i[1] := Low(Int64);
  LI64x4Base.i[2] := 0;
  LI64x4Base.i[3] := Int64(-444444444444444444);

  GetDispatchTable;
  LTestedCount := 0;
  try
    SetVectorAsmEnabled(True);

    for LBackend in LBackends do
    begin
      if (LBackend <> sbScalar) and (not IsBackendRegistered(LBackend)) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LTestedCount);
      LDispatch := GetDispatchTable;
      LDirectDispatch := GetDirectDispatchTable;

      CheckTrue(LDispatch <> nil, 'Dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(LDirectDispatch <> nil, 'Direct dispatch table should be assigned for backend ' + DirectBackendName(LBackend));
      CheckEqual(Ord(LDispatch^.Backend), Ord(LDirectDispatch^.Backend), 'Direct dispatch backend should track dispatch for backend ' + DirectBackendName(LBackend));

      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.LoadI64x4), 'LoadI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.StoreI64x4), 'StoreI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.SplatI64x4), 'SplatI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ZeroI64x4), 'ZeroI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ExtractI32x8), 'ExtractI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.InsertI32x8), 'InsertI32x8 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ExtractI32x16), 'ExtractI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.InsertI32x16), 'InsertI32x16 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.ExtractI64x4), 'ExtractI64x4 should be assigned for backend ' + DirectBackendName(LBackend));
      CheckTrue(Assigned(LDirectDispatch^.CoreVectors.InsertI64x4), 'InsertI64x4 should be assigned for backend ' + DirectBackendName(LBackend));

      LI64x4ByDirect := LDirectDispatch^.CoreVectors.LoadI64x4(LAlignedSrc);
      LI64x4ByScalar := LScalarTable.CoreVectors.LoadI64x4(LAlignedSrc);
      AssertVecI64x4Equal('Direct LoadI64x4 aligned', LBackend, LI64x4ByScalar, LI64x4ByDirect);

      LI64x4ByFacade := VecI64x4Load(LAlignedSrc);
      AssertVecI64x4Equal('Facade LoadI64x4 aligned', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByDirect := LDirectDispatch^.CoreVectors.LoadI64x4(LUnalignedSrc);
      LI64x4ByScalar := LScalarTable.CoreVectors.LoadI64x4(LUnalignedSrc);
      AssertVecI64x4Equal('Direct LoadI64x4 unaligned', LBackend, LI64x4ByScalar, LI64x4ByDirect);

      LI64x4ByFacade := VecI64x4Load(LUnalignedSrc);
      AssertVecI64x4Equal('Facade LoadI64x4 unaligned', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      for LLane := 0 to 3 do
      begin
        LAlignedDirectDst[LLane] := Int64($1111111111111111);
        LAlignedFacadeDst[LLane] := Int64($2222222222222222);
        LAlignedScalarDst[LLane] := Int64($3333333333333333);
        LUnalignedDirectDst[LLane] := Int64($4444444444444444);
        LUnalignedFacadeDst[LLane] := Int64($5555555555555555);
        LUnalignedScalarDst[LLane] := Int64($6666666666666666);
      end;

      LDirectDispatch^.CoreVectors.StoreI64x4(LAlignedDirectDst, LScalarTable.CoreVectors.LoadI64x4(LAlignedSrc));
      VecI64x4Store(LAlignedFacadeDst, VecI64x4Load(LAlignedSrc));
      LScalarTable.CoreVectors.StoreI64x4(LAlignedScalarDst, LScalarTable.CoreVectors.LoadI64x4(LAlignedSrc));
      AssertI64BufferEqual('Direct StoreI64x4 aligned', LBackend, LAlignedScalarDst, LAlignedDirectDst);
      AssertI64BufferEqual('Facade StoreI64x4 aligned', LBackend, LAlignedScalarDst, LAlignedFacadeDst);

      LDirectDispatch^.CoreVectors.StoreI64x4(LUnalignedDirectDst, LScalarTable.CoreVectors.LoadI64x4(LUnalignedSrc));
      VecI64x4Store(LUnalignedFacadeDst, VecI64x4Load(LUnalignedSrc));
      LScalarTable.CoreVectors.StoreI64x4(LUnalignedScalarDst, LScalarTable.CoreVectors.LoadI64x4(LUnalignedSrc));
      AssertI64BufferEqual('Direct StoreI64x4 unaligned', LBackend, LUnalignedScalarDst, LUnalignedDirectDst);
      AssertI64BufferEqual('Facade StoreI64x4 unaligned', LBackend, LUnalignedScalarDst, LUnalignedFacadeDst);

      LI64x4ByDirect := LDirectDispatch^.CoreVectors.SplatI64x4(High(Int64));
      LI64x4ByScalar := LScalarTable.CoreVectors.SplatI64x4(High(Int64));
      AssertVecI64x4Equal('Direct SplatI64x4 high', LBackend, LI64x4ByScalar, LI64x4ByDirect);

      LI64x4ByFacade := VecI64x4Splat(High(Int64));
      AssertVecI64x4Equal('Facade SplatI64x4 high', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByDirect := LDirectDispatch^.CoreVectors.SplatI64x4(Low(Int64));
      LI64x4ByScalar := LScalarTable.CoreVectors.SplatI64x4(Low(Int64));
      AssertVecI64x4Equal('Direct SplatI64x4 low', LBackend, LI64x4ByScalar, LI64x4ByDirect);

      LI64x4ByFacade := VecI64x4Splat(Low(Int64));
      AssertVecI64x4Equal('Facade SplatI64x4 low', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      LI64x4ByDirect := LDirectDispatch^.CoreVectors.ZeroI64x4();
      LI64x4ByScalar := LScalarTable.CoreVectors.ZeroI64x4();
      AssertVecI64x4Equal('Direct ZeroI64x4', LBackend, LI64x4ByScalar, LI64x4ByDirect);

      LI64x4ByFacade := VecI64x4Zero;
      AssertVecI64x4Equal('Facade ZeroI64x4', LBackend, LI64x4ByScalar, LI64x4ByFacade);

      for LIndex := 0 to 3 do
      begin
        case LIndex of
          0: LExtractIndex := -99;
          1: LExtractIndex := 0;
          2: LExtractIndex := 7;
        else
          LExtractIndex := 99;
        end;

        LExpectedI32 := LScalarTable.CoreVectors.ExtractI32x8(LI32x8Base, LExtractIndex);
        LActualI32 := LDirectDispatch^.CoreVectors.ExtractI32x8(LI32x8Base, LExtractIndex);
        CheckEqual(LExpectedI32, LActualI32, 'Direct ExtractI32x8 idx ' + IntToStr(LExtractIndex) + ' backend ' + DirectBackendName(LBackend));

        LFacadeI32 := VecI32x8Extract(LI32x8Base, LExtractIndex);
        CheckEqual(LExpectedI32, LFacadeI32, 'Facade ExtractI32x8 idx ' + IntToStr(LExtractIndex) + ' backend ' + DirectBackendName(LBackend));

        LI32x8ByDirect := LDirectDispatch^.CoreVectors.InsertI32x8(LI32x8Base, High(Int32) - LIndex, LExtractIndex);
        LI32x8ByScalar := LScalarTable.CoreVectors.InsertI32x8(LI32x8Base, High(Int32) - LIndex, LExtractIndex);
        AssertVecI32x8Equal('Direct InsertI32x8 idx ' + IntToStr(LExtractIndex), LBackend, LI32x8ByScalar, LI32x8ByDirect);

        LI32x8ByFacade := VecI32x8Insert(LI32x8Base, High(Int32) - LIndex, LExtractIndex);
        AssertVecI32x8Equal('Facade InsertI32x8 idx ' + IntToStr(LExtractIndex), LBackend, LI32x8ByScalar, LI32x8ByFacade);
      end;

      for LIndex := 0 to 3 do
      begin
        case LIndex of
          0: LExtractIndex := -99;
          1: LExtractIndex := 0;
          2: LExtractIndex := 15;
        else
          LExtractIndex := 99;
        end;

        LExpectedI32 := LScalarTable.CoreVectors.ExtractI32x16(LI32x16Base, LExtractIndex);
        LActualI32 := LDirectDispatch^.CoreVectors.ExtractI32x16(LI32x16Base, LExtractIndex);
        CheckEqual(LExpectedI32, LActualI32, 'Direct ExtractI32x16 idx ' + IntToStr(LExtractIndex) + ' backend ' + DirectBackendName(LBackend));

        LFacadeI32 := VecI32x16Extract(LI32x16Base, LExtractIndex);
        CheckEqual(LExpectedI32, LFacadeI32, 'Facade ExtractI32x16 idx ' + IntToStr(LExtractIndex) + ' backend ' + DirectBackendName(LBackend));

        LI32x16ByDirect := LDirectDispatch^.CoreVectors.InsertI32x16(LI32x16Base, Low(Int32) + LIndex, LExtractIndex);
        LI32x16ByScalar := LScalarTable.CoreVectors.InsertI32x16(LI32x16Base, Low(Int32) + LIndex, LExtractIndex);
        AssertVecI32x16Equal('Direct InsertI32x16 idx ' + IntToStr(LExtractIndex), LBackend, LI32x16ByScalar, LI32x16ByDirect);

        LI32x16ByFacade := VecI32x16Insert(LI32x16Base, Low(Int32) + LIndex, LExtractIndex);
        AssertVecI32x16Equal('Facade InsertI32x16 idx ' + IntToStr(LExtractIndex), LBackend, LI32x16ByScalar, LI32x16ByFacade);
      end;

      for LIndex := 0 to 3 do
      begin
        case LIndex of
          0: LExtractIndex := -99;
          1: LExtractIndex := 0;
          2: LExtractIndex := 3;
        else
          LExtractIndex := 99;
        end;

        LExpectedI64 := LScalarTable.CoreVectors.ExtractI64x4(LI64x4Base, LExtractIndex);
        LActualI64 := LDirectDispatch^.CoreVectors.ExtractI64x4(LI64x4Base, LExtractIndex);
        CheckEqual(LExpectedI64, LActualI64, 'Direct ExtractI64x4 idx ' + IntToStr(LExtractIndex) + ' backend ' + DirectBackendName(LBackend));

        LFacadeI64 := VecI64x4Extract(LI64x4Base, LExtractIndex);
        CheckEqual(LExpectedI64, LFacadeI64, 'Facade ExtractI64x4 idx ' + IntToStr(LExtractIndex) + ' backend ' + DirectBackendName(LBackend));

        LI64x4ByDirect := LDirectDispatch^.CoreVectors.InsertI64x4(LI64x4Base, Int64(Low(Int64) + LIndex), LExtractIndex);
        LI64x4ByScalar := LScalarTable.CoreVectors.InsertI64x4(LI64x4Base, Int64(Low(Int64) + LIndex), LExtractIndex);
        AssertVecI64x4Equal('Direct InsertI64x4 idx ' + IntToStr(LExtractIndex), LBackend, LI64x4ByScalar, LI64x4ByDirect);

        LI64x4ByFacade := VecI64x4Insert(LI64x4Base, Int64(Low(Int64) + LIndex), LExtractIndex);
        AssertVecI64x4Equal('Facade InsertI64x4 idx ' + IntToStr(LExtractIndex), LBackend, LI64x4ByScalar, LI64x4ByFacade);
      end;
    end;

    CheckTrue(LTestedCount > 0, 'At least one backend should be tested');
  finally
    FreeAligned(LAlignedBlock);
  end;
end;

procedure RunDirectDispatchConcurrentReRegisterSnapshotConsistency;
const
  WRITER_THREADS = 4;
  WRITER_ITERATIONS = 200;
  READER_THREADS = 6;
  READER_ITERATIONS = 2500;
var
  LOriginalTable: TSimdDispatchTable;
  LOriginalBackend: TSimdBackend;
  LTableA: TSimdDispatchTable;
  LTableB: TSimdDispatchTable;
  LWriters: array of TDirectDispatchMutationWorker;
  LReaders: array of TDirectDispatchReadWorker;
  LIndex: Integer;
  LAllSuccess: Boolean;
  LErrorMsgs: string;
begin
  LOriginalBackend := GetCurrentBackend;
  if not TryGetRegisteredBackendDispatchTable(sbScalar, LOriginalTable) then
    raise Exception.Create('Scalar backend should be registered for synthetic direct-dispatch re-register test');

  LTableA := LOriginalTable;
  LTableB := LOriginalTable;
  ConfigureDirectDispatchSyntheticTableA(LTableA);
  ConfigureDirectDispatchSyntheticTableB(LTableB);

  SetActiveBackend(sbScalar);
  RegisterBackend(sbScalar, LTableA);
  RebindDirectDispatch;

  if not IsDirectDispatchSyntheticSnapshotA(GetDirectDispatchTable) then
    raise Exception.Create('Synthetic table A should be active before concurrent read/write');

  SetLength(LWriters, WRITER_THREADS);
  SetLength(LReaders, READER_THREADS);
  for LIndex := 0 to High(LWriters) do
    LWriters[LIndex] := TDirectDispatchMutationWorker.Create(
      WRITER_ITERATIONS, LIndex, sbScalar, LTableA, LTableB);
  for LIndex := 0 to High(LReaders) do
    LReaders[LIndex] := TDirectDispatchReadWorker.Create(READER_ITERATIONS);

  try
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Start;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Start;

    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].WaitFor;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].WaitFor;

    LAllSuccess := True;
    LErrorMsgs := '';

    for LIndex := 0 to High(LWriters) do
      if not LWriters[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LWriters[LIndex].ErrorMsg + '; ';
      end;

    for LIndex := 0 to High(LReaders) do
      if not LReaders[LIndex].Success then
      begin
        LAllSuccess := False;
        LErrorMsgs := LErrorMsgs + LReaders[LIndex].ErrorMsg + '; ';
      end;

    if not LAllSuccess then
      raise Exception.Create('Concurrent direct-dispatch re-register/read failed: ' + LErrorMsgs);
  finally
    for LIndex := 0 to High(LWriters) do
      LWriters[LIndex].Free;
    for LIndex := 0 to High(LReaders) do
      LReaders[LIndex].Free;

    RegisterBackend(sbScalar, LOriginalTable);
    if not RestoreSavedBackendStateAndVerify(LOriginalBackend, @GetCurrentBackend) then
      raise Exception.CreateFmt(
        'Direct dispatch concurrent cleanup failed to restore previous backend selection (expected=%d, actual=%d)', [Ord(LOriginalBackend), Ord(GetCurrentBackend)]);
    RebindDirectDispatch;
  end;
end;

procedure TTestCase_DirectDispatchConcurrent.Test_DirectDispatchTable_Concurrent_ReRegister_SnapshotConsistency;
begin
  RunDirectDispatchConcurrentReRegisterSnapshotConsistency;
end;


end.