unit nextpas.compiler.ir.hir.types;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.collections.vec;

type
  THIRTypeId = LongInt;

  THIRTypeKind = (
    htkVoid,
    htkBool,
    htkInt,
    htkFloat,
    htkChar,
    htkArray,
    htkDynArray,
    htkString,
    htkSet,
    htkRecord,
    htkClass,
    htkInterface,
    htkClassRef,
    htkFunc,
    htkPointer,
    htkUntypedPtr
  );

  THIRIntWidth = (iwI8, iwI16, iwI32, iwI64);
  THIRFloatWidth = (fwF32, fwF64, fwF80);
  THIRStringKind = (skShort, skAnsi, skUnicode);
  THIRCallConv = (ccDefault, ccCDecl, ccStdCall, ccRegister, ccPascal);

  THirNodeKind = (
    hnkVarDeclRuntime,
    hnkVarDeclArrRuntime,
    hnkVarDeclArrBorrowedRuntime,
    hnkVarDeclPtrRuntime,
    hnkVarDeclVarrefRuntime,
    hnkVarDeclRecordRuntime,
    hnkProcedureDecl,
    hnkFunctionDecl,
    hnkAssignRuntime,
    hnkHaltCallRuntime,
    hnkHaltCall,
    hnkCondBrRuntime,
    hnkSwitchRuntime,
    hnkBrRuntime,
    hnkBlockLabelRuntime,
    hnkFunctionBodyBegin,
    hnkFunctionBodyEnd,
    hnkRetRuntime,
    hnkCallRuntime,
    hnkStringTempOwnedRuntime,
    hnkStringTempBorrowArgRuntime,
    hnkStringTempLengthRuntime,
    hnkStringTempReleaseRuntime,
    hnkObjectFreeRuntime,
    hnkTStringFromIntRuntime,
    hnkTStringCopyRuntime,
    hnkWriteIntRuntime,
    hnkWriteStringRuntime,
    hnkWriteStrVarRuntime,
    hnkWriteCall,
    hnkSetLengthArrRuntime,
    hnkSetLengthFieldArrRuntime,
    hnkDynArrayCleanupRuntime,
    hnkManagedRecordCleanupRuntime,
    hnkAssignArrElemRuntime,
    hnkMethodBodyBegin,
    hnkClassNewRuntime,
    hnkFieldStoreRuntime,
    hnkRecordFieldStoreRuntime,
    hnkRecordCopyRuntime,
    hnkVmtStoreRuntime,
    hnkIntfAdjustRuntime,
    hnkIntfAddRefRuntime,
    hnkIntfReleaseRuntime,
    hnkTryBeginRuntime,
    hnkTryEndRuntime,
    hnkFinallyBeginRuntime,
    hnkFinallyEndRuntime,
    hnkExceptBeginRuntime,
    hnkExceptEndRuntime,
    hnkRaiseRuntime,
    hnkProcessInitRuntime,
    hnkProcessFiniRuntime,
    hnkUnitInitRuntime,
    hnkUnitFiniRuntime,
    hnkFillCharRuntime,
    hnkMoveRuntime,
    hnkInterlockedCasRuntime,
    hnkInterlockedXchgRuntime,
    hnkInterlockedFetchAddRuntime,
    hnkInterlockedCas64Runtime,
    hnkInterlockedFetchAdd64Runtime,
    hnkGetMemRuntime,
    hnkFreeMemRuntime,
    hnkReallocMemRuntime,
    hnkAssignedRuntime,
    hnkLowHighRuntime,
    { TString 24B runtime nodes (coexist with old 4-slot nodes) }
    hnkVarDeclTStringRuntime,
    hnkAssignTStringLiteralRuntime,
    hnkAssignTStringCopyRuntime,
    hnkAssignTStringCallRuntime,
    hnkAssignTStringConcatRuntime,
    hnkAssignTStringFieldLoadRuntime,
    hnkTStringCleanupRuntime,
    hnkFieldStoreTStringRuntime,
    hnkRetTStringRuntime,
    hnkUnknown
  );

  THIRFieldEntry = record
    Name: string;
    TypeId: THIRTypeId;
    Offset: LongInt;
  end;

  THIRParamEntry = record
    Name: string;
    TypeId: THIRTypeId;
    IsVar: Boolean;
    IsConst: Boolean;
    IsOut: Boolean;
  end;

  THirFieldEntryVec = specialize TVec<THIRFieldEntry>;
  THirParamEntryVec = specialize TVec<THIRParamEntry>;
  THirTypeIdVec = specialize TVec<THIRTypeId>;

  THIRTypeRec = record
    Id: THIRTypeId;
    Kind: THIRTypeKind;
    Name: string;
    BitWidth: Byte;
    Signed: Boolean;
    FloatWidth: THIRFloatWidth;
    CharWidth: Byte;
    ElemTypeId: THIRTypeId;
    IndexTypeId: THIRTypeId;
    LowBound: Int64;
    HighBound: Int64;
    StringKind: THIRStringKind;
    { Nested product tables owned by the type table entry (default heap). }
    Fields: THirFieldEntryVec;
    Params: THirParamEntryVec;
    ReturnTypeId: THIRTypeId;
    CallConv: THIRCallConv;
    PointeeTypeId: THIRTypeId;
    ParentTypeId: THIRTypeId;
    InterfaceIds: THirTypeIdVec;
    SizeBytes: LongInt;
    Alignment: LongInt;
  end;

  PHirTypeRec = ^THIRTypeRec;
  THirTypeRecVec = specialize TVec<THIRTypeRec>;

  THIRTypeTable = class
  private
    FTypes: THirTypeRecVec;
    FNextId: THIRTypeId;
  public
    constructor Create;
    destructor Destroy; override;
    function AddType(AKind: THIRTypeKind; const AName: string): THIRTypeId;
    function GetType(AId: THIRTypeId): THIRTypeRec;
    function FindByName(const AName: string): THIRTypeId;
    function Count: LongInt;

    function AddIntType(ABitWidth: Byte; ASigned: Boolean): THIRTypeId;
    function AddFloatType(AWidth: THIRFloatWidth): THIRTypeId;
    function AddPointerType(APointee: THIRTypeId): THIRTypeId;
    function AddArrayType(AElem: THIRTypeId; ALow, AHigh: Int64): THIRTypeId;
    function AddDynArrayType(AElem: THIRTypeId): THIRTypeId;
    function AddStringType(AKind: THIRStringKind): THIRTypeId;
    function AddRecordType(const AName: string): THIRTypeId;
    procedure AddRecordField(ARecordId: THIRTypeId;
      const AFieldName: string; AFieldType: THIRTypeId);
    function AddFuncType(const AParams: array of THIRParamEntry;
      ARetType: THIRTypeId; AConv: THIRCallConv): THIRTypeId;
  end;

