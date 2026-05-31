program bench_builder;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.text.builder,
  nextpas.core.text.view;

var
  B: TBenchRunner;
  GSink: SizeUInt;

procedure BenchAppendStr_Short(aIters: Int64);
var
  LIt: Int64;
  LSb: TStringBuilder;
begin
  for LIt := 1 to aIters do
  begin
    LSb.Init(64);
    LSb.AppendStr('hello');
    LSb.AppendStr(' ');
    LSb.AppendStr('world');
    GSink := LSb.Len;
    LSb.Done;
  end;
end;

procedure BenchAppendStr_100x(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LSb: TStringBuilder;
begin
  for LIt := 1 to aIters do
  begin
    LSb.Init(1024);
    for LI := 1 to 100 do
      LSb.AppendStr('abcdefghij');
    GSink := LSb.Len;
    LSb.Done;
  end;
end;

procedure BenchAppendChar_1000(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LSb: TStringBuilder;
begin
  for LIt := 1 to aIters do
  begin
    LSb.Init(1024);
    for LI := 1 to 1000 do
      LSb.AppendChar('x');
    GSink := LSb.Len;
    LSb.Done;
  end;
end;

procedure BenchAppendInt_100(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LSb: TStringBuilder;
begin
  for LIt := 1 to aIters do
  begin
    LSb.Init(512);
    for LI := 1 to 100 do
      LSb.AppendInt(Int64(LI) * 12345);
    GSink := LSb.Len;
    LSb.Done;
  end;
end;

procedure BenchAppendMixed(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LSb: TStringBuilder;
begin
  for LIt := 1 to aIters do
  begin
    LSb.Init(256);
    LSb.AppendStr('HTTP/1.1 ');
    LSb.AppendInt(200);
    LSb.AppendStr(' OK');
    LSb.AppendChar(#13);
    LSb.AppendChar(#10);
    LSb.AppendStr('Content-Length: ');
    LSb.AppendInt(1024);
    LSb.AppendChar(#13);
    LSb.AppendChar(#10);
    LSb.AppendChar(#13);
    LSb.AppendChar(#10);
    GSink := LSb.Len;
    LSb.Done;
  end;
end;

procedure BenchToString(aIters: Int64);
var
  LIt: Int64;
  LSb: TStringBuilder;
  LS: string;
begin
  LSb.Init(256);
  LSb.AppendStr('The quick brown fox jumps over the lazy dog');
  for LIt := 1 to aIters do
    LS := LSb.ToString;
  GSink := Length(LS);
  LSb.Done;
end;

procedure BenchPreallocGrow(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LSb: TStringBuilder;
begin
  for LIt := 1 to aIters do
  begin
    LSb.Init(16);
    for LI := 1 to 50 do
      LSb.AppendStr('0123456789abcdef');
    GSink := LSb.Len;
    LSb.Done;
  end;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.text.builder benchmark ===');
  WriteLn;
  B.Run('AppendStr short (3x)', @BenchAppendStr_Short);
  B.Run('AppendStr 100x "abcdefghij"', @BenchAppendStr_100x);
  B.Run('AppendChar 1000x', @BenchAppendChar_1000);
  B.Run('AppendInt 100x', @BenchAppendInt_100);
  B.Run('AppendMixed (HTTP header)', @BenchAppendMixed);
  B.Run('ToString (43 bytes)', @BenchToString);
  B.Run('Grow from 16 to 800 bytes', @BenchPreallocGrow);
  WriteLn;
  B.Summary;
  B.Free;
end.
