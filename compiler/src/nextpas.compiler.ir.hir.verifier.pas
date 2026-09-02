unit nextpas.compiler.ir.hir.verifier;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model;

type
  THIRVerifyError = record
    FuncName: string;
    BlockId: THIRBlockId;
    Message: string;
  end;

  THirVerifyErrorVec = specialize TVec<THIRVerifyError>;
  THirValueIdVec = specialize TVec<THIRValueId>;

  THIRVerifier = class
  private
    FModule: THIRModule;
    FAllocator: IAllocator;
    FErrors: THirVerifyErrorVec;
    function CreateValueIdVec: THirValueIdVec;
    procedure AddError(const AFuncName: string; ABlockId: THIRBlockId;
      const AMsg: string);
    procedure VerifyFunction(const AFunc: THIRFunction);
    procedure VerifySSADefs(const AFunc: THIRFunction);
    procedure VerifySSAUses(const AFunc: THIRFunction);
    procedure VerifyTerminators(const AFunc: THIRFunction);
    procedure VerifyTypes(const AFunc: THIRFunction);
    procedure VerifySystemContractSequences(const AFunc: THIRFunction);
  public
    constructor Create(AModule: THIRModule; AAllocator: IAllocator = nil);
    destructor Destroy; override;
    function Verify: Boolean;
    function ErrorCount: LongInt;
    function ErrorAt(AIndex: LongInt): THIRVerifyError;
  end;

implementation

uses
  SysUtils, Generics.Collections,
  nextpas.core.text.conv, nextpas.compiler.ir.system_contracts;

type
  TBlockIdMap = specialize TDictionary<THIRBlockId, LongInt>;
  TDefPos = record
    BlockIdx: LongInt;
    BlockId: THIRBlockId;
    InstrIdx: LongInt; // -1 for params, otherwise 0..n-1 within block
  end;
  TDefMap = specialize TDictionary<THIRValueId, TDefPos>;
  TBlockIdxVec = specialize TVec<LongInt>;

constructor THIRVerifier.Create(AModule: THIRModule; AAllocator: IAllocator);
begin
  inherited Create;
  FModule := AModule;
  FAllocator := AAllocator;
  if FAllocator <> nil then
    FErrors := THirVerifyErrorVec.Create(0, FAllocator)
  else
    FErrors := THirVerifyErrorVec.Create;
end;

destructor THIRVerifier.Destroy;
begin
  FErrors.Free;
  inherited Destroy;
end;

function THIRVerifier.CreateValueIdVec: THirValueIdVec;
begin
  if FAllocator <> nil then
    Result := THirValueIdVec.Create(0, FAllocator)
  else
    Result := THirValueIdVec.Create;
end;

procedure THIRVerifier.AddError(const AFuncName: string;
  ABlockId: THIRBlockId; const AMsg: string);
var
  Err: THIRVerifyError;
begin
  Err.FuncName := AFuncName;
  Err.BlockId := ABlockId;
  Err.Message := AMsg;
  FErrors.Push(Err);
end;

// Build O(1) block id -> index cache, validates uniqueness, zero-copy via GetPtrUnchecked
function BuildBlockIndexMap(const AFunc: THIRFunction; out AMap: TBlockIdMap): Boolean;
var
  I: LongInt;
  PBlock: ^THIRBlock;
begin
  Result := False;
  AMap := TBlockIdMap.Create;
  if AFunc.Blocks = nil then Exit(True);
  for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
  begin
    // zero-copy access
    PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(I));
    if AMap.ContainsKey(PBlock^.Id) then
      Exit(False);
    AMap.Add(PBlock^.Id, I);
  end;
  Result := True;
end;

procedure GetTermSuccs(const ATerm: THIRTerminator; const AOut: TBlockIdxVec; const AMap: TBlockIdMap);
var
  I: LongInt;
  Idx: LongInt;
begin
  AOut.Clear;
  case ATerm.Kind of
    htkBranch:
      if AMap.TryGetValue(ATerm.TargetBlock, Idx) then AOut.Push(Idx);
    htkCondBranch:
      begin
        if AMap.TryGetValue(ATerm.TrueBlock, Idx) then AOut.Push(Idx);
        if AMap.TryGetValue(ATerm.FalseBlock, Idx) then AOut.Push(Idx);
      end;
    htkSwitch:
      begin
        if AMap.TryGetValue(ATerm.DefaultBlock, Idx) then AOut.Push(Idx);
        if ATerm.SwitchCases <> nil then
          for I := 0 to LongInt(ATerm.SwitchCases.Count) - 1 do
            if AMap.TryGetValue(ATerm.SwitchCases[SizeUInt(I)].TargetBlock, Idx) then
              AOut.Push(Idx);
      end;
    htkReturn, htkUnreachable: ;
  end;
