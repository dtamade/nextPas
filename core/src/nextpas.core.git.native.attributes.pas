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
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common,
  nextpas.core.git.native.util;

function TrimSpaces(const S: string): string;
var A,B: Integer;
begin
  A:=1; B:=Length(S);
  while (A<=B) and (S[A] in [' ',#9,#10,#13]) do Inc(A);
  while (B>=A) and (S[B] in [' ',#9,#10,#13]) do Dec(B);
  if B<A then Exit('');
  Result:=Copy(S,A,B-A+1);
end;

function StripCR(const S: string): string;
begin if (Length(S)>0) and (S[Length(S)]=#13) then Result:=Copy(S,1,Length(S)-1) else Result:=S; end;

// FindBlobInTree / PeelToTree reused from nextpas.core.git.native.common (single source)

// ---- pattern matching ----

function PreprocessPattern(const APat: string): string;
var I: Integer; R: string;
begin
  // Replace "**" with #1 (any including /), single "*" with #2 (any except /)
  R:='';
  I:=1;
  while I<=Length(APat) do
  begin
    if (APat[I]='*') and (I<Length(APat)) and (APat[I+1]='*') then
    begin
      R:=R+Chr(1);
      Inc(I,2);
      // optional single '/' after ** ? keep as is; **/ is handled as #1 + '/'
    end else if APat[I]='*' then
    begin R:=R+Chr(2); Inc(I); end
    else begin R:=R+APat[I]; Inc(I); end;
  end;
  Result:=R;
end;

function WildMatchRec(const Pat, Str: string; PI, SI: Integer; var Memo: array of Integer; PLen, SLen: Integer): Boolean;
var Res: Boolean;
  function MemoGet(p,s: Integer): Integer; begin Result:=Memo[p*(SLen+2)+s]; end;
  procedure MemoSet(p,s: Integer; V: Integer); begin Memo[p*(SLen+2)+s]:=V; end;
begin
  if MemoGet(PI,SI)<> -1 then Exit(MemoGet(PI,SI)=1);
  if PI>PLen then
  begin
    Res:=SI>SLen;
    MemoSet(PI,SI, Ord(Res));
    Exit(Res);
  end;
  if Pat[PI]=Chr(1) then // **
  begin
    // ** matches any sequence including /
    if WildMatchRec(Pat,Str,PI+1,SI,Memo,PLen,SLen) then begin MemoSet(PI,SI,1); Exit(True); end;
    if SI<=SLen then if WildMatchRec(Pat,Str,PI,SI+1,Memo,PLen,SLen) then begin MemoSet(PI,SI,1); Exit(True); end;
    MemoSet(PI,SI,0); Exit(False);
  end else if Pat[PI]=Chr(2) then // * matches any except /
  begin
    if WildMatchRec(Pat,Str,PI+1,SI,Memo,PLen,SLen) then begin MemoSet(PI,SI,1); Exit(True); end;
    if (SI<=SLen) and (Str[SI]<>'/') then if WildMatchRec(Pat,Str,PI,SI+1,Memo,PLen,SLen) then begin MemoSet(PI,SI,1); Exit(True); end;
    MemoSet(PI,SI,0); Exit(False);
  end else if Pat[PI]='?' then
  begin
    if (SI<=SLen) and (Str[SI]<>'/') then Res:=WildMatchRec(Pat,Str,PI+1,SI+1,Memo,PLen,SLen)
    else Res:=False;
    MemoSet(PI,SI, Ord(Res)); Exit(Res);
  end else
  begin
    if (SI<=SLen) and (Pat[PI]=Str[SI]) then Res:=WildMatchRec(Pat,Str,PI+1,SI+1,Memo,PLen,SLen)
    else Res:=False;
    MemoSet(PI,SI, Ord(Res)); Exit(Res);
  end;
end;

function AttrPatternMatches(const APattern, APath: string): Boolean;
var Pat,Str: string; Memo: array of Integer; PLen,SLen,I: Integer; HasSlash: Boolean;
begin
  if APattern='' then Exit(False);
  HasSlash:=Pos('/',APattern)>0;
  if not HasSlash then
  begin
    // match basename only
    Str:=APath;
    I:=Length(Str);
    while (I>0) and (Str[I]<>'/') do Dec(I);
    Str:=Copy(Str,I+1,MaxInt);
    Pat:=PreprocessPattern(APattern);
  end else
  begin
    Pat:=PreprocessPattern(APattern);
    Str:=APath;
    // handle leading '/' anchor: git treats "/foo" as anchored, but we treat as without '/'
    if (Length(Pat)>0) and (Pat[1]='/') then Pat:=Copy(Pat,2,MaxInt);
  end;
  PLen:=Length(Pat); SLen:=Length(Str);
  SetLength(Memo,(PLen+2)*(SLen+2));
  for I:=0 to High(Memo) do Memo[I]:=-1;
  Result:=WildMatchRec(Pat,Str,1,1,Memo,PLen,SLen);
end;

function SplitWs(const S: string): TStringArray;
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
    AAttr.Name:=LowerCase(Name);
    AAttr.Value:='';
    AAttr.Kind:=akUnset;
    Exit(True);
  end;
  if Tok[1]='!' then
  begin
    Name:=Copy(Tok,2,MaxInt);
    if Name='' then Exit(False);
    AAttr.Name:=LowerCase(Name);
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
    AAttr.Name:=LowerCase(Name);
    AAttr.Value:=Val;
    AAttr.Kind:=akValue;
    Exit(True);
  end;
  AAttr.Name:=LowerCase(Tok);
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
    L:=TrimSpaces(StripCR(Lines[I]));
    if L='' then Continue;
    if (L[1]='#') or (L[1]=';') then Continue;
    Tokens:=SplitWs(L);
    if Length(Tokens)=0 then Continue;
    Pat:=Tokens[0];
    // pattern may be quoted? gitattributes supports quoted pattern with spaces? ignore for now
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
  for I:=0 to High(Arr) do if Arr[I].Name=LowerCase(AName) then
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
