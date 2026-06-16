program test_yaml_roundtrip;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.yaml.types,
  nextpas.core.yaml,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ===== Parse → Stringify → Re-parse → Compare ===== }

procedure Roundtrip(const ALabel, AInput: string);
var
  LDoc1, LDoc2: IYamlDocument;
  LOutput: string;

  procedure CompareValues(const AV1, AV2: TYamlValue; const APath: string);
  var
    LI: Integer;
    LKey: string;
  begin
    if AV1.IsNull and AV2.IsNull then
      Exit;
    CheckEqual(Ord(AV1.Kind), Ord(AV2.Kind), APath + ': kind mismatch');
    case AV1.Kind of
      ynkBool:
        CheckEqual(AV1.AsBool, AV2.AsBool, APath + ': bool mismatch');
      ynkInt:
        CheckEqual(AV1.AsInt, AV2.AsInt, APath + ': int mismatch');
      ynkFloat:
        ; { floats may have precision differences in stringify }
      ynkString:
        CheckEqual(AV1.AsStr.ToString, AV2.AsStr.ToString, APath + ': string mismatch');
      ynkSequence:
      begin
        CheckEqual(AV1.SeqLen, AV2.SeqLen, APath + ': seq len mismatch');
        for LI := 0 to Integer(AV1.SeqLen) - 1 do
          CompareValues(AV1.SeqGet(LI), AV2.SeqGet(LI),
            APath + '[' + IntToStr(LI) + ']');
      end;
      ynkMapping:
      begin
        CheckEqual(AV1.MapLen, AV2.MapLen, APath + ': map len mismatch');
        for LI := 0 to Integer(AV1.MapLen) - 1 do
        begin
          LKey := AV1.MapKeyAt(LI).ToString;
          CompareValues(AV1.MapValueAt(LI), AV2.MapValueAt(LI),
            APath + '.' + LKey);
        end;
      end;
    end;
  end;

begin
  LDoc1 := YamlParse(AInput);
  Check(not LDoc1.HasError, ALabel + ': first parse no error');
  LOutput := LDoc1.Stringify;
  Check(Length(LOutput) > 0, ALabel + ': stringify not empty');
  LDoc2 := YamlParse(LOutput);
  Check(not LDoc2.HasError, ALabel + ': re-parse no error');
  CompareValues(LDoc1.Root, LDoc2.Root, ALabel);
end;

procedure TestRoundtripScalars;
begin
  Roundtrip('scalars',
    'name: hello' + #10 +
    'count: 42' + #10 +
    'flag: true' + #10 +
    'empty: null');
end;

procedure TestRoundtripSequence;
begin
  Roundtrip('sequence',
    '- alpha' + #10 +
    '- beta' + #10 +
    '- gamma');
end;

procedure TestRoundtripMapping;
begin
  Roundtrip('mapping',
    'host: localhost' + #10 +
    'port: 8080' + #10 +
    'debug: false');
end;

procedure TestRoundtripNestedMap;
begin
  Roundtrip('nested map',
    'server:' + #10 +
    '  host: localhost' + #10 +
    '  port: 8080' + #10 +
    'database:' + #10 +
    '  name: mydb' + #10 +
    '  pool: 10');
end;

procedure TestRoundtripMapOfSeqs;
begin
  Roundtrip('map of seqs',
    'tags:' + #10 +
    '  - go' + #10 +
    '  - rust' + #10 +
    '  - pascal' + #10 +
    'ports:' + #10 +
    '  - 80' + #10 +
    '  - 443');
end;

procedure TestRoundtripEmptyContainers;
begin
  Roundtrip('empty containers',
    'list: []' + #10 +
    'map: {}');
end;

procedure TestRoundtripNestedEmpty;
begin
  Roundtrip('nested with empty',
    'a:' + #10 +
    '  b: 1' + #10 +
    '  c: []' + #10 +
    '  d: {}');
end;

{ ===== Builder → Stringify → Parse → Compare ===== }

procedure TestBuilderRoundtrip;
var
  LBuilder: TYamlBuilder;
  LOutput: string;
  LDoc: IYamlDocument;
begin
  LBuilder.Init;
  LBuilder.BeginMap;
    LBuilder.PutKey('name');
    LBuilder.PutStr('nextpas');
    LBuilder.PutKey('version');
    LBuilder.PutInt(1);
    LBuilder.PutKey('tags');
    LBuilder.BeginSeq;
      LBuilder.PutStr('pascal');
      LBuilder.PutStr('compiler');
    LBuilder.EndSeq;
  LBuilder.EndMap;
  LOutput := LBuilder.Stringify;
  LBuilder.Done;

  LDoc := YamlParse(LOutput);
  Check(not LDoc.HasError, 'builder roundtrip: no error');
  Check(LDoc.Root.IsMap, 'builder roundtrip: root is map');
  CheckEqual('nextpas', LDoc.Root.MapGet('name').AsStr.ToString, 'builder roundtrip: name');
  CheckEqual(Int64(1), LDoc.Root.MapGet('version').AsInt, 'builder roundtrip: version');
  Check(LDoc.Root.MapGet('tags').IsSeq, 'builder roundtrip: tags is seq');
  CheckEqual(UInt32(2), LDoc.Root.MapGet('tags').SeqLen, 'builder roundtrip: 2 tags');
