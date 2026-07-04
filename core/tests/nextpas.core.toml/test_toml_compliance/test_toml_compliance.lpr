program test_toml_compliance;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.toml.value,
  nextpas.core.toml,
  nextpas.core.test;

var
  T: TTestSuite;

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
  Check(not LDoc.HasError, 'hex escape \x accepted (TOML v1.1)');
  Check(LDoc.Root.Get('x').AsStr.Equals(TStringView.Create(PAnsiChar('3'), 1)), '\x33 = "3"');
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

{ toml-test/valid/datetime }

procedure TestValidDateTimeLowerCase;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = 1987-07-05t17:45:00z');
  Check(not LDoc.HasError, 'lowercase t and z accepted');
  Check(LDoc.Root.Get('a').IsDateTime, 'is datetime');
  CheckEqual(Int64(1987), Int64(LDoc.Root.Get('a').AsDateTime.Year), 'year');
end;

{ toml-test/valid/key }

procedure TestValidDottedKeyMixed;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('name.first = "Arthur"' + #10 + '"name".''last'' = "Dent"');
  Check(not LDoc.HasError, 'mixed quote dotted key ok');
  Check(LDoc.Root.Get('name').Get('first').AsStr.Equals(
    TStringView.Create(PAnsiChar('Arthur'), 6)), 'name.first');
  Check(LDoc.Root.Get('name').Get('last').AsStr.Equals(
    TStringView.Create(PAnsiChar('Dent'), 4)), 'name.last');
end;

procedure TestValidKeySpaces;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('"a b" = 1' + #10 + '" c d " = 2');
  Check(not LDoc.HasError, 'quoted key with spaces ok');
  CheckEqual(Int64(1), LDoc.Root.Get('a b').AsInt, 'a b = 1');
  CheckEqual(Int64(2), LDoc.Root.Get(' c d ').AsInt, ' c d  = 2');
end;

{ toml-test/invalid/datetime }

procedure TestRejectDateTimeNoT;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1987-07-0517:45:00Z');
  Check(LDoc.HasError, 'no T separator rejected');
end;

procedure TestRejectDateTimeNoLeads;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1987-7-05T17:45:00Z');
  Check(LDoc.HasError, 'no leading zero in month rejected');
end;

procedure TestRejectDateTimeNoSecs;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1987-07-05T17:45Z');
  Check(LDoc.HasError, 'no seconds rejected');
end;

{ toml-test/valid/comment }

procedure TestValidTrickyComments;
var LDoc: ITomlDocument;
const
  TRICKY =
    '[section]#attached comment' + #10 +
    '#[notsection]' + #10 +
    'one = "11"#cmt' + #10 +
    'two = "22#"' + #10 +
    'three = ''#''' + #10;
begin
  LDoc := TomlParse(TRICKY);
  Check(not LDoc.HasError, 'tricky comments parse ok');
  Check(LDoc.Root.Get('section').Get('one').AsStr.Equals(
    TStringView.Create(PAnsiChar('11'), 2)), 'one = 11');
  Check(LDoc.Root.Get('section').Get('two').AsStr.Equals(
    TStringView.Create(PAnsiChar('22#'), 3)), 'two = 22#');
  Check(LDoc.Root.Get('section').Get('three').AsStr.Equals(
    TStringView.Create(PAnsiChar('#'), 1)), 'three = #');
end;

{ FindByPath }

procedure TestFindByPath;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a.b]' + #10 + 'c = 42' + #10 + '[server]' + #10 + 'host = "localhost"');
  Check(not LDoc.HasError, 'parse ok');
  CheckEqual(Int64(42), LDoc.Root.FindByPath('a.b.c').AsInt, 'a.b.c = 42');
  Check(LDoc.Root.FindByPath('server.host').AsStr.Equals(
    TStringView.Create(PAnsiChar('localhost'), 9)), 'server.host');
  Check(not LDoc.Root.FindByPath('a.b.missing').IsValid, 'missing path');
  Check(not LDoc.Root.FindByPath('x.y.z').IsValid, 'nonexistent path');
end;

{ toml-test/valid/array + inline-table + string }

procedure TestValidNestedDoubleArray;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('nest = [[["a"], [1, 2, [3]]]]');
  Check(not LDoc.HasError, 'nested double array ok');
  CheckEqual(Int64(1), LDoc.Root.Get('nest').ArrayLen, 'outer len');
  CheckEqual(Int64(2), LDoc.Root.Get('nest').ArrayGet(0).ArrayLen, 'inner len');
end;

procedure TestValidInlineTableNest;
var LDoc: ITomlDocument;
const
  INPUT =
    'tbl_tbl_empty = { tbl_0 = {} }' + #10 +
    'tbl_tbl_val = { tbl_1 = { one = 1 } }' + #10 +
    'arr_arr_tbl_empty = [ [ {} ] ]' + #10;
begin
  LDoc := TomlParse(INPUT);
  Check(not LDoc.HasError, 'inline table nest ok');
  Check(LDoc.Root.Get('tbl_tbl_empty').Get('tbl_0').IsTable, 'nested empty table');
  CheckEqual(Int64(1), LDoc.Root.Get('tbl_tbl_val').Get('tbl_1').Get('one').AsInt, 'nested val');
end;

procedure TestValidMultilineContinuation;
var LDoc: ITomlDocument;
const
  INPUT = 'equivalent_two = """' + #10 +
    'The quick brown \' + #10 + #10 + #10 +
    '  fox jumps over \' + #10 +
    '    the lazy dog."""' + #10;
begin
  LDoc := TomlParse(INPUT);
  Check(not LDoc.HasError, 'multiline continuation ok');
  Check(LDoc.Root.Get('equivalent_two').AsStr.Equals(
    TStringView.Create(PAnsiChar('The quick brown fox jumps over the lazy dog.'), 44)),
    'continuation result');
end;

procedure TestValidEscapedBackslash;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('answer = "\\x64"');
  Check(not LDoc.HasError, 'escaped backslash ok');
  Check(LDoc.Root.Get('answer').AsStr.Equals(
    TStringView.Create(PAnsiChar('\x64'), 4)), 'value = \x64');
end;

{ Codex review regression tests }

procedure TestEmptyQuotedKey;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('"" = "blank"');
  Check(not LDoc.HasError, 'empty quoted key accepted');
  Check(LDoc.Root.Get('').AsStr.Equals(
    TStringView.Create(PAnsiChar('blank'), 5)), 'empty key value');
end;

procedure TestRejectHexOverflow;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 0xffffffffffffffff');
  Check(LDoc.HasError, 'hex overflow rejected');
  LDoc := TomlParse('x = 0x8000000000000000');
  Check(LDoc.HasError, 'hex > Int64.Max rejected');
end;

procedure TestRejectValueArrayAsArrayTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('fruits = ["apple"]' + #10 + '[[fruits]]' + #10 + 'name = "banana"');
  Check(LDoc.HasError, 'value array then [[]] rejected');
end;

procedure TestRejectDottedKeyReopen;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('fruit.apple.color = "red"' + #10 + '[fruit.apple]' + #10 + 'taste = "sweet"');
  Check(LDoc.HasError, 'dotted key table reopen rejected');
end;

procedure TestMultiLine4Quotes;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = """line""""');
  Check(not LDoc.HasError, '4 quotes accepted');
  Check(LDoc.Root.Get('s').AsStr.Equals(
    TStringView.Create(PAnsiChar('line"'), 5)), '4 quotes = line"');
end;

procedure TestMultiLineEscapedBsNewline;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = """a\\' + #10 + 'b"""');
  Check(not LDoc.HasError, 'escaped-bs + newline ok');
  Check(LDoc.Root.Get('s').AsStr.Equals(
    TStringView.Create(PAnsiChar('a\' + #10 + 'b'), 4)), 'a\ + newline + b');
end;

{ toml-test/valid — remaining categories }

procedure TestValidFloatExponent;
var LDoc: ITomlDocument;
const
  INPUT = 'exp = 3e2' + #10 + 'pos-exp = 3e+2' + #10 + 'neg-exp = 3e-2' + #10 +
    'frac = 3.1e2' + #10 + 'neg = -1e-1' + #10 + 'zero = 0e2' + #10;
begin
  LDoc := TomlParse(INPUT);
  Check(not LDoc.HasError, 'float exponent forms ok');
  Check(Abs(LDoc.Root.Get('exp').AsFloat - 300.0) < 0.01, 'exp = 300');
  Check(Abs(LDoc.Root.Get('neg-exp').AsFloat - 0.03) < 0.001, 'neg-exp = 0.03');
  Check(Abs(LDoc.Root.Get('frac').AsFloat - 310.0) < 0.01, 'frac = 310');
  Check(Abs(LDoc.Root.Get('neg').AsFloat - (-0.1)) < 0.001, 'neg = -0.1');
end;

procedure TestValidFloatZero;
var LDoc: ITomlDocument;
const
  INPUT = 'zero = 0.0' + #10 + 'signed-pos = +0.0' + #10 + 'signed-neg = -0.0' + #10 +
    'exponent = 0e0' + #10;
begin
  LDoc := TomlParse(INPUT);
  Check(not LDoc.HasError, 'float zero forms ok');
  Check(Abs(LDoc.Root.Get('zero').AsFloat) < 0.001, 'zero = 0.0');
  Check(LDoc.Root.Get('exponent').IsFloat, 'exponent is float');
end;

procedure TestValidIntegerZero;
var LDoc: ITomlDocument;
const
  INPUT = 'd1 = 0' + #10 + 'd2 = +0' + #10 + 'd3 = -0' + #10 +
    'h1 = 0x0' + #10 + 'h2 = 0x00' + #10 + 'o1 = 0o0' + #10;
begin
  LDoc := TomlParse(INPUT);
  Check(not LDoc.HasError, 'integer zero forms ok');
  CheckEqual(Int64(0), LDoc.Root.Get('d1').AsInt, 'd1 = 0');
  CheckEqual(Int64(0), LDoc.Root.Get('d2').AsInt, 'd2 = +0');
  CheckEqual(Int64(0), LDoc.Root.Get('d3').AsInt, 'd3 = -0');
  CheckEqual(Int64(0), LDoc.Root.Get('h1').AsInt, 'h1 = 0x0');
  CheckEqual(Int64(0), LDoc.Root.Get('o1').AsInt, 'o1 = 0o0');
end;

procedure TestValidTableSubEmpty;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[a]' + #10 + '[a.b]');
  Check(not LDoc.HasError, 'sub-empty table ok');
  Check(LDoc.Root.Get('a').IsTable, 'a is table');
  Check(LDoc.Root.Get('a').Get('b').IsTable, 'a.b is table');
  CheckEqual(Int64(0), Int64(LDoc.Root.Get('a').Get('b').TableLen), 'a.b empty');
end;

procedure TestValidTableArrayImplicit;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[[albums.songs]]' + #10 + 'name = "Glory Days"');
  Check(not LDoc.HasError, 'array-implicit ok');
  Check(LDoc.Root.Get('albums').IsTable, 'albums is table');
  Check(LDoc.Root.Get('albums').Get('songs').IsArray, 'songs is array');
  Check(LDoc.Root.Get('albums').Get('songs').ArrayGet(0).Get('name').AsStr.Equals(
    TStringView.Create(PAnsiChar('Glory Days'), 10)), 'song name');
end;

{ Codex R2 regression tests }

procedure TestRejectArrayTableThenTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[[a]]' + #10 + 'x = 1' + #10 + '[a]' + #10 + 'y = 2');
  Check(LDoc.HasError, '[[a]] then [a] rejected');
end;

procedure TestRejectTimeOnlyOffset;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('t = 07:32:00Z');
  Check(LDoc.HasError, 'time-only with offset rejected');
  LDoc := TomlParse('t = 07:32:00+09:00');
  Check(LDoc.HasError, 'time-only with +offset rejected');
end;

procedure TestRejectFeb30;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('dt = 1979-02-30T00:00:00Z');
  Check(LDoc.HasError, 'Feb 30 rejected');
  LDoc := TomlParse('dt = 2024-02-30T00:00:00Z');
  Check(LDoc.HasError, 'Feb 30 leap year rejected');
  LDoc := TomlParse('dt = 2024-02-29T00:00:00Z');
  Check(not LDoc.HasError, 'Feb 29 leap year accepted');
end;

procedure TestLiteralMultiLine4Quotes;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = ' + #39#39#39 + 'line' + #39#39#39#39);
  Check(not LDoc.HasError, 'literal 4 quotes accepted');
  Check(LDoc.Root.Get('s').AsStr.Equals(
    TStringView.Create(PAnsiChar('line' + #39), 5)), 'literal 4q = line' + #39);
end;

{ Multi-line control char rejection }

procedure TestRejectCtrlMultiLineBasic;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = """abc' + #8 + 'def"""');
  Check(LDoc.HasError, 'backspace in multi-line basic rejected');
  LDoc := TomlParse('s = """abc' + #0 + 'def"""');
  Check(LDoc.HasError, 'null in multi-line basic rejected');
  LDoc := TomlParse('s = """abc' + #9 + 'def"""');
  Check(not LDoc.HasError, 'tab in multi-line basic accepted');
end;

procedure TestRejectCtrlMultiLineLiteral;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = ' + #39#39#39 + 'abc' + #8 + 'def' + #39#39#39);
  Check(LDoc.HasError, 'backspace in multi-line literal rejected');
  LDoc := TomlParse('s = ' + #39#39#39 + 'abc' + #9 + 'def' + #39#39#39);
  Check(not LDoc.HasError, 'tab in multi-line literal accepted');
end;

begin
  T := TTestSuite.Create('nextpas.core.toml compliance');
  { Valid }
  T.Test('multi-line basic string', @TestMultiLineBasicString);
  T.Test('multi-line literal string', @TestMultiLineLiteralString);
  T.Test('integer boundary', @TestIntegerBoundary);
  T.Test('float precision', @TestFloatPrecision);
  T.Test('empty string', @TestEmptyString);
  T.Test('empty array', @TestEmptyArray);
  T.Test('empty inline table', @TestEmptyInlineTable);
  T.Test('nested arrays', @TestNestedArrays);
  T.Test('unicode string', @TestUnicodeString);
  T.Test('datetime fractional', @TestDateTimeFractional);
  T.Test('datetime space separator', @TestDateTimeSpaceSeparator);
  T.Test('multiple table sections', @TestMultipleTableSections);
  T.Test('super-table after sub', @TestSuperTableAfterSub);
  T.Test('dotted key creates implicit', @TestDottedKeyCreatesImplicit);
  T.Test('array table multiple entries', @TestArrayTableMultipleEntries);
  T.Test('inline table nested', @TestInlineTableNested);
  T.Test('hex upper case', @TestHexUpperCase);
  T.Test('zero integer', @TestZeroInteger);
  T.Test('positive integer', @TestPositiveInteger);
  { Invalid }
  T.Test('reject duplicate key', @TestRejectDuplicateKey);
  T.Test('reject duplicate table', @TestRejectDuplicateTable);
  T.Test('reject bare key invalid', @TestRejectBareKeyInvalid);
  T.Test('reject missing value', @TestRejectMissingValue);
  T.Test('reject trailing garbage', @TestRejectTrailingGarbage);
  T.Test('reject invalid month', @TestRejectInvalidMonth);
  T.Test('reject invalid hour', @TestRejectInvalidHour);
  T.Test('reject datetime trailing', @TestRejectDateTimeTrailing);
  T.Test('dotted key with spaces', @TestDottedKeyWithSpaces);
  T.Test('reject leading zero', @TestRejectLeadingZero);
  T.Test('reject trailing dot', @TestRejectTrailingDot);
  T.Test('reject leading dot', @TestRejectLeadingDot);
  T.Test('reject trailing exponent', @TestRejectTrailingExponent);
  T.Test('reject double underscore', @TestRejectDoubleUnderscore);
  T.Test('reject leading underscore', @TestRejectLeadingUnderscore);
  T.Test('reject trailing underscore', @TestRejectTrailingUnderscore);
  T.Test('reject escape slash', @TestRejectEscapeSlash);
  T.Test('unicode escape \\u', @TestUnicodeEscape4);
  T.Test('unicode escape \\U', @TestUnicodeEscape8);
  T.Test('reject inline table extension', @TestRejectInlineTableExtension);
  T.Test('reject inline table reopen', @TestRejectInlineTableReopen);
  { Official toml-test suite cases }
  T.Test('spec-example-1', @TestSpecExample1);
  T.Test('implicit-explicit-after', @TestImplicitExplicitAfter);
  T.Test('reject hex escape', @TestRejectHexEscape);
  T.Test('multiline array', @TestMultilineArray);
  { toml-test/invalid/integer }
  T.Test('reject capital 0B/0X/0O', @TestRejectCapitalBin);
  T.Test('reject capital 0X', @TestRejectCapitalHex);
  T.Test('reject capital 0O', @TestRejectCapitalOct);
  T.Test('reject double sign', @TestRejectDoubleSign);
  T.Test('reject signed base prefix', @TestRejectSignedBase);
  T.Test('reject leading zero signed', @TestRejectLeadingZeroSigned);
  T.Test('reject underscore after prefix', @TestRejectUsAfterPrefix);
  { toml-test/invalid/string }
  T.Test('reject bad escapes', @TestRejectBadEscapes);
  T.Test('reject bad unicode', @TestRejectBadUnicode);
  T.Test('reject text after string', @TestRejectTextAfterString);
  { StringifyPretty }
  T.Test('stringify pretty', @TestStringifyPretty);
  { toml-test/invalid/float }
  T.Test('reject float double-e', @TestRejectFloatDoubleE);
  T.Test('reject float Inf/NaN capital', @TestRejectFloatCapital);
  T.Test('reject float leading-zero', @TestRejectFloatLeadingZero);
  { toml-test/invalid/table }
  T.Test('reject table redefine key', @TestRejectTableRedefineKey);
  T.Test('reject dotted key then array-table', @TestRejectDottedThenArrayTable);
  { toml-test/invalid/inline-table }
  T.Test('reject inline-table duplicate key', @TestRejectInlineDupKey);
  T.Test('reject inline-table overwrite', @TestRejectInlineOverwrite);
  { toml-test/valid cases }
  T.Test('spec-example-1-compact', @TestSpecExampleCompact);
  T.Test('implicit-explicit-before', @TestImplicitExplicitBefore);
  T.Test('implicit-groups', @TestImplicitGroups);
  { AsString convenience }
  T.Test('AsString method', @TestAsStringMethod);
  { toml-test/valid/datetime }
  T.Test('valid datetime lowercase t/z', @TestValidDateTimeLowerCase);
  { toml-test/valid/key }
  T.Test('valid dotted key mixed quotes', @TestValidDottedKeyMixed);
  T.Test('valid key with spaces', @TestValidKeySpaces);
  { toml-test/invalid/datetime }
  T.Test('reject datetime no-t', @TestRejectDateTimeNoT);
  T.Test('reject datetime no-leads', @TestRejectDateTimeNoLeads);
  T.Test('reject datetime no-secs', @TestRejectDateTimeNoSecs);
  { toml-test/valid/comment }
  T.Test('valid tricky comments', @TestValidTrickyComments);
  { FindByPath }
  T.Test('FindByPath', @TestFindByPath);
  { toml-test/valid/array + inline-table + string }
  T.Test('valid nested double array', @TestValidNestedDoubleArray);
  T.Test('valid inline-table nested', @TestValidInlineTableNest);
  T.Test('valid multiline line continuation', @TestValidMultilineContinuation);
  T.Test('valid escaped backslash', @TestValidEscapedBackslash);
  { Codex review regression tests }
  T.Test('empty quoted key', @TestEmptyQuotedKey);
  T.Test('reject hex overflow', @TestRejectHexOverflow);
  T.Test('reject value-array as array-table', @TestRejectValueArrayAsArrayTable);
  T.Test('reject dotted key reopen', @TestRejectDottedKeyReopen);
  T.Test('multi-line 4 quotes', @TestMultiLine4Quotes);
  T.Test('multi-line escaped-bs newline', @TestMultiLineEscapedBsNewline);
  { toml-test/valid — remaining categories }
  T.Test('valid float exponent forms', @TestValidFloatExponent);
  T.Test('valid float zero forms', @TestValidFloatZero);
  T.Test('valid integer zero forms', @TestValidIntegerZero);
  T.Test('valid table sub-empty', @TestValidTableSubEmpty);
  T.Test('valid table array-implicit', @TestValidTableArrayImplicit);
  { Codex R2 regression tests }
  T.Test('reject [[a]] then [a]', @TestRejectArrayTableThenTable);
  T.Test('reject time-only offset', @TestRejectTimeOnlyOffset);
  T.Test('reject Feb 30', @TestRejectFeb30);
  T.Test('literal multi-line 4 quotes', @TestLiteralMultiLine4Quotes);
  { Multi-line control char rejection }
  T.Test('reject ctrl in multi-line basic', @TestRejectCtrlMultiLineBasic);
  T.Test('reject ctrl in multi-line literal', @TestRejectCtrlMultiLineLiteral);
  if not T.Run then Halt(1);
end.
