program bench_yaml;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.yaml;

const
  ITERATIONS = 1000;

var
  GSmall, GMedium, GLarge: string;

procedure BuildTestData;
var
  LI: Integer;
begin
  GSmall := '{name: Alice, age: 30, active: true, score: 3.14}';

  GMedium := '{users: [{id: 1, name: Alice, email: alice@example.com, age: 30}, ' +
    '{id: 2, name: Bob, email: bob@example.com, age: 25}, ' +
    '{id: 3, name: Charlie, email: charlie@example.com, age: 35}], ' +
    'total: 3, page: 1, hasMore: false}';

  GLarge := '{items: [';
  for LI := 1 to 100 do
  begin
    if LI > 1 then GLarge := GLarge + ', ';
    GLarge := GLarge + '{id: ' + IntToStr(LI) +
      ', name: item' + IntToStr(LI) +
      ', value: ' + IntToStr(LI * 10) +
      ', active: true}';
  end;
  GLarge := GLarge + '], count: 100, version: 2}';
end;

procedure BenchParse(const AName, AInput: string; AIterations: Integer);
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LDoc: IYamlDocument;
  LNsPerOp: Double;
begin
  LDoc := YamlParse(AInput);
  if LDoc.HasError then
  begin
    WriteLn('  ERROR: ', AName, ' parse failed');
    Exit;
  end;

  LStart := TInstant.Now;
  for LI := 1 to AIterations do
    LDoc := YamlParse(AInput);
  LElapsed := LStart.Elapsed.AsSecondsF;
  LNsPerOp := (LElapsed * 1e9) / AIterations;
  WriteLn(Format('  %-45s %8.0f ns/op  (%d bytes)', [AName, LNsPerOp, Length(AInput)]));
end;

procedure BenchStringify(const AName, AInput: string; AIterations: Integer);
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LDoc: IYamlDocument;
  LNsPerOp: Double;
begin
  LDoc := YamlParse(AInput);
  if LDoc.HasError then Exit;

  LStart := TInstant.Now;
  for LI := 1 to AIterations do
    LDoc.Stringify;
  LElapsed := LStart.Elapsed.AsSecondsF;
  LNsPerOp := (LElapsed * 1e9) / AIterations;
  WriteLn(Format('  %-45s %8.0f ns/op', [AName, LNsPerOp]));
end;

begin
  BuildTestData;
  WriteLn('=== nextpas.core.yaml benchmarks ===');
  WriteLn;
  WriteLn('--- Parse ---');
  BenchParse('parse small (50B flow map)', GSmall, ITERATIONS * 10);
  BenchParse('parse medium (250B nested)', GMedium, ITERATIONS * 5);
  BenchParse('parse large (10KB, 100 items)', GLarge, ITERATIONS);
  WriteLn;
  WriteLn('--- Stringify ---');
  BenchStringify('stringify small', GSmall, ITERATIONS * 10);
  BenchStringify('stringify medium', GMedium, ITERATIONS * 5);
  BenchStringify('stringify large', GLarge, ITERATIONS);
  WriteLn;
  WriteLn('--- Reference (Go yaml.v3, approximate) ---');
  WriteLn('  Go yaml.v3 parse small (~50B):              ~2000 ns/op');
  WriteLn('  Go yaml.v3 parse medium (~250B):            ~8000 ns/op');
  WriteLn('  Go yaml.v3 parse large (~10KB):           ~200000 ns/op');
  WriteLn;
  WriteLn('done.');
end.
