program bench_strings;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.text,
  nextpas.core.text.compare;

const
  WarmupIterations = 1000;
  MeasureIterations = 100000;
  TrimSampleCount = 100;

type
  TBenchProc = procedure;

  TBenchCase = record
    Name: string;
    Iterations: Int64;
    TotalNs: QWord;
    NsPerOp: Double;
    ThroughputMBps: Double;
  end;

var
  GTrimSamples: array[0..TrimSampleCount - 1] of string;
  GSplitSample: string;
  GSplitParts: TStringArray;
  GJoinParts: TStringArray;
  GJoinSeparator: string;
  GReplaceSource: string;
  GReplaceOld: string;
  GReplaceNew: string;
  GContainsSource: string;
  GContainsNeedle: string;
  GPrefixSource: string;
  GPrefixNeedle: string;
  GSuffixNeedle: string;
  GEqualCaseLeft: string;
  GEqualCaseRight: string;
  GUpperSource: string;
  GLowerSource: string;
  GStringSink: string;
  GBoolSink: Boolean;
  GArraySink: TStringArray;
  GIntSink: SizeInt;
  GBytesPerIteration: SizeUInt;

procedure AddJoinPart(const AValue: string);
var
  LLen: SizeInt;
begin
  LLen := Length(GJoinParts);
  SetLength(GJoinParts, LLen + 1);
  GJoinParts[LLen] := AValue;
end;

function BuildCsvRow: string;
var
  LParts: TStringArray;
  I: Integer;
begin
  SetLength(LParts, 12);
  for I := Low(LParts) to High(LParts) do
    LParts[I] := Format('field_%.2d=value_%.2d', [I, I * 7 + 3]);
  Result := TextJoin(LParts, ',');
end;

function CalcNsPerOp(ATotalNs: QWord; AIterations: Int64): Double;
begin
  if AIterations <= 0 then
    Exit(0);
  Result := Double(ATotalNs) / Double(AIterations);
end;

function CalcThroughputMBps(ATotalBytes: QWord; ATotalNs: QWord): Double;
const
  BytesPerMB = 1024.0 * 1024.0;
  NsPerSecond = 1000000000.0;
begin
  if (ATotalBytes = 0) or (ATotalNs = 0) then
    Exit(0);
  Result := (Double(ATotalBytes) / BytesPerMB) / (Double(ATotalNs) / NsPerSecond);
end;

procedure PrintHeader;
begin
  WriteLn('操作名 | 迭代次数 | 总耗时(ns) | 单次(ns/op) | 吞吐量(MB/s)');
  WriteLn('--- | ---: | ---: | ---: | ---:');
end;

procedure PrintCase(const ACase: TBenchCase);
begin
  WriteLn(
    ACase.Name, ' | ',
    ACase.Iterations, ' | ',
    ACase.TotalNs, ' | ',
    FormatFloat('0.00', ACase.NsPerOp), ' | ',
    FormatFloat('0.00', ACase.ThroughputMBps)
  );
end;

procedure RunCase(const AName: string; ABytesPerIteration: SizeUInt; AProc: TBenchProc);
var
  LStartNs: UInt64;
  LTotalNs: UInt64;
  LCase: TBenchCase;
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
  LCase.ThroughputMBps := CalcThroughputMBps(QWord(ABytesPerIteration) * QWord(MeasureIterations), LTotalNs);
  PrintCase(LCase);
end;

procedure SetupTrimSamples;
var
  I: Integer;
begin
  for I := 0 to High(GTrimSamples) do
    GTrimSamples[I] := Format('  sample_%.2d alpha beta gamma delta epsilon zeta eta theta iota  ', [I]);
  GBytesPerIteration := 0;
  for I := 0 to High(GTrimSamples) do
    Inc(GBytesPerIteration, Length(GTrimSamples[I]));
end;

