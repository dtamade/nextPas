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

begin
  T := TTestRunner.Create('nextpas.core.yaml.block');
  T.Run('Block mapping', @TestBlockMapping);
  T.Run('Block sequence', @TestBlockSequence);
  T.Run('Block mapping with seq value', @TestBlockMappingWithSeqValue);
  T.Run('Block nested mapping', @TestBlockNestedMapping);
  T.Run('Block scalar literal', @TestBlockScalarLiteral);
  T.Run('Mixed flow and block', @TestMixedFlowAndBlock);
  T.Summary;
end.
