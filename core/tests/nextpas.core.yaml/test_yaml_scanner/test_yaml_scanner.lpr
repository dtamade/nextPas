program test_yaml_scanner;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.scanner;

var
  T: TTestRunner;

procedure TestStreamStartEnd;
var
  S: TYamlScanner;
  LTok: TYamlToken;
begin
  S.Init(nil, 0);
  LTok := S.NextToken;
  Check(LTok.Kind = ytkStreamStart, 'stream start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkStreamEnd, 'stream end');
end;

procedure TestFlowMapping;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '{name: Alice, age: 30}';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'stream start');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapStart, '{');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'key name');
  Check(LTok.Value.ToString = 'name', 'key=name');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, ':');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'val Alice');
  Check(LTok.Value.ToString = 'Alice', 'val=Alice');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowEntry, ',');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'key age');
  Check(LTok.Value.ToString = 'age', 'key=age');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, ': 2');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'val 30');
  Check(LTok.Value.ToString = '30', 'val=30');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapEnd, '}');
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamEnd, 'end');
end;

procedure TestFlowSequence;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '[1, 2, hello]';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'start');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowSeqStart, '[');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, '1');
  Check(LTok.Value.ToString = '1', 'v=1');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowEntry, ',1');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, '2');
  Check(LTok.Value.ToString = '2', 'v=2');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowEntry, ',2');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'hello');
  Check(LTok.Value.ToString = 'hello', 'v=hello');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowSeqEnd, ']');
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamEnd, 'end');
end;

procedure TestSingleQuoted;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '''hello world''';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; // stream start
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'single quoted scalar');
  Check(LTok.Style = yssSingleQuoted, 'style single');
  Check(LTok.Value.ToString = 'hello world', 'value');
end;

procedure TestDoubleQuoted;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '"hello\nworld"';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; // stream start
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'double quoted scalar');
  Check(LTok.Style = yssDoubleQuoted, 'style double');
  Check(LTok.Value.ToString = 'hello\nworld', 'raw value with escape');

  LInput := '"tab \' + #9 + 'escape"';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; // stream start
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'literal-tab escape accepted');
  Check(LTok.Style = yssDoubleQuoted, 'literal-tab escape style');
  Check(LTok.Value.ToString = 'tab \' + #9 + 'escape',
    'literal-tab escape remains raw value');
end;

procedure TestRejectsInvalidDoubleQuotedEscape;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '"bad \q escape"';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'invalid escape start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'invalid double-quoted escape rejected');
  Check(Pos('invalid escape', S.Error.Message.ToString) > 0,
    'invalid escape diagnostic');
  CheckEqual(Int64(1), Int64(S.Error.Line), 'invalid escape line');
  CheckEqual(Int64(6), Int64(S.Error.Col), 'invalid escape column');
  CheckEqual(Int64(5), Int64(S.Error.Offset), 'invalid escape offset');
end;

procedure TestComments;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '{a: 1} # comment';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'start');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapStart, '{');
  LTok := S.NextToken; Check(LTok.Value.ToString = 'a', 'key');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, ':');
  LTok := S.NextToken; Check(LTok.Value.ToString = '1', 'val');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapEnd, '}');
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamEnd, 'end after comment');
end;

procedure TestAnchorAlias;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '&ref value';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; // stream start
  LTok := S.NextToken;
  Check(LTok.Kind = ytkAnchor, 'anchor');
  Check(LTok.Value.ToString = 'ref', 'anchor name');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'scalar after anchor');
  Check(LTok.Value.ToString = 'value', 'scalar value');
end;

procedure TestRejectsEmptyAnchorAliasNames;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '& value';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'empty anchor start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'empty anchor rejected');
  Check(Pos('empty anchor/alias name', S.Error.Message.ToString) > 0,
    'empty anchor diagnostic');
  CheckEqual(Int64(1), Int64(S.Error.Line), 'empty anchor line');
  CheckEqual(Int64(2), Int64(S.Error.Col), 'empty anchor column');
  CheckEqual(Int64(1), Int64(S.Error.Offset), 'empty anchor offset');

  LInput := '* ';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'empty alias start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'empty alias rejected');
  Check(Pos('empty anchor/alias name', S.Error.Message.ToString) > 0,
    'empty alias diagnostic');
  CheckEqual(Int64(1), Int64(S.Error.Line), 'empty alias line');
  CheckEqual(Int64(2), Int64(S.Error.Col), 'empty alias column');
  CheckEqual(Int64(1), Int64(S.Error.Offset), 'empty alias offset');
end;

procedure TestDocMarkers;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '---' + #10 + 'hello' + #10 + '...';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'start');
  LTok := S.NextToken; Check(LTok.Kind = ytkDocStart, '---');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'hello');
  Check(LTok.Value.ToString = 'hello', 'v=hello');
  LTok := S.NextToken; Check(LTok.Kind = ytkDocEnd, '...');
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamEnd, 'end');
end;

