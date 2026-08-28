unit nextpas.core.git.native.describe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Describe: nearest tag distance à la `git describe`.
  BFS over commit parents (shortest path) from peeled HEAD,
  first tagged ancestor wins. Annotated-only by default. }

function GitDescribe(const AGitDir: string): string; overload;
function GitDescribe(const AGitDir, ARef: string): string; overload;
function GitDescribeTags(const AGitDir: string): string; overload;
function GitDescribeTags(const AGitDir, ARef: string): string; overload;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.tag,
  nextpas.core.git.native.revwalk;

function LocalTrim(const S: string): string;
var I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  J := Length(S);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if J < I then Result := '' else Result := Copy(S, I, J - I + 1);
end;

function ShortHex(const AOid: TGitOid): string;
begin
  Result := Copy(GitOidToHex(AOid), 1, 7);
end;

function EffectiveTagOid(const AEntry: TGitTagEntry): TGitOid;
begin
  if AEntry.IsAnnotated then
    Result := AEntry.PeeledOid
  else
    Result := AEntry.Oid;
end;

function FindTagForOid(const AOid: TGitOid; const ATags: TGitTagArray): string;
var I: Integer; E: TGitOid;
begin
  for I := 0 to High(ATags) do
  begin
    E := EffectiveTagOid(ATags[I]);
    if GitOidSame(E, AOid) then Exit(ATags[I].Name);
  end;
  Result := '';
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  TagInfo: TGitTagInfo;
  Depth: Integer;
begin
  Result := AOid;
  Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin
      TagInfo := GitParseTag(Data);
      Result := TagInfo.Target;
      Inc(Depth);
    end
    else if Kind = gokCommit then Exit
    else raise EGitError.CreateFmt('ref does not point to commit: %s', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('tag peel too deep');
end;

function ResolveStartOid(const AGitDir, ARef: string): TGitOid;
var R: string;
begin
  R := LocalTrim(ARef);
  if R = '' then
    Result := GitResolveHead(AGitDir)
  else
  begin
    try
      Result := GitRevParse(AGitDir, R);
    except
      Result := GitResolveRef(AGitDir, R);
    end;
  end;
end;

type
  TQueueEntry = record
    Oid: TGitOid;
    Dist: Integer;
  end;

function DescribeInternal(const AGitDir, ARef: string; AIncludeLightweight: Boolean): string;
var
  Repo: TNativeRepository;
  StartOid, Peeled: TGitOid;
  Tags, Filtered: TGitTagArray;
  I: Integer;
  Queue: array of TQueueEntry;
  Head: Integer;
  Visited: TGitOidSet;
  Cur: TQueueEntry;
  TagName: string;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  ParentOid: TGitOid;
  P: Integer;
begin
  if AGitDir = '' then raise EGitError.Create('describe: gitdir empty');
  Tags := GitTagList(AGitDir);
  // filter
  if not AIncludeLightweight then
  begin
    SetLength(Filtered, 0);
    for I := 0 to High(Tags) do
      if Tags[I].IsAnnotated then
      begin
        SetLength(Filtered, Length(Filtered)+1);
        Filtered[High(Filtered)] := Tags[I];
      end;
    Tags := Filtered;
  end;
  if Length(Tags) = 0 then
    raise EGitError.Create('no tag found');
  Repo := TNativeRepository.Create(AGitDir);
  Visited := TGitOidSet.Create;
  try
    StartOid := ResolveStartOid(AGitDir, ARef);
    Peeled := PeelToCommit(Repo, StartOid);
    // distance 0 check
    TagName := FindTagForOid(Peeled, Tags);
    if TagName <> '' then Exit(TagName);
    SetLength(Queue, 1);
    Queue[0].Oid := Peeled;
    Queue[0].Dist := 0;
    Head := 0;
    Visited.Add(Peeled);
    while Head < Length(Queue) do
    begin
      Cur := Queue[Head];
      Inc(Head);
      // read parents of Cur
      try
        Data := Repo.ReadObject(Cur.Oid, Kind);
      except
        Continue;
      end;
      if Kind <> gokCommit then Continue;
      Info := GitParseCommit(Data);
      for P := 0 to High(Info.Parents) do
      begin
        ParentOid := Info.Parents[P];
        if Visited.Contains(ParentOid) then Continue;
        Visited.Add(ParentOid);
        TagName := FindTagForOid(ParentOid, Tags);
        if TagName <> '' then
        begin
          // distance is Cur.Dist + 1
          Result := TagName + '-' + IntToStr(Cur.Dist + 1) + '-g' + ShortHex(Peeled);
          Exit;
        end;
        SetLength(Queue, Length(Queue)+1);
        Queue[High(Queue)].Oid := ParentOid;
        Queue[High(Queue)].Dist := Cur.Dist + 1;
        // guard large histories
        if Length(Queue) > 100000 then
          raise EGitError.Create('describe: history too large');
      end;
    end;
    raise EGitError.Create('no tag found');
  finally
    Visited.Free;
    Repo.Free;
  end;
end;

function GitDescribe(const AGitDir: string): string;
begin
  Result := DescribeInternal(AGitDir, '', False);
end;

function GitDescribe(const AGitDir, ARef: string): string;
begin
  Result := DescribeInternal(AGitDir, ARef, False);
end;

function GitDescribeTags(const AGitDir: string): string;
begin
  Result := DescribeInternal(AGitDir, '', True);
end;

function GitDescribeTags(const AGitDir, ARef: string): string;
begin
  Result := DescribeInternal(AGitDir, ARef, True);
end;

end.
