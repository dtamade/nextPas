program bench_number_ops;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.text,
  nextpas.core.text.number;

const
  WarmupIterations = 1000;
  MeasureIterations = 100000;

  IntValue: Int64 = -1234567890123456789;
  UIntValue: UInt64 = High(UInt64);
  HexValue: UInt64 = (UInt64($DEADBEEF) shl 32) or UInt64($CAFEBABE);
  FloatValue: Double = 1234567.89012345;

  ParseIntText = '-1234567890123456789';
  ParseFloatText = '1234567.89012345';
  FormatTextValue = 'benchmark';

type
  TBenchProc = procedure;

  TBenchCase = record
    Name: string;
    Iterations: Int64;
    TotalNs: UInt64;
    NsPerOp: Double;
  end;

var
  GStringSink: string;
  GIntSink: Int64;
  GDoubleSink: Double;
  GBoolSink: Boolean;
  GBufferSink: Int32;
  GBuffer: array[0..63] of AnsiChar;

function CalcNsPerOp(const ATotalNs: UInt64; const AIterations: Int64): Double;
begin
  if AIterations <= 0 then
    Exit(0.0);
  Result := Double(ATotalNs) / Double(AIterations);
end;

procedure PrintHeader;
begin
  WriteLn('操作名 | 迭代次数 | 总耗时(ns) | 单次(ns/op)');
  WriteLn('--- | ---: | ---: | ---:');
end;

procedure PrintCase(const ACase: TBenchCase);
begin
  WriteLn(
    ACase.Name, ' | ',
    ACase.Iterations, ' | ',
    ACase.TotalNs, ' | ',
    FormatFloat('0.00', ACase.NsPerOp)
  );
end;

procedure RunCase(const AName: string; AProc: TBenchProc);
var
  LCase: TBenchCase;
  LStartNs: UInt64;
  LTotalNs: UInt64;
  I: Integer;
begin
  for I := 1 to WarmupIterations do
    AProc();

  LStartNs := platform_monotonic_ns;
  for I := 1 to MeasureIterations do
    AProc();
  LTotalNs := platform_monotonic_ns - LStartNs;

  LCase.Name := AName;
  LCase.Iterations := MeasureIterations;
  LCase.TotalNs := LTotalNs;
  LCase.NsPerOp := CalcNsPerOp(LTotalNs, MeasureIterations);
  PrintCase(LCase);
end;

procedure BenchIntToStr;
begin
  GStringSink := nextpas.core.text.IntToStr(IntValue);
end;

procedure BenchUIntToStr;
begin
  GStringSink := nextpas.core.text.UIntToStr(UIntValue);
end;

procedure BenchIntToHex;
begin
  GStringSink := nextpas.core.text.IntToHex(HexValue, 16);
end;

procedure BenchStrToInt;
begin
  GIntSink := nextpas.core.text.StrToInt(ParseIntText);
end;

procedure BenchFloatToStr;
begin
  GStringSink := nextpas.core.text.FloatToStr(FloatValue);
end;

procedure BenchTryStrToFloat;
begin
  GBoolSink := nextpas.core.text.TryStrToFloat(ParseFloatText, GDoubleSink);
end;

procedure BenchTextFormat;
begin
  GStringSink := nextpas.core.text.TextFormat('%d %s %f',
    [IntValue, FormatTextValue, FloatValue]);
end;

procedure BenchParseDouble;
begin
  GBoolSink := nextpas.core.text.number.ParseDouble(
    PAnsiChar(ParseFloatText), Length(ParseFloatText), GDoubleSink);
end;

procedure BenchFloatToBuffer;
begin
  GBufferSink := nextpas.core.text.number.FloatToBuffer(FloatValue, @GBuffer[0]);
  if GBufferSink > 0 then
    GIntSink := Ord(GBuffer[GBufferSink - 1]);
end;

begin
  GStringSink := '';
  GIntSink := 0;
  GDoubleSink := 0.0;
  GBoolSink := False;
  GBufferSink := 0;
  WriteLn('=== nextpas.core.text number format/parse benchmark ===');
  PrintHeader;
  RunCase('IntToStr', @BenchIntToStr);
  RunCase('UIntToStr', @BenchUIntToStr);
  RunCase('IntToHex', @BenchIntToHex);
  RunCase('StrToInt', @BenchStrToInt);
  RunCase('FloatToStr', @BenchFloatToStr);
  RunCase('TryStrToFloat', @BenchTryStrToFloat);
  RunCase('TextFormat', @BenchTextFormat);
  RunCase('ParseDouble', @BenchParseDouble);
  RunCase('FloatToBuffer', @BenchFloatToBuffer);
  if GBoolSink and (GIntSink = Low(Int64)) and (GDoubleSink = 0.0) and
     (GBufferSink = 0) and (Length(GStringSink) = 0) then
    WriteLn('');
end.
