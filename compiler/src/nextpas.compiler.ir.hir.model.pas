unit nextpas.compiler.ir.hir.model;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils, Generics.Collections,
  nextpas.core.collections.vec,
  nextpas.compiler.ir.hir.types, nextpas.compiler.ir.system_contracts;

type
  THIRValueId = LongInt;
  THIRBlockId = LongInt;
  THIRFuncId = LongInt;

  THIRInstrKind = (
    hikAlloca,
    hikLoad,
    hikStore,
    hikGetFieldPtr,
    hikAdd,
    hikSub,
    hikMul,
    hikDiv,
    hikMod,
    hikNeg,
    hikNot,
    hikBitAnd,
    hikBitOr,
    hikBitXor,
    hikShl,
    hikShr,
    hikCmpEq,
    hikCmpNe,
    hikCmpLt,
    hikCmpLe,
    hikCmpGt,
    hikCmpGe,
    hikTrunc,
    hikZext,
    hikSext,
    hikBitcast,
    hikIntToFloat,
    hikFloatToInt,
    hikCall,
    hikIndirectCall,
    hikIntrinsic,
    hikInsertField,
    hikExtractField,
    hikPhi,
    hikTryBegin,
    hikTryEnd,
    hikFinallyBegin,
    hikFinallyEnd,
    hikExceptBegin,
    hikExceptEnd,
    hikRaise,
    hikConstFloat
  );

  THIRTermKind = (
    htkReturn,
    htkBranch,
    htkCondBranch,
    htkSwitch,
    htkUnreachable
  );

  THIROperand = record
    ValueId: THIRValueId;
    TypeId: THIRTypeId;
  end;

  THIRPhiEntry = record
    ValueId: THIRValueId;
    BlockId: THIRBlockId;
  end;

  THIRInstr = record
    ResultId: THIRValueId;
    Kind: THIRInstrKind;
    TypeId: THIRTypeId;
    Operands: array of THIROperand;
    PhiEntries: array of THIRPhiEntry;
    FieldIndex: LongInt;
    CallTarget: string;
    IntrinsicName: string;
    HasSystemContract: Boolean;
    SystemContractKind: TSystemContractKind;
    FloatValue: Double;
    SourceLine: LongInt;
    SourceCol: LongInt;
    StructTypeName: string;  // 非空时表示该指令操作的 struct 类型名 (hikGetFieldPtr/hikExtractField/hikInsertField)
  end;

  THIRSwitchCase = record
    Value: Int64;
    TargetBlock: THIRBlockId;
  end;

  THirSwitchCaseVec = specialize TVec<THIRSwitchCase>;

  THIRTerminator = record
    Kind: THIRTermKind;
    ReturnValue: THIRValueId;
    Condition: THIRValueId;
    TrueBlock: THIRBlockId;
    FalseBlock: THIRBlockId;
    TargetBlock: THIRBlockId;
    { Nested product table owned by block terminator (default heap). }
    SwitchCases: THirSwitchCaseVec;
    DefaultBlock: THIRBlockId;
  end;

  THirInstrVec = specialize TVec<THIRInstr>;
  THirBlockIdVec = specialize TVec<THIRBlockId>;

  THIRBlock = record
    Id: THIRBlockId;
    Name: string;
    { Nested product tables owned by module block entry (default heap). }
    Instrs: THirInstrVec;
    Terminator: THIRTerminator;
    Preds: THirBlockIdVec;
    Succs: THirBlockIdVec;
  end;

  THIRParam = record
    Name: string;
    TypeId: THIRTypeId;
    ValueId: THIRValueId;
    IsVar: Boolean;
    IsConst: Boolean;
  end;

  THirParamVec = specialize TVec<THIRParam>;
  THirBlockVec = specialize TVec<THIRBlock>;

  THIRFunction = record
    Id: THIRFuncId;
    Name: string;
    ReturnTypeId: THIRTypeId;
    { Nested product tables owned by module function entry (default heap). }
    Params: THirParamVec;
    Blocks: THirBlockVec;
    EntryBlockId: THIRBlockId;
    IsExternal: Boolean;
    ExternalLib: string;
    ExternalName: string;
    UsesOwnedStringReturnAbi: Boolean; { 旧 4-slot owned path — 迁移后删除 }
    IsTStringReturnAbi: Boolean;        { 新 TString 24B sret path }
  end;

  THirStringVec = specialize TVec<string>;
  THirLongIntVec = specialize TVec<LongInt>;

  THIRVmtGlobal = record
    ClassName: string;
    { Nested product table owned by module VMT entry (default heap). }
    Funcs: THirStringVec;
  end;

  THIRImtGlobal = record
    ClassName: string;
    InterfaceName: string;
    { Nested product tables owned by module IMT entry (default heap). }
    ThunkNames: THirStringVec;
    ThunkParamCounts: THirLongIntVec;
    SlotOffset: LongInt;
  end;

  THIRGlobal = record
    Name: string;
    TypeId: THIRTypeId;
    ValueId: THIRValueId;
    InitValue: Int64;
    InitStr: string;
    HasInit: Boolean;
    IsThreadVar: Boolean;
    { TString globals use inline 24B %TString storage, not a ptr slot:
      runtime tstring calls read/write them as inline structs. }
    IsTStringStorage: Boolean;
  end;

  PHirFunction = ^THIRFunction;
  PHirBlock = ^THIRBlock;
  PHirVmtGlobal = ^THIRVmtGlobal;
  PHirImtGlobal = ^THIRImtGlobal;
  THirFunctionVec = specialize TVec<THIRFunction>;
  THirGlobalVec = specialize TVec<THIRGlobal>;
  THirVmtGlobalVec = specialize TVec<THIRVmtGlobal>;
  THirImtGlobalVec = specialize TVec<THIRImtGlobal>;

  THIRModule = class
  private
    FTypes: THIRTypeTable;
    FFunctions: THirFunctionVec;
    FGlobals: THirGlobalVec;
    FGlobalIndex: specialize TDictionary<string, SizeInt>;
    FVmtGlobals: THirVmtGlobalVec;
    FImtGlobals: THirImtGlobalVec;
    FNextValueId: THIRValueId;
    FNextBlockId: THIRBlockId;
    FNextFuncId: THIRFuncId;
    FModuleName: string;
    FUnitInitOrder: THirStringVec;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    function Types: THIRTypeTable;
    function ModuleName: string;

    function NewValue: THIRValueId;
    function NewBlockId: THIRBlockId;

    function AddFunction(const AName: string;
      ARetType: THIRTypeId): THIRFuncId;
    procedure SetFunctionOwnedStringReturnAbi(AFuncId: THIRFuncId;
      AValue: Boolean);
    procedure SetFunctionTStringReturnAbi(AFuncId: THIRFuncId;
      AValue: Boolean);
    procedure SetFunctionExternal(AFuncId: THIRFuncId;
      AIsExternal: Boolean; const AExternalLib: string;
      const AExternalName: string);
    procedure AddFunctionParam(AFuncId: THIRFuncId;
      const AName: string; ATypeId: THIRTypeId;
      AIsVar: Boolean; AIsConst: Boolean);
    function AddBlock(AFuncId: THIRFuncId;
      const AName: string): THIRBlockId;
    procedure SetEntryBlock(AFuncId: THIRFuncId; ABlockId: THIRBlockId);

    procedure AddInstr(AFuncId: THIRFuncId; ABlockId: THIRBlockId;
      const AInstr: THIRInstr);
    procedure SetTerminator(AFuncId: THIRFuncId; ABlockId: THIRBlockId;
      const ATerm: THIRTerminator);

    procedure AddGlobal(const AName: string; ATypeId: THIRTypeId;
      AIsThreadVar: Boolean = False;
      AIsTStringStorage: Boolean = False);

    function FunctionCount: LongInt;
    function FunctionAt(AIndex: LongInt): THIRFunction;
    function FindFunctionReturnType(const AName: string): THIRTypeId;
    function GlobalCount: LongInt;
    function GlobalAt(AIndex: LongInt): THIRGlobal;
    procedure AddVmtGlobal(const AClassName: string; const AFuncs: array of string);
    function VmtGlobalCount: LongInt;
    function VmtGlobalAt(AIndex: LongInt): THIRVmtGlobal;
    procedure AddImtGlobal(const AClassName, AInterfaceName: string;
      const AThunkNames: array of string;
      const AParamCounts: array of LongInt; ASlotOffset: LongInt);
    function ImtGlobalCount: LongInt;
    function ImtGlobalAt(AIndex: LongInt): THIRImtGlobal;
    procedure SetUnitInitOrder(const AOrder: array of string);
    function UnitInitOrderCount: LongInt;
    function UnitInitOrderAt(const AIndex: LongInt): string;
  end;

