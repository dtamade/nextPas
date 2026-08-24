unit nextpas.compiler.ir.hir.builder;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.sema.semantic_model, nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model, nextpas.compiler.frontend.source_database,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TExprStack = record
    Values: specialize TVec<THIRValueId>;
    Types: specialize TVec<THIRTypeId>;
    procedure Init(AAllocator: IAllocator = nil);
    procedure Done;
    procedure Push(AVal: THIRValueId);
    procedure PushTyped(AVal: THIRValueId; AType: THIRTypeId);
    function Pop: THIRValueId;
    function PopTyped(out AType: THIRTypeId): THIRValueId;
    function PeekType: THIRTypeId;
    function Count: LongInt;
  end;

  TAllocaEntry = record
    Name: string;
    Value: THIRValueId;
    TypeId: THIRTypeId;
    RecordSlots: LongInt;
    IsVarParam: Boolean;
  end;

  THIRExprResult = record
    ValueId: THIRValueId;
    TypeId: THIRTypeId;
    ValueClass: TSemanticHirValueClass;
    AddressValueId: THIRValueId;
  end;

  TTypedHirNodeVec = specialize TVec<TTypedHirNode>;
  THirNameVec = specialize TVec<string>;
  THirBlockNameVec = THirNameVec;
  THirBlockIdVec = specialize TVec<THIRBlockId>;
  THirAllocaVec = specialize TVec<TAllocaEntry>;
  THirTypeIdVec = specialize TVec<THIRTypeId>;
  THirValueIdVec = specialize TVec<THIRValueId>;

  THIRBuilder = class
  private
    FSemaModel: TSemanticModel;
    FModule: THIRModule;
    { Optional phase scratch for working TVecs (cleanup/blocks/allocas/globals). }
    FAllocator: IAllocator;
    FCurrentFuncId: THIRFuncId;
    FCurrentBlockId: THIRBlockId;
    FBlockTerminated: Boolean;
    FSavedFuncId: THIRFuncId;
    FSavedBlockId: THIRBlockId;
    FSavedAllocas: THirAllocaVec;
    FSavedBlockNames: THirNameVec;
    FSavedBlockIds: THirBlockIdVec;
    FSavedEntryBlockId: THIRBlockId;
    FPendingParamCount: LongInt;
    FPendingParamLlvmIdx: LongInt;
    FPendingObjectFreeDestroyName: string;
    FPendingObjectFreeReceiverName: string;
    FPendingObjectFreeReceiverValue: THIRValueId;
    FPendingObjectFreeCleanupClass: string;
    FPendingObjectFreeHeapRelease: Boolean;
    FPendingCleanupNodes: TTypedHirNodeVec;
    FSretValueId: THIRValueId;

    FAllocas: THirAllocaVec;

    FIntfVarNames: THirNameVec;

    FGlobalNames: THirNameVec;
    FGlobalTypes: THirTypeIdVec;
    FGlobalRefCache: THirNameVec;
    FGlobalRefValues: THirValueIdVec;
    FInStartFunc: Boolean;
    FEntryBlockId: THIRBlockId;

    FBlockNames: THirBlockNameVec;
    FBlockIds: THirBlockIdVec;

    FFwdFuncNames: THirNameVec;
    FFwdFuncRetTypes: THirTypeIdVec;
    FLegacyIntType: THIRTypeId;
    FBoolType: THIRTypeId;
    FStringType: THIRTypeId;
    FPtrType: THIRTypeId;
    FIntTypeCache: array[0..3, 0..1] of THIRTypeId;
    FFloat32Type: THIRTypeId;
    FFloat64Type: THIRTypeId;

    { Source position tracking for debug info }
    FSourceDatabase: TSourceDatabase;
    FCurrentSourceFileId: TSourceFileId;
    FCurrentSourceLine: LongInt;
    FCurrentSourceCol: LongInt;

    procedure ClearWorkBlocks;
    procedure SnapshotWorkTables(AAllocas: THirAllocaVec;
      ANames: THirNameVec; AIds: THirBlockIdVec);
    procedure RestoreWorkBlocks(ANames: THirNameVec; AIds: THirBlockIdVec);
    procedure ClearWorkAllocas;
    procedure RestoreWorkAllocas(AEntries: THirAllocaVec);
    function CreateAllocaVec: THirAllocaVec;
    function CreateNameVec: THirNameVec;
    function CreateBlockIdVec: THirBlockIdVec;
    procedure ClearGlobalRefs;
    procedure RegisterGlobal(const AName: string; AType: THIRTypeId);
    function EnsureBlock(const AName: string): THIRBlockId;
    function FindBlock(const AName: string): THIRBlockId;
    procedure EnsureAlloca(const AName: string; AType: THIRTypeId);
    procedure RegisterAllocaEntry(const AName: string; AValue: THIRValueId;
      AType: THIRTypeId; AIsVarParam: Boolean);
    function FindAlloca(const AName: string): THIRValueId;
    function FindLocalAlloca(const AName: string): THIRValueId;
    function FindAllocaType(const AName: string): THIRTypeId;
    function IsVarParamAlloca(const AName: string): Boolean;
    function GetIntType: THIRTypeId;
    function GetBoolType: THIRTypeId;
    function GetStringType: THIRTypeId;
    function GetPtrType: THIRTypeId;
    function GetIntTypeByWidth(const ABitWidth: LongInt;
      const ASigned: Boolean): THIRTypeId;
    function GetFloatTypeByWidth(const ABitWidth: LongInt): THIRTypeId;
    function SemanticTypeIdToHirTypeId(const ATypeId: LongInt): THIRTypeId;
    function ExprHirTypeId(const AExpr: TSemanticHirExpr): THIRTypeId;
    function ExprIdHirTypeId(const AExprId: LongInt): THIRTypeId;
    function HirTypeIsInt(const ATypeId: THIRTypeId): Boolean;
    function HirTypeIsBool(const ATypeId: THIRTypeId): Boolean;
    function TryClassifyScalarCast(const ASourceTypeId,
      ATargetTypeId: THIRTypeId; out AKind: THIRInstrKind;
      out ANoOp: Boolean): Boolean;

    procedure EmitInstr(const AInstr: THIRInstr);
    function EmitBinOp(AKind: THIRInstrKind; AType: THIRTypeId;
      ALhs, ARhs: THIRValueId): THIRValueId;
    function EmitCmpOp(AKind: THIRInstrKind; AType: THIRTypeId;
      ALhs, ARhs: THIRValueId; ALhsType, ARhsType: THIRTypeId): THIRValueId;
    function EmitLoad(AType: THIRTypeId; AAddr: THIRValueId): THIRValueId;
    procedure EmitStore(AType: THIRTypeId; AVal, AAddr: THIRValueId);

    function ParseIntExprArg(const AExprArg: string): THIRValueId;
    function ParseIntExprArgTyped(const AExprArg: string;
      out ATypeId: THIRTypeId): THIRValueId;
    procedure EmitExprInt(var S: TExprStack; const AArg: string);
    procedure EmitExprNull(var S: TExprStack);
    procedure EmitExprVar(var S: TExprStack; const AArg: string);
    procedure EmitExprVarRef(var S: TExprStack; const AArg: string);
    procedure EmitExprRecVar(var S: TExprStack; const AArg: string);
    procedure EmitExprStrVar(var S: TExprStack; const AArg: string);
    procedure EmitExprTsData(var S: TExprStack; const AArg: string);
    procedure EmitExprStrLit(var S: TExprStack; const AArg: string);
    procedure EmitExprIs(var S: TExprStack; const AArg: string);
    procedure EmitExprArrLoad(var S: TExprStack);
    procedure EmitExprArrLoadPtr(var S: TExprStack);
    procedure EmitExprArrElemRef(var S: TExprStack; const AArg: string);
    procedure EmitExprPtrElemLoad(var S: TExprStack; const AArg: string);
    procedure EmitExprFieldRef(var S: TExprStack; const AArg: string);
    procedure EmitExprRLoad(var S: TExprStack; const AArg: string);
    procedure EmitExprFieldStrLen(var S: TExprStack; const AArg: string);
    procedure EmitExprUnaryOp(var S: TExprStack; AKind: THIRInstrKind;
      const AIntrinsic: string);
    procedure EmitExprBinOp(var S: TExprStack; AKind: THIRInstrKind);
    procedure EmitExprCmp(var S: TExprStack; const AArg: string);
    procedure EmitExprStrCmp(var S: TExprStack; const AArg: string);
    procedure EmitExprStrPos(var S: TExprStack);
    procedure EmitExprZext(var S: TExprStack);
    procedure EmitExprCall(var S: TExprStack; const AArg: string);
    procedure EmitExprInterlocked(var S: TExprStack; const AArg: string);
    procedure EmitExprICall(var S: TExprStack; const AArg: string);
    procedure EmitExprArrLoadVar(var S: TExprStack; const AArg: string);
    procedure EmitExprTsLoad(var S: TExprStack; const AArg: string);
    procedure EmitExprField(var S: TExprStack; const AArg: string);
    procedure EmitExprVcall(var S: TExprStack; AArg: string);
    procedure EmitExprIvcall(var S: TExprStack; AArg: string);
    function LowerExprKind(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerCastExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerUnaryExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerBinaryExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerCompareExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerCallExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerDispatchedCallExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    procedure InitExprResult(out AResult: THIRExprResult);
    procedure SetExprValue(out AResult: THIRExprResult;
      const AValueId: THIRValueId; const ATypeId: THIRTypeId;
      const AValueClass: TSemanticHirValueClass);
    procedure SetExprAddress(out AResult: THIRExprResult;
      const AAddressValueId: THIRValueId; const ATypeId: THIRTypeId);
    function CanLowerExpr(const AExprId: LongInt): Boolean;
    function CanLowerExprAsAddress(const AExprId: LongInt): Boolean;
    function CanLowerExprKind(const AExpr: TSemanticHirExpr): Boolean;
    function EmitConstFloat(const AValue: Double): THIRValueId;
    function GetFloatType: THIRTypeId;
    function EmitConstInt(const AValue: Int64): THIRValueId;
    function EmitConstIntSmart(const AValue: Int64): THIRValueId;
    function EmitConstIntOfType(const AValue: Int64;
      const ATypeId: THIRTypeId): THIRValueId;
    function EmitNullPtrValue: THIRValueId;
    function ParseArrayDeclOperand(const AOperand: string; out AName: string;
      out AIsStatic: Boolean; out ALow, AHigh, ALength: Int64): Boolean;
    procedure EmitStaticArrayBacking(const AName: string; const ALength: Int64);
    procedure InitializeDynArraySlots(const AName: string);
    function NormalizeArrayIndexValue(const AArrayName: string;
      const AIndexValue: THIRValueId): THIRValueId;
    function EmitStructuredSymbolValue(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerSymbolAddressExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerAddressOfExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerDerefExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerFieldExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function LowerArrayElemExpr(const AExpr: TSemanticHirExpr;
      out AResult: THIRExprResult): Boolean;
    function CompareKindForOp(const AOp: string; out AKind: THIRInstrKind): Boolean;
    function BinaryKindForOp(const AOp: string; out AKind: THIRInstrKind): Boolean;
    function LowerExprValue(const AExprId: LongInt;
      out AResult: THIRExprResult): Boolean;
    function LowerExprAddress(const AExprId: LongInt;
      out AResult: THIRExprResult): Boolean;
    function LowerNodeExprOrBlob(const ANode: TTypedHirNode;
      const AExprArg: string): THIRValueId;
    function LowerNodeExprOrBlobTyped(const ANode: TTypedHirNode;
      const AExprArg: string; out ATypeId: THIRTypeId): THIRValueId;
    function LowerNodeTargetExprAddress(const ANode: TTypedHirNode;
      out AResult: THIRExprResult): Boolean;
    function NormalizeScalarValueToType(const AValueId: THIRValueId;
      const ASourceTypeId, ATargetTypeId: THIRTypeId): THIRValueId;
    function NormalizeInt64RuntimeValue(const AValueId: THIRValueId;
      const ATypeId: THIRTypeId): THIRValueId;
    procedure ProcessIntfAdjust(const ANode: TTypedHirNode);
    procedure ProcessIntfAddRef(const ANode: TTypedHirNode);
    procedure ProcessIntfRelease(const ANode: TTypedHirNode);
    procedure ProcessNode(const ANode: TTypedHirNode);
    procedure QueueCleanupNode(const ANode: TTypedHirNode);
    procedure FlushPendingCleanupNodes;
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
    procedure ProcessExternalDecl(const ANode: TTypedHirNode);
    procedure ProcessRetRuntime(const ANode: TTypedHirNode);
    procedure ProcessCallRuntime(const ANode: TTypedHirNode);
    procedure ProcessStringTempOwnedRuntime(const ANode: TTypedHirNode);
    procedure ProcessStringTempBorrowArgRuntime(const ANode: TTypedHirNode);
    procedure ProcessStringTempLengthRuntime(const ANode: TTypedHirNode);
    procedure ProcessStringTempReleaseRuntime(const ANode: TTypedHirNode);
    procedure ProcessObjectFreeRuntime(const ANode: TTypedHirNode);
    procedure ProcessFillCharRuntime(const ANode: TTypedHirNode);
    procedure ProcessMoveRuntime(const ANode: TTypedHirNode);
    procedure ProcessGetMemRuntime(const ANode: TTypedHirNode);
    procedure ProcessFreeMemRuntime(const ANode: TTypedHirNode);
    procedure ProcessAssignedRuntime(const ANode: TTypedHirNode);
    procedure ProcessInterlockedOp(const ANode: TTypedHirNode);
    procedure ProcessWriteInt(const ANode: TTypedHirNode);
    procedure ProcessWriteStr(const ANode: TTypedHirNode);
    procedure ProcessWriteString(const ANode: TTypedHirNode);
    procedure ProcessWriteCall(const ANode: TTypedHirNode);
    procedure ProcessWriteStrVar(const ANode: TTypedHirNode);
    procedure ProcessIntToStr(const ANode: TTypedHirNode);
    procedure ProcessCopyStr(const ANode: TTypedHirNode);
    procedure ProcessSetLengthArr(const ANode: TTypedHirNode);
    procedure ProcessSetLengthFieldArr(const ANode: TTypedHirNode);
    procedure ProcessDynArrayCleanup(const ANode: TTypedHirNode);
    procedure ProcessManagedRecordCleanup(const ANode: TTypedHirNode);
    procedure ProcessAssignArrElem(const ANode: TTypedHirNode);
    procedure ProcessMethodBegin(const ANode: TTypedHirNode);
    procedure ProcessClassNew(const ANode: TTypedHirNode);
    procedure ProcessFieldStore(const ANode: TTypedHirNode);
    procedure ProcessRecordFieldStore(const ANode: TTypedHirNode);
    procedure ProcessRecordCopy(const ANode: TTypedHirNode);
    procedure ProcessVmtStore(const ANode: TTypedHirNode);
    function FieldSlotPtr(AObjectPtr: THIRValueId;
      const ASlotIndex: LongInt): THIRValueId;
    procedure EmitObjectStringCleanupCall(const AClassName: string;
      const AReceiverPtr: THIRValueId);
    procedure EmitObjectDynArrayCleanupCall(const AClassName: string;
      const AReceiverPtr: THIRValueId);
    procedure EnsureObjectStringCleanupHelper(const AClassName: string);
    procedure EnsureObjectDynArrayCleanupHelper(const AClassName: string);
    procedure EmitInterfaceSlotStore(AObjPtr: THIRValueId;
      const AClassName: string; const ASlot: TInterfaceSlotMeta);
    procedure ProcessExceptionNode(const ANode: TTypedHirNode);
    procedure EmitProcessInit;
    procedure EmitProcessFini;
    procedure EnsureVmtForClass(const AClassName: string);
    { TString 24B runtime }
    procedure ProcessVarDeclTString(const ANode: TTypedHirNode);
    procedure ProcessAssignTStringLiteral(const ANode: TTypedHirNode);
    procedure ProcessAssignTStringCopy(const ANode: TTypedHirNode);
    procedure ProcessAssignTStringConcat(const ANode: TTypedHirNode);
    procedure ProcessAssignTStringCall(const ANode: TTypedHirNode);
    procedure ProcessAssignTStringFieldLoad(const ANode: TTypedHirNode);
    procedure ProcessFieldStoreTString(const ANode: TTypedHirNode);
    procedure ProcessRetTString(const ANode: TTypedHirNode);
    procedure EmitTStringInit(const AName: string);
    procedure EmitTStringFini(AValue: THIRValueId);
    procedure EmitTStringAssign(ADst, ASrc: THIRValueId);
    function EmitTStringLen(AValue: THIRValueId): THIRValueId;
    function EmitTStringData(AValue: THIRValueId): THIRValueId;
    procedure SetCurrentSourcePosFromSymbol(ASymbolId: LongInt);
  public
    constructor Create(ASemaModel: TSemanticModel;
      ASourceDatabase: TSourceDatabase = nil;
      ASourceFileId: TSourceFileId = 0;
      const AAllocator: IAllocator = nil);
    destructor Destroy; override;
    function LowerExpr(const AExprId: LongInt;
      out AResult: THIRExprResult): Boolean;
    procedure Build;
    function Module: THIRModule;
  end;

implementation

uses
  nextpas.core.text.conv, nextpas.core.os.env, nextpas.compiler.ir.system_contracts;

procedure TExprStack.Init(AAllocator: IAllocator);
begin
  if AAllocator <> nil then
  begin
    Values := specialize TVec<THIRValueId>.Create(0, AAllocator);
    Types := specialize TVec<THIRTypeId>.Create(0, AAllocator);
  end
  else
  begin
    Values := specialize TVec<THIRValueId>.Create;
    Types := specialize TVec<THIRTypeId>.Create;
  end;
end;

procedure TExprStack.Done;
begin
  Types.Free;
  Values.Free;
  Types := nil;
  Values := nil;
end;

procedure TExprStack.Push(AVal: THIRValueId);
begin
  Values.Push(AVal);
  Types.Push(0);
end;

procedure TExprStack.PushTyped(AVal: THIRValueId; AType: THIRTypeId);
begin
  Values.Push(AVal);
  Types.Push(AType);
end;

function TExprStack.Pop: THIRValueId;
var
  Dummy: THIRTypeId;
begin
  if Values.Count = 0 then
    Exit(0);
  if not Values.TryPop(Result) then
    Exit(0);
  if not Types.TryPop(Dummy) then
    ; { keep Values/Types lengths aligned }
end;

function TExprStack.PopTyped(out AType: THIRTypeId): THIRValueId;
begin
  AType := 0;
  if Values.Count = 0 then
    Exit(0);
  if not Values.TryPop(Result) then
    Exit(0);
  if not Types.TryPop(AType) then
    AType := 0;
end;

function TExprStack.PeekType: THIRTypeId;
begin
  if Types.Count = 0 then
    Exit(0);
  Result := Types[Types.Count - 1];
end;

function TExprStack.Count: LongInt;
begin
  Result := LongInt(Values.Count);
end;

function ExtractVarOperandName(const AExprArg: string): string;
begin
  Result := '';
  if (Length(AExprArg) > 4) and (Copy(AExprArg, 1, 4) = 'var ') then
  begin
    Result := Copy(AExprArg, 5, Length(AExprArg));
    if (Length(Result) > 0) and (Result[Length(Result)] = #10) then
      Result := Copy(Result, 1, Length(Result) - 1);
    Result := Trim(Result);
  end;
end;

function ExtractPlainVarOperandName(const AExprArg: string): string;
var
  NewlinePos: LongInt;
begin
  Result := '';
  if (Length(AExprArg) <= 4) or (Copy(AExprArg, 1, 4) <> 'var ') then
    Exit;
  NewlinePos := Pos(#10, AExprArg);
  if (NewlinePos <= 5) or (NewlinePos <> Length(AExprArg)) then
    Exit;
  Result := Trim(Copy(AExprArg, 5, NewlinePos - 5));
end;

constructor THIRBuilder.Create(ASemaModel: TSemanticModel;
  ASourceDatabase: TSourceDatabase; ASourceFileId: TSourceFileId;
  const AAllocator: IAllocator);
var
  I, J: LongInt;
begin
  inherited Create;
  FSemaModel := ASemaModel;
  FSourceDatabase := ASourceDatabase;
  FCurrentSourceFileId := ASourceFileId;
  FAllocator := AAllocator;
  FCurrentSourceLine := 0;
  FCurrentSourceCol := 0;
  FModule := THIRModule.Create('main');
  FCurrentFuncId := 0;
  FCurrentBlockId := 0;
  FBlockTerminated := False;
  FInStartFunc := True;
  FEntryBlockId := 0;
  FPendingParamCount := 0;
  FPendingParamLlvmIdx := 0;
  FPendingObjectFreeDestroyName := '';
  FPendingObjectFreeReceiverName := '';
  FPendingObjectFreeReceiverValue := 0;
  FPendingObjectFreeCleanupClass := '';
  FPendingObjectFreeHeapRelease := False;
  if FAllocator <> nil then
  begin
    FPendingCleanupNodes := TTypedHirNodeVec.Create(0, FAllocator);
    FBlockNames := THirBlockNameVec.Create(0, FAllocator);
    FBlockIds := THirBlockIdVec.Create(0, FAllocator);
    FAllocas := THirAllocaVec.Create(0, FAllocator);
    FSavedAllocas := THirAllocaVec.Create(0, FAllocator);
    FSavedBlockNames := THirNameVec.Create(0, FAllocator);
    FSavedBlockIds := THirBlockIdVec.Create(0, FAllocator);
    FIntfVarNames := THirNameVec.Create(0, FAllocator);
    FGlobalNames := THirNameVec.Create(0, FAllocator);
    FGlobalTypes := THirTypeIdVec.Create(0, FAllocator);
    FGlobalRefCache := THirNameVec.Create(0, FAllocator);
    FGlobalRefValues := THirValueIdVec.Create(0, FAllocator);
    FFwdFuncNames := THirNameVec.Create(0, FAllocator);
    FFwdFuncRetTypes := THirTypeIdVec.Create(0, FAllocator);
  end
  else
  begin
    FPendingCleanupNodes := TTypedHirNodeVec.Create;
    FBlockNames := THirBlockNameVec.Create;
    FBlockIds := THirBlockIdVec.Create;
    FAllocas := THirAllocaVec.Create;
    FSavedAllocas := THirAllocaVec.Create;
    FSavedBlockNames := THirNameVec.Create;
    FSavedBlockIds := THirBlockIdVec.Create;
    FIntfVarNames := THirNameVec.Create;
    FGlobalNames := THirNameVec.Create;
    FGlobalTypes := THirTypeIdVec.Create;
    FGlobalRefCache := THirNameVec.Create;
    FGlobalRefValues := THirValueIdVec.Create;
    FFwdFuncNames := THirNameVec.Create;
    FFwdFuncRetTypes := THirTypeIdVec.Create;
  end;
  FLegacyIntType := 0;
  FBoolType := 0;
  FStringType := 0;
  FPtrType := 0;
  FFloat32Type := 0;
  FFloat64Type := 0;
  for I := Low(FIntTypeCache) to High(FIntTypeCache) do
    for J := Low(FIntTypeCache[I]) to High(FIntTypeCache[I]) do
      FIntTypeCache[I, J] := 0;
end;

destructor THIRBuilder.Destroy;
begin
  FFwdFuncRetTypes.Free;
  FFwdFuncNames.Free;
  FGlobalRefValues.Free;
  FGlobalRefCache.Free;
  FGlobalTypes.Free;
  FGlobalNames.Free;
  FIntfVarNames.Free;
  FSavedBlockIds.Free;
  FSavedBlockNames.Free;
  FSavedAllocas.Free;
  FAllocas.Free;
  FBlockIds.Free;
  FBlockNames.Free;
  FPendingCleanupNodes.Free;
  inherited Destroy;
end;

function THIRBuilder.CreateAllocaVec: THirAllocaVec;
begin
  if FAllocator <> nil then
    Result := THirAllocaVec.Create(0, FAllocator)
  else
    Result := THirAllocaVec.Create;
end;

function THIRBuilder.CreateNameVec: THirNameVec;
begin
  if FAllocator <> nil then
    Result := THirNameVec.Create(0, FAllocator)
  else
    Result := THirNameVec.Create;
end;

function THIRBuilder.CreateBlockIdVec: THirBlockIdVec;
begin
  if FAllocator <> nil then
    Result := THirBlockIdVec.Create(0, FAllocator)
  else
    Result := THirBlockIdVec.Create;
end;

procedure THIRBuilder.ClearWorkBlocks;
begin
  FBlockNames.Clear;
  FBlockIds.Clear;
end;

procedure THIRBuilder.SnapshotWorkTables(AAllocas: THirAllocaVec;
  ANames: THirNameVec; AIds: THirBlockIdVec);
var
  I: LongInt;
begin
  AAllocas.Clear;
  for I := 0 to LongInt(FAllocas.Count) - 1 do
    AAllocas.Push(FAllocas[I]);
  ANames.Clear;
  AIds.Clear;
  for I := 0 to LongInt(FBlockNames.Count) - 1 do
  begin
    ANames.Push(FBlockNames[I]);
    AIds.Push(FBlockIds[I]);
  end;
end;

procedure THIRBuilder.RestoreWorkBlocks(ANames: THirNameVec; AIds: THirBlockIdVec);
var
  I: LongInt;
begin
  ClearWorkBlocks;
  for I := 0 to LongInt(ANames.Count) - 1 do
  begin
    FBlockNames.Push(ANames[I]);
    if I < LongInt(AIds.Count) then
      FBlockIds.Push(AIds[I])
    else
      FBlockIds.Push(0);
  end;
end;

procedure THIRBuilder.ClearWorkAllocas;
begin
  FAllocas.Clear;
end;

procedure THIRBuilder.RestoreWorkAllocas(AEntries: THirAllocaVec);
var
  I: LongInt;
begin
  ClearWorkAllocas;
  for I := 0 to LongInt(AEntries.Count) - 1 do
    FAllocas.Push(AEntries[I]);
end;

procedure THIRBuilder.ClearGlobalRefs;
begin
  FGlobalRefCache.Clear;
  FGlobalRefValues.Clear;
end;

procedure THIRBuilder.RegisterGlobal(const AName: string; AType: THIRTypeId);
var
  I: LongInt;
begin
  if FGlobalNames.Count > 0 then
    for I := 0 to LongInt(FGlobalNames.Count) - 1 do
      if SameText(FGlobalNames[I], AName) then
        Exit;
  FGlobalNames.Push(AName);
  FGlobalTypes.Push(AType);
end;

function THIRBuilder.FindBlock(const AName: string): THIRBlockId;
var
  I: SizeUInt;
begin
  if FBlockNames.Count > 0 then
    for I := 0 to FBlockNames.Count - 1 do
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
  FBlockNames.Push(AName);
  FBlockIds.Push(Result);
end;

function THIRBuilder.Module: THIRModule;
begin
  Result := FModule;
end;

procedure THIRBuilder.InitExprResult(out AResult: THIRExprResult);
begin
  AResult.ValueId := 0;
  AResult.TypeId := 0;
  AResult.ValueClass := shvcNone;
  AResult.AddressValueId := 0;
end;

procedure THIRBuilder.SetExprValue(out AResult: THIRExprResult;
  const AValueId: THIRValueId; const ATypeId: THIRTypeId;
  const AValueClass: TSemanticHirValueClass);
begin
  AResult.ValueId := AValueId;
  AResult.TypeId := ATypeId;
  AResult.ValueClass := AValueClass;
  AResult.AddressValueId := 0;
end;

procedure THIRBuilder.SetExprAddress(out AResult: THIRExprResult;
  const AAddressValueId: THIRValueId; const ATypeId: THIRTypeId);
begin
  AResult.ValueId := 0;
  AResult.TypeId := ATypeId;
  AResult.ValueClass := shvcAddress;
  AResult.AddressValueId := AAddressValueId;
end;

{$I np_hir_builder_lower.inc}
{$I np_hir_builder_type_helpers.inc}
{$I np_hir_builder_emit.inc}
{$I np_hir_builder_process.inc}
