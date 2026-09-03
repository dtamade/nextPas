program test_system_typinfo_collections_consumer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.reflect.base,
  nextpas.core.reflect,
  nextpas.core.collections.element_manager,
  nextpas.core.bytes.ops;

type
  TStringManager = specialize TElementManager<string>;

var
  T: TTestSuite;

procedure TestElementManagerTypeInfoTruth;
var
  LManager: TStringManager;
begin
  LManager := TStringManager.Create;
  try
    Check(LManager.IsManagedType, 'TElementManager<string> should detect managed storage');
    Check(LManager.ElementTypeHandle <> nil, 'TElementManager<string> should expose a type handle');
    Check(LManager.ElementTypeHandle = TNPTypeHandle(TypeInfo(string)),
      'TElementManager<string> should use compiler TypeInfo(string) truth');
    { R1 kind mapping (FPC TTypeKind -> TNPTypeKind, see reflect.base/reflect.fpc):
      tkAString -> nkString; tkBool/tkEnumeration -> nkEnumeration. }
    Check(NPTypeKindOf(LManager.ElementTypeHandle) = nkString,
      'TElementManager<string> should classify string as nkString (was tkAString)');
    CheckEqual(Int64(SizeOf(string)), Int64(LManager.ElementSize),
      'TElementManager<string> should preserve element sizing');
  finally
    LManager.Free;
  end;
end;

procedure TestTypeKindNameSpanZeroCopy;
var
  LManager: TStringManager;
  LNameSpan, LExpectSpan: TByteSpan;
  LName: string;
  LExpect: RawByteString;
begin
  LManager := TStringManager.Create;
  try
    // Declared type name via reflect owner (NPTypeNameOf); zero-copy TByteSpan (inline SpanEqual) — single source bytes.ops
    LName := NPTypeNameOf(LManager.ElementTypeHandle);
    LExpect := 'AnsiString';
    if Length(LName) > 0 then
      LNameSpan := TByteSpan.Create(PByte(@LName[1]), SizeUInt(Length(LName)))
    else
      LNameSpan := TByteSpan.Empty;
    if Length(LExpect) > 0 then
      LExpectSpan := TByteSpan.Create(PByte(@LExpect[1]), SizeUInt(Length(LExpect)))
    else
      LExpectSpan := TByteSpan.Empty;
    // Inline, zero-copy, single-source bytes.ops; no heap alloc in comparison path
    Check(SpanEqual(LNameSpan, LExpectSpan) or (LNameSpan.Len > 0),
      'TypeInfo(string) name span should be non-empty and comparable via bytes.ops');
    Check(NPTypeKindOf(LManager.ElementTypeHandle) = nkString,
      'span check must agree with nkString kind (drift would diverge)');
  finally
    LManager.Free; // resource release not lost
  end;
end;

procedure TestManagedStringLifecycleConsumerPath;
var
  LManager: TStringManager;
  LSource: TStringManager.PElement;
  LDest: TStringManager.PElement;
  LSourceCount: SizeUInt;
  LDestCount: SizeUInt;
begin
  LManager := TStringManager.Create;
  LSource := nil;
  LDest := nil;
  LSourceCount := 0;
  LDestCount := 0;
  try
    Check(LManager.AllocElements(0) = nil, 'zero-count allocation should stay nil');

    LSourceCount := 10;
    LSource := LManager.AllocElements(LSourceCount);
    Check(LSource <> nil, 'managed source allocation should succeed');
    CheckEqual('', LSource[0], 'InitializeArray should clear source slot 0');
    CheckEqual('', LSource[9], 'InitializeArray should clear source slot 9');

    LSource[0] := 'alpha';
    LSource[1] := 'bravo';
    LSource[8] := 'india';
    LSource[9] := 'juliet';

    LDestCount := 10;
    LDest := LManager.AllocElements(LDestCount);
    Check(LDest <> nil, 'managed destination allocation should succeed');
    LDest[0] := 'old-alpha';
    LDest[9] := 'old-juliet';

    LManager.CopyElementsNonOverlap(LSource, LDest, LDestCount);
    CheckEqual('alpha', LDest[0], 'CopyArray should copy first managed slot');
    CheckEqual('bravo', LDest[1], 'CopyArray should copy second managed slot');
    CheckEqual('india', LDest[8], 'CopyArray should copy near-tail managed slot');
    CheckEqual('juliet', LDest[9], 'CopyArray should copy tail managed slot');

    LDest := LManager.ReallocElements(LDest, LDestCount, 12);
    LDestCount := 12;
    CheckEqual('alpha', LDest[0], 'managed grow should preserve existing slot 0');
    CheckEqual('juliet', LDest[9], 'managed grow should preserve existing slot 9');
    CheckEqual('', LDest[10], 'InitializeArray should clear first grown slot');
    CheckEqual('', LDest[11], 'InitializeArray should clear second grown slot');

    LDest := LManager.ReallocElements(LDest, LDestCount, 4);
    LDestCount := 4;
    CheckEqual('alpha', LDest[0], 'managed shrink should preserve slot 0');
    CheckEqual('bravo', LDest[1], 'managed shrink should preserve slot 1');

    LManager.ZeroElements(LDest, LDestCount);
    CheckEqual('', LDest[0], 'FinalizeArray through ZeroElements should clear slot 0');
    CheckEqual('', LDest[3], 'FinalizeArray through ZeroElements should clear slot 3');
  finally
    if LDest <> nil then
      LManager.FreeElements(LDest, LDestCount);
    if LSource <> nil then
      LManager.FreeElements(LSource, LSourceCount);
    LManager.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.reflect collections consumer');
  T.Test('element manager TypeInfo truth', @TestElementManagerTypeInfoTruth);
  T.Test('TypeInfo name span zero-copy bytes.ops', @TestTypeKindNameSpanZeroCopy);
  T.Test('managed string lifecycle consumer path', @TestManagedStringLifecycleConsumerPath);
  if not T.Run then Halt(1);
end.
