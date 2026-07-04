program bench_xml;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.xml;
var GConfigXml: string; GDataXml: string; GSink: UInt64;
function BuildConfigXml(ATargetBytes: Integer): string;
var LLen, LCap, LI: Integer; LBuffer: string;
begin
  LLen := 0; LCap := 0; LBuffer := '';
  LI := 0;
  while LLen < ATargetBytes - 16 do begin
    if LLen + 120 > LCap then begin if LCap = 0 then LCap := 8192 else LCap := LCap * 2; SetLength(LBuffer, LCap); end;
    LLen := LLen + FormatBuf(LBuffer[LLen + 1], '  <service name="service%d" enabled="true"><host>127.0.0.1</host><port>%d</port></service>'#10, [LI, 8000 + (LI mod 1000)]);
    Inc(LI);
  end;
  SetLength(LBuffer, LLen);
  Result := '<?xml version="1.0" encoding="utf-8"?>'#10'<config>'#10 + LBuffer + '</config>';
end;
function BuildDataXml(AItemBytes: Integer): string;
var LLen, LCap, LI: Integer; LBuffer: string;
begin
  LLen := 0; LCap := 0; LBuffer := '';
  LI := 0;
  while LLen < AItemBytes - 16 do begin
    if LLen + 80 > LCap then begin if LCap = 0 then LCap := 8192 else LCap := LCap * 2; SetLength(LBuffer, LCap); end;
    LLen := LLen + FormatBuf(LBuffer[LLen + 1], '<item id="%d"><value>%d</value><name>item_%d</name></item>', [LI, LI * 10, LI]);
    Inc(LI);
  end;
  SetLength(LBuffer, LLen);
  Result := '<data>' + LBuffer + '</data>';
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var LDoc: IXmlDocument;
begin LDoc := TXmlDocument.Parse(GConfigXml); GSink := GSink xor UInt64(LDoc.Root.ChildCount); end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var LDoc: IXmlDocument;
begin LDoc := TXmlDocument.Parse(GDataXml); GSink := GSink xor UInt64(LDoc.Root.ChildCount); end;
var LSuite: IBenchSuite;
begin
  GConfigXml := BuildConfigXml(2000); GDataXml := BuildDataXml(50000); GSink := 0;
  LSuite := TBenchSuite.Create('xml');
  LSuite.Add('Parse/small', @BenchParseSmall).Add('Parse/large', @BenchParseLarge);
  WriteLn(LSuite.Run.PrintToConsole);
end.
