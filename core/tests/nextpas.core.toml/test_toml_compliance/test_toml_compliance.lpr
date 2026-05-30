program test_toml_compliance;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.toml.value,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

{ --- Valid TOML that must parse --- }

procedure TestMultiLineBasicString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = """' + #10 + 'hello' + #10 + 'world"""');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('s').AsStr.Equals(
    TStringView.Create(PAnsiChar('hello' + #10 + 'world'), 11)), 'multi-line basic');
end;

procedure TestMultiLineLiteralString;
var LDoc: ITomlDocument;
const
  INPUT = 's = '#39#39#39 + #10 + 'no \escape' + #10 + 'here' + #39#39#39;
begin
  LDoc := TomlParse(INPUT);
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('s').AsStr.Equals(
    TStringView.Create(PAnsiChar('no \escape' + #10 + 'here'), 15)), 'multi-line literal');
end;

procedure TestIntegerBoundary;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('max = 9223372036854775807' + #10 + 'min = -9223372036854775808');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(9223372036854775807), LDoc.Root.Get('max').AsInt, 'Int64 max');
  CheckEqual(Int64(-9223372036854775808), LDoc.Root.Get('min').AsInt, 'Int64 min');
end;

procedure TestFloatPrecision;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('f = 1.7976931348623157e+308');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('f').AsFloat > 1.79e308, 'near Double max');
end;

procedure TestEmptyString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = ""');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('s').IsStr, 'is string');
  Check(LDoc.Root.Get('s').AsStr.IsEmpty, 'empty string');
end;

procedure TestEmptyArray;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = []');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('a').IsArray, 'is array');
  CheckEqual(Int64(0), Int64(LDoc.Root.Get('a').ArrayLen), 'empty array');
end;

procedure TestEmptyInlineTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('t = {}');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('t').IsTable, 'is table');
  CheckEqual(Int64(0), Int64(LDoc.Root.Get('t').TableLen), 'empty table');
end;

procedure TestNestedArrays;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = [[1, 2], [3, 4]]');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(2), Int64(LDoc.Root.Get('a').ArrayLen), '2 sub-arrays');
  CheckEqual(Int64(1), LDoc.Root.Get('a').ArrayGet(0).ArrayGet(0).AsInt, '[0][0] = 1');
  CheckEqual(Int64(4), LDoc.Root.Get('a').ArrayGet(1).ArrayGet(1).AsInt, '[1][1] = 4');
end;

procedure TestUnicodeString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = "ABC"');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('s').AsStr.Equals(
    TStringView.Create(PAnsiChar('ABC'), 3)), 'unicode ABC');
end;

procedure TestDateTimeFractional;
var
  LDoc: ITomlDocument;
  LDT: TTomlDateTime;
begin
  LDoc := TomlParse('dt = 1979-05-27T07:32:00.999999999Z');
  Check(not LDoc.HasError, 'no error');
  LDT := LDoc.Root.Get('dt').AsDateTime;
  CheckEqual(Int64(999999999), Int64(LDT.Nanosecond), 'nanosecond');
end;

procedure TestDateTimeSpaceSeparator;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('dt = 1979-05-27 07:32:00Z');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('dt').IsDateTime, 'is datetime');
end;

procedure TestMultipleTableSections;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse(
    '[a]' + #10 + 'x = 1' + #10 +
    '[b]' + #10 + 'y = 2' + #10 +
    '[c]' + #10 + 'z = 3');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), LDoc.Root.Get('a').Get('x').AsInt, 'a.x = 1');
  CheckEqual(Int64(2), LDoc.Root.Get('b').Get('y').AsInt, 'b.y = 2');
  CheckEqual(Int64(3), LDoc.Root.Get('c').Get('z').AsInt, 'c.z = 3');
end;

procedure TestSuperTableAfterSub;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse(
    '[a.b]' + #10 + 'x = 1' + #10 +
    '[a]' + #10 + 'y = 2');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), LDoc.Root.Get('a').Get('b').Get('x').AsInt, 'a.b.x = 1');
  CheckEqual(Int64(2), LDoc.Root.Get('a').Get('y').AsInt, 'a.y = 2');
end;

procedure TestDottedKeyCreatesImplicit;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('fruit.apple.color = "red"');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('fruit').IsTable, 'fruit is table');
  Check(LDoc.Root.Get('fruit').Get('apple').IsTable, 'apple is table');
  Check(LDoc.Root.Get('fruit').Get('apple').Get('color').AsStr.Equals(
    TStringView.Create(PAnsiChar('red'), 3)), 'color = red');
end;

procedure TestArrayTableMultipleEntries;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse(
    '[[fruits]]' + #10 + 'name = "apple"' + #10 +
    '[[fruits]]' + #10 + 'name = "banana"' + #10 +
    '[[fruits]]' + #10 + 'name = "cherry"');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(3), Int64(LDoc.Root.Get('fruits').ArrayLen), '3 fruits');
  Check(LDoc.Root.Get('fruits').ArrayGet(2).Get('name').AsStr.Equals(
    TStringView.Create(PAnsiChar('cherry'), 6)), 'fruit 2 = cherry');
end;

procedure TestInlineTableNested;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('point = {x = 1, y = 2, meta = {label = "origin"}}');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), LDoc.Root.Get('point').Get('x').AsInt, 'x = 1');
  Check(LDoc.Root.Get('point').Get('meta').Get('label').AsStr.Equals(
    TStringView.Create(PAnsiChar('origin'), 6)), 'meta.label = origin');
end;

procedure TestHexUpperCase;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0xDEADBEEF');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64($DEADBEEF), LDoc.Root.Get('x').AsInt, 'hex upper');
end;

procedure TestZeroInteger;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(0), LDoc.Root.Get('x').AsInt, 'zero');
end;

