program bench_builder_ops;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.text;

var
  B: TBenchRunner;
  GSizeSink: SizeUInt;
  GStringSink: string;

procedure BenchAppendStr(AIters: Int64);
var
  LIt: Int64;
  LBuilder: IStringBuilder;
begin
  LBuilder := MakeStringBuilder(128);
  for LIt := 1 to AIters do
  begin
    LBuilder.Clear;
    LBuilder.AppendStr('hello');
    LBuilder.AppendStr(' ');
    LBuilder.AppendStr('unicode');
    LBuilder.AppendStr(' ');
    LBuilder.AppendStr('builder');
    GSizeSink := LBuilder.Len;
  end;
end;

procedure BenchAppendInt(AIters: Int64);
var
  LIt: Int64;
  LI: Integer;
  LBuilder: IStringBuilder;
begin
  LBuilder := MakeStringBuilder(512);
  for LIt := 1 to AIters do
  begin
    LBuilder.Clear;
    for LI := 1 to 100 do
      LBuilder.AppendInt(Int64(LI) * 1234567);
    GSizeSink := LBuilder.Len;
  end;
end;

procedure BenchAppendFloat(AIters: Int64);
var
  LIt: Int64;
  LI: Integer;
  LBuilder: IStringBuilder;
begin
  LBuilder := MakeStringBuilder(512);
  for LIt := 1 to AIters do
  begin
    LBuilder.Clear;
    for LI := 1 to 50 do
      LBuilder.AppendFloat(LI * 3.141592653589793);
    GSizeSink := LBuilder.Len;
  end;
end;

procedure BenchToString(AIters: Int64);
var
  LIt: Int64;
  LBuilder: IStringBuilder;
begin
  LBuilder := MakeStringBuilder(256);
  LBuilder.AppendStr('The quick brown fox jumps over the lazy dog');
  LBuilder.AppendStr(' ');
  LBuilder.AppendStr('0123456789');
  for LIt := 1 to AIters do
    GStringSink := LBuilder.ToString;
end;

procedure BenchAppendLoop10000(AIters: Int64);
var
  LIt: Int64;
  LI: Integer;
  LBuilder: IStringBuilder;
begin
  LBuilder := MakeStringBuilder(32768);
  for LIt := 1 to AIters do
  begin
    LBuilder.Clear;
    for LI := 1 to 10000 do
      LBuilder.AppendStr('x');
    GSizeSink := LBuilder.Len;
  end;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.text builder ops benchmark ===');
  WriteLn;
  B.Run('IStringBuilder.AppendStr', @BenchAppendStr);
  B.Run('IStringBuilder.AppendInt', @BenchAppendInt);
  B.Run('IStringBuilder.AppendFloat', @BenchAppendFloat);
  B.Run('IStringBuilder.ToString', @BenchToString);
  B.Run('IStringBuilder.AppendStr loop 10000x', @BenchAppendLoop10000);
  WriteLn;
  B.Summary;
  B.Free;
end.
