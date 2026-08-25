program test_diff_myers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.diff.base,
  nextpas.core.diff.myers;

{ Soundness: replaying the script over both arrays must land exactly at
  their ends, with every equal pair matching. }
function Replay(const AOld, ANew: TStringArray;
  const AEdits: TDiffEditArray): Boolean;
var
  I, Oi, Nj: Integer;
begin
  Result := False;
  Oi := 0;
  Nj := 0;
  for I := 0 to Length(AEdits) - 1 do
  begin
    case AEdits[I].Action of
      daEqual:
        begin
          if (Oi >= Length(AOld)) or (Nj >= Length(ANew)) then
            Exit;
          if AOld[Oi] <> ANew[Nj] then
            Exit;
          Inc(Oi);
          Inc(Nj);
        end;
      daDelete:
        begin
          if Oi >= Length(AOld) then
            Exit;
          Inc(Oi);
        end;
      daInsert:
        begin
          if Nj >= Length(ANew) then
            Exit;
          Inc(Nj);
        end;
    end;
  end;
  Result := (Oi = Length(AOld)) and (Nj = Length(ANew));
end;

procedure CheckCounts(const AOld, ANew: TStringArray;
  const AEdits: TDiffEditArray; const ATag: string);
var
  I, NEq, NDel, NIns: Integer;
begin
  NEq := 0;
  NDel := 0;
  NIns := 0;
  for I := 0 to Length(AEdits) - 1 do
    case AEdits[I].Action of
      daEqual: Inc(NEq);
      daDelete: Inc(NDel);
      daInsert: Inc(NIns);
    end;
  CheckTrue(NEq + NDel = Length(AOld), ATag + ': old side accounting');
  CheckTrue(NEq + NIns = Length(ANew), ATag + ': new side accounting');
end;

function LcgNext(var AState: Cardinal): Cardinal;
begin
  AState := AState * 1664525 + 1013904223;
  Result := AState shr 16;
end;

{ ── exact cases ──────────────────────────────────────────────────────────── }

procedure TestIdenticalArrays;
var
  A: TStringArray;
  E: TDiffEditArray;
  I: Integer;
begin
  A := TStringArray.Create('one', 'two', 'three');
  E := DiffLines(A, A);
  CheckTrue(Length(E) = 3, 'identical: three edits');
  for I := 0 to 2 do
    CheckTrue(E[I].Action = daEqual, 'identical: all equal');
end;

procedure TestEmptySides;
var
  A: TStringArray;
  E: TDiffEditArray;
begin
  SetLength(A, 0);
  E := DiffLines(nil, nil);
  CheckTrue(Length(E) = 0, 'both empty: no edits');

  E := DiffLines(nil, TStringArray.Create('a', 'b'));
  CheckTrue(Length(E) = 2, 'empty old: two inserts');
  CheckTrue((E[0].Action = daInsert) and (E[1].Action = daInsert),
    'empty old: all inserts');

  A := TStringArray.Create('a', 'b');
  E := DiffLines(A, nil);
  CheckTrue(Length(E) = 2, 'empty new: two deletes');
  CheckTrue((E[0].Action = daDelete) and (E[1].Action = daDelete),
    'empty new: all deletes');
end;

procedure TestSingleSubstitutionMinimal;
var
  A, B: TStringArray;
  E: TDiffEditArray;
  Del, Ins: Integer;
  I: Integer;
begin
  A := TStringArray.Create('a', 'b', 'c');
  B := TStringArray.Create('a', 'x', 'c');
  E := DiffLines(A, B);
  // minimal script is exactly one delete + one insert
  CheckTrue(Length(E) = 4, 'subst: prefix+del+ins+suffix');
  Del := 0;
  Ins := 0;
  for I := 0 to High(E) do
  begin
    if E[I].Action = daDelete then
      Inc(Del);
    if E[I].Action = daInsert then
      Inc(Ins);
  end;
  CheckTrue(Del = 1, 'subst: exactly one delete');
  CheckTrue(Ins = 1, 'subst: exactly one insert');
  CheckCounts(A, B, E, 'subst');
  CheckTrue(Replay(A, B, E), 'subst: replay');
end;

procedure TestPrefixSuffixStripping;
var
  A, B: TStringArray;
  E: TDiffEditArray;
  I: Integer;
