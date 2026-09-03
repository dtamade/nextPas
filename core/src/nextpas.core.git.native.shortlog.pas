unit nextpas.core.git.native.shortlog;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Shortlog subfamily: author aggregation à la `git shortlog -s -n`.
  Groups commits by Author Name+Email (case-sensitive),
  counts descending then name ascending, mirroring git's output. }

type
  TGitShortlogEntry = record
    AuthorName: string;
    AuthorEmail: string;
    Count: Integer;
    Commits: array of TGitOid; // in revwalk order (newest first)
  end;
  TGitShortlogArray = array of TGitShortlogEntry;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray; overload;
function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray; overload;
function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string; overload;
function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string; overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.builder,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.revparse;

function LocalTrim(const S: string): string;
var I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  J := Length(S);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if J < I then Result := '' else Result := Copy(S, I, J - I + 1);
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; TagInfo: TGitTagInfo; Depth: Integer;
begin
  Result := AOid; Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin TagInfo := GitParseTag(Data); Result := TagInfo.Target; Inc(Depth); end
    else if Kind = gokCommit then Exit
    else raise EGitError.CreateFmt('ref does not point to commit: %s', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('tag peel too deep');
end;

function ResolveStartOid(const AGitDir, ARef: string): TGitOid;
var R: string;
begin
  R := LocalTrim(ARef);
  if R = '' then Result := GitResolveHead(AGitDir)
  else
    try Result := GitRevParse(AGitDir, R);
    except Result := GitResolveRef(AGitDir, R); end;
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

function ShortKey(const AName, AEmail: string): string;
begin
  Result := AName + #0 + AEmail;
end;

function GitShortlogInternal(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray;
var
  Repo: TNativeRepository;
  StartOid, Peeled: TGitOid;
  Oids: TGitOidArray;
  I, J, K: Integer;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  Found: Integer;
  Entry: TGitShortlogEntry;
  LResLen, LResCap: Integer;
  LCapArr: array of Integer;
begin
  Result := nil;
  LResLen := 0;
  LResCap := 0;
  SetLength(LCapArr, 0);
  if AGitDir = '' then raise EGitError.Create('shortlog: gitdir empty');
  Repo := TNativeRepository.Create(AGitDir);
  try
    StartOid := ResolveStartOid(AGitDir, ARef);
    Peeled := PeelToCommit(Repo, StartOid);
    if AMaxCount < 0 then Oids := GitCollectCommits(Repo, [Peeled], -1)
    else Oids := GitCollectCommits(Repo, [Peeled], AMaxCount);
    // group: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
    for I := 0 to High(Oids) do
    begin
      Data := Repo.ReadObject(Oids[I], Kind);
      if Kind <> gokCommit then Continue;
      Info := GitParseCommit(Data);
      Found := -1;
      for J := 0 to LResLen - 1 do
        if (Result[J].AuthorName = Info.Author.Name) and (Result[J].AuthorEmail = Info.Author.Email) then
        begin Found := J; Break; end;
      if Found >= 0 then
      begin
        Inc(Result[Found].Count);
        if Result[Found].Count > Length(Result[Found].Commits) then
        begin
          LCapArr[Found] := BytesGrowCapacityInt(LCapArr[Found], Result[Found].Count);
          SetLength(Result[Found].Commits, LCapArr[Found]);
        end;
        Result[Found].Commits[Result[Found].Count - 1] := Oids[I];
      end
      else
      begin
        Entry.AuthorName := Info.Author.Name;
        Entry.AuthorEmail := Info.Author.Email;
        Entry.Count := 1;
        if LResLen + 1 > LResCap then
        begin
          LResCap := BytesGrowCapacityInt(LResCap, LResLen + 1);
          SetLength(Result, LResCap);
          SetLength(LCapArr, LResCap);
        end;
        LCapArr[LResLen] := BytesGrowCapacityInt(0, 1);
        SetLength(Entry.Commits, LCapArr[LResLen]);
        Entry.Commits[0] := Oids[I];
        Result[LResLen] := Entry;
        Inc(LResLen);
      end;
    end;
    // trim capacity slack to exact logical length
    if LResLen <> Length(Result) then
      SetLength(Result, LResLen);
    if LResLen <> Length(LCapArr) then
      SetLength(LCapArr, LResLen);
    for I := 0 to High(Result) do
      if Length(Result[I].Commits) <> Result[I].Count then
        SetLength(Result[I].Commits, Result[I].Count);
  finally
    Repo.Free;
  end;
  // sort: count descending, then name ascending, then email ascending
  for I := 1 to High(Result) do
  begin
    J := I;
    while J > 0 do
    begin
      K := 0;
      if Result[J-1].Count < Result[J].Count then K := 1
      else if Result[J-1].Count = Result[J].Count then
      begin
        K := LocalCompareStr(Result[J-1].AuthorName, Result[J].AuthorName);
        if K = 0 then K := LocalCompareStr(Result[J-1].AuthorEmail, Result[J].AuthorEmail);
        if K > 0 then K := 1 else K := 0;
      end;
      if K = 0 then Break;
      Entry := Result[J-1]; Result[J-1] := Result[J]; Result[J] := Entry;
      Dec(J);
    end;
  end;
end;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray;
begin
  Result := GitShortlogInternal(AGitDir, ARef, AMaxCount);
end;

function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray;
begin
  Result := GitShortlogInternal(AGitDir, '', AMaxCount);
end;

function FormatShortlog(const AEntries: TGitShortlogArray): string;
var
  I: Integer;
  B: TBufStringBuilder;
begin
  // perf: single allocation via text.builder zero-copy (single SetString from view), amortized O(n) vs S:=S+ O(n²)
  if Length(AEntries) = 0 then Exit('');
  B.Init(256);
  try
    for I := 0 to High(AEntries) do
    begin
      B.AppendInt(AEntries[I].Count);
      B.AppendChar(#9);
      B.AppendStr(AEntries[I].AuthorName);
      B.AppendStr(' <');
      B.AppendStr(AEntries[I].AuthorEmail);
      B.AppendStr('>'#10);
    end;
    Result := B.ToString;
  finally
    B.Done;
  end;
end;

function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string;
var E: TGitShortlogArray;
begin
  E := GitShortlogInternal(AGitDir, ARef, AMaxCount);
  Result := FormatShortlog(E);
end;

function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string;
begin
  Result := GitShortlogText(AGitDir, '', AMaxCount);
end;

end.
