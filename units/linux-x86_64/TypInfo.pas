unit TypInfo;

{$mode objfpc}{$H+}

interface

type
  TTypeKind = System.TTypeKind;
  PPTypeInfo = ^PTypeInfo;
  PTypeInfo = ^TTypeInfo;
  TTypeInfo = record
    Kind: TTypeKind;
    Name: ShortString;
  end;
  PPropInfo = ^TPropInfo;
  TPropInfo = packed record
    PropType: PPTypeInfo;
    GetProc: Pointer;
    SetProc: Pointer;
    StoredProc: Pointer;
    Index: Integer;
    Default: Integer;
    NameIndex: SmallInt;
    Name: ShortString;
  end;

{ Re-export System.TTypeKind enum values so consumers can use TypInfo.tkInteger etc. }
const
  tkUnknown    = System.tkUnknown;
  tkInteger    = System.tkInteger;
  tkChar       = System.tkChar;
  tkEnumeration = System.tkEnumeration;
  tkFloat      = System.tkFloat;
  tkSString    = System.tkSString;
  tkLString    = System.tkLString;
  tkAString    = System.tkAString;
  tkWString    = System.tkWString;
  tkSet        = System.tkSet;
  tkClass      = System.tkClass;
  tkMethod     = System.tkMethod;
  tkWChar      = System.tkWChar;
  tkVariant    = System.tkVariant;
  tkArray      = System.tkArray;
  tkRecord     = System.tkRecord;
  tkInterface  = System.tkInterface;
  tkInt64      = System.tkInt64;
  tkDynArray   = System.tkDynArray;
  tkUString    = System.tkUString;
  tkUChar      = System.tkUChar;
  tkBool       = System.tkBool;
  tkQWord      = System.tkQWord;
  tkClassRef   = System.tkClassRef;
  tkPointer    = System.tkPointer;
  tkProcVar    = System.tkProcVar;

function GetPropInfo(Instance: TObject; const PropName: string): PPropInfo;

implementation

function GetPropInfo(Instance: TObject; const PropName: string): PPropInfo;
begin
  Result := nil;
end;

end.
