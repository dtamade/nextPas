unit np_hir_model;

{$mode objfpc}{$H+}

interface

uses
  np_hir_types;

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
    hikRaise
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
    SourceLine: LongInt;
    SourceCol: LongInt;
  end;

  THIRSwitchCase = record
    Value: Int64;
    TargetBlock: THIRBlockId;
  end;

  THIRTerminator = record
    Kind: THIRTermKind;
    ReturnValue: THIRValueId;
    Condition: THIRValueId;
    TrueBlock: THIRBlockId;
    FalseBlock: THIRBlockId;
    TargetBlock: THIRBlockId;
    SwitchCases: array of THIRSwitchCase;
    DefaultBlock: THIRBlockId;
  end;

  THIRBlock = record
    Id: THIRBlockId;
    Name: string;
    Instrs: array of THIRInstr;
    Terminator: THIRTerminator;
    Preds: array of THIRBlockId;
    Succs: array of THIRBlockId;
  end;

  THIRParam = record
    Name: string;
    TypeId: THIRTypeId;
    ValueId: THIRValueId;
    IsVar: Boolean;
    IsConst: Boolean;
  end;

  THIRFunction = record
    Id: THIRFuncId;
    Name: string;
    ReturnTypeId: THIRTypeId;
    Params: array of THIRParam;
    Blocks: array of THIRBlock;
    EntryBlockId: THIRBlockId;
    IsExternal: Boolean;
    UsesOwnedStringReturnAbi: Boolean;
  end;

  THIRVmtGlobal = record
    ClassName: string;
    Funcs: array of string;
  end;

  THIRImtGlobal = record
    ClassName: string;
    InterfaceName: string;
    ThunkNames: array of string;
    ThunkParamCounts: array of LongInt;
    SlotOffset: LongInt;
  end;

  THIRGlobal = record
    Name: string;
    TypeId: THIRTypeId;
    ValueId: THIRValueId;
    InitValue: Int64;
    InitStr: string;
    HasInit: Boolean;
  end;

  THIRModule = class
  private
    FTypes: THIRTypeTable;
    FFunctions: array of THIRFunction;
    FGlobals: array of THIRGlobal;
    FVmtGlobals: array of THIRVmtGlobal;
    FImtGlobals: array of THIRImtGlobal;
    FNextValueId: THIRValueId;
    FNextBlockId: THIRBlockId;
    FNextFuncId: THIRFuncId;
    FModuleName: string;
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

    procedure AddGlobal(const AName: string; ATypeId: THIRTypeId);

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
  end;

function MakeOperand(AValueId: THIRValueId): THIROperand;
function MakeTypedOperand(AValueId: THIRValueId; ATypeId: THIRTypeId): THIROperand;

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

constructor THIRModule.Create(const AName: string);
begin
  inherited Create;
  FModuleName := AName;
  FTypes := THIRTypeTable.Create;
  SetLength(FFunctions, 0);
  SetLength(FGlobals, 0);
  SetLength(FVmtGlobals, 0);
  SetLength(FImtGlobals, 0);
  FNextValueId := 1;
  FNextBlockId := 1;
  FNextFuncId := 1;
end;

destructor THIRModule.Destroy;
begin
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
  Idx: SizeInt;
begin
  Idx := Length(FFunctions);
  SetLength(FFunctions, Idx + 1);
  FFunctions[Idx].Id := FNextFuncId;
  FFunctions[Idx].Name := AName;
  FFunctions[Idx].ReturnTypeId := ARetType;
  FFunctions[Idx].EntryBlockId := 0;
  FFunctions[Idx].IsExternal := False;
  FFunctions[Idx].UsesOwnedStringReturnAbi := False;
  SetLength(FFunctions[Idx].Params, 0);
  SetLength(FFunctions[Idx].Blocks, 0);
  Result := FNextFuncId;
  Inc(FNextFuncId);
end;

procedure THIRModule.SetFunctionOwnedStringReturnAbi(AFuncId: THIRFuncId;
  AValue: Boolean);
var
  I: SizeInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      FFunctions[I].UsesOwnedStringReturnAbi := AValue;
      Exit;
    end;
end;

procedure THIRModule.AddFunctionParam(AFuncId: THIRFuncId;
  const AName: string; ATypeId: THIRTypeId;
  AIsVar: Boolean; AIsConst: Boolean);
var
  I, Idx: SizeInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      Idx := Length(FFunctions[I].Params);
      SetLength(FFunctions[I].Params, Idx + 1);
      FFunctions[I].Params[Idx].Name := AName;
      FFunctions[I].Params[Idx].TypeId := ATypeId;
      FFunctions[I].Params[Idx].ValueId := NewValue;
      FFunctions[I].Params[Idx].IsVar := AIsVar;
      FFunctions[I].Params[Idx].IsConst := AIsConst;
      Exit;
    end;
end;

function THIRModule.AddBlock(AFuncId: THIRFuncId;
  const AName: string): THIRBlockId;
var
  I, Idx: SizeInt;
begin
  Result := NewBlockId;
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      Idx := Length(FFunctions[I].Blocks);
      SetLength(FFunctions[I].Blocks, Idx + 1);
      FFunctions[I].Blocks[Idx].Id := Result;
      FFunctions[I].Blocks[Idx].Name := AName;
      SetLength(FFunctions[I].Blocks[Idx].Instrs, 0);
      SetLength(FFunctions[I].Blocks[Idx].Preds, 0);
      SetLength(FFunctions[I].Blocks[Idx].Succs, 0);
      FFunctions[I].Blocks[Idx].Terminator.Kind := htkUnreachable;
      Exit;
    end;
