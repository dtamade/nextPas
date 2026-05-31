program bench_csv;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.csv;

type
  TBenchProc = procedure(AIterations: Int64);

var
  GSmallCsv: string;
  GLargeCsv: string;
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

function BuildCsv(ARowCount: Integer): string;
var
  LLen, LCap, LI: Integer;
  LBuffer: string;
begin
  LLen := 0;
  LCap := 0;
  LBuffer := '';
  for LI := 1 to ARowCount do
    AppendString(LBuffer, LLen, LCap, 'a,b,c,d,e' + #10);
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

procedure BenchParseSmall(AIterations: Int64);
var
  LI: Int64;
  LReader: TCsvReader;
  LRows: TStringMatrix;
begin
  for LI := 1 to AIterations do
  begin
    LReader := TCsvReader.Create(GSmallCsv);
    LRows := LReader.ReadAll;
    if LReader.HasError then
      raise Exception.Create(LReader.GetError);
    GSink := GSink xor UInt64(Length(LRows));
    if Length(LRows) > 0 then
      GSink := GSink xor UInt64(Length(LRows[0]));
  end;
end;

procedure BenchParseLarge(AIterations: Int64);
var
  LI: Int64;
  LReader: TCsvReader;
  LRows: TStringMatrix;
begin
  for LI := 1 to AIterations do
  begin
    LReader := TCsvReader.Create(GLargeCsv);
    LRows := LReader.ReadAll;
    if LReader.HasError then
      raise Exception.Create(LReader.GetError);
    GSink := GSink xor UInt64(Length(LRows));
    if Length(LRows) > 0 then
      GSink := GSink xor UInt64(Length(LRows[Length(LRows) - 1]));
  end;
end;

begin
  GSmallCsv := BuildCsv(1000);
  GLargeCsv := BuildCsv(10000);
  GSink := 0;

  WriteLn('=== nextpas.core.csv benchmark ===');
  WriteLn('  small CSV bytes: ', Length(GSmallCsv), ' (1000 rows x 5 cols)');
  WriteLn('  large CSV bytes: ', Length(GLargeCsv), ' (10000 rows x 5 cols)');
  PrintHeader;
  RunBench('csv parse 10KB / 1000x5', 1000, @BenchParseSmall);
  RunBench('csv parse 100KB / 10000x5', 100, @BenchParseLarge);
  WriteLn('  sink=', GSink);
end.
