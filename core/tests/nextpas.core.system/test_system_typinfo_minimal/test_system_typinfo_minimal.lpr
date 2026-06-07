program test_system_typinfo_minimal;

{$I nextpas.core.settings.inc}

uses
  Variants,
  nextpas.core.testing,
  nextpas.core.system.typinfo;

type
  PAnsiStringSlots = ^TAnsiStringSlots;
  TAnsiStringSlots = array[0..1] of AnsiString;
  TIntDynArray = array of Int32;
  TObjectMethod = procedure of object;
  TKindEnum = (keFirst, keSecond);

var
  T: TTestRunner;

procedure CheckTypeInfoKind(const AName: string;
  ATypeInfo: nextpas.core.system.typinfo.PTypeInfo;
  AActualKind: nextpas.core.system.typinfo.TTypeKind;
  AExpectedKind: nextpas.core.system.typinfo.TTypeKind);
begin
  Check(ATypeInfo <> nil, AName + ' TypeInfo should return metadata');
  Check(ATypeInfo^.Kind = AExpectedKind,
    AName + ' PTypeInfo.Kind should match the live facade kind');
  Check(AActualKind = AExpectedKind,
    AName + ' GetTypeKind should match the live facade kind');
end;

procedure TestTypeInfoAndGetTypeKindCompileTruth;
var
  LTypeInfo: nextpas.core.system.typinfo.PTypeInfo;
  LTypeKind: nextpas.core.system.typinfo.TTypeKind;
begin
  LTypeInfo := TypeInfo(AnsiString);
  Check(LTypeInfo <> nil, 'TypeInfo(AnsiString) should return metadata');
  Check(LTypeInfo^.Kind = nextpas.core.system.typinfo.tkAString,
    'PTypeInfo.Kind should expose tkAString through the live facade');

  LTypeKind := GetTypeKind(AnsiString);
  Check(LTypeKind = nextpas.core.system.typinfo.tkAString,
    'GetTypeKind should classify AnsiString through compile-truth');
  Check(GetTypeKind(Int32) = nextpas.core.system.typinfo.tkInteger,
    'GetTypeKind should classify Int32 as tkInteger');
  Check(GetTypeKind(Boolean) = nextpas.core.system.typinfo.tkBool,
    'GetTypeKind should classify Boolean as tkBool');
  Check(GetTypeKind(UInt64) = nextpas.core.system.typinfo.tkQWord,
    'GetTypeKind should classify UInt64 as tkQWord');
end;

procedure TestIntegerPTypeInfoIdentityCompileTruth;
var
  LInt8: nextpas.core.system.typinfo.PTypeInfo;
  LInt16: nextpas.core.system.typinfo.PTypeInfo;
  LInt32: nextpas.core.system.typinfo.PTypeInfo;
  LUInt8: nextpas.core.system.typinfo.PTypeInfo;
  LUInt16: nextpas.core.system.typinfo.PTypeInfo;
  LUInt32: nextpas.core.system.typinfo.PTypeInfo;
