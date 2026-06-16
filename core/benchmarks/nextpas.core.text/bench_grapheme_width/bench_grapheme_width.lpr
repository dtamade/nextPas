program bench_grapheme_width;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.text;

var
  B: TBenchRunner;
  GSizeSink: SizeUInt;
  GByteSink: Byte;
  GAsciiText: AnsiString;
  GCjkText: AnsiString;
  GEmojiText: AnsiString;

function BuildRepeated(const AValue: AnsiString; const ACount: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
    Result := Result + AValue;
end;

procedure InitSamples;
begin
  GAsciiText := BuildRepeated('HelloWorld1234', 32);
  GCjkText := BuildRepeated(#$E4#$B8#$AD#$E6#$96#$87#$E6#$B5#$8B#$E8#$AF#$95, 24);
  GEmojiText := BuildRepeated(
    #$F0#$9F#$91#$A8 + #$E2#$80#$8D + #$F0#$9F#$91#$A9 + #$E2#$80#$8D +
    #$F0#$9F#$91#$A7 + #$E2#$80#$8D + #$F0#$9F#$91#$A6, 12);
end;

procedure IterateGraphemes(const AData: AnsiString);
var
  LOffset: SizeUInt;
  LGR: TGraphemeResult;
begin
  LOffset := 0;
  while LOffset < SizeUInt(Length(AData)) do
  begin
    LGR := GraphemeNext(@PByte(PAnsiChar(AData))[LOffset], Length(AData) - LOffset);
    Inc(GSizeSink, SizeUInt(LGR.Width));
    Inc(LOffset, SizeUInt(LGR.ByteLen));
  end;
end;

procedure BenchGraphemeAscii(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    IterateGraphemes(GAsciiText);
end;

procedure BenchGraphemeCjk(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    IterateGraphemes(GCjkText);
end;

procedure BenchGraphemeEmoji(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    IterateGraphemes(GEmojiText);
end;

procedure BenchStringDisplayWidthAscii(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSizeSink := StringDisplayWidth(GAsciiText);
end;

procedure BenchStringDisplayWidthCjk(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSizeSink := StringDisplayWidth(GCjkText);
end;

procedure BenchStringDisplayWidthEmoji(AIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to AIters do
    GSizeSink := StringDisplayWidth(GEmojiText);
end;

procedure BenchCodepointWidth(AIters: Int64);
const
  CODEPOINTS: array[0..5] of UInt32 = (
    Ord('A'),
    $4E2D,
    $1F600,
    $0301,
    $200D,
    $1F1E6
  );
var
  LIt: Int64;
  LI: Integer;
begin
  for LIt := 1 to AIters do
    for LI := Low(CODEPOINTS) to High(CODEPOINTS) do
      GByteSink := CodepointWidth(CODEPOINTS[LI]);
end;

begin
  InitSamples;
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.text grapheme + width benchmark ===');
  WriteLn;

  WriteLn('--- GraphemeNext traversal ---');
  B.Run('GraphemeNext ASCII traversal', @BenchGraphemeAscii);
  B.Run('GraphemeNext CJK traversal', @BenchGraphemeCjk);
  B.Run('GraphemeNext emoji traversal', @BenchGraphemeEmoji);
  WriteLn;

  WriteLn('--- StringDisplayWidth ---');
  B.Run('StringDisplayWidth ASCII', @BenchStringDisplayWidthAscii);
  B.Run('StringDisplayWidth CJK', @BenchStringDisplayWidthCjk);
  B.Run('StringDisplayWidth emoji', @BenchStringDisplayWidthEmoji);
  WriteLn;

  WriteLn('--- CodepointWidth ---');
  B.Run('CodepointWidth mixed set', @BenchCodepointWidth);
  WriteLn;

  B.Summary;
  B.Free;
end.
