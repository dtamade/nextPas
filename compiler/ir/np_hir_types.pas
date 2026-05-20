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

implementation

uses
  SysUtils;

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
  FTypes[Idx].SizeBytes := 16;
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
