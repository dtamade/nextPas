{$mode ObjFPC}{$H+}
program inttohex_bench;
uses nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.text.conv;


const
  N = 500;

var
  GResult: string;

procedure IntToHexLarge(const ACtx: IBenchContext);
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 1 to N do
    S := IntToHex(Int64(I) * 123456789, 16);
  GResult := S;
end;

procedure IntToHexSmall(const ACtx: IBenchContext);
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 1 to N do
    S := IntToHex(I, 8);
  GResult := S;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('inttohex');
  LSuite.Add('IntToHex64/500', @IntToHexLarge);
  LSuite.Add('IntToHex32/500', @IntToHexSmall);
  LSuite.SetMinSamples(10);
  LSuite.SetMaxIterations(10000);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
