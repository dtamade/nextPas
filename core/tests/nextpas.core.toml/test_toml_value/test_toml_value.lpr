program test_toml_value;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.toml.value,
  nextpas.core.testing;

var
  T: TTestRunner;

function ParseDoc(const AToml: string): TTomlDocument;
begin
  Result.Init(DefaultAllocator);
  if not Result.Parse(TStringView.FromStr(AToml)) then
  begin
    WriteLn('  Parse error: ', Result.Error.Message.ToString);
    Result.Done;
    Fail('parse failed');
  end;
end;

procedure TestInvalidValue;
var
  LDoc: TTomlDocument;
  LVal: TTomlValue;
begin
  LDoc := ParseDoc('');
  LVal := TTomlValue.Create(LDoc, TOML_NODE_NONE);
  Check(not LVal.IsValid, 'not valid');
  CheckEqual(Int64(0), LVal.AsInt, 'int default 0');
  Check(LVal.AsStr.IsEmpty, 'str default empty');
  Check(not LVal.AsBool, 'bool default false');
  LDoc.Done;
end;

procedure TestGetString;
var
  LDoc: TTomlDocument;
  LRoot, LVal: TTomlValue;
begin
  LDoc := ParseDoc('name = "Alice"');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LVal := LRoot.Get('name');
  Check(LVal.IsValid, 'valid');
  Check(LVal.IsStr, 'is string');
  Check(LVal.AsStr.Equals(TStringView.Create(PAnsiChar('Alice'), 5)), 'val = Alice');
  LDoc.Done;
end;

procedure TestGetInt;
var
  LDoc: TTomlDocument;
  LRoot, LVal: TTomlValue;
begin
  LDoc := ParseDoc('port = 8080');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LVal := LRoot.Get('port');
  Check(LVal.IsValid, 'valid');
  Check(LVal.IsInt, 'is int');
  CheckEqual(Int64(8080), LVal.AsInt, 'val = 8080');
  LDoc.Done;
end;

procedure TestGetFloat;
var
  LDoc: TTomlDocument;
  LRoot, LVal: TTomlValue;
begin
  LDoc := ParseDoc('pi = 3.14');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LVal := LRoot.Get('pi');
  Check(LVal.IsFloat, 'is float');
  Check(Abs(LVal.AsFloat - 3.14) < 0.001, 'val ~ 3.14');
  LDoc.Done;
end;