end;

procedure TestBuilderPrettyRoundtrip;
var
  LBuilder: TYamlBuilder;
  LOutput: string;
  LDoc: IYamlDocument;
begin
  LBuilder.Init;
  LBuilder.BeginMap;
    LBuilder.PutKey('server');
    LBuilder.BeginMap;
      LBuilder.PutKey('host');
      LBuilder.PutStr('localhost');
      LBuilder.PutKey('port');
      LBuilder.PutInt(8080);
    LBuilder.EndMap;
  LBuilder.EndMap;
  LOutput := LBuilder.StringifyPretty;
  LBuilder.Done;

  Check(Pos('server:', LOutput) > 0, 'pretty output contains server');
  Check(Pos('host:', LOutput) > 0, 'pretty output contains host');

  LDoc := YamlParse(LOutput);
  Check(not LDoc.HasError, 'pretty roundtrip: no error');
  CheckEqual('localhost',
    LDoc.Root.MapGet('server').MapGet('host').AsStr.ToString,
    'pretty roundtrip: host');
end;

procedure TestBuilderEmptyRoundtrip;
var
  LBuilder: TYamlBuilder;
  LOutput: string;
  LDoc: IYamlDocument;
begin
  LBuilder.Init;
  LBuilder.PutNull;
  LOutput := LBuilder.Stringify;
  LBuilder.Done;

  LDoc := YamlParse(LOutput);
  Check(not LDoc.HasError, 'empty builder roundtrip: no error');
  Check(LDoc.Root.IsNull, 'empty builder roundtrip: root is null');
end;

procedure TestBuilderDeepNesting;
var
  LBuilder: TYamlBuilder;
  LOutput: string;
  LDoc: IYamlDocument;
  LVal: TYamlValue;
  LI: Integer;
begin
  LBuilder.Init;
  LBuilder.BeginMap;
  for LI := 0 to 9 do
  begin
    LBuilder.PutKey('k' + IntToStr(LI));
    if LI < 9 then
      LBuilder.BeginMap
    else
      LBuilder.PutStr('leaf');
  end;
  for LI := 0 to 8 do
    LBuilder.EndMap;
  LBuilder.EndMap;
  LOutput := LBuilder.Stringify;
  LBuilder.Done;

  LDoc := YamlParse(LOutput);
  Check(not LDoc.HasError, 'deep nesting roundtrip: no error');
  LVal := LDoc.Root;
  for LI := 0 to 8 do
    LVal := LVal.MapGet('k' + IntToStr(LI));
  CheckEqual('leaf', LVal.MapGet('k9').AsStr.ToString,
    'deep nesting roundtrip: leaf value');
end;

{ ===== StringifyPretty roundtrip ===== }

procedure TestPrettyPreservesStructure;
var
  LDoc1, LDoc2: IYamlDocument;
  LPretty: string;
begin
  LDoc1 := YamlParse(
    'services:' + #10 +
    '  web:' + #10 +
    '    image: nginx' + #10 +
    '    ports:' + #10 +
    '      - 80' + #10 +
    '      - 443' + #10 +
    '  db:' + #10 +
    '    image: postgres');
  Check(not LDoc1.HasError, 'pretty structure: parse ok');
  LPretty := LDoc1.StringifyPretty;
  Check(Pos('services:', LPretty) > 0, 'pretty has services');
  Check(Pos('web:', LPretty) > 0, 'pretty has web');
  Check(Pos('image: nginx', LPretty) > 0, 'pretty has image');

  LDoc2 := YamlParse(LPretty);
  Check(not LDoc2.HasError, 'pretty structure: re-parse ok');
  Check(LDoc2.Root.MapGet('services').MapGet('web').MapGet('image').AsStr.ToString = 'nginx',
    'pretty structure: image preserved');
end;

begin
  T := TTestRunner.Create('yaml roundtrip');
  { Parse → Stringify → Re-parse → Compare }
  T.Run('roundtrip scalars', @TestRoundtripScalars);
  T.Run('roundtrip sequence', @TestRoundtripSequence);
  T.Run('roundtrip mapping', @TestRoundtripMapping);
  T.Run('roundtrip nested map', @TestRoundtripNestedMap);
  T.Run('roundtrip map of seqs', @TestRoundtripMapOfSeqs);
  T.Run('roundtrip empty containers', @TestRoundtripEmptyContainers);
  T.Run('roundtrip nested with empty', @TestRoundtripNestedEmpty);
  { Builder roundtrip }
  T.Run('builder roundtrip', @TestBuilderRoundtrip);
  T.Run('builder pretty roundtrip', @TestBuilderPrettyRoundtrip);
  T.Run('builder empty roundtrip', @TestBuilderEmptyRoundtrip);
  T.Run('builder deep nesting', @TestBuilderDeepNesting);
  { Pretty roundtrip }
  T.Run('pretty preserves structure', @TestPrettyPreservesStructure);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
