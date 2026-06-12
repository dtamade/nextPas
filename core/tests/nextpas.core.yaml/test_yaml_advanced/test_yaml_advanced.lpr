program test_yaml_advanced;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml;

var
  T: TTestRunner;

{ P7: Anchors and Aliases }

procedure TestAnchorAlias;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := '{defaults: &def {timeout: 30}, server: *def}';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.IsMap, 'root is map');
  CheckEqual(Int64(30), LRoot.MapGet('defaults').MapGet('timeout').AsInt, 'defaults.timeout');
  CheckEqual(Int64(30), LRoot.MapGet('server').MapGet('timeout').AsInt, 'alias resolves');
end;

procedure TestAnchorScalar;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := '{name: &n Alice, greeting: *n}';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('name').AsStr.ToString = 'Alice', 'anchor value');
  Check(LRoot.MapGet('greeting').AsStr.ToString = 'Alice', 'alias value');
end;

procedure TestUndefinedAlias;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{a: *missing}');
  Check(LDoc.HasError, 'undefined alias error');
end;

{ P6: Block scalar styles }

procedure TestBlockLiteral;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'text: |' + #10 + '  hello' + #10 + '  world';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('text').IsStr, 'is str');
  Check(Length(LRoot.MapGet('text').AsStr.ToString) > 0, 'has content');
end;

procedure TestBlockFolded;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LInput: string;
begin
  LInput := 'text: >' + #10 + '  hello' + #10 + '  world';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('text').IsStr, 'is str');
end;

{ P8: Document markers }

procedure TestRejectsMultiDoc;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput := '---' + #10 + 'hello' + #10 + '---' + #10 + 'world';
  LDoc := YamlParse(LInput);
  Check(LDoc.HasError, 'multiple documents are rejected');
  Check(Pos('multiple YAML documents', LDoc.Error.Message.ToString) > 0,
    'multiple document diagnostic');
end;

procedure TestDocEnd;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput := '---' + #10 + '{a: 1}' + #10 + '...';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.IsMap, 'is map');
  CheckEqual(Int64(1), LDoc.Root.MapGet('a').AsInt, 'a=1');
end;

{ Edge cases }

procedure TestEmptyMapping;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('{}');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.IsMap, 'is map');
  CheckEqual(Int64(0), Int64(LDoc.Root.MapLen), 'empty');
end;

procedure TestEmptySequence;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('[]');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.IsSeq, 'is seq');
  CheckEqual(Int64(0), Int64(LDoc.Root.SeqLen), 'empty');
end;

procedure TestTrailingComma;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('[1, 2, 3,]');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(3), Int64(LDoc.Root.SeqLen), 'trailing comma ok');
end;

procedure TestHexOctalInt;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('0xFF');
  Check(LDoc.Root.IsInt, 'hex is int');
  CheckEqual(Int64(255), LDoc.Root.AsInt, '0xFF=255');

  LDoc := YamlParse('0o77');
  Check(LDoc.Root.IsInt, 'oct is int');
  CheckEqual(Int64(63), LDoc.Root.AsInt, '0o77=63');
end;

procedure TestSpecialFloats;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('.nan');
  Check(LDoc.Root.IsFloat, 'nan is float');

  LDoc := YamlParse('.inf');
  Check(LDoc.Root.IsFloat, 'inf is float');
  Check(LDoc.Root.AsFloat > 1e300, '+inf');

  LDoc := YamlParse('-.inf');
  Check(LDoc.Root.AsFloat < -1e300, '-inf');
end;

procedure TestQuotedStringsNotResolved;
var
  LDoc: IYamlDocument;
begin
  LDoc := YamlParse('''true''');
  Check(LDoc.Root.IsStr, 'quoted true is str');
  Check(LDoc.Root.AsStr.ToString = 'true', 'value=true');

  LDoc := YamlParse('"null"');
  Check(LDoc.Root.IsStr, 'quoted null is str');
  Check(LDoc.Root.AsStr.ToString = 'null', 'value=null');

  LDoc := YamlParse('''123''');
  Check(LDoc.Root.IsStr, 'quoted 123 is str');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml.advanced');
  T.Run('Anchor/alias mapping', @TestAnchorAlias);
  T.Run('Anchor/alias scalar', @TestAnchorScalar);
  T.Run('Undefined alias', @TestUndefinedAlias);
  T.Run('Block literal', @TestBlockLiteral);
  T.Run('Block folded', @TestBlockFolded);
  T.Run('Rejects multi-doc', @TestRejectsMultiDoc);
  T.Run('Doc end marker', @TestDocEnd);
  T.Run('Empty mapping', @TestEmptyMapping);
  T.Run('Empty sequence', @TestEmptySequence);
  T.Run('Trailing comma', @TestTrailingComma);
  T.Run('Hex/octal int', @TestHexOctalInt);
  T.Run('Special floats', @TestSpecialFloats);
  T.Run('Quoted not resolved', @TestQuotedStringsNotResolved);
  T.Summary;
end.