function MakeOperand(AValueId: THIRValueId): THIROperand;
function MakeTypedOperand(AValueId: THIRValueId; ATypeId: THIRTypeId): THIROperand;
procedure AssignSystemContract(var AInstr: THIRInstr;
  AKind: TSystemContractKind);
function IsSystemContract(const AInstr: THIRInstr;
  AKind: TSystemContractKind): Boolean;
function ValidateSystemContractInstr(const AInstr: THIRInstr;
  ATypes: THIRTypeTable; out AError: string): Boolean;
function ValidateObjectFreeSequenceContinuation(
  ARootReceiverValueId, AContinuationReceiverValueId: THIRValueId;
  const ARootDestroyTarget, AContinuationTarget: string;
  AContinuationKind: TSystemContractKind; out AError: string): Boolean;

implementation

uses
  nextpas.core.text.conv;

function MakeOperand(AValueId: THIRValueId): THIROperand;
begin
  Result.ValueId := AValueId;
  Result.TypeId := 0;
end;

function MakeTypedOperand(AValueId: THIRValueId; ATypeId: THIRTypeId): THIROperand;
begin
  Result.ValueId := AValueId;
  Result.TypeId := ATypeId;
end;

procedure AssignSystemContract(var AInstr: THIRInstr;
  AKind: TSystemContractKind);
