program bench_xml;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.xml;

type
  TBenchProc = procedure(AIterations: Int64);

var
  GConfigXml: string;
  GDataXml: string;
  GSink: UInt64;

procedure EnsureCapacity(var ABuffer: string; var ALength, ACapacity: Integer; AAdditional: Integer);
var
  LRequired: Integer;
begin
  LRequired := ALength + AAdditional;
  if LRequired <= ACapacity then
    Exit;
  if ACapacity = 0 then
    ACapacity := 1024;
  while ACapacity < LRequired do
    ACapacity := ACapacity * 2;
  SetLength(ABuffer, ACapacity);
end;

procedure AppendString(var ABuffer: string; var ALength, ACapacity: Integer; const AText: string);
var
  LTextLen: Integer;
begin
  LTextLen := Length(AText);
  if LTextLen = 0 then
    Exit;
  EnsureCapacity(ABuffer, ALength, ACapacity, LTextLen);
  Move(AText[1], ABuffer[ALength + 1], LTextLen);
  Inc(ALength, LTextLen);
end;

function BuildConfigXml(ATargetBytes: Integer): string;
var
  LLen, LCap, LI: Integer;
  LBuffer: string;
begin
  LLen := 0;
  LCap := 0;
  LBuffer := '';
  AppendString(LBuffer, LLen, LCap, '<?xml version="1.0" encoding="utf-8"?>' + #10 + '<config>' + #10);
  LI := 0;
  while LLen < ATargetBytes - 16 do
  begin
    AppendString(LBuffer, LLen, LCap,
      '  <service name="service' + IntToStr(LI) + '" enabled="true">' + #10 +
      '    <host>127.0.0.1</host>' + #10 +
      '    <port>' + IntToStr(8000 + (LI mod 1000)) + '</port>' + #10 +
      '    <timeout>30</timeout>' + #10 +
      '    <path>/var/lib/nextpas/service' + IntToStr(LI) + '</path>' + #10 +
      '  </service>' + #10);
    Inc(LI);
  end;
  AppendString(LBuffer, LLen, LCap, '</config>' + #10);
  SetLength(LBuffer, LLen);
  Result := LBuffer;
end;

function BuildDataXml(ATargetBytes: Integer): string;
var
  LLen, LCap, LI: Integer;
  LBuffer: string;
begin
  LLen := 0;
  LCap := 0;
  LBuffer := '';
  AppendString(LBuffer, LLen, LCap, '<?xml version="1.0" encoding="utf-8"?>' + #10 + '<dataset>' + #10);
  LI := 0;
  while LLen < ATargetBytes - 18 do
  begin
    AppendString(LBuffer, LLen, LCap,
      '  <row id="' + IntToStr(LI) + '" type="event">' + #10 +
      '    <name>item_' + IntToStr(LI) + '</name>' + #10 +
      '    <value>' + IntToStr(LI * 17) + '</value>' + #10 +
      '    <flag>' + IntToStr(LI mod 2) + '</flag>' + #10 +
      '    <message>payload for item ' + IntToStr(LI) + ' with stable benchmark text</message>' + #10 +
      '  </row>' + #10);
    Inc(LI);
  end;
  AppendString(LBuffer, LLen, LCap, '</dataset>' + #10);
  SetLength(LBuffer, LLen);
  Result := LBuffer;
end;

procedure PrintHeader;
begin
  WriteLn('  操作名                              迭代次数        总耗时          ns/op');
end;

procedure PrintResult(const AName: string; AIterations: Int64; AElapsed: UInt64);
var
  LNsPerOp: Double;
begin
  if AIterations > 0 then
    LNsPerOp := Double(AElapsed) / Double(AIterations)
  else
    LNsPerOp := 0.0;
  WriteLn(Format('  %-32s %10d %12.3f ms %12.1f ns/op',
    [AName, AIterations, Double(AElapsed) / 1000000.0, LNsPerOp]));
end;

procedure RunBench(const AName: string; AIterations: Int64; AProc: TBenchProc);
var
  LStart, LFinish: UInt64;
begin
  AProc(2);
  LStart := platform_monotonic_ns;
  AProc(AIterations);
  LFinish := platform_monotonic_ns;
  PrintResult(AName, AIterations, LFinish - LStart);
end;

procedure BenchTokenizeConfig(AIterations: Int64);
var
  LI: Int64;
  LReader: TXmlReader;
  LToken: TXmlToken;
  LCount: UInt64;
begin
  for LI := 1 to AIterations do
  begin
    LCount := 0;
    LReader := TXmlReader.Create(GConfigXml);
    try
      while LReader.Next(LToken) do
        Inc(LCount);
      if LReader.HasError then
        raise EXmlError.Create(LReader.GetError, LReader.Position);
      GSink := GSink xor LCount;
    finally
      LReader.Free;
    end;
  end;
end;

procedure BenchTokenizeData(AIterations: Int64);
var
  LI: Int64;
  LReader: TXmlReader;
  LToken: TXmlToken;
  LCount: UInt64;
begin
  for LI := 1 to AIterations do
  begin
    LCount := 0;
    LReader := TXmlReader.Create(GDataXml);
    try
      while LReader.Next(LToken) do
        Inc(LCount);
      if LReader.HasError then
        raise EXmlError.Create(LReader.GetError, LReader.Position);
      GSink := GSink xor LCount;
    finally
      LReader.Free;
    end;
  end;
end;

procedure BenchDomConfig(AIterations: Int64);
var
  LI: Int64;
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  for LI := 1 to AIterations do
  begin
    LDoc := XmlParse(GConfigXml);
    try
      LNodes := LDoc.SelectPath('/config/service');
      GSink := GSink xor UInt64(Length(LNodes));
      if Length(LNodes) > 0 then
        GSink := GSink xor UInt64(Length(LNodes[0].GetAttr('name', '')));
    finally
      LDoc.Free;
    end;
  end;
end;

procedure BenchDomData(AIterations: Int64);
var
  LI: Int64;
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  for LI := 1 to AIterations do
  begin
    LDoc := XmlParse(GDataXml);
    try
      LNodes := LDoc.SelectPath('/dataset/row');
      GSink := GSink xor UInt64(Length(LNodes));
      if Length(LNodes) > 0 then
        GSink := GSink xor UInt64(Length(LNodes[Length(LNodes) - 1].GetAttr('id', '')));
    finally
      LDoc.Free;
    end;
  end;
end;

begin
  GConfigXml := BuildConfigXml(10 * 1024);
  GDataXml := BuildDataXml(100 * 1024);
  GSink := 0;

  WriteLn('=== nextpas.core.xml benchmark ===');
  WriteLn('  config XML bytes: ', Length(GConfigXml));
  WriteLn('  data XML bytes:   ', Length(GDataXml));
  PrintHeader;
  RunBench('xml tokenize 10KB config', 300, @BenchTokenizeConfig);
  RunBench('xml tokenize 100KB data', 50, @BenchTokenizeData);
  RunBench('xml DOM+query 10KB config', 100, @BenchDomConfig);
  RunBench('xml DOM+query 100KB data', 20, @BenchDomData);
  WriteLn('  sink=', GSink);
end.