procedure SetupJoinParts;
begin
  SetLength(GJoinParts, 0);
  AddJoinPart('Alice');
  AddJoinPart('Bob');
  AddJoinPart('Charlie');
  AddJoinPart('Delta');
  AddJoinPart('Echo');
  AddJoinPart('Foxtrot');
  AddJoinPart('Golf');
  AddJoinPart('Hotel');
  AddJoinPart('India');
  AddJoinPart('Juliet');
  GJoinSeparator := ' | ';
end;

procedure SetupData;
begin
  SetupTrimSamples;
  GSplitSample := BuildCsvRow;
  GSplitParts := TextSplit(GSplitSample, ',');
  SetupJoinParts;
  GReplaceSource := 'Order status: pending, pending review, pending shipment, pending completion.';
  GReplaceOld := 'pending';
  GReplaceNew := 'ready';
  GContainsSource := 'The Unicode text module handles UTF-8 trimming, splitting, folding, and normalization safely.';
  GContainsNeedle := 'splitting';
  GPrefixSource := 'nextpas.core.text.unicode.facade';
  GPrefixNeedle := 'nextpas.core.text';
  GSuffixNeedle := 'facade';
  GEqualCaseLeft := 'CAF' + #$C3#$89;
  GEqualCaseRight := 'caf' + #$C3#$A9;
  GUpperSource := 'Stra' + #$C3#$9F + 'e ' + #$CE#$A9 + #$CE#$BC + #$CE#$AD + #$CE#$B3 + #$CE#$B1 + ' caf' + #$C3#$A9;
  GLowerSource := 'STRASSE ' + #$CE#$A9 + #$CE#$9C + #$CE#$95 + #$CE#$93 + #$CE#$91 + ' CAF' + #$C3#$89;
end;

procedure BenchTrim;
var
  I: Integer;
begin
  for I := 0 to High(GTrimSamples) do
    GStringSink := TextTrim(GTrimSamples[I]);
end;

procedure BenchSplit;
begin
  GArraySink := TextSplit(GSplitSample, ',');
  GIntSink := Length(GArraySink);
end;

procedure BenchJoin;
begin
  GStringSink := TextJoin(GJoinParts, GJoinSeparator);
end;

procedure BenchReplace;
begin
  GStringSink := TextReplaceAll(GReplaceSource, GReplaceOld, GReplaceNew);
end;

procedure BenchContains;
begin
  GBoolSink := TextContains(GContainsSource, GContainsNeedle);
end;

procedure BenchPrefixSuffix;
begin
  GBoolSink := TextStartsWith(GPrefixSource, GPrefixNeedle);
end;

procedure BenchEndsWith;
begin
  GBoolSink := TextEndsWith(GPrefixSource, GSuffixNeedle);
end;

procedure BenchEqualI;
begin
  GBoolSink := nextpas.core.text.compare.TextEqualI(GEqualCaseLeft, GEqualCaseRight);
end;

procedure BenchToUpper;
begin
  GStringSink := TextToUpper(GUpperSource);
end;

procedure BenchToLower;
begin
  GStringSink := TextToLower(GLowerSource);
end;

procedure RunBenchmarks;
begin
  PrintHeader;

  RunCase('TextTrim', GBytesPerIteration, @BenchTrim);
  RunCase('TextSplit', Length(GSplitSample), @BenchSplit);
  RunCase('TextJoin', Length(TextJoin(GJoinParts, GJoinSeparator)), @BenchJoin);
  RunCase('TextReplace', Length(GReplaceSource), @BenchReplace);
  RunCase('TextContains', Length(GContainsSource), @BenchContains);
  RunCase('TextStartsWith', Length(GPrefixSource), @BenchPrefixSuffix);
  RunCase('TextEndsWith', Length(GPrefixSource), @BenchEndsWith);
  RunCase('TextEqualI', Length(GEqualCaseLeft) + Length(GEqualCaseRight), @BenchEqualI);
  RunCase('TextToUpper', Length(GUpperSource), @BenchToUpper);
  RunCase('TextToLower', Length(GLowerSource), @BenchToLower);
end;

begin
  SetupData;
  RunBenchmarks;
  if GBoolSink and (GIntSink = -1) then
    WriteLn('');
end.
