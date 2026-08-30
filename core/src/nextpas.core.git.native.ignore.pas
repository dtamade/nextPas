unit nextpas.core.git.native.ignore;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Gitignore pattern engine (pure logic, no filesystem access).
  Callers own discovery and lifetime: push one source per governing file
  in ascending precedence order (.git/info/exclude, then root .gitignore,
  then nested ones while descending), pop when leaving a directory.

  Semantics mirrored from git (gitignore(5) / wildmatch):
  - blank lines and leading-'#' comments are skipped; '\#' escapes
  - trailing unescaped spaces are trimmed
  - leading '!' negates; a later match wins over an earlier one, and a
    deeper source wins over a shallower one
  - trailing '/' makes the pattern directory-only
  - a pattern with an embedded '/' anchors to its source's base dir;
    otherwise it matches the path's final component at any depth
  - '*' and '?' never cross '/'; '[...]' classes support ranges and
    '^'/'!' negation; '\' escapes the next pattern character; '**'
    segments match zero or more whole directories

  Structural rule lives with the caller: once a directory reports
  ignored, pruning the subtree is what makes "!x/y" under an ignored
  "x/" ineffective, exactly like git's traversal. Tracked files are
  exempt because the caller only consults the engine for untracked
  candidates. Matching is byte-sensitive (core.ignorecase=false). }