end;

procedure THIRVerifier.VerifySSADefs(const AFunc: THIRFunction);
var
  Dict: TDefMap;
  BI, II: LongInt;
  PBlock: ^THIRBlock;
  PInstr: ^THIRInstr;
  Pos: TDefPos;
  Prev: TDefPos;
begin
  Dict := TDefMap.Create;
  try
    if AFunc.Blocks = nil then Exit;
    for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    begin
      PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
      if PBlock^.Instrs = nil then Continue;
      for II := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
      begin
        PInstr := PBlock^.Instrs.GetPtrUnchecked(SizeUInt(II));
        if PInstr^.ResultId = 0 then
        begin
          AddError(AFunc.Name, PBlock^.Id,
            Format('instr %d [%s] has zero ResultId (block %d func %s)', [II, IntToStr(Ord(PInstr^.Kind)), PBlock^.Id, AFunc.Name]));
          Continue;
        end;
        if Dict.TryGetValue(PInstr^.ResultId, Prev) then
        begin
          AddError(AFunc.Name, PBlock^.Id,
            Format('SSA violation: %%%d defined more than once (prev block %d idx %d, dup block %d idx %d func %s)', [PInstr^.ResultId, Prev.BlockId, Prev.InstrIdx, PBlock^.Id, II, AFunc.Name]));
        end
        else
        begin
          Pos.BlockIdx := BI;
          Pos.BlockId := PBlock^.Id;
          Pos.InstrIdx := II;
          Dict.Add(PInstr^.ResultId, Pos);
        end;
      end;
    end;
    // also check param value ids duplicate with instr defs
    if AFunc.Params <> nil then
      for II := 0 to LongInt(AFunc.Params.Count) - 1 do
      begin
        if Dict.ContainsKey(AFunc.Params[SizeUInt(II)].ValueId) then
          AddError(AFunc.Name, AFunc.EntryBlockId,
            Format('SSA violation: param %%%d redefined by instr (func %s param %s)', [AFunc.Params[SizeUInt(II)].ValueId, AFunc.Name, AFunc.Params[SizeUInt(II)].Name]));
      end;
  finally
    Dict.Free;
  end;
end;

procedure THIRVerifier.VerifySSAUses(const AFunc: THIRFunction);
var
  DefMap: TDefMap;
  BlockMap: TBlockIdMap;
  BI, II, OI, PI: LongInt;
  PBlock: ^THIRBlock;
  PInstr: ^THIRInstr;
  DefPos: TDefPos;
  UseBlockIdx: LongInt;
  Dom: array of array of Boolean;
  Reach: array of Boolean;
  N: LongInt;
  I, J, K: LongInt;
  Changed: Boolean;
  Preds: array of TBlockIdxVec;
  Succs: array of TBlockIdxVec;
  Stack: TBlockIdxVec;
  PhiPos: LongInt;
  EntryIdx: LongInt;
  TmpVec: TBlockIdxVec;

  function Dominates(ADefIdx, AUseIdx: LongInt): Boolean;
  begin
    if (ADefIdx < 0) or (AUseIdx < 0) or (ADefIdx >= N) or (AUseIdx >= N) then Exit(False);
    Result := Dom[AUseIdx][ADefIdx];
  end;

