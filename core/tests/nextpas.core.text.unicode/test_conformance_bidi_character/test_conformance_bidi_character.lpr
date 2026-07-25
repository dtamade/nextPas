program test_conformance_bidi_character;
{**
 * Unicode 16.0 BidiCharacterTest harness (streaming).
 * Fixture: ../data/bidi_character_test.txt or bidi_character_test_smoke.txt
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.test,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.bidi;


function StrToIntDefLocal(const S: string; const ADefault: Integer = 0): Integer;
var
  V: Int64;
begin
  if TryStrToInt(S, V) then
    Result := Integer(V)
  else
    Result := ADefault;
end;

var
  T: TTestSuite;

function ResolveFixture(const AName: string): string;
begin
  if FileExists('../data/' + AName) then
    Exit('../data/' + AName);
  if FileExists('core/tests/nextpas.core.text.unicode/data/' + AName) then
    Exit('core/tests/nextpas.core.text.unicode/data/' + AName);
  Result := '../data/' + AName;
end;

function ParseHex(const AHex: string): TUnicodeCodepoint;
var
  I, D: Integer;
  V: UInt32;
begin
  V := 0;
  for I := 1 to Length(AHex) do
  begin
    case AHex[I] of
      '0'..'9': D := Ord(AHex[I]) - Ord('0');
      'a'..'f': D := Ord(AHex[I]) - Ord('a') + 10;
      'A'..'F': D := Ord(AHex[I]) - Ord('A') + 10;
    else
      D := 0;
    end;
    V := (V shl 4) or UInt32(D);
  end;
  Result := V;
end;

procedure ParseSpaceTokens(const AField: string; out AToks: array of string; out ACount: Integer);
var
  I, Start: Integer;
begin
  ACount := 0;
  Start := 1;
  for I := 1 to Length(AField) + 1 do
    if (I > Length(AField)) or (AField[I] = ' ') then
    begin
      if I > Start then
      begin
        Check(ACount < Length(AToks), 'token overflow');
        AToks[ACount] := Copy(AField, Start, I - Start);
        Inc(ACount);
      end;
      Start := I + 1;
    end;
end;

procedure TestBidiCharacter;
var
  LLines: TStringArray;
  LLineIdx: Integer;
  LPath: string;
  LLine: string;
  LLineNo, LChecked, LFail, I, Fld, Start, N, NT: Integer;
  LFields: array[0..4] of string;
  LCps: array of TUnicodeCodepoint;
  LCls: array of TBidiClass;
  LExpLevels: array of Integer;
  LExpReorder: array of Integer;
  LToks: array[0..511] of string;
  LRes: TBidiResolveResult;
  LOk: Boolean;
  LExpPara, LDir: Integer;
begin
  LPath := ResolveFixture('bidi_character_test.txt');
  if not FileExists(LPath) then
    LPath := ResolveFixture('bidi_character_test_smoke.txt');
  Check(FileExists(LPath), 'fixture exists: ' + LPath);

  LLines := ReadFileLines(LPath);
  LLineNo := 0;
  LChecked := 0;
  LFail := 0;
  for LLineIdx := 0 to High(LLines) do
  begin
    LLine := LLines[LLineIdx];
      Inc(LLineNo);
      if (LLine = '') or (LLine[1] = '#') then
        Continue;

      Fld := 0;
      Start := 1;
      for I := 1 to Length(LLine) + 1 do
        if (I > Length(LLine)) or (LLine[I] = ';') then
        begin
          if Fld <= 4 then
            LFields[Fld] := TextTrim(Copy(LLine, Start, I - Start));
          Inc(Fld);
          Start := I + 1;
        end;
      if Fld < 5 then
        Continue;

      ParseSpaceTokens(LFields[0], LToks, N);
      SetLength(LCps, N);
      SetLength(LCls, N);
      for I := 0 to N - 1 do
      begin
        LCps[I] := ParseHex(LToks[I]);
        LCls[I] := GetBidiClass(LCps[I]);
      end;

      LDir := StrToIntDefLocal(LFields[1], 2);
      LExpPara := StrToIntDefLocal(LFields[2], 0);

      ParseSpaceTokens(LFields[3], LToks, NT);
      CheckEqual(Int64(N), Int64(NT), TextFormat('level count line %d', [LLineNo]));
      SetLength(LExpLevels, N);
      for I := 0 to N - 1 do
        if LToks[I] = 'x' then
          LExpLevels[I] := -1
        else
          LExpLevels[I] := StrToInt(LToks[I]);

      ParseSpaceTokens(LFields[4], LToks, NT);
      SetLength(LExpReorder, NT);
      for I := 0 to NT - 1 do
        LExpReorder[I] := StrToInt(LToks[I]);

      LRes := ResolveBidiClassesWithBrackets(LCls, LCps, LDir);

      LOk := (LRes.ParagraphLevel = Byte(LExpPara)) and (Length(LRes.Levels) = N);
      if LOk then
        for I := 0 to N - 1 do
        begin
          if LExpLevels[I] < 0 then
          begin
            if LRes.Levels[I] <> BIDI_LEVEL_REMOVED then
              LOk := False;
          end
          else if Integer(LRes.Levels[I]) <> LExpLevels[I] then
            LOk := False;
        end;
      if LOk then
      begin
        if Length(LRes.VisualToLogical) <> Length(LExpReorder) then
          LOk := False
        else
          for I := 0 to High(LExpReorder) do
            if LRes.VisualToLogical[I] <> LExpReorder[I] then
              LOk := False;
      end;

      if not LOk then
      begin
        Inc(LFail);
        if LFail <= 30 then
          WriteLn(TextFormat('FAIL line %d dir=%d expPara=%d gotPara=%d',
            [LLineNo, LDir, LExpPara, LRes.ParagraphLevel]));
      end;
      Inc(LChecked);
  end;

  WriteLn(TextFormat('checked=%d fail=%d pass=%d', [LChecked, LFail, LChecked - LFail]));
  CheckEqual(Int64(0), Int64(LFail), TextFormat('bidi character failures: %d', [LFail]));
  Check(LChecked > 0, 'expected some bidi rows');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance.bidi_character');
  T.Test('BidiCharacterTest suite', @TestBidiCharacter);
  if not T.Run then
    Halt(1);
end.
