unit np_hir_builder;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH ../../core/src}

interface

uses
  np_semantic_model, np_hir_types, np_hir_model, np_source_database;

type
  TExprStack = record
    Values: array of THIRValueId;
    Types: array of THIRTypeId;
    Count: LongInt;
    procedure Init;
    procedure Push(AVal: THIRValueId);
    procedure PushTyped(AVal: THIRValueId; AType: THIRTypeId);
    function Pop: THIRValueId;
    function PopTyped(out AType: THIRTypeId): THIRValueId;
    function PeekType: THIRTypeId;
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

  THIRBuilder = class
  private
    FSemaModel: TSemanticModel;
    FModule: THIRModule;
    FCurrentFuncId: THIRFuncId;
    FCurrentBlockId: THIRBlockId;
    FBlockTerminated: Boolean;
    FSavedFuncId: THIRFuncId;
    FSavedBlockId: THIRBlockId;
    FSavedAllocas: array of TAllocaEntry;
    FSavedAllocaCount: LongInt;
    FSavedBlockNames: array of string;
    FSavedBlockIds: array of THIRBlockId;
    FSavedBlockCount: LongInt;
    FSavedEntryBlockId: THIRBlockId;
    FPendingParamCount: LongInt;
    FPendingParamLlvmIdx: LongInt;
    FPendingObjectFreeDestroyName: string;
    FPendingObjectFreeReceiverName: string;
    FPendingObjectFreeReceiverValue: THIRValueId;
    FPendingObjectFreeCleanupClass: string;
    FPendingObjectFreeHeapRelease: Boolean;
    FPendingCleanupNodes: array of TTypedHirNode;
    FPendingCleanupCount: LongInt;
    FSretValueId: THIRValueId;

    FAllocas: array of TAllocaEntry;
    FAllocaCount: LongInt;

    FIntfVarNames: array of string;
    FIntfVarCount: LongInt;

    FGlobalNames: array of string;
    FGlobalTypes: array of THIRTypeId;
    FGlobalCount: LongInt;
    FGlobalRefCache: array of string;
    FGlobalRefValues: array of THIRValueId;
    FGlobalRefCount: LongInt;
    FInStartFunc: Boolean;
    FEntryBlockId: THIRBlockId;

    FBlockNames: array of string;
    FBlockIds: array of THIRBlockId;
    FBlockCount: LongInt;

    FFwdFuncNames: array of string;
    FFwdFuncRetTypes: array of THIRTypeId;
    FFwdFuncCount: LongInt;
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
    procedure EmitExprStrLit(var S: TExprStack; const AArg: string);
    procedure EmitExprIs(var S: TExprStack; const AArg: string);
    procedure EmitExprArrLoad(var S: TExprStack);
    procedure EmitExprArrLoadPtr(var S: TExprStack);
    procedure EmitExprArrElemRef(var S: TExprStack; const AArg: string);
    procedure EmitExprFieldRef(var S: TExprStack; const AArg: string);
    procedure EmitExprRLoad(var S: TExprStack; const AArg: string);
    procedure EmitExprUnaryOp(var S: TExprStack; AKind: THIRInstrKind;
      const AIntrinsic: string);
    procedure EmitExprBinOp(var S: TExprStack; AKind: THIRInstrKind);
    procedure EmitExprCmp(var S: TExprStack; const AArg: string);
    procedure EmitExprStrCmp(var S: TExprStack; const AArg: string);
    procedure EmitExprZext(var S: TExprStack);
    procedure EmitExprCall(var S: TExprStack; const AArg: string);
    procedure EmitExprArrLoadVar(var S: TExprStack; const AArg: string);
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
      ASourceFileId: TSourceFileId = 0);
    destructor Destroy; override;
    function LowerExpr(const AExprId: LongInt;
      out AResult: THIRExprResult): Boolean;
    procedure Build;
    function Module: THIRModule;
  end;

implementation

uses
  nextpas.core.text.conv, nextpas.core.system.contracts;

procedure TExprStack.Init;
begin
  Count := 0;
  SetLength(Values, 0);
  SetLength(Types, 0);
end;

procedure TExprStack.Push(AVal: THIRValueId);
begin
  if Count >= Length(Values) then
  begin
    SetLength(Values, Count + 16);
    SetLength(Types, Count + 16);
  end;
  Values[Count] := AVal;
  Types[Count] := 0;
  Inc(Count);
end;

procedure TExprStack.PushTyped(AVal: THIRValueId; AType: THIRTypeId);
begin
  if Count >= Length(Values) then
  begin
    SetLength(Values, Count + 16);
    SetLength(Types, Count + 16);
  end;
  Values[Count] := AVal;
  Types[Count] := AType;
  Inc(Count);
