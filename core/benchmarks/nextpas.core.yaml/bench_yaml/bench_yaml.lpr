program bench_yaml;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.yaml;
var GSmall, GMedium, GLarge: string; GSink: UInt64;
procedure BuildTestData;
var LI: Integer;
begin
  GSmall := '{name: Alice, age: 30, active: true, score: 3.14}';
  GMedium := '{users: [{id: 1, name: Alice, email: alice@example.com, age: 30}, {id: 2, name: Bob, email: bob@example.com, age: 25}, {id: 3, name: Charlie, email: charlie@example.com, age: 35}], total: 3, page: 1, hasMore: false}';
  GLarge := '{items: [';
  for LI := 1 to 100 do begin
    if LI > 1 then GLarge := GLarge + ', ';
    GLarge := GLarge + '{id: ' + IntToStr(LI) + ', name: item' + IntToStr(LI) + ', value: ' + IntToStr(LI * 10) + ', active: true}';
  end;
  GLarge := GLarge + '], count: 100, version: 2}';
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var LDoc: IYamlDocument;
begin LDoc := YamlParse(GSmall); GSink := GSink xor UInt64(Length(GSmall)); end;
procedure BenchParseMedium(const ACtx: IBenchContext);
var LDoc: IYamlDocument;
begin LDoc := YamlParse(GMedium); GSink := GSink xor UInt64(Length(GMedium)); end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var LDoc: IYamlDocument;
begin LDoc := YamlParse(GLarge); GSink := GSink xor UInt64(Length(GLarge)); end;
var LSuite: IBenchSuite;
begin
  BuildTestData; GSink := 0;
  LSuite := TBenchSuite.Create('yaml');
  LSuite.Add('Parse/small', @BenchParseSmall).Add('Parse/medium', @BenchParseMedium).Add('Parse/large', @BenchParseLarge);
  WriteLn(LSuite.Run.PrintToConsole);
end.
