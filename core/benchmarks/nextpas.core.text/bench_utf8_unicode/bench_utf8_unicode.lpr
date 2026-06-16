program bench_utf8_unicode;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode,
  nextpas.core.text.compare;

const
  Iterations = 50000;

type
  TBenchProc = procedure;

var
  GAsciiText: string;
  GCjkText: string;
  GEmojiText: string;
  GMixedText: string;
  GCanonicalComposed: string;
  GCanonicalDecomposed: string;
  GCaseFoldLeft: string;
  GCaseFoldRight: string;
  GValidationSink: Boolean;
  GCountSink: SizeUInt;
  GCodePointSink: UInt32;
  GLengthSink: Byte;
  GStringSink: string;

procedure AppendUtf8(var ADst: string; const ACodePoint: UInt32);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LOldLen: SizeInt;
  I: Byte;
begin
  LLen := UTF8Encode(ACodePoint, @LBuf[0]);
  if LLen = 0 then
    Exit;

  LOldLen := Length(ADst);
  SetLength(ADst, LOldLen + LLen);
  for I := 0 to LLen - 1 do
    ADst[LOldLen + I + 1] := AnsiChar(LBuf[I]);
end;

function Utf8Of(const ACodePoints: array of UInt32): string;
var
  I: SizeInt;
begin
  Result := '';
  for I := 0 to High(ACodePoints) do
    AppendUtf8(Result, ACodePoints[I]);
end;

function MeasureNs(const AProc: TBenchProc): UInt64;
var
  LStartNs: UInt64;
begin
  LStartNs := platform_monotonic_ns;
  AProc();
  Result := platform_monotonic_ns - LStartNs;
end;

procedure PrintHeader;
begin
  WriteLn('操作名 | 迭代次数 | 总耗时(ns) | 单次(ns/op)');
  WriteLn('--- | ---: | ---: | ---:');
end;

procedure RunBench(const AName: string; const AProc: TBenchProc);
var
  LTotalNs: UInt64;
  LNsPerOp: Double;
begin
  LTotalNs := MeasureNs(AProc);
  if Iterations > 0 then
    LNsPerOp := Double(LTotalNs) / Double(Iterations)
  else
    LNsPerOp := 0;

  WriteLn(
    AName, ' | ',
    Iterations, ' | ',
    LTotalNs, ' | ',
    FormatFloat('0.00', LNsPerOp)
  );
end;

procedure SetupSamples;
begin
  GAsciiText := 'Hello, UTF-8 world! 12345 ABC xyz ~/[]{}()';
  GCjkText := Utf8Of([$4F60, $597D, $4E16, $754C, $FF0C, $6B22, $8FCE, $4F7F, $7528, $55AE, $5143, $6E2C, $8A66]);
  GEmojiText := Utf8Of([$1F44B, $1F30D, $2728, $1F680, $1F469, $200D, $1F4BB, $1F600]);
  GMixedText := 'Stra' + Utf8Of([$00DF]) + 'e ' + GCjkText + ' ' + GEmojiText + ' Caf' + Utf8Of([$00E9]);
  GCanonicalComposed := Utf8Of([$00C5]);
  GCanonicalDecomposed := Utf8Of([$0041, $030A]);
  GCaseFoldLeft := 'Stra' + Utf8Of([$00DF]) + 'e';
  GCaseFoldRight := 'STRASSE';
end;

procedure BenchUtf8IsValid;
var
  I: Integer;
begin
  for I := 1 to Iterations do
  begin
    GValidationSink := UTF8IsValid(PByte(PAnsiChar(GAsciiText)), Length(GAsciiText));
    GValidationSink := UTF8IsValid(PByte(PAnsiChar(GCjkText)), Length(GCjkText)) and GValidationSink;
    GValidationSink := UTF8IsValid(PByte(PAnsiChar(GEmojiText)), Length(GEmojiText)) and GValidationSink;
  end;
end;

procedure BenchUtf8CodePointCount;
var
  I: Integer;
begin
  for I := 1 to Iterations do
    GCountSink := UTF8CodePointCount(PByte(PAnsiChar(GMixedText)), Length(GMixedText));
end;

procedure BenchUtf8DecodeEncode;
var
  I: Integer;
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LBuf: array[0..3] of Byte;
begin
  for I := 1 to Iterations do
  begin
    LIter.Init(PByte(PAnsiChar(GMixedText)), Length(GMixedText));
    while LIter.Next(LCp) do
    begin
      GCodePointSink := LCp;
      GLengthSink := UTF8Encode(LCp, @LBuf[0]);
    end;
  end;
end;

procedure BenchUtf8Iterator;
var
  I: Integer;
  LIter: TUTF8Iterator;
  LCp: UInt32;
begin
  for I := 1 to Iterations do
  begin
    LIter.Init(PByte(PAnsiChar(GMixedText)), Length(GMixedText));
    while LIter.Next(LCp) do
      GCodePointSink := LCp;
  end;
end;

procedure BenchUtf8ToUpperLower;
var
  I: Integer;
begin
  for I := 1 to Iterations do
  begin
    GStringSink := UTF8ToUpper(GMixedText);
    GStringSink := UTF8ToLower(GStringSink);
  end;
end;

procedure BenchNfd;
var
  I: Integer;
begin
  for I := 1 to Iterations do
    GStringSink := NFD(GMixedText);
end;

procedure BenchNfc;
var
  I: Integer;
begin
  for I := 1 to Iterations do
    GStringSink := NFC(GMixedText);
end;

procedure BenchUtf8CaseFold;
var
  I: Integer;
begin
  for I := 1 to Iterations do
    GStringSink := UTF8CaseFold(GMixedText);
end;

procedure BenchTextEqualCanonical;
var
  I: Integer;
begin
  for I := 1 to Iterations do
    GValidationSink := TextEqualCanonical(GCanonicalComposed, GCanonicalDecomposed);
end;

procedure BenchTextEqualCaseFold;
var
  I: Integer;
begin
  for I := 1 to Iterations do
    GValidationSink := TextEqualCaseFold(GCaseFoldLeft, GCaseFoldRight);
end;

begin
  SetupSamples;
  PrintHeader;
  RunBench('UTF8IsValid', @BenchUtf8IsValid);
  RunBench('UTF8CodePointCount', @BenchUtf8CodePointCount);
  RunBench('UTF8Decode + UTF8Encode', @BenchUtf8DecodeEncode);
  RunBench('TUTF8Iterator', @BenchUtf8Iterator);
  RunBench('UTF8ToUpper / UTF8ToLower', @BenchUtf8ToUpperLower);
  RunBench('NFD', @BenchNfd);
  RunBench('NFC', @BenchNfc);
  RunBench('UTF8CaseFold', @BenchUtf8CaseFold);
  RunBench('TextEqualCanonical', @BenchTextEqualCanonical);
  RunBench('TextEqualCaseFold', @BenchTextEqualCaseFold);

  if GValidationSink and (GCountSink = 0) and (GCodePointSink = 0) and (GLengthSink = 0) then
    WriteLn('');
end.