end;

function TExprStack.Pop: THIRValueId;
begin
  if Count = 0 then Exit(0);
  Dec(Count);
  Result := Values[Count];
end;

function TExprStack.PopTyped(out AType: THIRTypeId): THIRValueId;
begin
  if Count = 0 then begin AType := 0; Exit(0); end;
  Dec(Count);
  Result := Values[Count];
  AType := Types[Count];
end;

function TExprStack.PeekType: THIRTypeId;
begin
  if Count = 0 then Exit(0);
  Result := Types[Count - 1];
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
  ASourceDatabase: TSourceDatabase; ASourceFileId: TSourceFileId);
var
  I, J: LongInt;
begin
  inherited Create;
  FSemaModel := ASemaModel;
  FSourceDatabase := ASourceDatabase;
  FCurrentSourceFileId := ASourceFileId;
  FCurrentSourceLine := 0;
  FCurrentSourceCol := 0;
  FModule := THIRModule.Create('main');
  FCurrentFuncId := 0;
  FCurrentBlockId := 0;
  FBlockTerminated := False;
  FAllocaCount := 0;
  FIntfVarCount := 0;
  FBlockCount := 0;
  FGlobalCount := 0;
  FGlobalRefCount := 0;
  FInStartFunc := True;
  FEntryBlockId := 0;
  FPendingParamCount := 0;
  FPendingParamLlvmIdx := 0;
  FPendingObjectFreeDestroyName := '';
  FPendingObjectFreeReceiverName := '';
  FPendingObjectFreeReceiverValue := 0;
  FPendingObjectFreeCleanupClass := '';
  FPendingObjectFreeHeapRelease := False;
  SetLength(FPendingCleanupNodes, 0);
  FPendingCleanupCount := 0;
  FLegacyIntType := 0;
  FBoolType := 0;
  FStringType := 0;
  FPtrType := 0;
  FFloat32Type := 0;
  FFloat64Type := 0;
  for I := Low(FIntTypeCache) to High(FIntTypeCache) do
    for J := Low(FIntTypeCache[I]) to High(FIntTypeCache[I]) do
      FIntTypeCache[I, J] := 0;
  SetLength(FAllocas, 0);
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
function THIRBuilder.NormalizeScalarValueToType(const AValueId: THIRValueId;
  const ASourceTypeId, ATargetTypeId: THIRTypeId): THIRValueId;
var
  Kind: THIRInstrKind;
  NoOp: Boolean;
  Instr: THIRInstr;
begin
  Result := AValueId;
  if AValueId = 0 then
    Exit(0);
  if (ASourceTypeId = 0) or (ATargetTypeId = 0) then
    Exit(0);

  if not TryClassifyScalarCast(ASourceTypeId, ATargetTypeId, Kind, NoOp) then
    Exit(0);
  if NoOp then
    Exit;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := Kind;
  Instr.TypeId := ATargetTypeId;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(AValueId, ASourceTypeId);
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.NormalizeInt64RuntimeValue(const AValueId: THIRValueId;
  const ATypeId: THIRTypeId): THIRValueId;
begin
  Result := NormalizeScalarValueToType(AValueId, ATypeId, GetIntType);
end;

function THIRBuilder.GetIntType: THIRTypeId;
begin
  if FLegacyIntType = 0 then
    FLegacyIntType := FModule.Types.AddIntType(64, True);
  Result := FLegacyIntType;
end;

function THIRBuilder.GetBoolType: THIRTypeId;
begin
  if FBoolType = 0 then
    FBoolType := FModule.Types.AddType(htkBool, 'bool');
  Result := FBoolType;
end;

function THIRBuilder.GetStringType: THIRTypeId;
begin
  if FStringType = 0 then
    FStringType := FModule.Types.AddStringType(skAnsi);
  Result := FStringType;
end;

function THIRBuilder.GetPtrType: THIRTypeId;
begin
  if FPtrType = 0 then
    FPtrType := FModule.Types.AddPointerType(0);
  Result := FPtrType;
end;

function THIRBuilder.GetIntTypeByWidth(const ABitWidth: LongInt;
  const ASigned: Boolean): THIRTypeId;
var
  WidthIndex, SignedIndex: LongInt;
begin
  case ABitWidth of
    1:
      Exit(GetBoolType);
    8:
      WidthIndex := 0;
    16:
      WidthIndex := 1;
    32:
      WidthIndex := 2;
    64:
      WidthIndex := 3;
  else
    Exit(0);
  end;

  if ASigned then
    SignedIndex := 1
  else
    SignedIndex := 0;
  if FIntTypeCache[WidthIndex, SignedIndex] = 0 then
    FIntTypeCache[WidthIndex, SignedIndex] :=
      FModule.Types.AddIntType(ABitWidth, ASigned);
  Result := FIntTypeCache[WidthIndex, SignedIndex];
