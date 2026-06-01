program test_yaml_block;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml;

var
  T: TTestRunner;

procedure TestBlockMapping;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'name: Alice' + #10 + 'age: 30';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  CheckEqual(Int64(2), Int64(LRoot.MapLen), 'len=2');
  Check(LRoot.MapGet('name').AsStr.ToString = 'Alice', 'name=Alice');
  CheckEqual(Int64(30), LRoot.MapGet('age').AsInt, 'age=30');
end;

procedure TestBlockSequence;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := '- apple' + #10 + '- banana' + #10 + '- cherry';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsSeq, 'is seq');
  CheckEqual(Int64(3), Int64(LRoot.SeqLen), 'len=3');
  Check(LRoot.SeqGet(0).AsStr.ToString = 'apple', '[0]=apple');
  Check(LRoot.SeqGet(1).AsStr.ToString = 'banana', '[1]=banana');
  Check(LRoot.SeqGet(2).AsStr.ToString = 'cherry', '[2]=cherry');
end;

procedure TestBlockMappingWithSeqValue;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'fruits:' + #10 + '  - apple' + #10 + '  - banana' + #10 + 'count: 2';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  Check(LRoot.MapGet('fruits').IsSeq, 'fruits is seq');
  CheckEqual(Int64(2), Int64(LRoot.MapGet('fruits').SeqLen), 'fruits len');
  Check(LRoot.MapGet('fruits').SeqGet(0).AsStr.ToString = 'apple', 'fruits[0]');
  CheckEqual(Int64(2), LRoot.MapGet('count').AsInt, 'count=2');
end;

procedure TestBlockNestedMapping;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'server:' + #10 + '  host: localhost' + #10 + '  port: 8080';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'root is map');
  Check(LRoot.MapGet('server').IsMap, 'server is map');
  Check(LRoot.MapGet('server').MapGet('host').AsStr.ToString = 'localhost', 'host');
  CheckEqual(Int64(8080), LRoot.MapGet('server').MapGet('port').AsInt, 'port');
end;

procedure TestBlockScalarLiteral;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'desc: |' + #10 + '  line1' + #10 + '  line2';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  Check(LRoot.MapGet('desc').IsStr, 'desc is str');
end;

procedure TestMixedFlowAndBlock;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'name: Alice' + #10 + 'tags: [dev, ops]';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  Check(LRoot.MapGet('name').AsStr.ToString = 'Alice', 'name');
  Check(LRoot.MapGet('tags').IsSeq, 'tags is seq');
  CheckEqual(Int64(2), Int64(LRoot.MapGet('tags').SeqLen), 'tags len');
  Check(LRoot.MapGet('tags').SeqGet(0).AsStr.ToString = 'dev', 'tags[0]');
end;

procedure TestBlockScalarFolded;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'desc: >' + #10 + '  line1' + #10 + '  line2';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('desc').IsStr, 'desc is str');
end;

procedure TestBlockScalarLiteralStrip;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput, LVal: string;
begin
  LInput := 'text: |-' + #10 + '  hello' + #10 + '  world' + #10;
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  LVal := LRoot.MapGet('text').AsStr.ToString;
  Check(Length(LVal) > 0, 'has content');
  Check(LVal[Length(LVal)] <> #10, 'strip removes trailing newline');
end;

procedure TestBlockScalarLiteralKeep;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput, LVal: string;
begin
  LInput := 'text: |+' + #10 + '  hello' + #10 + #10;
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  LVal := LRoot.MapGet('text').AsStr.ToString;
  Check(Length(LVal) > 0, 'has content');
end;

procedure TestDocumentMarkers;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := '---' + #10 + 'name: Alice' + #10 + '...';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  Check(LRoot.MapGet('name').AsStr.ToString = 'Alice', 'name=Alice');
end;

procedure TestBlockSeqOfMappings;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := '- name: Alice' + #10 + '  age: 30' + #10 + '- name: Bob' + #10 + '  age: 25';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.IsSeq, 'is seq');
  CheckEqual(Int64(2), Int64(LRoot.SeqLen), 'len=2');
  Check(LRoot.SeqGet(0).IsMap, '[0] is map');
  Check(LRoot.SeqGet(0).MapGet('name').AsStr.ToString = 'Alice', '[0].name');
  CheckEqual(Int64(25), LRoot.SeqGet(1).MapGet('age').AsInt, '[1].age');
end;

procedure TestCommentsInBlock;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := '# top comment' + #10 + 'name: Alice # inline' + #10 + '# between' + #10 + 'age: 30';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  Check(LRoot.MapGet('name').AsStr.ToString = 'Alice', 'name');
  CheckEqual(Int64(30), LRoot.MapGet('age').AsInt, 'age');
end;

procedure TestEmptyValuesInBlock;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'a: null' + #10 + 'b: ~' + #10 + 'c: ""';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'is map');
  Check(LRoot.MapGet('a').IsNull, 'a is null');
  Check(LRoot.MapGet('b').IsNull, 'b is null');
  Check(LRoot.MapGet('c').AsStr.ToString = '', 'c is empty str');
end;

procedure TestNestedBlockSequences;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'items:' + #10 + '  - a' + #10 + '  - b' + #10 + '  - c';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('items').IsSeq, 'items is seq');
  CheckEqual(Int64(3), Int64(LRoot.MapGet('items').SeqLen), 'items len=3');
  Check(LRoot.MapGet('items').SeqGet(2).AsStr.ToString = 'c', 'items[2]=c');
end;

procedure TestMultiLevelIndent;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'a:' + #10 + '  b:' + #10 + '    c:' + #10 + '      d: deep';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('a').MapGet('b').MapGet('c').MapGet('d').AsStr.ToString = 'deep', 'deep val');
end;

procedure TestBooleanValues;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'a: true' + #10 + 'b: false' + #10 + 'c: yes' + #10 + 'd: no';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('a').AsBool = True, 'a=true');
  Check(LRoot.MapGet('b').AsBool = False, 'b=false');
end;

procedure TestNullValues;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'a: null' + #10 + 'b: ~' + #10 + 'c:';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('a').IsNull, 'a is null');
  Check(LRoot.MapGet('b').IsNull, 'b is null');
  Check(LRoot.MapGet('c').IsNull, 'c is null');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml.block');
  T.Run('Block mapping', @TestBlockMapping);
  T.Run('Block sequence', @TestBlockSequence);
  T.Run('Block mapping with seq value', @TestBlockMappingWithSeqValue);
  T.Run('Block nested mapping', @TestBlockNestedMapping);
  T.Run('Block scalar literal', @TestBlockScalarLiteral);
  T.Run('Mixed flow and block', @TestMixedFlowAndBlock);
  T.Run('Block scalar folded', @TestBlockScalarFolded);
  T.Run('Block scalar literal strip', @TestBlockScalarLiteralStrip);
  T.Run('Block scalar literal keep', @TestBlockScalarLiteralKeep);
  T.Run('Document markers', @TestDocumentMarkers);
  T.Run('Block seq of mappings', @TestBlockSeqOfMappings);
  T.Run('Comments in block', @TestCommentsInBlock);
  T.Run('Empty values in block', @TestEmptyValuesInBlock);
  T.Run('Nested block sequences', @TestNestedBlockSequences);
  T.Run('Multi-level indent', @TestMultiLevelIndent);
  T.Run('Boolean values', @TestBooleanValues);
  T.Run('Null values', @TestNullValues);
  T.Summary;
end.
