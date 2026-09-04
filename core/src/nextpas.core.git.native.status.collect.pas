unit nextpas.core.git.native.status.collect;

{$I nextpas.core.settings.inc}

{ status 收集域: 七参主入口编排 (stage0/renameset/索引/候选/配对/输出).
  扫描/未跟踪/配对 helpers 经 scan/untracked/match 域单源复用.
  依赖: base/scan/untracked/match (status.*) + L0-L1 owner + repo/index/refs/objmodel. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.status.base,
  nextpas.core.git.native.status.similarity;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.index,
  nextpas.core.git.native.ignore,
  nextpas.core.git.native.status.scan,
  nextpas.core.git.native.status.untracked,
  nextpas.core.git.native.status.match;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray;
var
  Repo: TNativeRepository;
  Idx: TGitIndexFile;
  HeadList: TPathOidArray;
  Tracked: TStringArray;
  HaveHead: Boolean;
  HeadCommit: TGitOid;
  CommitData: TBytes;
  ObjKind: TGitObjectKind;
  CommitInfo: TGitCommitInfo;
  I: Integer;
  Stage0Entries: array of TGitIndexEntry;
  Stage0Pos: array of Integer;
  Deletes: TPathOidArray;
  Adds: TPathOidArray;
  AddEntryPos: array of Integer;
  BothPaths: TPathOidArray;
  BothEntry: array of TGitIndexEntry;
  Candidates: TRenameCandidateArray;
  PairedSrc: array of Boolean;
  PairedDst: array of Boolean;
  RenamePairs: TRenameCandidateArray;
  CopyPairs: TRenameCandidateArray;
  TrackedStatus: TGitNativeStatusArray;
  LTrackedCount, LTrackedCap: SizeInt;
  LStatusCount, LStatusCap: SizeInt;
  LCandCount, LCandCap: SizeInt;
  LRenameCount, LRenameCap: SizeInt;
  LCopyCount, LCopyCap: SizeInt;
  DeleteSigs, AddSigs, HeadSigs: TBlobSigArray;
  LAddOidBuckets: array of Integer;
  LOidEntries: array of record AddIdx: Integer; Next: Integer; end;
  LAddOidCap: Integer;
  LHashHeads: array of Integer;
  LHashEntries: array of record Hash: UInt32; AddIdx: Integer; Next: Integer; end;
  LVisited: array of Boolean;
  LVisitedList: array of Integer;
  LVisitedCount: Integer;

  procedure BuildStage0;
  var
    K: Integer;
    LCount, LCap: SizeInt;
  begin
    Stage0Entries := nil;
    Stage0Pos := nil;
    LCount := 0;
    LCap := 0;
    for K := 0 to High(Idx.Entries) do
    begin
      if Idx.Entries[K].Stage <> 0 then Continue;
      if LCount = LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Stage0Entries, LCap);
        SetLength(Stage0Pos, LCap);
      end;
      Stage0Entries[LCount] := Idx.Entries[K];
      Stage0Pos[LCount] := K;
      Inc(LCount);
    end;
    if LCap <> LCount then
    begin
      SetLength(Stage0Entries, LCount);
      SetLength(Stage0Pos, LCount);
    end;
  end;

  procedure BuildRenameSets;
  var
    HI, SI: Integer;
    LDelCount, LDelCap: SizeInt;
    LAddCount, LAddCap: SizeInt;
    LBothCount, LBothCap: SizeInt;
    procedure EnsureDelCap;
    begin
      if LDelCount = LDelCap then
      begin
        LDelCap := SizeInt(GrowArrayCapacity(SizeUInt(LDelCap), SizeUInt(LDelCount + 1)));
        SetLength(Deletes, LDelCap);
      end;
    end;
    procedure EnsureAddCap;
    begin
      if LAddCount = LAddCap then
      begin
        LAddCap := SizeInt(GrowArrayCapacity(SizeUInt(LAddCap), SizeUInt(LAddCount + 1)));
        SetLength(Adds, LAddCap);
        SetLength(AddEntryPos, LAddCap);
      end;
    end;
    procedure EnsureBothCap;
    begin
      if LBothCount = LBothCap then
      begin
        LBothCap := SizeInt(GrowArrayCapacity(SizeUInt(LBothCap), SizeUInt(LBothCount + 1)));
        SetLength(BothPaths, LBothCap);
        SetLength(BothEntry, LBothCap);
      end;
    end;
  begin
    Deletes := nil; Adds := nil; AddEntryPos := nil; BothPaths := nil; BothEntry := nil;
    LDelCount := 0; LDelCap := 0; LAddCount := 0; LAddCap := 0; LBothCount := 0; LBothCap := 0;
    HI := 0; SI := 0;
    while (HI <= High(HeadList)) and (SI <= High(Stage0Entries)) do
    begin
      if CompareString(HeadList[HI].Path, Stage0Entries[SI].Path, nil) < 0 then
      begin
        EnsureDelCap; Deletes[LDelCount] := HeadList[HI]; Inc(LDelCount); Inc(HI);
      end
      else if CompareString(HeadList[HI].Path, Stage0Entries[SI].Path, nil) > 0 then
      begin
        EnsureAddCap;
        Adds[LAddCount].Path := Stage0Entries[SI].Path;
        Adds[LAddCount].Oid := Stage0Entries[SI].Oid;
        Adds[LAddCount].Mode := Stage0Entries[SI].Mode;
        AddEntryPos[LAddCount] := SI;
        Inc(LAddCount); Inc(SI);
      end
      else
      begin
        EnsureBothCap;
        BothPaths[LBothCount] := HeadList[HI];
        BothEntry[LBothCount] := Stage0Entries[SI];
        Inc(LBothCount); Inc(HI); Inc(SI);
      end;
    end;
    while HI <= High(HeadList) do
    begin EnsureDelCap; Deletes[LDelCount] := HeadList[HI]; Inc(LDelCount); Inc(HI); end;
    while SI <= High(Stage0Entries) do
    begin
      EnsureAddCap;
      Adds[LAddCount].Path := Stage0Entries[SI].Path;
      Adds[LAddCount].Oid := Stage0Entries[SI].Oid;
      Adds[LAddCount].Mode := Stage0Entries[SI].Mode;
      AddEntryPos[LAddCount] := SI;
      Inc(LAddCount); Inc(SI);
    end;
    if LDelCap <> LDelCount then SetLength(Deletes, LDelCount);
    if LAddCap <> LAddCount then begin SetLength(Adds, LAddCount); SetLength(AddEntryPos, LAddCount); end;
    if LBothCap <> LBothCount then begin SetLength(BothPaths, LBothCount); SetLength(BothEntry, LBothCount); end;
  end;

  procedure BuildAddIndexes;
  var
    II, KK, Bucket, DI2: Integer;
    HVal: UInt32;
    TotalHashes: Integer;
  begin
    LAddOidCap := 16;
    while LAddOidCap < Length(Adds) * 2 do LAddOidCap := LAddOidCap * 2;
    SetLength(LAddOidBuckets, LAddOidCap);
    SetLength(LOidEntries, Length(Adds));
    for II := 0 to LAddOidCap - 1 do LAddOidBuckets[II] := -1;
    for DI2 := 0 to High(Adds) do
    begin
      HVal := OidHash(Adds[DI2].Oid);
      if IsBlobMode(Adds[DI2].Mode) then HVal := HVal xor UInt32($9E3779B9);
      Bucket := Integer(HVal and UInt32(LAddOidCap - 1));
      LOidEntries[DI2].AddIdx := DI2;
      LOidEntries[DI2].Next := LAddOidBuckets[Bucket];
      LAddOidBuckets[Bucket] := DI2;
    end;
    TotalHashes := 0;
    for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then Inc(TotalHashes, AddSigs[DI2].Count);
    II := 16;
    while II < TotalHashes * 2 do II := II * 2;
    if II < 16 then II := 16;
    SetLength(LHashHeads, II);
    for KK := 0 to High(LHashHeads) do LHashHeads[KK] := -1;
    SetLength(LHashEntries, TotalHashes);
    KK := 0;
    for DI2 := 0 to High(Adds) do if AddSigs[DI2].Valid then
      for II := 0 to AddSigs[DI2].Count - 1 do
      begin
        Bucket := Integer(AddSigs[DI2].Hashes[II] and UInt32(Length(LHashHeads) - 1));
        LHashEntries[KK].Hash := AddSigs[DI2].Hashes[II];
        LHashEntries[KK].AddIdx := DI2;
        LHashEntries[KK].Next := LHashHeads[Bucket];
        LHashHeads[Bucket] := KK;
        Inc(KK);
      end;
    SetLength(LVisited, Length(Adds));
    SetLength(LVisitedList, Length(Adds));
    for II := 0 to High(LVisited) do LVisited[II] := False;
  end;

  procedure AppendUntrackedGroupToResult(var AResult: TGitNativeStatusArray);
  var
    LPaths: TStringArray;
    LStatus: TGitNativeStatusArray;
    LCount, LCap: SizeInt;
    LIgnore: TGitIgnoreMatcher;
    II: Integer;
  begin
    if not AIncludeUntracked then Exit;
    LPaths := nil;
    LIgnore := TGitIgnoreMatcher.Create;
    try
      PushInfoAndGlobalExcludes(LIgnore, AGitDir);
      CollectUntracked(AWorkTree, '', Tracked, LIgnore, LPaths);
    finally
      LIgnore.Free;
    end;
    SortStrings(LPaths);
    LStatus := nil;
    LCount := 0; LCap := 0;
    for II := 0 to High(LPaths) do
    begin
      if LCount = LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(LStatus, LCap);
      end;
      LStatus[LCount].Path := LPaths[II];
      LStatus[LCount].OldPath := '';
      LStatus[LCount].Similarity := 0;
      LStatus[LCount].HeadCode := gscUnmodified;
      LStatus[LCount].WorkCode := gscUntracked;
      Inc(LCount);
    end;
    if LCap <> LCount then SetLength(LStatus, LCount);
    AppendUntrackedGroup(AResult, LStatus);
  end;

