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
  T.Run('Comments', @TestComments);
  T.Run('Anchor/alias', @TestAnchorAlias);
  T.Run('Doc markers', @TestDocMarkers);
  T.Run('Nested flow', @TestNestedFlow);
  T.Run('Block seq indicator', @TestBlockSeqIndicator);
  T.Run('Plain scalar edge', @TestPlainScalarEdgeCases);
  T.Summary;
end.
