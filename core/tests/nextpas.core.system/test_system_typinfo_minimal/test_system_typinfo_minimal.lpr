program test_system_typinfo_minimal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.system.typinfo;

type
  PAnsiStringSlots = ^TAnsiStringSlots;
  TAnsiStringSlots = array[0..1] of AnsiString;

var
  T: TTestRunner;

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

    nextpas.core.system.typinfo.CopyArray(LDest, LSource, LTypeInfo, Length(LSource^));

    CheckEqual('left', LDest^[0], 'CopyArray should preserve source value 0');
    CheckEqual('right', LDest^[1], 'CopyArray should preserve source value 1');
  finally
    if LDestInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LDest, LTypeInfo, Length(LDest^));
    if LSourceInitialized then
      nextpas.core.system.typinfo.FinalizeArray(LSource, LTypeInfo, Length(LSource^));
    FreeMem(LDest);
    FreeMem(LSource);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.system.typinfo');
  T.Run('TypeInfo and GetTypeKind compile-truth', @TestTypeInfoAndGetTypeKindCompileTruth);
  T.Run('managed array lifecycle helpers', @TestManagedArrayLifecycleHelpers);
  T.Summary;
end.
