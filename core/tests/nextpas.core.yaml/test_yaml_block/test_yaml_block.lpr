program test_yaml_block;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml;

var
  T: TTestSuite;

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

procedure TestSeqOfMapsWithNestedSeq;
var
  LDoc: IYamlDocument;
  LRoot, LItem0, LItem1, LItems, LChild: TYamlValue;
  LInput: string;
  LWalk: Integer;
begin
  { Nested seq-of-maps whose items themselves contain a seq. The second
    outer '-' is indented; a scanner that clears line-start on indent
    spaces would roll it into the first item's nested seq. }
  LInput :=
    'weights:' + #10 +
    '  - task: latency' + #10 +
    '    items:' + #10 +
    '      - domain: example.com' + #10 +
    '        weight: 2' + #10 +
    '      - domain: foo.com' + #10 +
    '        weight: 1' + #10 +
    '  - task: dns' + #10 +
    '    items:' + #10 +
    '      - domain: bar.com' + #10 +
    '        weight: 3' + #10;
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error: ' + LDoc.Error.Message.ToString);
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'root map');
  CheckEqual(Int64(2), Int64(LRoot.MapGet('weights').SeqLen), 'outer seq len=2');
  LItem0 := LRoot.MapGet('weights').SeqGet(0);
  LItem1 := LRoot.MapGet('weights').SeqGet(1);
  Check(LItem0.IsMap, '[0] is map');
  Check(LItem1.IsMap, '[1] is map');
  CheckEqual('latency', LItem0.MapGet('task').AsStr.ToString, '[0].task');
  CheckEqual('dns', LItem1.MapGet('task').AsStr.ToString, '[1].task');
  CheckEqual(Int64(2), Int64(LItem0.MapGet('items').SeqLen), '[0].items len=2');
  CheckEqual(Int64(1), Int64(LItem1.MapGet('items').SeqLen), '[1].items len=1');
  CheckEqual('example.com',
    LItem0.MapGet('items').SeqGet(0).MapGet('domain').AsStr.ToString, '[0].items[0]');
  CheckEqual('foo.com',
    LItem0.MapGet('items').SeqGet(1).MapGet('domain').AsStr.ToString, '[0].items[1]');
  CheckEqual('bar.com',
    LItem1.MapGet('items').SeqGet(0).MapGet('domain').AsStr.ToString, '[1].items[0]');
  CheckEqual(Int64(3), LItem1.MapGet('items').SeqGet(0).MapGet('weight').AsInt,
    '[1].items[0].weight');

  LItems := LRoot.MapGet('weights');
  LChild := LItems.FirstChild;
  LWalk := 0;
  while LChild.IsValid do
  begin
    Inc(LWalk);
    LChild := LChild.NextSibling;
  end;
  CheckEqual(Int64(2), Int64(LWalk), 'FirstChild/NextSibling walk matches SeqLen');
end;

begin
  T := TTestSuite.Create('nextpas.core.yaml.block');
  T.Test('Block mapping', @TestBlockMapping);
  T.Test('Block sequence', @TestBlockSequence);
  T.Test('Block mapping with seq value', @TestBlockMappingWithSeqValue);
  T.Test('Block nested mapping', @TestBlockNestedMapping);
  T.Test('Block scalar literal', @TestBlockScalarLiteral);
  T.Test('Mixed flow and block', @TestMixedFlowAndBlock);
  T.Test('Block scalar folded', @TestBlockScalarFolded);
  T.Test('Block scalar literal strip', @TestBlockScalarLiteralStrip);
  T.Test('Block scalar literal keep', @TestBlockScalarLiteralKeep);
  T.Test('Document markers', @TestDocumentMarkers);
  T.Test('Block seq of mappings', @TestBlockSeqOfMappings);
  T.Test('Comments in block', @TestCommentsInBlock);
  T.Test('Empty values in block', @TestEmptyValuesInBlock);
  T.Test('Nested block sequences', @TestNestedBlockSequences);
  T.Test('Multi-level indent', @TestMultiLevelIndent);
  T.Test('Boolean values', @TestBooleanValues);
  T.Test('Null values', @TestNullValues);
  T.Test('Seq of maps with nested seq', @TestSeqOfMapsWithNestedSeq);
  if not T.Run then Halt(1);
end.
