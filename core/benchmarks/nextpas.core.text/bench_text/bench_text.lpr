program bench_text;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.text.view,
  nextpas.core.text.number,
  nextpas.core.text.escape,
  nextpas.core.text.scan,
  nextpas.core.text.utf8,
  nextpas.core.text.builder,
  nextpas.core.text.conv;

const
  ITERATIONS = 100000;

procedure BenchOp(const AName: string; const AOps: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LNsPerOp: Double;
  LMOps: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if LNs > 0 then
  begin
    LNsPerOp := LNs / AOps;
    LMOps := (AOps / 1000000.0) / (LNs / 1000000000.0);
  end
  else
  begin
    LNsPerOp := 0;
    LMOps := 0;
  end;
  WriteLn(Format('  %-40s %8.1f ns/op  %8.1f Mops/s', [AName, LNsPerOp, LMOps]));
end;

{ === IndexOf benchmark: nextpas vs FPC Pos === }

procedure BenchIndexOf;
const
  DATA = 'The quick brown fox jumps over the lazy dog and finds the hidden treasure at the end';
  N = ITERATIONS * 10;
var
  LView: TStringView;
  LStart: TInstant;
  I: Int32;
  LDummy: PtrInt;
begin
  LView := TStringView.Create(PAnsiChar(DATA), Length(DATA));
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := LView.IndexOf('t');
  BenchOp('TStringView.IndexOf (vec16)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := System.Pos('t', DATA);
  BenchOp('FPC Pos (scalar)', N, LStart.Elapsed);
end;

{ === Equals benchmark: nextpas vs FPC = === }

procedure BenchEquals;
const
  A = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!!';
  B = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!!';
  N = ITERATIONS * 10;
var
  LVA, LVB: TStringView;
  LStart: TInstant;
  I: Int32;
  LDummy: Boolean;
begin
  LVA := TStringView.Create(PAnsiChar(A), Length(A));
  LVB := TStringView.Create(PAnsiChar(B), Length(B));
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := LVA.Equals(LVB);
  BenchOp('TStringView.Equals 64B (vec16)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := A = B;
  BenchOp('FPC string = (scalar)', N, LStart.Elapsed);
end;

{ === IntToBuffer benchmark: nextpas vs FPC IntToStr === }

procedure BenchIntToBuffer;
const
  N = ITERATIONS * 5;
var
  LBuf: array[0..24] of AnsiChar;
  LStart: TInstant;
  I: Int32;
  LDummy: Int32;
  LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := IntToBuffer(Int64(1234567890), @LBuf[0]);
  BenchOp('IntToBuffer (2-digit LUT)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LS := SysUtils.IntToStr(1234567890);
  BenchOp('FPC SysUtils.IntToStr', N, LStart.Elapsed);
end;

{ === FloatToBuffer benchmark: nextpas vs FPC FloatToStr === }

procedure BenchFloatToBuffer;
const
  N = ITERATIONS;
var
  LBuf: array[0..31] of AnsiChar;
  LStart: TInstant;
  I: Int32;
  LDummy: Int32;
  LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := FloatToBuffer(3.141592653589793, @LBuf[0]);
  BenchOp('FloatToBuffer (Schubfach)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LS := SysUtils.FloatToStr(3.141592653589793);
  BenchOp('FPC SysUtils.FloatToStr', N, LStart.Elapsed);
end;

{ === ParseDouble benchmark: nextpas vs FPC Val === }

procedure BenchParseDouble;
const
  DATA = '3.141592653589793';
  N = ITERATIONS;
var
  LStart: TInstant;
  I: Int32;
  LV: Double;
  LCode: Integer;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    ParseDouble(PAnsiChar(DATA), Length(DATA), LV);
  BenchOp('ParseDouble', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    System.Val(DATA, LV, LCode);
  BenchOp('FPC Val (Grisu1 path)', N, LStart.Elapsed);
end;

{ === JsonEscape benchmark === }

procedure BenchJsonEscape;
const
  CLEAN = 'This is a perfectly normal string without any special characters at all here';
  DIRTY = 'He said "hello\world" and then\nnewline happened\there';
  N = ITERATIONS * 5;
var
  LBuf: array[0..511] of AnsiChar;
  LStart: TInstant;
  I: Int32;
  LDummy: SizeUInt;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := JsonEscapeToBuffer(PAnsiChar(CLEAN), Length(CLEAN), @LBuf[0]);
  BenchOp('JsonEscape clean 76B (vec16)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := JsonEscapeToBuffer(PAnsiChar(DIRTY), Length(DIRTY), @LBuf[0]);
  BenchOp('JsonEscape dirty 54B (vec16)', N, LStart.Elapsed);
end;

{ === SkipWhitespace benchmark === }

procedure BenchSkipWhitespace;
var
  LBuf: array[0..255] of AnsiChar;
  LStart: TInstant;
  I: Int32;
  LDummy: SizeUInt;
const
  N = ITERATIONS * 10;
begin
  FillChar(LBuf, 200, Ord(' '));
  LBuf[200] := '{';
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := ScanSkipWhitespace(@LBuf[0], 201);
  BenchOp('ScanSkipWhitespace 200B (vec16)', N, LStart.Elapsed);
end;

{ === UTF-8 validate benchmark === }

procedure BenchUtf8Validate;
const
  ASCII = 'The quick brown fox jumps over the lazy dog 0123456789 ABCDEFGHIJKLMNOP';
  N = ITERATIONS * 10;
var
  LStart: TInstant;
  I: Int32;
  LDummy: Boolean;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := UTF8IsValid(PByte(PAnsiChar(ASCII)), Length(ASCII));
  BenchOp('UTF8IsValid 71B ASCII', N, LStart.Elapsed);
end;

{ === StringBuilder benchmark === }

procedure BenchStringBuilder;
const
  N = ITERATIONS;
var
  LB: TStringBuilder;
  LStart: TInstant;
  I, J: Int32;
  LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
  begin
    LB.Init(128);
    for J := 1 to 10 do
    begin
      LB.AppendStr('key');
      LB.AppendChar(':');
      LB.AppendInt(J * 100);
      LB.AppendChar(',');
    end;
    LB.Done;
  end;
  BenchOp('TStringBuilder 10x append', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
  begin
    LS := '';
    for J := 1 to 10 do
      LS := LS + 'key:' + SysUtils.IntToStr(J * 100) + ',';
  end;
  BenchOp('FPC string concat 10x', N, LStart.Elapsed);
end;

{ === text.conv vs SysUtils comparison === }

procedure BenchConvIntToStr;
const N = ITERATIONS * 5;
var LStart: TInstant; I: Int32; LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LS := nextpas.core.text.conv.IntToStr(Int64(I) * 123456789);
  BenchOp('text.conv.IntToStr', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LS := SysUtils.IntToStr(Int64(I) * 123456789);
  BenchOp('SysUtils.IntToStr', N, LStart.Elapsed);
end;

procedure BenchConvTrim;
const
  PADDED = '   hello world   ';
  N = ITERATIONS * 10;
var LStart: TInstant; I: Int32; LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LS := nextpas.core.text.conv.Trim(PADDED);
  BenchOp('text.conv.Trim', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LS := SysUtils.Trim(PADDED);
  BenchOp('SysUtils.Trim', N, LStart.Elapsed);
end;

procedure BenchConvLowerCase;
const
  MIXED = 'The Quick Brown Fox Jumps Over The Lazy Dog';
  N = ITERATIONS * 10;
var LStart: TInstant; I: Int32; LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LS := nextpas.core.text.conv.LowerCase(MIXED);
  BenchOp('text.conv.LowerCase 44B', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LS := SysUtils.LowerCase(MIXED);
  BenchOp('SysUtils.LowerCase 44B', N, LStart.Elapsed);
end;

procedure BenchConvFormat;
const N = ITERATIONS;
var LStart: TInstant; I: Int32; LS: string;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    LS := nextpas.core.text.conv.Format('item %d: %s = %d', [I, 'value', I * 10]);
  BenchOp('text.conv.Format (3 args)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    LS := SysUtils.Format('item %d: %s = %d', [I, 'value', I * 10]);
  BenchOp('SysUtils.Format (3 args)', N, LStart.Elapsed);
end;

procedure BenchConvStrToInt;
const
  NUMS: array[0..4] of string = ('12345', '-99999', '0', '2147483647', '-1');
  N = ITERATIONS * 5;
var LStart: TInstant; I, LCode: Int32; LV: Int64;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    nextpas.core.text.conv.TryStrToInt(NUMS[I mod 5], LV);
  BenchOp('text.conv.TryStrToInt', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
    System.Val(NUMS[I mod 5], LV, LCode);
  BenchOp('System.Val (baseline)', N, LStart.Elapsed);
end;

begin
  WriteLn('=== nextpas.core.text benchmarks ===');
  WriteLn('  (', ITERATIONS, ' base iterations, higher = more precise)');
  WriteLn;

  WriteLn('--- Search ---');
  BenchIndexOf;
  WriteLn;

  WriteLn('--- Compare ---');
  BenchEquals;
  WriteLn;

  WriteLn('--- Integer Format ---');
  BenchIntToBuffer;
  WriteLn;

  WriteLn('--- Float Format ---');
  BenchFloatToBuffer;
  WriteLn;

  WriteLn('--- Float Parse ---');
  BenchParseDouble;
  WriteLn;

  WriteLn('--- JSON Escape ---');
  BenchJsonEscape;
  WriteLn;

  WriteLn('--- Whitespace Skip ---');
  BenchSkipWhitespace;
  WriteLn;

  WriteLn('--- UTF-8 Validate ---');
  BenchUtf8Validate;
  WriteLn;

  WriteLn('--- StringBuilder ---');
  BenchStringBuilder;
  WriteLn;

  WriteLn('--- text.conv vs SysUtils ---');
  BenchConvIntToStr;
  BenchConvTrim;
  BenchConvLowerCase;
  BenchConvFormat;
  BenchConvStrToInt;
  WriteLn;

  WriteLn('--- Reference (literature/known values) ---');
  WriteLn('  Go strconv.FormatFloat:                ~120 ns/op (Ryu)');
  WriteLn('  Go strconv.ParseFloat:                 ~50 ns/op (Eisel-Lemire)');
  WriteLn('  Rust ryu::d2s_buffered:                ~25 ns/op');
  WriteLn('  yyjson write (C, Schubfach):           ~30 ns/op');
  WriteLn('  yyjson read (C, Eisel-Lemire):         ~20 ns/op');
  WriteLn;

  WriteLn('Done.');
end.
