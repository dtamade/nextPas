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
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.revparse,
  nextpas.core.text.conv;

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

function LocalCompareStr(const A, B: string): Integer; inline;
var I, L: Integer;
begin
  // perf: inline + zero-copy char scan, single source for CompareShortlogEntry, avoids SysUtils overhead
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

function CompareShortlogEntry(const A, B: TGitShortlogEntry; AData: Pointer): SizeInt; inline;
begin
  // perf: inline comparator for collections.algorithms.Sort (IntroSort O(n log n), no per-call Temp), single source ordering
  if A.Count > B.Count then Exit(-1);
  if A.Count < B.Count then Exit(1);
  Result := LocalCompareStr(A.AuthorName, B.AuthorName);
  if Result <> 0 then Exit;
  Result := LocalCompareStr(A.AuthorEmail, B.AuthorEmail);
end;

function GitShortlogInternal(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray;
var
  Repo: TNativeRepository;
  StartOid, Peeled: TGitOid;
  Oids: TGitOidArray;
  I, J: Integer;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  Found: Integer;
  Entry: TGitShortlogEntry;
  ResultCount: SizeUInt;
  LCap, LNeed, LNewCap: SizeUInt;
begin
  Result := nil;
  if AGitDir = '' then raise EGitError.Create('shortlog: gitdir empty');
  Repo := TNativeRepository.Create(AGitDir);
  try
    StartOid := ResolveStartOid(AGitDir, ARef);
    Peeled := PeelToCommit(Repo, StartOid);
    if AMaxCount < 0 then Oids := GitCollectCommits(Repo, [Peeled], -1)
    else Oids := GitCollectCommits(Repo, [Peeled], AMaxCount);
    // group: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), avoids O(n²) SetLength(Length+1) churn, single shrink at end; zero-copy Oid record Move
    ResultCount := 0;
    for I := 0 to High(Oids) do
    begin
      Data := Repo.ReadObject(Oids[I], Kind);
      if Kind <> gokCommit then Continue;
      Info := GitParseCommit(Data);
      Found := -1;
      for J := 0 to Integer(ResultCount) - 1 do
        if (Result[J].AuthorName = Info.Author.Name) and (Result[J].AuthorEmail = Info.Author.Email) then
        begin Found := J; Break; end;
      if Found >= 0 then
      begin
        // perf: amortized doubling via bytes.ops GrowArrayCapacity (single source, BYTES_BUILDER_MIN_GROW + *2), O(1) amortized per append, zero-copy TGitOid Move (20B) via direct assignment
        Inc(Result[Found].Count);
        LNeed := SizeUInt(Result[Found].Count);
        LCap := SizeUInt(Length(Result[Found].Commits));
        if LCap < LNeed then
        begin
          LNewCap := GrowArrayCapacity(LCap, LNeed);
          SetLength(Result[Found].Commits, LNewCap);
        end;
        Result[Found].Commits[LNeed - 1] := Oids[I];
      end
      else
      begin
        Entry.AuthorName := Info.Author.Name;
        Entry.AuthorEmail := Info.Author.Email;
        Entry.Count := 1;
        Entry.Commits := nil;
        // perf: amortized geometric growth single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), avoids per-entry Length+1 churn
        LNewCap := GrowArrayCapacity(0, 1);
        SetLength(Entry.Commits, LNewCap);
        Entry.Commits[0] := Oids[I];
        // perf: outer array geometric growth single source via bytes.ops GrowArrayCapacity, amortized O(1), zero-copy record Move via assignment
        LNeed := ResultCount + 1;
        LCap := SizeUInt(Length(Result));
        if LCap < LNeed then
        begin
          LNewCap := GrowArrayCapacity(LCap, LNeed);
          SetLength(Result, LNewCap);
        end;
        Result[ResultCount] := Entry;
        Inc(ResultCount);
        Entry.Commits := nil; // break CoW share, avoids next new-alloc copy-on-write churn, zero-copy nil assign
      end;
    end;
  finally
    Repo.Free;
  end;
  // single shrink after grouping: bytes.ops single source geometric growth -> one SetLength to exact, avoids O(n²) jitter
  SetLength(Result, ResultCount);
  for I := 0 to High(Result) do
    if SizeUInt(Length(Result[I].Commits)) <> SizeUInt(Result[I].Count) then
      SetLength(Result[I].Commits, Result[I].Count);
  // sort: count descending, then name ascending, then email ascending — single source via collections.algorithms.Sort (IntroSort O(n log n) + Heap fallback, no per-call Temp)
  if Length(Result) > 1 then
    specialize Sort<TGitShortlogEntry>(Result, @CompareShortlogEntry, nil);
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
var I: Integer; S: string;
begin
  S := '';
  for I := 0 to High(AEntries) do
    S := S + IntToStr(AEntries[I].Count) + #9 + AEntries[I].AuthorName + ' <' + AEntries[I].AuthorEmail + '>' + #10;
  Result := S;
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