var
  ContractDefinition: TSystemContractDefinition;
begin
  ContractDefinition := SystemContractAt(AKind);
  if ContractDefinition.SemanticName = '' then
    raise ERangeError.Create('Unknown System contract kind: ' +
      IntToStr(Ord(AKind)));
  AInstr.HasSystemContract := True;
  AInstr.SystemContractKind := AKind;
  AInstr.IntrinsicName := ContractDefinition.SemanticName;
end;

function IsSystemContract(const AInstr: THIRInstr;
  AKind: TSystemContractKind): Boolean;
begin
  Result := AInstr.HasSystemContract and
    (AInstr.SystemContractKind = AKind);
end;

function ValidateSystemContractInstr(const AInstr: THIRInstr;
  ATypes: THIRTypeTable; out AError: string): Boolean;
var
  ContractDefinition: TSystemContractDefinition;
  ContractOrdinal: LongInt;
  OperandIndex: LongInt;
  OperandType: THIRTypeRec;
begin
  AError := '';
  if not AInstr.HasSystemContract then
    Exit(True);

  ContractOrdinal := Ord(AInstr.SystemContractKind);
  if AInstr.Kind <> hikIntrinsic then
  begin
    AError := 'system-contract-kind-must-be-intrinsic:' +
      IntToStr(ContractOrdinal);
    Exit(False);
  end;

  case AInstr.SystemContractKind of
    sckProcessInit,
    sckProcessFini,
    sckHalt,
    sckStringInit,
    sckStringFini,
    sckStringAssign,
    sckDynArrayFini,
    sckDynArraySetLength,
    sckInterfaceAddRef,
    sckInterfaceRelease,
    sckHeapAlloc,
    sckHeapFree,
    sckObjectAlloc,
    sckObjectFree,
    sckObjectFreeDestroy,
    sckObjectFreeCleanup,
    sckObjectFreeRelease,
    sckManagedRecordFini,
    sckExceptionTryPush,
    sckExceptionTryPop,
    sckExceptionRaise,
    sckExceptionFinallyEnd,
    sckExceptionExceptEnd:
      ;
  else
    AError := 'system-contract-kind-unsupported:' +
      IntToStr(ContractOrdinal);
    Exit(False);
  end;

  ContractDefinition := SystemContractAt(AInstr.SystemContractKind);
  if AInstr.IntrinsicName <> ContractDefinition.SemanticName then
  begin
    AError := 'system-contract-name-mismatch:' + IntToStr(ContractOrdinal);
    Exit(False);
  end;

  { Zero-arg void lifecycle contracts (process init/fini + exception boundary).
    try_push may carry handler label in CallTarget. }
  if (AInstr.SystemContractKind = sckProcessInit) or
    (AInstr.SystemContractKind = sckProcessFini) or
    (AInstr.SystemContractKind = sckExceptionTryPush) or
    (AInstr.SystemContractKind = sckExceptionTryPop) or
    (AInstr.SystemContractKind = sckExceptionRaise) or
    (AInstr.SystemContractKind = sckExceptionFinallyEnd) or
    (AInstr.SystemContractKind = sckExceptionExceptEnd) then
  begin
    if Length(AInstr.Operands) <> 0 then
    begin
      AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
        ':' + IntToStr(Length(AInstr.Operands));
      Exit(False);
    end;
    Exit(True);
  end;

  { Halt: const exit-code in CallTarget, or one int operand for dynamic code. }
  if AInstr.SystemContractKind = sckHalt then
  begin
    if Length(AInstr.Operands) = 0 then
    begin
      if AInstr.CallTarget = '' then
      begin
        AError := 'system-contract-target-missing:' +
          IntToStr(ContractOrdinal);
        Exit(False);
      end;
      Exit(True);
    end;
    if Length(AInstr.Operands) <> 1 then
    begin
      AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
        ':' + IntToStr(Length(AInstr.Operands));
      Exit(False);
    end;
    if ATypes = nil then
    begin
      AError := 'system-contract-type-table-missing:' +
        IntToStr(ContractOrdinal);
      Exit(False);
    end;
    OperandType := ATypes.GetType(AInstr.Operands[0].TypeId);
    if OperandType.Kind <> htkInt then
    begin
      AError := 'system-contract-operand-not-int:' +
        IntToStr(ContractOrdinal) + ':' +
        IntToStr(AInstr.Operands[0].TypeId);
      Exit(False);
    end;
    Exit(True);
  end;

  { Managed string TString triad: init/fini = 1 ptr; assign = 2 ptr. }
  if (AInstr.SystemContractKind = sckStringInit) or
    (AInstr.SystemContractKind = sckStringFini) or
    (AInstr.SystemContractKind = sckStringAssign) then
  begin
    if ATypes = nil then
    begin
      AError := 'system-contract-type-table-missing:' +
        IntToStr(ContractOrdinal);
      Exit(False);
    end;
    if AInstr.SystemContractKind = sckStringAssign then
    begin
      if Length(AInstr.Operands) <> 2 then
      begin
        AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
          ':' + IntToStr(Length(AInstr.Operands));
        Exit(False);
      end;
    end
    else if Length(AInstr.Operands) <> 1 then
    begin
      AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
        ':' + IntToStr(Length(AInstr.Operands));
      Exit(False);
    end;
    for OperandIndex := 0 to High(AInstr.Operands) do
    begin
      OperandType := ATypes.GetType(AInstr.Operands[OperandIndex].TypeId);
      if OperandType.Kind <> htkPointer then
      begin
        AError := 'system-contract-operand-not-pointer:' +
          IntToStr(ContractOrdinal) + ':' +
          IntToStr(AInstr.Operands[OperandIndex].TypeId);
        Exit(False);
      end;
    end;
    Exit(True);
  end;

  { Dynarray fini: (ptr, len:int, elem_size:int). SetLength: + new_len:int. }
  if (AInstr.SystemContractKind = sckDynArrayFini) or
    (AInstr.SystemContractKind = sckDynArraySetLength) then
  begin
    if ATypes = nil then
    begin
      AError := 'system-contract-type-table-missing:' +
        IntToStr(ContractOrdinal);
      Exit(False);
    end;
    if AInstr.SystemContractKind = sckDynArraySetLength then
    begin
      if Length(AInstr.Operands) <> 4 then
      begin
        AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
          ':' + IntToStr(Length(AInstr.Operands));
        Exit(False);
      end;
    end
    else if Length(AInstr.Operands) <> 3 then
    begin
      AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
        ':' + IntToStr(Length(AInstr.Operands));
      Exit(False);
    end;
    OperandType := ATypes.GetType(AInstr.Operands[0].TypeId);
    if OperandType.Kind <> htkPointer then
    begin
      AError := 'system-contract-operand-not-pointer:' +
        IntToStr(ContractOrdinal) + ':' +
        IntToStr(AInstr.Operands[0].TypeId);
      Exit(False);
    end;
    for OperandIndex := 1 to High(AInstr.Operands) do
    begin
      OperandType := ATypes.GetType(AInstr.Operands[OperandIndex].TypeId);
      if OperandType.Kind <> htkInt then
      begin
        AError := 'system-contract-operand-not-int:' +
          IntToStr(ContractOrdinal) + ':' +
          IntToStr(AInstr.Operands[OperandIndex].TypeId);
        Exit(False);
      end;
    end;
    Exit(True);
  end;

  { Heap / object alloc: one size:int operand; result is caller-owned pointer. }
  if (AInstr.SystemContractKind = sckHeapAlloc) or
    (AInstr.SystemContractKind = sckObjectAlloc) then
  begin
    if Length(AInstr.Operands) <> 1 then
    begin
      AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
        ':' + IntToStr(Length(AInstr.Operands));
      Exit(False);
    end;
    if ATypes = nil then
    begin
      AError := 'system-contract-type-table-missing:' +
        IntToStr(ContractOrdinal);
      Exit(False);
    end;
    OperandType := ATypes.GetType(AInstr.Operands[0].TypeId);
    if OperandType.Kind <> htkInt then
    begin
      AError := 'system-contract-operand-not-int:' +
        IntToStr(ContractOrdinal) + ':' +
        IntToStr(AInstr.Operands[0].TypeId);
      Exit(False);
    end;
    Exit(True);
  end;

  { Heap free falls through: one pointer operand (default path). }

  if Length(AInstr.Operands) <> 1 then
  begin
    AError := 'system-contract-operand-count:' + IntToStr(ContractOrdinal) +
      ':' + IntToStr(Length(AInstr.Operands));
    Exit(False);
  end;

  if ATypes = nil then
  begin
    AError := 'system-contract-type-table-missing:' +
      IntToStr(ContractOrdinal);
    Exit(False);
  end;
  OperandType := ATypes.GetType(AInstr.Operands[0].TypeId);
  if OperandType.Kind <> htkPointer then
  begin
    AError := 'system-contract-operand-not-pointer:' +
      IntToStr(ContractOrdinal) + ':' +
      IntToStr(AInstr.Operands[0].TypeId);
    Exit(False);
  end;

  if ((AInstr.SystemContractKind = sckObjectFree) or
    (AInstr.SystemContractKind = sckObjectFreeDestroy) or
    (AInstr.SystemContractKind = sckObjectFreeCleanup)) and
    (AInstr.CallTarget = '') then
  begin
    AError := 'system-contract-target-missing:' +
      IntToStr(ContractOrdinal);
    Exit(False);
  end;
  Result := True;
