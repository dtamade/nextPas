unit nextpas.core.git.native.submodule;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Submodule subfamily: `.gitmodules` INI + gitlink `$E000`.

  Parses `[submodule "name"]` sections (`path`/`url`/`branch`/`update`).
  Sources: worktree `.gitmodules` file or tree blob (HEAD:.gitmodules).
  Gitlink oid is read from tree/index when needed; this unit does not
  clone/fetch submodules. }

type
  TGitSubmodule = record
    Name: string;
    Path: string;
    Url: string;
    Branch: string;
  end;
  TGitSubmoduleArray = array of TGitSubmodule;

function GitParseGitModules(const AText: string): TGitSubmoduleArray; overload;
function GitParseGitModules(const AData: TBytes): TGitSubmoduleArray; overload;
function GitListSubmodules(const AGitDir: string): TGitSubmoduleArray;
function GitListSubmodulesAtTree(const AGitDir: string; const ATreeOid: TGitOid): TGitSubmoduleArray;
function GitListSubmodulesAtRef(const AGitDir, ARef: string): TGitSubmoduleArray;
function GitSubmoduleAtPath(const AGitDir, APath: string): TGitSubmodule;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.util;

function UnquoteValue(const S: string): string; inline;
var T: string; I, J, N: Integer; C: Char;
begin
  T:=GitTrimSpaces(S);
  if (Length(T)>=2) and (T[1]='"') and (T[Length(T)]='"') then
  begin
    N:=Length(T)-2;
    if N<=0 then Exit('');
    // perf: single SetLength(max) + pointer fill O(n) single alloc, zero-copy direct index (BytesCopy single Move single source pattern in bytes.ops), avoid O(n²) Result+=Char churn; inline hot path, owner bytes.ops
    SetLength(Result, N);
    J:=1;
    I:=2;
    while I<Length(T) do
    begin
      C:=T[I];
      if C='\' then
      begin
        if I+1>=Length(T) then Break;
        Inc(I); C:=T[I];
        case C of
          'n': Result[J]:=#10;
          't': Result[J]:=#9;
          'b': Result[J]:=#8;
          '\': Result[J]:='\';
          '"': Result[J]:='"';
        else Result[J]:=C;
        end;
        Inc(J);
      end else
      begin
        Result[J]:=C;
        Inc(J);
      end;
      Inc(I);
    end;
    if J-1<>N then SetLength(Result, J-1);
  end else
    Result:=T;
end;

function StripComment(const S: string): string;
var I: Integer; InQ: Boolean; C: Char;
begin
  InQ:=False; Result:=S;
  for I:=1 to Length(S) do
  begin
    C:=S[I];
    if C='"' then InQ:=not InQ
    else if not InQ and ((C='#') or (C=';')) then
    begin Result:=Copy(S,1,I-1); Break; end;
  end;
end;

function ExtractSubmoduleName(const AHeader: string): string;
var H,Inner: string;
begin
  H:=GitTrimSpaces(AHeader);
  if (Length(H)<2) or (H[1]<>'[') or (H[Length(H)]<>']') then Exit('');
  Inner:=GitTrimSpaces(Copy(H,2,Length(H)-2));
  if Length(Inner)<9 then Exit('');
  if LowerCase(Copy(Inner,1,9))<>'submodule' then Exit('');
  Inner:=GitTrimSpaces(Copy(Inner,10, MaxInt));
  if (Length(Inner)<2) or (Inner[1]<>'"') or (Inner[Length(Inner)]<>'"') then Exit('');
  Result:=Copy(Inner,2,Length(Inner)-2);
end;

function LowerKey(const S: string): string; inline;
begin Result:=LowerCase(GitTrimSpaces(S)); end;

function GitParseGitModules(const AText: string): TGitSubmoduleArray;
var Lines: TStringArray; I: Integer; Line, Key, Val, CurName: string; EqPos: Integer; Cur: TGitSubmodule; HasCur: Boolean;
  procedure FlushCur;
  begin
    if not HasCur then Exit;
    if Cur.Path<>'' then
    begin
      SetLength(Result, Length(Result)+1);
      Result[High(Result)]:=Cur;
    end;
    HasCur:=False; Cur.Name:=''; Cur.Path:=''; Cur.Url:=''; Cur.Branch:='';
  end;