procedure TestRejectsUnsupportedDirectives;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '%YAML 1.2' + #10 + 'hello';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'yaml directive rejected');
  Check(Pos('directives', S.Error.Message.ToString) > 0, 'directive diagnostic');

  LInput := '%TAG !e! tag:example.com,2024:' + #10 + 'hello';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'tag start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'tag directive rejected');
  Check(Pos('directives', S.Error.Message.ToString) > 0, 'tag diagnostic');
end;

procedure TestRejectsUnsupportedTags;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '!str hello';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'tag start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'root tag rejected');
  Check(Pos('tags', S.Error.Message.ToString) > 0, 'root tag diagnostic');

  LInput := 'name: !str hello';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'map tag start');
  LTok := S.NextToken; Check(LTok.Kind = ytkScalar, 'map key');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, 'map colon');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkError, 'map tag rejected');
  Check(Pos('tags', S.Error.Message.ToString) > 0, 'map tag diagnostic');
end;

procedure TestQuotedBangStringsRemainScalars;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '''!str hello''';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'single start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'single quoted bang string');
  Check(LTok.Style = yssSingleQuoted, 'single quoted style');
  Check(LTok.Value.ToString = '!str hello', 'single quoted value');

  LInput := '"!str hello"';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'double start');
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'double quoted bang string');
  Check(LTok.Style = yssDoubleQuoted, 'double quoted style');
  Check(LTok.Value.ToString = '!str hello', 'double quoted value');
end;

procedure TestNestedFlow;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '{a: [1, 2], b: {c: 3}}';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'start');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapStart, '{');
  LTok := S.NextToken; Check(LTok.Value.ToString = 'a', 'a');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, ':');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowSeqStart, '[');
  LTok := S.NextToken; Check(LTok.Value.ToString = '1', '1');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowEntry, ',');
  LTok := S.NextToken; Check(LTok.Value.ToString = '2', '2');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowSeqEnd, ']');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowEntry, ',');
  LTok := S.NextToken; Check(LTok.Value.ToString = 'b', 'b');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, ':');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapStart, '{');
  LTok := S.NextToken; Check(LTok.Value.ToString = 'c', 'c');
  LTok := S.NextToken; Check(LTok.Kind = ytkValue, ':');
  LTok := S.NextToken; Check(LTok.Value.ToString = '3', '3');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapEnd, '}');
  LTok := S.NextToken; Check(LTok.Kind = ytkFlowMapEnd, '} outer');
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamEnd, 'end');
end;

procedure TestBlockSeqIndicator;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := '- hello' + #10 + '- world';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamStart, 'start');
  LTok := S.NextToken; Check(LTok.Kind = ytkBlockSeqStart, '- 1');
  LTok := S.NextToken; Check(LTok.Value.ToString = 'hello', 'hello');
  LTok := S.NextToken; Check(LTok.Kind = ytkBlockSeqStart, '- 2');
  LTok := S.NextToken; Check(LTok.Value.ToString = 'world', 'world');
  LTok := S.NextToken; Check(LTok.Kind = ytkStreamEnd, 'end');
end;

procedure TestPlainScalarEdgeCases;
var
  S: TYamlScanner;
  LTok: TYamlToken;
  LInput: string;
begin
  LInput := 'hello:world';
  S.Init(@LInput[1], Length(LInput));
  LTok := S.NextToken; // stream start
  LTok := S.NextToken;
  Check(LTok.Kind = ytkScalar, 'colon in middle');
  Check(LTok.Value.ToString = 'hello:world', 'colon not separator');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml.scanner');
  T.Run('Stream start/end', @TestStreamStartEnd);
  T.Run('Flow mapping', @TestFlowMapping);
  T.Run('Flow sequence', @TestFlowSequence);
  T.Run('Single quoted', @TestSingleQuoted);
  T.Run('Double quoted', @TestDoubleQuoted);
  T.Run('Rejects invalid double-quoted escape',
    @TestRejectsInvalidDoubleQuotedEscape);
  T.Run('Comments', @TestComments);
  T.Run('Anchor/alias', @TestAnchorAlias);
  T.Run('Rejects empty anchor/alias names', @TestRejectsEmptyAnchorAliasNames);
  T.Run('Doc markers', @TestDocMarkers);
  T.Run('Rejects unsupported directives', @TestRejectsUnsupportedDirectives);
  T.Run('Rejects unsupported tags', @TestRejectsUnsupportedTags);
  T.Run('Quoted bang strings remain scalars', @TestQuotedBangStringsRemainScalars);
  T.Run('Nested flow', @TestNestedFlow);
  T.Run('Block seq indicator', @TestBlockSeqIndicator);
  T.Run('Plain scalar edge', @TestPlainScalarEdgeCases);
  T.Summary;
end.