end;

function ValidateObjectFreeSequenceContinuation(
  ARootReceiverValueId, AContinuationReceiverValueId: THIRValueId;
  const ARootDestroyTarget, AContinuationTarget: string;
  AContinuationKind: TSystemContractKind; out AError: string): Boolean;
begin
  AError := '';
  if AContinuationReceiverValueId <> ARootReceiverValueId then
  begin
    AError := 'system-contract-sequence-receiver-mismatch';
    Exit(False);
  end;
  if (AContinuationKind = sckObjectFreeDestroy) and
    (not SameText(AContinuationTarget, ARootDestroyTarget)) then
  begin
    AError := 'system-contract-sequence-destroy-target-mismatch';
    Exit(False);
  end;
  Result := True;
end;

constructor THIRModule.Create(const AName: string);
begin
  inherited Create;
  FModuleName := AName;
  FTypes := THIRTypeTable.Create;
  FFunctions := THirFunctionVec.Create;
  FGlobals := THirGlobalVec.Create;
  FGlobalIndex := specialize TDictionary<string, SizeInt>.Create;
  FVmtGlobals := THirVmtGlobalVec.Create;
  FImtGlobals := THirImtGlobalVec.Create;
  FUnitInitOrder := THirStringVec.Create;
  FNextValueId := 1;
  FNextBlockId := 1;
  FNextFuncId := 1;
