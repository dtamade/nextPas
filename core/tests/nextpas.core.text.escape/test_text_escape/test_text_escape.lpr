program test_text_escape;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.escape,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.simd.vec,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestEscapeClean;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
begin
  Move('hello world', Src[0], 11);
  N := JsonEscapeToBuffer(@Src[0], 11, @Dst[0]);
  Dst[N] := #0;
  CheckEqual('hello world', string(PAnsiChar(@Dst[0])), 'clean passthrough');
  CheckEqual(Int64(11), Int64(N), 'len unchanged');
end;

procedure TestEscapeQuoteBackslash;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
begin
  Move('a"b\c', Src[0], 5);
  N := JsonEscapeToBuffer(@Src[0], 5, @Dst[0]);
  Dst[N] := #0;
  CheckEqual('a\"b\\c', string(PAnsiChar(@Dst[0])), 'quote+backslash');
end;

procedure TestEscapeControlChars;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
begin
  Src[0] := #9; Src[1] := #10; Src[2] := #13; Src[3] := #8; Src[4] := #12;
  N := JsonEscapeToBuffer(@Src[0], 5, @Dst[0]);
  Dst[N] := #0;
  CheckEqual('\t\n\r\b\f', string(PAnsiChar(@Dst[0])), 'named escapes');
end;