begin
  Result:=nil;
  Lines:=GitSplitLines(AText);
  CurName:=''; HasCur:=False;
  Cur.Name:=''; Cur.Path:=''; Cur.Url:=''; Cur.Branch:='';
  for I:=0 to High(Lines) do
  begin
    Line:=Lines[I];
    Line:=GitStripCR(Line);
    Line:=GitTrimSpaces(Line);
    if Line='' then Continue;
    if (Line[1]='#') or (Line[1]=';') then Continue;
    if Line[1]='[' then
    begin
      FlushCur;
      CurName:=ExtractSubmoduleName(Line);
      if CurName<>'' then
      begin Cur.Name:=CurName; HasCur:=True; end;
      Continue;
    end;
    if not HasCur then Continue;
    EqPos:=Pos('=', Line);
    if EqPos=0 then Continue;
    Key:=LowerKey(Copy(Line,1,EqPos-1));
    Val:=GitTrimSpaces(Copy(Line, EqPos+1, MaxInt));
    Val:=StripComment(Val);
    Val:=UnquoteValue(Val);
    if Key='path' then Cur.Path:=Val
    else if Key='url' then Cur.Url:=Val
    else if Key='branch' then Cur.Branch:=Val;
  end;
  FlushCur;
end;

function GitParseGitModules(const AData: TBytes): TGitSubmoduleArray;
begin
  if Length(AData)=0 then Exit(nil);
  // perf: inline single source via bytes.ops.BytesToString (single Move in owner, zero-copy TByteSpan view, inline hot path, owner bytes.ops)
  Result:=GitParseGitModules(nextpas.core.bytes.ops.BytesToString(AData));
end;

function GitListSubmodules(const AGitDir: string): TGitSubmoduleArray;
var WDir, F: string; Data: TBytes;
begin
  WDir:=GitWorktreeDir(AGitDir);
  F:=PathJoin2(WDir, '.gitmodules');
  if FileExists(F) then
  begin
    Data:=ReadFile(F);
    Exit(GitParseGitModules(Data));
  end;
  try Result:=GitListSubmodulesAtRef(AGitDir, 'HEAD');
  except Result:=nil; end;
end;

function GitListSubmodulesAtTree(const AGitDir: string; const ATreeOid: TGitOid): TGitSubmoduleArray;
var Repo: TNativeRepository; TreeOid, BlobOid: TGitOid; Kind: TGitObjectKind; Data: TBytes;
begin
  Result:=nil;
  if GitIsZeroOid(ATreeOid) then Exit;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    TreeOid:=ATreeOid;
    try
      Data:=Repo.ReadObject(TreeOid, Kind);
      if Kind=gokCommit then
      begin
        TreeOid:=GitPeelToTree(Repo, TreeOid);
      end else if Kind=gokTag then
      begin
        TreeOid:=GitPeelToTree(Repo, TreeOid);
      end;
    except
      Exit;
    end;
    if not GitFindBlobInTree(Repo, TreeOid, '.gitmodules', BlobOid) then Exit;
    Data:=Repo.ReadObject(BlobOid, Kind);
    if Kind<>gokBlob then Exit;
    Result:=GitParseGitModules(Data);
  finally Repo.Free; end;
end;

function GitListSubmodulesAtRef(const AGitDir, ARef: string): TGitSubmoduleArray;
var Oid: TGitOid; Repo: TNativeRepository; TreeOid: TGitOid;
begin
  if ARef='' then raise EGitError.Create('submodule: empty ref');
  try Oid:=GitRevParse(AGitDir, ARef);
  except Oid:=GitResolveRef(AGitDir, ARef); end;
  Repo:=TNativeRepository.Create(AGitDir);
  try TreeOid:=GitPeelToTree(Repo, Oid);
  finally Repo.Free; end;
  Result:=GitListSubmodulesAtTree(AGitDir, TreeOid);
end;

function GitSubmoduleAtPath(const AGitDir, APath: string): TGitSubmodule;
var All: TGitSubmoduleArray; I: Integer;
begin
  if APath='' then raise EGitError.Create('submodule: empty path');
  All:=GitListSubmodules(AGitDir);
  for I:=0 to High(All) do if All[I].Path=APath then Exit(All[I]);
  raise EGitError.CreateFmt('submodule: not found "%s"', [APath]);
end;

end.
