unit nextpas.core.git.native.refs;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base;

{ Ref resolution over loose refs (.git/<name> files), packed-refs, and HEAD.
  Also discovers the git directory walking upward from a working dir. }

function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean;
function GitDiscoverGitDir(const AStartDir: string): string;
{ True when APath itself has the git directory shape (HEAD/objects/refs).
  Unborn repos (HEAD symref with missing target) are not considered shape-valid;
  that prevents GitResolveHead throwing on every consumer. }
function IsGitDirShape(const APath: string): Boolean; inline;
function GitHeadRefName(const AGitDir: string): string; inline;
function GitResolveHead(const AGitDir: string): TGitOid;
function GitResolveRef(const AGitDir: string; const ARefName: string): TGitOid;
function GitTryResolveHead(const AGitDir: string; out AOid: TGitOid): Boolean; inline;
function GitTryResolveRef(const AGitDir: string; const ARefName: string; out AOid: TGitOid): Boolean; inline;

implementation

const
  CMaxSymDepth = 8;

function PackedRefExistsInline(const AGitDir, ARefName: string): Boolean; inline;
var
  Lines: TStringArray;
  I, Sp: Integer;
  Line, Name: string;
begin
  Result := False;
  if not FileExists(PathJoin2(AGitDir, 'packed-refs')) then
    Exit(False);
  try
    Lines := ReadFileLines(PathJoin2(AGitDir, 'packed-refs'));
  except
    Exit(False);
  end;
  for I := 0 to Length(Lines) - 1 do
  begin
    Line := Trim(Lines[I]);
    if (Line = '') or (Line[1] = '#') or (Line[1] = '^') then
      Continue;
    Sp := Pos(' ', Line);
    if Sp < 41 then
      Continue;
    Name := Trim(Copy(Line, Sp + 1, MaxInt));
    if Name = ARefName then
      Exit(True);
  end;
end;

function IsGitDirShape(const APath: string): Boolean; inline;
var
  LHead: string;
  LText: string;
begin
  if not DirectoryExists(PathJoin2(APath, 'objects')) then
    Exit(False);
  if not DirectoryExists(PathJoin2(APath, 'refs')) then
    Exit(False);
  if not FileExists(PathJoin2(APath, 'HEAD')) then
    Exit(False);
  try
    LText := Trim(ReadFileText(PathJoin2(APath, 'HEAD')));
  except
    Exit(False);
  end;
  if LText = '' then
    Exit(False);
  if Copy(LText, 1, 5) = 'ref: ' then
  begin
    LHead := Trim(Copy(LText, 6, MaxInt));
    if LHead = '' then
      Exit(False);
    // unborn: HEAD symref without object yet is still a valid git dir
    if FileExists(PathJoin2(APath, LHead)) then
      Exit(True);
    if PackedRefExistsInline(APath, LHead) then
      Exit(True);
    // allow unborn (no refs yet) as valid shape for Discover
    Exit(True);
  end;
  Result := GitOidIsValidHex(LText);
end;

// Resolves a ".git" entry that may be a real directory or a gitfile pointer.
// Worktree's gitdir (main/.git/worktrees/<id>) is valid via commondir, not IsGitDirShape.
function ResolveDotGitEntry(const ADotGit: string): string;
var
  Text, Target: string;
begin
  if DirectoryExists(ADotGit) then
    Exit(ADotGit);
  if not FileExists(ADotGit) then
    Exit('');
  Text := ReadFileText(ADotGit);
  if Copy(Text, 1, 7) <> 'gitdir:' then
    Exit('');
  Target := Trim(Copy(Text, 8, MaxInt));
  if Target = '' then
    Exit('');
  if not PathIsAbsolute(Target) then
    Target := PathJoin2(PathDir(ADotGit), Target);
  if IsGitDirShape(Target) then
    Exit(Target);
  if FileExists(PathJoin2(Target, 'commondir')) then
    Exit(Target);
  Result := '';
end;

function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean;
var
  P, DotGit: string;
