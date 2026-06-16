program test_system_typinfo_minimal;

{$I nextpas.core.settings.inc}

uses
  Variants,
  nextpas.core.testing,
  nextpas.core.system.typinfo;

type
  PAnsiStringSlots = ^TAnsiStringSlots;
  TAnsiStringSlots = array[0..1] of AnsiString;
  PInterfaceSlots = ^TInterfaceSlots;
  TInterfaceSlots = array[0..1] of IInterface;
  TIntDynArray = array of Int32;
  TObjectMethod = procedure of object;
  TProcVar = procedure;
  TKindEnum = (keFirst, keSecond);
  TKindSet = set of TKindEnum;
  TStaticArray = array[0..1] of Integer;
  TKindRecord = record
    Value: Integer;
  end;

  ISystemTypInfoProbe = interface
    ['{A1980734-1B05-44E2-AC4B-D15C65E96483}']
    function Value: Integer;
  end;

  TSystemTypInfoProbeClass = class of TSystemTypInfoProbe;

  TSystemTypInfoProbe = class(TInterfacedObject, ISystemTypInfoProbe)
  private
    FValue: Integer;
  public
    constructor Create(AValue: Integer);
    function Value: Integer;
  end;

var
  T: TTestRunner;
  ManagedProbeDestroyedCount: Int32 = 0;

constructor TManagedProbe.Create(AProbeId: Int32);
begin
  inherited Create;
  FProbeId := AProbeId;
end;

destructor TManagedProbe.Destroy;
begin
  Inc(ManagedProbeDestroyedCount);
  inherited Destroy;
end;

function TManagedProbe.ProbeId: Int32;
begin
  Result := FProbeId;
end;

constructor TSystemTypInfoProbe.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
end;

function TSystemTypInfoProbe.Value: Integer;
begin
  Result := FValue;
end;

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

procedure TestStructuredKindAliasesCompileTruth;
begin
  CheckTypeInfoKind('ISystemTypInfoProbe', TypeInfo(ISystemTypInfoProbe), GetTypeKind(ISystemTypInfoProbe),
    nextpas.core.system.typinfo.tkInterface);
  CheckTypeInfoKind('TSystemTypInfoProbe', TypeInfo(TSystemTypInfoProbe), GetTypeKind(TSystemTypInfoProbe),
    nextpas.core.system.typinfo.tkClass);
  CheckTypeInfoKind('TSystemTypInfoProbeClass', TypeInfo(TSystemTypInfoProbeClass), GetTypeKind(TSystemTypInfoProbeClass),
    nextpas.core.system.typinfo.tkClassRef);
  CheckTypeInfoKind('TKindSet', TypeInfo(TKindSet), GetTypeKind(TKindSet),
    nextpas.core.system.typinfo.tkSet);
  CheckTypeInfoKind('TProcVar', TypeInfo(TProcVar), GetTypeKind(TProcVar),
    nextpas.core.system.typinfo.tkProcVar);
  CheckTypeInfoKind('TStaticArray', TypeInfo(TStaticArray), GetTypeKind(TStaticArray),
    nextpas.core.system.typinfo.tkArray);
  CheckTypeInfoKind('TKindRecord', TypeInfo(TKindRecord), GetTypeKind(TKindRecord),
    nextpas.core.system.typinfo.tkRecord);
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

procedure TestInterfaceReferenceArrayLifecycleHelpers;
var
  LSource: PInterfaceSlots;
  LDest: PInterfaceSlots;
  LSourceInitialized: Boolean;
  LDestInitialized: Boolean;
  LFirst: ISystemTypInfoProbe;
  LSecond: ISystemTypInfoProbe;
  LReadBack: ISystemTypInfoProbe;
begin
  GetMem(LSource, SizeOf(TInterfaceSlots));
  GetMem(LDest, SizeOf(TInterfaceSlots));
  LSourceInitialized := False;
  LDestInitialized := False;
  LFirst := TSystemTypInfoProbe.Create(11);
  LSecond := TSystemTypInfoProbe.Create(22);
  try
    nextpas.core.system.typinfo.InitializeArray(LSource, TypeInfo(ISystemTypInfoProbe), Length(LSource^));
    LSourceInitialized := True;
    nextpas.core.system.typinfo.InitializeArray(LDest, TypeInfo(ISystemTypInfoProbe), Length(LDest^));
    LDestInitialized := True;

    LSource^[0] := LFirst;
    LSource^[1] := LSecond;
    LDest^[0] := TSystemTypInfoProbe.Create(1);
    LDest^[1] := TSystemTypInfoProbe.Create(2);

    nextpas.core.system.typinfo.CopyArray(LDest, LSource, TypeInfo(ISystemTypInfoProbe), Length(LSource^));

    LReadBack := LDest^[0] as ISystemTypInfoProbe;
    Check(LReadBack <> nil,
      'interface reference array lifecycle helpers should copy slot 0');
    CheckEqual(Int64(11), Int64(LReadBack.Value),
      'CopyArray should preserve interface reference value 0');
    LReadBack := nil;

    LReadBack := LDest^[1] as ISystemTypInfoProbe;
    Check(LReadBack <> nil,
      'interface reference array lifecycle helpers should copy slot 1');
    CheckEqual(Int64(22), Int64(LReadBack.Value),
      'CopyArray should preserve interface reference value 1');
    LReadBack := nil;

    nextpas.core.system.typinfo.CopyArray(LDest, LSource, TypeInfo(ISystemTypInfoProbe), 0);
    LReadBack := LDest^[0] as ISystemTypInfoProbe;
    Check(LReadBack <> nil,
      'zero-count interface CopyArray should preserve destination slot 0');
    CheckEqual(Int64(11), Int64(LReadBack.Value),
      'zero-count CopyArray should not mutate interface reference value 0');
    LReadBack := nil;
  finally
    if LDestInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LDest, TypeInfo(ISystemTypInfoProbe), Length(LDest^));
    if LSourceInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LSource, TypeInfo(ISystemTypInfoProbe), Length(LSource^));
    FreeMem(LDest);
    FreeMem(LSource);
    LSecond := nil;
    LFirst := nil;
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

