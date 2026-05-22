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
    FSavedAllocaTypes: array of THIRTypeId;
    FSavedAllocaCount: LongInt;
    FSavedVarParamFlags: array of Boolean;
    FSavedBlockNames: array of string;
    FSavedBlockIds: array of THIRBlockId;
    FSavedBlockCount: LongInt;
    FPendingParamCount: LongInt;
    FPendingParamLlvmIdx: LongInt;
    FSretValueId: THIRValueId;

    FAllocaNames: array of string;
    FAllocaValues: array of THIRValueId;
    FAllocaTypes: array of THIRTypeId;
    FAllocaCount: LongInt;
    FRecordAllocaSlots: array of LongInt;
    FVarParamFlags: array of Boolean;

    FGlobalNames: array of string;
    FGlobalTypes: array of THIRTypeId;
    FGlobalCount: LongInt;
    FInStartFunc: Boolean;

    FBlockNames: array of string;
    FBlockIds: array of THIRBlockId;
    FBlockCount: LongInt;

    FFwdFuncNames: array of string;
    FFwdFuncRetTypes: array of THIRTypeId;
    FFwdFuncCount: LongInt;

    function EnsureBlock(const AName: string): THIRBlockId;
    function FindBlock(const AName: string): THIRBlockId;
    procedure EnsureAlloca(const AName: string; AType: THIRTypeId);
    function FindAlloca(const AName: string): THIRValueId;
    function FindAllocaType(const AName: string): THIRTypeId;
    function IsVarParamAlloca(const AName: string): Boolean;
    function GetIntType: THIRTypeId;
    function GetBoolType: THIRTypeId;
    function GetStringType: THIRTypeId;
    function GetPtrType: THIRTypeId;

    procedure EmitInstr(const AInstr: THIRInstr);
    function EmitBinOp(AKind: THIRInstrKind; AType: THIRTypeId;
      ALhs, ARhs: THIRValueId): THIRValueId;
    function EmitCmpOp(AKind: THIRInstrKind; AType: THIRTypeId;
      ALhs, ARhs: THIRValueId; ALhsType, ARhsType: THIRTypeId): THIRValueId;
    function EmitLoad(AType: THIRTypeId; AAddr: THIRValueId): THIRValueId;
    procedure EmitStore(AType: THIRTypeId; AVal, AAddr: THIRValueId);

    function ParseIntBlob(const ABlob: string): THIRValueId;
    procedure ProcessNode(const ANode: TTypedHirNode);
    procedure ProcessVarDecl(const ANode: TTypedHirNode);
    procedure ProcessAssign(const ANode: TTypedHirNode);
    procedure ProcessHaltCall(const ANode: TTypedHirNode);
    procedure ProcessHaltCallConst(const ANode: TTypedHirNode);
    procedure ProcessCondBr(const ANode: TTypedHirNode);
    procedure ProcessSwitch(const ANode: TTypedHirNode);
    procedure ProcessBr(const ANode: TTypedHirNode);
    procedure ProcessBlockLabel(const ANode: TTypedHirNode);
    procedure ProcessFunctionBegin(const ANode: TTypedHirNode);
    procedure ProcessFunctionEnd(const ANode: TTypedHirNode);
    procedure ProcessRetRuntime(const ANode: TTypedHirNode);
    procedure ProcessCallRuntime(const ANode: TTypedHirNode);
    procedure ProcessWriteInt(const ANode: TTypedHirNode);
    procedure ProcessWriteStr(const ANode: TTypedHirNode);
    procedure ProcessWriteStrVar(const ANode: TTypedHirNode);
    procedure ProcessAssignStr(const ANode: TTypedHirNode);
    procedure ProcessAssignStrCopy(const ANode: TTypedHirNode);
    procedure ProcessAssignStrCall(const ANode: TTypedHirNode);
    procedure ProcessAssignStrVcall(const ANode: TTypedHirNode);
    procedure ProcessAssignStrConcat(const ANode: TTypedHirNode);
    procedure ProcessRetStrRuntime(const ANode: TTypedHirNode);
    procedure ProcessSetLengthArr(const ANode: TTypedHirNode);
    procedure ProcessAssignArrElem(const ANode: TTypedHirNode);
    procedure ProcessMethodBegin(const ANode: TTypedHirNode);
    procedure ProcessClassNew(const ANode: TTypedHirNode);
    procedure ProcessFieldStore(const ANode: TTypedHirNode);
    procedure ProcessFieldStoreStr(const ANode: TTypedHirNode);
    procedure ProcessRecordFieldStore(const ANode: TTypedHirNode);
    procedure ProcessRecordCopy(const ANode: TTypedHirNode);
    procedure ProcessAssignStrFieldLoad(const ANode: TTypedHirNode);
    procedure ProcessVmtStore(const ANode: TTypedHirNode);
    procedure EnsureVmtForClass(const AClassName: string);
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
  FGlobalCount := 0;
  FInStartFunc := True;
  FPendingParamCount := 0;
  FPendingParamLlvmIdx := 0;
  SetLength(FAllocaNames, 0);
  SetLength(FAllocaValues, 0);
  SetLength(FRecordAllocaSlots, 0);
  SetLength(FVarParamFlags, 0);
  SetLength(FGlobalNames, 0);
  SetLength(FGlobalTypes, 0);
  SetLength(FBlockNames, 0);
  SetLength(FBlockIds, 0);
  FFwdFuncCount := 0;
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
    SetLength(FAllocaTypes, FAllocaCount + 32);
    SetLength(FRecordAllocaSlots, FAllocaCount + 32);
    SetLength(FVarParamFlags, FAllocaCount + 32);
  end;
  FAllocaNames[FAllocaCount] := AName;
  FAllocaValues[FAllocaCount] := Instr.ResultId;
  FAllocaTypes[FAllocaCount] := AType;
  FRecordAllocaSlots[FAllocaCount] := 0;
  FVarParamFlags[FAllocaCount] := False;
  Inc(FAllocaCount);
end;

function THIRBuilder.FindAlloca(const AName: string): THIRValueId;
var
  I: LongInt;
  Instr: THIRInstr;
begin
  for I := 0 to FAllocaCount - 1 do
    if SameText(FAllocaNames[I], AName) then
      Exit(FAllocaValues[I]);
  for I := 0 to FGlobalCount - 1 do
    if SameText(FGlobalNames[I], AName) then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'global_ref';
      Instr.CallTarget := AName;
      EmitInstr(Instr);
      Exit(Instr.ResultId);
    end;
  Result := 0;
end;

function THIRBuilder.FindAllocaType(const AName: string): THIRTypeId;
var
  I: LongInt;
begin
  for I := 0 to FAllocaCount - 1 do
    if SameText(FAllocaNames[I], AName) then
      Exit(FAllocaTypes[I]);
  Result := 0;
end;

function THIRBuilder.IsVarParamAlloca(const AName: string): Boolean;
var
  I: LongInt;
begin
  for I := 0 to FAllocaCount - 1 do
    if SameText(FAllocaNames[I], AName) then
      Exit(FVarParamFlags[I]);
  Result := False;
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