end;

destructor THIRModule.Destroy;
var
  I, BI: SizeInt;
  Vmt: PHirVmtGlobal;
  Imt: PHirImtGlobal;
  Func: PHirFunction;
  Block: PHirBlock;
begin
  FUnitInitOrder.Free;
  FUnitInitOrder := nil;
  if FImtGlobals <> nil then
  begin
    for I := 0 to SizeInt(FImtGlobals.Count) - 1 do
    begin
      Imt := FImtGlobals.GetPtr(SizeUInt(I));
      Imt^.ThunkNames.Free;
      Imt^.ThunkNames := nil;
      Imt^.ThunkParamCounts.Free;
      Imt^.ThunkParamCounts := nil;
    end;
  end;
  FImtGlobals.Free;
  FImtGlobals := nil;
  if FVmtGlobals <> nil then
  begin
    for I := 0 to SizeInt(FVmtGlobals.Count) - 1 do
    begin
      Vmt := FVmtGlobals.GetPtr(SizeUInt(I));
      Vmt^.Funcs.Free;
      Vmt^.Funcs := nil;
    end;
  end;
  FVmtGlobals.Free;
  FVmtGlobals := nil;
  FGlobalIndex.Free;
  FGlobalIndex := nil;
  FGlobals.Free;
  FGlobals := nil;
  if FFunctions <> nil then
  begin
    for I := 0 to SizeInt(FFunctions.Count) - 1 do
    begin
      Func := FFunctions.GetPtr(SizeUInt(I));
      Func^.Params.Free;
      Func^.Params := nil;
      if Func^.Blocks <> nil then
      begin
        for BI := 0 to SizeInt(Func^.Blocks.Count) - 1 do
        begin
          Block := Func^.Blocks.GetPtr(SizeUInt(BI));
          Block^.Instrs.Free;
          Block^.Instrs := nil;
          Block^.Preds.Free;
          Block^.Preds := nil;
          Block^.Succs.Free;
          Block^.Succs := nil;
          Block^.Terminator.SwitchCases.Free;
          Block^.Terminator.SwitchCases := nil;
        end;
      end;
      Func^.Blocks.Free;
      Func^.Blocks := nil;
    end;
  end;
  FFunctions.Free;
  FFunctions := nil;
  FTypes.Free;
  inherited Destroy;