procedure TestPositiveInteger;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = +99');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(99), LDoc.Root.Get('x').AsInt, '+99');
end;

{ --- Invalid TOML that must be rejected --- }

procedure TestRejectDuplicateKey;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = 1' + #10 + 'a = 2');
  Check(LDoc.HasError, 'duplicate key rejected');
end;

procedure TestRejectDuplicateTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a]' + #10 + 'x = 1' + #10 + '[a]' + #10 + 'y = 2');
  Check(LDoc.HasError, 'duplicate explicit table rejected');
end;

procedure TestRejectBareKeyInvalid;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('key with spaces = 1');
  Check(LDoc.HasError, 'bare key with spaces rejected');
end;

procedure TestRejectMissingValue;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('key =');
  Check(LDoc.HasError, 'missing value rejected');
end;

procedure TestRejectTrailingGarbage;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('key = 1 garbage');
  Check(LDoc.HasError, 'trailing garbage rejected');
end;

procedure TestRejectInvalidMonth;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('dt = 1979-13-01T00:00:00Z');
  Check(LDoc.HasError, 'month 13 rejected');
end;

procedure TestRejectInvalidHour;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('dt = 1979-05-27T25:00:00Z');
  Check(LDoc.HasError, 'hour 25 rejected');
end;

procedure TestRejectDateTimeTrailing;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('dt = 1979-05-27oops');
  Check(LDoc.HasError, 'datetime trailing content rejected');
end;

procedure TestDottedKeyWithSpaces;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('fruit . color = "red"');
  Check(not LDoc.HasError, 'dotted key with spaces accepted');
  Check(LDoc.Root.Get('fruit').Get('color').AsStr.Equals(
    TStringView.Create(PAnsiChar('red'), 3)), 'fruit.color = red');
end;

procedure TestRejectLeadingZero;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 01');
  Check(LDoc.HasError, 'leading zero rejected');
end;

procedure TestRejectTrailingDot;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 7.');
  Check(LDoc.HasError, 'trailing dot rejected');
end;

procedure TestRejectLeadingDot;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = .5');
  Check(LDoc.HasError, 'leading dot rejected');
end;

procedure TestRejectTrailingExponent;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1e+');
  Check(LDoc.HasError, 'trailing exponent rejected');
end;

procedure TestRejectDoubleUnderscore;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1__2');
  Check(LDoc.HasError, 'double underscore rejected');