function ParseHirNodeKind(const AKind: string): THirNodeKind;

implementation

uses
  nextpas.core.text.conv;

function ParseHirNodeKind(const AKind: string): THirNodeKind;
begin
  case AKind of
    'var-decl-runtime': Result := hnkVarDeclRuntime;
    'var-decl-arr-runtime': Result := hnkVarDeclArrRuntime;
    'var-decl-arr-borrowed-runtime': Result := hnkVarDeclArrBorrowedRuntime;
    'var-decl-ptr-runtime': Result := hnkVarDeclPtrRuntime;
    'var-decl-varref-runtime': Result := hnkVarDeclVarrefRuntime;
    'var-decl-record-runtime': Result := hnkVarDeclRecordRuntime;
    'procedure-decl': Result := hnkProcedureDecl;
    'function-decl': Result := hnkFunctionDecl;
    'assign-runtime': Result := hnkAssignRuntime;
    'halt-call-runtime': Result := hnkHaltCallRuntime;
    'halt-call': Result := hnkHaltCall;
    'cond-br-runtime': Result := hnkCondBrRuntime;
    'switch-runtime': Result := hnkSwitchRuntime;
    'br-runtime': Result := hnkBrRuntime;
    'block-label-runtime': Result := hnkBlockLabelRuntime;
    'function-body-begin': Result := hnkFunctionBodyBegin;
    'function-body-end': Result := hnkFunctionBodyEnd;
    'ret-runtime': Result := hnkRetRuntime;
    'call-runtime': Result := hnkCallRuntime;
    'string-temp-owned-runtime': Result := hnkStringTempOwnedRuntime;
    'string-temp-borrow-arg-runtime': Result := hnkStringTempBorrowArgRuntime;
    'string-temp-length-runtime': Result := hnkStringTempLengthRuntime;
    'string-temp-release-runtime': Result := hnkStringTempReleaseRuntime;
    'object-free-runtime': Result := hnkObjectFreeRuntime;
    'tstring-from-int-runtime': Result := hnkTStringFromIntRuntime;
    'tstring-copy-runtime': Result := hnkTStringCopyRuntime;
    'write-int-runtime': Result := hnkWriteIntRuntime;
    'write-string-runtime': Result := hnkWriteStringRuntime;
    'write-str-var-runtime': Result := hnkWriteStrVarRuntime;
    'write-call': Result := hnkWriteCall;
    'setlength-arr-runtime': Result := hnkSetLengthArrRuntime;
    'setlength-field-arr-runtime': Result := hnkSetLengthFieldArrRuntime;
    'dynarray-cleanup-runtime': Result := hnkDynArrayCleanupRuntime;
    'managed-record-cleanup-runtime': Result := hnkManagedRecordCleanupRuntime;
    'assign-arr-elem-runtime': Result := hnkAssignArrElemRuntime;
    'method-body-begin': Result := hnkMethodBodyBegin;
    'class-new-runtime': Result := hnkClassNewRuntime;
    'field-store-runtime': Result := hnkFieldStoreRuntime;
    'record-field-store-runtime': Result := hnkRecordFieldStoreRuntime;
    'record-copy-runtime': Result := hnkRecordCopyRuntime;
    'vmt-store-runtime': Result := hnkVmtStoreRuntime;
    'intf-adjust-runtime': Result := hnkIntfAdjustRuntime;
    'intf-addref-runtime': Result := hnkIntfAddRefRuntime;
    'intf-release-runtime': Result := hnkIntfReleaseRuntime;
    'try-begin-runtime': Result := hnkTryBeginRuntime;
    'try-end-runtime': Result := hnkTryEndRuntime;
    'finally-begin-runtime': Result := hnkFinallyBeginRuntime;
    'finally-end-runtime': Result := hnkFinallyEndRuntime;
    'except-begin-runtime': Result := hnkExceptBeginRuntime;
    'except-end-runtime': Result := hnkExceptEndRuntime;
    'raise-runtime': Result := hnkRaiseRuntime;
    'process-init-runtime': Result := hnkProcessInitRuntime;
    'process-fini-runtime': Result := hnkProcessFiniRuntime;
    'unit-init-runtime': Result := hnkUnitInitRuntime;
    'unit-fini-runtime': Result := hnkUnitFiniRuntime;
    'fillchar-runtime': Result := hnkFillCharRuntime;
    'move-runtime': Result := hnkMoveRuntime;
    'interlocked-cas-runtime': Result := hnkInterlockedCasRuntime;
    'interlocked-xchg-runtime': Result := hnkInterlockedXchgRuntime;
    'interlocked-fetch-add-runtime': Result := hnkInterlockedFetchAddRuntime;
    'interlocked-cas64-runtime': Result := hnkInterlockedCas64Runtime;
    'interlocked-fetch-add64-runtime': Result := hnkInterlockedFetchAdd64Runtime;
    'getmem-runtime': Result := hnkGetMemRuntime;
    'freemem-runtime': Result := hnkFreeMemRuntime;
    'reallocmem-runtime': Result := hnkReallocMemRuntime;
    'assigned-runtime': Result := hnkAssignedRuntime;
    'lowhigh-runtime': Result := hnkLowHighRuntime;
    { TString 24B runtime nodes }
    'var-decl-tstring-runtime': Result := hnkVarDeclTStringRuntime;
    'assign-tstring-literal-runtime': Result := hnkAssignTStringLiteralRuntime;
    'assign-tstring-copy-runtime': Result := hnkAssignTStringCopyRuntime;
    'assign-tstring-call-runtime': Result := hnkAssignTStringCallRuntime;
    'assign-tstring-concat-runtime': Result := hnkAssignTStringConcatRuntime;
    'assign-tstring-field-load-runtime': Result := hnkAssignTStringFieldLoadRuntime;
    'tstring-cleanup-runtime': Result := hnkTStringCleanupRuntime;
    'field-store-tstring-runtime': Result := hnkFieldStoreTStringRuntime;
    'ret-tstring-runtime': Result := hnkRetTStringRuntime;
  else
    Result := hnkUnknown;
  end;