end;

procedure THIRModule.SetEntryBlock(AFuncId: THIRFuncId;
  ABlockId: THIRBlockId);
var
  I: SizeInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      FFunctions[I].EntryBlockId := ABlockId;
      Exit;
    end;
end;

procedure THIRModule.AddInstr(AFuncId: THIRFuncId; ABlockId: THIRBlockId;
  const AInstr: THIRInstr);
var
  FI, BI, Idx: SizeInt;
begin
  for FI := 0 to High(FFunctions) do
    if FFunctions[FI].Id = AFuncId then
    begin
      for BI := 0 to High(FFunctions[FI].Blocks) do
        if FFunctions[FI].Blocks[BI].Id = ABlockId then
        begin
          Idx := Length(FFunctions[FI].Blocks[BI].Instrs);
          SetLength(FFunctions[FI].Blocks[BI].Instrs, Idx + 1);
          FFunctions[FI].Blocks[BI].Instrs[Idx] := AInstr;
          Exit;
        end;
      Exit;
    end;
end;

procedure THIRModule.SetTerminator(AFuncId: THIRFuncId;
  ABlockId: THIRBlockId; const ATerm: THIRTerminator);
var
  FI, BI: SizeInt;
begin
  for FI := 0 to High(FFunctions) do
    if FFunctions[FI].Id = AFuncId then
    begin
      for BI := 0 to High(FFunctions[FI].Blocks) do
        if FFunctions[FI].Blocks[BI].Id = ABlockId then
        begin
          FFunctions[FI].Blocks[BI].Terminator := ATerm;
          Exit;
        end;
      Exit;
    end;
end;

procedure THIRModule.AddGlobal(const AName: string; ATypeId: THIRTypeId);
var
  Idx: SizeInt;
begin
  Idx := Length(FGlobals);
  SetLength(FGlobals, Idx + 1);
  FGlobals[Idx].Name := AName;
  FGlobals[Idx].TypeId := ATypeId;
  FGlobals[Idx].ValueId := NewValue;
  FGlobals[Idx].HasInit := False;
end;

function THIRModule.FunctionCount: LongInt;
begin
  Result := Length(FFunctions);
end;

function THIRModule.FunctionAt(AIndex: LongInt): THIRFunction;
begin
  Result := FFunctions[AIndex];
end;

function THIRModule.FindFunctionReturnType(const AName: string): THIRTypeId;
var
  I: LongInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Name = AName then
      Exit(FFunctions[I].ReturnTypeId);
  Result := 0;
end;

function THIRModule.GlobalCount: LongInt;
begin
  Result := Length(FGlobals);
end;

function THIRModule.GlobalAt(AIndex: LongInt): THIRGlobal;
begin
  Result := FGlobals[AIndex];
end;

procedure THIRModule.AddVmtGlobal(const AClassName: string; const AFuncs: array of string);
var
  Idx, I: LongInt;
begin
  for Idx := 0 to Length(FVmtGlobals) - 1 do
    if FVmtGlobals[Idx].ClassName = AClassName then Exit;
  Idx := Length(FVmtGlobals);
  SetLength(FVmtGlobals, Idx + 1);
  FVmtGlobals[Idx].ClassName := AClassName;
  SetLength(FVmtGlobals[Idx].Funcs, Length(AFuncs));
  for I := 0 to High(AFuncs) do
    FVmtGlobals[Idx].Funcs[I] := AFuncs[I];
end;

function THIRModule.VmtGlobalCount: LongInt;
begin
  Result := Length(FVmtGlobals);
end;

function THIRModule.VmtGlobalAt(AIndex: LongInt): THIRVmtGlobal;
begin
  Result := FVmtGlobals[AIndex];
end;

procedure THIRModule.AddImtGlobal(const AClassName, AInterfaceName: string;
  const AThunkNames: array of string;
  const AParamCounts: array of LongInt; ASlotOffset: LongInt);
var
  Idx, I: LongInt;
begin
  for Idx := 0 to Length(FImtGlobals) - 1 do
    if (FImtGlobals[Idx].ClassName = AClassName) and
      (FImtGlobals[Idx].InterfaceName = AInterfaceName) then Exit;
  Idx := Length(FImtGlobals);
  SetLength(FImtGlobals, Idx + 1);
  FImtGlobals[Idx].ClassName := AClassName;
  FImtGlobals[Idx].InterfaceName := AInterfaceName;
  FImtGlobals[Idx].SlotOffset := ASlotOffset;
  SetLength(FImtGlobals[Idx].ThunkNames, Length(AThunkNames));
  SetLength(FImtGlobals[Idx].ThunkParamCounts, Length(AParamCounts));
  for I := 0 to High(AThunkNames) do
    FImtGlobals[Idx].ThunkNames[I] := AThunkNames[I];
  for I := 0 to High(AParamCounts) do
    FImtGlobals[Idx].ThunkParamCounts[I] := AParamCounts[I];
end;

function THIRModule.ImtGlobalCount: LongInt;
begin
  Result := Length(FImtGlobals);
end;

function THIRModule.ImtGlobalAt(AIndex: LongInt): THIRImtGlobal;
begin
  Result := FImtGlobals[AIndex];
end;

end.