end;

function THIRBuilder.GetFloatType: THIRTypeId;
begin
  Result := GetFloatTypeByWidth(64);  { Default to Double }
end;

function THIRBuilder.GetFloatTypeByWidth(
  const ABitWidth: LongInt
): THIRTypeId;
begin
  case ABitWidth of
    32:
      begin
        if FFloat32Type = 0 then
          FFloat32Type := FModule.Types.AddFloatType(fwF32);
        Result := FFloat32Type;
      end;
    64:
      begin
        if FFloat64Type = 0 then
          FFloat64Type := FModule.Types.AddFloatType(fwF64);
        Result := FFloat64Type;
      end;
  else
    Result := 0;
  end;
end;

function THIRBuilder.SemanticTypeIdToHirTypeId(
  const ATypeId: LongInt
): THIRTypeId;
var
  Fact: TSemanticScalarTypeFact;
begin
  if (FSemaModel = nil) or
    (not FSemaModel.GetTypeScalarFact(ATypeId, Fact)) then
    Exit(0);

  case Fact.Kind of
    sskBool:
      Result := GetBoolType;
    sskInt:
      Result := GetIntTypeByWidth(Fact.BitWidth, Fact.Signed);
    sskFloat:
      Result := GetFloatTypeByWidth(Fact.BitWidth);
    sskPointer:
      Result := GetPtrType;
  else
    Result := 0;
  end;
end;

function THIRBuilder.ExprHirTypeId(
  const AExpr: TSemanticHirExpr
): THIRTypeId;
begin
  Result := SemanticTypeIdToHirTypeId(AExpr.TypeId);
end;

function THIRBuilder.ExprIdHirTypeId(const AExprId: LongInt): THIRTypeId;
var
  Expr: TSemanticHirExpr;
begin
  if (FSemaModel = nil) or (AExprId <= 0) or
    (AExprId > FSemaModel.HirExprCount) then
    Exit(0);
  Expr := FSemaModel.HirExprAt(AExprId - 1);
  Result := ExprHirTypeId(Expr);
end;

function THIRBuilder.HirTypeIsInt(const ATypeId: THIRTypeId): Boolean;
begin
  Result := (ATypeId <> 0) and
    (FModule.Types.GetType(ATypeId).Kind = htkInt);
end;

function THIRBuilder.HirTypeIsBool(const ATypeId: THIRTypeId): Boolean;
begin
  Result := (ATypeId <> 0) and
    (FModule.Types.GetType(ATypeId).Kind = htkBool);
end;

function THIRBuilder.TryClassifyScalarCast(const ASourceTypeId,
  ATargetTypeId: THIRTypeId; out AKind: THIRInstrKind;
  out ANoOp: Boolean): Boolean;
var
  SourceType, TargetType: THIRTypeRec;
begin
  AKind := hikZext;
  ANoOp := False;
  if (ASourceTypeId = 0) or (ATargetTypeId = 0) then
    Exit(False);
  if ASourceTypeId = ATargetTypeId then
  begin
    ANoOp := True;
    Exit(True);
  end;

  SourceType := FModule.Types.GetType(ASourceTypeId);
  TargetType := FModule.Types.GetType(ATargetTypeId);

  if SourceType.Kind = htkBool then
  begin
    if TargetType.Kind = htkBool then
    begin
      ANoOp := True;
      Exit(True);
    end;
    if TargetType.Kind <> htkInt then
      Exit(False);
    AKind := hikZext;
    Exit(TargetType.BitWidth > 1);
  end;

  if (SourceType.Kind <> htkInt) or (TargetType.Kind <> htkInt) then
    Exit(False);

  if SourceType.BitWidth = TargetType.BitWidth then
  begin
    ANoOp := True;
    Exit(True);
  end;

  if SourceType.BitWidth < TargetType.BitWidth then
  begin
    if SourceType.Signed then
      AKind := hikSext
    else
      AKind := hikZext;
    Exit(True);
  end;

  AKind := hikTrunc;
  Result := True;
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
  if (Pos('$owner', AName) > 0) or (Pos('$alloc_size', AName) > 0) then
    Instr.CallTarget := AName;
  if (FCurrentFuncId <> 0) and (FEntryBlockId <> 0) then
    FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)
  else
    EmitInstr(Instr);

  if FAllocaCount >= Length(FAllocas) then
    SetLength(FAllocas, FAllocaCount + 32);
  RegisterAllocaEntry(AName, Instr.ResultId, AType, False);
end;

