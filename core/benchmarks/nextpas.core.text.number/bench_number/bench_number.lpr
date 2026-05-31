program bench_number;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.text.number;

var
  B: TBenchRunner;
  GSink: Int64;
  GBuf: array[0..63] of AnsiChar;

procedure BenchIntToBuffer_Small(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := IntToBuffer(42, @GBuf[0]);
end;

procedure BenchIntToBuffer_Medium(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := IntToBuffer(1234567890, @GBuf[0]);
end;

procedure BenchIntToBuffer_Large(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := IntToBuffer(9223372036854775807, @GBuf[0]);
end;

procedure BenchIntToBuffer_Negative(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := IntToBuffer(-1234567890, @GBuf[0]);
end;

procedure BenchUIntToBuffer(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := UIntToBuffer(18446744073709551615, @GBuf[0]);
end;

procedure BenchParseInt64_Small(aIters: Int64);
var
  LIt: Int64;
  LVal: Int64;
const
  S: PAnsiChar = '42';
begin
  for LIt := 1 to aIters do
    ParseInt64(S, 2, LVal);
  GSink := LVal;
end;

procedure BenchParseInt64_Medium(aIters: Int64);
var
  LIt: Int64;
  LVal: Int64;
const
  S: PAnsiChar = '1234567890';
begin
  for LIt := 1 to aIters do
    ParseInt64(S, 10, LVal);
  GSink := LVal;
end;

procedure BenchParseInt64_Large(aIters: Int64);
var
  LIt: Int64;
  LVal: Int64;
const
  S: PAnsiChar = '9223372036854775807';
begin
  for LIt := 1 to aIters do
    ParseInt64(S, 19, LVal);
  GSink := LVal;
end;

procedure BenchFloatToBuffer(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := FloatToBuffer(3.141592653589793, @GBuf[0]);
end;

procedure BenchParseDouble(aIters: Int64);
var
  LIt: Int64;
  LVal: Double;
const
  S: PAnsiChar = '3.141592653589793';
begin
  for LIt := 1 to aIters do
    ParseDouble(S, 17, LVal);
  GSink := Int64(Trunc(LVal));
end;

procedure BenchIntToHex(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    GSink := IntToHexBuffer($DEADBEEFCAFE, @GBuf[0], 12);
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.text.number benchmark ===');
  WriteLn;
  B.Run('IntToBuffer(42)', @BenchIntToBuffer_Small);
  B.Run('IntToBuffer(1234567890)', @BenchIntToBuffer_Medium);
  B.Run('IntToBuffer(MaxInt64)', @BenchIntToBuffer_Large);
  B.Run('IntToBuffer(-1234567890)', @BenchIntToBuffer_Negative);
  B.Run('UIntToBuffer(MaxUInt64)', @BenchUIntToBuffer);
  B.Run('ParseInt64("42")', @BenchParseInt64_Small);
  B.Run('ParseInt64("1234567890")', @BenchParseInt64_Medium);
  B.Run('ParseInt64(MaxInt64)', @BenchParseInt64_Large);
  B.Run('FloatToBuffer(pi)', @BenchFloatToBuffer);
  B.Run('ParseDouble("3.14...")', @BenchParseDouble);
  B.Run('IntToHexBuffer', @BenchIntToHex);
  WriteLn;
  B.Summary;
  B.Free;
end.
