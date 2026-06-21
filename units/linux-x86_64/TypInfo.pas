unit TypInfo;

{$mode objfpc}{$H+}

interface

type
  TTypeKind = (
    tkUnknown, tkInteger, tkChar, tkEnumeration, tkFloat,
    tkSString, tkLString, tkAString, tkWString, tkSet, tkClass,
    tkMethod, tkWChar, tkVariant, tkArray, tkRecord, tkInterface,
    tkInt64, tkDynArray, tkUString, tkUChar, tkBool, tkQWord,
    tkClassRef, tkPointer, tkProcVar
  );
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

function GetPropInfo(Instance: TObject; const PropName: string): PPropInfo;

implementation

function GetPropInfo(Instance: TObject; const PropName: string): PPropInfo;
begin
  Result := nil;
end;

end.
