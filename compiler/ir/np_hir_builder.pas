unit np_hir_builder;

{$mode objfpc}{$H+}

interface

uses
  np_semantic_model, np_hir_types, np_hir_model;

type
  THIRBuilder = class
  private
    FSemaModel: TSemanticModel;
    FModule: THIRModule;
    FCurrentFuncId: THIRFuncId;
    FCurrentBlockId: THIRBlockId;
    FBlockTerminated: Boolean;
    FSavedFuncId: THIRFuncId;
    FSavedBlockId: THIRBlockId;
    FSavedAllocaNames: array of string;
    FSavedAllocaValues: array of THIRValueId;
    FSavedAllocaCount: LongInt;
    FSavedBlockNames: array of string;
    FSavedBlockIds: array of THIRBlockId;
    FSavedBlockCount: LongInt;

    FAllocaNames: array of string;
    FAllocaValues: array of THIRValueId;
    FAllocaCount: LongInt;

    FBlockNames: array of string;
    FBlockIds: array of THIRBlockId;
    FBlockCount: LongInt;

    function EnsureBlock(const AName: string): THIRBlockId;
    function FindBlock(const AName: string): THIRBlockId;
    procedure EnsureAlloca(const AName: string; AType: THIRTypeId);
    function FindAlloca(const AName: string): THIRValueId;
    function GetIntType: THIRTypeId;
    function GetBoolType: THIRTypeId;
    function GetStringType: THIRTypeId;
    function GetPtrType: THIRTypeId;

    procedure EmitInstr(const AInstr: THIRInstr);
    function EmitBinOp(AKind: THIRInstrKind; AType: THIRTypeId;
      ALhs, ARhs: THIRValueId): THIRValueId;
    function EmitLoad(AType: THIRTypeId; AAddr: THIRValueId): THIRValueId;
    procedure EmitStore(AType: THIRTypeId; AVal, AAddr: THIRValueId);

    function ParseIntBlob(const ABlob: string): THIRValueId;
    procedure ProcessNode(const ANode: TTypedHirNode);
    procedure ProcessVarDecl(const ANode: TTypedHirNode);
    procedure ProcessAssign(const ANode: TTypedHirNode);
    procedure ProcessHaltCall(const ANode: TTypedHirNode);
    procedure ProcessHaltCallConst(const ANode: TTypedHirNode);
    procedure ProcessCondBr(const ANode: TTypedHirNode);
    procedure ProcessBr(const ANode: TTypedHirNode);
    procedure ProcessBlockLabel(const ANode: TTypedHirNode);
    procedure ProcessFunctionBegin(const ANode: TTypedHirNode);
    procedure ProcessFunctionEnd(const ANode: TTypedHirNode);
    procedure ProcessRetRuntime(const ANode: TTypedHirNode);
    procedure ProcessCallRuntime(const ANode: TTypedHirNode);
    procedure ProcessWriteInt(const ANode: TTypedHirNode);
    procedure ProcessWriteStr(const ANode: TTypedHirNode);
    procedure ProcessWriteStrVar(const ANode: TTypedHirNode);
  public
    constructor Create(ASemaModel: TSemanticModel);
    destructor Destroy; override;
    procedure Build;
    function Module: THIRModule;
  end;

implementation

uses
  SysUtils;

var
  GIntType: THIRTypeId = 0;
  GBoolType: THIRTypeId = 0;
  GStringType: THIRTypeId = 0;
  GPtrType: THIRTypeId = 0;

constructor THIRBuilder.Create(ASemaModel: TSemanticModel);
begin
  inherited Create;
  FSemaModel := ASemaModel;
  FModule := THIRModule.Create('main');
  FCurrentFuncId := 0;
  FCurrentBlockId := 0;
  FBlockTerminated := False;
  FAllocaCount := 0;
  FBlockCount := 0;
  SetLength(FAllocaNames, 0);
  SetLength(FAllocaValues, 0);
  SetLength(FBlockNames, 0);
  SetLength(FBlockIds, 0);
end;

destructor THIRBuilder.Destroy;
begin
  inherited Destroy;
end;

function THIRBuilder.FindBlock(const AName: string): THIRBlockId;
var
  I: LongInt;
begin
  for I := 0 to FBlockCount - 1 do
    if FBlockNames[I] = AName then
      Exit(FBlockIds[I]);
  Result := 0;