var
  WC: TGitStatusCode;
  Cand: TRenameCandidate;
  Score: Integer;
  SI2, DI2: Integer;
  K, CK, J: Integer;

begin
  Result := nil;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Idx := GitReadIndex(AGitDir);
    HaveHead := True;
    try
      HeadCommit := GitResolveHead(AGitDir);
    except
      on E: EGitError do HaveHead := False;
    end;
    if HaveHead then
    begin
      CommitData := Repo.ReadObject(HeadCommit, ObjKind);
      if ObjKind <> gokCommit then raise EGitError.Create('HEAD does not point at a commit');
      CommitInfo := GitParseCommit(CommitData);
      FlattenTree(Repo, CommitInfo.Tree, '', HeadList);
    end;
    SortPathOids(HeadList);
    LTrackedCount := 0; LTrackedCap := 0; Tracked := nil;
    for I := 0 to High(Idx.Entries) do
      if (LTrackedCount = 0) or (Tracked[LTrackedCount - 1] <> Idx.Entries[I].Path) then
      begin
        if LTrackedCount = LTrackedCap then
        begin
          LTrackedCap := SizeInt(GrowArrayCapacity(SizeUInt(LTrackedCap), SizeUInt(LTrackedCount + 1)));
          SetLength(Tracked, LTrackedCap);
        end;
        Tracked[LTrackedCount] := Idx.Entries[I].Path;
        Inc(LTrackedCount);
      end;
    if LTrackedCap <> LTrackedCount then SetLength(Tracked, LTrackedCount);
    if (not HaveHead) or (not AFindRenames) then
    begin
      TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
      for K := 0 to High(Idx.Entries) do
      begin
        if Idx.Entries[K].Stage <> 0 then
        begin
          if (K = 0) or (Idx.Entries[K].Path <> Idx.Entries[K - 1].Path) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[K].Path, gscUnmerged, gscUnmerged);
          Continue;
        end;
      end;
      if not AFindRenames then
      begin
        BuildStage0; BuildRenameSets;
        for K := 0 to High(BothPaths) do
        begin
          WC := WorkCodeFor(AWorkTree, BothEntry[K]);
          if ModeClassOf(BothPaths[K].Mode) <> ModeClassOf(BothEntry[K].Mode) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscTypeChanged, WC)
          else if not GitOidSame(BothPaths[K].Oid, BothEntry[K].Oid) then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscModified, WC)
          else if WC <> gscUnmodified then
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscUnmodified, WC);
        end;
        for K := 0 to High(Deletes) do
          AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[K].Path, gscDeleted, gscUnmodified);
        for K := 0 to High(Adds) do
        begin
          WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[K]]);
          AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[K].Path, gscAdded, WC);
        end;
        if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
      end;
    end
    else
    begin
      for CK := 0 to High(Idx.Entries) do
        if Idx.Entries[CK].Stage <> 0 then
        begin
          TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
          for I := 0 to High(Idx.Entries) do
            if Idx.Entries[I].Stage <> 0 then
              if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
                AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
          BuildStage0; BuildRenameSets;
          for J := 0 to High(BothPaths) do
          begin
            WC := WorkCodeFor(AWorkTree, BothEntry[J]);
            if ModeClassOf(BothPaths[J].Mode) <> ModeClassOf(BothEntry[J].Mode) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscTypeChanged, WC)
            else if not GitOidSame(BothPaths[J].Oid, BothEntry[J].Oid) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscModified, WC)
            else if WC <> gscUnmodified then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[J].Path, gscUnmodified, WC);
          end;
          for J := 0 to High(Deletes) do
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[J].Path, gscDeleted, gscUnmodified);
          for J := 0 to High(Adds) do
          begin
            WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[J]]);
            AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[J].Path, gscAdded, WC);
          end;
          if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
          SortStatusByPath(TrackedStatus);
          Result := TrackedStatus;
          AppendUntrackedGroupToResult(Result);
          Exit;
        end;
    end;
    if (not HaveHead) or (not AFindRenames) then
    begin
      if not HaveHead then
      begin
        TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
        for I := 0 to High(Idx.Entries) do
        begin
          if Idx.Entries[I].Stage <> 0 then
          begin
            if (I = 0) or (Idx.Entries[I].Path <> Idx.Entries[I - 1].Path) then
              AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscUnmerged, gscUnmerged);
            Continue;
          end;
          WC := WorkCodeFor(AWorkTree, Idx.Entries[I]);
          AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Idx.Entries[I].Path, gscAdded, WC);
        end;
        if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
        SortStatusByPath(TrackedStatus);
        Result := TrackedStatus;
      end
      else
      begin
        if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
        Result := TrackedStatus;
      end;
      AppendUntrackedGroupToResult(Result);
      Exit;
    end;
    BuildStage0;
    BuildRenameSets;
    BuildBlobSigCache(Repo, Deletes, DeleteSigs);
    BuildBlobSigCache(Repo, Adds, AddSigs);
    Candidates := nil; LCandCount := 0; LCandCap := 0;
    if (Length(Deletes) > 0) and (Length(Adds) > 0) then
    begin
      BuildAddIndexes;
      for SI2 := 0 to High(Deletes) do
      begin
        if not IsBlobMode(Deletes[SI2].Mode) then Continue;
        LVisitedCount := 0;
        Score := Integer(OidHash(Deletes[SI2].Oid));
        if IsBlobMode(Deletes[SI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
        I := Integer(UInt32(Score) and UInt32(LAddOidCap - 1));
        DI2 := LAddOidBuckets[I];
        while DI2 <> -1 do
        begin
          K := LOidEntries[DI2].AddIdx;
          if GitOidSame(Deletes[SI2].Oid, Adds[K].Oid) and IsBlobMode(Adds[K].Mode) then
            if not LVisited[K] then
            begin LVisited[K] := True; LVisitedList[LVisitedCount] := K; Inc(LVisitedCount); end;
          DI2 := LOidEntries[DI2].Next;
        end;
        if DeleteSigs[SI2].Valid then
        begin
          if DeleteSigs[SI2].Count = 0 then
          begin
            for DI2 := 0 to High(Adds) do
              if AddSigs[DI2].Valid and (AddSigs[DI2].Count = 0) and IsBlobMode(Adds[DI2].Mode) then
                if not LVisited[DI2] then
                begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
          end
          else
          begin
            for I := 0 to DeleteSigs[SI2].Count - 1 do
            begin
              Score := Integer(DeleteSigs[SI2].Hashes[I] and UInt32(Length(LHashHeads) - 1));
              K := LHashHeads[Score];
              while K <> -1 do
              begin
                if LHashEntries[K].Hash = DeleteSigs[SI2].Hashes[I] then
                begin
                  DI2 := LHashEntries[K].AddIdx;
                  if not LVisited[DI2] then
                  begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
                end;
                K := LHashEntries[K].Next;
              end;
            end;
          end;
        end;
        for K := 0 to LVisitedCount - 1 do
        begin
          DI2 := LVisitedList[K];
          if not IsBlobMode(Adds[DI2].Mode) then Continue;
          if GitOidSame(Deletes[SI2].Oid, Adds[DI2].Oid) then Score := 100
          else Score := ScoreFromSigs(DeleteSigs[SI2], AddSigs[DI2]);
          if Score < 0 then Continue;
          if Score < ARenameThreshold then Continue;
          if LCandCount = LCandCap then
          begin
            LCandCap := SizeInt(GrowArrayCapacity(SizeUInt(LCandCap), SizeUInt(LCandCount + 1)));
            SetLength(Candidates, LCandCap);
          end;
          Candidates[LCandCount].SrcIdx := SI2;
          Candidates[LCandCount].DstIdx := DI2;
          Candidates[LCandCount].Score := Score;
          Inc(LCandCount);
        end;
        for K := 0 to LVisitedCount - 1 do LVisited[LVisitedList[K]] := False;
      end;
      if LCandCap <> LCandCount then SetLength(Candidates, LCandCount);
    end;
    SortCandidatesByScoreDesc(Candidates);
    SetLength(PairedSrc, Length(Deletes));
    SetLength(PairedDst, Length(Adds));
    for I := 0 to High(PairedSrc) do PairedSrc[I] := False;
    for I := 0 to High(PairedDst) do PairedDst[I] := False;
    RenamePairs := nil; LRenameCount := 0; LRenameCap := 0;
    for I := 0 to High(Candidates) do
    begin
      Cand := Candidates[I];
      if PairedSrc[Cand.SrcIdx] then Continue;
      if PairedDst[Cand.DstIdx] then Continue;
      PairedSrc[Cand.SrcIdx] := True;
      PairedDst[Cand.DstIdx] := True;
      if LRenameCount = LRenameCap then
      begin
        LRenameCap := SizeInt(GrowArrayCapacity(SizeUInt(LRenameCap), SizeUInt(LRenameCount + 1)));
        SetLength(RenamePairs, LRenameCap);
      end;
      RenamePairs[LRenameCount] := Cand;
      Inc(LRenameCount);
    end;
    if LRenameCap <> LRenameCount then SetLength(RenamePairs, LRenameCount);
    CopyPairs := nil; LCopyCount := 0; LCopyCap := 0;
    if AFindCopies then
    begin
      BuildBlobSigCache(Repo, HeadList, HeadSigs);
      Candidates := nil; LCandCount := 0; LCandCap := 0;
      if (Length(HeadList) > 0) and (Length(Adds) > 0) then
      begin
        if Length(LAddOidBuckets) = 0 then BuildAddIndexes;
        for SI2 := 0 to High(HeadList) do
        begin
          if not IsBlobMode(HeadList[SI2].Mode) then Continue;
          LVisitedCount := 0;
          Score := Integer(OidHash(HeadList[SI2].Oid));
          if IsBlobMode(HeadList[SI2].Mode) then Score := Score xor Integer(UInt32($9E3779B9));
          I := Integer(UInt32(Score) and UInt32(LAddOidCap - 1));
          DI2 := LAddOidBuckets[I];
          while DI2 <> -1 do
          begin
            K := LOidEntries[DI2].AddIdx;
            if GitOidSame(HeadList[SI2].Oid, Adds[K].Oid) and IsBlobMode(Adds[K].Mode) and not PairedDst[K] then
              if not LVisited[K] then
              begin LVisited[K] := True; LVisitedList[LVisitedCount] := K; Inc(LVisitedCount); end;
            DI2 := LOidEntries[DI2].Next;
          end;
          if HeadSigs[SI2].Valid then
          begin
            if HeadSigs[SI2].Count = 0 then
            begin
              for DI2 := 0 to High(Adds) do
                if not PairedDst[DI2] and AddSigs[DI2].Valid and (AddSigs[DI2].Count = 0) and IsBlobMode(Adds[DI2].Mode) then
                  if not LVisited[DI2] then
                  begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
            end
            else
            begin
              for I := 0 to HeadSigs[SI2].Count - 1 do
              begin
                Score := Integer(HeadSigs[SI2].Hashes[I] and UInt32(Length(LHashHeads) - 1));
                K := LHashHeads[Score];
                while K <> -1 do
                begin
                  if LHashEntries[K].Hash = HeadSigs[SI2].Hashes[I] then
                  begin
                    DI2 := LHashEntries[K].AddIdx;
                    if not PairedDst[DI2] and not LVisited[DI2] then
                    begin LVisited[DI2] := True; LVisitedList[LVisitedCount] := DI2; Inc(LVisitedCount); end;
                  end;
                  K := LHashEntries[K].Next;
                end;
              end;
            end;
          end;
          for K := 0 to LVisitedCount - 1 do
          begin
            DI2 := LVisitedList[K];
            if PairedDst[DI2] then Continue;
            if not IsBlobMode(Adds[DI2].Mode) then Continue;
            if GitOidSame(HeadList[SI2].Oid, Adds[DI2].Oid) then Score := 100
            else Score := ScoreFromSigs(HeadSigs[SI2], AddSigs[DI2]);
            if Score < 0 then Continue;
            if Score < ACopyThreshold then Continue;
            if LCandCount = LCandCap then
            begin
              LCandCap := SizeInt(GrowArrayCapacity(SizeUInt(LCandCap), SizeUInt(LCandCount + 1)));
              SetLength(Candidates, LCandCap);
            end;
            Candidates[LCandCount].SrcIdx := SI2;
            Candidates[LCandCount].DstIdx := DI2;
            Candidates[LCandCount].Score := Score;
            Inc(LCandCount);
          end;
          for K := 0 to LVisitedCount - 1 do LVisited[LVisitedList[K]] := False;
        end;
        if LCandCap <> LCandCount then SetLength(Candidates, LCandCount);
      end;
      SortCandidatesByScoreDesc(Candidates);
      for I := 0 to High(Candidates) do
      begin
        Cand := Candidates[I];
        if PairedDst[Cand.DstIdx] then Continue;
        PairedDst[Cand.DstIdx] := True;
        if LCopyCount = LCopyCap then
        begin
          LCopyCap := SizeInt(GrowArrayCapacity(SizeUInt(LCopyCap), SizeUInt(LCopyCount + 1)));
          SetLength(CopyPairs, LCopyCap);
        end;
        CopyPairs[LCopyCount] := Cand;
        Inc(LCopyCount);
      end;
      if LCopyCap <> LCopyCount then SetLength(CopyPairs, LCopyCount);
    end;
    TrackedStatus := nil; LStatusCount := 0; LStatusCap := 0;
    for I := 0 to High(RenamePairs) do
    begin
      Cand := RenamePairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendRenamedFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[Cand.SrcIdx].Path, Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    for I := 0 to High(CopyPairs) do
    begin
      Cand := CopyPairs[I];
      WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[Cand.DstIdx]]);
      AppendCopiedFast(TrackedStatus, LStatusCount, LStatusCap, HeadList[Cand.SrcIdx].Path, Adds[Cand.DstIdx].Path, Byte(Cand.Score), WC);
    end;
    for I := 0 to High(Deletes) do
      if not PairedSrc[I] then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Deletes[I].Path, gscDeleted, gscUnmodified);
    for I := 0 to High(Adds) do
      if not PairedDst[I] then
      begin
        WC := WorkCodeFor(AWorkTree, Stage0Entries[AddEntryPos[I]]);
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, Adds[I].Path, gscAdded, WC);
      end;
    for K := 0 to High(BothPaths) do
    begin
      WC := WorkCodeFor(AWorkTree, BothEntry[K]);
      if ModeClassOf(BothPaths[K].Mode) <> ModeClassOf(BothEntry[K].Mode) then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscTypeChanged, WC)
      else if not GitOidSame(BothPaths[K].Oid, BothEntry[K].Oid) then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscModified, WC)
      else if WC <> gscUnmodified then
        AppendStatusFast(TrackedStatus, LStatusCount, LStatusCap, BothEntry[K].Path, gscUnmodified, WC);
    end;
    if LStatusCap <> LStatusCount then SetLength(TrackedStatus, LStatusCount);
    SortStatusByPath(TrackedStatus);
    Result := TrackedStatus;
    AppendUntrackedGroupToResult(Result);
  finally
    Repo.Free;
  end;
end;

end.
