unit nextpas.core.git.native.attributes;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Attributes subfamily: `.gitattributes` pattern → attribute map.

  Line format per `gitattributes(5)`:
    pattern attr1 attr2 ...
  where attr is `name`, `-name` (unset), `!name`, or `name=value`.
  Pattern uses `*`, `?`, `**` wildcards; if no `/` in pattern it matches
  basename, otherwise full path. Comments `#`/`;` and empty lines skipped.
  Last matching pattern wins (later lines override).

  Sources: worktree `.gitattributes` (root) preferred, fallback to
  `HEAD:.gitattributes`. Per-directory cascading is not yet implemented
  (future: walk ancestors). }

type
  TGitAttrKind = (akSet, akUnset, akValue);
  TGitAttr = record
    Name: string;
    Value: string;
    Kind: TGitAttrKind;
  end;
  TGitAttrArray = array of TGitAttr;

  TGitAttrEntry = record
    Pattern: string;
    Attrs: TGitAttrArray;
  end;
  TGitAttrEntries = array of TGitAttrEntry;

function GitParseAttributes(const AText: string): TGitAttrEntries; overload;
function GitParseAttributes(const AData: TBytes): TGitAttrEntries; overload;
function GitLoadAttributes(const AGitDir: string): TGitAttrEntries;
function GitAttributesFor(const AGitDir, APath: string): TGitAttrArray; overload;
function GitAttributesFor(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray; overload;
function GitAttributeGet(const AGitDir, APath, AName: string): string; overload;
function GitAttributeGet(const AEntries: TGitAttrEntries; const APath, AName: string): string; overload;
function GitHasAttribute(const AEntries: TGitAttrEntries; const APath, AName: string): Boolean; overload;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.wildmatch,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.util;

{ single-source pattern matching: delegates to wildmatch, zero-copy basename }
function AttrPatternMatches(const APattern, APath: string): Boolean; inline;
var
  Pat: string;
  HasSlash: Boolean;
  BStart: Integer;
begin
  if APattern='' then Exit(False);
  HasSlash:= GitHasUnescapedSlash(APattern);
  Pat:= APattern;
  if (Length(Pat)>0) and (Pat[1]='/') then
    Delete(Pat,1,1);
  if not HasSlash then
  begin
    BStart:= Length(APath);
    while (BStart>0) and (APath[BStart]<>'/') do Dec(BStart);
    Inc(BStart);
    Result:= GitWildSegmentRange(Pat,1,Length(Pat), APath,BStart,Length(APath)-BStart+1);
  end
  else
    Result:= GitSegmentsMatch(Pat, APath);
end;

function SplitWs(const S: string): TStringArray; inline;
var I,Start: Integer; InW: Boolean;
begin
  Result:=nil; Start:=1; InW:=False;
  for I:=1 to Length(S)+1 do
  begin
    if (I>Length(S)) or (S[I] in [' ',#9]) then
    begin
      if InW then begin SetLength(Result,Length(Result)+1); Result[High(Result)]:=Copy(S,Start,I-Start); InW:=False; end;
    end else
    begin
      if not InW then begin Start:=I; InW:=True; end;
    end;
  end;
end;

function TryParseAttrToken(const Tok: string; out AAttr: TGitAttr): Boolean;
var Eq: Integer; Name,Val: string;
begin
  if Tok='' then Exit(False);
  if Tok[1]='-' then
  begin
    Name:=Copy(Tok,2,MaxInt);
    if Name='' then Exit(False);
    AAttr.Name:= nextpas.core.text.conv.LowerCase(Name);
    AAttr.Value:='';
    AAttr.Kind:=akUnset;
    Exit(True);
  end;
  if Tok[1]='!' then
  begin
    Name:=Copy(Tok,2,MaxInt);
    if Name='' then Exit(False);
    AAttr.Name:= nextpas.core.text.conv.LowerCase(Name);
    AAttr.Value:='';
    AAttr.Kind:=akUnset;
    Exit(True);
  end;
  Eq:=Pos('=',Tok);
  if Eq>0 then
  begin
    Name:=Copy(Tok,1,Eq-1);
    Val:=Copy(Tok,Eq+1,MaxInt);
    if Name='' then Exit(False);
    AAttr.Name:= nextpas.core.text.conv.LowerCase(Name);
    AAttr.Value:=Val;
    AAttr.Kind:=akValue;
    Exit(True);
  end;
  AAttr.Name:= nextpas.core.text.conv.LowerCase(Tok);
  AAttr.Value:='';
  AAttr.Kind:=akSet;
  Result:=True;
end;

function GitParseAttributes(const AText: string): TGitAttrEntries;
var Lines: TStringArray; I,J: Integer; L,Pat: string; Tokens: TStringArray; Entry: TGitAttrEntry; Attr: TGitAttr;
begin
  Result:=nil;
  Lines:=GitSplitLines(AText);
  for I:=0 to High(Lines) do
  begin
    L:=GitTrimSpaces(GitStripCR(Lines[I]));
    if L='' then Continue;
    if (L[1]='#') or (L[1]=';') then Continue;
    Tokens:=SplitWs(L);
    if Length(Tokens)=0 then Continue;
    Pat:=Tokens[0];
    Entry.Pattern:=Pat;
    Entry.Attrs:=nil;
    for J:=1 to High(Tokens) do
      if TryParseAttrToken(Tokens[J], Attr) then
      begin SetLength(Entry.Attrs, Length(Entry.Attrs)+1); Entry.Attrs[High(Entry.Attrs)]:=Attr; end;
    SetLength(Result, Length(Result)+1);
    Result[High(Result)]:=Entry;
  end;
end;

function GitParseAttributes(const AData: TBytes): TGitAttrEntries;
var S: string;
begin
  if Length(AData)=0 then Exit(nil);
  SetLength(S, Length(AData));
  Move(AData[0], S[1], Length(AData));
  Result:=GitParseAttributes(S);
end;

function GitLoadAttributes(const AGitDir: string): TGitAttrEntries;
var WDir,F: string; Data: TBytes; Repo: TNativeRepository; Oid,TreeOid,BlobOid: TGitOid; Kind: TGitObjectKind;
begin
  Result:=nil;
  WDir:=GitWorktreeDir(AGitDir);
  F:=PathJoin2(WDir,'.gitattributes');
  if FileExists(F) then begin Data:=ReadFile(F); Exit(GitParseAttributes(Data)); end;
  try Oid:=GitRevParse(AGitDir,'HEAD'); except Exit(nil); end;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    try TreeOid:=GitPeelToTree(Repo,Oid); except Exit(nil); end;
    if not GitFindBlobInTree(Repo,TreeOid,'.gitattributes',BlobOid) then Exit(nil);
    Data:=Repo.ReadObject(BlobOid, Kind);
    if Kind<>gokBlob then Exit(nil);
    Result:=GitParseAttributes(Data);
  finally Repo.Free; end;
end;

function MergeAttrs(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray;
var I,J,K: Integer; E: TGitAttrEntry; Found: Boolean;
begin
  Result:=nil;
  for I:=0 to High(AEntries) do
  begin
    E:=AEntries[I];
    if not AttrPatternMatches(E.Pattern, APath) then Continue;
    for J:=0 to High(E.Attrs) do
    begin
      Found:=False;
      for K:=0 to High(Result) do if Result[K].Name=E.Attrs[J].Name then
      begin Result[K]:=E.Attrs[J]; Found:=True; Break; end;
      if not Found then begin SetLength(Result,Length(Result)+1); Result[High(Result)]:=E.Attrs[J]; end;
    end;
  end;
end;

function GitAttributesFor(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray;
begin
  Result:=MergeAttrs(AEntries, APath);
end;

function GitAttributesFor(const AGitDir, APath: string): TGitAttrArray;
var E: TGitAttrEntries;
begin
  E:=GitLoadAttributes(AGitDir);
  Result:=MergeAttrs(E, APath);
end;

function GitAttributeGet(const AEntries: TGitAttrEntries; const APath, AName: string): string;
var Arr: TGitAttrArray; I: Integer;
begin
  Arr:=MergeAttrs(AEntries, APath);
  for I:=0 to High(Arr) do if Arr[I].Name= nextpas.core.text.conv.LowerCase(AName) then
  begin
    case Arr[I].Kind of
      akSet: Exit('set');
      akUnset: Exit('unspecified');
      akValue: Exit(Arr[I].Value);
    end;
  end;
  Result:='unspecified';
end;

function GitAttributeGet(const AGitDir, APath, AName: string): string;
var E: TGitAttrEntries;
begin
  E:=GitLoadAttributes(AGitDir);
  Result:=GitAttributeGet(E, APath, AName);
end;

function GitHasAttribute(const AEntries: TGitAttrEntries; const APath, AName: string): Boolean;
var V: string;
begin
  V:=GitAttributeGet(AEntries, APath, AName);
  Result:=(V<>'unspecified');
end;

end.
