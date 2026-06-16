program bench_scan;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.platform.time,
  nextpas.core.text.escape,
  nextpas.core.text.scan;

const
  SMALL_FIND_LEN = 32;
  MEDIUM_FIND_LEN = 256;
  LARGE_FIND_LEN = 4096;
  JSON_ESCAPED_LEN = 512;
  JSON_PLAIN_LEN = 256;

type
  TScanBuffer = array[0..LARGE_FIND_LEN - 1] of AnsiChar;
  TJsonEscapeBuffer = array[0..JSON_ESCAPED_LEN - 1] of AnsiChar;
  TJsonPlainBuffer = array[0..JSON_PLAIN_LEN - 1] of AnsiChar;

var
  B: TBenchRunner;
  GSink: PtrInt;
  GSizeSink: SizeUInt;
  GErrorSink: TUnescapeError;

  GFindSmall: TScanBuffer;
  GFindMedium: TScanBuffer;
  GFindLarge: TScanBuffer;
  GWhitespaceSmall: TScanBuffer;
  GWhitespaceMedium: TScanBuffer;
  GWhitespaceLarge: TScanBuffer;
  GSubstrHaystack: TScanBuffer;
  GJsonEscapeAscii: AnsiString;
  GJsonEscapeControl: AnsiString;
  GJsonEscapeUnicode: AnsiString;
  GJsonUnescapeAscii: AnsiString;
  GJsonUnescapeControl: AnsiString;
  GJsonUnescapeUnicode: AnsiString;
  GJsonFindAscii: AnsiString;
  GJsonFindEscaped: AnsiString;
  GJsonFindUnicode: AnsiString;

procedure FillBuffer(var AData: TScanBuffer; const ALen: SizeUInt; const AFill: AnsiChar);
begin
  FillChar(AData[0], ALen, Byte(AFill));
end;

procedure InitFindBuffers;
begin
  FillBuffer(GFindSmall, SMALL_FIND_LEN, 'a');
  FillBuffer(GFindMedium, MEDIUM_FIND_LEN, 'b');
  FillBuffer(GFindLarge, LARGE_FIND_LEN, 'c');
  GFindSmall[SMALL_FIND_LEN - 1] := 'z';
  GFindMedium[MEDIUM_FIND_LEN - 1] := 'z';
  GFindLarge[LARGE_FIND_LEN - 1] := 'z';
end;