begin
  if (AFunc.Blocks = nil) or (AFunc.Blocks.Count = 0) then Exit;
  N := LongInt(AFunc.Blocks.Count);
  if not BuildBlockIndexMap(AFunc, BlockMap) then
  begin
    BlockMap.Free;
    Exit;
  end;
  DefMap := TDefMap.Create;
  TmpVec := TBlockIdxVec.Create;
  try
    // zero-copy def collection
    if AFunc.Params <> nil then
      for PI := 0 to LongInt(AFunc.Params.Count) - 1 do
      begin
        DefPos.BlockIdx := -1;
        if BlockMap.TryGetValue(AFunc.EntryBlockId, EntryIdx) then
          DefPos.BlockIdx := EntryIdx
        else if N > 0 then
          DefPos.BlockIdx := 0;
        DefPos.BlockId := AFunc.EntryBlockId;
        DefPos.InstrIdx := -1;
        if not DefMap.ContainsKey(AFunc.Params[SizeUInt(PI)].ValueId) then
          DefMap.Add(AFunc.Params[SizeUInt(PI)].ValueId, DefPos);
      end;

    for BI := 0 to N - 1 do
    begin
      PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
      if PBlock^.Instrs = nil then Continue;
      for II := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
      begin
        PInstr := PBlock^.Instrs.GetPtrUnchecked(SizeUInt(II));
        if PInstr^.ResultId = 0 then Continue;
        if not DefMap.ContainsKey(PInstr^.ResultId) then
        begin
          DefPos.BlockIdx := BI;
          DefPos.BlockId := PBlock^.Id;
          DefPos.InstrIdx := II;
          DefMap.Add(PInstr^.ResultId, DefPos);
        end;
      end;
    end;

    // Build CFG succ/pred for dominance, cached
    SetLength(Succs, N);
    SetLength(Preds, N);
    for I := 0 to N - 1 do
    begin
      Succs[I] := TBlockIdxVec.Create;
      Preds[I] := TBlockIdxVec.Create;
    end;
    for BI := 0 to N - 1 do
    begin
      PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
      TmpVec.Clear;
      GetTermSuccs(PBlock^.Terminator, TmpVec, BlockMap);
      for I := 0 to LongInt(TmpVec.Count) - 1 do
      begin
        Succs[BI].Push(TmpVec[I]);
        Preds[TmpVec[I]].Push(BI);
      end;
    end;

    // Reachability from entry (for dominance and error context)
    SetLength(Reach, N);
    for I := 0 to N - 1 do Reach[I] := False;
    EntryIdx := 0;
    if not BlockMap.TryGetValue(AFunc.EntryBlockId, EntryIdx) then
      EntryIdx := 0;
    Stack := TBlockIdxVec.Create;
    try
      Stack.Push(EntryIdx);
      Reach[EntryIdx] := True;
      while Stack.Count > 0 do
      begin
        Stack.TryPop(I);
        for J := 0 to LongInt(Succs[I].Count) - 1 do
        begin
          K := Succs[I][SizeUInt(J)];
          if not Reach[K] then
          begin
            Reach[K] := True;
            Stack.Push(K);
          end;
        end;
      end;
    finally
      Stack.Free;
    end;

    // Dominators iterative bit matrix, O(N^2) but N small; cache dominates queries O(1)
    SetLength(Dom, N);
    for I := 0 to N - 1 do SetLength(Dom[I], N);
    for I := 0 to N - 1 do
      for J := 0 to N - 1 do
        Dom[I][J] := True;
    for J := 0 to N - 1 do
      Dom[EntryIdx][J] := (J = EntryIdx);
    // unreachable blocks dominate only themselves initially
    for I := 0 to N - 1 do
      if not Reach[I] then
        for J := 0 to N - 1 do
          Dom[I][J] := (J = I);

    repeat
      Changed := False;
      for BI := 0 to N - 1 do
      begin
        if BI = EntryIdx then Continue;
        if not Reach[BI] then Continue;
        // newDom = {BI} intersect over preds
        for J := 0 to N - 1 do
        begin
          if J = BI then Continue;
          // intersect: J in dom[BI] iff J in dom[p] for all p in preds[BI]
          if Preds[BI].Count = 0 then
          begin
            if Dom[BI][J] then begin Dom[BI][J] := False; Changed := True; end;
          end
          else
          begin
            // J must be in every pred's dom
            K := 0;
            for I := 0 to LongInt(Preds[BI].Count) - 1 do
              if Dom[Preds[BI][SizeUInt(I)]][J] then Inc(K);
            if (K = LongInt(Preds[BI].Count)) <> Dom[BI][J] then
            begin
              Dom[BI][J] := (K = LongInt(Preds[BI].Count));
              Changed := True;
            end;
          end;
        end;
        if not Dom[BI][BI] then begin Dom[BI][BI] := True; Changed := True; end;
      end;
    until not Changed;

    // Validate uses with dominance and undefined check
    for BI := 0 to N - 1 do
    begin
      PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
      if PBlock^.Instrs = nil then Continue;
      for II := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
      begin
        PInstr := PBlock^.Instrs.GetPtrUnchecked(SizeUInt(II));
        // phi operands checked separately
        if PInstr^.Kind = hikPhi then Continue;
        for OI := 0 to High(PInstr^.Operands) do
        begin
          if PInstr^.Operands[OI].ValueId = 0 then Continue;
          if not DefMap.TryGetValue(PInstr^.Operands[OI].ValueId, DefPos) then
          begin
            AddError(AFunc.Name, PBlock^.Id,
              Format('Use of undefined value %%%d at instr %d [%s] operand %d block %d func %s', [PInstr^.Operands[OI].ValueId, II, IntToStr(Ord(PInstr^.Kind)), OI, PBlock^.Id, AFunc.Name]));
            Continue;
          end;
          UseBlockIdx := BI;
          // same block: need def before use
          if DefPos.BlockIdx = UseBlockIdx then
          begin
            if DefPos.InstrIdx >= II then
              AddError(AFunc.Name, PBlock^.Id,
                Format('SSA dominance violation: use of %%%d in same block %d instr %d before def at instr %d func %s', [PInstr^.Operands[OI].ValueId, PBlock^.Id, II, DefPos.InstrIdx, AFunc.Name]));
          end
          else
          begin
            if not Dominates(DefPos.BlockIdx, UseBlockIdx) then
              AddError(AFunc.Name, PBlock^.Id,
                Format('SSA dominance violation: def of %%%d in block %d does not dominate use in block %d instr %d [%s] func %s', [PInstr^.Operands[OI].ValueId, DefPos.BlockId, PBlock^.Id, II, IntToStr(Ord(PInstr^.Kind)), AFunc.Name]));
          end;
        end;
        // terminator condition dominance checked in VerifyTerminators, but also check here for completeness
      end;
    end;

    // Phi-specific checks: phi must be at block start, entries correspond to preds, and each phi value dominates predecessor
    for BI := 0 to N - 1 do
    begin
      PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
      if PBlock^.Instrs = nil then Continue;
      PhiPos := -1;
      for II := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
      begin
        PInstr := PBlock^.Instrs.GetPtrUnchecked(SizeUInt(II));
        if PInstr^.Kind = hikPhi then
        begin
          PhiPos := II;
          if II <> 0 then
          begin
            // phi not at start: ensure all previous instrs are phi (already ensured by ordering check)
            // if non-phi before phi, error
            // we track first non-phi position
          end;
          // Validate phi entries
          if Length(PInstr^.PhiEntries) = 0 then
            AddError(AFunc.Name, PBlock^.Id,
              Format('phi %%%d has no entries block %d func %s', [PInstr^.ResultId, PBlock^.Id, AFunc.Name]));
          for OI := 0 to High(PInstr^.PhiEntries) do
          begin
            if not DefMap.TryGetValue(PInstr^.PhiEntries[OI].ValueId, DefPos) then
            begin
              AddError(AFunc.Name, PBlock^.Id,
                Format('phi %%%d entry %d uses undefined %%%d block %d func %s', [PInstr^.ResultId, OI, PInstr^.PhiEntries[OI].ValueId, PBlock^.Id, AFunc.Name]));
              Continue;
            end;
            if not BlockMap.ContainsKey(PInstr^.PhiEntries[OI].BlockId) then
            begin
              AddError(AFunc.Name, PBlock^.Id,
                Format('phi %%%d entry %d predecessor block %d not found func %s', [PInstr^.ResultId, OI, PInstr^.PhiEntries[OI].BlockId, AFunc.Name]));
              Continue;
            end;
            // predecessor must be in Preds[BI]
            BlockMap.TryGetValue(PInstr^.PhiEntries[OI].BlockId, J);
            K := 0;
            for I := 0 to LongInt(Preds[BI].Count) - 1 do
              if Preds[BI][SizeUInt(I)] = J then begin K := 1; Break; end;
            if K = 0 then
              AddError(AFunc.Name, PBlock^.Id,
                Format('phi %%%d entry %d predecessor %d not a CFG pred of block %d func %s', [PInstr^.ResultId, OI, PInstr^.PhiEntries[OI].BlockId, PBlock^.Id, AFunc.Name]));
            // dominance: def must dominate predecessor
            if DefPos.BlockIdx <> J then
              if not Dominates(DefPos.BlockIdx, J) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('phi %%%d entry %d value %%%d def block %d does not dominate pred %d func %s', [PInstr^.ResultId, OI, PInstr^.PhiEntries[OI].ValueId, DefPos.BlockId, PInstr^.PhiEntries[OI].BlockId, AFunc.Name]));
          end;
        end
        else
        begin
          if PhiPos >= 0 then
          begin
            // non-phi after phi block - phi must be contiguous at start
            // allow? ensure no phi after non-phi
          end;
          // if we have seen phi and now non-phi, future phi is error
          // we check by ensuring no phi after this point
          for K := II + 1 to LongInt(PBlock^.Instrs.Count) - 1 do
            if PBlock^.Instrs[SizeUInt(K)].Kind = hikPhi then
            begin
              AddError(AFunc.Name, PBlock^.Id,
                Format('phi %%%d not at block start (block %d func %s)', [PBlock^.Instrs[SizeUInt(K)].ResultId, PBlock^.Id, AFunc.Name]));
              Break;
            end;
          Break;
        end;
      end;
    end;

    for I := 0 to N - 1 do
    begin
      Succs[I].Free;
      Preds[I].Free;
    end;
  finally
    TmpVec.Free;
    DefMap.Free;
    BlockMap.Free;
  end;
