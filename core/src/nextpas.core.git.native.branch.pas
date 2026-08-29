unit nextpas.core.git.native.branch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Branch subfamily: refs/heads/* local branches.
  List merges loose files (recursive scan) + packed-refs prefix,
  dedup loose-wins lexicographically sorted.
  Create/Delete operate on loose refs and maintain packed-refs. }

type
  TGitBranchEntry = record
    Name: string;    // e.g. "main" or "feature/x"
    RefName: string; // "refs/heads/<Name>"
    Oid: TGitOid;
  end;
  TGitBranchArray = array of TGitBranchEntry;

function GitBranchList(const AGitDir: string): TGitBranchArray;
function GitBranchExists(const AGitDir, ABranchName: string): Boolean;
function GitBranchGetOid(const AGitDir, ABranchName: string): TGitOid;
function GitBranchCurrent(const AGitDir: string): string;
function GitBranchIsDetached(const AGitDir: string): Boolean;
function GitBranchCreate(const AGitDir, ABranchName: string; const AOid: TGitOid): TGitOid;
function GitBranchCreateFromRef(const AGitDir, ABranchName, ARefName: string): TGitOid;
procedure GitBranchDelete(const AGitDir, ABranchName: string);
function GitBranchRename(const AGitDir, AOldName, ANewName: string): TGitOid;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.refs;

function LocalTrim(const S: string): string;
var I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  J := Length(S);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if J < I then Result := ''
  else Result := Copy(S, I, J - I + 1);
end;

function LocalCompareStr(const A, B: string): Integer;
var I, L: Integer;
begin
  L := Length(A);
  if Length(B) < L then L := Length(B);
  for I := 1 to L do
    if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

const
  HeadsPrefix = 'refs/heads/';

function BranchRefPath(const AGitDir, AName: string): string;
var N: string;
begin
  N := AName;
  if Copy(N, 1, Length(HeadsPrefix)) = HeadsPrefix then
    Delete(N, 1, Length(HeadsPrefix));
  if (Length(N) > 0) and (N[1] = '/') then Delete(N, 1, 1);
  Result := PathJoin([AGitDir, 'refs', 'heads', N]);
end;

function NormalizeBranchName(const AName: string): string;
begin
  Result := LocalTrim(AName);
  if Copy(Result, 1, Length(HeadsPrefix)) = HeadsPrefix then
    Delete(Result, 1, Length(HeadsPrefix));
  // strip leading slashes
  while (Length(Result) > 0) and (Result[1] = '/') do Delete(Result, 1, 1);
end;

function IsValidBranchName(const AName: string): Boolean;
var I: Integer; C: Char;
begin
  if AName = '' then Exit(False);
  if Pos('..', AName) > 0 then Exit(False);
  if Pos('//', AName) > 0 then Exit(False);
  if AName[1] = '.' then Exit(False);
  if AName[Length(AName)] = '/' then Exit(False);
  if AName[Length(AName)] = '.' then Exit(False);
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if C in ['~', '^', ':', '?', '*', '[', #0..#31, #127] then Exit(False);
  end;
  if Pos('@{', AName) > 0 then Exit(False);
  if Copy(AName, Length(AName) - 4, 5) = '.lock' then Exit(False);
  Result := True;
end;

procedure SortBranches(var A: TGitBranchArray);
var I, J: Integer; T: TGitBranchEntry;
begin
  for I := 1 to High(A) do
  begin
    J := I;
    while (J > 0) and (LocalCompareStr(A[J-1].Name, A[J].Name) > 0) do
    begin
      T := A[J-1]; A[J-1] := A[J]; A[J] := T;
      Dec(J);
    end;
  end;
end;

function ContainsName(const A: TGitBranchArray; const AName: string): Boolean;
var I: Integer;
begin
  for I := 0 to High(A) do if A[I].Name = AName then Exit(True);
  Result := False;
end;

procedure CollectFromDir(const AGitDir, ABaseDir, APrefix: string; var AOut: TGitBranchArray);
var
  Entries: TDirEntryArray;
  I: Integer;
  Full, Rel, RefName: string;
  Oid: TGitOid;
  Text: string;
begin
  try
    Entries := ReadDir(ABaseDir);
  except
    Exit;
  end;
  for I := 0 to High(Entries) do
  begin
    Full := PathJoin([ABaseDir, Entries[I].Name]);
    if Entries[I].IsDir then
    begin
      CollectFromDir(AGitDir, Full, APrefix + Entries[I].Name + '/', AOut);
    end
    else
    begin
      Rel := APrefix + Entries[I].Name;
      RefName := HeadsPrefix + Rel;
      try
        Text := LocalTrim(ReadFileText(Full));
        if Copy(Text, 1, 5) = 'ref: ' then
          Oid := GitResolveRef(AGitDir, RefName)
        else
          Oid := GitOidFromHex(Text);
      except
        Continue;
      end;
      if ContainsName(AOut, Rel) then Continue;
      SetLength(AOut, Length(AOut)+1);
      AOut[High(AOut)].Name := Rel;
      AOut[High(AOut)].RefName := RefName;
      AOut[High(AOut)].Oid := Oid;
    end;
  end;
end;

procedure CollectFromPacked(const AGitDir: string; var AOut: TGitBranchArray);
var
  Lines: TStringArray;
  I, Sp: Integer;
  Line, Hex, Name, Short: string;
  Oid: TGitOid;
begin
  if not FileExists(PathJoin([AGitDir, 'packed-refs'])) then Exit;
  try
    Lines := ReadFileLines(PathJoin([AGitDir, 'packed-refs']));
  except
    Exit;
  end;
  for I := 0 to High(Lines) do
  begin
    Line := LocalTrim(Lines[I]);
    if (Line = '') or (Line[1] = '#') or (Line[1] = '^') then Continue;
    Sp := Pos(' ', Line);
    if Sp < 41 then Continue;
    Hex := Copy(Line, 1, Sp - 1);
    Name := LocalTrim(Copy(Line, Sp + 1, MaxInt));
    if Copy(Name, 1, Length(HeadsPrefix)) <> HeadsPrefix then Continue;
    Short := Copy(Name, Length(HeadsPrefix)+1, MaxInt);
    if ContainsName(AOut, Short) then Continue;
    try
      Oid := GitOidFromHex(Hex);
    except
      Continue;
    end;
    SetLength(AOut, Length(AOut)+1);
    AOut[High(AOut)].Name := Short;
    AOut[High(AOut)].RefName := Name;
    AOut[High(AOut)].Oid := Oid;
  end;
end;

function GitBranchList(const AGitDir: string): TGitBranchArray;
var Base: string;
begin
  Result := nil;
  Base := PathJoin([AGitDir, 'refs', 'heads']);
  CollectFromDir(AGitDir, Base, '', Result);
  CollectFromPacked(AGitDir, Result);
  SortBranches(Result);
end;

function GitBranchExists(const AGitDir, ABranchName: string): Boolean;
var N: string;
begin
  N := NormalizeBranchName(ABranchName);
  try
    GitBranchGetOid(AGitDir, N);
    Result := True;
  except
    Result := False;
  end;
end;

function GitBranchGetOid(const AGitDir, ABranchName: string): TGitOid;
var N: string;
begin
  N := NormalizeBranchName(ABranchName);
  if not IsValidBranchName(N) then
    raise EGitError.CreateFmt('invalid branch name "%s"', [ABranchName]);
  Result := GitResolveRef(AGitDir, HeadsPrefix + N);
end;

function GitBranchCurrent(const AGitDir: string): string;
var T: string;
begin
  T := GitHeadRefName(AGitDir);
  if Copy(T, 1, Length(HeadsPrefix)) = HeadsPrefix then
    Result := Copy(T, Length(HeadsPrefix)+1, MaxInt)
  else
    Result := '';
end;

function GitBranchIsDetached(const AGitDir: string): Boolean;
begin
  Result := GitBranchCurrent(AGitDir) = '';
end;

procedure RewritePackedWithout(const AGitDir, ARefName: string);
var
  Path, Tmp: string;
  Lines, Keep: TStringArray;
  I: Integer;
  Line, Name: string;
  Sp: Integer;
begin
  Path := PathJoin([AGitDir, 'packed-refs']);
  if not FileExists(Path) then Exit;
  Lines := ReadFileLines(Path);
  SetLength(Keep, 0);
  I := 0;
  while I <= High(Lines) do
  begin
    Line := Lines[I];
    if (Line <> '') and (Line[1] <> '#') and (Line[1] <> '^') then
    begin
      Sp := Pos(' ', Line);
      if Sp >= 41 then
      begin
        Name := LocalTrim(Copy(Line, Sp + 1, MaxInt));
        if Name = ARefName then
        begin
          if (I + 1 <= High(Lines)) and (Length(Lines[I+1]) > 0) and (Lines[I+1][1] = '^') then
            Inc(I);
          Inc(I);
          Continue;
        end;
      end;
    end;
    SetLength(Keep, Length(Keep)+1);
    Keep[High(Keep)] := Line;
    Inc(I);
  end;
  // if no change, skip write
  if Length(Keep) = Length(Lines) then Exit;
  Tmp := Path + '.tmp';
  WriteFileLines(Tmp, Keep);
  Rename(Tmp, Path);
end;

function GitBranchCreate(const AGitDir, ABranchName: string; const AOid: TGitOid): TGitOid;
var
  N, Ref, Hex: string;
begin
  N := NormalizeBranchName(ABranchName);
  if not IsValidBranchName(N) then
    raise EGitError.CreateFmt('invalid branch name "%s"', [ABranchName]);
  if not GitOidIsValidHex(GitOidToHex(AOid)) then
    raise EGitError.Create('branch create: invalid oid');
  if GitBranchExists(AGitDir, N) then
    raise EGitError.CreateFmt('branch "%s" already exists', [N]);
  // verify oid exists? try to ensure object exists via loose/pack?
  Hex := GitOidToHex(AOid);
  Ref := BranchRefPath(AGitDir, N);
  MkdirAll(PathDir(Ref), PermDirDefault);
  WriteFileText(Ref, Hex + #10);
  // ensure packed-refs does not shadow delete? keep loose wins
  Result := AOid;
end;

function GitBranchCreateFromRef(const AGitDir, ABranchName, ARefName: string): TGitOid;
var Oid: TGitOid;
begin
  Oid := GitResolveRef(AGitDir, ARefName);
  Result := GitBranchCreate(AGitDir, ABranchName, Oid);
end;

procedure GitBranchDelete(const AGitDir, ABranchName: string);
var
  N, Ref, HeadRef: string;
  IsCurrent: Boolean;
begin
  N := NormalizeBranchName(ABranchName);
  if not IsValidBranchName(N) then
    raise EGitError.CreateFmt('invalid branch name "%s"', [ABranchName]);
  if not GitBranchExists(AGitDir, N) then
    raise EGitError.CreateFmt('branch "%s" not found', [N]);
  HeadRef := GitHeadRefName(AGitDir);
  IsCurrent := HeadRef = HeadsPrefix + N;
  if IsCurrent then
    raise EGitError.CreateFmt('cannot delete current branch "%s"', [N]);
  Ref := BranchRefPath(AGitDir, N);
  if FileExists(Ref) then
    Remove(Ref)
  else
    // packed-refs only: need to rewrite
    ;
  RewritePackedWithout(AGitDir, HeadsPrefix + N);
  // clean empty parent dirs under refs/heads/
  try
    while True do
    begin
      Ref := PathDir(Ref);
      if (Ref = PathJoin([AGitDir, 'refs', 'heads'])) or (Ref = PathJoin([AGitDir, 'refs'])) or (Ref = AGitDir) then Break;
      if DirectoryExists(Ref) then
      begin
        if Length(ReadDir(Ref)) = 0 then Remove(Ref)
        else Break;
      end
      else Break;
    end;
  except
    // ignore cleanup errors
  end;
end;

function GitBranchRename(const AGitDir, AOldName, ANewName: string): TGitOid;
var Oid: TGitOid;
begin
  Oid := GitBranchGetOid(AGitDir, AOldName);
  if GitBranchExists(AGitDir, ANewName) then
    raise EGitError.CreateFmt('branch "%s" already exists', [ANewName]);
  GitBranchCreate(AGitDir, ANewName, Oid);
  // if old was current, update HEAD symref
  if GitBranchCurrent(AGitDir) = NormalizeBranchName(AOldName) then
  begin
    WriteFileText(PathJoin([AGitDir, 'HEAD']), 'ref: ' + HeadsPrefix + NormalizeBranchName(ANewName) + #10);
  end;
  GitBranchDelete(AGitDir, AOldName);
  Result := Oid;
end;

end.