end;

function THIRBuilder.EnsureBlock(const AName: string): THIRBlockId;
begin
  Result := FindBlock(AName);
  if Result <> 0 then Exit;
  if FCurrentFuncId = 0 then Exit(0);

  Result := FModule.AddBlock(FCurrentFuncId, AName);
  if FBlockCount >= Length(FBlockNames) then
  begin
    SetLength(FBlockNames, FBlockCount + 32);
    SetLength(FBlockIds, FBlockCount + 32);
  end;
  FBlockNames[FBlockCount] := AName;
  FBlockIds[FBlockCount] := Result;
  Inc(FBlockCount);
end;

function THIRBuilder.Module: THIRModule;
begin
  Result := FModule;
end;

function THIRBuilder.GetIntType: THIRTypeId;
begin
  if GIntType = 0 then
    GIntType := FModule.Types.AddIntType(64, True);
  Result := GIntType;
end;

function THIRBuilder.GetBoolType: THIRTypeId;
begin
  if GBoolType = 0 then
    GBoolType := FModule.Types.AddType(htkBool, 'bool');
  Result := GBoolType;
end;

function THIRBuilder.GetStringType: THIRTypeId;
begin
  if GStringType = 0 then
    GStringType := FModule.Types.AddStringType(skAnsi);
  Result := GStringType;
end;

function THIRBuilder.GetPtrType: THIRTypeId;
begin
  if GPtrType = 0 then
    GPtrType := FModule.Types.AddPointerType(0);
  Result := GPtrType;
end;

procedure THIRBuilder.EnsureAlloca(const AName: string; AType: THIRTypeId);
var
  Instr: THIRInstr;
begin
  if FindAlloca(AName) <> 0 then Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := AType;
  EmitInstr(Instr);

  if FAllocaCount >= Length(FAllocaNames) then
  begin
    SetLength(FAllocaNames, FAllocaCount + 32);
    SetLength(FAllocaValues, FAllocaCount + 32);
  end;
  FAllocaNames[FAllocaCount] := AName;
  FAllocaValues[FAllocaCount] := Instr.ResultId;
  Inc(FAllocaCount);
end;

function THIRBuilder.FindAlloca(const AName: string): THIRValueId;
var
  I: LongInt;
begin
  for I := 0 to FAllocaCount - 1 do
    if FAllocaNames[I] = AName then
      Exit(FAllocaValues[I]);
  Result := 0;
end;

procedure THIRBuilder.EmitInstr(const AInstr: THIRInstr);
begin
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
    FModule.AddInstr(FCurrentFuncId, FCurrentBlockId, AInstr);
end;