end;

constructor THIRTypeTable.Create;
begin
  inherited Create;
  FTypes := THirTypeRecVec.Create;
  FNextId := 1;
end;

destructor THIRTypeTable.Destroy;
var
  I: SizeInt;
  Ty: PHirTypeRec;
begin
  if FTypes <> nil then
  begin
    for I := 0 to SizeInt(FTypes.Count) - 1 do
    begin
      Ty := FTypes.GetPtr(SizeUInt(I));
      Ty^.Fields.Free;
      Ty^.Fields := nil;
      Ty^.Params.Free;
      Ty^.Params := nil;
      Ty^.InterfaceIds.Free;
      Ty^.InterfaceIds := nil;
    end;
  end;
  FTypes.Free;
  FTypes := nil;
  inherited Destroy;
end;

function THIRTypeTable.AddType(AKind: THIRTypeKind;
  const AName: string): THIRTypeId;
var
  Entry: THIRTypeRec;
begin
  Entry := Default(THIRTypeRec);
  Entry.Id := FNextId;
  Entry.Kind := AKind;
  Entry.Name := AName;
  Entry.BitWidth := 0;
  Entry.Signed := True;
  Entry.CharWidth := 1;
  Entry.ElemTypeId := 0;
  Entry.IndexTypeId := 0;
  Entry.LowBound := 0;
  Entry.HighBound := 0;
  Entry.StringKind := skAnsi;
  Entry.ReturnTypeId := 0;
  Entry.CallConv := ccDefault;
  Entry.PointeeTypeId := 0;
  Entry.ParentTypeId := 0;
  Entry.SizeBytes := 0;
  Entry.Alignment := 0;
  FTypes.Push(Entry);
  Result := FNextId;
  Inc(FNextId);
