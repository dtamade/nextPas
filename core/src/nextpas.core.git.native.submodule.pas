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
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I:=0 to GitOidRawLen-1 do if AOid.Bytes[I]<>0 then Exit(False);
  Result:=True;
end;

function TrimSpaces(const S: string): string;
var A,B: Integer;
begin
  A:=1; B:=Length(S);
  while (A<=B) and (S[A] in [' ',#9,#10,#13]) do Inc(A);
  while (B>=A) and (S[B] in [' ',#9,#10,#13]) do Dec(B);
  if B<A then Exit('');
  Result:=Copy(S,A,B-A+1);
end;

function UnquoteValue(const S: string): string;
var T: string; I: Integer; C: Char;
begin
  T:=TrimSpaces(S);
  if (Length(T)>=2) and (T[1]='"') and (T[Length(T)]='"') then
  begin
    Result:='';
    I:=2;
    while I<Length(T) do
    begin
      C:=T[I];
      if C='\' then
      begin
        if I+1>=Length(T) then Break;
        Inc(I); C:=T[I];
        case C of
          'n': Result:=Result+#10;
          't': Result:=Result+#9;
          'b': Result:=Result+#8;
          '\': Result:=Result+'\';
          '"': Result:=Result+'"';
        else Result:=Result+C;
        end;
      end else Result:=Result+C;
      Inc(I);
    end;
  end else
  begin
    // strip trailing comment outside quotes (already handled by caller for this path)
    Result:=T;
  end;
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
var H,Inner: string; P1,P2: Integer;
begin
  H:=TrimSpaces(AHeader);
  // expect [submodule "name"]
  if (Length(H)<2) or (H[1]<>'[') or (H[Length(H)]<>']') then Exit('');
  Inner:=TrimSpaces(Copy(H,2,Length(H)-2));
  if Length(Inner)<9 then Exit('');
  // case-insensitive check for 'submodule'
  if LowerCase(Copy(Inner,1,9))<>'submodule' then Exit('');
  Inner:=TrimSpaces(Copy(Inner,10, MaxInt));
  if (Length(Inner)<2) or (Inner[1]<>'"') or (Inner[Length(Inner)]<>'"') then Exit('');
  Result:=Copy(Inner,2,Length(Inner)-2);
end;

function LowerKey(const S: string): string;
begin Result:=LowerCase(TrimSpaces(S)); end;

function LocalEndsWith(const S, Suffix: string): Boolean;
begin Result:=(Length(S)>=Length(Suffix)) and (Copy(S, Length(S)-Length(Suffix)+1, Length(Suffix))=Suffix); end;

function LocalSplitLines(const S: string): TStringArray;
var P,Start: Integer; Line: string;
begin
  Result:=nil; Start:=1;
  for P:=1 to Length(S)+1 do if (P>Length(S)) or (S[P]=#10) then
  begin Line:=Copy(S, Start, P-Start); SetLength(Result, Length(Result)+1); Result[High(Result)]:=Line; Start:=P+1; end;
end;

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
  Lines:=LocalSplitLines(AText);
  CurName:=''; HasCur:=False;
  Cur.Name:=''; Cur.Path:=''; Cur.Url:=''; Cur.Branch:='';
  for I:=0 to High(Lines) do
  begin
    Line:=Lines[I];
    // strip CR
    if (Length(Line)>0) and (Line[Length(Line)]=#13) then Delete(Line, Length(Line),1);
    Line:=TrimSpaces(Line);
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
    Val:=TrimSpaces(Copy(Line, EqPos+1, MaxInt));
    Val:=StripComment(Val);
    Val:=UnquoteValue(Val);
    if Key='path' then Cur.Path:=Val
    else if Key='url' then Cur.Url:=Val
    else if Key='branch' then Cur.Branch:=Val;
    // update/ignore others
  end;
  FlushCur;
end;

function GitParseGitModules(const AData: TBytes): TGitSubmoduleArray;
var S: string;
begin
  if Length(AData)=0 then Exit(nil);
  SetLength(S, Length(AData));
  Move(AData[0], S[1], Length(AData));
  Result:=GitParseGitModules(S);
end;

function WorktreeDir(const AGitDir: string): string;
var P: Integer;
begin
  if LocalEndsWith(AGitDir, '/.git') then Result:=Copy(AGitDir,1,Length(AGitDir)-5)
  else if LocalEndsWith(AGitDir, '.git') then
  begin
    // bare? use parent heuristic: strip last component
    P:=Length(AGitDir);
    while (P>0) and (AGitDir[P]<>'/') do Dec(P);
    if P>0 then Result:=Copy(AGitDir,1,P-1) else Result:='.';
  end else Result:=AGitDir;
end;

function GitListSubmodules(const AGitDir: string): TGitSubmoduleArray;
var WDir, F: string; Data: TBytes;
begin
  // prefer worktree .gitmodules, fallback to HEAD tree
  WDir:=WorktreeDir(AGitDir);
  F:=PathJoin2(WDir, '.gitmodules');
  if FileExists(F) then
  begin
    Data:=ReadFile(F);
    Exit(GitParseGitModules(Data));
  end;
  // fallback to HEAD
  try Result:=GitListSubmodulesAtRef(AGitDir, 'HEAD');
  except Result:=nil; end;
end;

function FindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean;
var Kind: TGitObjectKind; Data: TBytes; Entries: TGitTreeEntryArray; I: Integer;
begin
  Result:=False;
  if IsZeroOid(ATreeOid) then Exit;
  Data:=ARepo.ReadObject(ATreeOid, Kind);
  if Kind<>gokTree then Exit;
  Entries:=GitParseTree(Data);
  for I:=0 to High(Entries) do if Entries[I].Name=AName then
  begin AOid:=Entries[I].Oid; Result:=True; Exit; end;
end;

function PeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; CInfo: TGitCommitInfo; TInfo: TGitTagInfo; Depth: Integer;
begin
  Result:=AOid; Depth:=0;
  while Depth<16 do
  begin
    Data:=ARepo.ReadObject(Result, Kind);
    case Kind of
      gokCommit: begin CInfo:=GitParseCommit(Data); Result:=CInfo.Tree; Exit; end;
      gokTree: Exit;
      gokTag: begin TInfo:=GitParseTag(Data); Result:=TInfo.Target; Inc(Depth); end;
    else raise EGitError.CreateFmt('submodule: object %s is not a tree/commit/tag', [GitOidToHex(AOid)]);
    end;
  end;
  raise EGitError.Create('submodule: tag peel too deep');
end;

function GitListSubmodulesAtTree(const AGitDir: string; const ATreeOid: TGitOid): TGitSubmoduleArray;
var Repo: TNativeRepository; TreeOid, BlobOid: TGitOid; Kind: TGitObjectKind; Data: TBytes;
begin
  Result:=nil;
  if IsZeroOid(ATreeOid) then Exit;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    TreeOid:=ATreeOid;
    // if caller passed commit oid, peel to tree
    try
      Data:=Repo.ReadObject(TreeOid, Kind);
      if Kind=gokCommit then
      begin
        TreeOid:=PeelToTree(Repo, TreeOid);
      end else if Kind=gokTag then
      begin
        TreeOid:=PeelToTree(Repo, TreeOid);
      end;
    except
      // not found -> empty
      Exit;
    end;
    if not FindBlobInTree(Repo, TreeOid, '.gitmodules', BlobOid) then Exit;
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
  try TreeOid:=PeelToTree(Repo, Oid);
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
