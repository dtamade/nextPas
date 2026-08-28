program bench_kv;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.fs, nextpas.core.text.conv,
  nextpas.core.text.kv;
var
  GSink: UInt64;
  GSmall, GMedium, GLarge: string;

procedure BuildFixtures;
var I: Integer;
begin
  GSmall := 'host=127.0.0.1 port=3306 user=root password=''p@ss wd'' db=app socket=/tmp/mysql.sock';
  GMedium := '';
  for I := 1 to 20 do
    GMedium := GMedium + 'k' + IntToStr(I) + '=v' + IntToStr(I) + ' ';
  // trim trailing space
  if (Length(GMedium)>0) and (GMedium[Length(GMedium)]=' ') then SetLength(GMedium, Length(GMedium)-1);
  // add quoted with @/= for realism
  GMedium := GMedium + ' extra=''a b c'' quoted="x=y@z"';

  GLarge := '';
  for I := 1 to 100 do
    GLarge := GLarge + 'k' + IntToStr(I) + '=v' + IntToStr(I) + ' ';
  if (Length(GLarge)>0) and (GLarge[Length(GLarge)]=' ') then SetLength(GLarge, Length(GLarge)-1);
end;

procedure BenchParseSmall(const ACtx: IBenchContext);
var P: TKVPairs;
begin
  P := ParseKV(GSmall);
  GSink := GSink xor UInt64(Length(P));
end;

procedure BenchParseMedium(const ACtx: IBenchContext);
var P: TKVPairs;
begin
  P := ParseKV(GMedium);
  GSink := GSink xor UInt64(Length(P));
end;

procedure BenchParseLarge(const ACtx: IBenchContext);
var P: TKVPairs;
begin
  P := ParseKV(GLarge);
  GSink := GSink xor UInt64(Length(P));
end;

procedure BenchScanSmall(const ACtx: IBenchContext);
var LCount: Integer;
begin
  LCount := 0;
  ScanKV(GSmall,
    procedure(const AKey, AValue: string)
    begin
      Inc(LCount);
    end);
  GSink := GSink xor UInt64(LCount);
end;

procedure BenchScanLarge(const ACtx: IBenchContext);
var LCount: Integer;
begin
  LCount := 0;
  ScanKV(GLarge,
    procedure(const AKey, AValue: string)
    begin
      Inc(LCount);
    end);
  GSink := GSink xor UInt64(LCount);
end;

var
  LResults: IBenchResults;
begin
  GSink := 0;
  BuildFixtures;
  LResults := TBenchSuite.Create('text.kv')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(7)
    .Add('kv/parse_small~80B', @BenchParseSmall)
    .Add('kv/parse_medium~350B', @BenchParseMedium)
    .Add('kv/parse_large~1.5KB', @BenchParseLarge)
    .Add('kv/scan_small~80B', @BenchScanSmall)
    .Add('kv/scan_large~1.5KB', @BenchScanLarge)
    .Run;
  WriteLn(LResults.PrintToConsole);
  WriteLn('sink=', GSink);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-kv.json');
end.