begin
  Result := False;
  AGitDir := '';
  P := AStartDir;
  while P <> '' do
  begin
    DotGit := PathJoin2(P, '.git');
    AGitDir := ResolveDotGitEntry(DotGit);
    if AGitDir <> '' then
      Exit(True);
    // bare repository shape at P itself
    if IsGitDirShape(P) then
    begin
      AGitDir := P;
      Exit(True);
    end;
    if (P = '/') or (Length(P) <= 1) then
      Break;
    P := PathDir(P);
  end;
end;

function GitDiscoverGitDir(const AStartDir: string): string;
begin
  if not GitTryDiscoverGitDir(AStartDir, Result) then
    raise EGitError.CreateFmt(
      'not a git repository (or any parent): %s', [AStartDir]);
end;

function ReadRefFileText(const APath: string): string;
begin
  Result := Trim(ReadFileText(APath));
end;

procedure ParsePackedRefs(const AGitDir: string; const ARefName: string;
  out AOid: TGitOid; out AFound: Boolean);
var
  Lines: TStringArray;
  I, Sp: Integer;
  Line, Hex, Name: string;
begin
  AFound := False;
  if not FileExists(PathJoin2(AGitDir, 'packed-refs')) then
    Exit;
  Lines := ReadFileLines(PathJoin2(AGitDir, 'packed-refs'));
  for I := 0 to Length(Lines) - 1 do
  begin
    Line := Trim(Lines[I]);
    if (Line = '') or (Line[1] = '#') or (Line[1] = '^') then
      Continue;
    Sp := Pos(' ', Line);
    if Sp < 41 then
      Continue;
    Hex := Copy(Line, 1, Sp - 1);
    Name := Trim(Copy(Line, Sp + 1, MaxInt));
    if Name = ARefName then
    begin
      AOid := GitOidFromHex(Hex);
      AFound := True;
      Exit;
    end;
  end;
end;

function GitHeadRefName(const AGitDir: string): string; inline;
var
  Text: string;
begin
  Result := '';
  Text := ReadRefFileText(PathJoin2(AGitDir, 'HEAD'));
  if Copy(Text, 1, 5) = 'ref: ' then
    Result := Trim(Copy(Text, 6, MaxInt));
end;

function ResolveRefDepth(const AGitDir: string; const ARefName: string;
  ADepth: Integer): TGitOid;
var
  Path: string;
  Text: string;
  Found: Boolean;
begin
  if ADepth > CMaxSymDepth then
    raise EGitError.CreateFmt('symbolic ref chain too deep at "%s"',
      [ARefName]);
  Path := PathJoin2(AGitDir, ARefName);
  if FileExists(Path) then
  begin
    Text := ReadRefFileText(Path);
    if Copy(Text, 1, 5) = 'ref: ' then
      Exit(ResolveRefDepth(AGitDir, Trim(Copy(Text, 6, MaxInt)),
        ADepth + 1));
    Result := GitOidFromHex(Text);
    Exit;
  end;
  ParsePackedRefs(AGitDir, ARefName, Result, Found);
  if not Found then
    raise EGitError.CreateFmt('ref "%s" not found in %s', [ARefName, AGitDir]);
end;

function GitResolveRef(const AGitDir: string; const ARefName: string): TGitOid;
begin
  Result := ResolveRefDepth(AGitDir, ARefName, 0);
end;

function GitResolveHead(const AGitDir: string): TGitOid;
var
  RefName: string;
begin
  RefName := GitHeadRefName(AGitDir);
  if RefName = '' then
  begin
    // detached HEAD stores the raw oid
    Result := GitOidFromHex(
      ReadRefFileText(PathJoin2(AGitDir, 'HEAD')));
    Exit;
  end;
  Result := GitResolveRef(AGitDir, RefName);
end;

function GitTryResolveHead(const AGitDir: string; out AOid: TGitOid): Boolean; inline;
begin
  try
    AOid := GitResolveHead(AGitDir);
    Result := True;
  except
    on E: EGitError do
      Result := False;
  end;
end;

function GitTryResolveRef(const AGitDir: string; const ARefName: string; out AOid: TGitOid): Boolean; inline;
begin
  try
    AOid := GitResolveRef(AGitDir, ARefName);
    Result := True;
  except
    on E: EGitError do
      Result := False;
  end;
end;

end.
