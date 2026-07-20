program bench_csv;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.csv,
  nextpas.core.fs;
var GSmallCsv: string; GLargeCsv: string; GSink: UInt64;
function BuildCsv(ARowCount: Integer): string;
var LLen, LCap, LI: Integer; LBuffer: string;
begin
  LLen := 0; LCap := 0; LBuffer := '';
  for LI := 1 to ARowCount do begin
    if LLen + 12 > LCap then begin if LCap = 0 then LCap := 1024 else LCap := LCap * 2; SetLength(LBuffer, LCap); end;
    Move('a,b,c,d,e'#10, LBuffer[LLen + 1], 11); Inc(LLen, 11);
  end;
  SetLength(LBuffer, LLen); Result := LBuffer;
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var LReader: TCsvReader; LRows: TStringMatrix;
begin LReader := TCsvReader.Create(GSmallCsv); LRows := LReader.ReadAll; GSink := GSink xor UInt64(Length(LRows)); end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var LReader: TCsvReader; LRows: TStringMatrix;
begin LReader := TCsvReader.Create(GLargeCsv); LRows := LReader.ReadAll; GSink := GSink xor UInt64(Length(LRows)); end;
var LResults: IBenchResults;
begin
  GSmallCsv := BuildCsv(1000); GLargeCsv := BuildCsv(10000); GSink := 0;
  LResults := TBenchSuite.Create('csv')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Parse/1K-rows', @BenchParseSmall).Add('Parse/10K-rows', @BenchParseLarge)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-csv.json');
end.