procedure THIRBuilder.RegisterAllocaEntry(const AName: string;
  AValue: THIRValueId; AType: THIRTypeId; AIsVarParam: Boolean);
begin
  if FAllocaCount >= Length(FAllocas) then
    SetLength(FAllocas, FAllocaCount + 32);
  FAllocas[FAllocaCount].Name := AName;
  FAllocas[FAllocaCount].Value := AValue;
  FAllocas[FAllocaCount].TypeId := AType;
  FAllocas[FAllocaCount].RecordSlots := 0;
  FAllocas[FAllocaCount].IsVarParam := AIsVarParam;
  Inc(FAllocaCount);
end;

function THIRBuilder.FindLocalAlloca(const AName: string): THIRValueId;
var
  I: LongInt;
begin
  for I := 0 to FAllocaCount - 1 do
    if SameText(FAllocas[I].Name, AName) then
      Exit(FAllocas[I].Value);
  Result := 0;
end;

function THIRBuilder.FindAlloca(const AName: string): THIRValueId;
var
  I: LongInt;
  Instr: THIRInstr;
begin
  for I := FAllocaCount - 1 downto 0 do
    if SameText(FAllocas[I].Name, AName) then
      Exit(FAllocas[I].Value);
  for I := 0 to FGlobalRefCount - 1 do
    if SameText(FGlobalRefCache[I], AName) then
      Exit(FGlobalRefValues[I]);
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
      if FGlobalRefCount >= Length(FGlobalRefCache) then
      begin
        SetLength(FGlobalRefCache, FGlobalRefCount + 16);
        SetLength(FGlobalRefValues, FGlobalRefCount + 16);
      end;
      FGlobalRefCache[FGlobalRefCount] := AName;
      FGlobalRefValues[FGlobalRefCount] := Instr.ResultId;
      Inc(FGlobalRefCount);
      Exit(Instr.ResultId);
    end;
  Result := 0;
end;

function THIRBuilder.FindAllocaType(const AName: string): THIRTypeId;
var
  I: LongInt;
begin
  for I := 0 to FAllocaCount - 1 do
    if SameText(FAllocas[I].Name, AName) then
      Exit(FAllocas[I].TypeId);
  Result := 0;
end;

function THIRBuilder.IsVarParamAlloca(const AName: string): Boolean;
var
  I: LongInt;
begin
  for I := 0 to FAllocaCount - 1 do
    if SameText(FAllocas[I].Name, AName) then
      Exit(FAllocas[I].IsVarParam);
  Result := False;
end;

procedure THIRBuilder.SetCurrentSourcePosFromSymbol(ASymbolId: LongInt);
var
  LSymbol: TSemanticSymbol;
  LLineCol: TLineCol;
begin
  if (ASymbolId <= 0) or (FSemaModel = nil) then
    Exit;
  LSymbol := FSemaModel.SymbolAt(ASymbolId);
  if (LSymbol.SymbolId <= 0) or (LSymbol.ByteOffset <= 0) then
    Exit;
  if (FSourceDatabase <> nil) and (FCurrentSourceFileId > 0) then
  begin
    LLineCol := FSourceDatabase.ByteOffsetToLineCol(
      FCurrentSourceFileId, LSymbol.ByteOffset);
    FCurrentSourceLine := LLineCol.Line;
    FCurrentSourceCol := LLineCol.Column;
  end;
end;

procedure THIRBuilder.EmitInstr(const AInstr: THIRInstr);
var
  LInstr: THIRInstr;
begin
  if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
  begin
    LInstr := AInstr;
    { Apply current source position to instruction for debug info }
    if (FCurrentSourceLine > 0) and (LInstr.SourceLine = 0) then
    begin
      LInstr.SourceLine := FCurrentSourceLine;
      LInstr.SourceCol := FCurrentSourceCol;
    end;
    FModule.AddInstr(FCurrentFuncId, FCurrentBlockId, LInstr);
  end;
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
  Instr.Operands[0] := MakeTypedOperand(ALhs, AType);
  Instr.Operands[1] := MakeTypedOperand(ARhs, AType);
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
  if ALhsType <> 0 then
    Instr.Operands[0] := MakeTypedOperand(ALhs, ALhsType)
  else
    Instr.Operands[0] := MakeOperand(ALhs);
  if ARhsType <> 0 then
    Instr.Operands[1] := MakeTypedOperand(ARhs, ARhsType)
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
  Instr.Operands[0] := MakeTypedOperand(AAddr, GetPtrType);
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
  Instr.Operands[0] := MakeTypedOperand(AVal, AType);
  Instr.Operands[1] := MakeTypedOperand(AAddr, GetPtrType);
  EmitInstr(Instr);
end;

{$I np_hir_builder_emit.inc}
{$I np_hir_builder_process.inc}
