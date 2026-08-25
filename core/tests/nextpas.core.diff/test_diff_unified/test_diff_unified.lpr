program test_diff_unified;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.process,
  nextpas.core.diff.base,
  nextpas.core.diff.myers,
  nextpas.core.diff.unified;

var
  GDir: string;

function BytesOfString(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

function SameLines(const AA, AB: TStringArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then
    Exit;
  for I := 0 to High(AA) do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

{ Rebuild the new-side line array by applying parsed hunks to the old side. }
function ReconstructNew(const AOld: TStringArray;
  const AHunks: TDiffHunkArray): TStringArray;
var
  H, L, Oi, Count, ExpectedStart: Integer;
begin
  Result := nil;
  Count := 0;
  Oi := 0;
  for H := 0 to Length(AHunks) - 1 do
  begin
    ExpectedStart := AHunks[H].OldStart - 1;
    while (Oi < ExpectedStart) and (Oi < Length(AOld)) do
    begin
      SetLength(Result, Count + 1);
      Result[Count] := AOld[Oi];
      Inc(Count);
      Inc(Oi);
    end;
    for L := 0 to Length(AHunks[H].Lines) - 1 do
      with AHunks[H].Lines[L] do
        case Action of
          daEqual:
            begin
              SetLength(Result, Count + 1);
              Result[Count] := AOld[Oi];
              Inc(Count);
              Inc(Oi);
            end;
          daDelete:
            Inc(Oi);
          daInsert:
            begin
              SetLength(Result, Count + 1);
              Result[Count] := Text;
              Inc(Count);
            end;
        end;
  end;
  while Oi < Length(AOld) do
  begin
    SetLength(Result, Count + 1);
    Result[Count] := AOld[Oi];
    Inc(Count);
    Inc(Oi);
  end;
end;

procedure PutFile(const AName, AText: string);
begin
  WriteFile(PathJoin2(GDir, AName), BytesOfString(AText), PermDefault);
end;

{ Run git diff --no-index; exit code 1 means "differences found" and is
  the normal outcome here. }
function GoldenDiff(const AOldName, ANewName: string): string;
var
  Out: TProcessOutput;
begin
  Out := RunIn('git',
    ['diff', '--no-index', '-U3', '--', AOldName, ANewName], GDir);
  CheckTrue((Out.ExitCode = 0) or (Out.ExitCode = 1),
    'git diff ran (exit ' + IntToStr(Out.ExitCode) + ')');
  Result := Out.StdOut;
end;

{ Cross-check our hunks against git's golden output three ways:
  structure equality after parsing the golden text, byte-identical
  re-render of the parsed hunks, and a full apply-roundtrip. }
procedure CheckGolden(const ATag, AOldText, ANewText: string);
var
  OldLines, NewLines, Rebuilt: TStringArray;
  Golden, RenderedAgain: string;
  GoldHunks, OurHunks: TDiffHunkArray;
  H, L: Integer;
begin
  OldLines := DiffSplitLines(AOldText);
  NewLines := DiffSplitLines(ANewText);

  PutFile('a.txt', AOldText);
  PutFile('b.txt', ANewText);
  Golden := GoldenDiff('a.txt', 'b.txt');

  GoldHunks := ParseUnified(Golden);
  OurHunks := BuildHunks(DiffLines(OldLines, NewLines), OldLines, NewLines, 3);

  CheckTrue(Length(GoldHunks) = Length(OurHunks),
    ATag + ': hunk count matches git');
  if Length(GoldHunks) <> Length(OurHunks) then
    Exit;
  for H := 0 to High(GoldHunks) do
  begin
    CheckTrue(GoldHunks[H].OldStart = OurHunks[H].OldStart,
      ATag + ': hunk ' + IntToStr(H) + ' old start');
    CheckTrue(GoldHunks[H].OldCount = OurHunks[H].OldCount,
      ATag + ': hunk ' + IntToStr(H) + ' old count');
    CheckTrue(GoldHunks[H].NewStart = OurHunks[H].NewStart,
      ATag + ': hunk ' + IntToStr(H) + ' new start');
    CheckTrue(GoldHunks[H].NewCount = OurHunks[H].NewCount,
      ATag + ': hunk ' + IntToStr(H) + ' new count');
    CheckTrue(Length(GoldHunks[H].Lines) = Length(OurHunks[H].Lines),
      ATag + ': hunk ' + IntToStr(H) + ' line count');
    if Length(GoldHunks[H].Lines) = Length(OurHunks[H].Lines) then
      for L := 0 to High(GoldHunks[H].Lines) do
      begin
        CheckTrue(GoldHunks[H].Lines[L].Action = OurHunks[H].Lines[L].Action,
          ATag + ': hunk ' + IntToStr(H) + ' line ' + IntToStr(L) + ' action');
        CheckTrue(GoldHunks[H].Lines[L].Text = OurHunks[H].Lines[L].Text,
          ATag + ': hunk ' + IntToStr(H) + ' line ' + IntToStr(L) + ' text');
      end;
  end;

  // parse/emit symmetry on git's own output
  RenderedAgain := EmitUnifiedHunks(GoldHunks);
  CheckTrue(RenderedAgain = EmitUnifiedHunks(OurHunks),
    ATag + ': emit(parse(git)) == emit(ours)');

  // applying git's hunks must reproduce our new side exactly
  Rebuilt := ReconstructNew(OldLines, GoldHunks);
  CheckTrue(SameLines(Rebuilt, NewLines), ATag + ': roundtrip rebuild');
end;

{ ── exact emit bytes ─────────────────────────────────────────────────────── }

procedure TestEmitExactBytes;
var
  A, B: TStringArray;
begin
  A := TStringArray.Create('a', 'b', 'c');
  B := TStringArray.Create('a', 'x', 'c');
  CheckTrue(EmitUnified(A, B, 3) =
    '@@ -1,3 +1,3 @@' + #10 +
    ' a' + #10 +
    '-b' + #10 +
    '+x' + #10 +
    ' c' + #10, 'emit: exact substitution block');

  // single-line sides omit ",1" like git does
  CheckTrue(EmitUnified(TStringArray.Create('only'),
    TStringArray.Create('changed'), 3) =
    '@@ -1 +1 @@' + #10 +
    '-only' + #10 +
    '+changed' + #10, 'emit: single-line ranges drop ,1');

  // empty old side renders as 0,0 like git does for created content
  CheckTrue(EmitUnified(nil, TStringArray.Create('fresh', 'lines'), 3) =
    '@@ -0,0 +1,2 @@' + #10 +
    '+fresh' + #10 +
    '+lines' + #10, 'emit: empty old side is 0,0');
end;

procedure TestParseIgnoresHeadersAndMarkers;
var
  Patch: string;
  H: TDiffHunkArray;
begin
  Patch :=
    'diff --git a/f.txt b/f.txt' + #10 +
    'index 1234567..89abcde 100644' + #10 +
    '--- a/f.txt' + #10 +
    '+++ b/f.txt' + #10 +
    '@@ -1,2 +1,2 @@ some_func' + #10 +
    ' keep me' + #10 +
    '-drop me' + #10 +
    '\ No newline at end of file' + #10 +
    '+add me' + #10 +
    'tail context' + #10;
  H := ParseUnified(Patch);
  CheckTrue(Length(H) = 1, 'parse: one hunk from noisy patch');
  CheckTrue(H[0].OldStart = 1, 'parse: old start');
  // header counts decide the size: 2 old rows + 2 new rows sharing one
  // equal row -> exactly three content lines; "tail context" is noise
  CheckTrue(Length(H[0].Lines) = 3, 'parse: marker line not counted');
  CheckTrue(H[0].Lines[0].Action = daEqual, 'parse: ctx action');
  CheckTrue(H[0].Lines[0].Text = 'keep me', 'parse: ctx text keeps space off');
  CheckTrue(H[0].Lines[1].Action = daDelete, 'parse: del action');
  CheckTrue(H[0].Lines[2].Action = daInsert, 'parse: ins after marker');
end;

procedure TestParseEmptyPatch;
var
  H: TDiffHunkArray;
begin
  H := ParseUnified('');
  CheckTrue(Length(H) = 0, 'parse: empty input yields no hunks');
end;

{ ── golden cases vs system git ───────────────────────────────────────────── }

procedure TestGoldenSingleHunk;
begin
  CheckGolden('single',
    'alpha' + #10 + 'beta' + #10 + 'gamma' + #10 + 'delta' + #10 + 'epsilon' + #10,
    'alpha' + #10 + 'beta' + 'BETA' + #10 + 'gamma' + #10 + 'delta' + #10 + 'epsilon' + #10);
end;

procedure TestGoldenTwoDistantHunks;
var
  I: Integer;
  OldL, NewL: TStringArray;
begin
  SetLength(OldL, 20);
  for I := 0 to 19 do
    OldL[I] := 'line' + IntToStr(I + 1);
  NewL := Copy(OldL, 0, Length(OldL));
  // change line 2 and line 19: far apart -> two hunks
  NewL[1] := 'line2-changed';
  NewL[18] := 'line19-changed';
  CheckGolden('distant', DiffJoinLines(OldL), DiffJoinLines(NewL));
end;

procedure TestGoldenMergedNearbyChanges;
var
  I: Integer;
  OldL, NewL: TStringArray;
begin
  SetLength(OldL, 15);
  for I := 0 to 14 do
    OldL[I] := 'row' + IntToStr(I + 1);
  NewL := Copy(OldL, 0, Length(OldL));
  NewL[3] := 'row4-x';
  NewL[7] := 'row8-y';
  // gap between changes is rows 5..7 (3 lines <= 2*ctx): git merges them
  CheckGolden('merged', DiffJoinLines(OldL), DiffJoinLines(NewL));
end;

procedure TestGoldenUtf8;
begin
  CheckGolden('utf8',
    '第一行' + #10 + '第二行' + #10 + '第三行' + #10,
    '第一行' + #10 + '第二行已修改' + #10 + '第三行' + #10);
end;

procedure TestGoldenTailShrink;
begin
  CheckGolden('shrink',
    'one' + #10 + 'two' + #10 + 'three' + #10 + 'four' + #10 + 'five' + #10 + 'six' + #10,
    'one' + #10 + 'two' + #10 + 'three' + #10 + 'new-bottom' + #10);
end;

procedure TestGoldenFromEmptyOld;
begin
  CheckGolden('from-empty', '', 'brand' + #10 + 'new' + #10 + 'file' + #10);
end;

{ ── main ─────────────────────────────────────────────────────────────────── }

procedure SetupFixture;
begin
  GDir := PathJoin([GetTempDir,
    'nextpas_diff_' + IntToStr(GetProcessID)]);
  RemoveAll(GDir);
  MkdirAll(GDir, PermDirDefault);
end;

procedure CleanupFixture;
begin
  RemoveAll(GDir);
end;

var
  T: TTestSuite;
begin
  SetupFixture;
  try
    T := TTestSuite.Create('nextpas.core.diff.unified');
    T.Test('emit produces exact git-style bytes', @TestEmitExactBytes);
    T.Test('parser tolerates headers, funcname, newline markers',
      @TestParseIgnoresHeadersAndMarkers);
    T.Test('empty patch parses to nothing', @TestParseEmptyPatch);
    T.Test('golden: single hunk', @TestGoldenSingleHunk);
    T.Test('golden: two distant hunks stay separate',
      @TestGoldenTwoDistantHunks);
    T.Test('golden: nearby changes merge into one hunk',
      @TestGoldenMergedNearbyChanges);
    T.Test('golden: utf-8 content', @TestGoldenUtf8);
    T.Test('golden: tail shrink', @TestGoldenTailShrink);
    T.Test('golden: creation from empty old side', @TestGoldenFromEmptyOld);
    if not T.Run then Halt(1);
  finally
    CleanupFixture;
  end;
end.
