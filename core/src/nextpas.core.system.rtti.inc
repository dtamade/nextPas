{**
 * @desc RTTI types for the nextPas system kernel.
 *
 * Defines TTypeKind, TTypeInfo, managed type lifecycle.
 * Contains {$compiler_type_kind} directive for TTypeKind.
 * Depends on base.inc, str.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are re-exported from FPC System via fpc.inc.
 *}

type
  { TTypeKind — compiler type kind enum }
{$compiler_type_kind}
  TTypeKind = (
    tkUnknown,
    tkInteger,
    tkChar,
    tkEnumeration,
    tkFloat,
    tkSet,
    tkMethod,
    tkSString,
    tkLString,
    tkAString,
    tkWString,
    tkVariant,
    tkArray,
    tkRecord,
    tkInterface,
    tkClass,
    tkObject,
    tkWChar,
    tkBool,
    tkInt64,
    tkQWord,
    tkDynArray,
    tkInterfaceRaw,
    tkProcVar,
    tkUString,
    tkUChar,
    tkHelper,
    tkFile,
    tkClassRef,
    tkPointer
  );

  { TTypeInfo record }
  PPTypeInfo = ^PTypeInfo;
  PTypeInfo = ^TTypeInfo;
  TTypeInfo = record
    Kind: TTypeKind;
    Name: ShortString;
  end;

  { TTypeData — type-specific data }
  PTypeData = ^TTypeData;
  TTypeData = record
    case TTypeKind of
      tkInteger, tkChar, tkEnumeration, tkWChar, tkBool: (
        OrdType: Byte;
        case TTypeKind of
          tkInteger, tkChar, tkEnumeration, tkWChar, tkBool: (
            MinValue: SizeInt;
            MaxValue: SizeInt;
            case TTypeKind of
              tkEnumeration: (
                BaseType: PPTypeInfo;
                NameList: ShortString;
              );
          );
      );
      tkFloat: (
        FloatType: Byte;
      );
      tkSet: (
        SetType: PPTypeInfo;
        SetSize: Byte;
      );
      tkMethod: (
        MethodKind: Byte;
        ParamCount: Byte;
        ParamList: array[0..1023] of Char;
      );
      tkSString: (
        MaxLength: Byte;
      );
      tkAString, tkLString, tkWString, tkUString: (
        StringCodePage: Word;
      );
      tkClass: (
        ClassType: TClass;
        ParentInfo: PPTypeInfo;
        PropCount: SmallInt;
        UnitName: ShortString;
      );
      tkInterface: (
        IntfParent: PPTypeInfo;
        IntfFlags: Byte;
        IntfGuid: TGUID;
        IntfUnit: ShortString;
      );
      tkDynArray: (
        ElSize: SizeInt;
        ElType: PPTypeInfo;
        ElType2: PPTypeInfo;
        VarType: LongInt;
        DynUnitName: ShortString;
      );
  end;

{ Managed type lifecycle — compiler intrinsics }
procedure InitializeArray(P: Pointer; TypeInfo: Pointer; Count: SizeInt);
procedure FinalizeArray(P: Pointer; TypeInfo: Pointer; Count: SizeInt);
procedure CopyArray(Dest, Src: Pointer; TypeInfo: Pointer; Count: SizeInt);
procedure Initialize(P: Pointer; TypeInfo: Pointer);
procedure Finalize(P: Pointer; TypeInfo: Pointer);
procedure CopyRecord(Dest, Src: Pointer; TypeInfo: Pointer);

implementation

{ Managed type lifecycle stubs — real implementations provided by runtime }
procedure InitializeArray(P: Pointer; TypeInfo: Pointer; Count: SizeInt);
begin
  { Stub — runtime provides real implementation }
end;

procedure FinalizeArray(P: Pointer; TypeInfo: Pointer; Count: SizeInt);
begin
  { Stub — runtime provides real implementation }
end;

procedure CopyArray(Dest, Src: Pointer; TypeInfo: Pointer; Count: SizeInt);
begin
  { Stub — runtime provides real implementation }
end;

procedure Initialize(P: Pointer; TypeInfo: Pointer);
begin
  { Stub — runtime provides real implementation }
end;

procedure Finalize(P: Pointer; TypeInfo: Pointer);
begin
  { Stub — runtime provides real implementation }
end;

procedure CopyRecord(Dest, Src: Pointer; TypeInfo: Pointer);
begin
  { Stub — runtime provides real implementation }
end;