begin
  LInt8 := TypeInfo(Int8);
  LInt16 := TypeInfo(Int16);
  LInt32 := TypeInfo(Int32);
  LUInt8 := TypeInfo(UInt8);
  LUInt16 := TypeInfo(UInt16);
  LUInt32 := TypeInfo(UInt32);

  Check(LInt8 <> nil, 'TypeInfo(Int8) should return metadata');
  Check(LInt16 <> nil, 'TypeInfo(Int16) should return metadata');
  Check(LInt32 <> nil, 'TypeInfo(Int32) should return metadata');
  Check(LUInt8 <> nil, 'TypeInfo(UInt8) should return metadata');
  Check(LUInt16 <> nil, 'TypeInfo(UInt16) should return metadata');
  Check(LUInt32 <> nil, 'TypeInfo(UInt32) should return metadata');

  Check(LInt8 = TypeInfo(Int8), 'TypeInfo(Int8) should be stable');
  Check(LInt16 = TypeInfo(Int16), 'TypeInfo(Int16) should be stable');
  Check(LInt32 = TypeInfo(Int32), 'TypeInfo(Int32) should be stable');
  Check(LUInt8 = TypeInfo(UInt8), 'TypeInfo(UInt8) should be stable');
  Check(LUInt16 = TypeInfo(UInt16), 'TypeInfo(UInt16) should be stable');
  Check(LUInt32 = TypeInfo(UInt32), 'TypeInfo(UInt32) should be stable');

  Check(LInt8 <> LInt16, 'integer PTypeInfo identity should distinguish Int8 and Int16');
  Check(LInt16 <> LInt32, 'integer PTypeInfo identity should distinguish Int16 and Int32');
  Check(LUInt8 <> LUInt16, 'integer PTypeInfo identity should distinguish UInt8 and UInt16');
  Check(LUInt16 <> LUInt32, 'integer PTypeInfo identity should distinguish UInt16 and UInt32');
  Check(LInt8 <> LUInt8, 'integer PTypeInfo identity should distinguish signed and unsigned 8-bit integers');
  Check(LInt16 <> LUInt16, 'integer PTypeInfo identity should distinguish signed and unsigned 16-bit integers');
  Check(LInt32 <> LUInt32, 'integer PTypeInfo identity should distinguish signed and unsigned 32-bit integers');

  Check(LInt8^.Kind = nextpas.core.system.typinfo.tkInteger,
    'Int8 should stay inside tkInteger family');
  Check(LInt16^.Kind = nextpas.core.system.typinfo.tkInteger,
    'Int16 should stay inside tkInteger family');
  Check(LInt32^.Kind = nextpas.core.system.typinfo.tkInteger,
    'Int32 should stay inside tkInteger family');
  Check(LUInt8^.Kind = nextpas.core.system.typinfo.tkInteger,
    'UInt8 should stay inside tkInteger family');
  Check(LUInt16^.Kind = nextpas.core.system.typinfo.tkInteger,
    'UInt16 should stay inside tkInteger family');
  Check(LUInt32^.Kind = nextpas.core.system.typinfo.tkInteger,
    'UInt32 should stay inside tkInteger family');
end;

procedure TestPTypeInfoKindConsistencyCompileTruth;
begin
  CheckTypeInfoKind('Char', TypeInfo(Char), GetTypeKind(Char),
    nextpas.core.system.typinfo.tkChar);
  CheckTypeInfoKind('WideChar', TypeInfo(WideChar), GetTypeKind(WideChar),
    nextpas.core.system.typinfo.tkWChar);
  CheckTypeInfoKind('Boolean', TypeInfo(Boolean), GetTypeKind(Boolean),
    nextpas.core.system.typinfo.tkBool);
  CheckTypeInfoKind('TKindEnum', TypeInfo(TKindEnum), GetTypeKind(TKindEnum),
    nextpas.core.system.typinfo.tkEnumeration);
  CheckTypeInfoKind('Int64', TypeInfo(Int64), GetTypeKind(Int64),
    nextpas.core.system.typinfo.tkInt64);
  CheckTypeInfoKind('UInt64', TypeInfo(UInt64), GetTypeKind(UInt64),
    nextpas.core.system.typinfo.tkQWord);
  CheckTypeInfoKind('Single', TypeInfo(Single), GetTypeKind(Single),
    nextpas.core.system.typinfo.tkFloat);
  CheckTypeInfoKind('Double', TypeInfo(Double), GetTypeKind(Double),
    nextpas.core.system.typinfo.tkFloat);
  CheckTypeInfoKind('ShortString', TypeInfo(ShortString), GetTypeKind(ShortString),
    nextpas.core.system.typinfo.tkSString);
  CheckTypeInfoKind('AnsiString', TypeInfo(AnsiString), GetTypeKind(AnsiString),
    nextpas.core.system.typinfo.tkAString);
  CheckTypeInfoKind('UnicodeString', TypeInfo(UnicodeString), GetTypeKind(UnicodeString),
    nextpas.core.system.typinfo.tkUString);
  CheckTypeInfoKind('Variant', TypeInfo(Variant), GetTypeKind(Variant),
    nextpas.core.system.typinfo.tkVariant);
  CheckTypeInfoKind('TObjectMethod', TypeInfo(TObjectMethod), GetTypeKind(TObjectMethod),
    nextpas.core.system.typinfo.tkMethod);
  CheckTypeInfoKind('Pointer', TypeInfo(Pointer), GetTypeKind(Pointer),
    nextpas.core.system.typinfo.tkPointer);
  CheckTypeInfoKind('TIntDynArray', TypeInfo(TIntDynArray), GetTypeKind(TIntDynArray),
    nextpas.core.system.typinfo.tkDynArray);
