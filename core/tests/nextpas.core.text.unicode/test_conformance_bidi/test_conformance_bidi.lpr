program test_conformance_bidi;
{**
 * Unicode 16.0 BidiTest.txt abstract conformance (streaming).
 * No brackets; uses ResolveBidiClasses only.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.test,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.bidi;


function StrToIntDefLocal(const S: string): Integer;
var
  V: Int64;
begin
  if TryStrToInt(S, V) then
    Result := Integer(V)
  else
    Result := 0;
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

function ParseClassName(const AName: string; out ACls: TBidiClass): Boolean;
begin
  Result := True;
  if AName = 'L' then ACls := bcL
  else if AName = 'R' then ACls := bcR
  else if AName = 'EN' then ACls := bcEN
  else if AName = 'ES' then ACls := bcES
  else if AName = 'ET' then ACls := bcET
  else if AName = 'AN' then ACls := bcAN
  else if AName = 'CS' then ACls := bcCS
  else if AName = 'B' then ACls := bcB
  else if AName = 'S' then ACls := bcS
  else if AName = 'WS' then ACls := bcWS
  else if AName = 'ON' then ACls := bcON
  else if AName = 'BN' then ACls := bcBN
  else if AName = 'NSM' then ACls := bcNSM
  else if AName = 'AL' then ACls := bcAL
  else if AName = 'LRE' then ACls := bcLRE
  else if AName = 'LRO' then ACls := bcLRO
  else if AName = 'RLE' then ACls := bcRLE
  else if AName = 'RLO' then ACls := bcRLO
  else if AName = 'PDF' then ACls := bcPDF
  else if AName = 'LRI' then ACls := bcLRI
  else if AName = 'RLI' then ACls := bcRLI
  else if AName = 'FSI' then ACls := bcFSI
  else if AName = 'PDI' then ACls := bcPDI
  else
    Result := False;
end;

procedure ParseTokens(const AField: string; out AToks: array of string; out ACount: Integer);
var
  I, Start: Integer;
begin
  ACount := 0;
  Start := 1;
  for I := 1 to Length(AField) + 1 do
    if (I > Length(AField)) or (AField[I] = ' ') or (AField[I] = #9) then
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

procedure TestBidiAbstract;
var
  LLines: TStringArray;
  LLineIdx: Integer;
  LPath: string;
  LLine, LLevelsLine, LReorderLine: string;
  LLineNo, LChecked, LFail, I, N, NT, Bitset, Dir: Integer;
  LToks: array[0..255] of string;
  LCls: array of TBidiClass;
  LExpLevels: array of Integer;
  LExpReorder: array of Integer;
  LRes: TBidiResolveResult;
  LOk: Boolean;
  LSemi: Integer;
  LInput, LBits: string;
  C: TBidiClass;
begin
  LPath := ResolveFixture('bidi_test.txt');
  Check(FileExists(LPath), 'fixture exists: ' + LPath);

  LLines := ReadFileLines(LPath);
  LLineNo := 0;
  LChecked := 0;
  LFail := 0;
  LLevelsLine := '';
  LReorderLine := '';
  for LLineIdx := 0 to High(LLines) do
  begin
    LLine := LLines[LLineIdx];
      Inc(LLineNo);
      if (LLine = '') or (LLine[1] = '#') then
        Continue;
      if (Length(LLine) >= 8) and (Copy(LLine, 1, 8) = '@Levels:') then
      begin
        LLevelsLine := TextTrim(Copy(LLine, 9, High(Integer)));
        Continue;
      end;
      if (Length(LLine) >= 9) and (Copy(LLine, 1, 9) = '@Reorder:') then
      begin
        LReorderLine := TextTrim(Copy(LLine, 10, High(Integer)));
        Continue;
      end;
      if LLine[1] = '@' then
        Continue;

      LSemi := Pos(';', LLine);
      if LSemi = 0 then
        Continue;
      LInput := TextTrim(Copy(LLine, 1, LSemi - 1));
      LBits := TextTrim(Copy(LLine, LSemi + 1, High(Integer)));
      Bitset := StrToIntDefLocal(LBits);

      ParseTokens(LInput, LToks, N);
      SetLength(LCls, N);
      for I := 0 to N - 1 do
      begin
        Check(ParseClassName(LToks[I], C), 'class ' + LToks[I]);
        LCls[I] := C;
      end;

      ParseTokens(LLevelsLine, LToks, NT);
      CheckEqual(Int64(N), Int64(NT), TextFormat('levels count line %d', [LLineNo]));
      SetLength(LExpLevels, N);
      for I := 0 to N - 1 do
        if LToks[I] = 'x' then
          LExpLevels[I] := -1
        else
          LExpLevels[I] := StrToInt(LToks[I]);

      ParseTokens(LReorderLine, LToks, NT);
      SetLength(LExpReorder, NT);
      for I := 0 to NT - 1 do
        LExpReorder[I] := StrToInt(LToks[I]);

      for Dir := 0 to 2 do
      begin
        { bitset: 1=auto(2), 2=LTR(0), 4=RTL(1) }
        case Dir of
          0: if (Bitset and 2) = 0 then Continue; { force LTR }
          1: if (Bitset and 4) = 0 then Continue; { force RTL }
          2: if (Bitset and 1) = 0 then Continue; { auto }
        end;

        LRes := ResolveBidiClasses(LCls, Dir);
        LOk := Length(LRes.Levels) = N;
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
          if LFail <= 15 then
            WriteLn(TextFormat('FAIL line %d dir=%d input=%s', [LLineNo, Dir, LInput]));
        end;
        Inc(LChecked);
      end;
  end;

  WriteLn(TextFormat('checked=%d fail=%d pass=%d', [LChecked, LFail, LChecked - LFail]));
  CheckEqual(Int64(0), Int64(LFail), TextFormat('bidi abstract failures: %d', [LFail]));
  Check(LChecked > 1000, TextFormat('expected many rows, got %d', [LChecked]));
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance.bidi');
  T.Test('BidiTest.txt abstract suite', @TestBidiAbstract);
  if not T.Run then
    Halt(1);
end.