end;

function THIRModule.Types: THIRTypeTable;
begin
  Result := FTypes;
end;

function THIRModule.ModuleName: string;
begin
  Result := FModuleName;
end;

function THIRModule.NewValue: THIRValueId;
begin
  Result := FNextValueId;
  Inc(FNextValueId);
end;

function THIRModule.NewBlockId: THIRBlockId;
begin
  Result := FNextBlockId;
  Inc(FNextBlockId);
end;

function THIRModule.AddFunction(const AName: string;
  ARetType: THIRTypeId): THIRFuncId;
var
  Func: THIRFunction;
begin
  Func := Default(THIRFunction);
  Func.Id := FNextFuncId;
  Func.Name := AName;
  Func.ReturnTypeId := ARetType;
  Func.EntryBlockId := 0;
  Func.IsExternal := False;
  Func.UsesOwnedStringReturnAbi := False;
  Func.IsTStringReturnAbi := False;
  FFunctions.Push(Func);
  Result := FNextFuncId;
  Inc(FNextFuncId);
end;

procedure THIRModule.SetFunctionOwnedStringReturnAbi(AFuncId: THIRFuncId;
  AValue: Boolean);
var
  I: SizeInt;
  Func: PHirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.UsesOwnedStringReturnAbi := AValue;
      Exit;
    end;
  end;
end;

procedure THIRModule.SetFunctionTStringReturnAbi(AFuncId: THIRFuncId;
  AValue: Boolean);
var
  I: SizeInt;
  Func: PHirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.IsTStringReturnAbi := AValue;
      Exit;
    end;
  end;
end;

procedure THIRModule.SetFunctionExternal(AFuncId: THIRFuncId;
  AIsExternal: Boolean; const AExternalLib: string;
  const AExternalName: string);
var
  I: SizeInt;
  Func: PHirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.IsExternal := AIsExternal;
      Func^.ExternalLib := AExternalLib;
      Func^.ExternalName := AExternalName;
      Exit;
    end;
  end;
end;

procedure THIRModule.AddFunctionParam(AFuncId: THIRFuncId;
  const AName: string; ATypeId: THIRTypeId;
  AIsVar: Boolean; AIsConst: Boolean);
var
  I: SizeInt;
  Func: PHirFunction;
  Param: THIRParam;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      if Func^.Params = nil then
        Func^.Params := THirParamVec.Create;
      Param.Name := AName;
      Param.TypeId := ATypeId;
      Param.ValueId := NewValue;
      Param.IsVar := AIsVar;
      Param.IsConst := AIsConst;
      Func^.Params.Push(Param);
      Exit;
    end;
  end;
