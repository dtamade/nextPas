program test_json_edge_cases;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.json,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestInt64BoundsViaFacade;
var
  LDoc: IJsonDocument;
  LErr: TJsonError;
begin
  LDoc := JsonParse('9223372036854775807');
  Check(not LDoc.HasError, 'int64 max parses');
  Check(LDoc.Root.IsInt, 'int64 max is int');
  CheckEqual(High(Int64), LDoc.Root.AsInt, 'int64 max value');

  LDoc := JsonParse('-9223372036854775808');
  Check(not LDoc.HasError, 'int64 min parses');
  Check(LDoc.Root.IsInt, 'int64 min is int');
  CheckEqual(Low(Int64), LDoc.Root.AsInt, 'int64 min value');

  LDoc := JsonParse('{"n":9223372036854775807}');
  Check(not LDoc.HasError, 'int64 max in object parses');
  CheckEqual(High(Int64), LDoc.Root.ObjectGet('n').AsInt,
    'int64 max object field');

  LDoc := JsonParse('9223372036854775808');
  Check(LDoc.HasError, 'int64 max+1 rejects');
  LErr := LDoc.Error;
  CheckEqual('number overflow', LErr.Message.ToString,
    'positive overflow message via facade');

  LDoc := JsonParse('-9223372036854775809');
  Check(LDoc.HasError, 'int64 min-1 rejects');
  LErr := LDoc.Error;
  CheckEqual('number overflow', LErr.Message.ToString,
    'negative overflow message via facade');
end;

procedure TestJsSafeIntegerBoundary;
var
  LDoc: IJsonDocument;
const
  JS_SAFE_MAX = '9007199254740991'; { 2^53-1 }
  JS_SAFE_MAX_PLUS = '9007199254740992';
begin
  LDoc := JsonParse(JS_SAFE_MAX);
  Check(not LDoc.HasError, 'JS safe max parses as int');
  Check(LDoc.Root.IsInt, 'JS safe max is int kind');
  CheckEqual(Int64(9007199254740991), LDoc.Root.AsInt, 'JS safe max value');

  { Beyond JS float mantissa, still valid Int64 for nextPas. }
  LDoc := JsonParse(JS_SAFE_MAX_PLUS);
  Check(not LDoc.HasError, 'JS safe max+1 still valid int64');
  Check(LDoc.Root.IsInt, 'JS safe max+1 is int kind');
  CheckEqual(Int64(9007199254740992), LDoc.Root.AsInt, 'JS safe max+1 value');
end;

procedure TestLargeIntRoundtrip;
var
  LDoc: IJsonDocument;
  LText: string;
begin
  LDoc := JsonParse('{"hi":9223372036854775807,"lo":-9223372036854775808}');
  Check(not LDoc.HasError, 'bound object parses');
  LText := LDoc.Stringify;
  Check(Pos('9223372036854775807', LText) > 0, 'max survives stringify');
  Check(Pos('-9223372036854775808', LText) > 0, 'min survives stringify');
  LDoc := JsonParse(LText);
  Check(not LDoc.HasError, 'stringify reparse');
  CheckEqual(High(Int64), LDoc.Root.ObjectGet('hi').AsInt, 'roundtrip max');
  CheckEqual(Low(Int64), LDoc.Root.ObjectGet('lo').AsInt, 'roundtrip min');
end;

begin
  T := TTestSuite.Create('nextpas.core.json (edge cases / large int)');
  T.Test('int64 bounds via facade', @TestInt64BoundsViaFacade);
  T.Test('JS safe integer boundary', @TestJsSafeIntegerBoundary);
  T.Test('large int roundtrip', @TestLargeIntRoundtrip);
  if not T.Run then Halt(1);
end.