procedure TestGetBool;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('a = true' + #10 + 'b = false');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  Check(LRoot.Get('a').AsBool = True, 'a = true');
  Check(LRoot.Get('b').AsBool = False, 'b = false');
  LDoc.Done;
end;

procedure TestGetMissing;
var
  LDoc: TTomlDocument;
  LRoot, LVal: TTomlValue;
begin
  LDoc := ParseDoc('x = 1');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LVal := LRoot.Get('nonexistent');
  Check(not LVal.IsValid, 'not valid');
  CheckEqual(Int64(0), LVal.AsInt, 'default 0');
  LDoc.Done;
end;

procedure TestHas;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('x = 1');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  Check(LRoot.Has('x'), 'has x');
  Check(not LRoot.Has('y'), 'not has y');
  LDoc.Done;
end;

procedure TestNestedTable;
var
  LDoc: TTomlDocument;
  LRoot, LServer: TTomlValue;
begin
  LDoc := ParseDoc('[server]' + #10 + 'host = "localhost"' + #10 + 'port = 9090');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LServer := LRoot.Get('server');
  Check(LServer.IsValid, 'server exists');
  Check(LServer.IsTable, 'server is table');
  Check(LServer.Get('host').AsStr.Equals(
    TStringView.Create(PAnsiChar('localhost'), 9)), 'host = localhost');
  CheckEqual(Int64(9090), LServer.Get('port').AsInt, 'port = 9090');
  LDoc.Done;
end;

procedure TestChainedGet;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('[a.b]' + #10 + 'c = 42');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  CheckEqual(Int64(42), LRoot.Get('a').Get('b').Get('c').AsInt, 'a.b.c = 42');
  LDoc.Done;
end;

procedure TestTableLen;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('a = 1' + #10 + 'b = 2' + #10 + 'c = 3');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  CheckEqual(Int64(3), Int64(LRoot.TableLen), 'table len = 3');
  LDoc.Done;
end;

procedure TestTableKeyAt;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('alpha = 1' + #10 + 'beta = 2');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  Check(LRoot.TableKeyAt(0).Equals(TStringView.Create(PAnsiChar('alpha'), 5)), 'key 0 = alpha');
  Check(LRoot.TableKeyAt(1).Equals(TStringView.Create(PAnsiChar('beta'), 4)), 'key 1 = beta');
  LDoc.Done;
end;

procedure TestTableValueAt;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('a = 10' + #10 + 'b = 20');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  CheckEqual(Int64(10), LRoot.TableValueAt(0).AsInt, 'val 0 = 10');
  CheckEqual(Int64(20), LRoot.TableValueAt(1).AsInt, 'val 1 = 20');
  LDoc.Done;
end;

procedure TestArrayLen;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('nums = [1, 2, 3, 4, 5]');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  CheckEqual(Int64(5), Int64(LRoot.Get('nums').ArrayLen), 'array len = 5');
  LDoc.Done;
end;

procedure TestArrayGet;
var
  LDoc: TTomlDocument;
  LRoot, LArr: TTomlValue;
begin
  LDoc := ParseDoc('items = ["a", "b", "c"]');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LArr := LRoot.Get('items');
  Check(LArr.ArrayGet(0).AsStr.Equals(TStringView.Create(PAnsiChar('a'), 1)), 'item 0 = a');
  Check(LArr.ArrayGet(1).AsStr.Equals(TStringView.Create(PAnsiChar('b'), 1)), 'item 1 = b');
  Check(LArr.ArrayGet(2).AsStr.Equals(TStringView.Create(PAnsiChar('c'), 1)), 'item 2 = c');
  Check(not LArr.ArrayGet(3).IsValid, 'item 3 invalid');
  LDoc.Done;
end;

procedure TestArrayTable;
var
  LDoc: TTomlDocument;
  LRoot, LProducts, LItem: TTomlValue;
begin
  LDoc := ParseDoc('[[products]]' + #10 + 'name = "Hammer"' + #10 +
    '[[products]]' + #10 + 'name = "Nail"');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LProducts := LRoot.Get('products');
  Check(LProducts.IsArray, 'products is array');
  CheckEqual(Int64(2), Int64(LProducts.ArrayLen), '2 products');
  LItem := LProducts.ArrayGet(0);
  Check(LItem.IsTable, 'item 0 is table');
  Check(LItem.Get('name').AsStr.Equals(TStringView.Create(PAnsiChar('Hammer'), 6)), 'item 0 = Hammer');
  LItem := LProducts.ArrayGet(1);
  Check(LItem.Get('name').AsStr.Equals(TStringView.Create(PAnsiChar('Nail'), 4)), 'item 1 = Nail');
  LDoc.Done;
end;

procedure TestDateTime;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
  LDT: TTomlDateTime;
begin
  LDoc := ParseDoc('dt = 2024-06-15T14:30:00+09:00');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  Check(LRoot.Get('dt').IsDateTime, 'is datetime');
  LDT := LRoot.Get('dt').AsDateTime;
  CheckEqual(Int64(2024), Int64(LDT.Year), 'year');
  CheckEqual(Int64(6), Int64(LDT.Month), 'month');
  CheckEqual(Int64(14), Int64(LDT.Hour), 'hour');
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(540), Int64(LDT.OffsetMinutes), 'offset +09:00');
  LDoc.Done;
end;

procedure TestIntPromotesToFloat;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('n = 42');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  Check(Abs(LRoot.Get('n').AsFloat - 42.0) < 0.001, 'int promotes to float');
  LDoc.Done;
end;

procedure TestEnumerateArray;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
  LItem: TTomlValue;
  LSum: Int64;
begin
  LDoc := ParseDoc('nums = [10, 20, 30]');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LSum := 0;
  for LItem in TomlEnumerate(LRoot.Get('nums')) do
    LSum := LSum + LItem.AsInt;
  CheckEqual(Int64(60), LSum, 'enumerate array sum');
  LDoc.Done;
end;

procedure TestEnumerateTable;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
  LItem: TTomlValue;
  LCount: Int32;
begin
  LDoc := ParseDoc('a = 1' + #10 + 'b = 2' + #10 + 'c = 3');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LCount := 0;
  for LItem in TomlEnumerate(LRoot) do
    Inc(LCount);
  CheckEqual(Int64(3), Int64(LCount), 'enumerate table count');
  LDoc.Done;
end;

procedure TestEnumerateEmpty;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
  LItem: TTomlValue;
  LCount: Int32;
begin
  LDoc := ParseDoc('arr = []');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LCount := 0;
  for LItem in TomlEnumerate(LRoot.Get('arr')) do
    Inc(LCount);
  CheckEqual(Int64(0), Int64(LCount), 'enumerate empty');
  LDoc.Done;
end;

procedure TestKeyProperty;
var
  LDoc: TTomlDocument;
  LRoot, LItem: TTomlValue;
  LKeys: string;
begin
  LDoc := ParseDoc('alpha = 1' + #10 + 'beta = 2' + #10 + 'gamma = 3');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  LKeys := '';
  for LItem in TomlEnumerate(LRoot) do
    LKeys := LKeys + LItem.Key.ToString + ',';
  CheckEqual('alpha,beta,gamma,', LKeys, 'key property iteration');
  Check(LRoot.Get('beta').Key.Equals(TStringView.Create(PAnsiChar('beta'), 4)), 'key of get');
  LDoc.Done;
end;

procedure TestFindByPath;
var
  LDoc: TTomlDocument;
  LRoot: TTomlValue;
begin
  LDoc := ParseDoc('[a.b]' + #10 + 'c = 42' + #10 + '[server]' + #10 + 'host = "localhost"');
  LRoot := TTomlValue.Create(LDoc, LDoc.Root);
  CheckEqual(Int64(42), LRoot.FindByPath('a.b.c').AsInt, 'a.b.c = 42');
  Check(LRoot.FindByPath('server.host').AsStr.Equals(
    TStringView.Create(PAnsiChar('localhost'), 9)), 'server.host');
  Check(not LRoot.FindByPath('a.b.missing').IsValid, 'missing path');
  Check(not LRoot.FindByPath('x.y.z').IsValid, 'nonexistent path');
  CheckEqual(Int64(42), LRoot.FindByPath('a').FindByPath('b.c').AsInt, 'chained FindByPath');
  LDoc.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.value');
  T.Run('invalid value', @TestInvalidValue);
  T.Run('get string', @TestGetString);
  T.Run('get int', @TestGetInt);
  T.Run('get float', @TestGetFloat);
  T.Run('get bool', @TestGetBool);
  T.Run('get missing', @TestGetMissing);
  T.Run('has', @TestHas);
  T.Run('nested table', @TestNestedTable);
  T.Run('chained get', @TestChainedGet);
  T.Run('table len', @TestTableLen);
  T.Run('table key at', @TestTableKeyAt);
  T.Run('table value at', @TestTableValueAt);
  T.Run('array len', @TestArrayLen);
  T.Run('array get', @TestArrayGet);
  T.Run('array table', @TestArrayTable);
  T.Run('datetime', @TestDateTime);
  T.Run('int promotes to float', @TestIntPromotesToFloat);
  T.Run('enumerate array', @TestEnumerateArray);
  T.Run('enumerate table', @TestEnumerateTable);
  T.Run('enumerate empty', @TestEnumerateEmpty);
  T.Run('key property', @TestKeyProperty);
  T.Run('find by path', @TestFindByPath);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
