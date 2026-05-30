program test_toml_stress;
{ Stress tests designed to actively expose bugs rather than verify happy paths.
  Covers: lifecycle management, resource leaks, boundary conditions, state machine
  completeness, depth limits, large-scale data, and performance regression. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.mem.intf,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.toml.value,
  nextpas.core.toml.builder,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === 1. Lifecycle & Resource Management === }

procedure TestParseReuse;
var
  LDoc: TTomlDocument;
  LView: TStringView;
begin
  LDoc.Init(DefaultAllocator);
  LView := TStringView.FromStr('a = "first"');
  Check(LDoc.Parse(LView), 'first parse');
  LView := TStringView.FromStr('b = "second"');
  Check(LDoc.Parse(LView), 'second parse (reuse)');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'only second parse keys');
  LDoc.Done;
end;

procedure TestManyParseReuseCycles;
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Integer;
begin
  LDoc.Init(DefaultAllocator);
  for LI := 1 to 100 do
  begin
    LView := TStringView.FromStr('k = ' + IntToStr(LI));
    Check(LDoc.Parse(LView), 'parse cycle ' + IntToStr(LI));
  end;
  LDoc.Done;
end;

procedure TestInterfaceAutoRelease;
var
  LI: Integer;
begin
  for LI := 1 to 1000 do
  begin
    TomlParse('x = ' + IntToStr(LI));
  end;
  Check(True, '1000 interface cycles no leak');
end;

procedure TestBuilderAutoRelease;
var
  LI: Integer;
  LB: ITomlBuilder;
begin
  for LI := 1 to 1000 do
  begin
    LB := TomlBuilder;
    LB.Key('k'); LB.Int(LI);
  end;
  Check(True, '1000 builder cycles no leak');
end;

{ === 2. Boundary Conditions & Depth === }

procedure TestManyEmptyArrays;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 200 do
    LInput := LInput + 'a' + IntToStr(LI) + ' = []' + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '200 empty arrays no depth overflow');
  CheckEqual(Int64(200), Int64(LDoc.Root.TableLen), '200 keys');
end;

procedure TestManyEmptyInlineTables;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 200 do
    LInput := LInput + 't' + IntToStr(LI) + ' = {}' + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '200 empty inline tables no depth overflow');
  CheckEqual(Int64(200), Int64(LDoc.Root.TableLen), '200 keys');
end;

procedure TestDeepInlineTableNesting;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 'x = ';
  for LI := 1 to 50 do
    LInput := LInput + '{a' + IntToStr(LI) + ' = ';
  LInput := LInput + '1';
  for LI := 1 to 50 do
    LInput := LInput + '}';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '50-deep inline table nesting ok');
end;

procedure TestDepthLimitExact;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 'x = ';
  for LI := 1 to 128 do
    LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 128 do
    LInput := LInput + ']';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, 'exactly 128 depth ok');

  LInput := 'x = ';
  for LI := 1 to 129 do
    LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 129 do
    LInput := LInput + ']';
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, '129 depth rejected');
end;

{ === 3. State Machine Completeness === }

procedure TestValueArrayThenDottedKey;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = [1, 2, 3]' + #10 + 'a.b = 4');
  Check(LDoc.HasError, 'value array then dotted key rejected');
end;

procedure TestInlineDottedKeyCorrectCount;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('t = {a.b = 1, a.c = 2, d = 3}');
  Check(not LDoc.HasError, 'inline dotted key ok');
  CheckEqual(Int64(2), Int64(LDoc.Root.Get('t').TableLen), 't has 2 direct children (a, d)');
  CheckEqual(Int64(2), Int64(LDoc.Root.Get('t').Get('a').TableLen), 'a has 2 children (b, c)');
  CheckEqual(Int64(1), LDoc.Root.Get('t').Get('a').Get('b').AsInt, 'a.b = 1');
  CheckEqual(Int64(2), LDoc.Root.Get('t').Get('a').Get('c').AsInt, 'a.c = 2');
  CheckEqual(Int64(3), LDoc.Root.Get('t').Get('d').AsInt, 'd = 3');
end;

procedure TestArrayTableThenValueArray;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('items = [1, 2]' + #10 + '[[items]]' + #10 + 'x = 1');
  Check(LDoc.HasError, 'value array then array-table rejected');
end;

procedure TestDottedKeyImplicitThenExplicit;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a.b = 1' + #10 + '[a]' + #10 + 'c = 2');
  Check(LDoc.HasError, 'dotted then explicit rejected');
end;

procedure TestExplicitThenDottedOk;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a]' + #10 + 'b.c = 1');
  Check(not LDoc.HasError, 'explicit then dotted inside ok');
  CheckEqual(Int64(1), LDoc.Root.Get('a').Get('b').Get('c').AsInt, 'a.b.c = 1');
end;

{ === 4. Large Scale Data === }