procedure InitWhitespaceBuffers;
begin
  FillBuffer(GWhitespaceSmall, SMALL_FIND_LEN, ' ');
  FillBuffer(GWhitespaceMedium, MEDIUM_FIND_LEN, #9);
  FillBuffer(GWhitespaceLarge, LARGE_FIND_LEN, #10);
  GWhitespaceSmall[SMALL_FIND_LEN - 1] := '{';
  GWhitespaceMedium[MEDIUM_FIND_LEN - 1] := '[';
  GWhitespaceLarge[LARGE_FIND_LEN - 1] := '"';
end;

procedure InitSubstringBuffer;
var
  I: Integer;
begin
  for I := 0 to LARGE_FIND_LEN - 1 do
    GSubstrHaystack[I] := AnsiChar(Ord('a') + (I mod 23));
  Move('needle-value'[1], GSubstrHaystack[2048], Length('needle-value'));
end;

function RepeatText(const AText: string; const ACount: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
    Result := Result + AText;
end;

procedure InitJsonSamples;
begin
  GJsonEscapeAscii :=
    'alpha-numeric-plain-text-' + RepeatText('segment-', 8);
  GJsonEscapeControl :=
    'line1' + #10 + 'line2' + #9 + 'tab' + #13 + 'carriage' + '"' + '\';
  GJsonEscapeUnicode :=
    'hello ' + #$E4#$B8#$AD#$E6#$96#$87 + ' ' + #$F0#$9F#$98#$80 + ' ' +
    #$E2#$9D#$A4 + #$EF#$B8#$8F;

  GJsonUnescapeAscii :=
    'plain string without escapes';
  GJsonUnescapeControl :=
    'line1\nline2\tindent\rreturn\"quote\\slash';
  GJsonUnescapeUnicode :=
    'unicode \u4e2d\u6587 \ud83d\ude00 \u2764\ufe0f';

  GJsonFindAscii :=
    'plain ascii string with terminator"';
  GJsonFindEscaped :=
    'quote \\\" inside string and slash \\\\ ending"';
  GJsonFindUnicode :=
    'utf8 ' + #$E4#$B8#$AD#$E6#$96#$87 + ' ' + #$F0#$9F#$98#$80 + '"';
end;

procedure PrintBytesPerSecond(const AName: string; const ABytesPerOp: Double; const AOpsPerSec: Double);
var
  LGiBPerSec: Double;
begin
  if ABytesPerOp <= 0 then
    Exit;
  LGiBPerSec := (ABytesPerOp * AOpsPerSec) / (1024.0 * 1024.0 * 1024.0);
  WriteLn(Format('    %-36s %8.2f GiB/s', [AName + ' throughput', LGiBPerSec]));
end;

procedure PrintFocusThroughput(const AName: string; const ADataLen: SizeUInt; const AProc: TBenchProc);
const
  MEASURE_ITERS = 200000;
var
  LStartNs: UInt64;
  LEndNs: UInt64;
  LNs: UInt64;
  LOpsPerSec: Double;
begin
  LStartNs := platform_monotonic_ns;
  AProc(MEASURE_ITERS);
  LEndNs := platform_monotonic_ns;
  LNs := LEndNs - LStartNs;
  if LNs = 0 then
    Exit;
  LOpsPerSec := (MEASURE_ITERS * 1000000000.0) / LNs;
  PrintBytesPerSecond(AName, ADataLen, LOpsPerSec);
end;

procedure BenchFindByteSmall(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := ScanFindByte(@GFindSmall[0], SMALL_FIND_LEN, Ord('z'));
end;

procedure BenchFindByteMedium(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := ScanFindByte(@GFindMedium[0], MEDIUM_FIND_LEN, Ord('z'));
end;

procedure BenchFindByteLarge(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := ScanFindByte(@GFindLarge[0], LARGE_FIND_LEN, Ord('z'));
end;

procedure BenchSkipWhitespaceSmall(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSizeSink := ScanSkipWhitespace(@GWhitespaceSmall[0], SMALL_FIND_LEN);
end;

procedure BenchSkipWhitespaceMedium(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSizeSink := ScanSkipWhitespace(@GWhitespaceMedium[0], MEDIUM_FIND_LEN);
end;

procedure BenchSkipWhitespaceLarge(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSizeSink := ScanSkipWhitespace(@GWhitespaceLarge[0], LARGE_FIND_LEN);
end;

procedure BenchFindSubstring(AIters: Int64);
const
  NEEDLE = 'needle-value';
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := ScanFindSubstring(@GSubstrHaystack[0], LARGE_FIND_LEN, PAnsiChar(NEEDLE), Length(NEEDLE));
end;

procedure BenchJsonEscapeAscii(AIters: Int64);
var
  LIt: Int64;
  LBuf: TJsonEscapeBuffer;
begin
  for LIt := 1 to AIters do
    GSizeSink := JsonEscapeToBuffer(PAnsiChar(GJsonEscapeAscii), Length(GJsonEscapeAscii), @LBuf[0]);
end;

procedure BenchJsonEscapeControl(AIters: Int64);
var
  LIt: Int64;
  LBuf: TJsonEscapeBuffer;
begin
  for LIt := 1 to AIters do
    GSizeSink := JsonEscapeToBuffer(PAnsiChar(GJsonEscapeControl), Length(GJsonEscapeControl), @LBuf[0]);
end;

procedure BenchJsonEscapeUnicode(AIters: Int64);
var
  LIt: Int64;
  LBuf: TJsonEscapeBuffer;
begin
  for LIt := 1 to AIters do
    GSizeSink := JsonEscapeToBuffer(PAnsiChar(GJsonEscapeUnicode), Length(GJsonEscapeUnicode), @LBuf[0]);
end;

procedure BenchJsonUnescapeAscii(AIters: Int64);
var
  LIt: Int64;
  LBuf: TJsonPlainBuffer;
  LErr: TUnescapeError;
begin
  for LIt := 1 to AIters do
  begin
    GSizeSink := JsonUnescapeToBuffer(PAnsiChar(GJsonUnescapeAscii), Length(GJsonUnescapeAscii), @LBuf[0], LErr);
    GErrorSink := LErr;
  end;
end;

procedure BenchJsonUnescapeControl(AIters: Int64);
var
  LIt: Int64;
  LBuf: TJsonPlainBuffer;
  LErr: TUnescapeError;
begin
  for LIt := 1 to AIters do
  begin
    GSizeSink := JsonUnescapeToBuffer(PAnsiChar(GJsonUnescapeControl), Length(GJsonUnescapeControl), @LBuf[0], LErr);
    GErrorSink := LErr;
  end;
end;

procedure BenchJsonUnescapeUnicode(AIters: Int64);
var
  LIt: Int64;
  LBuf: TJsonPlainBuffer;
  LErr: TUnescapeError;
begin
  for LIt := 1 to AIters do
  begin
    GSizeSink := JsonUnescapeToBuffer(PAnsiChar(GJsonUnescapeUnicode), Length(GJsonUnescapeUnicode), @LBuf[0], LErr);
    GErrorSink := LErr;
  end;
end;

procedure BenchJsonFindEndAscii(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := JsonFindStringEnd(PAnsiChar(GJsonFindAscii), Length(GJsonFindAscii));
end;

procedure BenchJsonFindEndEscaped(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := JsonFindStringEnd(PAnsiChar(GJsonFindEscaped), Length(GJsonFindEscaped));
end;

procedure BenchJsonFindEndUnicode(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSink := JsonFindStringEnd(PAnsiChar(GJsonFindUnicode), Length(GJsonFindUnicode));
end;

begin
  InitFindBuffers;
  InitWhitespaceBuffers;
  InitSubstringBuffer;
  InitJsonSamples;

  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.text scan + escape benchmark ===');
  WriteLn;

  WriteLn('--- ScanFindByte ---');
  B.Run('ScanFindByte small 32B', @BenchFindByteSmall);
  B.Run('ScanFindByte medium 256B', @BenchFindByteMedium);
  B.Run('ScanFindByte large 4096B', @BenchFindByteLarge);
  PrintFocusThroughput('ScanFindByte small 32B', SMALL_FIND_LEN, @BenchFindByteSmall);
  PrintFocusThroughput('ScanFindByte medium 256B', MEDIUM_FIND_LEN, @BenchFindByteMedium);
  PrintFocusThroughput('ScanFindByte large 4096B', LARGE_FIND_LEN, @BenchFindByteLarge);
  WriteLn;

  WriteLn('--- ScanSkipWhitespace ---');
  B.Run('ScanSkipWhitespace small 32B', @BenchSkipWhitespaceSmall);
  B.Run('ScanSkipWhitespace medium 256B', @BenchSkipWhitespaceMedium);
  B.Run('ScanSkipWhitespace large 4096B', @BenchSkipWhitespaceLarge);
  PrintFocusThroughput('ScanSkipWhitespace small 32B', SMALL_FIND_LEN, @BenchSkipWhitespaceSmall);
  PrintFocusThroughput('ScanSkipWhitespace medium 256B', MEDIUM_FIND_LEN, @BenchSkipWhitespaceMedium);
  PrintFocusThroughput('ScanSkipWhitespace large 4096B', LARGE_FIND_LEN, @BenchSkipWhitespaceLarge);
  WriteLn;

  WriteLn('--- ScanFindSubstring ---');
  B.Run('ScanFindSubstring 4096B haystack', @BenchFindSubstring);
  WriteLn;

  WriteLn('--- JsonEscapeToBuffer ---');
  B.Run('JsonEscapeToBuffer ASCII', @BenchJsonEscapeAscii);
  B.Run('JsonEscapeToBuffer control chars', @BenchJsonEscapeControl);
  B.Run('JsonEscapeToBuffer Unicode UTF-8', @BenchJsonEscapeUnicode);
  WriteLn;

  WriteLn('--- JsonUnescapeToBuffer ---');
  B.Run('JsonUnescapeToBuffer ASCII', @BenchJsonUnescapeAscii);
  B.Run('JsonUnescapeToBuffer control chars', @BenchJsonUnescapeControl);
  B.Run('JsonUnescapeToBuffer Unicode escapes', @BenchJsonUnescapeUnicode);
  WriteLn;

  WriteLn('--- JsonFindStringEnd ---');
  B.Run('JsonFindStringEnd ASCII', @BenchJsonFindEndAscii);
  B.Run('JsonFindStringEnd escaped', @BenchJsonFindEndEscaped);
  B.Run('JsonFindStringEnd Unicode UTF-8', @BenchJsonFindEndUnicode);
  WriteLn;

  B.Summary;
  B.Free;
end.
