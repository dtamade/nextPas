program test_reflect_kind;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect,
  nextpas.core.test;

type
  TProbeEnum = (peFirst, peSecond);
  TProbeSet = set of TProbeEnum;
  TProbeRec = record
    Value: LongInt;
  end;
  TProbeManaged = record
    Text: AnsiString;
    Count: LongInt;
  end;
  TProbeClass = class(TObject)
  end;
  TIntDynArray = array of LongInt;
  TStaticArray = array[0..1] of LongInt;
  TProcVar = procedure;
  TObjMethod = procedure of object;
  IProbeFace = interface
    ['{7B3A5C1D-2E4F-4A6B-8C9D-0E1F2A3B4C5D}']
    function Id: LongInt;
  end;

  PAnsiStringSlots = ^TAnsiStringSlots;
  TAnsiStringSlots = array[0..1] of AnsiString;
  PManagedSlots = ^TManagedSlots;
  TManagedSlots = array[0..1] of TProbeManaged;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;

begin
  LSuite := TTestSuite.Create('reflect.kind');

  LSuite.Test('ordinal and float kinds', procedure
  begin
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(LongInt))) = nkInteger, 'LongInt is nkInteger');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Byte))) = nkInteger, 'Byte is nkInteger');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Int64))) = nkInt64, 'Int64 is nkInt64');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(QWord))) = nkQWord, 'QWord is nkQWord');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Boolean))) = nkEnumeration, 'Boolean is nkEnumeration');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TProbeEnum))) = nkEnumeration, 'enum is nkEnumeration');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Single))) = nkFloat, 'Single is nkFloat');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Double))) = nkFloat, 'Double is nkFloat');
  end);

  LSuite.Test('string and char kinds', procedure
  begin
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Char))) = nkChar, 'Char is nkChar');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(WideChar))) = nkChar, 'WideChar is nkChar');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(ShortString))) = nkString, 'ShortString is nkString');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(AnsiString))) = nkString, 'AnsiString is nkString');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(UnicodeString))) = nkString, 'UnicodeString is nkString');
  end);

  LSuite.Test('structured kinds', procedure
  begin
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TProbeSet))) = nkSet, 'set is nkSet');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TProbeClass))) = nkClass, 'class is nkClass');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TProbeRec))) = nkRecord, 'record is nkRecord');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(IProbeFace))) = nkInterface, 'interface is nkInterface');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TIntDynArray))) = nkDynArray, 'dynarray is nkDynArray');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TStaticArray))) = nkArray, 'static array is nkArray');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Pointer))) = nkPointer, 'Pointer is nkPointer');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TProcVar))) = nkProcedure, 'procvar is nkProcedure');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(TObjMethod))) = nkProcedure, 'method pointer is nkProcedure');
    CheckTrue(NPTypeKindOf(TNPTypeHandle(TypeInfo(Variant))) = nkVariant, 'Variant is nkVariant');
  end);

  LSuite.Test('handle interop with TypeInfo', procedure
  var
    LFirst, LSecond: TNPTypeHandle;
  begin
    LFirst := TNPTypeHandle(TypeInfo(LongInt));
    LSecond := TNPTypeHandle(TypeInfo(LongInt));
    CheckFalse(LFirst = nil, 'TypeInfo handle is not nil');
    CheckTrue(LFirst = LSecond, 'TypeInfo handle is stable');
    CheckTrue(LFirst <> TNPTypeHandle(TypeInfo(Double)), 'handles distinguish LongInt and Double');
    CheckTrue(Pointer(LFirst) = TypeInfo(LongInt), 'handle round-trips to Pointer');
    CheckTrue(NPTypeKindOf(LFirst) = nkInteger, 'kind follows handle identity');
  end);

  LSuite.Test('type names', procedure
  begin
    CheckEqual('LongInt', NPTypeNameOf(TNPTypeHandle(TypeInfo(LongInt))), 'name of LongInt');
    CheckEqual('AnsiString', NPTypeNameOf(TNPTypeHandle(TypeInfo(AnsiString))), 'name of AnsiString');
    CheckEqual('', NPTypeNameOf(nil), 'nil handle has empty name');
  end);

  LSuite.Test('layout self-check and unknown', procedure
  var
    LBuf: array[0..15] of Byte;
    LIdx: Integer;
  begin
    CheckTrue(NPReflectSelfCheckPassed, 'initialization self-check ran and passed');
    CheckTrue(NPTypeKindOf(nil) = nkUnknown, 'nil handle is nkUnknown');
    for LIdx := 0 to High(LBuf) do
      LBuf[LIdx] := 0;
    LBuf[0] := $FF;
    CheckTrue(NPTypeKindOf(TNPTypeHandle(@LBuf)) = nkUnknown, 'out-of-range kind byte is nkUnknown');
  end);

  LSuite.Test('initialize string slots', procedure
  var
    LSlots: PAnsiStringSlots;
    LHandle: TNPTypeHandle;
    LRaised: Boolean;
  begin
    LHandle := TNPTypeHandle(TypeInfo(AnsiString));
    GetMem(LSlots, SizeOf(TAnsiStringSlots));
    try
      ReflectInitializeArray(LHandle, LSlots, Length(LSlots^));
      CheckEqual('', LSlots^[0], 'slot 0 initialized to empty');
      CheckEqual('', LSlots^[1], 'slot 1 initialized to empty');
      LSlots^[0] := 'left';
      LSlots^[1] := 'right';
      CheckEqual('left', LSlots^[0], 'slot 0 keeps assigned value');
      CheckEqual('right', LSlots^[1], 'slot 1 keeps assigned value');
      ReflectInitializeArray(LHandle, nil, 0);
      CheckTrue(True, 'zero count with nil pointer is a no-op');
      LRaised := False;
      try
        ReflectInitializeArray(nil, LSlots, 1);
      except
        on E: Exception do LRaised := True;
      end;
      CheckTrue(LRaised, 'nil handle with positive count raises');
      LRaised := False;
      try
        ReflectInitializeArray(LHandle, nil, 1);
      except
        on E: Exception do LRaised := True;
      end;
      CheckTrue(LRaised, 'nil pointer with positive count raises');
    finally
      System.FinalizeArray(LSlots, Pointer(LHandle), Length(LSlots^));
      FreeMem(LSlots);
    end;
  end);

  LSuite.Test('initialize managed record slots', procedure
  var
    LSlots: PManagedSlots;
    LHandle: TNPTypeHandle;
  begin
    LHandle := TNPTypeHandle(TypeInfo(TProbeManaged));
    CheckTrue(NPTypeKindOf(LHandle) = nkRecord, 'managed record kind is nkRecord');
    GetMem(LSlots, SizeOf(TManagedSlots));
    try
      ReflectInitializeArray(LHandle, LSlots, Length(LSlots^));
      CheckEqual('', LSlots^[0].Text, 'record slot 0 string initialized');
      CheckEqual('', LSlots^[1].Text, 'record slot 1 string initialized');
      LSlots^[0].Text := 'hello';
      LSlots^[0].Count := 7;
      CheckEqual('hello', LSlots^[0].Text, 'record slot keeps assigned string');
      CheckEqual(Int64(7), Int64(LSlots^[0].Count), 'record slot keeps assigned integer');
    finally
      System.FinalizeArray(LSlots, Pointer(LHandle), Length(LSlots^));
      FreeMem(LSlots);
    end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.reflect.kind');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
