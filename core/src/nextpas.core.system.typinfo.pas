unit nextpas.core.system.typinfo;
{**
 * @desc Minimal TypInfo compatibility facade. This unit intentionally exposes
 * only identity/kind aliases and managed-array lifecycle helpers; property
 * reflection stays out of this live surface.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  TypInfo;

type
  PTypeInfo = TypInfo.PTypeInfo;
  TTypeKind = TypInfo.TTypeKind;

const
  tkInteger = TypInfo.tkInteger;
  tkChar = TypInfo.tkChar;
  tkWChar = TypInfo.tkWChar;
  tkBool = TypInfo.tkBool;
  tkEnumeration = TypInfo.tkEnumeration;
  tkInt64 = TypInfo.tkInt64;
  tkQWord = TypInfo.tkQWord;
  tkFloat = TypInfo.tkFloat;
  tkSString = TypInfo.tkSString;
  tkAString = TypInfo.tkAString;
  tkLString = TypInfo.tkLString;
  tkUString = TypInfo.tkUString;
  tkWString = TypInfo.tkWString;
  tkVariant = TypInfo.tkVariant;
  tkMethod = TypInfo.tkMethod;
  tkPointer = TypInfo.tkPointer;
  tkInterface = TypInfo.tkInterface;
  tkDynArray = TypInfo.tkDynArray;

procedure InitializeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
procedure FinalizeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
procedure CopyArray(ADest, ASrc: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;

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

end.
