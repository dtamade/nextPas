unit nextpas.core.system.typinfo;
{**
 * @desc TypInfo compatibility facade for nextPas system kernel.
 *
 * Exposes RTTI type aliases, managed-array lifecycle helpers,
 * and property/enum reflection functions.
 *
 * Note: TypeInfo() is a compiler built-in function available through System.
 * It is NOT declared in this unit but becomes accessible when this unit is in
 * the uses clause. This is by design — it is a compile-truth import, not a
 * unit-owned wrapper function.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  TypInfo;

type
  PTypeInfo = TypInfo.PTypeInfo;
  TTypeKind = TypInfo.TTypeKind;
  PTypeData = TypInfo.PTypeData;
  TTypeData = TypInfo.TTypeData;

const
  tkInteger = TypInfo.tkInteger;
  tkChar = TypInfo.tkChar;
  tkWChar = TypInfo.tkWChar;
  tkBool = TypInfo.tkBool;
  tkEnumeration = TypInfo.tkEnumeration;
  tkInt64 = TypInfo.tkInt64;
  tkQWord = TypInfo.tkQWord;
  tkFloat = TypInfo.tkFloat;
  tkSet = TypInfo.tkSet;
  tkClass = TypInfo.tkClass;
  tkMethod = TypInfo.tkMethod;
  tkSString = TypInfo.tkSString;
  tkAString = TypInfo.tkAString;
  tkLString = TypInfo.tkLString;
  tkUString = TypInfo.tkUString;
  tkWString = TypInfo.tkWString;
  tkVariant = TypInfo.tkVariant;
  tkArray = TypInfo.tkArray;
  tkRecord = TypInfo.tkRecord;
  tkInterface = TypInfo.tkInterface;
  tkClassRef = TypInfo.tkClassRef;
  tkPointer = TypInfo.tkPointer;
  tkDynArray = TypInfo.tkDynArray;
  tkProcVar = TypInfo.tkProcVar;

{ Managed type lifecycle }
procedure InitializeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
procedure FinalizeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
procedure CopyArray(ADest, ASrc: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;

{ Property reflection }
function GetPropInfo(AInstance: TObject; const APropName: string): PPropInfo;
function GetPropInfo(ATypeInfo: PTypeInfo; const APropName: string): PPropInfo;

{ Enum reflection }
function GetEnumName(ATypeInfo: PTypeInfo; AValue: Integer): string;
function GetEnumValue(ATypeInfo: PTypeInfo; const AName: string): Integer;

implementation

procedure InitializeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt);
begin
  System.InitializeArray(APtr, ATypeInfo, ACount);
end;

procedure FinalizeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt);
begin
  System.FinalizeArray(APtr, ATypeInfo, ACount);
end;

procedure CopyArray(ADest, ASrc: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt);
begin
  System.CopyArray(ADest, ASrc, ATypeInfo, ACount);
end;

function GetPropInfo(AInstance: TObject; const APropName: string): PPropInfo;
begin
  Result := TypInfo.GetPropInfo(AInstance, APropName);
end;

function GetPropInfo(ATypeInfo: PTypeInfo; const APropName: string): PPropInfo;
begin
  Result := TypInfo.GetPropInfo(ATypeInfo, APropName);
end;

function GetEnumName(ATypeInfo: PTypeInfo; AValue: Integer): string;
begin
  Result := TypInfo.GetEnumName(ATypeInfo, AValue);
end;

function GetEnumValue(ATypeInfo: PTypeInfo; const AName: string): Integer;
begin
  Result := TypInfo.GetEnumValue(ATypeInfo, AName);
end;

end.
