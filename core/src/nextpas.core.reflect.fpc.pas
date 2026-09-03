unit nextpas.core.reflect.fpc;

{**
 * @desc Sole owner of FPC RTTI layout knowledge (L0).
 *
 * Reads the kind byte through a self-declared mirror record, never uses
 * TypInfo. TypeInfo() is a compiler intrinsic returning Pointer, assigned
 * directly to TNPTypeHandle. FPC kind ordinals pinned to
 * rtl/inc/rttih.inc TTypeKind (0..29) with 1-byte Kind (MINENUMSIZE 1);
 * TTypeInfo is 1-byte packed (PACKRECORDS 1: Kind byte, then ShortString Name).
 * Unit initialization runs a layout self-check (Assert + fail-closed
 * raise) so any compiler layout drift fails at startup, not silently.
 *}

{$I nextpas.core.settings.inc}
{$ASSERTIONS ON}

interface

uses
  nextpas.core.reflect.base;

type
  { Mirror of FPC TTypeInfo header; only Kind + Name are read. }
  PNPFpcTypeInfo = ^TNPFpcTypeInfo;
  TNPFpcTypeInfo = packed record
    KindCode: Byte;
    Name: ShortString;
  end;

{ Maps a handle to our kind vocabulary; nil or out-of-range gives nkUnknown. }
function NPTypeKindOf(AHandle: TNPTypeHandle): TNPTypeKind;

{ Declared type name (ShortString mirror read); nil gives ''. }
function NPTypeNameOf(AHandle: TNPTypeHandle): string;

{ Initializes ACount managed slots via System runtime (replaces the
  system-typinfo InitializeArray shim for collections). No-op on
  zero/negative count; raises on nil with positive count. }
procedure ReflectInitializeArray(AHandle: TNPTypeHandle; APtr: Pointer; ACount: SizeInt);

{ True once the initialization layout self-check has passed. }
function NPReflectSelfCheckPassed: Boolean; inline;

implementation

uses
  nextpas.core.base;

{ FPC TTypeKind ordinals (rtl/inc/rttih.inc, MINENUMSIZE 1 packing). }
const
  FPC_TK_UNKNOWN = 0;
  FPC_TK_INTEGER = 1;
  FPC_TK_CHAR = 2;
  FPC_TK_ENUMERATION = 3;
  FPC_TK_FLOAT = 4;
  FPC_TK_SET = 5;
  FPC_TK_METHOD = 6;
  FPC_TK_SSTRING = 7;
  FPC_TK_LSTRING = 8;
  FPC_TK_ASTRING = 9;
  FPC_TK_WSTRING = 10;
  FPC_TK_VARIANT = 11;
  FPC_TK_ARRAY = 12;
  FPC_TK_RECORD = 13;
  FPC_TK_INTERFACE = 14;
  FPC_TK_CLASS = 15;
  FPC_TK_OBJECT = 16;
  FPC_TK_WCHAR = 17;
  FPC_TK_BOOL = 18;
  FPC_TK_INT64 = 19;
  FPC_TK_QWORD = 20;
  FPC_TK_DYNARRAY = 21;
  FPC_TK_INTERFACERAW = 22;
  FPC_TK_PROCVAR = 23;
  FPC_TK_USTRING = 24;
  FPC_TK_UCHAR = 25;
  FPC_TK_HELPER = 26;
  FPC_TK_FILE = 27;
  FPC_TK_CLASSREF = 28;
  FPC_TK_POINTER = 29;

var
  GSelfCheckPassed: Boolean = False;

function NPTypeKindOf(AHandle: TNPTypeHandle): TNPTypeKind;
var
  LCode: Byte;
begin
  if AHandle = nil then
    Exit(nkUnknown);
  LCode := PNPFpcTypeInfo(AHandle)^.KindCode;
  case LCode of
    FPC_TK_INTEGER: Result := nkInteger;
    FPC_TK_CHAR, FPC_TK_WCHAR, FPC_TK_UCHAR: Result := nkChar;
    FPC_TK_ENUMERATION, FPC_TK_BOOL: Result := nkEnumeration;
    FPC_TK_FLOAT: Result := nkFloat;
    FPC_TK_SSTRING, FPC_TK_LSTRING, FPC_TK_ASTRING,
    FPC_TK_WSTRING, FPC_TK_USTRING: Result := nkString;
    FPC_TK_SET: Result := nkSet;
    FPC_TK_CLASS, FPC_TK_CLASSREF: Result := nkClass;
    FPC_TK_RECORD, FPC_TK_OBJECT: Result := nkRecord;
    FPC_TK_INTERFACE, FPC_TK_INTERFACERAW: Result := nkInterface;
    FPC_TK_INT64: Result := nkInt64;
    FPC_TK_QWORD: Result := nkQWord;
    FPC_TK_DYNARRAY: Result := nkDynArray;
    FPC_TK_ARRAY: Result := nkArray;
    FPC_TK_POINTER: Result := nkPointer;
    FPC_TK_METHOD, FPC_TK_PROCVAR: Result := nkProcedure;
    FPC_TK_VARIANT: Result := nkVariant;
  else
    Result := nkUnknown;
  end;
end;

function NPTypeNameOf(AHandle: TNPTypeHandle): string;
begin
  if AHandle = nil then
    Exit('');
  Result := PNPFpcTypeInfo(AHandle)^.Name;
end;

procedure ReflectInitializeArray(AHandle: TNPTypeHandle; APtr: Pointer; ACount: SizeInt);
begin
  if ACount <= 0 then
    Exit;
  if APtr = nil then
    raise EArgumentNil.Create('ReflectInitializeArray: pointer is nil');
  if AHandle = nil then
    raise EArgumentNil.Create('ReflectInitializeArray: type handle is nil');
  System.InitializeArray(APtr, Pointer(AHandle), ACount);
end;

function NPReflectSelfCheckPassed: Boolean;
begin
  Result := GSelfCheckPassed;
end;

procedure RunLayoutSelfCheck;
var
  LOk: Boolean;
  LInt: PNPFpcTypeInfo;
begin
  LInt := PNPFpcTypeInfo(TypeInfo(LongInt));
  LOk := (LInt <> nil)
    and (LInt^.KindCode = FPC_TK_INTEGER)
    and (PNPFpcTypeInfo(TypeInfo(Boolean))^.KindCode = FPC_TK_BOOL)
    and (PNPFpcTypeInfo(TypeInfo(Double))^.KindCode = FPC_TK_FLOAT)
    and (PNPFpcTypeInfo(TypeInfo(AnsiString))^.KindCode = FPC_TK_ASTRING)
    and (LInt^.Name = 'LongInt')
    and (NPTypeKindOf(TNPTypeHandle(TypeInfo(LongInt))) = nkInteger);
  Assert(LOk, 'reflect.fpc: FPC RTTI layout mismatch');
  if not LOk then
    raise EInvalidState.Create('reflect.fpc: FPC RTTI layout self-check failed');
  GSelfCheckPassed := True;
end;

initialization
  RunLayoutSelfCheck;

end.