function THIRBuilder.EmitCmpOp(AKind: THIRInstrKind; AType: THIRTypeId;
  ALhs, ARhs: THIRValueId; ALhsType, ARhsType: THIRTypeId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := AKind;
  Instr.TypeId := AType;
  SetLength(Instr.Operands, 2);
  if (ALhsType <> 0) and (ALhsType = GetPtrType) then
    Instr.Operands[0] := MakeTypedOperand(ALhs, GetPtrType)
  else
    Instr.Operands[0] := MakeOperand(ALhs);
  if (ARhsType <> 0) and (ARhsType = GetPtrType) then
    Instr.Operands[1] := MakeTypedOperand(ARhs, GetPtrType)
  else
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
  StackTypes: array of THIRTypeId;
  StackCount: LongInt;
  Lines: array of string;
  LineCount, I, SpacePos: LongInt;
  Line, Token, Arg: string;
  Lhs, Rhs, V: THIRValueId;
  Instr: THIRInstr;
  ArgCount, J: LongInt;
  CallArgs: array of THIRValueId;
  CallArgTypes: array of THIRTypeId;
  ConstVal: Int64;
  SlotIdx, ExtraArgCount, VcallI: LongInt;
  VcallArgs: array of THIRValueId;
  VcallArgTypes: array of THIRTypeId;
  CmpLhsType, CmpRhsType: THIRTypeId;
  RecName: string;
  FieldIdx, ValCode: LongInt;
  IdxVal: THIRValueId;

  procedure Push(AVal: THIRValueId);
  begin
    if StackCount >= Length(Stack) then
    begin
      SetLength(Stack, StackCount + 16);
      SetLength(StackTypes, StackCount + 16);
    end;
    Stack[StackCount] := AVal;
    StackTypes[StackCount] := 0;
    Inc(StackCount);
  end;

  procedure PushTyped(AVal: THIRValueId; AType: THIRTypeId);
  begin
    if StackCount >= Length(Stack) then
    begin
      SetLength(Stack, StackCount + 16);
      SetLength(StackTypes, StackCount + 16);
    end;
    Stack[StackCount] := AVal;
    StackTypes[StackCount] := AType;
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
    else if Token = 'null' then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'null';
      EmitInstr(Instr);
      PushTyped(Instr.ResultId, GetPtrType);
    end
    else if Token = 'var' then
    begin
      V := FindAlloca(Arg);
      if (V = 0) and (Pos('.', Arg) > 0) then
      begin
        EnsureAlloca(Arg, GetIntType);
        V := FindAlloca(Arg);
      end;
      if V <> 0 then
      begin
        if IsVarParamAlloca(Arg) then
        begin
          V := EmitLoad(GetPtrType, V);
          Push(EmitLoad(GetIntType, V));
        end
        else if FindAllocaType(Arg) = GetPtrType then
          PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
        else
          Push(EmitLoad(GetIntType, V));
      end
      else if FSemaModel.LookupConstValue(Arg, ConstVal) then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikLoad;
        Instr.TypeId := GetIntType;
        Instr.IntrinsicName := 'const:' + IntToStr(ConstVal);
        EmitInstr(Instr);
        Push(Instr.ResultId);
      end
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
    else if Token = 'varref' then
    begin
      V := FindAlloca(Arg);
      if V <> 0 then
      begin
        if IsVarParamAlloca(Arg) then
          PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
        else
          PushTyped(V, GetPtrType);
      end;
    end
    else if Token = 'recvar' then
    begin
      V := FindAlloca(Arg);
      if V <> 0 then
        PushTyped(V, GetPtrType);
    end
    else if Token = 'is' then
    begin
      Rhs := Pop;
      EnsureVmtForClass(Arg);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'const:0';
      EmitInstr(Instr);
      V := Instr.ResultId;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeOperand(Rhs);
      Instr.Operands[1] := MakeOperand(V);
      EmitInstr(Instr);
      V := EmitLoad(GetPtrType, Instr.ResultId);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'is_instance';
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeTypedOperand(V, GetPtrType);
      Instr.CallTarget := Arg;
      EmitInstr(Instr);
      Push(Instr.ResultId);
    end
    else if Token = 'rload' then
    begin
      SpacePos := Pos(' ', Arg);
      if SpacePos > 0 then
      begin
        RecName := Copy(Arg, 1, SpacePos - 1);
        Val(Copy(Arg, SpacePos + 1, Length(Arg)), FieldIdx, ValCode);
        if ValCode = 0 then
        begin
          V := FindAlloca(RecName);
          if V <> 0 then
          begin
            if FindAllocaType(RecName) = GetPtrType then
              V := EmitLoad(GetPtrType, V);

            FillChar(Instr, SizeOf(Instr), 0);
            Instr.ResultId := FModule.NewValue;
            Instr.Kind := hikLoad;
            Instr.TypeId := GetIntType;
            Instr.IntrinsicName := 'const:' + IntToStr(FieldIdx);
            EmitInstr(Instr);
            IdxVal := Instr.ResultId;

            FillChar(Instr, SizeOf(Instr), 0);
            Instr.ResultId := FModule.NewValue;
            Instr.Kind := hikIntrinsic;
            Instr.TypeId := GetPtrType;
            Instr.IntrinsicName := 'gep_i64';
            SetLength(Instr.Operands, 2);
            Instr.Operands[0] := MakeOperand(V);
            Instr.Operands[1] := MakeOperand(IdxVal);
            EmitInstr(Instr);

            Push(EmitLoad(GetIntType, Instr.ResultId));
          end;
        end;
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
      CmpRhsType := 0;
      if StackCount > 0 then CmpRhsType := StackTypes[StackCount - 1];
      Rhs := Pop;
      CmpLhsType := 0;
      if StackCount > 0 then CmpLhsType := StackTypes[StackCount - 1];
      Lhs := Pop;
      if Arg = 'eq' then
        Push(EmitCmpOp(hikCmpEq, GetBoolType, Lhs, Rhs, CmpLhsType, CmpRhsType))
      else if Arg = 'ne' then
        Push(EmitCmpOp(hikCmpNe, GetBoolType, Lhs, Rhs, CmpLhsType, CmpRhsType))
      else if Arg = 'slt' then
        Push(EmitCmpOp(hikCmpLt, GetBoolType, Lhs, Rhs, CmpLhsType, CmpRhsType))
      else if Arg = 'sle' then
        Push(EmitCmpOp(hikCmpLe, GetBoolType, Lhs, Rhs, CmpLhsType, CmpRhsType))
      else if Arg = 'sgt' then
        Push(EmitCmpOp(hikCmpGt, GetBoolType, Lhs, Rhs, CmpLhsType, CmpRhsType))
      else if Arg = 'sge' then
        Push(EmitCmpOp(hikCmpGe, GetBoolType, Lhs, Rhs, CmpLhsType, CmpRhsType));
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
      SetLength(CallArgTypes, ArgCount);
      for J := ArgCount - 1 downto 0 do
      begin
        Dec(StackCount);
        CallArgs[J] := Stack[StackCount];
        CallArgTypes[J] := StackTypes[StackCount];
      end;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikCall;
      Instr.TypeId := FModule.FindFunctionReturnType(Token);
      if Instr.TypeId = 0 then
      begin
        Instr.TypeId := GetIntType;
        for J := 0 to FFwdFuncCount - 1 do
          if FFwdFuncNames[J] = Token then
          begin
            Instr.TypeId := FFwdFuncRetTypes[J];
            Break;
          end;
      end;
      Instr.CallTarget := Token;
      SetLength(Instr.Operands, ArgCount);
      for J := 0 to ArgCount - 1 do
      begin
        if CallArgTypes[J] <> 0 then
          Instr.Operands[J] := MakeTypedOperand(CallArgs[J], CallArgTypes[J])
        else
          Instr.Operands[J] := MakeOperand(CallArgs[J]);
      end;
      EmitInstr(Instr);
      if FModule.Types.GetType(Instr.TypeId).Kind = htkPointer then
        PushTyped(Instr.ResultId, Instr.TypeId)
      else
        Push(Instr.ResultId);
    end
    else if Token = 'strvar' then
    begin
      V := FindAlloca(Arg + '$ptr');
      if V <> 0 then
        PushTyped(EmitLoad(GetPtrType, V), GetPtrType);
      V := FindAlloca(Arg + '$len');
      if V <> 0 then
        Push(EmitLoad(GetIntType, V));
    end
    else if Token = 'arrload' then
    begin
      Rhs := Pop;
      V := FindAlloca(Arg + '$ptr');
      if V <> 0 then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikLoad;
        Instr.TypeId := GetPtrType;
        SetLength(Instr.Operands, 1);
        Instr.Operands[0] := MakeOperand(V);
        EmitInstr(Instr);
        V := Instr.ResultId;

        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := GetPtrType;
        Instr.IntrinsicName := 'gep_i64';
        SetLength(Instr.Operands, 2);
        Instr.Operands[0] := MakeOperand(V);
        Instr.Operands[1] := MakeOperand(Rhs);
        EmitInstr(Instr);
        V := Instr.ResultId;

        Push(EmitLoad(GetIntType, V));
      end
      else
        Push(Rhs);
    end
    else if Token = 'field' then
    begin
      SpacePos := Pos(' ', Arg);
      if SpacePos > 0 then
      begin
        Token := Copy(Arg, 1, SpacePos - 1);
        Arg := Copy(Arg, SpacePos + 1, Length(Arg));
        SpacePos := Pos(' ', Arg);
        if SpacePos > 0 then
          ArgCount := StrToIntDef(Copy(Arg, 1, SpacePos - 1), 0)
        else
          ArgCount := StrToIntDef(Arg, 0);
      end
      else
      begin
        Token := Arg;
        ArgCount := 0;
      end;
      V := FindAlloca(Token);
      if V <> 0 then
      begin
        V := EmitLoad(GetPtrType, V);
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikLoad;
        Instr.TypeId := GetIntType;
        Instr.IntrinsicName := 'const:' + IntToStr(ArgCount);
        EmitInstr(Instr);
        Rhs := Instr.ResultId;
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := GetPtrType;
        Instr.IntrinsicName := 'gep_i64';
        SetLength(Instr.Operands, 2);
        Instr.Operands[0] := MakeOperand(V);
        Instr.Operands[1] := MakeOperand(Rhs);
        EmitInstr(Instr);
        if Pos(' p', Arg) > 0 then
          PushTyped(EmitLoad(GetPtrType, Instr.ResultId), GetPtrType)
        else
          Push(EmitLoad(GetIntType, Instr.ResultId));
      end;
    end
    else if Token = 'vcall' then
    begin
      CmpLhsType := 0;
      if (Length(Arg) > 2) and (Arg[Length(Arg)] = 'p') and
        (Arg[Length(Arg) - 1] = ' ') then
      begin
        CmpLhsType := GetPtrType;
        Arg := Copy(Arg, 1, Length(Arg) - 2);
      end;
      SpacePos := Pos(' ', Arg);
      if SpacePos > 0 then
      begin
        SlotIdx := StrToIntDef(Copy(Arg, 1, SpacePos - 1), 0);
        ExtraArgCount := StrToIntDef(Copy(Arg, SpacePos + 1, Length(Arg)), 0);
      end
      else
      begin
        SlotIdx := StrToIntDef(Arg, 0);
        ExtraArgCount := 0;
      end;
      SetLength(VcallArgs, ExtraArgCount);
      SetLength(VcallArgTypes, ExtraArgCount);
      for VcallI := ExtraArgCount - 1 downto 0 do
      begin
        if StackCount > 0 then
          VcallArgTypes[VcallI] := StackTypes[StackCount - 1]
        else
          VcallArgTypes[VcallI] := 0;
        VcallArgs[VcallI] := Pop;
      end;
      Rhs := Pop;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'const:0';
      EmitInstr(Instr);
      V := Instr.ResultId;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeOperand(Rhs);
      Instr.Operands[1] := MakeOperand(V);
      EmitInstr(Instr);
      V := EmitLoad(GetPtrType, Instr.ResultId);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'const:' + IntToStr(SlotIdx + 1);
      EmitInstr(Instr);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeOperand(V);
      Instr.Operands[1] := MakeOperand(Instr.ResultId - 1);
      EmitInstr(Instr);
      V := EmitLoad(GetPtrType, Instr.ResultId);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      if CmpLhsType = GetPtrType then
        Instr.TypeId := GetPtrType
      else
        Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'vcall';
      SetLength(Instr.Operands, 2 + ExtraArgCount);
      Instr.Operands[0] := MakeTypedOperand(V, GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(Rhs, GetPtrType);
      for VcallI := 0 to ExtraArgCount - 1 do
      begin
        if VcallArgTypes[VcallI] <> 0 then
          Instr.Operands[2 + VcallI] := MakeTypedOperand(VcallArgs[VcallI], VcallArgTypes[VcallI])
        else
          Instr.Operands[2 + VcallI] := MakeOperand(VcallArgs[VcallI]);
      end;
      EmitInstr(Instr);
      if CmpLhsType = GetPtrType then
        PushTyped(Instr.ResultId, GetPtrType)
      else
        Push(Instr.ResultId);
    end;
  end;

  if StackCount > 0 then
    Result := Pop;
end;

procedure THIRBuilder.ProcessVarDecl(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  ParamIdx: LongInt;
  ParamValueId: THIRValueId;
  Arg: string;
  TabPos, Code: LongInt;
begin
  if ANode.Kind = 'var-decl-runtime' then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      if FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].TypeId = GetPtrType then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetPtrType;
        EmitInstr(Instr);

        if FAllocaCount >= Length(FAllocaNames) then
        begin
          SetLength(FAllocaNames, FAllocaCount + 32);
          SetLength(FAllocaValues, FAllocaCount + 32);
          SetLength(FAllocaTypes, FAllocaCount + 32);
          SetLength(FRecordAllocaSlots, FAllocaCount + 32);
          SetLength(FVarParamFlags, FAllocaCount + 32);
        end;
        FAllocaNames[FAllocaCount] := ANode.Operand;
        FAllocaValues[FAllocaCount] := Instr.ResultId;
        FAllocaTypes[FAllocaCount] := GetPtrType;
        Inc(FAllocaCount);

        EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      end
      else
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetIntType;
        EmitInstr(Instr);

        if FAllocaCount >= Length(FAllocaNames) then
        begin
          SetLength(FAllocaNames, FAllocaCount + 32);
          SetLength(FAllocaValues, FAllocaCount + 32);
          SetLength(FAllocaTypes, FAllocaCount + 32);
          SetLength(FRecordAllocaSlots, FAllocaCount + 32);
          SetLength(FVarParamFlags, FAllocaCount + 32);
        end;
        FAllocaNames[FAllocaCount] := ANode.Operand;
        FAllocaValues[FAllocaCount] := Instr.ResultId;
        FAllocaTypes[FAllocaCount] := GetIntType;
        Inc(FAllocaCount);

        EmitStore(GetIntType, ParamValueId, Instr.ResultId);
      end;
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else if FInStartFunc then
    begin
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ANode.Operand;
      FGlobalTypes[FGlobalCount] := GetIntType;
      Inc(FGlobalCount);
      FModule.AddGlobal(ANode.Operand, GetIntType);
    end
    else
      EnsureAlloca(ANode.Operand, GetIntType);
  end
  else if ANode.Kind = 'var-decl-str-runtime' then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      EnsureAlloca(ANode.Operand + '$ptr', GetPtrType);
      EnsureAlloca(ANode.Operand + '$len', GetIntType);
      EmitStore(GetPtrType, ParamValueId, FindAlloca(ANode.Operand + '$ptr'));
      EmitStore(GetIntType,
        FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx + 1].ValueId,
        FindAlloca(ANode.Operand + '$len'));
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx, 2);
    end
    else
    begin
      EnsureAlloca(ANode.Operand + '$ptr', GetPtrType);
      EnsureAlloca(ANode.Operand + '$len', GetIntType);
    end;
  end
  else if ANode.Kind = 'var-decl-arr-runtime' then
  begin
    EnsureAlloca(ANode.Operand + '$ptr', GetPtrType);
    EnsureAlloca(ANode.Operand + '$len', GetIntType);
  end
  else if ANode.Kind = 'var-decl-ptr-runtime' then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetPtrType;
      EmitInstr(Instr);

      if FAllocaCount >= Length(FAllocaNames) then
      begin
        SetLength(FAllocaNames, FAllocaCount + 32);
        SetLength(FAllocaValues, FAllocaCount + 32);
        SetLength(FAllocaTypes, FAllocaCount + 32);
        SetLength(FRecordAllocaSlots, FAllocaCount + 32);
        SetLength(FVarParamFlags, FAllocaCount + 32);
      end;
      FAllocaNames[FAllocaCount] := ANode.Operand;
      FAllocaValues[FAllocaCount] := Instr.ResultId;
      FAllocaTypes[FAllocaCount] := GetPtrType;
      FRecordAllocaSlots[FAllocaCount] := 0;
      Inc(FAllocaCount);

      EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else if FSretValueId <> 0 then
    begin
      if FAllocaCount >= Length(FAllocaNames) then
      begin
        SetLength(FAllocaNames, FAllocaCount + 32);
        SetLength(FAllocaValues, FAllocaCount + 32);
        SetLength(FAllocaTypes, FAllocaCount + 32);
        SetLength(FRecordAllocaSlots, FAllocaCount + 32);
        SetLength(FVarParamFlags, FAllocaCount + 32);
      end;
      FAllocaNames[FAllocaCount] := ANode.Operand;
      FAllocaValues[FAllocaCount] := FSretValueId;
      FAllocaTypes[FAllocaCount] := GetPtrType;
      FVarParamFlags[FAllocaCount] := False;
      Inc(FAllocaCount);
      FSretValueId := 0;
    end
    else
      EnsureAlloca(ANode.Operand, GetPtrType);
  end
  else if ANode.Kind = 'var-decl-varref-runtime' then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetPtrType;
      EmitInstr(Instr);

      if FAllocaCount >= Length(FAllocaNames) then
      begin
        SetLength(FAllocaNames, FAllocaCount + 32);
        SetLength(FAllocaValues, FAllocaCount + 32);
        SetLength(FAllocaTypes, FAllocaCount + 32);
        SetLength(FRecordAllocaSlots, FAllocaCount + 32);
        SetLength(FVarParamFlags, FAllocaCount + 32);
      end;
      FAllocaNames[FAllocaCount] := ANode.Operand;
      FAllocaValues[FAllocaCount] := Instr.ResultId;
      FAllocaTypes[FAllocaCount] := GetPtrType;
      FVarParamFlags[FAllocaCount] := True;
      Inc(FAllocaCount);

      EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else
      EnsureAlloca(ANode.Operand, GetPtrType);
  end
  else if ANode.Kind = 'var-decl-record-runtime' then
  begin
    TabPos := Pos(#9, ANode.Operand);
    if TabPos > 0 then
    begin
      Arg := Copy(ANode.Operand, 1, TabPos - 1);
      Val(Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand)), ParamIdx, Code);
      if Code = 0 then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetIntType;
        Instr.IntrinsicName := 'record:' + IntToStr(ParamIdx);
        EmitInstr(Instr);

        if FAllocaCount >= Length(FAllocaNames) then
        begin
          SetLength(FAllocaNames, FAllocaCount + 32);
          SetLength(FAllocaValues, FAllocaCount + 32);
          SetLength(FAllocaTypes, FAllocaCount + 32);
          SetLength(FRecordAllocaSlots, FAllocaCount + 32);
          SetLength(FVarParamFlags, FAllocaCount + 32);
        end;
        FAllocaNames[FAllocaCount] := Arg;
        FAllocaValues[FAllocaCount] := Instr.ResultId;
        FAllocaTypes[FAllocaCount] := GetIntType;
        FRecordAllocaSlots[FAllocaCount] := ParamIdx;
        Inc(FAllocaCount);
      end;
    end;
  end;
