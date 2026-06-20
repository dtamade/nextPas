unit np_hir_types;

{$mode objfpc}{$H+}

interface

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
    Fields: array of THIRFieldEntry;
    Params: array of THIRParamEntry;
    ReturnTypeId: THIRTypeId;
    CallConv: THIRCallConv;
    PointeeTypeId: THIRTypeId;
    ParentTypeId: THIRTypeId;
    InterfaceIds: array of THIRTypeId;
    SizeBytes: LongInt;
    Alignment: LongInt;
  end;

  THIRTypeTable = class
  private
    FTypes: array of THIRTypeRec;
    FNextId: THIRTypeId;
  public
    constructor Create;
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
  SetLength(FTypes, 0);
  FNextId := 1;
end;

function THIRTypeTable.AddType(AKind: THIRTypeKind;
  const AName: string): THIRTypeId;
var
  Idx: SizeInt;
begin
  Idx := Length(FTypes);
  SetLength(FTypes, Idx + 1);
  FTypes[Idx].Id := FNextId;
  FTypes[Idx].Kind := AKind;
  FTypes[Idx].Name := AName;
  FTypes[Idx].BitWidth := 0;
  FTypes[Idx].Signed := True;
  FTypes[Idx].CharWidth := 1;
  FTypes[Idx].ElemTypeId := 0;
  FTypes[Idx].IndexTypeId := 0;
  FTypes[Idx].LowBound := 0;
  FTypes[Idx].HighBound := 0;
  FTypes[Idx].StringKind := skAnsi;
  FTypes[Idx].ReturnTypeId := 0;
  FTypes[Idx].CallConv := ccDefault;
  FTypes[Idx].PointeeTypeId := 0;
  FTypes[Idx].ParentTypeId := 0;
  FTypes[Idx].SizeBytes := 0;
  FTypes[Idx].Alignment := 0;
  SetLength(FTypes[Idx].Fields, 0);
  SetLength(FTypes[Idx].Params, 0);
  SetLength(FTypes[Idx].InterfaceIds, 0);
  Result := FNextId;
  Inc(FNextId);
end;

function THIRTypeTable.GetType(AId: THIRTypeId): THIRTypeRec;
var
  I: SizeInt;
begin
  for I := 0 to High(FTypes) do
    if FTypes[I].Id = AId then
      Exit(FTypes[I]);
  Result := Default(THIRTypeRec);
end;

function THIRTypeTable.FindByName(const AName: string): THIRTypeId;
var
  I: SizeInt;
begin
  for I := 0 to High(FTypes) do
    if SameText(FTypes[I].Name, AName) then
      Exit(FTypes[I].Id);
  Result := 0;
end;

function THIRTypeTable.Count: LongInt;
begin
  Result := Length(FTypes);
end;

function THIRTypeTable.AddIntType(ABitWidth: Byte;
  ASigned: Boolean): THIRTypeId;
var
  Idx: SizeInt;
begin
  Result := AddType(htkInt, 'i' + IntToStr(ABitWidth));
  Idx := Length(FTypes) - 1;
  FTypes[Idx].BitWidth := ABitWidth;
  FTypes[Idx].Signed := ASigned;
  FTypes[Idx].SizeBytes := ABitWidth div 8;
  FTypes[Idx].Alignment := FTypes[Idx].SizeBytes;
end;

function THIRTypeTable.AddFloatType(AWidth: THIRFloatWidth): THIRTypeId;
var
  Idx: SizeInt;
  N: string;
begin
  case AWidth of
    fwF32: N := 'f32';
    fwF64: N := 'f64';
    fwF80: N := 'f80';
  end;
  Result := AddType(htkFloat, N);
  Idx := Length(FTypes) - 1;
  FTypes[Idx].FloatWidth := AWidth;
  case AWidth of
    fwF32: begin FTypes[Idx].SizeBytes := 4; FTypes[Idx].Alignment := 4; end;
    fwF64: begin FTypes[Idx].SizeBytes := 8; FTypes[Idx].Alignment := 8; end;
    fwF80: begin FTypes[Idx].SizeBytes := 10; FTypes[Idx].Alignment := 16; end;
  end;
end;

function THIRTypeTable.AddPointerType(APointee: THIRTypeId): THIRTypeId;
var
  Idx: SizeInt;
begin
  Result := AddType(htkPointer, '^');
  Idx := Length(FTypes) - 1;
  FTypes[Idx].PointeeTypeId := APointee;
  FTypes[Idx].SizeBytes := 8;
  FTypes[Idx].Alignment := 8;
end;

function THIRTypeTable.AddArrayType(AElem: THIRTypeId;
  ALow, AHigh: Int64): THIRTypeId;
var
  Idx: SizeInt;
begin
  Result := AddType(htkArray, 'array');
  Idx := Length(FTypes) - 1;
  FTypes[Idx].ElemTypeId := AElem;
  FTypes[Idx].LowBound := ALow;
  FTypes[Idx].HighBound := AHigh;
end;

function THIRTypeTable.AddDynArrayType(AElem: THIRTypeId): THIRTypeId;
var
  Idx: SizeInt;
begin
  Result := AddType(htkDynArray, 'dynarray');
  Idx := Length(FTypes) - 1;
  FTypes[Idx].ElemTypeId := AElem;
  FTypes[Idx].SizeBytes := 8;
  FTypes[Idx].Alignment := 8;
end;

function THIRTypeTable.AddStringType(AKind: THIRStringKind): THIRTypeId;
var
  Idx: SizeInt;
  N: string;
begin
  case AKind of
    skShort: N := 'ShortString';
    skAnsi: N := 'AnsiString';
    skUnicode: N := 'UnicodeString';
  end;
  Result := AddType(htkString, N);
  Idx := Length(FTypes) - 1;
  FTypes[Idx].StringKind := AKind;
  FTypes[Idx].SizeBytes := 24;
  FTypes[Idx].Alignment := 8;
end;

function THIRTypeTable.AddRecordType(const AName: string): THIRTypeId;
begin
  Result := AddType(htkRecord, AName);
end;

procedure THIRTypeTable.AddRecordField(ARecordId: THIRTypeId;
  const AFieldName: string; AFieldType: THIRTypeId);
var
  I: SizeInt;
  Idx: SizeInt;
begin
  for I := 0 to High(FTypes) do
    if FTypes[I].Id = ARecordId then
    begin
      Idx := Length(FTypes[I].Fields);
      SetLength(FTypes[I].Fields, Idx + 1);
      FTypes[I].Fields[Idx].Name := AFieldName;
      FTypes[I].Fields[Idx].TypeId := AFieldType;
      FTypes[I].Fields[Idx].Offset := -1;
      Exit;
    end;
end;

function THIRTypeTable.AddFuncType(const AParams: array of THIRParamEntry;
  ARetType: THIRTypeId; AConv: THIRCallConv): THIRTypeId;
var
  Idx: SizeInt;
  I: LongInt;
begin
  Result := AddType(htkFunc, 'func');
  Idx := Length(FTypes) - 1;
  FTypes[Idx].ReturnTypeId := ARetType;
  FTypes[Idx].CallConv := AConv;
  SetLength(FTypes[Idx].Params, Length(AParams));
  for I := 0 to High(AParams) do
    FTypes[Idx].Params[I] := AParams[I];
end;

end.