end;

function THIRModule.AddBlock(AFuncId: THIRFuncId;
  const AName: string): THIRBlockId;
var
  I: SizeInt;
  Func: PHirFunction;
  Block: THIRBlock;
begin
  Result := NewBlockId;
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      if Func^.Blocks = nil then
        Func^.Blocks := THirBlockVec.Create;
      Block := Default(THIRBlock);
      Block.Id := Result;
      Block.Name := AName;
      Block.Terminator.Kind := htkUnreachable;
      Func^.Blocks.Push(Block);
      Exit;
    end;
  end;
end;

procedure THIRModule.SetEntryBlock(AFuncId: THIRFuncId;
  ABlockId: THIRBlockId);
var
  I: SizeInt;
  Func: PHirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.EntryBlockId := ABlockId;
      Exit;
    end;
  end;
end;

procedure THIRModule.AddInstr(AFuncId: THIRFuncId; ABlockId: THIRBlockId;
  const AInstr: THIRInstr);
var
  FI, BI: SizeInt;
  Func: PHirFunction;
  Block: PHirBlock;
begin
  for FI := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.Id = AFuncId then
    begin
      if Func^.Blocks = nil then
        Exit;
      for BI := 0 to SizeInt(Func^.Blocks.Count) - 1 do
      begin
        Block := Func^.Blocks.GetPtr(SizeUInt(BI));
        if Block^.Id = ABlockId then
        begin
          if Block^.Instrs = nil then
            Block^.Instrs := THirInstrVec.Create;
          Block^.Instrs.Push(AInstr);
          Exit;
        end;
      end;
      Exit;
    end;
  end;
end;

procedure THIRModule.SetTerminator(AFuncId: THIRFuncId;
  ABlockId: THIRBlockId; const ATerm: THIRTerminator);
var
  FI, BI: SizeInt;
  Func: PHirFunction;
  Block: PHirBlock;
begin
  for FI := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.Id = AFuncId then
    begin
      if Func^.Blocks = nil then
        Exit;
      for BI := 0 to SizeInt(Func^.Blocks.Count) - 1 do
      begin
        Block := Func^.Blocks.GetPtr(SizeUInt(BI));
        if Block^.Id = ABlockId then
        begin
          if Block^.Terminator.SwitchCases <> ATerm.SwitchCases then
          begin
            Block^.Terminator.SwitchCases.Free;
            Block^.Terminator.SwitchCases := nil;
          end;
          Block^.Terminator := ATerm;
          Exit;
        end;
      end;
      Exit;
    end;
  end;
end;

procedure THIRModule.AddGlobal(const AName: string; ATypeId: THIRTypeId;
  AIsThreadVar: Boolean; AIsTStringStorage: Boolean);
var
  Global: THIRGlobal;
  LKey: string;
begin
  { Unit-scope same-name vars across units collapse to one LLVM @g_ name. }
  // O(1) hash dedup — reuse FGlobalIndex with LowerCase key, no linear scan
  LKey := LowerCase(AName);
  if (FGlobalIndex <> nil) and FGlobalIndex.ContainsKey(LKey) then
    Exit;
  Global := Default(THIRGlobal);
  Global.Name := AName;
  Global.TypeId := ATypeId;
  Global.ValueId := NewValue;
  Global.HasInit := False;
  Global.IsThreadVar := AIsThreadVar;
  Global.IsTStringStorage := AIsTStringStorage;
  FGlobals.Push(Global);
  if FGlobalIndex <> nil then
    FGlobalIndex.AddOrSetValue(LKey, SizeInt(FGlobals.Count) - 1);
end;

function THIRModule.FunctionCount: LongInt;
begin
  if FFunctions = nil then
    Exit(0);
  Result := LongInt(FFunctions.Count);
end;

function THIRModule.FunctionAt(AIndex: LongInt): THIRFunction;
begin
  Result := FFunctions[SizeUInt(AIndex)];
end;

function THIRModule.FindFunctionReturnType(const AName: string): THIRTypeId;
var
  I: LongInt;
  PF: ^THIRFunction;
begin
  for I := 0 to LongInt(FFunctions.Count) - 1 do
  begin
    PF := FFunctions.GetPtrUnchecked(SizeUInt(I));
    if PF^.Name = AName then
      Exit(PF^.ReturnTypeId);
  end;
  Result := 0;