procedure TestManagedInterfaceArrayLifecycleHelpers;
var
  LDest: PInterfaceSlots;
  LDestInitialized: Boolean;
  LSource: PInterfaceSlots;
  LSourceInitialized: Boolean;
  LTypeInfo: nextpas.core.system.typinfo.PTypeInfo;
begin
  ManagedProbeDestroyedCount := 0;
  LTypeInfo := TypeInfo(IManagedProbe);
  CheckTypeInfoKind('IManagedProbe', LTypeInfo, GetTypeKind(IManagedProbe),
    nextpas.core.system.typinfo.tkInterface);

  GetMem(LSource, SizeOf(TInterfaceSlots));
  GetMem(LDest, SizeOf(TInterfaceSlots));
  LSourceInitialized := False;
  LDestInitialized := False;
  try
    nextpas.core.system.typinfo.InitializeArray(LSource, LTypeInfo,
      Length(LSource^));
    LSourceInitialized := True;
    nextpas.core.system.typinfo.InitializeArray(LDest, LTypeInfo,
      Length(LDest^));
    LDestInitialized := True;

    Check(LSource^[0] = nil, 'interface source slot 0 should initialize to nil');
    Check(LSource^[1] = nil, 'interface source slot 1 should initialize to nil');
    Check(LDest^[0] = nil, 'interface destination slot 0 should initialize to nil');
    Check(LDest^[1] = nil, 'interface destination slot 1 should initialize to nil');

    LSource^[0] := TManagedProbe.Create(10) as IManagedProbe;
    LSource^[1] := TManagedProbe.Create(20) as IManagedProbe;
    nextpas.core.system.typinfo.CopyArray(LDest, LSource, LTypeInfo,
      Length(LSource^));

    Check(LDest^[0] = LSource^[0], 'CopyArray should preserve interface identity 0');
    Check(LDest^[1] = LSource^[1], 'CopyArray should preserve interface identity 1');
    CheckEqual(10, LDest^[0].ProbeId, 'CopyArray should preserve interface value 0');
    CheckEqual(20, LDest^[1].ProbeId, 'CopyArray should preserve interface value 1');

    nextpas.core.system.typinfo.FinalizeArray(LSource, LTypeInfo,
      Length(LSource^));
    LSourceInitialized := False;
    CheckEqual(0, ManagedProbeDestroyedCount,
      'destination interface slots should keep probes alive after source finalize');
    CheckEqual(10, LDest^[0].ProbeId,
      'destination interface slot 0 should stay usable after source finalize');
    CheckEqual(20, LDest^[1].ProbeId,
      'destination interface slot 1 should stay usable after source finalize');

    nextpas.core.system.typinfo.FinalizeArray(LDest, LTypeInfo, Length(LDest^));
    LDestInitialized := False;
  finally
    if LDestInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LDest, LTypeInfo, Length(LDest^));
    if LSourceInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LSource, LTypeInfo,
        Length(LSource^));
    FreeMem(LDest);
    FreeMem(LSource);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.system.typinfo');
  T.Run('TypeInfo and GetTypeKind compile-truth', @TestTypeInfoAndGetTypeKindCompileTruth);
  T.Run('integer PTypeInfo identity compile-truth', @TestIntegerPTypeInfoIdentityCompileTruth);
  T.Run('PTypeInfo kind consistency compile-truth', @TestPTypeInfoKindConsistencyCompileTruth);
  T.Run('structured kind aliases compile-truth', @TestStructuredKindAliasesCompileTruth);
  T.Run('managed array lifecycle helpers', @TestManagedArrayLifecycleHelpers);
  T.Run('interface reference array lifecycle helpers', @TestInterfaceReferenceArrayLifecycleHelpers);
  T.Run('collection kind aliases compile-truth', @TestCollectionKindAliasesCompileTruth);
  T.Run('managed interface array lifecycle helpers',
    @TestManagedInterfaceArrayLifecycleHelpers);
  T.Summary;
end.