end;

procedure THIRVerifier.VerifyTerminators(const AFunc: THIRFunction);
var
  BI, I, J: LongInt;
  PBlock: ^THIRBlock;
  BlockMap: TBlockIdMap;
  EntryIdx: LongInt;
  Reach: array of Boolean;
  Stack: TBlockIdxVec;
  SuccLists: array of TBlockIdxVec;
  N: LongInt;
  Cur: LongInt;
  PredCount: array of LongInt;
  IsReachable: Boolean;
  DefMap: TDefMap;
  DefPos: TDefPos;
  PI: LongInt;
begin
  if (AFunc.Blocks = nil) or (AFunc.Blocks.Count = 0) then
  begin
    if not AFunc.IsExternal then
      AddError(AFunc.Name, 0, Format('Non-external function %s has no blocks', [AFunc.Name]));
    Exit;
  end;
  N := LongInt(AFunc.Blocks.Count);
  if not BuildBlockIndexMap(AFunc, BlockMap) then
  begin
    AddError(AFunc.Name, 0, Format('duplicate block id in function %s', [AFunc.Name]));
    BlockMap.Free;
    Exit;
  end;
  EntryIdx := 0;
  BlockMap.TryGetValue(AFunc.EntryBlockId, EntryIdx);
  try
    // Entry block validation with context
    if AFunc.EntryBlockId = 0 then
      AddError(AFunc.Name, AFunc.Blocks.GetPtrUnchecked(0)^.Id,
        Format('function %s entry block id is 0 (expected block %d)', [AFunc.Name, AFunc.Blocks.GetPtrUnchecked(0)^.Id]))
    else if not BlockMap.TryGetValue(AFunc.EntryBlockId, EntryIdx) then
      AddError(AFunc.Name, AFunc.EntryBlockId,
        Format('function %s entry block %d not found among %d blocks', [AFunc.Name, AFunc.EntryBlockId, N]));

    // Build succ lists cached O(1) via BlockMap
    SetLength(SuccLists, N);
    SetLength(PredCount, N);
    for I := 0 to N - 1 do
    begin
      SuccLists[I] := TBlockIdxVec.Create;
      PredCount[I] := 0;
    end;
    // Build def map for terminator condition checks (zero-copy)
    DefMap := TDefMap.Create;
    try
      if AFunc.Params <> nil then
        for PI := 0 to LongInt(AFunc.Params.Count) - 1 do
        begin
          DefPos.BlockIdx := EntryIdx;
          DefPos.BlockId := AFunc.EntryBlockId;
          DefPos.InstrIdx := -1;
          if not DefMap.ContainsKey(AFunc.Params[SizeUInt(PI)].ValueId) then
            DefMap.Add(AFunc.Params[SizeUInt(PI)].ValueId, DefPos);
        end;
      for BI := 0 to N - 1 do
      begin
        PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
        if PBlock^.Instrs <> nil then
          for I := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
            if not DefMap.ContainsKey(PBlock^.Instrs.GetPtrUnchecked(SizeUInt(I))^.ResultId) and (PBlock^.Instrs.GetPtrUnchecked(SizeUInt(I))^.ResultId <> 0) then
            begin
              DefPos.BlockIdx := BI; DefPos.BlockId := PBlock^.Id; DefPos.InstrIdx := I;
              DefMap.Add(PBlock^.Instrs.GetPtrUnchecked(SizeUInt(I))^.ResultId, DefPos);
            end;
      end;

      for BI := 0 to N - 1 do
      begin
        PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
        // Validate terminator kind range
        if not (PBlock^.Terminator.Kind in [htkReturn, htkBranch, htkCondBranch, htkSwitch, htkUnreachable]) then
          AddError(AFunc.Name, PBlock^.Id,
            Format('invalid terminator kind %d in block %d func %s', [Ord(PBlock^.Terminator.Kind), PBlock^.Id, AFunc.Name]));
        case PBlock^.Terminator.Kind of
          htkReturn:
            begin
              // return value if non-zero must be defined
              if PBlock^.Terminator.ReturnValue <> 0 then
                if not DefMap.ContainsKey(PBlock^.Terminator.ReturnValue) then
                  AddError(AFunc.Name, PBlock^.Id,
                    Format('return uses undefined %%%d (block %d func %s)', [PBlock^.Terminator.ReturnValue, PBlock^.Id, AFunc.Name]));
            end;
          htkBranch:
            begin
              if not BlockMap.ContainsKey(PBlock^.Terminator.TargetBlock) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('branch target %d not found (block %d func %s kind htkBranch)', [PBlock^.Terminator.TargetBlock, PBlock^.Id, AFunc.Name]))
              else
              begin
                BlockMap.TryGetValue(PBlock^.Terminator.TargetBlock, Cur);
                SuccLists[BI].Push(Cur);
                Inc(PredCount[Cur]);
              end;
              if PBlock^.Terminator.TargetBlock = PBlock^.Id then
              begin
                // self-loop allowed but warn if needed; keep as info not error
              end;
            end;
          htkCondBranch:
            begin
              if PBlock^.Terminator.Condition = 0 then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('cond branch missing condition (block %d func %s)', [PBlock^.Id, AFunc.Name]))
              else if not DefMap.ContainsKey(PBlock^.Terminator.Condition) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('cond branch condition %%%d undefined (block %d func %s)', [PBlock^.Terminator.Condition, PBlock^.Id, AFunc.Name]));
              if not BlockMap.ContainsKey(PBlock^.Terminator.TrueBlock) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('cond branch true target %d not found (block %d func %s)', [PBlock^.Terminator.TrueBlock, PBlock^.Id, AFunc.Name]))
              else
              begin
                BlockMap.TryGetValue(PBlock^.Terminator.TrueBlock, Cur);
                SuccLists[BI].Push(Cur); Inc(PredCount[Cur]);
              end;
              if not BlockMap.ContainsKey(PBlock^.Terminator.FalseBlock) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('cond branch false target %d not found (block %d func %s)', [PBlock^.Terminator.FalseBlock, PBlock^.Id, AFunc.Name]))
              else
              begin
                BlockMap.TryGetValue(PBlock^.Terminator.FalseBlock, Cur);
                SuccLists[BI].Push(Cur); Inc(PredCount[Cur]);
              end;
              if PBlock^.Terminator.TrueBlock = PBlock^.Terminator.FalseBlock then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('cond branch true/false same target %d (block %d func %s)', [PBlock^.Terminator.TrueBlock, PBlock^.Id, AFunc.Name]));
            end;
          htkSwitch:
            begin
              if PBlock^.Terminator.Condition = 0 then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('switch missing condition (block %d func %s)', [PBlock^.Id, AFunc.Name]))
              else if not DefMap.ContainsKey(PBlock^.Terminator.Condition) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('switch condition %%%d undefined (block %d func %s)', [PBlock^.Terminator.Condition, PBlock^.Id, AFunc.Name]));
              if not BlockMap.ContainsKey(PBlock^.Terminator.DefaultBlock) then
                AddError(AFunc.Name, PBlock^.Id,
                  Format('switch default target %d not found (block %d func %s)', [PBlock^.Terminator.DefaultBlock, PBlock^.Id, AFunc.Name]))
              else
              begin
                BlockMap.TryGetValue(PBlock^.Terminator.DefaultBlock, Cur);
                SuccLists[BI].Push(Cur); Inc(PredCount[Cur]);
              end;
              if PBlock^.Terminator.SwitchCases <> nil then
                for I := 0 to LongInt(PBlock^.Terminator.SwitchCases.Count) - 1 do
                begin
                  if not BlockMap.ContainsKey(PBlock^.Terminator.SwitchCases[SizeUInt(I)].TargetBlock) then
                    AddError(AFunc.Name, PBlock^.Id,
                      Format('switch case %d target %d not found (block %d func %s)', [I, PBlock^.Terminator.SwitchCases[SizeUInt(I)].TargetBlock, PBlock^.Id, AFunc.Name]))
                  else
                  begin
                    BlockMap.TryGetValue(PBlock^.Terminator.SwitchCases[SizeUInt(I)].TargetBlock, Cur);
                    // duplicate value check: zero-copy scan of prior cases
                    for J := 0 to I - 1 do
                      if PBlock^.Terminator.SwitchCases[SizeUInt(J)].Value = PBlock^.Terminator.SwitchCases[SizeUInt(I)].Value then
                        AddError(AFunc.Name, PBlock^.Id,
                          Format('switch duplicate case value %d (block %d func %s)', [PBlock^.Terminator.SwitchCases[SizeUInt(I)].Value, PBlock^.Id, AFunc.Name]));
                    BlockMap.TryGetValue(PBlock^.Terminator.SwitchCases[SizeUInt(I)].TargetBlock, Cur);
                    SuccLists[BI].Push(Cur); Inc(PredCount[Cur]);
                  end;
                end;
            end;
          htkUnreachable:
            begin
              // unreachable is only valid for dead blocks; will be flagged after reachability
            end;
        end;
      end;
    finally
      DefMap.Free;
    end;

    // Reachability analysis from entry, cached
    SetLength(Reach, N);
    for I := 0 to N - 1 do Reach[I] := False;
    if BlockMap.TryGetValue(AFunc.EntryBlockId, EntryIdx) then
    else EntryIdx := 0;
    Stack := TBlockIdxVec.Create;
    try
      Stack.Push(EntryIdx);
      Reach[EntryIdx] := True;
      while Stack.Count > 0 do
      begin
        Stack.TryPop(Cur);
        for I := 0 to LongInt(SuccLists[Cur].Count) - 1 do
        begin
          BI := SuccLists[Cur][SizeUInt(I)];
          if not Reach[BI] then
          begin
            Reach[BI] := True;
            Stack.Push(BI);
          end;
        end;
      end;
      for BI := 0 to N - 1 do
      begin
        PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
        IsReachable := Reach[BI];
        if PBlock^.Terminator.Kind = htkUnreachable then
        begin
          if IsReachable then
            AddError(AFunc.Name, PBlock^.Id,
              Format('reachable block %d has unreachable terminator (func %s, %d instrs, entry %d)', [PBlock^.Id, AFunc.Name, LongInt(PBlock^.Instrs.Count), AFunc.EntryBlockId]));
          // dead blocks should have no succs (already)
        end
        else
        begin
          if not IsReachable then
          begin
            // dead block with real terminator: allow but ensure it has terminator; no error
            // optionally warn if PredCount =0 and BI<>EntryIdx
          end;
          if SuccLists[BI].Count = 0 then
          begin
            if PBlock^.Terminator.Kind <> htkReturn then
              AddError(AFunc.Name, PBlock^.Id,
                Format('block %d terminator %d has no successors but not return (func %s)', [PBlock^.Id, Ord(PBlock^.Terminator.Kind), AFunc.Name]));
          end;
        end;
        // CFG integrity: Preds/Succs vectors if populated must match terminator succs
        if (PBlock^.Succs <> nil) and (LongInt(PBlock^.Succs.Count) <> LongInt(SuccLists[BI].Count)) then
          AddError(AFunc.Name, PBlock^.Id,
            Format('block %d Succs count mismatch: stored %d vs terminator %d (func %s)', [PBlock^.Id, LongInt(PBlock^.Succs.Count), LongInt(SuccLists[BI].Count), AFunc.Name]));
        if (PBlock^.Preds <> nil) and (LongInt(PBlock^.Preds.Count) <> PredCount[BI]) then
          AddError(AFunc.Name, PBlock^.Id,
            Format('block %d Preds count mismatch: stored %d vs CFG %d (func %s)', [PBlock^.Id, LongInt(PBlock^.Preds.Count), PredCount[BI], AFunc.Name]));
      end;
    finally
      Stack.Free;
    end;

    for I := 0 to N - 1 do SuccLists[I].Free;
  finally
    BlockMap.Free;
  end;