function THIRBuilder.EmitBinOp(AKind: THIRInstrKind; AType: THIRTypeId;
  ALhs, ARhs: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := AKind;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ALhs);
  Instr.Operands[1] := MakeOperand(ARhs);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitLoad(AType: THIRTypeId;
  AAddr: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeOperand(AAddr);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

procedure THIRBuilder.EmitStore(AType: THIRTypeId;
  AVal, AAddr: THIRValueId);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikStore;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(AVal);
  Instr.Operands[1] := MakeOperand(AAddr);
  EmitInstr(Instr);
end;

function THIRBuilder.ParseIntBlob(const ABlob: string): THIRValueId;
var
  Stack: array of THIRValueId;
  StackCount: LongInt;
  Lines: array of string;
  LineCount, I, SpacePos: LongInt;
  Line, Token, Arg: string;
  Lhs, Rhs, V: THIRValueId;
  Instr: THIRInstr;
  ArgCount, J: LongInt;
  CallArgs: array of THIRValueId;

  procedure Push(AVal: THIRValueId);
  begin
    if StackCount >= Length(Stack) then
      SetLength(Stack, StackCount + 16);
    Stack[StackCount] := AVal;
    Inc(StackCount);
  end;

  function Pop: THIRValueId;
  begin
    if StackCount = 0 then Exit(0);
    Dec(StackCount);
    Result := Stack[StackCount];
  end;

begin
  Result := 0;
  StackCount := 0;
  SetLength(Stack, 0);

  SetLength(Lines, 0);
  LineCount := 0;
  Line := '';
  for I := 1 to Length(ABlob) do
  begin
    if ABlob[I] = #10 then
    begin
      if Line <> '' then
      begin
        if LineCount >= Length(Lines) then
          SetLength(Lines, LineCount + 16);
        Lines[LineCount] := Line;
        Inc(LineCount);
      end;
      Line := '';
    end
    else
      Line := Line + ABlob[I];
  end;
  if Line <> '' then
  begin
    if LineCount >= Length(Lines) then
      SetLength(Lines, LineCount + 16);
    Lines[LineCount] := Line;
    Inc(LineCount);
  end;

  for I := 0 to LineCount - 1 do
  begin
    Line := Lines[I];
    SpacePos := Pos(' ', Line);
    if SpacePos > 0 then
    begin
      Token := Copy(Line, 1, SpacePos - 1);
      Arg := Copy(Line, SpacePos + 1, Length(Line));
    end
    else
    begin
      Token := Line;
      Arg := '';
    end;

    if Token = 'int' then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'const:' + Arg;
      EmitInstr(Instr);
      Push(Instr.ResultId);
    end
    else if Token = 'var' then
    begin
      V := FindAlloca(Arg);
      if V <> 0 then
        Push(EmitLoad(GetIntType, V))
      else
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikCall;
        Instr.TypeId := GetIntType;
        Instr.CallTarget := Arg;
        EmitInstr(Instr);
        Push(Instr.ResultId);
      end;
    end
    else if Token = 'add' then
    begin
      Rhs := Pop; Lhs := Pop;
      Push(EmitBinOp(hikAdd, GetIntType, Lhs, Rhs));
    end
    else if Token = 'sub' then
    begin
      Rhs := Pop; Lhs := Pop;
      Push(EmitBinOp(hikSub, GetIntType, Lhs, Rhs));
    end
    else if Token = 'mul' then
    begin
      Rhs := Pop; Lhs := Pop;
      Push(EmitBinOp(hikMul, GetIntType, Lhs, Rhs));
    end
    else if Token = 'div' then
    begin
      Rhs := Pop; Lhs := Pop;
      Push(EmitBinOp(hikDiv, GetIntType, Lhs, Rhs));
    end
    else if Token = 'mod' then
    begin
      Rhs := Pop; Lhs := Pop;
      Push(EmitBinOp(hikMod, GetIntType, Lhs, Rhs));
    end
    else if Token = 'neg' then
    begin
      Rhs := Pop;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikNeg;
      Instr.TypeId := GetIntType;
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeOperand(Rhs);
      EmitInstr(Instr);
      Push(Instr.ResultId);
    end
    else if Token = 'cmp' then
    begin
      Rhs := Pop; Lhs := Pop;
      if Arg = 'eq' then
        Push(EmitBinOp(hikCmpEq, GetBoolType, Lhs, Rhs))
      else if Arg = 'ne' then
        Push(EmitBinOp(hikCmpNe, GetBoolType, Lhs, Rhs))
      else if Arg = 'slt' then
        Push(EmitBinOp(hikCmpLt, GetBoolType, Lhs, Rhs))
      else if Arg = 'sle' then
        Push(EmitBinOp(hikCmpLe, GetBoolType, Lhs, Rhs))
      else if Arg = 'sgt' then
        Push(EmitBinOp(hikCmpGt, GetBoolType, Lhs, Rhs))
      else if Arg = 'sge' then
        Push(EmitBinOp(hikCmpGe, GetBoolType, Lhs, Rhs));
    end
    else if Token = 'zext' then
    begin
      Rhs := Pop;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikZext;
      Instr.TypeId := GetIntType;
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeOperand(Rhs);
      EmitInstr(Instr);
      Push(Instr.ResultId);
    end
    else if Token = 'call' then
    begin
      SpacePos := Pos(' ', Arg);
      if SpacePos > 0 then
      begin
        Token := Copy(Arg, 1, SpacePos - 1);
        ArgCount := StrToIntDef(Copy(Arg, SpacePos + 1, Length(Arg)), 0);
      end
      else
      begin
        Token := Arg;
        ArgCount := 0;
      end;
      SetLength(CallArgs, ArgCount);
      for J := ArgCount - 1 downto 0 do
        CallArgs[J] := Pop;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikCall;
      Instr.TypeId := GetIntType;
      Instr.CallTarget := Token;
      SetLength(Instr.Operands, ArgCount);
      for J := 0 to ArgCount - 1 do
        Instr.Operands[J] := MakeOperand(CallArgs[J]);
      EmitInstr(Instr);
      Push(Instr.ResultId);
    end
    else if Token = 'arrload' then
    begin
      Rhs := Pop;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'arrload:' + Arg;
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeOperand(Rhs);
      EmitInstr(Instr);
      Push(Instr.ResultId);
    end;
  end;

  if StackCount > 0 then
    Result := Pop;
end;

procedure THIRBuilder.ProcessVarDecl(const ANode: TTypedHirNode);
begin
  if ANode.Kind = 'var-decl-runtime' then
    EnsureAlloca(ANode.Operand, GetIntType)
  else if ANode.Kind = 'var-decl-str-runtime' then
  begin
    EnsureAlloca(ANode.Operand + '$ptr', GetPtrType);
    EnsureAlloca(ANode.Operand + '$len', GetIntType);
  end
  else if ANode.Kind = 'var-decl-arr-runtime' then
  begin
    EnsureAlloca(ANode.Operand + '$ptr', GetPtrType);
    EnsureAlloca(ANode.Operand + '$len', GetIntType);
  end;
end;

procedure THIRBuilder.ProcessAssign(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Blob: string;
  V, Addr: THIRValueId;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Blob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  V := ParseIntBlob(Blob);
  Addr := FindAlloca(VarName);
  if (V <> 0) and (Addr <> 0) then
    EmitStore(GetIntType, V, Addr);
end;

procedure THIRBuilder.ProcessHaltCall(const ANode: TTypedHirNode);
var
  V: THIRValueId;
  Instr: THIRInstr;
begin
  V := ParseIntBlob(ANode.Operand);
  if V <> 0 then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'halt';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeOperand(V);
    EmitInstr(Instr);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessHaltCallConst(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'halt';
  Instr.CallTarget := ANode.Operand;
  EmitInstr(Instr);
  FBlockTerminated := True;
end;

procedure THIRBuilder.ProcessCondBr(const ANode: TTypedHirNode);
var
  Term: THIRTerminator;
  V: THIRValueId;
  Blob, LabelPart, ThenLabel, ElseLabel: string;
  TabPos, NlPos: LongInt;
begin
  Blob := ANode.Operand;
  NlPos := Pos('labels ', Blob);
  if NlPos = 0 then Exit;

  LabelPart := Copy(Blob, NlPos + 7, Length(Blob));
  TabPos := Pos(#9, LabelPart);
  if TabPos > 0 then
  begin
    ThenLabel := Copy(LabelPart, 1, TabPos - 1);
    ElseLabel := Copy(LabelPart, TabPos + 1, Length(LabelPart));
    if (Length(ElseLabel) > 0) and (ElseLabel[Length(ElseLabel)] = #10) then
      ElseLabel := Copy(ElseLabel, 1, Length(ElseLabel) - 1);
  end
  else
    Exit;

  V := ParseIntBlob(Copy(Blob, 1, NlPos - 1));

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkCondBranch;
  Term.Condition := V;
  Term.TrueBlock := EnsureBlock(ThenLabel);
  Term.FalseBlock := EnsureBlock(ElseLabel);
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessBr(const ANode: TTypedHirNode);
var
  Term: THIRTerminator;
  Target: string;
begin
  Target := ANode.Operand;
  if (Length(Target) > 0) and (Target[Length(Target)] = #10) then
    Target := Copy(Target, 1, Length(Target) - 1);

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkBranch;
  Term.TargetBlock := EnsureBlock(Target);
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessBlockLabel(const ANode: TTypedHirNode);
var
  NewBlock: THIRBlockId;
  Term: THIRTerminator;
begin
  if FCurrentFuncId = 0 then Exit;
  NewBlock := EnsureBlock(ANode.Operand);

  if (FCurrentBlockId <> 0) and (not FBlockTerminated) then
  begin
    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkBranch;
    Term.TargetBlock := NewBlock;
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
  end;

  FCurrentBlockId := NewBlock;
  FBlockTerminated := False;
end;

procedure THIRBuilder.ProcessFunctionBegin(const ANode: TTypedHirNode);
var
  TabPos, ColonPos, Pos2, Pos3: LongInt;
  FuncName, Rest, ParamCountStr, ParamName: string;
  EntryBlock: THIRBlockId;
  I, ParamCount, SearchFrom: LongInt;
  ParamValueId: THIRValueId;
  Instr: THIRInstr;
begin
  FSavedFuncId := FCurrentFuncId;
  FSavedBlockId := FCurrentBlockId;
  FSavedAllocaCount := FAllocaCount;
  SetLength(FSavedAllocaNames, FAllocaCount);
  SetLength(FSavedAllocaValues, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
  begin
    FSavedAllocaNames[I] := FAllocaNames[I];
    FSavedAllocaValues[I] := FAllocaValues[I];
  end;
  FSavedBlockCount := FBlockCount;
  SetLength(FSavedBlockNames, FBlockCount);
  SetLength(FSavedBlockIds, FBlockCount);
  for I := 0 to FBlockCount - 1 do
  begin
    FSavedBlockNames[I] := FBlockNames[I];
    FSavedBlockIds[I] := FBlockIds[I];
  end;

  TabPos := Pos(#9, ANode.Operand);
  ColonPos := Pos(':', ANode.Operand);

  if TabPos > 0 then
  begin
    FuncName := Copy(ANode.Operand, 1, TabPos - 1);
    Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

    ParamCount := 0;
    if Rest <> '' then
    begin
      Pos2 := Pos(#9, Rest);
      if Pos2 > 0 then
      begin
        Rest := Copy(Rest, Pos2 + 1, Length(Rest));
        Pos3 := Pos(#9, Rest);
        if Pos3 > 0 then
        begin
          ParamCountStr := Copy(Rest, 1, Pos3 - 1);
          ParamCount := StrToIntDef(ParamCountStr, 0);
          Rest := Copy(Rest, Pos3 + 1, Length(Rest));
        end;
      end;
    end;

    FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);

    for I := 0 to ParamCount - 1 do
    begin
      SearchFrom := Pos(#9, Rest);
      if SearchFrom > 0 then
      begin
        ParamName := Copy(Rest, 1, SearchFrom - 1);
        Rest := Copy(Rest, SearchFrom + 1, Length(Rest));
      end
      else
      begin
        ParamName := Rest;
        Rest := '';
      end;
      FModule.AddFunctionParam(FCurrentFuncId, ParamName, GetIntType, False, False);
    end;

    EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
    FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
    FCurrentBlockId := EntryBlock;
    FBlockTerminated := False;
    FAllocaCount := 0;
    FBlockCount := 0;

    for I := 0 to ParamCount - 1 do
    begin
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[I].ValueId;
      ParamName := FModule.FunctionAt(FModule.FunctionCount - 1).Params[I].Name;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetIntType;
      EmitInstr(Instr);

      if FAllocaCount >= Length(FAllocaNames) then
      begin
        SetLength(FAllocaNames, FAllocaCount + 32);
        SetLength(FAllocaValues, FAllocaCount + 32);
      end;
      FAllocaNames[FAllocaCount] := ParamName;
      FAllocaValues[FAllocaCount] := Instr.ResultId;
      Inc(FAllocaCount);

      EmitStore(GetIntType, ParamValueId, Instr.ResultId);
    end;
  end
  else
  begin
    FuncName := ANode.DisplayName;
    ParamCount := 0;
    if ColonPos > 0 then
      ParamCount := StrToIntDef(Copy(ANode.Operand, 1, ColonPos - 1), 0);

    FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);

    EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
    FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
    FCurrentBlockId := EntryBlock;
    FBlockTerminated := False;
    FAllocaCount := 0;
    FBlockCount := 0;
  end;
end;

procedure THIRBuilder.ProcessFunctionEnd(const ANode: TTypedHirNode);
var
  I: LongInt;
begin
  FCurrentFuncId := FSavedFuncId;
  FCurrentBlockId := FSavedBlockId;
  FAllocaCount := FSavedAllocaCount;
  for I := 0 to FSavedAllocaCount - 1 do
  begin
    FAllocaNames[I] := FSavedAllocaNames[I];
    FAllocaValues[I] := FSavedAllocaValues[I];
  end;
  FBlockCount := FSavedBlockCount;
  for I := 0 to FSavedBlockCount - 1 do
  begin
    FBlockNames[I] := FSavedBlockNames[I];
    FBlockIds[I] := FSavedBlockIds[I];
  end;
end;

procedure THIRBuilder.ProcessRetRuntime(const ANode: TTypedHirNode);
var
  V: THIRValueId;
  Term: THIRTerminator;
begin
  V := ParseIntBlob(ANode.Operand);
  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkReturn;
  Term.ReturnValue := V;
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
    FBlockTerminated := True;
  end;
end;

procedure THIRBuilder.ProcessCallRuntime(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  TabPos: LongInt;
  FuncName, Rest, ArgBlob: string;
  ArgValue: THIRValueId;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    FuncName := Copy(ANode.Operand, 1, TabPos - 1);
    Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end
  else
  begin
    FuncName := ANode.Operand;
    Rest := '';
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := FuncName;

  while Rest <> '' do
  begin
    TabPos := Pos(#9, Rest);
    if TabPos > 0 then
    begin
      ArgBlob := Copy(Rest, 1, TabPos - 1);
      Rest := Copy(Rest, TabPos + 1, Length(Rest));
    end
    else
    begin
      ArgBlob := Rest;
      Rest := '';
    end;
    ArgValue := ParseIntBlob(ArgBlob);
    if ArgValue <> 0 then
    begin
      SetLength(Instr.Operands, Length(Instr.Operands) + 1);
      Instr.Operands[High(Instr.Operands)] := MakeOperand(ArgValue);
    end;
  end;

  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessWriteInt(const ANode: TTypedHirNode);
var
  V: THIRValueId;
  Instr: THIRInstr;
begin
  V := ParseIntBlob(ANode.Operand);
  if V <> 0 then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'write_int';
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeOperand(V);
    EmitInstr(Instr);
  end;
end;

procedure THIRBuilder.ProcessWriteStr(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'write_str';
  Instr.CallTarget := ANode.Operand;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessWriteStrVar(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  PtrVal, LenVal: THIRValueId;
begin
  PtrVal := FindAlloca(ANode.Operand + '$ptr');
  LenVal := FindAlloca(ANode.Operand + '$len');
  if (PtrVal = 0) or (LenVal = 0) then Exit;

  PtrVal := EmitLoad(GetPtrType, PtrVal);
  LenVal := EmitLoad(GetIntType, LenVal);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'write_str_var';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(PtrVal);
  Instr.Operands[1] := MakeOperand(LenVal);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessNode(const ANode: TTypedHirNode);
begin
  if (ANode.Kind = 'var-decl-runtime') or
     (ANode.Kind = 'var-decl-str-runtime') or
     (ANode.Kind = 'var-decl-arr-runtime') then
    ProcessVarDecl(ANode)
  else if ANode.Kind = 'assign-runtime' then
    ProcessAssign(ANode)
  else if ANode.Kind = 'halt-call-runtime' then
    ProcessHaltCall(ANode)
  else if ANode.Kind = 'halt-call' then
    ProcessHaltCallConst(ANode)
  else if ANode.Kind = 'cond-br-runtime' then
    ProcessCondBr(ANode)
  else if ANode.Kind = 'br-runtime' then
    ProcessBr(ANode)
  else if ANode.Kind = 'block-label-runtime' then
    ProcessBlockLabel(ANode)
  else if ANode.Kind = 'function-body-begin' then
    ProcessFunctionBegin(ANode)
  else if ANode.Kind = 'function-body-end' then
    ProcessFunctionEnd(ANode)
  else if ANode.Kind = 'ret-runtime' then
    ProcessRetRuntime(ANode)
  else if ANode.Kind = 'call-runtime' then
    ProcessCallRuntime(ANode)
  else if ANode.Kind = 'write-int-runtime' then
    ProcessWriteInt(ANode)
  else if ANode.Kind = 'write-string-runtime' then
    ProcessWriteStr(ANode)
  else if ANode.Kind = 'write-str-var-runtime' then
    ProcessWriteStrVar(ANode)
  else if ANode.Kind = 'write-call' then
    ProcessWriteStr(ANode);
end;

procedure THIRBuilder.Build;
var
  I: LongInt;
  Node: TTypedHirNode;
  EntryBlock: THIRBlockId;
  Instr: THIRInstr;
begin
  FCurrentFuncId := FModule.AddFunction('_start', GetIntType);
  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FBlockTerminated := False;

  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    ProcessNode(Node);
  end;

  if not FBlockTerminated then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'halt';
    Instr.CallTarget := '0';
    EmitInstr(Instr);
  end;
end;

end.