procedure TestEscapeNullByte;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
begin
  Src[0] := 'a'; Src[1] := #0; Src[2] := 'b';
  N := JsonEscapeToBuffer(@Src[0], 3, @Dst[0]);
  CheckEqual(Int64(8), Int64(N), 'len=8');
  Check(Dst[1] = '\', 'escape start');
  Check(Dst[2] = 'u', 'unicode escape');
  Check(Dst[7] = 'b', 'trailing b');
end;

procedure TestEscapeToBuilder;
var
  B: TStringBuilder;
  V: TStringView;
begin
  B.Init(64);
  V := TStringView.Create(PAnsiChar('he said "hi"'), 12);
  JsonEscapeToBuilder(V, B);
  CheckEqual('he said \"hi\"', B.ToString, 'builder escape');
  B.Done;
end;

procedure TestUnescapeBasic;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
  E: TUnescapeError;
const
  INPUT = 'hello \"world\"\\!';
begin
  Move(INPUT[1], Src[0], Length(INPUT));
  N := JsonUnescapeToBuffer(@Src[0], Length(INPUT), @Dst[0], E);
  Dst[N] := #0;
  Check(E = ueNone, 'no error');
  CheckEqual('hello "world"\!', string(PAnsiChar(@Dst[0])), 'unescape basic');
end;

procedure TestUnescapeNamedChars;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
  E: TUnescapeError;
const
  INPUT = '\t\n\r\b\f\/';
begin
  Move(INPUT[1], Src[0], Length(INPUT));
  N := JsonUnescapeToBuffer(@Src[0], Length(INPUT), @Dst[0], E);
  Check(E = ueNone, 'no error');
  Check(Dst[0] = #9, 'tab');
  Check(Dst[1] = #10, 'lf');
  Check(Dst[2] = #13, 'cr');
  Check(Dst[3] = #8, 'bs');
  Check(Dst[4] = #12, 'ff');
  Check(Dst[5] = '/', 'slash');
  CheckEqual(Int64(6), Int64(N), 'len=6');
end;

procedure TestUnescapeUnicode;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
  E: TUnescapeError;
const
  INPUT = 'é';
begin
  Move(INPUT[1], Src[0], Length(INPUT));
  N := JsonUnescapeToBuffer(@Src[0], Length(INPUT), @Dst[0], E);
  Check(E = ueNone, 'no error');
  Check(Byte(Dst[0]) = $C3, 'e-acute byte 0');
  Check(Byte(Dst[1]) = $A9, 'e-acute byte 1');
  CheckEqual(Int64(2), Int64(N), 'len=2 (UTF-8)');
end;

procedure TestUnescapeSurrogatePair;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
  E: TUnescapeError;
const
  INPUT = '😀';
begin
  Move(INPUT[1], Src[0], Length(INPUT));
  N := JsonUnescapeToBuffer(@Src[0], Length(INPUT), @Dst[0], E);
  Check(E = ueNone, 'no error');
  Check(Byte(Dst[0]) = $F0, 'emoji byte 0');
  Check(Byte(Dst[1]) = $9F, 'emoji byte 1');
  Check(Byte(Dst[2]) = $98, 'emoji byte 2');
  Check(Byte(Dst[3]) = $80, 'emoji byte 3');
  CheckEqual(Int64(4), Int64(N), 'len=4 (U+1F600)');
end;

procedure TestUnescapeErrors;
var
  Src, Dst: array[0..63] of AnsiChar;
  N: SizeUInt;
  E: TUnescapeError;
begin
  Src[0] := '\';
  N := JsonUnescapeToBuffer(@Src[0], 1, @Dst[0], E);
  Check(E = ueTruncated, 'truncated');

  Move('\x'#0, Src[0], 2);
  N := JsonUnescapeToBuffer(@Src[0], 2, @Dst[0], E);
  Check(E = ueInvalidEscape, 'invalid escape \x');

  Move('\u00GG'#0, Src[0], 6);
  N := JsonUnescapeToBuffer(@Src[0], 6, @Dst[0], E);
  Check(E = ueInvalidUnicode, 'invalid hex');

  Move('\uD800x'#0, Src[0], 7);
  N := JsonUnescapeToBuffer(@Src[0], 7, @Dst[0], E);
  Check(E = ueInvalidUnicode, 'lone surrogate');
end;

procedure TestUnescapeRejectsBareControlBytes;
var
  Src, Dst: array[0..127] of AnsiChar;
  N: SizeUInt;
  E: TUnescapeError;
  I: SizeUInt;
begin
  Src[0] := 'a';
  Src[1] := #10;
  Src[2] := 'b';
  N := JsonUnescapeToBuffer(@Src[0], 3, @Dst[0], E);
  Check(E = ueInvalidEscape, 'scalar bare control rejected');
  CheckEqual(Int64(1), Int64(N), 'scalar error offset');

  for I := 0 to VecWidth + 2 do
    Src[I] := 'x';
  Src[5] := #10;
  N := JsonUnescapeToBuffer(@Src[0], VecWidth + 3, @Dst[0], E);
  Check(E = ueInvalidEscape, 'SIMD bare control rejected');
  CheckEqual(Int64(5), Int64(N), 'SIMD error offset');
end;

procedure TestFindStringEnd;
begin
  CheckEqual(Int64(5), Int64(JsonFindStringEnd(PAnsiChar('hello"'), 6)), 'simple');
  CheckEqual(Int64(6), Int64(JsonFindStringEnd(PAnsiChar('he'#92'"lo"'), 7)), 'escaped quote');
  CheckEqual(Int64(-1), Int64(JsonFindStringEnd(PAnsiChar('no end'), 6)), 'no end');
  CheckEqual(Int64(0), Int64(JsonFindStringEnd(PAnsiChar('"'), 1)), 'immediate');
  CheckEqual(Int64(2), Int64(JsonFindStringEnd(PAnsiChar(#92#92'"'), 3)), 'escaped bs then quote');
end;

procedure TestEscapeLongString;
var
  Src: array[0..255] of AnsiChar;
  Dst: array[0..511] of AnsiChar;
  N: SizeUInt;
  I: Integer;
begin
  for I := 0 to 255 do
    Src[I] := 'a';
  Src[100] := '"';
  Src[200] := '\';
  N := JsonEscapeToBuffer(@Src[0], 256, @Dst[0]);
  Check(N = 258, 'long string: 256 + 2 extra escape chars');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.escape');
  T.Run('escape clean', @TestEscapeClean);
  T.Run('escape quote+backslash', @TestEscapeQuoteBackslash);
  T.Run('escape control chars', @TestEscapeControlChars);
  T.Run('escape null byte', @TestEscapeNullByte);
  T.Run('escape to builder', @TestEscapeToBuilder);
  T.Run('unescape basic', @TestUnescapeBasic);
  T.Run('unescape named chars', @TestUnescapeNamedChars);
  T.Run('unescape unicode', @TestUnescapeUnicode);
  T.Run('unescape surrogate pair', @TestUnescapeSurrogatePair);
  T.Run('unescape errors', @TestUnescapeErrors);
  T.Run('unescape rejects bare controls', @TestUnescapeRejectsBareControlBytes);
  T.Run('find string end', @TestFindStringEnd);
  T.Run('escape long string', @TestEscapeLongString);
  T.Summary;
end.