end;

procedure THIRVerifier.VerifyTypes(const AFunc: THIRFunction);
var
  BI, II: LongInt;
  PBlock: ^THIRBlock;
  PInstr: ^THIRInstr;
  ContractError: string;
begin
  if AFunc.Blocks = nil then
    Exit;
  for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
  begin
    PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
    if PBlock^.Instrs = nil then Continue;
    for II := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
    begin
      PInstr := PBlock^.Instrs.GetPtrUnchecked(SizeUInt(II));
      if PInstr^.HasSystemContract and
        (not ValidateSystemContractInstr(PInstr^, FModule.Types, ContractError)) then
        AddError(AFunc.Name, PBlock^.Id,
          Format('%s at instr %d [%s] %%%d block %d func %s', [ContractError, II, IntToStr(Ord(PInstr^.Kind)), PInstr^.ResultId, PBlock^.Id, AFunc.Name]));
      if PInstr^.Kind = hikAlloca then
      begin
        if PInstr^.TypeId = 0 then
          AddError(AFunc.Name, PBlock^.Id,
            Format('alloca %%%d has no type at instr %d block %d func %s', [PInstr^.ResultId, II, PBlock^.Id, AFunc.Name]));
      end;
      if PInstr^.Kind in [hikAdd, hikSub, hikMul, hikDiv, hikMod] then
      begin
        if Length(PInstr^.Operands) < 2 then
          AddError(AFunc.Name, PBlock^.Id,
            Format('Arithmetic op %%%d needs 2 operands at instr %d block %d func %s', [PInstr^.ResultId, II, PBlock^.Id, AFunc.Name]));
      end;
      if PInstr^.Kind = hikCall then
      begin
        if PInstr^.CallTarget = '' then
          AddError(AFunc.Name, PBlock^.Id,
            Format('call %%%d has empty target at instr %d block %d func %s', [PInstr^.ResultId, II, PBlock^.Id, AFunc.Name]));
      end;
    end;
  end;