type
  TGitIgnoreMatcher = class
  private type
    TPattern = record
      Text: string;     { pattern body after prefix/suffix handling }
      Negated: Boolean;
      DirOnly: Boolean;
      Anchored: Boolean;
    end;
    TSource = record
      BaseDir: string;  { worktree-relative owner dir, '' = root }
      Patterns: array of TPattern;
    end;
  private
    FSources: array of TSource;
    class procedure CompileLine(const ALine: string;
      out APattern: TPattern); static;
    class function WildSegment(const APattern, AName: string): Boolean; static; inline;
    class function SegmentsMatch(const APattern, APath: string): Boolean; static; inline;
  public
    { AText holds raw .gitignore-style lines; ABaseDir anchors embedded-
      slash patterns and scopes the whole source }
    procedure PushSource(const ABaseDir, AText: string);
    { drops the most recently pushed source }
    procedure PopSource;
    { ARelPath is worktree-relative with '/' separators; AIsDir selects
      whether directory-only patterns may fire. Paths outside every
      source's scope report False. }
    function IsIgnored(const ARelPath: string; AIsDir: Boolean): Boolean;
  end;

implementation

uses
  nextpas.core.git.native.wildmatch;

function CountTrailingBackslashesBefore(const AValue: string;
  APos: Integer): Integer; inline;
begin
  Result := 0;
  while (APos >= 1) and (AValue[APos] = '\') do
  begin
    Inc(Result);
    Dec(APos);
  end;
end;

function HasUnescapedChar(const AValue: string; AChar: Char): Boolean; inline;
var
  I: Integer;
begin
  Result := False;
  if AChar = '/' then
    Exit(GitHasUnescapedSlash(AValue));
  I := 1;
  while I <= Length(AValue) do
  begin
    if AValue[I] = '\' then
      Inc(I, 2)
    else
    begin
      if AValue[I] = AChar then
        Exit(True);
      Inc(I);
    end;
  end;
end;

function BasenameStart(const APath: string): Integer; inline;
var
  I: Integer;
begin
  for I := Length(APath) downto 1 do
    if APath[I] = '/' then
      Exit(I + 1);
  Result := 1;
end;

{ strips trailing unescaped spaces, gitignore(5) style }
function TrimTrailingSpaces(const AValue: string): string; inline;
begin
  Result := AValue;
  while (Length(Result) > 0) and (Result[Length(Result)] = ' ')
    and (CountTrailingBackslashesBefore(
      Result, Length(Result) - 1) mod 2 = 0) do
    Delete(Result, Length(Result), 1);
end;

{ single-source delegation: all fnmatch lives in wildmatch }
class function TGitIgnoreMatcher.WildSegment(
  const APattern, AName: string): Boolean;
begin
  Result := GitWildSegment(APattern, AName);
end;

class function TGitIgnoreMatcher.SegmentsMatch(
  const APattern, APath: string): Boolean;
begin
  Result := GitSegmentsMatch(APattern, APath);
end;

class procedure TGitIgnoreMatcher.CompileLine(const ALine: string;
  out APattern: TPattern);
var
  Body: string;
begin
  APattern.Text := '';
  APattern.Negated := False;
  APattern.DirOnly := False;
  APattern.Anchored := False;

  Body := TrimTrailingSpaces(ALine);
  if (Body = '') or (Body[1] = '#') then
    Exit;
  if Body[1] = '!' then
  begin
    APattern.Negated := True;
    Delete(Body, 1, 1);
  end;
  // unescaped trailing '/' restricts the pattern to directories
  if (Body <> '') and (Body[Length(Body)] = '/')
    and (CountTrailingBackslashesBefore(Body,
      Length(Body) - 1) mod 2 = 0) then
  begin
    APattern.DirOnly := True;
    Delete(Body, Length(Body), 1);
  end;
  if Body = '' then
    Exit;
  // a single leading '/' only marks anchoring; drop it
  APattern.Anchored := HasUnescapedChar(Body, '/');
  if Body[1] = '/' then
    Delete(Body, 1, 1);
  APattern.Text := Body;
end;

procedure TGitIgnoreMatcher.PushSource(const ABaseDir, AText: string);
var
  Src: TSource;
  Line: string;
  Start, I: Integer;
  Pat: TPattern;
begin
  Src.BaseDir := ABaseDir;
  // a trailing slash on the owner dir would break the scoping prefix test
  if (Length(Src.BaseDir) > 0)
    and (Src.BaseDir[Length(Src.BaseDir)] = '/') then
    Delete(Src.BaseDir, Length(Src.BaseDir), 1);
  Src.Patterns := nil;
  Start := 1;
  for I := 1 to Length(AText) + 1 do
  begin
    if (I > Length(AText)) or (AText[I] = #10) then
    begin
      Line := Copy(AText, Start, I - Start);
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        Delete(Line, Length(Line), 1);
      CompileLine(Line, Pat);
      if Pat.Text <> '' then
      begin
        SetLength(Src.Patterns, Length(Src.Patterns) + 1);
        Src.Patterns[High(Src.Patterns)] := Pat;
      end;
      Start := I + 1;
    end;
  end;
  SetLength(FSources, Length(FSources) + 1);
  FSources[High(FSources)] := Src;
end;

procedure TGitIgnoreMatcher.PopSource;
begin
  SetLength(FSources, Length(FSources) - 1);
end;

function TGitIgnoreMatcher.IsIgnored(const ARelPath: string;
  AIsDir: Boolean): Boolean;
var
  G, P: Integer;
  ScopeLen: Integer;
  Sub: string;
  BStart: Integer;
begin
  Result := False;
  // deepest source first; within a source the last pattern wins
  for G := High(FSources) downto 0 do
  begin
    if FSources[G].BaseDir = '' then
      Sub := ARelPath
    else
    begin
      ScopeLen := Length(FSources[G].BaseDir);
      if (Length(ARelPath) <= ScopeLen)
        or (Copy(ARelPath, 1, ScopeLen) <> FSources[G].BaseDir)
        or (ARelPath[ScopeLen + 1] <> '/') then
        Continue;
      Sub := Copy(ARelPath, ScopeLen + 2, MaxInt);
    end;
    for P := High(FSources[G].Patterns) downto 0 do
    begin
      if FSources[G].Patterns[P].DirOnly and not AIsDir then
        Continue;
      if FSources[G].Patterns[P].Anchored then
      begin
        if SegmentsMatch(FSources[G].Patterns[P].Text, Sub) then
          Exit(not FSources[G].Patterns[P].Negated);
      end
      else
      begin
        BStart := BasenameStart(Sub);
        if GitWildSegmentRange(FSources[G].Patterns[P].Text, 1,
          Length(FSources[G].Patterns[P].Text), Sub, BStart,
          Length(Sub) - BStart + 1) then
          Exit(not FSources[G].Patterns[P].Negated);
      end;
    end;
  end;
end;

end.