end;

procedure THIRBuilder.ProcessAssign(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Blob: string;
  V, Addr: THIRValueId;
  StoreType: THIRTypeId;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Blob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  V := ParseIntBlob(Blob);
  Addr := FindAlloca(VarName);
  if Addr = 0 then
  begin
    EnsureAlloca(VarName, GetIntType);
    Addr := FindAlloca(VarName);
  end;
  if (V <> 0) and (Addr <> 0) then
  begin
    if IsVarParamAlloca(VarName) then
    begin
      Addr := EmitLoad(GetPtrType, Addr);
      EmitStore(GetIntType, V, Addr);
    end
    else
    begin
      StoreType := FindAllocaType(VarName);
      if StoreType = 0 then
        StoreType := GetIntType;
      EmitStore(StoreType, V, Addr);
    end;
  end;
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

procedure THIRBuilder.ProcessSwitch(const ANode: TTypedHirNode);
var
  Term: THIRTerminator;
  V: THIRValueId;
  Blob, Line, Rest, ValStr, LabelStr: string;
  SwitchPos, NlPos, TabPos, CaseCount, I: LongInt;
begin
  Blob := ANode.Operand;
  SwitchPos := Pos('switch ', Blob);
  if SwitchPos = 0 then Exit;

  V := ParseIntBlob(Copy(Blob, 1, SwitchPos - 1));
  Rest := Copy(Blob, SwitchPos + 7, Length(Blob));

  NlPos := Pos(#10, Rest);
  if NlPos = 0 then Exit;
  CaseCount := StrToIntDef(Copy(Rest, 1, NlPos - 1), 0);
  Rest := Copy(Rest, NlPos + 1, Length(Rest));

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkSwitch;
  Term.Condition := V;
  SetLength(Term.SwitchCases, CaseCount);

  for I := 0 to CaseCount - 1 do
  begin
    NlPos := Pos(#10, Rest);
    if NlPos = 0 then
      Line := Rest
    else
      Line := Copy(Rest, 1, NlPos - 1);
    Rest := Copy(Rest, NlPos + 1, Length(Rest));

    TabPos := Pos(#9, Line);
    if TabPos = 0 then Continue;
    ValStr := Copy(Line, 1, TabPos - 1);
    LabelStr := Copy(Line, TabPos + 1, Length(Line));
    Term.SwitchCases[I].Value := StrToInt64Def(ValStr, 0);
    Term.SwitchCases[I].TargetBlock := EnsureBlock(LabelStr);
  end;

  NlPos := Pos(#10, Rest);
  if NlPos = 0 then
    Line := Rest
  else
    Line := Copy(Rest, 1, NlPos - 1);
  TabPos := Pos(#9, Line);
  if TabPos > 0 then
    LabelStr := Copy(Line, TabPos + 1, Length(Line))
  else
    LabelStr := Line;
  Term.DefaultBlock := EnsureBlock(LabelStr);

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
  FInStartFunc := False;
  SetLength(FSavedAllocaNames, FAllocaCount);
  SetLength(FSavedAllocaValues, FAllocaCount);
  SetLength(FSavedAllocaTypes, FAllocaCount);
  SetLength(FSavedVarParamFlags, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
  begin
    FSavedAllocaNames[I] := FAllocaNames[I];
    FSavedAllocaValues[I] := FAllocaValues[I];
    FSavedAllocaTypes[I] := FAllocaTypes[I];
    FSavedVarParamFlags[I] := FVarParamFlags[I];
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
    FPendingParamCount := 0;
    FPendingParamLlvmIdx := 0;

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
        SetLength(FAllocaTypes, FAllocaCount + 32);
        SetLength(FRecordAllocaSlots, FAllocaCount + 32);
        SetLength(FVarParamFlags, FAllocaCount + 32);
      end;
      FAllocaNames[FAllocaCount] := ParamName;
      FAllocaValues[FAllocaCount] := Instr.ResultId;
      FAllocaTypes[FAllocaCount] := GetIntType;
      Inc(FAllocaCount);

      EmitStore(GetIntType, ParamValueId, Instr.ResultId);
    end;
  end
  else
  begin
    FuncName := ANode.DisplayName;
    ParamCount := 0;
    Rest := ANode.Operand;
    if ColonPos > 0 then
    begin
      ParamCount := StrToIntDef(Copy(Rest, 1, ColonPos - 1), 0);
      Rest := Copy(Rest, ColonPos + 1, Length(Rest));
    end
    else
      Rest := '';

    Pos2 := Pos(':', Rest);
    if Pos2 > 0 then
    begin
      ParamName := Copy(Rest, 1, Pos2 - 1);
      Rest := Copy(Rest, Pos2 + 1, Length(Rest));
    end
    else
    begin
      ParamName := Rest;
      Rest := '';
    end;

    if Rest = 's' then
      FCurrentFuncId := FModule.AddFunction(FuncName, GetStringType)
    else if Rest = 'p' then
      FCurrentFuncId := FModule.AddFunction(FuncName, GetPtrType)
    else if (Length(Rest) > 1) and (Rest[1] = 'r') then
    begin
      FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);
      FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
    end
    else
      FCurrentFuncId := FModule.AddFunction(FuncName, GetIntType);

    for I := 0 to ParamCount - 1 do
    begin
      if (I < Length(ParamName)) and (ParamName[I + 1] = 's') then
      begin
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I) + '_ptr', GetPtrType, False, False);
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I) + '_len', GetIntType, False, False);
      end
      else if (I < Length(ParamName)) and (ParamName[I + 1] = 'v') then
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I), GetPtrType, True, False)
      else if (I < Length(ParamName)) and
        ((ParamName[I + 1] = 'p') or (ParamName[I + 1] = 'r')) then
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I), GetPtrType, False, False)
      else
        FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I), GetIntType, False, False);
    end;

    EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
    FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
    FCurrentBlockId := EntryBlock;
    FBlockTerminated := False;
    FAllocaCount := 0;
    FBlockCount := 0;
    if (Length(Rest) > 1) and (Rest[1] = 'r') then
    begin
      FPendingParamCount := ParamCount;
      FPendingParamLlvmIdx := 1;
      FSretValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
    end
    else
    begin
      FPendingParamCount := ParamCount;
      FPendingParamLlvmIdx := 0;
      FSretValueId := 0;
    end;
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
    FAllocaTypes[I] := FSavedAllocaTypes[I];
    FVarParamFlags[I] := FSavedVarParamFlags[I];
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
  FuncName, Rest, ArgBlob, StrVarName: string;
  ArgValue, PtrVal, LenVal: THIRValueId;
  ArgOps: array of THIROperand;
  ArgCount, I: LongInt;
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

  ArgCount := 0;
  SetLength(ArgOps, 0);
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
    if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strvar ') then
    begin
      StrVarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
        StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
      PtrVal := FindAlloca(StrVarName + '$ptr');
      LenVal := FindAlloca(StrVarName + '$len');
      if (PtrVal <> 0) and (LenVal <> 0) then
      begin
        PtrVal := EmitLoad(GetPtrType, PtrVal);
        LenVal := EmitLoad(GetIntType, LenVal);
        SetLength(ArgOps, ArgCount + 2);
        ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
        ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntType);
        Inc(ArgCount, 2);
      end;
    end
    else
    begin
      ArgValue := ParseIntBlob(ArgBlob);
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 1);
        if (Length(ArgBlob) > 4) and (Copy(ArgBlob, 1, 4) = 'var ') then
        begin
          StrVarName := Copy(ArgBlob, 5, Length(ArgBlob));
          if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
            StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
          if (not IsVarParamAlloca(StrVarName)) and
            (FindAllocaType(StrVarName) = GetPtrType) then
            ArgOps[ArgCount] := MakeTypedOperand(ArgValue, GetPtrType)
          else
            ArgOps[ArgCount] := MakeOperand(ArgValue);
        end
        else if (Pos(' p' + #10, ArgBlob) > 0) or
          (Copy(ArgBlob, 1, 4) = 'null') or
          (Copy(ArgBlob, 1, 7) = 'recvar ') or
          (Copy(ArgBlob, 1, 7) = 'varref ') then
          ArgOps[ArgCount] := MakeTypedOperand(ArgValue, GetPtrType)
        else
          ArgOps[ArgCount] := MakeOperand(ArgValue);
        Inc(ArgCount);
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := FuncName;
  Instr.Operands := ArgOps;
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

procedure THIRBuilder.ProcessAssignStr(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  VarName: string;
  PtrAddr, LenAddr: THIRValueId;
begin
  VarName := ANode.Operand;
  PtrAddr := FindAlloca(VarName + '$ptr');
  LenAddr := FindAlloca(VarName + '$len');
  if (PtrAddr = 0) or (LenAddr = 0) then Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'store_str_lit';
  Instr.CallTarget := ANode.DisplayName;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(PtrAddr);
  Instr.Operands[1] := MakeOperand(LenAddr);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignStrCopy(const ANode: TTypedHirNode);
var
  SrcName, DstName: string;
  SrcPtr, SrcLen, DstPtr, DstLen, LoadedPtr, LoadedLen: THIRValueId;
begin
  SrcName := ANode.DisplayName;
  DstName := ANode.Operand;
  SrcPtr := FindAlloca(SrcName + '$ptr');
  SrcLen := FindAlloca(SrcName + '$len');
  DstPtr := FindAlloca(DstName + '$ptr');
  DstLen := FindAlloca(DstName + '$len');
  if (SrcPtr = 0) or (SrcLen = 0) or (DstPtr = 0) or (DstLen = 0) then Exit;

  LoadedPtr := EmitLoad(GetPtrType, SrcPtr);
  LoadedLen := EmitLoad(GetIntType, SrcLen);
  EmitStore(GetPtrType, LoadedPtr, DstPtr);
  EmitStore(GetIntType, LoadedLen, DstLen);
end;

procedure THIRBuilder.ProcessAssignStrCall(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  FuncName, ArgBlob, DstName: string;
  DstPtr, DstLen: THIRValueId;
  TabPos: LongInt;
  ArgParts: array of string;
  ArgPartCount, I: LongInt;
  ArgValues: array of THIRValueId;
  ArgTypes: array of THIRTypeId;
  ArgCount: LongInt;
  PartBlob: string;
  V: THIRValueId;
begin
  FuncName := ANode.DisplayName;
  ArgBlob := ANode.Operand;
  TabPos := Pos(#9, ArgBlob);
  if TabPos > 0 then
  begin
    DstName := Copy(ArgBlob, 1, TabPos - 1);
    ArgBlob := Copy(ArgBlob, TabPos + 1, Length(ArgBlob));
  end
  else
  begin
    DstName := ArgBlob;
    ArgBlob := '';
  end;

  DstPtr := FindAlloca(DstName + '$ptr');
  DstLen := FindAlloca(DstName + '$len');
  if (DstPtr = 0) or (DstLen = 0) then Exit;

  ArgCount := 0;
  SetLength(ArgValues, 0);
  SetLength(ArgTypes, 0);
  if ArgBlob <> '' then
  begin
    SetLength(ArgParts, 0);
    ArgPartCount := 0;
    PartBlob := '';
    for I := 1 to Length(ArgBlob) do
    begin
      if ArgBlob[I] = #9 then
      begin
        if PartBlob <> '' then
        begin
          if ArgPartCount >= Length(ArgParts) then
            SetLength(ArgParts, ArgPartCount + 8);
          ArgParts[ArgPartCount] := PartBlob;
          Inc(ArgPartCount);
          PartBlob := '';
        end;
      end
      else
        PartBlob := PartBlob + ArgBlob[I];
    end;
    if PartBlob <> '' then
    begin
      if ArgPartCount >= Length(ArgParts) then
        SetLength(ArgParts, ArgPartCount + 8);
      ArgParts[ArgPartCount] := PartBlob;
      Inc(ArgPartCount);
    end;

    for I := 0 to ArgPartCount - 1 do
    begin
      if Copy(ArgParts[I], 1, 7) = 'strvar ' then
      begin
        PartBlob := Copy(ArgParts[I], 8, Length(ArgParts[I]) - 8);
        V := FindAlloca(PartBlob + '$ptr');
        if V <> 0 then
        begin
          if ArgCount >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := EmitLoad(GetPtrType, V);
          ArgTypes[ArgCount] := GetPtrType;
          Inc(ArgCount);
        end;
        V := FindAlloca(PartBlob + '$len');
        if V <> 0 then
        begin
          if ArgCount >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := EmitLoad(GetIntType, V);
          ArgTypes[ArgCount] := GetIntType;
          Inc(ArgCount);
        end;
      end
      else
      begin
        V := ParseIntBlob(ArgParts[I]);
        if V <> 0 then
        begin
          if ArgCount >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := V;
          ArgTypes[ArgCount] := GetIntType;
          Inc(ArgCount);
        end;
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'call_str_func';
  Instr.CallTarget := FuncName;
  SetLength(Instr.Operands, 2 + ArgCount);
  Instr.Operands[0] := MakeOperand(DstPtr);
  Instr.Operands[1] := MakeOperand(DstLen);
  for I := 0 to ArgCount - 1 do
    Instr.Operands[2 + I] := MakeTypedOperand(ArgValues[I], ArgTypes[I]);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignStrVcall(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  DstName, ObjName: string;
  DstPtr, DstLen: THIRValueId;
  ObjAlloca, ObjVal, VmtPtr, SlotConst, FnPtr, V: THIRValueId;
  SlotIdx: LongInt;
  TabPos, TabPos2: LongInt;
  Rest: string;
begin
  Rest := ANode.Operand;
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  DstName := Copy(Rest, 1, TabPos - 1);
  Rest := Copy(Rest, TabPos + 1, Length(Rest));
  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  ObjName := Copy(Rest, 1, TabPos2 - 1);
  SlotIdx := StrToIntDef(Copy(Rest, TabPos2 + 1, Length(Rest)), 0);

  DstPtr := FindAlloca(DstName + '$ptr');
  DstLen := FindAlloca(DstName + '$len');
  if (DstPtr = 0) or (DstLen = 0) then Exit;

  ObjAlloca := FindAlloca(ObjName);
  if ObjAlloca = 0 then Exit;
  ObjVal := EmitLoad(GetPtrType, ObjAlloca);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:0';
  EmitInstr(Instr);
  V := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjVal);
  Instr.Operands[1] := MakeOperand(V);
  EmitInstr(Instr);
  VmtPtr := EmitLoad(GetPtrType, Instr.ResultId);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(SlotIdx + 1);
  EmitInstr(Instr);
  SlotConst := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(VmtPtr);
  Instr.Operands[1] := MakeOperand(SlotConst);
  EmitInstr(Instr);
  FnPtr := EmitLoad(GetPtrType, Instr.ResultId);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'vcall_str';
  SetLength(Instr.Operands, 4);
  Instr.Operands[0] := MakeTypedOperand(FnPtr, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(ObjVal, GetPtrType);
  Instr.Operands[2] := MakeOperand(DstPtr);
  Instr.Operands[3] := MakeOperand(DstLen);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignStrConcat(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  DstName, LhsOp, RhsOp: string;
  DstPtr, DstLen: THIRValueId;
  LhsPtr, LhsLen, RhsPtr, RhsLen: THIRValueId;
  TabPos: LongInt;
begin
  DstName := ANode.Operand;
  TabPos := Pos(#9, ANode.DisplayName);
  if TabPos = 0 then Exit;
  LhsOp := Copy(ANode.DisplayName, 1, TabPos - 1);
  RhsOp := Copy(ANode.DisplayName, TabPos + 1, Length(ANode.DisplayName));

  DstPtr := FindAlloca(DstName + '$ptr');
  DstLen := FindAlloca(DstName + '$len');
  if (DstPtr = 0) or (DstLen = 0) then Exit;

  LhsPtr := FindAlloca(LhsOp + '$ptr');
  LhsLen := FindAlloca(LhsOp + '$len');
  RhsPtr := FindAlloca(RhsOp + '$ptr');
  RhsLen := FindAlloca(RhsOp + '$len');
  if (LhsPtr = 0) or (LhsLen = 0) or (RhsPtr = 0) or (RhsLen = 0) then Exit;

  LhsPtr := EmitLoad(GetPtrType, LhsPtr);
  LhsLen := EmitLoad(GetIntType, LhsLen);
  RhsPtr := EmitLoad(GetPtrType, RhsPtr);
  RhsLen := EmitLoad(GetIntType, RhsLen);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'str_concat';
  SetLength(Instr.Operands, 6);
  Instr.Operands[0] := MakeOperand(LhsPtr);
  Instr.Operands[1] := MakeOperand(LhsLen);
  Instr.Operands[2] := MakeOperand(RhsPtr);
  Instr.Operands[3] := MakeOperand(RhsLen);
  Instr.Operands[4] := MakeOperand(DstPtr);
  Instr.Operands[5] := MakeOperand(DstLen);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessRetStrRuntime(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  VarName: string;
  PtrVal, LenVal: THIRValueId;
begin
  VarName := ANode.Operand;
  PtrVal := FindAlloca(VarName + '$ptr');
  LenVal := FindAlloca(VarName + '$len');
  if (PtrVal = 0) or (LenVal = 0) then Exit;

  PtrVal := EmitLoad(GetPtrType, PtrVal);
  LenVal := EmitLoad(GetIntType, LenVal);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'ret_str';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(PtrVal);
  Instr.Operands[1] := MakeOperand(LenVal);
  EmitInstr(Instr);
  FBlockTerminated := True;
end;

procedure THIRBuilder.ProcessSetLengthArr(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  ArrName, Blob: string;
  SizeVal, PtrVal: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  ArrName := Copy(ANode.Operand, 1, TabPos - 1);
  Blob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  SizeVal := ParseIntBlob(Blob);
  if SizeVal = 0 then Exit;

  EmitStore(GetIntType, SizeVal, FindAlloca(ArrName + '$len'));

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'arr_alloc';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeOperand(SizeVal);
  EmitInstr(Instr);
  PtrVal := Instr.ResultId;

  EmitStore(GetPtrType, PtrVal, FindAlloca(ArrName + '$ptr'));
end;

procedure THIRBuilder.ProcessAssignArrElem(const ANode: TTypedHirNode);
var
  TabPos, TabPos2: LongInt;
  ArrName, Rest, IdxBlob, ValBlob: string;
  IdxVal, ValVal, BasePtr, ElemPtr: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  ArrName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  IdxBlob := Copy(Rest, 1, TabPos2 - 1);
  ValBlob := Copy(Rest, TabPos2 + 1, Length(Rest));

  IdxVal := ParseIntBlob(IdxBlob);
  ValVal := ParseIntBlob(ValBlob);
  if (IdxVal = 0) or (ValVal = 0) then Exit;

  BasePtr := EmitLoad(GetPtrType, FindAlloca(ArrName + '$ptr'));

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(BasePtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  ElemPtr := Instr.ResultId;

  EmitStore(GetIntType, ValVal, ElemPtr);
end;

procedure THIRBuilder.ProcessMethodBegin(const ANode: TTypedHirNode);
var
  I, ColonPos, ParamCount, Pos2: LongInt;
  FuncName, Rest, ParamTypes, RetSuffix: string;
  EntryBlock: THIRBlockId;
  ParamValueId: THIRValueId;
  Instr: THIRInstr;
  RetType: THIRTypeId;
begin
  FSavedFuncId := FCurrentFuncId;
  FSavedBlockId := FCurrentBlockId;
  FSavedAllocaCount := FAllocaCount;
  FInStartFunc := False;
  SetLength(FSavedAllocaNames, FAllocaCount);
  SetLength(FSavedAllocaValues, FAllocaCount);
  SetLength(FSavedAllocaTypes, FAllocaCount);
  SetLength(FSavedVarParamFlags, FAllocaCount);
  for I := 0 to FAllocaCount - 1 do
  begin
    FSavedAllocaNames[I] := FAllocaNames[I];
    FSavedAllocaValues[I] := FAllocaValues[I];
    FSavedAllocaTypes[I] := FAllocaTypes[I];
    FSavedVarParamFlags[I] := FVarParamFlags[I];
  end;
  FSavedBlockCount := FBlockCount;
  SetLength(FSavedBlockNames, FBlockCount);
  SetLength(FSavedBlockIds, FBlockCount);
  for I := 0 to FBlockCount - 1 do
  begin
    FSavedBlockNames[I] := FBlockNames[I];
    FSavedBlockIds[I] := FBlockIds[I];
  end;

  FuncName := ANode.DisplayName;
  Rest := ANode.Operand;
  ColonPos := Pos(':', Rest);
  ParamCount := 0;
  ParamTypes := '';
  RetSuffix := '';
  if ColonPos > 0 then
  begin
    ParamCount := StrToIntDef(Copy(Rest, 1, ColonPos - 1), 0);
    ParamTypes := Copy(Rest, ColonPos + 1, Length(Rest));
    Pos2 := Pos(':', ParamTypes);
    if Pos2 > 0 then
    begin
      RetSuffix := Copy(ParamTypes, Pos2 + 1, Length(ParamTypes));
      ParamTypes := Copy(ParamTypes, 1, Pos2 - 1);
    end;
  end;

  if RetSuffix = 's' then
    RetType := GetStringType
  else if RetSuffix = 'p' then
    RetType := GetPtrType
  else
    RetType := GetIntType;

  FCurrentFuncId := FModule.AddFunction(FuncName, RetType);
  FModule.AddFunctionParam(FCurrentFuncId, 'self', GetPtrType, False, False);
  for I := 1 to ParamCount - 1 do
  begin
    if (I < Length(ParamTypes)) and (ParamTypes[I + 1] = 's') then
    begin
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_ptr', GetPtrType, False, False);
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_len', GetIntType, False, False);
    end
    else if (I < Length(ParamTypes)) and
      ((ParamTypes[I + 1] = 'p') or (ParamTypes[I + 1] = 'r')) then
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetPtrType, False, False)
    else
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetIntType, False, False);
  end;

  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FBlockTerminated := False;
  FAllocaCount := 0;
  FBlockCount := 0;

  ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetPtrType;
  EmitInstr(Instr);
  if FAllocaCount >= Length(FAllocaNames) then
  begin
    SetLength(FAllocaNames, FAllocaCount + 32);
    SetLength(FAllocaValues, FAllocaCount + 32);
    SetLength(FAllocaTypes, FAllocaCount + 32);
    SetLength(FRecordAllocaSlots, FAllocaCount + 32);
    SetLength(FVarParamFlags, FAllocaCount + 32);
  end;
  FAllocaNames[FAllocaCount] := 'self';
  FAllocaValues[FAllocaCount] := Instr.ResultId;
  FAllocaTypes[FAllocaCount] := GetPtrType;
  Inc(FAllocaCount);
  EmitStore(GetPtrType, ParamValueId, Instr.ResultId);

  FPendingParamCount := ParamCount - 1;
  FPendingParamLlvmIdx := 1;
end;

procedure THIRBuilder.ProcessClassNew(const ANode: TTypedHirNode);
var
  I, TabPos: LongInt;
  VarName, Rest, CtorName, ArgBlob: string;
  SizeVal, PtrVal, ArgValue, V: THIRValueId;
  Instr: THIRInstr;
  ArgOps: array of THIROperand;
  ArgCount: LongInt;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos > 0 then
  begin
    CtorName := Copy(Rest, 1, TabPos - 1);
    Rest := Copy(Rest, TabPos + 1, Length(Rest));
  end
  else
  begin
    CtorName := Rest;
    Rest := '';
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + ANode.DisplayName;
  EmitInstr(Instr);
  SizeVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'class_alloc';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeOperand(SizeVal);
  EmitInstr(Instr);
  PtrVal := Instr.ResultId;

  V := FindAlloca(VarName);
  if V = 0 then
    EnsureAlloca(VarName, GetPtrType)
  else if not IsVarParamAlloca(VarName) then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikAlloca;
    Instr.TypeId := GetPtrType;
    EmitInstr(Instr);
    for I := 0 to FAllocaCount - 1 do
      if SameText(FAllocaNames[I], VarName) then
      begin
        FAllocaValues[I] := Instr.ResultId;
        FAllocaTypes[I] := GetPtrType;
        Break;
      end;
  end;
  V := FindAlloca(VarName);
  if IsVarParamAlloca(VarName) then
    EmitStore(GetPtrType, PtrVal, EmitLoad(GetPtrType, V))
  else
    EmitStore(GetPtrType, PtrVal, V);

  ArgCount := 1;
  SetLength(ArgOps, 1);
  ArgOps[0] := MakeTypedOperand(PtrVal, GetPtrType);
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
    if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strvar ') then
    begin
      VarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(VarName) > 0) and (VarName[Length(VarName)] = #10) then
        VarName := Copy(VarName, 1, Length(VarName) - 1);
      ArgValue := FindAlloca(VarName + '$ptr');
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 2);
        ArgOps[ArgCount] := MakeTypedOperand(EmitLoad(GetPtrType, ArgValue), GetPtrType);
        Inc(ArgCount);
        ArgValue := FindAlloca(VarName + '$len');
        if ArgValue <> 0 then
          ArgOps[ArgCount] := MakeOperand(EmitLoad(GetIntType, ArgValue))
        else
          ArgOps[ArgCount] := MakeOperand(0);
        Inc(ArgCount);
      end;
    end
    else
    begin
      ArgValue := ParseIntBlob(ArgBlob);
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 1);
        ArgOps[ArgCount] := MakeOperand(ArgValue);
        Inc(ArgCount);
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := CtorName;
  Instr.Operands := ArgOps;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EnsureVmtForClass(const AClassName: string);
var
  VmtCount: Int64;
  I, J: LongInt;
  Funcs: array of string;
  FuncName, ParentClass: string;
begin
  for J := 0 to FModule.VmtGlobalCount - 1 do
    if FModule.VmtGlobalAt(J).ClassName = AClassName then
      Exit;
  if not FSemaModel.LookupConstValue(AClassName + '$vmt_count', VmtCount) then
    VmtCount := 0;
  if not FSemaModel.LookupStringConstValue(AClassName + '$parent_class', ParentClass) then
    ParentClass := '';
  SetLength(Funcs, VmtCount + 1);
  if ParentClass <> '' then
  begin
    Funcs[0] := ParentClass + '.vmt';
    EnsureVmtForClass(ParentClass);
  end
  else
    Funcs[0] := '';
  for I := 0 to VmtCount - 1 do
  begin
    if not FSemaModel.LookupStringConstValue(
      AClassName + '$vmt_func_' + IntToStr(I), FuncName) then
      FuncName := '';
    Funcs[I + 1] := FuncName;
  end;
  FModule.AddVmtGlobal(AClassName, Funcs);
end;

procedure THIRBuilder.ProcessVmtStore(const ANode: TTypedHirNode);
var
  ClsName, FuncName, VarName, ParentClass: string;
  VmtCount: Int64;
  I, TabPos: LongInt;
  Funcs: array of string;
  ObjPtr, ZeroVal, SlotPtr: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    VarName := Copy(ANode.Operand, 1, TabPos - 1);
    ClsName := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end
  else
  begin
    VarName := 'self';
    ClsName := ANode.Operand;
  end;

  if not FSemaModel.LookupConstValue(ClsName + '$vmt_count', VmtCount) then
    VmtCount := 0;

  if not FSemaModel.LookupStringConstValue(ClsName + '$parent_class', ParentClass) then
    ParentClass := '';

  SetLength(Funcs, VmtCount + 1);
  if ParentClass <> '' then
    Funcs[0] := ParentClass + '.vmt'
  else
    Funcs[0] := '';
  for I := 0 to VmtCount - 1 do
  begin
    if not FSemaModel.LookupStringConstValue(
      ClsName + '$vmt_func_' + IntToStr(I), FuncName) then
      FuncName := '';
    Funcs[I + 1] := FuncName;
  end;
  FModule.AddVmtGlobal(ClsName, Funcs);

  if (ParentClass <> '') and
    FSemaModel.LookupConstValue(ParentClass + '$vmt_count', VmtCount) then
  begin
    SetLength(Funcs, VmtCount + 1);
    if FSemaModel.LookupStringConstValue(ParentClass + '$parent_class', FuncName) and
      (FuncName <> '') then
      Funcs[0] := FuncName + '.vmt'
    else
      Funcs[0] := '';
    for I := 0 to VmtCount - 1 do
    begin
      if not FSemaModel.LookupStringConstValue(
        ParentClass + '$vmt_func_' + IntToStr(I), FuncName) then
        FuncName := '';
      Funcs[I + 1] := FuncName;
    end;
    FModule.AddVmtGlobal(ParentClass, Funcs);
  end;

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);
  if IsVarParamAlloca(VarName) then
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:0';
  EmitInstr(Instr);
  ZeroVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(ZeroVal);
  EmitInstr(Instr);
  SlotPtr := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'vmt_store';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SlotPtr, GetPtrType);
  Instr.CallTarget := ClsName;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessFieldStore(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, ValBlob, Token: string;
  ObjPtr, IdxVal, ValVal, FieldPtr: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IdxStr;
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldPtr := Instr.ResultId;

  ValVal := ParseIntBlob(ValBlob);
  if ValVal <> 0 then
  begin
    if (Length(ValBlob) > 4) and (Copy(ValBlob, 1, 4) = 'var ') then
    begin
      Token := Copy(ValBlob, 5, Length(ValBlob));
      if (Length(Token) > 0) and (Token[Length(Token)] = #10) then
        Token := Copy(Token, 1, Length(Token) - 1);
      if FindAllocaType(Token) = GetPtrType then
        EmitStore(GetPtrType, ValVal, FieldPtr)
      else
        EmitStore(GetIntType, ValVal, FieldPtr);
    end
    else if (Pos(' p' + #10, ValBlob) > 0) or
      (Copy(ValBlob, 1, 4) = 'null') then
      EmitStore(GetPtrType, ValVal, FieldPtr)
    else
      EmitStore(GetIntType, ValVal, FieldPtr);
  end;
end;

procedure THIRBuilder.ProcessRecordFieldStore(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, ValBlob: string;
  RecPtr, IdxVal, ValVal, FieldPtr: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));

  RecPtr := FindAlloca(VarName);
  if RecPtr = 0 then Exit;

  if FindAllocaType(VarName) = GetPtrType then
    RecPtr := EmitLoad(GetPtrType, RecPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IdxStr;
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(RecPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldPtr := Instr.ResultId;

  ValVal := ParseIntBlob(ValBlob);
  if ValVal <> 0 then
    EmitStore(GetIntType, ValVal, FieldPtr);
end;

procedure THIRBuilder.ProcessRecordCopy(const ANode: TTypedHirNode);
var
  TabPos, I, FieldCount, Code: LongInt;
  DstName, Rest, SrcName, CountStr: string;
  DstPtr, SrcPtr, IdxVal, SrcField, DstField, LoadedVal: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  DstName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  SrcName := Copy(Rest, 1, TabPos - 1);
  CountStr := Copy(Rest, TabPos + 1, Length(Rest));
  Val(CountStr, FieldCount, Code);
  if Code <> 0 then Exit;

  DstPtr := FindAlloca(DstName);
  SrcPtr := FindAlloca(SrcName);
  if (DstPtr = 0) or (SrcPtr = 0) then Exit;

  for I := 0 to FieldCount - 1 do
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(I);
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(SrcPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    SrcField := Instr.ResultId;

    LoadedVal := EmitLoad(GetIntType, SrcField);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(I);
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(DstPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    DstField := Instr.ResultId;

    EmitStore(GetIntType, LoadedVal, DstField);
  end;
end;

procedure THIRBuilder.ProcessFieldStoreStr(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, SrcSpec, SrcName: string;
  ObjPtr, IdxVal, FieldPtrPtr, FieldLenPtr, SrcPtr, SrcLen: THIRValueId;
  Instr: THIRInstr;
  Idx, IdxPlusOne: LongInt;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  SrcSpec := Copy(Rest, TabPos + 1, Length(Rest));
  Idx := StrToIntDef(IdxStr, 0);
  IdxPlusOne := Idx + 1;

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IdxStr;
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldPtrPtr := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(IdxPlusOne);
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldLenPtr := Instr.ResultId;

  if (Length(SrcSpec) > 4) and (Copy(SrcSpec, 1, 4) = 'lit ') then
  begin
    SrcName := Copy(SrcSpec, 5, Length(SrcSpec));
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'store_str_lit';
    Instr.CallTarget := SrcName;
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(FieldPtrPtr);
    Instr.Operands[1] := MakeOperand(FieldLenPtr);
    EmitInstr(Instr);
  end
  else if (Length(SrcSpec) > 4) and (Copy(SrcSpec, 1, 4) = 'var ') then
  begin
    SrcName := Copy(SrcSpec, 5, Length(SrcSpec));
    SrcPtr := FindAlloca(SrcName + '$ptr');
    SrcLen := FindAlloca(SrcName + '$len');
    if (SrcPtr = 0) or (SrcLen = 0) then Exit;
    SrcPtr := EmitLoad(GetPtrType, SrcPtr);
    SrcLen := EmitLoad(GetIntType, SrcLen);
    EmitStore(GetPtrType, SrcPtr, FieldPtrPtr);
    EmitStore(GetIntType, SrcLen, FieldLenPtr);
  end;
end;

procedure THIRBuilder.ProcessAssignStrFieldLoad(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  DstName, IdxStr: string;
  ObjPtr, IdxVal, FieldPtrPtr, FieldLenPtr, LoadedPtr, LoadedLen: THIRValueId;
  DstPtrAlloca, DstLenAlloca: THIRValueId;
  Instr: THIRInstr;
  Idx, IdxPlusOne: LongInt;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  DstName := Copy(ANode.Operand, 1, TabPos - 1);
  IdxStr := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  Idx := StrToIntDef(IdxStr, 0);
  IdxPlusOne := Idx + 1;

  ObjPtr := FindAlloca('self');
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(Idx);
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldPtrPtr := Instr.ResultId;
  LoadedPtr := EmitLoad(GetPtrType, FieldPtrPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(IdxPlusOne);
  EmitInstr(Instr);
  IdxVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  FieldLenPtr := Instr.ResultId;
  LoadedLen := EmitLoad(GetIntType, FieldLenPtr);

  DstPtrAlloca := FindAlloca(DstName + '$ptr');
  DstLenAlloca := FindAlloca(DstName + '$len');
  if (DstPtrAlloca = 0) or (DstLenAlloca = 0) then Exit;
  EmitStore(GetPtrType, LoadedPtr, DstPtrAlloca);
  EmitStore(GetIntType, LoadedLen, DstLenAlloca);
end;

procedure THIRBuilder.ProcessNode(const ANode: TTypedHirNode);
begin
  if (ANode.Kind = 'var-decl-runtime') or
     (ANode.Kind = 'var-decl-str-runtime') or
     (ANode.Kind = 'var-decl-arr-runtime') or
     (ANode.Kind = 'var-decl-ptr-runtime') or
     (ANode.Kind = 'var-decl-varref-runtime') or
     (ANode.Kind = 'var-decl-record-runtime') then
    ProcessVarDecl(ANode)
  else if ANode.Kind = 'assign-runtime' then
    ProcessAssign(ANode)
  else if ANode.Kind = 'assign-str-runtime' then
    ProcessAssignStr(ANode)
  else if ANode.Kind = 'assign-str-copy-runtime' then
    ProcessAssignStrCopy(ANode)
  else if ANode.Kind = 'assign-str-call-runtime' then
    ProcessAssignStrCall(ANode)
  else if ANode.Kind = 'assign-str-vcall-runtime' then
    ProcessAssignStrVcall(ANode)
  else if ANode.Kind = 'assign-str-concat-runtime' then
    ProcessAssignStrConcat(ANode)
  else if ANode.Kind = 'halt-call-runtime' then
    ProcessHaltCall(ANode)
  else if ANode.Kind = 'halt-call' then
    ProcessHaltCallConst(ANode)
  else if ANode.Kind = 'cond-br-runtime' then
    ProcessCondBr(ANode)
  else if ANode.Kind = 'switch-runtime' then
    ProcessSwitch(ANode)
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
  else if ANode.Kind = 'ret-str-runtime' then
    ProcessRetStrRuntime(ANode)
  else if ANode.Kind = 'call-runtime' then
    ProcessCallRuntime(ANode)
  else if ANode.Kind = 'write-int-runtime' then
    ProcessWriteInt(ANode)
  else if ANode.Kind = 'write-string-runtime' then
    ProcessWriteStr(ANode)
  else if ANode.Kind = 'write-str-var-runtime' then
    ProcessWriteStrVar(ANode)
  else if ANode.Kind = 'write-call' then
    ProcessWriteStr(ANode)
  else if ANode.Kind = 'setlength-arr-runtime' then
    ProcessSetLengthArr(ANode)
  else if ANode.Kind = 'assign-arr-elem-runtime' then
    ProcessAssignArrElem(ANode)
  else if ANode.Kind = 'method-body-begin' then
    ProcessMethodBegin(ANode)
  else if ANode.Kind = 'class-new-runtime' then
    ProcessClassNew(ANode)
  else if ANode.Kind = 'field-store-runtime' then
    ProcessFieldStore(ANode)
  else if ANode.Kind = 'record-field-store-runtime' then
    ProcessRecordFieldStore(ANode)
  else if ANode.Kind = 'record-copy-runtime' then
    ProcessRecordCopy(ANode)
  else if ANode.Kind = 'field-store-str-runtime' then
    ProcessFieldStoreStr(ANode)
  else if ANode.Kind = 'assign-str-field-load-runtime' then
    ProcessAssignStrFieldLoad(ANode)
  else if ANode.Kind = 'vmt-store-runtime' then
    ProcessVmtStore(ANode);
end;

procedure THIRBuilder.Build;
var
  I: LongInt;
  Node: TTypedHirNode;
  EntryBlock: THIRBlockId;
  Instr: THIRInstr;
  FwdName, FwdRest: string;
  FwdColon, FwdColon2: LongInt;
begin
  FFwdFuncCount := 0;
  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    if (Node.Kind = 'function-body-begin') or
       (Node.Kind = 'method-body-begin') then
    begin
      FwdName := Node.DisplayName;
      FwdRest := '';
      FwdColon := Pos(':', Node.Operand);
      if FwdColon > 0 then
      begin
        FwdRest := Copy(Node.Operand, FwdColon + 1, Length(Node.Operand));
        FwdColon2 := Pos(':', FwdRest);
        if FwdColon2 > 0 then
          FwdRest := Copy(FwdRest, FwdColon2 + 1, Length(FwdRest))
        else
          FwdRest := '';
      end;
      if FFwdFuncCount >= Length(FFwdFuncNames) then
      begin
        SetLength(FFwdFuncNames, FFwdFuncCount + 32);
        SetLength(FFwdFuncRetTypes, FFwdFuncCount + 32);
      end;
      FFwdFuncNames[FFwdFuncCount] := FwdName;
      if FwdRest = 'p' then
        FFwdFuncRetTypes[FFwdFuncCount] := GetPtrType
      else if FwdRest = 's' then
        FFwdFuncRetTypes[FFwdFuncCount] := GetStringType
      else
        FFwdFuncRetTypes[FFwdFuncCount] := GetIntType;
      Inc(FFwdFuncCount);
    end;
  end;

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
