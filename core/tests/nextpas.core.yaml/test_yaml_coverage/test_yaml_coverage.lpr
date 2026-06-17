program test_yaml_coverage;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Classes,
  nextpas.core.testing,
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.yaml.types,
  nextpas.core.yaml.parser,
  nextpas.core.yaml.builder,
  nextpas.core.yaml;

var
  T: TTestRunner;

const
  YAML_PARSER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.yaml.parser.pas';
  YAML_PARSER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.yaml.parser.pas';

type
  TFailingReallocateAllocator = class(TInterfacedObject, IAllocator)
  private
    FFailOnReallocateCall: SizeUInt;
    FReallocateCalls: SizeUInt;
  public
    constructor Create(const AFailOnReallocateCall: SizeUInt);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

  TFailingAllocateAllocator = class(TInterfacedObject, IAllocator)
  private
    FFailOnAllocateCall: SizeUInt;
    FAllocateCalls: SizeUInt;
  public
    constructor Create(const AFailOnAllocateCall: SizeUInt);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

  TCountingAllocator = class(TInterfacedObject, IAllocator)
  private
    FAllocations: SizeUInt;
    FDeallocations: SizeUInt;
  public
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
    function OutstandingAllocations: SizeUInt;
  end;

constructor TFailingReallocateAllocator.Create(const AFailOnReallocateCall: SizeUInt);
begin
  inherited Create;
  FFailOnReallocateCall := AFailOnReallocateCall;
  FReallocateCalls := 0;
end;

function TFailingReallocateAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := System.GetMem(aSize);
end;

function TFailingReallocateAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := System.AllocMem(aSize);
end;

function TFailingReallocateAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Inc(FReallocateCalls);
  if (FFailOnReallocateCall > 0) and (FReallocateCalls = FFailOnReallocateCall) then
    Exit(nil);
  Result := System.ReallocMem(aDst, aSize);
end;

procedure TFailingReallocateAllocator.FreeMem(aDst: Pointer);
begin
  if aDst <> nil then
    System.FreeMem(aDst);
end;

function TFailingReallocateAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TFailingReallocateAllocator.AllocAligned(aSize,
  aAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

procedure TFailingReallocateAllocator.FreeAligned(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

function TFailingReallocateAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

constructor TFailingAllocateAllocator.Create(const AFailOnAllocateCall: SizeUInt);
begin
  inherited Create;
  FFailOnAllocateCall := AFailOnAllocateCall;
  FAllocateCalls := 0;
end;

function TFailingAllocateAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Inc(FAllocateCalls);
  if (FFailOnAllocateCall > 0) and (FAllocateCalls = FFailOnAllocateCall) then
    Exit(nil);
  Result := System.GetMem(aSize);
end;

function TFailingAllocateAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Inc(FAllocateCalls);
  if (FFailOnAllocateCall > 0) and (FAllocateCalls = FFailOnAllocateCall) then
    Exit(nil);
  Result := System.AllocMem(aSize);
end;

function TFailingAllocateAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Result := System.ReallocMem(aDst, aSize);
end;

procedure TFailingAllocateAllocator.FreeMem(aDst: Pointer);
begin
  if aDst <> nil then
    System.FreeMem(aDst);
end;

function TFailingAllocateAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TFailingAllocateAllocator.AllocAligned(aSize,
  aAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

procedure TFailingAllocateAllocator.FreeAligned(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

function TFailingAllocateAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

function TCountingAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := System.GetMem(aSize);
  Inc(FAllocations);
end;

function TCountingAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := System.AllocMem(aSize);
  Inc(FAllocations);
end;

function TCountingAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Result := System.ReallocMem(aDst, aSize);
end;

procedure TCountingAllocator.FreeMem(aDst: Pointer);
begin
  if aDst <> nil then
  begin
    System.FreeMem(aDst);
    Inc(FDeallocations);
  end;
end;

function TCountingAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TCountingAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

procedure TCountingAllocator.FreeAligned(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

function TCountingAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

function TCountingAllocator.OutstandingAllocations: SizeUInt;
begin
  Result := FAllocations - FDeallocations;
end;

function ReadSourceFile(const APath: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(APath);
    Result := LowerCase(LText.Text);
  finally
    LText.Free;
  end;
end;

function ResolveSourcePath(const APathFromTest: string;
  const APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckSourceContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(LowerCase(ANeedle), ASource) > 0, AMessage);
end;

procedure CheckSourceAbsent(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(LowerCase(ANeedle), ASource) = 0, AMessage);
end;

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

procedure TestParserAllocatorSurface;
var
  LDoc: TYamlDocument;
  LInput: string;
begin
  YamlDocInitWith(LDoc, DefaultAllocator);
  Check(LDoc.Allocator <> nil, 'init sets allocator');
  CheckEqual(Int64(0), Int64(LDoc.NodeCount()), 'init node count');
  CheckEqual(Int64(0), Int64(LDoc.AnchorCount()), 'init anchor count');
  LDoc.Done;
  CheckEqual(Int64(0), Int64(LDoc.NodeCount()), 'done clears node count');
  CheckEqual(Int64(0), Int64(LDoc.AnchorCount()), 'done clears anchor count');

  LInput := '{svc: api, port: 8080}';
  YamlDocParseWith(LDoc, @LInput[1], Length(LInput), DefaultAllocator);
  try
    Check(not LDoc.HasError(), 'parse with allocator');
    Check(LDoc.NodeCount() > 0, 'parse keeps node surface');
    CheckEqual(Int64(2), Int64(LDoc.Node(LDoc.Root())^.Container.Count), 'root pair count');
  finally
    LDoc.Done;
  end;

  LInput := '[1, 2, 3]';
  YamlDocParseViewWith(LDoc, TStringView.FromStr(LInput), DefaultAllocator);
  try
    Check(not LDoc.HasError(), 'parse view with allocator');
    Check(LDoc.Node(LDoc.Root())^.Kind = ynkSequence, 'root sequence');
    CheckEqual(Int64(3), Int64(LDoc.Node(LDoc.Root())^.Container.Count), 'sequence len');
  finally
    LDoc.Done;
  end;
end;

procedure TestParserSourceTracksPrivateSurfaceAndOOMGuards;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(
    YAML_PARSER_SOURCE_PATH_FROM_TEST,
    YAML_PARSER_SOURCE_PATH_FROM_ROOT));
  CheckSourceContains(LSource, 'tyamldocument = record',
    'parser exposes TYamlDocument record');
  CheckSourceContains(LSource, 'private',
    'document record must declare a private section');
  CheckSourceContains(LSource, 'fnodes: pyamlnode;',
    'document node storage must use F-prefixed private field');
  CheckSourceContains(LSource, 'fnodecount: uint32;',
    'document node count must use F-prefixed private field');
  CheckSourceContains(LSource, 'function addnode: uint32;',
    'document add node must be a record method');
  CheckSourceContains(LSource, 'procedure registeranchor(const aname: tstringview; anodeidx: uint32);',
    'anchor registration must be a private record method');
  CheckSourceContains(LSource, 'function node(aidx: uint32): pyamlnode; inline;',
    'document must expose node accessor');
  CheckSourceContains(LSource, 'function anchorcount: uint32; inline;',
    'document must expose anchor count accessor');
  CheckSourceContains(LSource, 'function allocator: iallocator; inline;',
    'document must expose allocator accessor');
  CheckSourceContains(LSource, 'procedure setroot(aidx: uint32); inline;',
    'document must expose root setter for builder');
  CheckSourceContains(LSource, 'lnewptr := fallocator.reallocmem(pointer(fnodes),',
    'node growth must stage reallocate result');
  CheckSourceContains(LSource, 'if lnewptr = nil then',
    'node growth must guard nil reallocate');
  CheckSourceContains(LSource, 'lnewptr := fallocator.reallocmem(pointer(fanchors),',
    'anchor growth must stage reallocate result');
  CheckSourceContains(LSource, 'lptr := fallocator.getmem(fnodecap * sizeof(tyamlnode));',
    'init must stage node allocation');
  CheckSourceContains(LSource, 'lptr := fallocator.getmem(fanchorcap * sizeof(tyamlanchorentry));',
    'init must stage anchor allocation');
  CheckSourceContains(LSource, 'fallocator.freemem(pointer(fnodes));',
    'init must release staged nodes when anchor allocation fails');
  CheckSourceContains(LSource, 'if adoc.fnodes <> nil then',
    'parse with allocator must clean an existing document first');
  CheckSourceContains(LSource, 'adoc.done;',
    'reparse path must release old buffers before re-init');
  CheckSourceAbsent(LSource, 'function addnode(var adoc: tyamldocument): uint32;',
    'free AddNode helper must be removed');
  CheckSourceAbsent(LSource, 'procedure registeranchor(var adoc: tyamldocument;',
    'free RegisterAnchor helper must be removed');
end;

function BuildYamlSequence(const AItemCount: Integer): string;
var
  LI: Integer;
begin
  Result := '[';
  for LI := 0 to AItemCount - 1 do
  begin
    if LI > 0 then
      Result := Result + ', ';
    Result := Result + IntToStr(LI);
  end;
  Result := Result + ']';
end;

function BuildYamlAnchors(const AAnchorCount: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to AAnchorCount - 1 do
    Result := Result + 'k' + IntToStr(LI) + ': &a' + IntToStr(LI) + ' ' +
      IntToStr(LI) + #10;
end;

procedure TestParserNodeGrowthOOMFailsClosed;
var
  LAllocatorObj: TFailingReallocateAllocator;
  LAllocator: IAllocator;
  LDoc: TYamlDocument;
  LInput: string;
begin
  LAllocatorObj := TFailingReallocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  LInput := BuildYamlSequence(96);
  YamlDocParseWith(LDoc, @LInput[1], Length(LInput), LAllocator);
  try
    Check(LDoc.HasError(), 'node growth OOM sets error');
    CheckEqual('out of memory', LDoc.Error().Message.ToString,
      'node growth OOM message');
  finally
    LDoc.Done;
  end;
end;

procedure TestParserAnchorGrowthOOMFailsClosed;
var
  LAllocatorObj: TFailingReallocateAllocator;
  LAllocator: IAllocator;
  LDoc: TYamlDocument;
  LInput: string;
begin
  LAllocatorObj := TFailingReallocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  LInput := BuildYamlAnchors(24);
  YamlDocParseWith(LDoc, @LInput[1], Length(LInput), LAllocator);
  try
    Check(LDoc.HasError(), 'anchor growth OOM sets error');
    CheckEqual('out of memory', LDoc.Error().Message.ToString,
      'anchor growth OOM message');
  finally
    LDoc.Done;
  end;
end;

procedure TestParserInitAllocateOOMFailsClosed;
var
  LAllocatorObj: TFailingAllocateAllocator;
  LAllocator: IAllocator;
  LDoc: TYamlDocument;
begin
  LAllocatorObj := TFailingAllocateAllocator.Create(1);
  LAllocator := LAllocatorObj as IAllocator;
  YamlDocInitWith(LDoc, LAllocator);
  try
    Check(LDoc.HasError(), 'init node allocate OOM sets error');
    CheckEqual('out of memory', LDoc.Error().Message.ToString,
      'init node allocate OOM message');
  finally
    LDoc.Done;
  end;
end;

procedure TestParserReparseReleasesPriorDocument;
var
  LAllocatorObj: TCountingAllocator;
  LAllocator: IAllocator;
  LDoc: TYamlDocument;
  LInput: string;
begin
  LAllocatorObj := TCountingAllocator.Create;
  LAllocator := LAllocatorObj as IAllocator;

  LInput := '{svc: api}';
  YamlDocParseWith(LDoc, @LInput[1], Length(LInput), LAllocator);
  CheckEqual(Int64(2), Int64(LAllocatorObj.OutstandingAllocations),
    'first parse owns nodes and anchors');

  LInput := '[1, 2, 3]';
  YamlDocParseViewWith(LDoc, TStringView.FromStr(LInput), LAllocator);
  try
    Check(not LDoc.HasError, 'reparse succeeds');
    CheckEqual(Int64(2), Int64(LAllocatorObj.OutstandingAllocations),
      'reparse reuses ownership without leaking prior document');
  finally
    LDoc.Done;
  end;
  CheckEqual(Int64(0), Int64(LAllocatorObj.OutstandingAllocations),
    'final done releases all YAML buffers');
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
  T.Run('Parser allocator surface', @TestParserAllocatorSurface);
  T.Run('Parser source tracks private surface and OOM guards',
    @TestParserSourceTracksPrivateSurfaceAndOOMGuards);
  T.Run('Parser node growth OOM fails closed',
    @TestParserNodeGrowthOOMFailsClosed);
  T.Run('Parser anchor growth OOM fails closed',
    @TestParserAnchorGrowthOOMFailsClosed);
  T.Run('Parser init allocate OOM fails closed',
    @TestParserInitAllocateOOMFailsClosed);
  T.Run('Parser reparse releases prior document',
    @TestParserReparseReleasesPriorDocument);
  T.Run('K8s pod spec', @TestK8sPodSpec);
  T.Run('Docker compose', @TestDockerCompose);
  T.Run('GitHub Actions', @TestGitHubActions);
  T.Run('Config file', @TestConfigFile);
  T.Run('Multiline values', @TestMultilineValues);
  T.Run('Complex nesting', @TestComplexNesting);
  T.Summary;
end.
