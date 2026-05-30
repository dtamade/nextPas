program test_yaml_coverage;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.yaml.types,
  nextpas.core.yaml.builder,
  nextpas.core.yaml;

var
  T: TTestRunner;

{ API coverage: PutFloat, PutStrView, YamlParse(TStringView) }

procedure TestPutFloat;
var
  LB: TYamlBuilder;
  LDoc: IYamlDocument;
  LOut: string;
begin
  LB.Init;
  LB.PutFloat(3.14);
  LOut := LB.Stringify;
  LB.Done;
  LDoc := YamlParse(LOut);
  Check(LDoc.Root.IsFloat, 'float parsed');
  Check(Abs(LDoc.Root.AsFloat - 3.14) < 0.01, 'float value');
end;

procedure TestPutStrView;
var
  LB: TYamlBuilder;
  LOut: string;
  LView: TStringView;
  LStr: string;
begin
  LStr := 'hello from view';
  LView := TStringView.FromStr(LStr);
  LB.Init;
  LB.PutStrView(LView);
  LOut := LB.Stringify;
  LB.Done;
  Check(Pos('hello from view', LOut) > 0, 'strview output');
end;

procedure TestParseStringView;
var
  LDoc: IYamlDocument;
  LInput: string;
  LView: TStringView;
begin
  LInput := '{x: 42}';
  LView := TStringView.FromStr(LInput);
  LDoc := YamlParse(LView);
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(42), LDoc.Root.MapGet('x').AsInt, 'x=42');
end;

{ Real-world YAML scenarios }

procedure TestK8sPodSpec;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput :=
    'apiVersion: v1' + #10 +
    'kind: Pod' + #10 +
    'metadata:' + #10 +
    '  name: nginx' + #10 +
    '  labels:' + #10 +
    '    app: nginx' + #10 +
    'spec:' + #10 +
    '  containers:' + #10 +
    '    - name: nginx' + #10 +
    '      image: nginx:latest' + #10 +
    '      ports:' + #10 +
    '        - containerPort: 80';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'k8s no error');
  Check(LDoc.Root.IsMap, 'root is map');
  Check(LDoc.Root.MapGet('apiVersion').AsStr.ToString = 'v1', 'apiVersion');
  Check(LDoc.Root.MapGet('kind').AsStr.ToString = 'Pod', 'kind');
  Check(LDoc.Root.MapGet('metadata').MapGet('name').AsStr.ToString = 'nginx', 'metadata.name');
  Check(LDoc.Root.MapGet('metadata').MapGet('labels').MapGet('app').AsStr.ToString = 'nginx', 'labels.app');
end;

procedure TestDockerCompose;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput :=
    'version: "3.8"' + #10 +
    'services:' + #10 +
    '  web:' + #10 +
    '    image: nginx' + #10 +
    '    ports:' + #10 +
    '      - "80:80"' + #10 +
    '  db:' + #10 +
    '    image: postgres' + #10 +
    '    environment:' + #10 +
    '      POSTGRES_DB: mydb';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'compose no error');
  Check(LDoc.Root.MapGet('version').AsStr.ToString = '3.8', 'version');
  Check(LDoc.Root.MapGet('services').IsMap, 'services is map');
  Check(LDoc.Root.MapGet('services').MapGet('web').MapGet('image').AsStr.ToString = 'nginx', 'web.image');
  Check(LDoc.Root.MapGet('services').MapGet('db').MapGet('image').AsStr.ToString = 'postgres', 'db.image');
end;

procedure TestGitHubActions;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput :=
    'name: CI' + #10 +
    'on: [push, pull_request]' + #10 +
    'jobs:' + #10 +
    '  build:' + #10 +
    '    runs-on: ubuntu-latest' + #10 +
    '    steps:' + #10 +
    '      - uses: actions/checkout@v4' + #10 +
    '      - name: Build' + #10 +
    '        run: make build';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'gh actions no error');
  Check(LDoc.Root.MapGet('name').AsStr.ToString = 'CI', 'name=CI');
  Check(LDoc.Root.MapGet('on').IsSeq, 'on is seq');
  CheckEqual(Int64(2), Int64(LDoc.Root.MapGet('on').SeqLen), 'on len=2');
  Check(LDoc.Root.MapGet('jobs').MapGet('build').MapGet('runs-on').AsStr.ToString = 'ubuntu-latest', 'runs-on');
end;

procedure TestConfigFile;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput :=
    '# Application config' + #10 +
    'server:' + #10 +
    '  host: 0.0.0.0' + #10 +
    '  port: 8080' + #10 +
    '  debug: false' + #10 +
    'database:' + #10 +
    '  url: "postgres://localhost/mydb"' + #10 +
    '  pool_size: 10' + #10 +
    '  timeout: 30.5';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'config no error');
  Check(LDoc.Root.MapGet('server').MapGet('host').AsStr.ToString = '0.0.0.0', 'host');
  CheckEqual(Int64(8080), LDoc.Root.MapGet('server').MapGet('port').AsInt, 'port');
  Check(LDoc.Root.MapGet('server').MapGet('debug').AsBool = False, 'debug');
  CheckEqual(Int64(10), LDoc.Root.MapGet('database').MapGet('pool_size').AsInt, 'pool_size');
  Check(Abs(LDoc.Root.MapGet('database').MapGet('timeout').AsFloat - 30.5) < 0.01, 'timeout');
end;

procedure TestMultilineValues;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput :=
    'simple: hello world' + #10 +
    'quoted: "with \"escape\""' + #10 +
    'single: ''no escape''';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'multiline no error');
  Check(LDoc.Root.MapGet('simple').AsStr.ToString = 'hello world', 'simple');
  Check(LDoc.Root.MapGet('single').AsStr.ToString = 'no escape', 'single');
end;

procedure TestComplexNesting;
var
  LDoc: IYamlDocument;
  LInput: string;
begin
  LInput := '{a: {b: {c: [1, {d: true}, [2, 3]]}}}';
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'complex no error');
  Check(LDoc.Root.MapGet('a').MapGet('b').MapGet('c').IsSeq, 'c is seq');
  CheckEqual(Int64(3), Int64(LDoc.Root.MapGet('a').MapGet('b').MapGet('c').SeqLen), 'c len');
  CheckEqual(Int64(1), LDoc.Root.MapGet('a').MapGet('b').MapGet('c').SeqGet(0).AsInt, 'c[0]');
  Check(LDoc.Root.MapGet('a').MapGet('b').MapGet('c').SeqGet(1).MapGet('d').AsBool, 'c[1].d');
end;

begin
  T := TTestRunner.Create('nextpas.core.yaml.coverage');
  T.Run('PutFloat', @TestPutFloat);
  T.Run('PutStrView', @TestPutStrView);
  T.Run('Parse TStringView', @TestParseStringView);
  T.Run('K8s pod spec', @TestK8sPodSpec);
  T.Run('Docker compose', @TestDockerCompose);
  T.Run('GitHub Actions', @TestGitHubActions);
  T.Run('Config file', @TestConfigFile);
  T.Run('Multiline values', @TestMultilineValues);
  T.Run('Complex nesting', @TestComplexNesting);
  T.Summary;
end.