end;

function THIRTypeTable.GetType(AId: THIRTypeId): THIRTypeRec;
var
  I: SizeInt;
begin
  for I := 0 to SizeInt(FTypes.Count) - 1 do
    if FTypes[SizeUInt(I)].Id = AId then
      Exit(FTypes[SizeUInt(I)]);
  Result := Default(THIRTypeRec);
end;

function THIRTypeTable.FindByName(const AName: string): THIRTypeId;
var
  I: SizeInt;
begin
  for I := 0 to SizeInt(FTypes.Count) - 1 do
    if SameText(FTypes[SizeUInt(I)].Name, AName) then
      Exit(FTypes[SizeUInt(I)].Id);
  Result := 0;
end;

function THIRTypeTable.Count: LongInt;
begin
  if FTypes = nil then
    Exit(0);
  Result := LongInt(FTypes.Count);
end;

function THIRTypeTable.AddIntType(ABitWidth: Byte;
  ASigned: Boolean): THIRTypeId;
var
  Ty: PHirTypeRec;
begin
  Result := AddType(htkInt, 'i' + IntToStr(ABitWidth));
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.BitWidth := ABitWidth;
  Ty^.Signed := ASigned;
  Ty^.SizeBytes := ABitWidth div 8;
  Ty^.Alignment := Ty^.SizeBytes;