end;

function THIRModule.GlobalCount: LongInt;
begin
  if FGlobals = nil then
    Exit(0);
  Result := LongInt(FGlobals.Count);
end;

function THIRModule.GlobalAt(AIndex: LongInt): THIRGlobal;
begin
  Result := FGlobals[SizeUInt(AIndex)];
end;

procedure THIRModule.AddVmtGlobal(const AClassName: string; const AFuncs: array of string);
var
  Idx, I: LongInt;
  Entry: THIRVmtGlobal;
begin
  for Idx := 0 to LongInt(FVmtGlobals.Count) - 1 do
    if FVmtGlobals[SizeUInt(Idx)].ClassName = AClassName then Exit;
  Entry := Default(THIRVmtGlobal);
  Entry.ClassName := AClassName;
  if Length(AFuncs) > 0 then
    Entry.Funcs := THirStringVec.Create(SizeUInt(Length(AFuncs)))
  else
    Entry.Funcs := THirStringVec.Create;
  for I := 0 to High(AFuncs) do
    Entry.Funcs.Push(AFuncs[I]);
  FVmtGlobals.Push(Entry);
end;

function THIRModule.VmtGlobalCount: LongInt;
begin
  if FVmtGlobals = nil then
    Exit(0);
  Result := LongInt(FVmtGlobals.Count);
end;

function THIRModule.VmtGlobalAt(AIndex: LongInt): THIRVmtGlobal;
begin
  Result := FVmtGlobals[SizeUInt(AIndex)];
end;

procedure THIRModule.AddImtGlobal(const AClassName, AInterfaceName: string;
  const AThunkNames: array of string;
  const AParamCounts: array of LongInt; ASlotOffset: LongInt);
var
  Idx, I: LongInt;
  Entry: THIRImtGlobal;
begin
  for Idx := 0 to LongInt(FImtGlobals.Count) - 1 do
    if (FImtGlobals[SizeUInt(Idx)].ClassName = AClassName) and
      (FImtGlobals[SizeUInt(Idx)].InterfaceName = AInterfaceName) then Exit;
  Entry := Default(THIRImtGlobal);
  Entry.ClassName := AClassName;
  Entry.InterfaceName := AInterfaceName;
  Entry.SlotOffset := ASlotOffset;
  if Length(AThunkNames) > 0 then
    Entry.ThunkNames := THirStringVec.Create(SizeUInt(Length(AThunkNames)))
  else
    Entry.ThunkNames := THirStringVec.Create;
  if Length(AParamCounts) > 0 then
    Entry.ThunkParamCounts := THirLongIntVec.Create(SizeUInt(Length(AParamCounts)))
  else
    Entry.ThunkParamCounts := THirLongIntVec.Create;
  for I := 0 to High(AThunkNames) do
    Entry.ThunkNames.Push(AThunkNames[I]);
  for I := 0 to High(AParamCounts) do
    Entry.ThunkParamCounts.Push(AParamCounts[I]);
  FImtGlobals.Push(Entry);
end;

function THIRModule.ImtGlobalCount: LongInt;
begin
  if FImtGlobals = nil then
    Exit(0);
  Result := LongInt(FImtGlobals.Count);
end;

function THIRModule.ImtGlobalAt(AIndex: LongInt): THIRImtGlobal;
begin
  Result := FImtGlobals[SizeUInt(AIndex)];
end;

procedure THIRModule.SetUnitInitOrder(const AOrder: array of string);
var
  I: LongInt;
begin
  if FUnitInitOrder = nil then
    FUnitInitOrder := THirStringVec.Create;
  FUnitInitOrder.Clear;
  for I := 0 to High(AOrder) do
    FUnitInitOrder.Push(AOrder[I]);
end;

function THIRModule.UnitInitOrderCount: LongInt;
begin
  if FUnitInitOrder = nil then
    Exit(0);
  Result := LongInt(FUnitInitOrder.Count);
end;

function THIRModule.UnitInitOrderAt(const AIndex: LongInt): string;
begin
  if (FUnitInitOrder = nil) or (AIndex < 0) or
    (AIndex >= LongInt(FUnitInitOrder.Count)) then
    Exit('');
  Result := FUnitInitOrder[SizeUInt(AIndex)];
end;

end.