end;

procedure TestManagedArrayLifecycleHelpers;
var
  LTypeInfo: nextpas.core.system.typinfo.PTypeInfo;
  LSource: PAnsiStringSlots;
  LDest: PAnsiStringSlots;
  LSourceInitialized: Boolean;
  LDestInitialized: Boolean;
begin
  LTypeInfo := TypeInfo(AnsiString);

  GetMem(LSource, SizeOf(TAnsiStringSlots));
  GetMem(LDest, SizeOf(TAnsiStringSlots));
  LSourceInitialized := False;
  LDestInitialized := False;
  try
    nextpas.core.system.typinfo.InitializeArray(LSource, LTypeInfo, Length(LSource^));
    LSourceInitialized := True;
    nextpas.core.system.typinfo.InitializeArray(LDest, LTypeInfo, Length(LDest^));
    LDestInitialized := True;

    LSource^[0] := 'left';
    LSource^[1] := 'right';
    LDest^[0] := 'old-left';
    LDest^[1] := 'old-right';

    nextpas.core.system.typinfo.CopyArray(LDest, LSource, LTypeInfo, Length(LSource^));

    CheckEqual('left', LDest^[0], 'CopyArray should preserve source value 0');
    CheckEqual('right', LDest^[1], 'CopyArray should preserve source value 1');

    LSource^[0] := 'zero-left';
    LSource^[1] := 'zero-right';
    nextpas.core.system.typinfo.CopyArray(LDest, LSource, LTypeInfo, 0);

    CheckEqual('left', LDest^[0], 'zero-count CopyArray should not change destination value 0');
    CheckEqual('right', LDest^[1], 'zero-count CopyArray should not change destination value 1');
  finally
    if LDestInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LDest, LTypeInfo, Length(LDest^));
    if LSourceInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LSource, LTypeInfo, Length(LSource^));
    FreeMem(LDest);
    FreeMem(LSource);
  end;
end;

procedure TestCollectionKindAliasesCompileTruth;
begin
  Check(GetTypeKind(Double) = nextpas.core.system.typinfo.tkFloat,
    'GetTypeKind should classify Double as tkFloat');
  Check(GetTypeKind(ShortString) = nextpas.core.system.typinfo.tkSString,
    'GetTypeKind should classify ShortString as tkSString');
  Check(GetTypeKind(Variant) = nextpas.core.system.typinfo.tkVariant,
    'GetTypeKind should classify Variant as tkVariant');
  Check(GetTypeKind(TObjectMethod) = nextpas.core.system.typinfo.tkMethod,
    'GetTypeKind should classify object method pointers as tkMethod');
  Check(GetTypeKind(Pointer) = nextpas.core.system.typinfo.tkPointer,
    'GetTypeKind should classify Pointer as tkPointer');
  Check(GetTypeKind(TIntDynArray) = nextpas.core.system.typinfo.tkDynArray,
    'GetTypeKind should classify dynamic arrays as tkDynArray');
end;

begin
  T := TTestRunner.Create('nextpas.core.system.typinfo');
  T.Run('TypeInfo and GetTypeKind compile-truth', @TestTypeInfoAndGetTypeKindCompileTruth);
  T.Run('integer PTypeInfo identity compile-truth', @TestIntegerPTypeInfoIdentityCompileTruth);
  T.Run('PTypeInfo kind consistency compile-truth', @TestPTypeInfoKindConsistencyCompileTruth);
  T.Run('managed array lifecycle helpers', @TestManagedArrayLifecycleHelpers);
  T.Run('collection kind aliases compile-truth', @TestCollectionKindAliasesCompileTruth);
  T.Summary;
end.