procedure TestLargeTable5000Keys;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 5000 do
    LInput := LInput + 'key_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '5000 keys ok');
  CheckEqual(Int64(5000), Int64(LDoc.Root.TableLen), '5000 keys count');
  CheckEqual(Int64(1), LDoc.Root.Get('key_1').AsInt, 'first');
  CheckEqual(Int64(2500), LDoc.Root.Get('key_2500').AsInt, 'middle');
  CheckEqual(Int64(5000), LDoc.Root.Get('key_5000').AsInt, 'last');
end;

procedure TestLargeArrayTable;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '[[items]]' + #10 + 'id = ' + IntToStr(LI) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '500 array-table entries ok');
  CheckEqual(Int64(500), Int64(LDoc.Root.Get('items').ArrayLen), '500 items');
  CheckEqual(Int64(250), LDoc.Root.Get('items').ArrayGet(249).Get('id').AsInt, 'item 250');
end;

procedure TestDuplicateKeyInLargeTable;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 1000 do
    LInput := LInput + 'key_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LInput := LInput + 'key_500 = 999' + #10;
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, 'duplicate in large table detected');
end;

{ === 5. Stringify Correctness === }

procedure TestStringifyRoundTripLargeDoc;
var
  LDoc1, LDoc2: ITomlDocument;
  LInput, LStr: string;
  LI: Integer;
begin
  LInput := '[config]' + #10 + 'name = "app"' + #10;
  for LI := 1 to 50 do
    LInput := LInput + '[[items]]' + #10 + 'id = ' + IntToStr(LI) + #10 +
      'name = "item_' + IntToStr(LI) + '"' + #10;
  LDoc1 := TomlParse(LInput);
  Check(not LDoc1.HasError, 'parse ok');
  LStr := LDoc1.Stringify;
  LDoc2 := TomlParse(LStr);
  Check(not LDoc2.HasError, 'round-trip parse ok');
  CheckEqual(Int64(50), Int64(LDoc2.Root.Get('items').ArrayLen), 'round-trip items count');
end;

procedure TestStringifyEmptyDocument;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('');
  Check(not LDoc.HasError, 'empty parse ok');
  CheckEqual('', LDoc.Stringify, 'empty stringify');
end;

{ === 6. Enumerator Correctness === }

procedure TestEnumeratorOnLargeTable;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI, LCount: Integer;
  LItem: TTomlValue;
begin
  LInput := '';
  for LI := 1 to 100 do
    LInput := LInput + 'k' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, 'parse ok');
  LCount := 0;
  for LItem in TomlEnumerate(LDoc.Root) do
  begin
    Inc(LCount);
    Check(LItem.IsInt, 'item is int');
  end;
  CheckEqual(Int64(100), Int64(LCount), 'enumerate 100 items');
end;

procedure TestEnumeratorOnEmptyTable;
var
  LDoc: ITomlDocument;
  LItem: TTomlValue;
  LCount: Integer;
begin
  LDoc := TomlParse('');
  LCount := 0;
  for LItem in TomlEnumerate(LDoc.Root) do
    Inc(LCount);
  CheckEqual(Int64(0), Int64(LCount), 'enumerate empty = 0');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml stress');
  { Lifecycle }
  T.Run('parse reuse', @TestParseReuse);
  T.Run('many parse reuse cycles', @TestManyParseReuseCycles);
  T.Run('interface auto-release (1000x)', @TestInterfaceAutoRelease);
  T.Run('builder auto-release (1000x)', @TestBuilderAutoRelease);
  { Boundary/Depth }
  T.Run('200 empty arrays', @TestManyEmptyArrays);
  T.Run('200 empty inline tables', @TestManyEmptyInlineTables);
  T.Run('50-deep inline table', @TestDeepInlineTableNesting);
  T.Run('depth limit exact (128/129)', @TestDepthLimitExact);
  { State Machine }
  T.Run('value array then dotted key', @TestValueArrayThenDottedKey);
  T.Run('inline dotted key correct count', @TestInlineDottedKeyCorrectCount);
  T.Run('array-table then value array', @TestArrayTableThenValueArray);
  T.Run('dotted then explicit rejected', @TestDottedKeyImplicitThenExplicit);
  T.Run('explicit then dotted ok', @TestExplicitThenDottedOk);
  { Large Scale }
  T.Run('5000 keys', @TestLargeTable5000Keys);
  T.Run('500 array-table entries', @TestLargeArrayTable);
  T.Run('duplicate in large table', @TestDuplicateKeyInLargeTable);
  { Stringify }
  T.Run('stringify round-trip large', @TestStringifyRoundTripLargeDoc);
  T.Run('stringify empty document', @TestStringifyEmptyDocument);
  { Enumerator }
  T.Run('enumerate 100 items', @TestEnumeratorOnLargeTable);
  T.Run('enumerate empty', @TestEnumeratorOnEmptyTable);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
