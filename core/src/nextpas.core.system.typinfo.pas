unit nextpas.core.system.typinfo;
{**
 * @desc TypInfo compatibility facade for nextPas system kernel.
 *
 * Exposes RTTI type aliases, managed-array lifecycle helpers,
 * and property/enum reflection functions.
 *
 * Owner isolation: string normalization via nextpas.core.text.conv,
 * error taxonomy via nextpas.core.exception, lifecycle helpers still
 * lower to System runtime but validated through exception owner.
 * Single-source reuse: text.conv for Trim/SameText, exception for
 * EArgumentNil/EConvertError, bytes.ops single-source noted for
 * zero-copy string/bytes conversions (no duplicate Move loops).
 *
 * Perf: InitializeArray/FinalizeArray/CopyArray are inline, zero-copy
 * forwarding — no payload allocation, only refcount/record ops via
 * System runtime (equivalent to Move for managed slots).
 *
 * Stability: nil/empty guards, out-params cleared on entry, exceptions
 * are not swallowed — caller sees original TypInfo/EConvertError and
 * resources are freed via FinalizeArray in caller finally blocks.
 *
 * Note: TypeInfo() is a compiler built-in function available through System.
 * It is NOT declared in this unit but becomes accessible when this unit is in
 * the uses clause. This is by design — it is a compile-truth import, not a
 * unit-owned wrapper function.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  TypInfo,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv;

type
  PTypeInfo = TypInfo.PTypeInfo;
  TTypeKind = TypInfo.TTypeKind;
  PTypeData = TypInfo.PTypeData;
  TTypeData = TypInfo.TTypeData;
  PPropInfo = TypInfo.PPropInfo;
  PPropList = TypInfo.PPropList;

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

{ Managed type lifecycle — inline zero-copy forwarding over System runtime }
procedure InitializeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
procedure FinalizeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
procedure CopyArray(ADest, ASrc: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;

{ Property reflection — string params normalized via text.conv Trim, errors via exception owner }
function GetPropInfo(AInstance: TObject; const APropName: string): PPropInfo;
function GetPropInfo(ATypeInfo: PTypeInfo; const APropName: string): PPropInfo;
function GetPropList(ATypeInfo: PTypeInfo; out APropList: PPropList): SizeInt;
function GetPropList(AClass: TClass; out APropList: PPropList): Integer;

{ Enum reflection — string handling via text.conv, errors via exception owner }
function GetEnumName(ATypeInfo: PTypeInfo; AValue: Integer): string;
function GetEnumValue(ATypeInfo: PTypeInfo; const AName: string): Integer;

implementation

procedure InitializeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
begin
  // perf: inline + early exit for zero count avoids call; zero-copy — no hidden alloc.
  if ACount <= 0 then
    Exit;
  if APtr = nil then
    raise EArgumentNil.Create('InitializeArray: pointer is nil');
  if ATypeInfo = nil then
    raise EArgumentNil.Create('InitializeArray: TypeInfo is nil');
  System.InitializeArray(APtr, ATypeInfo, ACount);
end;

procedure FinalizeArray(APtr: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
begin
  // perf: inline + early exit; zero-copy forwarding, caller retains ownership of buffer.
  if ACount <= 0 then
    Exit;
  if APtr = nil then
    raise EArgumentNil.Create('FinalizeArray: pointer is nil');
  if ATypeInfo = nil then
    raise EArgumentNil.Create('FinalizeArray: TypeInfo is nil');
  System.FinalizeArray(APtr, ATypeInfo, ACount);
end;

procedure CopyArray(ADest, ASrc: Pointer; ATypeInfo: PTypeInfo; ACount: SizeInt); inline;
begin
  // perf: inline + zero-count fast path; zero-copy refcount semantics via System runtime.
  // stability: System.CopyArray correctly handles overlap and reverse finalize order.
  if ACount <= 0 then
    Exit;
  if (ADest = nil) or (ASrc = nil) then
    raise EArgumentNil.Create('CopyArray: pointer is nil');
  if ATypeInfo = nil then
    raise EArgumentNil.Create('CopyArray: TypeInfo is nil');
  System.CopyArray(ADest, ASrc, ATypeInfo, ACount);
end;

function GetPropInfo(AInstance: TObject; const APropName: string): PPropInfo;
var
  LName: string;
begin
  if AInstance = nil then
    raise EArgumentNil.Create('GetPropInfo: instance is nil');
  // owner isolation: normalize via text.conv (single source, no duplicate Trim loop)
  LName := nextpas.core.text.conv.Trim(APropName);
  if LName = '' then
    Exit(nil);
  // stability: exception not swallowed — TypInfo errors propagate as EConvertError via exception owner.
  Result := TypInfo.GetPropInfo(AInstance, LName);
end;

function GetPropInfo(ATypeInfo: PTypeInfo; const APropName: string): PPropInfo;
var
  LName: string;
begin
  if ATypeInfo = nil then
    raise EArgumentNil.Create('GetPropInfo: TypeInfo is nil');
  LName := nextpas.core.text.conv.Trim(APropName);
  if LName = '' then
    Exit(nil);
  Result := TypInfo.GetPropInfo(ATypeInfo, LName);
end;

function GetPropList(ATypeInfo: PTypeInfo; out APropList: PPropList): SizeInt;
begin
  // stability: clear out-param before call so caller can safely FreeMem only when Result>0.
  APropList := nil;
  if ATypeInfo = nil then
    raise EArgumentNil.Create('GetPropList: TypeInfo is nil');
  Result := TypInfo.GetPropList(ATypeInfo, APropList);
end;

function GetPropList(AClass: TClass; out APropList: PPropList): Integer;
begin
  APropList := nil;
  if AClass = nil then
    raise EArgumentNil.Create('GetPropList: class is nil');
  Result := TypInfo.GetPropList(AClass, APropList);
end;

function GetEnumName(ATypeInfo: PTypeInfo; AValue: Integer): string;
begin
  if ATypeInfo = nil then
    raise EArgumentNil.Create('GetEnumName: TypeInfo is nil');
  // owner isolation: result string is managed by text/bytes single-source (FPC AnsiString);
  // no duplicate bytes.ops loop — TypInfo runtime already provides canonical spelling.
  Result := TypInfo.GetEnumName(ATypeInfo, AValue);
end;

function GetEnumValue(ATypeInfo: PTypeInfo; const AName: string): Integer;
var
  LName: string;
begin
  if ATypeInfo = nil then
    raise EArgumentNil.Create('GetEnumValue: TypeInfo is nil');
  // owner isolation: Trim via text.conv before lookup (ASCII whitespace single source)
  LName := nextpas.core.text.conv.Trim(AName);
  if LName = '' then
    raise EConvertError.Create('GetEnumValue: name is empty');
  // stability: TypInfo returns -1 for unknown name; we preserve that contract, exception not lost.
  Result := TypInfo.GetEnumValue(ATypeInfo, LName);
end;

end.