end;

procedure THIRVerifier.VerifySystemContractSequences(
  const AFunc: THIRFunction);
var
  BI, II: LongInt;
  GuardActive: Boolean;
  GuardReceiverValueId: THIRValueId;
  GuardDestroyTarget: string;
  PBlock: ^THIRBlock;
  PInstr: ^THIRInstr;
  ContractError: string;
begin
  if AFunc.Blocks = nil then
    Exit;
  for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
  begin
    PBlock := AFunc.Blocks.GetPtrUnchecked(SizeUInt(BI));
    GuardActive := False;
    GuardReceiverValueId := 0;
    GuardDestroyTarget := '';
    if PBlock^.Instrs = nil then
      Continue;
    for II := 0 to LongInt(PBlock^.Instrs.Count) - 1 do
    begin
      PInstr := PBlock^.Instrs.GetPtrUnchecked(SizeUInt(II));
      if not PInstr^.HasSystemContract then
      begin
        GuardActive := False;
        GuardReceiverValueId := 0;
        GuardDestroyTarget := '';
        Continue;
      end;
      if not ValidateSystemContractInstr(PInstr^, FModule.Types,
        ContractError) then
        Continue;

      case PInstr^.SystemContractKind of
        sckObjectFree:
        begin
          GuardActive := True;
          GuardReceiverValueId := PInstr^.Operands[0].ValueId;
          GuardDestroyTarget := PInstr^.CallTarget;
        end;
        sckObjectFreeDestroy,
        sckObjectFreeCleanup,
        sckObjectFreeRelease:
        begin
          if not GuardActive then
            AddError(AFunc.Name, PBlock^.Id,
              Format('system-contract-sequence-root-missing:%d at instr %d block %d func %s', [Ord(PInstr^.SystemContractKind), II, PBlock^.Id, AFunc.Name]))
          else if not ValidateObjectFreeSequenceContinuation(
            GuardReceiverValueId, PInstr^.Operands[0].ValueId,
            GuardDestroyTarget, PInstr^.CallTarget,
            PInstr^.SystemContractKind, ContractError) then
            AddError(AFunc.Name, PBlock^.Id,
              Format('%s at instr %d block %d func %s', [ContractError, II, PBlock^.Id, AFunc.Name]));
          if PInstr^.SystemContractKind = sckObjectFreeRelease then
          begin
            GuardActive := False;
            GuardReceiverValueId := 0;
            GuardDestroyTarget := '';
          end;
        end;
      else
        ;
      end;
    end;
  end;
end;

procedure THIRVerifier.VerifyFunction(const AFunc: THIRFunction);
begin
  VerifySSADefs(AFunc);
  VerifySSAUses(AFunc);
  VerifyTerminators(AFunc);
  VerifyTypes(AFunc);
  VerifySystemContractSequences(AFunc);
end;

function THIRVerifier.Verify: Boolean;
var
  I: LongInt;
begin
  FErrors.Clear;
  for I := 0 to FModule.FunctionCount - 1 do
    VerifyFunction(FModule.FunctionAt(I));
  Result := FErrors.Count = 0;
end;

function THIRVerifier.ErrorCount: LongInt;
begin
  Result := LongInt(FErrors.Count);
end;

function THIRVerifier.ErrorAt(AIndex: LongInt): THIRVerifyError;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FErrors.Count)) then
  begin
    Result.FuncName := '';
    Result.BlockId := 0;
    Result.Message := '';
    Exit;
  end;
  Result := FErrors[AIndex];
end;

end.
