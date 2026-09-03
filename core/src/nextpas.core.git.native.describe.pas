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
  nextpas.core.git.native.revwalk,
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

function ShortHex(const AOid: TGitOid): string;
begin
  Result := Copy(GitOidToHex(AOid), 1, 7);
end;

function EffectiveTagOid(const AEntry: TGitTagEntry): TGitOid; inline;
begin
  if AEntry.IsAnnotated then
    Result := AEntry.PeeledOid
  else
    Result := AEntry.Oid;
end;

{ ── O(1) tag lookup: hash map oid -> name ────────────────────────────────
  Reuses single-source FNV hash over raw oid bytes (same as TGitOidSet),
  open-addressing power-of-two, linear probe, inline + zero-copy. No
  extra bytes.ops/wildmatch duplication; map built once per Describe. }

type
  TTagMap = record
    Keys: array of TGitOid;
    Values: array of string;
    Used: array of Boolean;
    CapMask: Integer;
    Count: Integer;
  end;

function TagMapHash(const AOid: TGitOid): SizeUInt; inline;
var I: Integer; H: LongWord;
begin
  // zero-copy FNV-1a over 20 raw bytes, no string allocation
  H := LongWord($811C9DC5);
  for I := 0 to GitOidRawLen - 1 do
  begin
    {$PUSH}{$Q-}{$R-}
    H := (H xor LongWord(AOid.Bytes[I])) * LongWord($01000193);
    {$POP}
  end;
  Result := SizeUInt(H);
end;

procedure TagMapInit(var AMap: TTagMap; ACap: Integer); inline;
var Cap, I: Integer;
begin
  // power-of-two capacity for mask probe, at least 16
  Cap := 16;
  while Cap < ACap do Cap := Cap shl 1;
  SetLength(AMap.Keys, Cap);
  SetLength(AMap.Values, Cap);
  SetLength(AMap.Used, Cap);
  for I := 0 to Cap - 1 do AMap.Used[I] := False;
  AMap.CapMask := Cap - 1;
  AMap.Count := 0;
end;

procedure TagMapGrow(var AMap: TTagMap);
var OldKeys: array of TGitOid; OldVals: array of string; OldUsed: array of Boolean;
    OldCap, NewCap, I, Idx: Integer; H: SizeUInt;
begin
  OldCap := Length(AMap.Keys);
  NewCap := OldCap shl 1;
  if NewCap < 16 then NewCap := 16;
  OldKeys := AMap.Keys;
  OldVals := AMap.Values;
  OldUsed := AMap.Used;
  SetLength(AMap.Keys, NewCap);
  SetLength(AMap.Values, NewCap);
  SetLength(AMap.Used, NewCap);
  for I := 0 to NewCap - 1 do AMap.Used[I] := False;
  AMap.CapMask := NewCap - 1;
  AMap.Count := 0;
  for I := 0 to OldCap - 1 do
    if OldUsed[I] then
    begin
      H := TagMapHash(OldKeys[I]);
      Idx := Integer(H and SizeUInt(AMap.CapMask));
      while AMap.Used[Idx] do Idx := (Idx + 1) and AMap.CapMask;
      AMap.Keys[Idx] := OldKeys[I];
      AMap.Values[Idx] := OldVals[I];
      AMap.Used[Idx] := True;
      Inc(AMap.Count);
    end;
end;

procedure TagMapAdd(var AMap: TTagMap; const AOid: TGitOid; const AName: string); inline;
var Idx: Integer; H: SizeUInt;
begin
  if Length(AMap.Keys) = 0 then TagMapInit(AMap, 16);
  if AMap.Count * 4 >= Length(AMap.Keys) * 3 then TagMapGrow(AMap);
  H := TagMapHash(AOid);
  Idx := Integer(H and SizeUInt(AMap.CapMask));
  while AMap.Used[Idx] do
  begin
    if GitOidSame(AMap.Keys[Idx], AOid) then Exit; // keep first tag name
    Idx := (Idx + 1) and AMap.CapMask;
  end;
  AMap.Keys[Idx] := AOid;
  AMap.Values[Idx] := AName;
  AMap.Used[Idx] := True;
  Inc(AMap.Count);
end;

function TagMapFind(const AMap: TTagMap; const AOid: TGitOid): string; inline;
var Idx: Integer; H: SizeUInt;
begin
  if Length(AMap.Keys) = 0 then Exit('');
  H := TagMapHash(AOid);
  Idx := Integer(H and SizeUInt(AMap.CapMask));
  while AMap.Used[Idx] do
  begin
    if GitOidSame(AMap.Keys[Idx], AOid) then Exit(AMap.Values[Idx]);
    Idx := (Idx + 1) and AMap.CapMask;
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
  I, FilteredCount, FilteredIdx: Integer;
  Queue: array of TQueueEntry;
  Head, QueueLen: Integer;
  Visited: TGitOidSet;
  TagMap: TTagMap;
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
  // filter annotated-only: pre-count once, single allocation O(n)
  if not AIncludeLightweight then
  begin
    FilteredCount := 0;
    for I := 0 to High(Tags) do
      if Tags[I].IsAnnotated then Inc(FilteredCount);
    if FilteredCount = 0 then
      Tags := nil
    else
    begin
      SetLength(Filtered, FilteredCount);
      FilteredIdx := 0;
      for I := 0 to High(Tags) do
        if Tags[I].IsAnnotated then
        begin
          Filtered[FilteredIdx] := Tags[I];
          Inc(FilteredIdx);
        end;
      Tags := Filtered;
    end;
  end;
  if Length(Tags) = 0 then
    raise EGitError.Create('no tag found');
  // build O(1) hash map oid->name: amortized O(tags), inline hash
  TagMapInit(TagMap, Length(Tags) * 2);
  for I := 0 to High(Tags) do
    TagMapAdd(TagMap, EffectiveTagOid(Tags[I]), Tags[I].Name);
  Repo := TNativeRepository.Create(AGitDir);
  Visited := TGitOidSet.Create;
  try
    StartOid := ResolveStartOid(AGitDir, ARef);
    Peeled := PeelToCommit(Repo, StartOid);
    // distance 0 check: O(1) hash lookup inline
    TagName := TagMapFind(TagMap, Peeled);
    if TagName <> '' then Exit(TagName);
    // BFS queue with geometric growth: amortized O(1) per enqueue, avoids O(n²) realloc
    QueueLen := 1;
    SetLength(Queue, 64);
    Queue[0].Oid := Peeled;
    Queue[0].Dist := 0;
    Head := 0;
    Visited.Add(Peeled);
    while Head < QueueLen do
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
        TagName := TagMapFind(TagMap, ParentOid); // inline O(1)
        if TagName <> '' then
        begin
          // distance is Cur.Dist + 1
          Result := TagName + '-' + IntToStr(Cur.Dist + 1) + '-g' + ShortHex(Peeled);
          Exit;
        end;
        // amortized doubling: zero per-parent SetLength(...+1)
        if QueueLen >= Length(Queue) then
          SetLength(Queue, Length(Queue) * 2);
        Queue[QueueLen].Oid := ParentOid;
        Queue[QueueLen].Dist := Cur.Dist + 1;
        Inc(QueueLen);
        // guard large histories
        if QueueLen > 100000 then
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
