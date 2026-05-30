program bench_toml_parse;

{$mode objfpc}{$H+}
{$optimization on}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.toml.value,
  nextpas.core.toml,
  nextpas.core.bench;

type
  TBumpAllocator = class(TInterfacedObject, IAllocator)
  private
    FBuf: PByte;
    FCap: SizeUInt;
    FPos: SizeUInt;
  public
    constructor Create(ACap: SizeUInt);
    destructor Destroy; override;
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    procedure Reset;
  end;

constructor TBumpAllocator.Create(ACap: SizeUInt);
begin
  inherited Create;
  FCap := ACap;
  FBuf := GetMem(ACap);
  FPos := 0;
end;

destructor TBumpAllocator.Destroy;
begin
  FreeMem(FBuf);
  inherited;
end;

function TBumpAllocator.Allocate(const ASize: SizeUInt): Pointer;
var
  LAligned: SizeUInt;
begin
  LAligned := (FPos + 7) and not SizeUInt(7);
  if LAligned + ASize > FCap then
    Exit(GetMem(ASize));
  Result := FBuf + LAligned;
  FPos := LAligned + ASize;
end;

function TBumpAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := Allocate(ANewSize);
  if APtr <> nil then
    Move(APtr^, Result^, ANewSize);
end;

procedure TBumpAllocator.Deallocate(const APtr: Pointer);
begin
  if (PByte(APtr) < FBuf) or (PByte(APtr) >= FBuf + FCap) then
    FreeMem(APtr);
end;

procedure TBumpAllocator.Reset;
begin
  FPos := 0;
end;

var
  GSmallToml: string;
  GMediumToml: string;
  GLargeToml: string;

procedure BuildInputs;
var
  LI: Integer;
begin
  GSmallToml :=
    'name = "my-app"' + #10 +
    'version = "1.0.0"' + #10 +
    'description = "A sample application"' + #10 +
    'license = "MIT"' + #10 +
    'authors = ["Alice", "Bob"]' + #10 +
    'debug = false' + #10 +
    'port = 8080' + #10 +
    'timeout = 30.5' + #10 +
    'created = 2024-01-15T10:30:00Z' + #10 +
    'tags = ["web", "api", "fast"]' + #10;

  GMediumToml :=
    '[package]' + #10 +
    'name = "nextpas"' + #10 +
    'version = "0.1.0"' + #10 +
    'edition = "2024"' + #10 + #10 +
    '[dependencies]' + #10 +
    'http = "2.0.0"' + #10 +
    'json = "1.5.0"' + #10 +
    'toml = "0.8.0"' + #10 +
    'crypto = "0.4.0"' + #10 + #10 +
    '[server]' + #10 +
    'host = "0.0.0.0"' + #10 +
    'port = 443' + #10 +
    'workers = 4' + #10 +
    'max_connections = 10000' + #10 +
    'timeout_ms = 30000' + #10 +
    'tls = true' + #10 + #10 +
    '[database]' + #10 +
    'url = "postgres://localhost:5432/mydb"' + #10 +
    'pool_size = 20' + #10 +
    'idle_timeout = 300' + #10 +
    'ssl_mode = "require"' + #10 + #10;
  for LI := 1 to 20 do
    GMediumToml := GMediumToml + '[[features]]' + #10 +
      'name = "feature-' + IntToStr(LI) + '"' + #10 +
      'enabled = true' + #10 +
      'priority = ' + IntToStr(LI) + #10 + #10;

  GLargeToml := '';
  for LI := 1 to 100 do
    GLargeToml := GLargeToml + '[section_' + IntToStr(LI) + ']' + #10 +
      'key_a = "value_' + IntToStr(LI) + '_a"' + #10 +
      'key_b = ' + IntToStr(LI * 100) + #10 +
      'key_c = ' + IntToStr(LI) + '.5' + #10 +
      'key_d = true' + #10 +
      'key_e = [1, 2, 3, 4, 5]' + #10 +
      'key_f = {x = ' + IntToStr(LI) + ', y = ' + IntToStr(LI * 2) + '}' + #10 + #10;
end;

procedure BenchSmallParse(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GSmallToml);
  for LI := 1 to AIters do
  begin
    LDoc.Init(DefaultAllocator);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

procedure BenchMediumParse(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GMediumToml);
  for LI := 1 to AIters do
  begin
    LDoc.Init(DefaultAllocator);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

