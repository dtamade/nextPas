program test_compiler_mem;
{**
 * Product-path wire: nextpas.core.compiler.mem → nextpas.core.mem.
 * Locks unit-scoped VirtualArena helpers for real compiler modules.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.compiler.mem,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.arena,
  nextpas.core.collections.vec,
  nextpas.core.text.conv;

var
  T: TTestSuite;
  LRunPassed: Boolean;

const
  NODE_SIZES: array[0..5] of SizeUInt = (24, 32, 48, 64, 128, 256);

type
  PAstNode = ^TAstNode;
  TAstNode = record
    Kind: LongWord;
    Child: PAstNode;
    Payload: array[0..15] of Byte;
  end;

procedure TestCompilerUnitArenaChurn;
var
  LArena: TVirtualArena;
  LRoot, LChild, LPrev: PAstNode;
  LPeak: SizeUInt;
  U, N: Integer;
  LSize: SizeUInt;
  LPtr: Pointer;
begin
  CompilerInitUnitArena(LArena);
  try
    LPeak := 0;
    for U := 1 to 6 do
    begin
      LRoot := PAstNode(LArena.Alloc(SizeOf(TAstNode)));
      Check(LRoot <> nil, 'root');
      LRoot^.Kind := 1;
      LRoot^.Child := nil;
      LPrev := LRoot;
      for N := 1 to 100 do
      begin
        LSize := NODE_SIZES[N mod Length(NODE_SIZES)];
        if LSize < SizeOf(TAstNode) then
          LSize := SizeOf(TAstNode);
        LChild := PAstNode(LArena.Alloc(LSize));
        Check(LChild <> nil, 'child');
        LChild^.Kind := LongWord(N);
        LChild^.Child := nil;
        LPrev^.Child := LChild;
        LPrev := LChild;
        LPtr := LArena.AllocNoPointer(16);
        Check(LPtr <> nil, 'blob');
      end;
      if LArena.PeakUsed > LPeak then
        LPeak := LArena.PeakUsed;
      LArena.Reset;
      Check(LArena.TotalUsed = 0, 'unit Reset');
    end;
    Check(LPeak > 0, 'peak');
  finally
    CompilerReleaseUnitArena(LArena);
  end;
end;

procedure TestCompilerUnitAllocatorPlugin;
var
  LAlloc: IAllocator;
  LVA: TVirtualArenaAllocator;
  I: Integer;
  LPtr: Pointer;
begin
  LAlloc := CompilerCreateUnitAllocator;
  Check(LAlloc <> nil, 'unit alloc');
  Check(not LAlloc.Traits.SupportsRealloc, 'no realloc');
  LVA := LAlloc as TVirtualArenaAllocator;
  for I := 1 to 200 do
  begin
    LPtr := LAlloc.GetMem(NODE_SIZES[I mod Length(NODE_SIZES)]);
    Check(LPtr <> nil, 'plugin GetMem');
  end;
  LAlloc.FreeMem(LPtr);
  LVA.Reset;
  Check(LAlloc.GetMem(64) <> nil, 'after Reset');
end;

procedure TestCompilerUnitArenaAdapter;
var
  LArena: IArena;
  I: Integer;
begin
  LArena := CompilerCreateUnitArenaAdapter;
  Check(LArena <> nil, 'adapter');
  for I := 1 to 50 do
    Check(LArena.Alloc(48) <> nil, 'adapter alloc');
  Check(LArena.UsedSize > 0, 'used');
  LArena.Reset;
  Check(LArena.UsedSize = 0, 'reset');
end;

procedure TestCompilerProcessHeapSameAsMem;
begin
  Check(CompilerProcessHeap = DefaultHeap, 'heap alias');
  Check(CompilerProcessAllocator = DefaultAllocator, 'ia alias');
end;

procedure TestCompilerUnitScope;
var
  LScope: TCompilerUnitScope;
  LRoot, LChild: PAstNode;
  LTryPtr: Pointer;
  I: Integer;
  LPeak: SizeUInt;
begin
  FillChar(LScope, SizeOf(LScope), 0);
  Check(not LScope.Active, 'inactive before begin');
  Check(LScope.Alloc(32) = nil, 'alloc inactive = nil');

  LScope.BeginScope;
  try
    Check(LScope.Active, 'active after begin');
    LRoot := PAstNode(LScope.Alloc(SizeOf(TAstNode)));
    Check(LRoot <> nil, 'scope root');
    LRoot^.Kind := 1;
    LRoot^.Child := nil;
    LPeak := 0;
    for I := 1 to 80 do
    begin
      LChild := PAstNode(LScope.Alloc(SizeOf(TAstNode)));
      Check(LChild <> nil, 'scope child');
      LChild^.Kind := LongWord(I);
      LChild^.Child := nil;
      LRoot^.Child := LChild;
      LRoot := LChild;
      Check(LScope.AllocNoPointer(16) <> nil, 'blob');
    end;
    Check(LScope.TotalUsed > 0, 'total used');
    LPeak := LScope.PeakUsed;
    Check(LPeak > 0, 'peak');
    Check(Pos('mem unit: active=1', LScope.FormatStats) > 0, 'unit format active');
    Check(Pos('peak=', LScope.FormatStats) > 0, 'unit format peak');
    Check(Pos('used=', LScope.FormatStats) > 0, 'unit format used');
    Check(CompilerFormatUnitStats(LScope) = LScope.FormatStats, 'unit format alias');
    LScope.Reset;
    Check(LScope.TotalUsed = 0, 'reset clears used');
    Check(LScope.Active, 'still active after reset');
    Check(LScope.Alloc(SizeOf(TAstNode)) <> nil, 'alloc after reset');
    Check(LScope.TryAlloc(SizeOf(TAstNode), LTryPtr), 'TryAlloc');
    Check(LTryPtr <> nil, 'TryAlloc ptr');
  finally
    LScope.EndScope;
  end;
  Check(not LScope.Active, 'inactive after end');
  Check(LScope.Alloc(16) = nil, 'post-end alloc nil');
  Check(not LScope.TryAlloc(16, LTryPtr), 'TryAlloc inactive false');
  Check(Pos('mem unit: active=0', LScope.FormatStats) > 0, 'unit format inactive');
end;

procedure TestCompilerSessionScope;
var
  LSession: TCompilerSessionScope;
  LRoot, LChild: PAstNode;
  LTryPtr: Pointer;
  U, I: Integer;
begin
  FillChar(LSession, SizeOf(LSession), 0);
  Check(not LSession.Active, 'inactive before begin');
  Check(LSession.Alloc(32) = nil, 'alloc inactive = nil');
  Check(LSession.UnitCount = 0, 'zero units');

  LSession.BeginSession;
  try
    Check(LSession.Active, 'active after begin');
    for U := 1 to 4 do
    begin
      LSession.UnitBegin;
      LRoot := PAstNode(LSession.Alloc(SizeOf(TAstNode)));
      Check(LRoot <> nil, 'session root');
      LRoot^.Kind := LongWord(U);
      LRoot^.Child := nil;
      for I := 1 to 40 do
      begin
        LChild := PAstNode(LSession.Alloc(SizeOf(TAstNode)));
        Check(LChild <> nil, 'session child');
        LChild^.Kind := LongWord(I);
        LChild^.Child := nil;
        LRoot^.Child := LChild;
        LRoot := LChild;
        Check(LSession.AllocNoPointer(16) <> nil, 'blob');
      end;
      Check(LSession.TotalUsed > 0, 'unit used');
      LSession.UnitEnd;
      Check(LSession.SessionPeak > 0, 'session peak tracks');
    end;
    Check(LSession.UnitCount = 4, 'four units');
    Check(LSession.SessionPeak > 0, 'session peak final');
    Check(Pos('mem session: active=1', LSession.FormatStats) > 0, 'session format active');
    Check(Pos('units=4', LSession.FormatStats) > 0, 'session format units');
    Check(Pos('peak=', LSession.FormatStats) > 0, 'session format peak');
    Check(Pos('used=', LSession.FormatStats) > 0, 'session format used');
    Check(CompilerFormatSessionStats(LSession) = LSession.FormatStats,
      'session format alias');
    LSession.Reset;
    Check(LSession.TotalUsed = 0, 'reset clears used');
    Check(LSession.TryAlloc(SizeOf(TAstNode), LTryPtr), 'TryAlloc');
    Check(LTryPtr <> nil, 'TryAlloc ptr');
  finally
    LSession.EndSession;
  end;
  Check(not LSession.Active, 'inactive after end');
  Check(LSession.UnitCount = 0, 'units cleared');
  Check(LSession.Alloc(16) = nil, 'post-end alloc nil');
  Check(Pos('mem session: active=0', LSession.FormatStats) > 0,
    'session format inactive');
end;

procedure TestVecGrowOnVirtualArena;
{ Product path: GreenTree TVec growth when SupportsRealloc=False (alloc+copy). }
var
  LAlloc: IAllocator;
  LVec: specialize TVec<LongInt>;
  I: Integer;
  LVA: TVirtualArenaAllocator;
begin
  LAlloc := CompilerCreateUnitAllocator;
  Check(LAlloc <> nil, 'unit alloc');
  Check(not LAlloc.Traits.SupportsRealloc, 'arena no realloc');
  LVec := specialize TVec<LongInt>.Create(0, LAlloc);
  try
    for I := 1 to 512 do
      LVec.Push(I);
    Check(LVec.Count = 512, 'count after grow');
    Check(LVec.Items[0] = 1, 'first');
    Check(LVec.Items[255] = 256, 'mid');
    Check(LVec.Items[511] = 512, 'last');
  finally
    LVec.Free;
  end;
  LVA := LAlloc as TVirtualArenaAllocator;
  LVA.Reset;
end;

procedure TestManagedStringVecOnVirtualArena;
{ Sema FBreakLabels path: TVec<string> grow/reset on arena. }
var
  LAlloc: IAllocator;
  LVec: specialize TVec<string>;
  I: Integer;
  LVA: TVirtualArenaAllocator;
begin
  LAlloc := CompilerCreateUnitAllocator;
  LVec := specialize TVec<string>.Create(0, LAlloc);
  try
    for I := 1 to 128 do
      LVec.Push('label_' + IntToStr(I));
    Check(LVec.Count = 128, 'string count');
    Check(LVec.Items[0] = 'label_1', 'first label');
    Check(LVec.Items[127] = 'label_128', 'last label');
  finally
    LVec.Free;
  end;
  LVA := LAlloc as TVirtualArenaAllocator;
  LVA.Reset;
end;

type
  { Mirrors Detach unit graph/search path records (session product after Resolve). }
  TSessionUnitRecord = record
    UnitId: string;
    Origin: LongInt;
  end;
  TSessionUnitVec = specialize TVec<TSessionUnitRecord>;
  TPhaseScratchVec = specialize TVec<LongInt>;

procedure TestDetachProductSurvivesScratchReset;
{ Product contract: session-long Detach tables use default-heap TVec;
  phase-local work on VirtualArena is bulk-reclaimed; session tables remain. }
var
  LScratch: IAllocator;
  LPhase: TPhaseScratchVec;
  LSession: TSessionUnitVec;
  LRec: TSessionUnitRecord;
  LVA: TVirtualArenaAllocator;
  I: Integer;
begin
  LScratch := CompilerCreateUnitAllocator;
  { Session product — nil allocator = default heap (DetachUnitGraph pattern). }
  LSession := TSessionUnitVec.Create;
  try
    LRec.UnitId := 'system';
    LRec.Origin := 1;
    LSession.Push(LRec);
    LRec.UnitId := 'sysutils';
    LRec.Origin := 2;
    LSession.Push(LRec);

    LPhase := TPhaseScratchVec.Create(0, LScratch);
    try
      for I := 1 to 64 do
        LPhase.Push(I);
      Check(LPhase.Count = 64, 'phase work filled');
    finally
      LPhase.Free;
    end;

    LVA := LScratch as TVirtualArenaAllocator;
    LVA.Reset;

    Check(LSession.Count = 2, 'session Detach product count after Reset');
    Check(LSession.Items[0].UnitId = 'system', 'session first after Reset');
    Check(LSession.Items[1].UnitId = 'sysutils', 'session second after Reset');
    Check(LSession.Items[1].Origin = 2, 'session field after Reset');
  finally
    LSession.Free;
  end;
end;

procedure TestAstIndependentOfScratchReset;
{ Dual-track: FAstAllocator and FScratchAllocator are independent VirtualArenas.
  ResetScratchAllocator must not reclaim AST node storage. }
var
  LAst, LScratch: IAllocator;
  LAstVA, LScratchVA: TVirtualArenaAllocator;
  PAst: PLongInt;
  PScratch: PLongInt;
  I: Integer;
begin
  LAst := CompilerCreateUnitAllocator;
  LScratch := CompilerCreateUnitAllocator;
  LAstVA := LAst as TVirtualArenaAllocator;
  LScratchVA := LScratch as TVirtualArenaAllocator;

  PAst := PLongInt(LAst.GetMem(SizeOf(LongInt)));
  Check(PAst <> nil, 'ast alloc');
  PAst^ := $A57A57;
  for I := 1 to 32 do
  begin
    PScratch := PLongInt(LScratch.GetMem(SizeOf(LongInt)));
    Check(PScratch <> nil, 'scratch alloc');
    PScratch^ := I;
  end;

  LScratchVA.Reset;
  Check(PAst^ = $A57A57, 'AST payload survives scratch Reset');

  PScratch := PLongInt(LScratch.GetMem(SizeOf(LongInt)));
  Check(PScratch <> nil, 'scratch after Reset');
  PScratch^ := 99;
  Check(PScratch^ = 99, 'scratch write after Reset');
  Check(PAst^ = $A57A57, 'AST still intact after scratch reuse');

  { Symmetric: AST Reset must not be required for scratch to stay live. }
  LAstVA.Reset;
  Check(PScratch^ = 99, 'scratch payload survives AST Reset');
end;

procedure TestUnitBeginPreservesSessionPeak;
{ UnitBegin reclaims unit scratch (TotalUsed→0) but SessionPeak from UnitEnd
  must survive into the next unit (peak accounting across units). }
var
  LSession: TCompilerSessionScope;
  LPeakAfterUnit1: SizeUInt;
begin
  FillChar(LSession, SizeOf(LSession), 0);
  LSession.BeginSession;
  try
    LSession.UnitBegin;
    Check(LSession.Alloc(256) <> nil, 'unit1 alloc');
    Check(LSession.TotalUsed > 0, 'unit1 used');
    LSession.UnitEnd;
    LPeakAfterUnit1 := LSession.SessionPeak;
    Check(LPeakAfterUnit1 > 0, 'peak after unit1');
    Check(LSession.UnitCount = 1, 'unit count 1');

    LSession.UnitBegin;
    Check(LSession.TotalUsed = 0, 'UnitBegin clears TotalUsed');
    Check(LSession.SessionPeak = LPeakAfterUnit1, 'SessionPeak survives UnitBegin');
    Check(LSession.UnitCount = 2, 'unit count 2');
    Check(LSession.Alloc(64) <> nil, 'unit2 alloc');
    LSession.UnitEnd;
    Check(LSession.SessionPeak >= LPeakAfterUnit1, 'peak non-decreasing');
  finally
    LSession.EndSession;
  end;
end;

procedure TestArenaFreeMemNoOpUntilReset;
{ VirtualArena FreeMem is no-op; payload stays until Reset bulk-reclaims. }
var
  LAlloc: IAllocator;
  LVA: TVirtualArenaAllocator;
  P: PLongInt;
begin
  LAlloc := CompilerCreateUnitAllocator;
  LVA := LAlloc as TVirtualArenaAllocator;
  P := PLongInt(LAlloc.GetMem(SizeOf(LongInt)));
  Check(P <> nil, 'alloc');
  P^ := $FEED01;
  LAlloc.FreeMem(P);
  Check(P^ = $FEED01, 'FreeMem no-op keeps payload');
  LVA.Reset;
  { After Reset the slab is reusable; only contract is Reset reclaims. }
  P := PLongInt(LAlloc.GetMem(SizeOf(LongInt)));
  Check(P <> nil, 'alloc after Reset');
  P^ := 7;
  Check(P^ = 7, 'write after Reset');
end;

type
  TEntryOwnedKids = specialize TVec<string>;
  TEntryOwnedRecord = record
    Name: string;
    Kids: TEntryOwnedKids;
  end;
  TEntryOwnedVec = specialize TVec<TEntryOwnedRecord>;

procedure TestEntryOwnedNestedSurvivesScratchReset;
{ Entry-owned nested TVec on default heap (HIR SwitchCases / MIR Args pattern):
  parent table + nested kids outlive phase scratch Reset. }
var
  LScratch: IAllocator;
  LPhase: TPhaseScratchVec;
  LEntries: TEntryOwnedVec;
  LRec: TEntryOwnedRecord;
  LVA: TVirtualArenaAllocator;
  I: Integer;
begin
  LScratch := CompilerCreateUnitAllocator;
  LEntries := TEntryOwnedVec.Create;
  try
    LRec.Name := 'case0';
    LRec.Kids := TEntryOwnedKids.Create;
    LRec.Kids.Push('a');
    LRec.Kids.Push('b');
    LEntries.Push(LRec);
    LRec.Name := 'case1';
    LRec.Kids := TEntryOwnedKids.Create;
    LRec.Kids.Push('c');
    LEntries.Push(LRec);

    LPhase := TPhaseScratchVec.Create(0, LScratch);
    try
      for I := 1 to 48 do
        LPhase.Push(I);
    finally
      LPhase.Free;
    end;
    LVA := LScratch as TVirtualArenaAllocator;
    LVA.Reset;

    Check(LEntries.Count = 2, 'entries after scratch Reset');
    Check(LEntries.Items[0].Name = 'case0', 'entry0 name');
    Check(LEntries.Items[0].Kids.Count = 2, 'entry0 kids');
    Check(LEntries.Items[0].Kids.Items[1] = 'b', 'entry0 kid');
    Check(LEntries.Items[1].Kids.Items[0] = 'c', 'entry1 kid');
  finally
    for I := 0 to LongInt(LEntries.Count) - 1 do
      LEntries.Items[I].Kids.Free;
    LEntries.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.compiler.mem');
  T.Test('unit arena AST churn', @TestCompilerUnitArenaChurn);
  T.Test('unit IAllocator plugin', @TestCompilerUnitAllocatorPlugin);
  T.Test('unit IArena adapter', @TestCompilerUnitArenaAdapter);
  T.Test('process heap aliases', @TestCompilerProcessHeapSameAsMem);
  T.Test('TCompilerUnitScope lifecycle', @TestCompilerUnitScope);
  T.Test('TCompilerSessionScope lifecycle', @TestCompilerSessionScope);
  T.Test('TVec grow on VirtualArena', @TestVecGrowOnVirtualArena);
  T.Test('TVec<string> grow on VirtualArena', @TestManagedStringVecOnVirtualArena);
  T.Test('Detach product survives scratch Reset', @TestDetachProductSurvivesScratchReset);
  T.Test('AST independent of scratch Reset', @TestAstIndependentOfScratchReset);
  T.Test('UnitBegin preserves SessionPeak', @TestUnitBeginPreservesSessionPeak);
  T.Test('arena FreeMem no-op until Reset', @TestArenaFreeMemNoOpUntilReset);
  T.Test('entry-owned nested survives scratch Reset', @TestEntryOwnedNestedSurvivesScratchReset);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