end;

procedure TestRejectLeadingUnderscore;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = _1');
  Check(LDoc.HasError, 'leading underscore rejected');
end;

procedure TestRejectTrailingUnderscore;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1_');
  Check(LDoc.HasError, 'trailing underscore rejected');
end;

procedure TestRejectEscapeSlash;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "a\/b"');
  Check(LDoc.HasError, 'escape slash \/ rejected in TOML');
end;

procedure TestUnicodeEscape4;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "A"');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('x').AsStr.Equals(
    TStringView.Create(PAnsiChar('A'), 1)), 'A = A');
end;

procedure TestUnicodeEscape8;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "\U0001F600"');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('x').AsStr.Len = 4, '\U0001F600 is 4 UTF-8 bytes');
end;

procedure TestRejectInlineTableExtension;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('point = {x = 1}' + #10 + 'point.y = 2');
  Check(LDoc.HasError, 'inline table extension rejected');
end;

procedure TestRejectInlineTableReopen;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('t = {a = 1}' + #10 + '[t]' + #10 + 'b = 2');
  Check(LDoc.HasError, 'inline table reopen rejected');
end;

procedure TestSpecExample1;
var LDoc: ITomlDocument;
const
  SPEC1 =
    '# This is a TOML document.' + #10 +
    'title = "TOML Example"' + #10 + #10 +
    '[owner]' + #10 +
    'name = "Lance Uppercut"' + #10 +
    'dob = 1979-05-27T07:32:00-08:00' + #10 + #10 +
    '[database]' + #10 +
    'server = "192.168.1.1"' + #10 +
    'ports = [ 8001, 8001, 8002 ]' + #10 +
    'connection_max = 5000' + #10 +
    'enabled = true' + #10 + #10 +
    '[servers]' + #10 + #10 +
    '[servers.alpha]' + #10 +
    'ip = "10.0.0.1"' + #10 +
    'dc = "eqdc10"' + #10 + #10 +
    '[servers.beta]' + #10 +
    'ip = "10.0.0.2"' + #10 +
    'dc = "eqdc10"' + #10 + #10 +
    '[clients]' + #10 +
    'data = [ ["gamma", "delta"], [1, 2] ]' + #10 +
    'hosts = [' + #10 + '  "alpha",' + #10 + '  "omega"' + #10 + ']' + #10;
begin
  LDoc := TomlParse(SPEC1);
  Check(not LDoc.HasError, 'spec example 1 parses');
  Check(LDoc.Root.Get('title').AsStr.Equals(
    TStringView.Create(PAnsiChar('TOML Example'), 12)), 'title');
  Check(LDoc.Root.Get('owner').Get('name').AsStr.Equals(
    TStringView.Create(PAnsiChar('Lance Uppercut'), 14)), 'owner.name');
  CheckEqual(Int64(5000), LDoc.Root.Get('database').Get('connection_max').AsInt, 'connection_max');
  CheckEqual(Int64(3), LDoc.Root.Get('database').Get('ports').ArrayLen, 'ports len');
  Check(LDoc.Root.Get('database').Get('enabled').AsBool, 'enabled');
  Check(LDoc.Root.Get('servers').Get('alpha').Get('ip').AsStr.Equals(
    TStringView.Create(PAnsiChar('10.0.0.1'), 8)), 'servers.alpha.ip');
  CheckEqual(Int64(2), LDoc.Root.Get('clients').Get('hosts').ArrayLen, 'hosts len');
end;

procedure TestImplicitExplicitAfter;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a.b.c]' + #10 + 'answer = 42' + #10 + '[a]' + #10 + 'better = 43');
  Check(not LDoc.HasError, 'implicit then explicit ok');
  CheckEqual(Int64(42), LDoc.Root.Get('a').Get('b').Get('c').Get('answer').AsInt, 'a.b.c.answer');
  CheckEqual(Int64(43), LDoc.Root.Get('a').Get('better').AsInt, 'a.better');
end;

procedure TestRejectHexEscape;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "\x33"');
  Check(LDoc.HasError, 'hex escape \x rejected in TOML v1.0');
end;

procedure TestMultilineArray;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('hosts = [' + #10 + '  "alpha",' + #10 + '  "omega",' + #10 + ']');
  Check(not LDoc.HasError, 'multiline array ok');
  CheckEqual(Int64(2), LDoc.Root.Get('hosts').ArrayLen, 'hosts len');
end;

{ toml-test/invalid/integer }

procedure TestRejectCapitalBin;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0B0');
  Check(LDoc.HasError, 'capital 0B rejected');
end;

procedure TestRejectCapitalHex;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0X1');
  Check(LDoc.HasError, 'capital 0X rejected');
end;

procedure TestRejectCapitalOct;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0O0');
  Check(LDoc.HasError, 'capital 0O rejected');
end;

procedure TestRejectDoubleSign;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = --99');
  Check(LDoc.HasError, 'double sign -- rejected');
  LDoc := TomlParse('x = ++99');
  Check(LDoc.HasError, 'double sign ++ rejected');
end;

procedure TestRejectSignedBase;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = -0b11010110');
  Check(LDoc.HasError, 'negative bin rejected');
  LDoc := TomlParse('x = +0xff');
  Check(LDoc.HasError, 'positive hex rejected');
  LDoc := TomlParse('x = -0o755');
  Check(LDoc.HasError, 'negative oct rejected');
end;

procedure TestRejectLeadingZeroSigned;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = -01');
  Check(LDoc.HasError, '-01 rejected');
  LDoc := TomlParse('x = +01');
  Check(LDoc.HasError, '+01 rejected');
end;

procedure TestRejectUsAfterPrefix;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0b_1');
  Check(LDoc.HasError, '0b_ rejected');
  LDoc := TomlParse('x = 0x_f');
  Check(LDoc.HasError, '0x_ rejected');
  LDoc := TomlParse('x = 0o_7');
  Check(LDoc.HasError, '0o_ rejected');
end;

{ toml-test/invalid/string }

procedure TestRejectBadEscapes;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "\a"');
  Check(LDoc.HasError, '\a rejected');
  LDoc := TomlParse('x = "\0"');
  Check(LDoc.HasError, '\0 rejected');
  LDoc := TomlParse('x = "\x33"');
  Check(LDoc.HasError, '\x rejected');
end;

procedure TestRejectBadUnicode;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "\uD800"');
  Check(LDoc.HasError, 'surrogate \uD800 rejected');
  LDoc := TomlParse('x = "\U00110000"');
  Check(LDoc.HasError, 'out of range \U00110000 rejected');
  LDoc := TomlParse('x = "\u00"');
  Check(LDoc.HasError, 'short \u00 rejected');
end;

procedure TestRejectTextAfterString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = "a"b');
  Check(LDoc.HasError, 'text after string rejected');
end;

procedure TestStringifyPretty;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('nums = [1, 2, 3]');
  Check(not LDoc.HasError, 'parse ok');
  Check(Pos(#10 + '  ', LDoc.StringifyPretty(2)) > 0, 'pretty has indentation');
end;

{ toml-test/invalid/float }

procedure TestRejectFloatDoubleE;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1ee2');
  Check(LDoc.HasError, '1ee2 rejected');
  LDoc := TomlParse('x = 1e2e3');
  Check(LDoc.HasError, '1e2e3 rejected');
end;

procedure TestRejectFloatCapital;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = Inf');
  Check(LDoc.HasError, 'Inf capital rejected');
  LDoc := TomlParse('x = NaN');
  Check(LDoc.HasError, 'NaN capital rejected');
end;

procedure TestRejectFloatLeadingZero;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 03.14');
  Check(LDoc.HasError, '03.14 rejected');
end;

{ toml-test/invalid/table }

procedure TestRejectTableRedefineKey;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[fruit]' + #10 + 'type = "apple"' + #10 + '[fruit.type]' + #10 + 'apple = "yes"');
  Check(LDoc.HasError, 'redefine scalar as table rejected');
end;

procedure TestRejectDottedThenArrayTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[fruit]' + #10 + 'apple.color = "red"' + #10 + '[[fruit.apple]]');
  Check(LDoc.HasError, 'dotted key then array-table rejected');
end;

{ toml-test/invalid/inline-table }

procedure TestRejectInlineDupKey;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = {b = 1, b = 2}');
  Check(LDoc.HasError, 'inline table duplicate key rejected');
end;

procedure TestRejectInlineOverwrite;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = { b = 1 }' + #10 + 'a.b = 2');
  Check(LDoc.HasError, 'inline table overwrite rejected');
end;

{ toml-test/valid cases }

procedure TestSpecExampleCompact;
var LDoc: ITomlDocument;
const
  COMPACT =
    'title="TOML Example"' + #10 +
    '[owner]' + #10 +
    'name="Lance Uppercut"' + #10 +
    'dob=1979-05-27T07:32:00-08:00' + #10 +
    '[database]' + #10 +
    'server="192.168.1.1"' + #10 +
    'ports=[8001,8001,8002]' + #10 +
    'connection_max=5000' + #10 +
    'enabled=true' + #10 +
    '[servers]' + #10 +
    '[servers.alpha]' + #10 +
    'ip="10.0.0.1"' + #10 +
    'dc="eqdc10"' + #10 +
    '[servers.beta]' + #10 +
    'ip="10.0.0.2"' + #10 +
    'dc="eqdc10"' + #10 +
    '[clients]' + #10 +
    'data=[["gamma","delta"],[1,2]]' + #10 +
    'hosts=["alpha","omega"]' + #10;
begin
  LDoc := TomlParse(COMPACT);
  Check(not LDoc.HasError, 'compact spec example parses');
  CheckEqual(Int64(5000), LDoc.Root.Get('database').Get('connection_max').AsInt, 'connection_max');
end;

procedure TestImplicitExplicitBefore;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a]' + #10 + 'better = 43' + #10 + '[a.b.c]' + #10 + 'answer = 42');
  Check(not LDoc.HasError, 'explicit then implicit ok');
  CheckEqual(Int64(43), LDoc.Root.Get('a').Get('better').AsInt, 'a.better');
  CheckEqual(Int64(42), LDoc.Root.Get('a').Get('b').Get('c').Get('answer').AsInt, 'a.b.c.answer');
end;

procedure TestImplicitGroups;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a.b.c]' + #10 + 'answer = 42');
  Check(not LDoc.HasError, 'implicit groups ok');
  Check(LDoc.Root.Get('a').IsTable, 'a is table');
  Check(LDoc.Root.Get('a').Get('b').IsTable, 'a.b is table');
  CheckEqual(Int64(42), LDoc.Root.Get('a').Get('b').Get('c').Get('answer').AsInt, 'answer');
end;

procedure TestAsStringMethod;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('name = "Alice"' + #10 + 'num = 42');
  Check(not LDoc.HasError, 'parse ok');
  CheckEqual('Alice', LDoc.Root.Get('name').AsString, 'AsString');
  CheckEqual('', LDoc.Root.Get('num').AsString, 'AsString on non-string');
  CheckEqual('', LDoc.Root.Get('missing').AsString, 'AsString on missing');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml compliance');
  { Valid }
  T.Run('multi-line basic string', @TestMultiLineBasicString);
  T.Run('multi-line literal string', @TestMultiLineLiteralString);
  T.Run('integer boundary', @TestIntegerBoundary);
  T.Run('float precision', @TestFloatPrecision);
  T.Run('empty string', @TestEmptyString);
  T.Run('empty array', @TestEmptyArray);
  T.Run('empty inline table', @TestEmptyInlineTable);
  T.Run('nested arrays', @TestNestedArrays);
  T.Run('unicode string', @TestUnicodeString);
  T.Run('datetime fractional', @TestDateTimeFractional);
  T.Run('datetime space separator', @TestDateTimeSpaceSeparator);
  T.Run('multiple table sections', @TestMultipleTableSections);
  T.Run('super-table after sub', @TestSuperTableAfterSub);
  T.Run('dotted key creates implicit', @TestDottedKeyCreatesImplicit);
  T.Run('array table multiple entries', @TestArrayTableMultipleEntries);
  T.Run('inline table nested', @TestInlineTableNested);
  T.Run('hex upper case', @TestHexUpperCase);
  T.Run('zero integer', @TestZeroInteger);
  T.Run('positive integer', @TestPositiveInteger);
  { Invalid }
  T.Run('reject duplicate key', @TestRejectDuplicateKey);
  T.Run('reject duplicate table', @TestRejectDuplicateTable);
  T.Run('reject bare key invalid', @TestRejectBareKeyInvalid);
  T.Run('reject missing value', @TestRejectMissingValue);
  T.Run('reject trailing garbage', @TestRejectTrailingGarbage);
  T.Run('reject invalid month', @TestRejectInvalidMonth);
  T.Run('reject invalid hour', @TestRejectInvalidHour);
  T.Run('reject datetime trailing', @TestRejectDateTimeTrailing);
  T.Run('dotted key with spaces', @TestDottedKeyWithSpaces);
  T.Run('reject leading zero', @TestRejectLeadingZero);
  T.Run('reject trailing dot', @TestRejectTrailingDot);
  T.Run('reject leading dot', @TestRejectLeadingDot);
  T.Run('reject trailing exponent', @TestRejectTrailingExponent);
  T.Run('reject double underscore', @TestRejectDoubleUnderscore);
  T.Run('reject leading underscore', @TestRejectLeadingUnderscore);
  T.Run('reject trailing underscore', @TestRejectTrailingUnderscore);
  T.Run('reject escape slash', @TestRejectEscapeSlash);
  T.Run('unicode escape \\u', @TestUnicodeEscape4);
  T.Run('unicode escape \\U', @TestUnicodeEscape8);
  T.Run('reject inline table extension', @TestRejectInlineTableExtension);
  T.Run('reject inline table reopen', @TestRejectInlineTableReopen);
  { Official toml-test suite cases }
  T.Run('spec-example-1', @TestSpecExample1);
  T.Run('implicit-explicit-after', @TestImplicitExplicitAfter);
  T.Run('reject hex escape', @TestRejectHexEscape);
  T.Run('multiline array', @TestMultilineArray);
  { toml-test/invalid/integer }
  T.Run('reject capital 0B/0X/0O', @TestRejectCapitalBin);
  T.Run('reject capital 0X', @TestRejectCapitalHex);
  T.Run('reject capital 0O', @TestRejectCapitalOct);
  T.Run('reject double sign', @TestRejectDoubleSign);
  T.Run('reject signed base prefix', @TestRejectSignedBase);
  T.Run('reject leading zero signed', @TestRejectLeadingZeroSigned);
  T.Run('reject underscore after prefix', @TestRejectUsAfterPrefix);
  { toml-test/invalid/string }
  T.Run('reject bad escapes', @TestRejectBadEscapes);
  T.Run('reject bad unicode', @TestRejectBadUnicode);
  T.Run('reject text after string', @TestRejectTextAfterString);
  { StringifyPretty }
  T.Run('stringify pretty', @TestStringifyPretty);
  { toml-test/invalid/float }
  T.Run('reject float double-e', @TestRejectFloatDoubleE);
  T.Run('reject float Inf/NaN capital', @TestRejectFloatCapital);
  T.Run('reject float leading-zero', @TestRejectFloatLeadingZero);
  { toml-test/invalid/table }
  T.Run('reject table redefine key', @TestRejectTableRedefineKey);
  T.Run('reject dotted key then array-table', @TestRejectDottedThenArrayTable);
  { toml-test/invalid/inline-table }
  T.Run('reject inline-table duplicate key', @TestRejectInlineDupKey);
  T.Run('reject inline-table overwrite', @TestRejectInlineOverwrite);
  { toml-test/valid cases }
  T.Run('spec-example-1-compact', @TestSpecExampleCompact);
  T.Run('implicit-explicit-before', @TestImplicitExplicitBefore);
  T.Run('implicit-groups', @TestImplicitGroups);
  { AsString convenience }
  T.Run('AsString method', @TestAsStringMethod);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
