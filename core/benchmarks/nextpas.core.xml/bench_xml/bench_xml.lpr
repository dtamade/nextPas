program bench_xml;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.xml,
  nextpas.core.fs,
  nextpas.core.text.conv;
var GConfigXml: string; GDataXml: string; GSink: UInt64;
function BuildConfigXml(ATargetBytes: Integer): string;
var LBuffer, LPiece: string; LI: Integer;
begin
  LBuffer := '';
  LI := 0;
  while Length(LBuffer) < ATargetBytes - 16 do
  begin
    LPiece := '  <service name="service' + IntToStr(LI) +
      '" enabled="true"><host>127.0.0.1</host><port>' +
      IntToStr(8000 + (LI mod 1000)) + '</port></service>'#10;
    LBuffer := LBuffer + LPiece;
    Inc(LI);
  end;
  Result := '<?xml version="1.0" encoding="utf-8"?>'#10'<config>'#10 + LBuffer + '</config>';
end;
function BuildDataXml(AItemBytes: Integer): string;
var LBuffer, LPiece: string; LI: Integer;
begin
  LBuffer := '';
  LI := 0;
  while Length(LBuffer) < AItemBytes - 16 do
  begin
    LPiece := '<item id="' + IntToStr(LI) + '"><value>' + IntToStr(LI * 10) +
      '</value><name>item_' + IntToStr(LI) + '</name></item>';
    LBuffer := LBuffer + LPiece;
    Inc(LI);
  end;
  Result := '<data>' + LBuffer + '</data>';
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse(GConfigXml);
  try
    GSink := GSink xor UInt64(LDoc.Root.ChildCount);
  finally
    LDoc.Done;
  end;
end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse(GDataXml);
  try
    GSink := GSink xor UInt64(LDoc.Root.ChildCount);
  finally
    LDoc.Done;
  end;
end;
var LResults: IBenchResults;
begin
  GConfigXml := BuildConfigXml(2000); GDataXml := BuildDataXml(50000); GSink := 0;
  LResults := TBenchSuite.Create('xml')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Parse/small', @BenchParseSmall).Add('Parse/large', @BenchParseLarge)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-xml.json');
end.