procedure BenchLargeParse(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GLargeToml);
  for LI := 1 to AIters do
  begin
    LDoc.Init(DefaultAllocator);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

procedure BenchSmallFacade(AIters: Int64);
var
  LDoc: ITomlDocument;
  LI: Int64;
begin
  for LI := 1 to AIters do
    LDoc := TomlParse(GSmallToml);
end;

procedure BenchMediumAccess(AIters: Int64);
var
  LDoc: ITomlDocument;
  LVal: TTomlValue;
  LI: Int64;
begin
  LDoc := TomlParse(GMediumToml);
  for LI := 1 to AIters do
  begin
    LVal := LDoc.Root.Get('server').Get('port');
    LVal := LDoc.Root.Get('database').Get('url');
    LVal := LDoc.Root.Get('features').ArrayGet(10).Get('name');
  end;
end;

var
  GStringHeavyToml: string;
  GLongStringToml: string;

procedure BuildStringInputs;
var
  LI: Integer;
  LLongVal: string;
begin
  GStringHeavyToml := '';
  for LI := 1 to 100 do
    GStringHeavyToml := GStringHeavyToml +
      'key_' + IntToStr(LI) + ' = "This is a medium-length string value number ' + IntToStr(LI) + ' with some content"' + #10;

  LLongVal := '';
  for LI := 1 to 1000 do
    LLongVal := LLongVal + 'abcdefghij';
  GLongStringToml := 'data = "' + LLongVal + '"' + #10 +
    'path = "C:\\Users\\admin\\Documents\\projects\\nextpas\\core\\src\\nextpas.core.toml.parser.pas"' + #10 +
    'url = "https://example.com/api/v2/users?page=1&limit=100&sort=name&order=asc"' + #10;
end;

procedure BenchStringHeavy(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GStringHeavyToml);
  for LI := 1 to AIters do
  begin
    LDoc.Init(DefaultAllocator);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

procedure BenchLongString(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GLongStringToml);
  for LI := 1 to AIters do
  begin
    LDoc.Init(DefaultAllocator);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

var
  LBench: TBenchRunner;
  GArena: IAllocator;

procedure BenchMediumArena(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GMediumToml);
  for LI := 1 to AIters do
  begin
    (GArena as TBumpAllocator).Reset;
    LDoc.Init(GArena);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

procedure BenchLargeArena(AIters: Int64);
var
  LDoc: TTomlDocument;
  LView: TStringView;
  LI: Int64;
begin
  LView := TStringView.FromStr(GLargeToml);
  for LI := 1 to AIters do
  begin
    (GArena as TBumpAllocator).Reset;
    LDoc.Init(GArena);
    LDoc.Parse(LView);
    LDoc.Done;
  end;
end;

begin
  BuildInputs;
  BuildStringInputs;
  GArena := TBumpAllocator.Create(1024 * 1024);

  WriteLn('=== nextpas.core.toml benchmark ===');
  WriteLn('Small TOML:  ', Length(GSmallToml):5, ' bytes (10 keys)');
  WriteLn('Medium TOML: ', Length(GMediumToml):5, ' bytes (~50 keys)');
  WriteLn('Large TOML:  ', Length(GLargeToml):5, ' bytes (~700 keys)');
  WriteLn('StringHeavy: ', Length(GStringHeavyToml):5, ' bytes (100 medium strings)');
  WriteLn('LongString:  ', Length(GLongStringToml):5, ' bytes (10KB string + escaped)');
  WriteLn;

  LBench := TBenchRunner.Create;
  LBench.Run('parse/small (10 keys)', @BenchSmallParse);
  LBench.Run('parse/medium (~50 keys)', @BenchMediumParse);
  LBench.Run('parse/large (~700 keys)', @BenchLargeParse);
  LBench.Run('parse/string-heavy (100 strings)', @BenchStringHeavy);
  LBench.Run('parse/long-string (10KB value)', @BenchLongString);
  LBench.Run('facade/small (parse+interface)', @BenchSmallFacade);
  LBench.Run('access/medium (3 lookups)', @BenchMediumAccess);
  LBench.Run('arena/medium (~50 keys)', @BenchMediumArena);
  LBench.Run('arena/large (~700 keys)', @BenchLargeArena);
  LBench.Summary;
  LBench.Free;
end.