begin
  A := TStringArray.Create('x', 'm', 'n', 'y');
  B := TStringArray.Create('x', 'p', 'q', 'y');
  E := DiffLines(A, B);
  CheckTrue(E[0].Action = daEqual, 'strip: leading equal');
  CheckTrue(E[High(E)].Action = daEqual, 'strip: trailing equal');
  for I := 1 to High(E) - 1 do
    CheckTrue(E[I].Action <> daEqual, 'strip: middle changed');
  CheckTrue(Replay(A, B, E), 'strip: replay');
end;

procedure TestDuplicateRowsMinimal;
var
  A, B: TStringArray;
  E: TDiffEditArray;
  Del, I: Integer;
begin
  A := TStringArray.Create('r', 'r', 'r');
  B := TStringArray.Create('r', 'r');
  E := DiffLines(A, B);
  Del := 0;
  for I := 0 to High(E) do
    if E[I].Action = daDelete then
      Inc(Del);
  CheckTrue(Del = 1, 'dup rows: minimal single delete');
  CheckTrue(Replay(A, B, E), 'dup rows: replay');
end;

procedure TestLcsTextbookDistance;
var
  A, B: TStringArray;
  E: TDiffEditArray;
begin
  // CLRS classic: LCS("ABCBDAB","BDCABA") has length 4 ("BCBA"),
  // so the shortest script length is |A|+|B|-LCS = 7+6-4 = 9
  A := TStringArray.Create('A', 'B', 'C', 'B', 'D', 'A', 'B');
  B := TStringArray.Create('B', 'D', 'C', 'A', 'B', 'A');
  E := DiffLines(A, B);
  CheckTrue(Length(E) = 9, 'lcs: shortest script length is 9');
  CheckTrue(Replay(A, B, E), 'lcs: replay');
  CheckCounts(A, B, E, 'lcs');
end;

procedure TestUtf8Content;
var
  A, B: TStringArray;
  E: TDiffEditArray;
begin
  A := TStringArray.Create('首行', '中间行', '尾行');
  B := TStringArray.Create('首行', '改过的行', '尾行');
  E := DiffLines(A, B);
  CheckTrue(Replay(A, B, E), 'utf8: replay');
  CheckCounts(A, B, E, 'utf8');
  CheckTrue(Length(E) = 4, 'utf8: same shape as ascii substitution');
end;

{ ── randomized consistency ──────────────────────────────────────────────── }

procedure TestRandomFuzzReplayAndInvariants;
const
  Alphabet = 'abcde';
var
  Seed: Cardinal;
  Iter, LenO, LenN, I, P: Integer;
  A, B: TStringArray;
  E: TDiffEditArray;
begin
  Seed := $D1FF0001;
  for Iter := 1 to 60 do
  begin
    LenO := Iter mod 25;
    LenN := (Iter * 7 + 3) mod 30;
    SetLength(A, LenO);
    SetLength(B, LenN);
    for I := 0 to LenO - 1 do
    begin
      P := LcgNext(Seed) mod 5 + 1;
      A[I] := Copy(Alphabet, P, 1);
    end;
    for I := 0 to LenN - 1 do
    begin
      P := LcgNext(Seed) mod 5 + 1;
      B[I] := Copy(Alphabet, P, 1);
    end;
    E := DiffLines(A, B);
    if not Replay(A, B, E) then
    begin
      CheckTrue(False, 'fuzz iter ' + IntToStr(Iter) + ': replay');
      Exit;
    end;
  end;
  CheckTrue(True, 'fuzz: all 60 iterations replay');
end;

{ ── main ─────────────────────────────────────────────────────────────────── }

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.diff.myers');
  T.Test('identical arrays produce pure equals', @TestIdenticalArrays);
  T.Test('empty sides take fast paths', @TestEmptySides);
  T.Test('single substitution is minimal', @TestSingleSubstitutionMinimal);
  T.Test('common prefix/suffix stripped around changes',
    @TestPrefixSuffixStripping);
  T.Test('duplicate rows yield one delete', @TestDuplicateRowsMinimal);
  T.Test('textbook LCS distance honored', @TestLcsTextbookDistance);
  T.Test('utf-8 content works', @TestUtf8Content);
  T.Test('randomized fuzz replays clean', @TestRandomFuzzReplayAndInvariants);
  if not T.Run then Halt(1);
end.
