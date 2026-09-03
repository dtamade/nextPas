unit nextpas.core.reflect.base;

{$I nextpas.core.settings.inc}

interface

type
  {** TTypeID - 类型唯一标识符 *}
  TTypeID = DWord;

  {** TFieldKind - 字段数据类型枚举 *}
  TFieldKind = (
    fkBool,
    fkInt8, fkInt16, fkInt32, fkInt64,
    fkUInt8, fkUInt16, fkUInt32, fkUInt64,
    fkFloat32, fkFloat64,
    fkString,
    fkEnum,
    fkRecord,
    fkDynArray,
    fkPointer
  );

  {** TFieldFlag - 字段元数据标记 *}
  TFieldFlag = (
    ffTransient,
    ffReadOnly,
    ffNetSync
  );
  TFieldFlags = set of TFieldFlag;

  {** TFieldDef - 字段定义 *}
  PFieldDef = ^TFieldDef;
  TFieldDef = record
    Name: string;
    Offset: PtrUInt;
    Size: Integer;
    Kind: TFieldKind;
    Flags: TFieldFlags;
    SubTypeID: TTypeID;
    ElementKind: TFieldKind;
    ElementSize: SizeUInt;
    ElementTypeID: TTypeID;
    DynArrayTypeInfo: Pointer;
  end;

  {** TTypeDef - 类型定义 *}
  PTypeDef = ^TTypeDef;
  TTypeDef = record
    Name: string;
    ID: TTypeID;
    Size: Integer;
    Fields: array[0..31] of TFieldDef;
    FieldCount: Integer;
    Active: Boolean;
  end;

const
  TYPE_ID_NONE: TTypeID = 0;
  REFLECT_MAX_TYPES = 512;
  REFLECT_MAX_FIELDS = 32;

{ ============================================================ }
{ FPC RTTI carrier (L0 pure: no uses, System intrinsics only)  }
{ ============================================================ }

type
  {** TNPTypeKind - our own kind vocabulary, replaces PTypeInfo in APIs. *}
  TNPTypeKind = (
    nkUnknown,     { tkUnknown, tkHelper, tkFile, out-of-range bytes }
    nkInteger,     { tkInteger: 8/16/32-bit signed and unsigned }
    nkChar,        { tkChar, tkWChar, tkUChar }
    nkEnumeration, { tkEnumeration, tkBool (Boolean is a 2-value enum) }
    nkFloat,       { tkFloat: Single/Double/Extended/Currency }
    nkString,      { tkSString, tkLString, tkAString, tkWString, tkUString }
    nkSet,         { tkSet }
    nkClass,       { tkClass, tkClassRef }
    nkRecord,      { tkRecord, tkObject (TP value objects) }
    nkInterface,   { tkInterface, tkInterfaceRaw }
    nkInt64,       { tkInt64 }
    nkQWord,       { tkQWord }
    nkDynArray,    { tkDynArray }
    nkArray,       { tkArray (static arrays) }
    nkPointer,     { tkPointer }
    nkProcedure,   { tkProcVar, tkMethod }
    nkVariant      { tkVariant }
  );

  {** TNPTypeHandle - opaque RTTI carrier, assigns from TypeInfo() result. *}
  TNPTypeHandle = Pointer;
  PNPTypeHandle = ^TNPTypeHandle;

implementation

end.