end;

function THIRTypeTable.AddFloatType(AWidth: THIRFloatWidth): THIRTypeId;
var
  Ty: PHirTypeRec;
  N: string;
begin
  case AWidth of
    fwF32: N := 'f32';
    fwF64: N := 'f64';
    fwF80: N := 'f80';
  end;
  Result := AddType(htkFloat, N);
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.FloatWidth := AWidth;
  case AWidth of
    fwF32: begin Ty^.SizeBytes := 4; Ty^.Alignment := 4; end;
    fwF64: begin Ty^.SizeBytes := 8; Ty^.Alignment := 8; end;
    fwF80: begin Ty^.SizeBytes := 10; Ty^.Alignment := 16; end;
  end;
end;

function THIRTypeTable.AddPointerType(APointee: THIRTypeId): THIRTypeId;
var
  Ty: PHirTypeRec;
begin
  Result := AddType(htkPointer, '^');
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.PointeeTypeId := APointee;
  Ty^.SizeBytes := 8;
  Ty^.Alignment := 8;
end;

function THIRTypeTable.AddArrayType(AElem: THIRTypeId;
  ALow, AHigh: Int64): THIRTypeId;
var
  Ty: PHirTypeRec;
begin
  Result := AddType(htkArray, 'array');
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.ElemTypeId := AElem;
  Ty^.LowBound := ALow;
  Ty^.HighBound := AHigh;
end;

function THIRTypeTable.AddDynArrayType(AElem: THIRTypeId): THIRTypeId;
var
  Ty: PHirTypeRec;
begin
  Result := AddType(htkDynArray, 'dynarray');
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.ElemTypeId := AElem;
  Ty^.SizeBytes := 8;
  Ty^.Alignment := 8;
end;

function THIRTypeTable.AddStringType(AKind: THIRStringKind): THIRTypeId;
var
  Ty: PHirTypeRec;
  N: string;
begin
  case AKind of
    skShort: N := 'ShortString';
    skAnsi: N := 'AnsiString';
    skUnicode: N := 'UnicodeString';
  end;
  Result := AddType(htkString, N);
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.StringKind := AKind;
  Ty^.SizeBytes := 24;
  Ty^.Alignment := 8;
end;

function THIRTypeTable.AddRecordType(const AName: string): THIRTypeId;
begin
  Result := AddType(htkRecord, AName);
end;

procedure THIRTypeTable.AddRecordField(ARecordId: THIRTypeId;
  const AFieldName: string; AFieldType: THIRTypeId);
var
  I: SizeInt;
  Ty: PHirTypeRec;
  Field: THIRFieldEntry;
begin
  for I := 0 to SizeInt(FTypes.Count) - 1 do
  begin
    Ty := FTypes.GetPtr(SizeUInt(I));
    if Ty^.Id = ARecordId then
    begin
      if Ty^.Fields = nil then
        Ty^.Fields := THirFieldEntryVec.Create;
      Field.Name := AFieldName;
      Field.TypeId := AFieldType;
      Field.Offset := -1;
      Ty^.Fields.Push(Field);
      Exit;
    end;
  end;
end;

function THIRTypeTable.AddFuncType(const AParams: array of THIRParamEntry;
  ARetType: THIRTypeId; AConv: THIRCallConv): THIRTypeId;
var
  Ty: PHirTypeRec;
  I: LongInt;
begin
  Result := AddType(htkFunc, 'func');
  Ty := FTypes.GetPtr(FTypes.Count - 1);
  Ty^.ReturnTypeId := ARetType;
  Ty^.CallConv := AConv;
  if Length(AParams) > 0 then
    Ty^.Params := THirParamEntryVec.Create(SizeUInt(Length(AParams)))
  else
    Ty^.Params := THirParamEntryVec.Create;
  for I := 0 to High(AParams) do
    Ty^.Params.Push(AParams[I]);
end;

end.
