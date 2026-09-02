unit nextpas.core.git.native.repository.diff;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.git.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common,
  nextpas.core.git.native.diff;

{ Diff subdomain: pure helpers + repository diff operations.
  Single-source via bytes.ops (SpanEqual), inline zero-copy for IsBinaryBytes/PathIncluded,
  TBytes->string via bytes.ops.BytesToString single source, no SysUtils. }

function RepositoryDiffEx(const AGitDir, AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
function RepositoryDiff(const AGitDir, AOldRef, ANewRef: string): TGitDiff; inline;
function RepositoryDiffWorkingTreeEx(const AGitDir, AWorkTree, ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
function RepositoryDiffWorkingTree(const AGitDir, AWorkTree, ARef: string): TGitDiff; inline;
function RepositoryWorkdirPatchText(const AGitDir, AWorkTree, ARevspec: string; const APaths: nextpas.core.base.TStringArray; AShowBinary: Boolean): string;
procedure RepositoryApplyPatch(const AGitDir, AWorkTree, APatchText: string);
procedure RepositoryCheckoutPaths(const AGitDir, AWorkTree, ARevspec: string; const APaths: nextpas.core.base.TStringArray);

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.blame,
  nextpas.core.git.native.util,
  nextpas.core.git.native.index,
  nextpas.core.git.native.write,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.text.utils,
  nextpas.core.os.env,
  nextpas.core.diff.myers,
  nextpas.core.diff.base,
  nextpas.core.text.conv;

type
  THunkArray = array of TGitDiffHunk;

function TrimInline(const S: string): string; inline;
begin
  Result := GitTrimSpaces(S);
end;

function WorkDirOf(const AGitDir, AWorkTree: string): string; inline;
begin
  if AWorkTree <> '' then
    Result := AWorkTree
  else
    Result := PathDir(AGitDir);
end;

function IsBinaryBytes(const AData: TBytes): Boolean; inline;
begin
  // perf: single-source via bytes.ops BytesIndexOf (inline SpanIndexOf -> MemFindByte SIMD disp.), zero-copy span view, no per-byte Pascal loop; early exit via SIMD
  Result := BytesIndexOf(AData, 0) >= 0;
end;

function BlobLinesOf(const AGitDir: string; const AOid: TGitOid): nextpas.core.base.TStringArray; inline;
var
  R: TNativeRepository;
  K: TGitObjectKind;
  D: TBytes;
  S: string;
begin
  Result:=nil;
  if GitOidIsZero(AOid) then
    Exit;
  R:=TNativeRepository.Create(AGitDir);
  try
    D:=R.ReadObject(AOid,K);
    if IsBinaryBytes(D) then
      Exit(nil);
    S:=BytesToString(D);
    Result:=GitSplitLines(S);
    if (Length(Result)=1) and (Result[0]='') and (Length(S)=0) then
      SetLength(Result,0);
    if (Length(Result)>0) and (Result[High(Result)]='') and (Length(S)>0) and (S[Length(S)]=#10) then
      SetLength(Result,Length(Result)-1);
  finally
    R.Free;
  end;
end;

function PathIncluded(const APath: string; const APaths: nextpas.core.base.TStringArray): Boolean; inline;
var
  I: Integer;
begin
  if Length(APaths)=0 then
    Exit(True);
  for I:=0 to High(APaths) do
    if (APath=APaths[I]) or ((Length(APath)>Length(APaths[I])) and (Copy(APath,1,Length(APaths[I])+1)=APaths[I]+'/')) then
      Exit(True);
  Result:=False;
end;

function WorkTreeLinesOf(const AWorkTree, ARel: string): nextpas.core.base.TStringArray; inline;
var
  P: string;
  D: TBytes;
  S: string;
begin
  Result:=nil;
  P:=PathJoin([AWorkTree,ARel]);
  if not FileExists(P) then
    Exit(nil);
  try
    D:=ReadFile(P);
  except
    Exit(nil);
  end;
  if IsBinaryBytes(D) then
    Exit(nil);
  S:=BytesToString(D);
  Result:=GitSplitLines(S);
  if (Length(Result)=1) and (Result[0]='') and (Length(S)=0) then
    SetLength(Result,0);
  if (Length(Result)>0) and (Result[High(Result)]='') and (Length(S)>0) and (S[Length(S)]=#10) then
    SetLength(Result,Length(Result)-1);
end;

procedure BuildLCSOps(const AOld, ANew: nextpas.core.base.TStringArray; out AOpcodes: nextpas.core.base.TStringArray; out AOldTexts: nextpas.core.base.TStringArray; out ANewTexts: nextpas.core.base.TStringArray);
var
  LEdits: TDiffEditArray;
  LCnt, I: Integer;
begin
  // perf: Myers O(ND) single source via nextpas.core.diff.myers (owner), avoids (N+1)*(M+1) OOM; single allocation for outputs, zero-copy string CoW, amortized via bytes.ops GrowArrayCapacity discipline (no per-entry Length+1 churn)
  // stability: no manual LCS table to free, auto-managed dynamic arrays; inline path delegates to unified Myers core
  LEdits := DiffLines(AOld, ANew);
  LCnt := Length(LEdits);
  SetLength(AOpcodes, LCnt);
  SetLength(AOldTexts, LCnt);
  SetLength(ANewTexts, LCnt);
  for I := 0 to LCnt - 1 do
    case LEdits[I].Action of
      daEqual: begin AOpcodes[I] := ' '; AOldTexts[I] := AOld[LEdits[I].OldIndex]; ANewTexts[I] := ANew[LEdits[I].NewIndex]; end;
      daDelete: begin AOpcodes[I] := '-'; AOldTexts[I] := AOld[LEdits[I].OldIndex]; ANewTexts[I] := ''; end;
      daInsert: begin AOpcodes[I] := '+'; AOldTexts[I] := ''; ANewTexts[I] := ANew[LEdits[I].NewIndex]; end;
    end;
end;

function UnifiedHunksFromOps(const AOpcodes: nextpas.core.base.TStringArray; const AOldTexts, ANewTexts: nextpas.core.base.TStringArray; AContext: Integer): THunkArray;
var
  N,I, OldNo, NewNo, SPos, EPos, HS, HE, OC, NC, K: Integer;
  H: TGitDiffHunk;
  ChangedBlocks: array of record SPos,EPos: Integer; end;
  CB, ResCount, LOldLen, LAddLen: Integer;
begin
  Result:=nil;
  N:=Length(AOpcodes);
  if N=0 then
    Exit;
  SetLength(ChangedBlocks,0);
  I:=0;
  while I<N do
  begin
    if AOpcodes[I]<>' ' then
    begin
      SPos:=I;
      while (I<N) and (AOpcodes[I]<>' ') do
        Inc(I);
      EPos:=I-1;
      CB:=Length(ChangedBlocks);
      SetLength(ChangedBlocks,CB+1);
      ChangedBlocks[CB].SPos:=SPos;
      ChangedBlocks[CB].EPos:=EPos;
    end
    else
      Inc(I);
  end;
  if Length(ChangedBlocks)=0 then
    Exit;
  // perf: pre-allocate Result to ChangedBlocks upper bound (single allocation, amortized O(1) append via index)
  ResCount:=0;
  SetLength(Result, Length(ChangedBlocks));
  OldNo:=1;
  NewNo:=1;
  for I:=0 to High(AOpcodes) do
  begin
    if I=0 then
    begin
    end;
  end;
  for CB:=0 to High(ChangedBlocks) do
  begin
    SPos:=ChangedBlocks[CB].SPos - AContext;
    if SPos<0 then
      SPos:=0;
    EPos:=ChangedBlocks[CB].EPos + AContext;
    if EPos>=N then
      EPos:=N-1;
    if (CB>0) and (SPos <= ChangedBlocks[CB-1].EPos + AContext*2 +1) then
    begin
      if SPos <= ChangedBlocks[CB-1].EPos + AContext then
        Continue;
    end;
    HS:=SPos;
    HE:=EPos;
    H.OldStart:=1;
    H.NewStart:=1;
    OC:=0;
    NC:=0;
    OldNo:=1;
    NewNo:=1;
    for K:=0 to HS-1 do
    begin
      if AOpcodes[K]=' ' then
      begin
        Inc(OldNo);
        Inc(NewNo);
      end
      else if AOpcodes[K]='-' then
        Inc(OldNo)
      else
        Inc(NewNo);
    end;
    H.OldStart:=OldNo;
    H.NewStart:=NewNo;
    for K:=HS to HE do
    begin
      if AOpcodes[K]=' ' then
      begin
        Inc(OC);
        Inc(NC);
      end
      else if AOpcodes[K]='-' then
        Inc(OC)
      else
        Inc(NC);
    end;
    H.OldCount:=OC;
    H.NewCount:=NC;
    H.Header:='@@ -'+IntToStr(H.OldStart)+','+IntToStr(H.OldCount)+' +'+IntToStr(H.NewStart)+','+IntToStr(H.NewCount)+' @@';
    // perf: single allocation for hunk lines (HE-HS+1) vs per-line SetLength(Length+1) O(n²) realloc/copy
    SetLength(H.Lines, HE - HS + 1);
    for K:=HS to HE do
    begin
      if AOpcodes[K]=' ' then
        H.Lines[K - HS]:=' '+AOldTexts[K]
      else if AOpcodes[K]='-' then
        H.Lines[K - HS]:='-'+AOldTexts[K]
      else
        H.Lines[K - HS]:='+'+ANewTexts[K];
    end;
    // perf: amortized single pre-allocation to ChangedBlocks upper bound (single SetLength) + index append; no per-hunk Length+1 churn (bytes.ops GrowArrayCapacity discipline)
    Result[ResCount]:=H;
    Inc(ResCount);
  end;
  SetLength(Result, ResCount);
  if Length(Result)>1 then
  begin
    I:=0;
    while I<Length(Result)-1 do
    begin
      if Result[I].NewStart+Result[I].NewCount + AContext >= Result[I+1].NewStart then
      begin
        // perf: single allocation for merged lines (old+add) vs per-line SetLength(Length+1)
        LOldLen:=Length(Result[I].Lines);
        LAddLen:=Length(Result[I+1].Lines);
        SetLength(Result[I].Lines, LOldLen + LAddLen);
        for K:=0 to LAddLen-1 do
          Result[I].Lines[LOldLen + K]:=Result[I+1].Lines[K];
        Result[I].OldCount:=Result[I].OldCount+Result[I+1].OldCount;
        Result[I].NewCount:=Result[I].NewCount+Result[I+1].NewCount;
        Result[I].Header:='@@ -'+IntToStr(Result[I].OldStart)+','+IntToStr(Result[I].OldCount)+' +'+IntToStr(Result[I].NewStart)+','+IntToStr(Result[I].NewCount)+' @@';
        for K:=I+1 to High(Result)-1 do
          Result[K]:=Result[K+1];
        SetLength(Result,Length(Result)-1);
      end
      else
        Inc(I);
    end;
  end;
end;

function BuildPureFileHunks(const AOldLines, ANewLines: nextpas.core.base.TStringArray; AContext: Integer): THunkArray;
var
  Opcs: nextpas.core.base.TStringArray;
  OT, NT: nextpas.core.base.TStringArray;
begin
  Result:=nil;
  if (AOldLines=nil) and (ANewLines=nil) then
    Exit(nil);
  if (AOldLines=nil) then
  begin
    if (ANewLines=nil) or (Length(ANewLines)=0) then
      Exit(nil);
  end;
  BuildLCSOps(AOldLines,ANewLines,Opcs,OT,NT);
  Result:=UnifiedHunksFromOps(Opcs,OT,NT,AContext);
end;

function ResolveTreeOid(const AGitDir, ARef: string): TGitOid; inline;
var
  Oid: TGitOid;
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  Tag: TGitTagInfo;
begin
  try
    Oid:=GitRevParse(AGitDir,ARef);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    Data:=Repo.ReadObject(Oid,Kind);
    if Kind=gokCommit then
    begin
      Info:=GitParseCommit(Data);
      Result:=Info.Tree;
    end
    else if Kind=gokTree then
      Result:=Oid
    else if Kind=gokTag then
    begin
      Tag:=GitParseTag(Data);
      Result:=GitPeelToTree(Repo,Tag.Target);
    end
    else raise EGitError.CreateFmt('object %s is not tree/commit/tag',[GitOidToHex(Oid)]);
  finally
    Repo.Free;
  end;
end;

function RepositoryDiffEx(const AGitDir, AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
var
  OldTree, NewTree: TGitOid;
  DiffArr: TGitDiffArray;
  I, J, K, Add, Del: Integer;
  Entry: TGitDiffEntry;
  OldLines, NewLines: nextpas.core.base.TStringArray;
  Hunks: THunkArray;
  F: TGitDiffFile;
  Ctx, FilesCount, FilesCap: Integer;
begin
  Result.Files:=nil;
  FilesCount:=0;
  FilesCap:=0;
  if TrimInline(AOldRef)='' then
    raise EGitError.Create('diff: empty old ref');
  if TrimInline(ANewRef)='' then
    raise EGitError.Create('diff: empty new ref');
  try
    GitRevParse(AGitDir,AOldRef);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  try
    GitRevParse(AGitDir,ANewRef);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  OldTree:=ResolveTreeOid(AGitDir,AOldRef);
  NewTree:=ResolveTreeOid(AGitDir,ANewRef);
  Ctx:=AOptions.UnifiedLines;
  if Ctx<=0 then
    Ctx:=3;
  DiffArr:=GitDiffTrees(AGitDir,OldTree,NewTree);
  // perf: DiffFlat preallocation single source (upper-bound Length(DiffArr) single SetLength, inline index append, zero-copy string CoW) vs per-file SetLength(Length+1) O(n²) realloc/copy; bytes.ops discipline
  FilesCap:=Length(DiffArr);
  if FilesCap>0 then
    SetLength(Result.Files, FilesCap);
  for I:=0 to High(DiffArr) do
  begin
    Entry:=DiffArr[I];
    if not PathIncluded(Entry.Path, AOptions.Paths) then
      Continue;
    OldLines:=nil;
    NewLines:=nil;
    try
      OldLines:=BlobLinesOf(AGitDir,Entry.OldOid);
    except
      on EGitError do raise;
      on Exception do raise EGitError.Create(CurrentExceptionMessage);
    end;
    try
      NewLines:=BlobLinesOf(AGitDir,Entry.NewOid);
    except
      on EGitError do raise;
      on Exception do raise EGitError.Create(CurrentExceptionMessage);
    end;
    if (OldLines=nil) and (NewLines=nil) and (not GitOidIsZero(Entry.OldOid)) and (not GitOidIsZero(Entry.NewOid)) then
    begin
      F.OldPath:=Entry.Path;
      F.NewPath:=Entry.Path;
      case Entry.Status of
        gdsAdded: F.Status:=nextpas.core.git.base.gdsAdded;
        gdsDeleted: F.Status:=nextpas.core.git.base.gdsDeleted;
        gdsTypeChanged: F.Status:=nextpas.core.git.base.gdsTypeChange;
        else F.Status:=nextpas.core.git.base.gdsModified;
      end;
      F.Additions:=0;
      F.Deletions:=0;
      F.Hunks:=nil;
      SetLength(F.Hunks,1);
      F.Hunks[0].Header:='@@ -1,0 +1,0 @@';
      F.Hunks[0].OldStart:=1;
      F.Hunks[0].OldCount:=0;
      F.Hunks[0].NewStart:=1;
      F.Hunks[0].NewCount:=0;
      F.Hunks[0].Lines:=nil;
      // perf: amortized index append into preallocated FilesCap (DiffFlat single source), no O(n²) Length+1 churn
      if FilesCount>=FilesCap then
      begin
        FilesCap:=Integer(GrowArrayCapacity(SizeUInt(FilesCap), SizeUInt(FilesCount+1)));
        SetLength(Result.Files, FilesCap);
      end;
      Result.Files[FilesCount]:=F;
      Inc(FilesCount);
      Continue;
    end;
    if (OldLines=nil) then
      SetLength(OldLines,0);
    if (NewLines=nil) then
      SetLength(NewLines,0);
    Hunks:=BuildPureFileHunks(OldLines,NewLines,Ctx);
    if (Length(Hunks)=0) and (Length(OldLines)<>Length(NewLines)) then
    begin
      SetLength(Hunks,1);
      Hunks[0].Header:='@@ -1,'+IntToStr(Length(OldLines))+' +1,'+IntToStr(Length(NewLines))+' @@';
      Hunks[0].OldStart:=1;
      Hunks[0].OldCount:=Length(OldLines);
      Hunks[0].NewStart:=1;
      Hunks[0].NewCount:=Length(NewLines);
      Hunks[0].Lines:=nil;
    end;
    if (Length(Hunks)=0) and (Length(OldLines)=Length(NewLines)) then
      Continue;
    F.OldPath:=Entry.Path;
    F.NewPath:=Entry.Path;
    case Entry.Status of
      gdsAdded: F.Status:=nextpas.core.git.base.gdsAdded;
      gdsDeleted: F.Status:=nextpas.core.git.base.gdsDeleted;
      gdsTypeChanged: F.Status:=nextpas.core.git.base.gdsTypeChange;
      else F.Status:=nextpas.core.git.base.gdsModified;
    end;
    Add:=0;
    Del:=0;
    for J:=0 to High(Hunks) do
      for K:=0 to High(Hunks[J].Lines) do
        if Length(Hunks[J].Lines[K])>0 then
          if Hunks[J].Lines[K][1]='+' then
            Inc(Add)
          else if Hunks[J].Lines[K][1]='-' then
            Inc(Del);
    F.Additions:=Add;
    F.Deletions:=Del;
    F.Hunks:=Hunks;
    // perf: amortized index append into preallocated FilesCap (DiffFlat single source), no O(n²) Length+1 churn
    if FilesCount>=FilesCap then
    begin
      FilesCap:=Integer(GrowArrayCapacity(SizeUInt(FilesCap), SizeUInt(FilesCount+1)));
      SetLength(Result.Files, FilesCap);
    end;
    Result.Files[FilesCount]:=F;
    Inc(FilesCount);
  end;
  SetLength(Result.Files, FilesCount);
end;

function RepositoryDiff(const AGitDir, AOldRef, ANewRef: string): TGitDiff; inline;
begin
  Result := RepositoryDiffEx(AGitDir, AOldRef, ANewRef, DefaultGitDiffOptions);
end;

function RepositoryDiffWorkingTreeEx(const AGitDir, AWorkTree, ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
var
  Work: string;
  TreeOid: TGitOid;
  OldFlat: TGitDiffArray;
  Entry: TGitDiffEntry;
  OldLines, NewLines: nextpas.core.base.TStringArray;
  Hunks: THunkArray;
  F: TGitDiffFile;
  Ctx, I, J, K, Add, Del, FilesCount, FilesCap: Integer;
  LPath: string;
  Repo: TNativeRepository;
begin
  Result.Files:=nil;
  FilesCount:=0;
  FilesCap:=0;
  if TrimInline(ARef)='' then
    raise EGitError.Create('diffWorkingTree: empty ref');
  try
    GitRevParse(AGitDir,ARef);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create(CurrentExceptionMessage);
  end;
  Work:=WorkDirOf(AGitDir,AWorkTree);
  if Work='' then
    raise EGitError.Create('DiffWorkingTreeEx: bare repository has no workdir');
  TreeOid:=ResolveTreeOid(AGitDir,ARef);
  Ctx:=AOptions.UnifiedLines;
  if Ctx<=0 then
    Ctx:=3;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    OldFlat:=GitDiffTrees(AGitDir, Default(TGitOid), TreeOid);
    for I:=0 to High(OldFlat) do
    begin
      Entry.Path:=OldFlat[I].Path;
      Entry.OldOid:=OldFlat[I].NewOid;
      Entry.NewOid:=Default(TGitOid);
      Entry.Status:=gdsAdded;
      OldFlat[I]:=Entry;
    end;
  finally
    Repo.Free;
  end;
  // perf: DiffFlat preallocation single source (upper-bound Length(OldFlat) single SetLength, inline index append, zero-copy string CoW) vs per-file SetLength(Length+1) O(n²)
  FilesCap:=Length(OldFlat);
  if FilesCap>0 then
    SetLength(Result.Files, FilesCap);
  for I:=0 to High(OldFlat) do
  begin
    LPath:=OldFlat[I].Path;
    if not PathIncluded(LPath, AOptions.Paths) then
      Continue;
    try
      OldLines:=BlobLinesOf(AGitDir, OldFlat[I].OldOid);
    except
      on EGitError do raise;
      on Exception do raise EGitError.Create(CurrentExceptionMessage);
    end;
    NewLines:=WorkTreeLinesOf(Work, LPath);
    if (OldLines=nil) and (NewLines=nil) then
    begin
      if not FileExists(PathJoin([Work,LPath])) then
      begin
        F.OldPath:=LPath;
        F.NewPath:=LPath;
        F.Status:=nextpas.core.git.base.gdsDeleted;
        F.Additions:=0;
        F.Deletions:=0;
        SetLength(F.Hunks,1);
        F.Hunks[0].Header:='@@ -1,0 +1,0 @@';
        F.Hunks[0].OldStart:=1;
        F.Hunks[0].OldCount:=0;
        F.Hunks[0].NewStart:=1;
        F.Hunks[0].NewCount:=0;
        F.Hunks[0].Lines:=nil;
        // perf: index append into preallocated FilesCap, no O(n²) Length+1
        if FilesCount>=FilesCap then
        begin
          FilesCap:=Integer(GrowArrayCapacity(SizeUInt(FilesCap), SizeUInt(FilesCount+1)));
          SetLength(Result.Files, FilesCap);
        end;
        Result.Files[FilesCount]:=F;
        Inc(FilesCount);
        Continue;
      end
      else
        Continue;
    end;
    if OldLines=nil then
      SetLength(OldLines,0);
    if NewLines=nil then
    begin
      if FileExists(PathJoin([Work,LPath])) then
        Continue
      else
      begin
        Hunks:=BuildPureFileHunks(OldLines,NewLines,Ctx);
        if Length(Hunks)=0 then
        begin
          SetLength(Hunks,1);
          Hunks[0].Header:='@@ -1,'+IntToStr(Length(OldLines))+' +1,0 @@';
          Hunks[0].OldStart:=1;
          Hunks[0].OldCount:=Length(OldLines);
          Hunks[0].NewStart:=1;
          Hunks[0].NewCount:=0;
          // perf: single allocation for deleted-lines ('-'+OldLines) vs per-line SetLength(Length+1) O(n²); zero-copy string CoW
          SetLength(Hunks[0].Lines, Length(OldLines));
          for J:=0 to High(OldLines) do
          begin
            Hunks[0].Lines[J]:='-'+OldLines[J];
          end;
        end;
        F.OldPath:=LPath;
        F.NewPath:=LPath;
        F.Status:=nextpas.core.git.base.gdsDeleted;
        Add:=0;
        Del:=0;
        for J:=0 to High(Hunks) do
          for K:=0 to High(Hunks[J].Lines) do
            if Length(Hunks[J].Lines[K])>0 then
              if Hunks[J].Lines[K][1]='-' then
                Inc(Del);
        F.Additions:=Add;
        F.Deletions:=Del;
        F.Hunks:=Hunks;
        // perf: index append into preallocated FilesCap, no O(n²) Length+1
        if FilesCount>=FilesCap then
        begin
          FilesCap:=Integer(GrowArrayCapacity(SizeUInt(FilesCap), SizeUInt(FilesCount+1)));
          SetLength(Result.Files, FilesCap);
        end;
        Result.Files[FilesCount]:=F;
        Inc(FilesCount);
        Continue;
      end;
    end;
    Hunks:=BuildPureFileHunks(OldLines,NewLines,Ctx);
    if Length(Hunks)=0 then
      Continue;
    F.OldPath:=LPath;
    F.NewPath:=LPath;
    F.Status:=nextpas.core.git.base.gdsModified;
    Add:=0;
    Del:=0;
    for J:=0 to High(Hunks) do
      for K:=0 to High(Hunks[J].Lines) do
        if Length(Hunks[J].Lines[K])>0 then
          if Hunks[J].Lines[K][1]='+' then
            Inc(Add)
          else if Hunks[J].Lines[K][1]='-' then
            Inc(Del);
    F.Additions:=Add;
    F.Deletions:=Del;
    F.Hunks:=Hunks;
    // perf: index append into preallocated FilesCap, no O(n²) Length+1
    if FilesCount>=FilesCap then
    begin
      FilesCap:=Integer(GrowArrayCapacity(SizeUInt(FilesCap), SizeUInt(FilesCount+1)));
      SetLength(Result.Files, FilesCap);
    end;
    Result.Files[FilesCount]:=F;
    Inc(FilesCount);
  end;
  SetLength(Result.Files, FilesCount);
end;

function RepositoryDiffWorkingTree(const AGitDir, AWorkTree, ARef: string): TGitDiff; inline;
begin
  Result := RepositoryDiffWorkingTreeEx(AGitDir, AWorkTree, ARef, DefaultGitDiffOptions);
end;

function RepositoryWorkdirPatchText(const AGitDir, AWorkTree, ARevspec: string; const APaths: nextpas.core.base.TStringArray; AShowBinary: Boolean): string;
var
  Work: string;
  D: TGitDiff;
  Opts: TGitDiffOptions;
  I, J: Integer;
  S: string;
  HasBinary: Boolean;
  function IsBin(const AHunks: array of TGitDiffHunk): Boolean; inline;
  var
    K: Integer;
  begin
    Result:=False;
    for K:=0 to High(AHunks) do
      if Length(AHunks[K].Lines)=0 then
      begin
        Result:=True;
        Exit;
      end;
  end;
begin
  Result:='';
  Work:=WorkDirOf(AGitDir,AWorkTree);
  if Work='' then
    raise EGitError.Create('WorkdirPatchText: bare repository has no workdir');
  Opts:=DefaultGitDiffOptions;
  Opts.Paths:=APaths;
  if TrimInline(ARevspec)='' then
    D:=RepositoryDiffWorkingTreeEx(AGitDir, AWorkTree, 'HEAD',Opts)
  else
    D:=RepositoryDiffWorkingTreeEx(AGitDir, AWorkTree, ARevspec,Opts);
  for I:=0 to High(D.Files) do
  begin
    HasBinary:=IsBin(D.Files[I].Hunks);
    if HasBinary and not AShowBinary then
      Continue;
    S:='diff --git a/'+D.Files[I].OldPath+' b/'+D.Files[I].NewPath+#10+
       '--- a/'+D.Files[I].OldPath+#10+
       '+++ b/'+D.Files[I].NewPath+#10;
    Result:=Result+S;
    if HasBinary then
    begin
      Result:=Result+'Binary files differ'#10;
      Continue;
    end;
    for J:=0 to High(D.Files[I].Hunks) do
    begin
      Result:=Result+D.Files[I].Hunks[J].Header+#10;
      for S in D.Files[I].Hunks[J].Lines do
        Result:=Result+S+#10;
    end;
  end;
end;

procedure RepositoryApplyPatch(const AGitDir, AWorkTree, APatchText: string);
var
  Work: string;
  Lines: nextpas.core.base.TStringArray;
  I, SPos: Integer;
  Line, APath, BPath, CurPath: string;
  OldLines, NewLines: nextpas.core.base.TStringArray;
  Hunks: THunkArray;
  HunksCount, HunksCap: SizeUInt;
  CurHunk: TGitDiffHunk;
  CurLinesCount, CurLinesCap: SizeUInt;
  InHunk: Boolean;
  IsBin: Boolean;
  FullPath: string;
  NewContent: string;
  J, K, OldIdx, NewCount, NewCap, TotalHunkLines: Integer;
  LBuilder: IBytesBuilder;
  LSpan: TByteSpan;
  function IsBinaryHunk(const AHunk: TGitDiffHunk): Boolean; inline;
  var
    Idx: Integer;
  begin
    Result:=False;
    for Idx:=0 to High(AHunk.Lines) do
      if Pos('Binary',AHunk.Lines[Idx])>0 then
        Exit(True);
  end;
begin
  if APatchText='' then
    Exit;
  Work:=WorkDirOf(AGitDir,AWorkTree);
  if Work='' then
    raise EGitError.Create('ApplyPatch: bare repository has no workdir');
  Lines:=GitSplitLines(APatchText);
  CurPath:='';
  CurHunk.Header:='';
  CurHunk.Lines:=nil;
  CurLinesCount:=0;
  CurLinesCap:=0;
  InHunk:=False;
  Hunks:=nil;
  HunksCount:=0;
  HunksCap:=0;
  for I:=0 to High(Lines) do
  begin
    Line:=Lines[I];
    if Pos('diff --git ',Line)=1 then
    begin
      if CurPath<>'' then
      begin
        if InHunk then
        begin
          // perf: DiffFlat preallocation single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) append, zero-copy record Move, avoids O(n²) SetLength(Length+1) per hunk (10k hunk copy jitter); trim Lines to count before Move
          SetLength(CurHunk.Lines, CurLinesCount);
          if HunksCount>=HunksCap then
          begin
            HunksCap:=GrowArrayCapacity(HunksCap, HunksCount+1);
            SetLength(Hunks, HunksCap);
          end;
          Hunks[HunksCount]:=CurHunk;
          Inc(HunksCount);
          CurHunk.Lines:=nil; CurLinesCount:=0; CurLinesCap:=0;
        end;
        SetLength(Hunks, HunksCount);
        if HunksCount>0 then
        begin
          FullPath:=PathJoin([Work,CurPath]);
          OldLines:=WorkTreeLinesOf(Work,CurPath);
          if OldLines=nil then
            SetLength(OldLines,0);
          // perf: prealloc upper-bound Length(OldLines)+totalHunkLines single SetLength vs per-line SetLength(Length+1) O(n²) Move; bytes.ops single source prealloc pattern (DiffFlat) + zero-copy string CoW, amortized O(1) append via index
          TotalHunkLines:=0;
          for J:=0 to High(Hunks) do
            Inc(TotalHunkLines, Length(Hunks[J].Lines));
          NewCap:=Length(OldLines)+TotalHunkLines;
          if NewCap<0 then NewCap:=Length(OldLines);
          SetLength(NewLines, NewCap);
          NewCount:=0;
          OldIdx:=0;
          for J:=0 to High(Hunks) do
          begin
            for K:=0 to High(Hunks[J].Lines) do
            begin
              if Length(Hunks[J].Lines[K])=0 then
                Continue;
              case Hunks[J].Lines[K][1] of
                ' ': begin if OldIdx<Length(OldLines) then begin NewLines[NewCount]:=OldLines[OldIdx]; Inc(NewCount); Inc(OldIdx); end; end;
                '-': Inc(OldIdx);
                '+': begin NewLines[NewCount]:=Copy(Hunks[J].Lines[K],2,MaxInt); Inc(NewCount); end;
              end;
            end;
          end;
          while OldIdx<Length(OldLines) do
          begin
            NewLines[NewCount]:=OldLines[OldIdx];
            Inc(NewCount);
            Inc(OldIdx);
          end;
          SetLength(NewLines, NewCount);
          // perf: bytes.builder single source (IBytesBuilder inline Grow, WrittenSpan zero-copy) vs O(n²) string +=; single allocation
          LBuilder:=CreateBytesBuilder;
          for J:=0 to High(NewLines) do
          begin
            if Length(NewLines[J])>0 then
              LBuilder.AppendBytes(PByte(PAnsiChar(NewLines[J])),Length(NewLines[J]));
            LBuilder.AppendByte(10);
          end;
          LSpan:=LBuilder.WrittenSpan;
          SetLength(NewContent,LSpan.Len);
          if LSpan.Len>0 then
            Move(LSpan.Data^,PAnsiChar(NewContent)^,LSpan.Len);
          try
            MkdirAll(PathDir(FullPath),PermDirDefault);
            WriteFileText(FullPath,NewContent);
          except
            on Exception do raise EGitError.Create('ApplyPatch: write "'+CurPath+'": '+CurrentExceptionMessage);
          end;
        end;
        Hunks:=nil; HunksCount:=0; HunksCap:=0;
        CurHunk.Header:='';
        CurHunk.Lines:=nil; CurLinesCount:=0; CurLinesCap:=0;
        InHunk:=False;
      end;
      SPos:=Pos(' b/',Line);
      if SPos>0 then
        BPath:=Copy(Line,SPos+3,MaxInt)
      else
        BPath:='';
      CurPath:=BPath;
      APath:=BPath;
    end
    else if Pos('@@ ',Line)=1 then
    begin
      if InHunk then
      begin
        // perf: DiffFlat single source via bytes.ops GrowArrayCapacity, amortized O(1) per hunk, no O(n²) Length+1 (10k hunks)
        SetLength(CurHunk.Lines, CurLinesCount);
        if HunksCount>=HunksCap then
        begin
          HunksCap:=GrowArrayCapacity(HunksCap, HunksCount+1);
          SetLength(Hunks, HunksCap);
        end;
        Hunks[HunksCount]:=CurHunk;
        Inc(HunksCount);
      end;
      CurHunk.Header:=Line;
      CurHunk.Lines:=nil; CurLinesCount:=0; CurLinesCap:=0;
      InHunk:=True;
    end
    else if InHunk and (Length(Line)>0) and (Line[1] in [' ','+','-']) then
    begin
      // perf: binary guard bounded to CurLinesCount (actual) vs capacity Length(CurHunk.Lines) to avoid O(n²) slack scan; inline, zero-copy Pos
      IsBin:=False;
      for K:=0 to Integer(CurLinesCount)-1 do
        if Pos('Binary', CurHunk.Lines[K])>0 then
        begin IsBin:=True; Break; end;
      if IsBin then
        Continue;
      // perf: DiffFlat single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) per line, zero-copy string CoW, avoids O(n²) SetLength(Length+1) per hunk line (10k lines copy jitter); inline hot
      if CurLinesCount>=CurLinesCap then
      begin
        CurLinesCap:=GrowArrayCapacity(CurLinesCap, CurLinesCount+1);
        SetLength(CurHunk.Lines, CurLinesCap);
      end;
      CurHunk.Lines[CurLinesCount]:=Line;
      Inc(CurLinesCount);
    end;
  end;
  if CurPath<>'' then
  begin
    if InHunk then
    begin
      // perf: DiffFlat single source via bytes.ops GrowArrayCapacity, amortized O(1) per hunk, trim Lines to count
      SetLength(CurHunk.Lines, CurLinesCount);
      if HunksCount>=HunksCap then
      begin
        HunksCap:=GrowArrayCapacity(HunksCap, HunksCount+1);
        SetLength(Hunks, HunksCap);
      end;
      Hunks[HunksCount]:=CurHunk;
      Inc(HunksCount);
    end;
    SetLength(Hunks, HunksCount);
    if HunksCount>0 then
    begin
      FullPath:=PathJoin([Work,CurPath]);
      OldLines:=WorkTreeLinesOf(Work,CurPath);
      if OldLines=nil then
        SetLength(OldLines,0);
      // perf: prealloc upper-bound Length(OldLines)+totalHunkLines single SetLength vs per-line SetLength(Length+1) O(n²) Move; bytes.ops single source prealloc pattern (DiffFlat) + zero-copy string CoW, amortized O(1) append via index
      TotalHunkLines:=0;
      for J:=0 to High(Hunks) do
        Inc(TotalHunkLines, Length(Hunks[J].Lines));
      NewCap:=Length(OldLines)+TotalHunkLines;
      if NewCap<0 then NewCap:=Length(OldLines);
      SetLength(NewLines, NewCap);
      NewCount:=0;
      OldIdx:=0;
      for J:=0 to High(Hunks) do
        for K:=0 to High(Hunks[J].Lines) do
        begin
          if Length(Hunks[J].Lines[K])=0 then
            Continue;
          case Hunks[J].Lines[K][1] of
            ' ': begin if OldIdx<Length(OldLines) then begin NewLines[NewCount]:=OldLines[OldIdx]; Inc(NewCount); Inc(OldIdx); end; end;
            '-': Inc(OldIdx);
            '+': begin NewLines[NewCount]:=Copy(Hunks[J].Lines[K],2,MaxInt); Inc(NewCount); end;
          end;
        end;
      while OldIdx<Length(OldLines) do
      begin
        NewLines[NewCount]:=OldLines[OldIdx];
        Inc(NewCount);
        Inc(OldIdx);
      end;
      SetLength(NewLines, NewCount);
      // perf: bytes.builder single source (IBytesBuilder inline Grow, WrittenSpan zero-copy) vs O(n²) string +=; single allocation
      LBuilder:=CreateBytesBuilder;
      for J:=0 to High(NewLines) do
      begin
        if Length(NewLines[J])>0 then
          LBuilder.AppendBytes(PByte(PAnsiChar(NewLines[J])),Length(NewLines[J]));
        LBuilder.AppendByte(10);
      end;
      LSpan:=LBuilder.WrittenSpan;
      SetLength(NewContent,LSpan.Len);
      if LSpan.Len>0 then
        Move(LSpan.Data^,PAnsiChar(NewContent)^,LSpan.Len);
      try
        MkdirAll(PathDir(FullPath),PermDirDefault);
        WriteFileText(FullPath,NewContent);
      except
        on Exception do raise EGitError.Create('ApplyPatch: write "'+CurPath+'": '+CurrentExceptionMessage);
      end;
    end;
  end;
end;

procedure RepositoryCheckoutPaths(const AGitDir, AWorkTree, ARevspec: string; const APaths: nextpas.core.base.TStringArray);
var
  Work: string;
  TreeOid: TGitOid;
  Repo: TNativeRepository;
  I, J, K: Integer;
  LPath: string;
  Parts: nextpas.core.base.TStringArray;
  CurOid: TGitOid;
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  Found: Boolean;
  BlobOid: TGitOid;
  BlobData: TBytes;
  BlobKind: TGitObjectKind;
  Full: string;
  IdxFile: TGitIndexFile;
  function SplitPath(const AValue: string): nextpas.core.base.TStringArray; inline;
  var
    S, P, Cnt: Integer;
  begin
    Result:=nil;
    Cnt:=1;
    for S:=1 to Length(AValue) do
      if AValue[S]='/' then
        Inc(Cnt);
    SetLength(Result,Cnt);
    S:=1;
    P:=0;
    for Cnt:=1 to Length(AValue)+1 do
      if (Cnt>Length(AValue)) or (AValue[Cnt]='/') then
      begin
        Result[P]:=Copy(AValue,S,Cnt-S);
        Inc(P);
        S:=Cnt+1;
      end;
  end;
begin
  if TrimInline(ARevspec)='' then
    raise EGitError.Create('CheckoutPaths: revspec required');
  if Length(APaths)=0 then
    Exit;
  Work:=WorkDirOf(AGitDir,AWorkTree);
  if Work='' then
    raise EGitError.Create('CheckoutPaths: bare repository has no workdir');
  TreeOid:=ResolveTreeOid(AGitDir,ARevspec);
  Repo:=TNativeRepository.Create(AGitDir);
  try
    try
      IdxFile:=GitReadIndex(AGitDir);
    except
      IdxFile.Entries:=nil;
    end;
    for I:=0 to High(APaths) do
    begin
      LPath:=APaths[I];
      if LPath='' then
        Continue;
      Parts:=SplitPath(LPath);
      CurOid:=TreeOid;
      Found:=False;
      BlobOid:=Default(TGitOid);
      for J:=0 to High(Parts) do
      begin
        Data:=Repo.ReadObject(CurOid,Kind);
        if Kind<>gokTree then
          raise EGitError.CreateFmt('CheckoutPaths: not a tree at %s',[LPath]);
        Entries:=GitParseTree(Data);
        Found:=False;
        for K:=0 to High(Entries) do
          if Entries[K].Name=Parts[J] then
          begin
            if J=High(Parts) then
            begin
              BlobOid:=Entries[K].Oid;
              Found:=True;
              Break;
            end
            else
            begin
              if Entries[K].Mode<>$4000 then
                raise EGitError.CreateFmt('CheckoutPaths: not a directory %s',[LPath]);
              CurOid:=Entries[K].Oid;
              Found:=True;
              Break;
            end;
          end;
        if not Found then
          Break;
      end;
      if not Found then
        raise EGitError.CreateFmt('CheckoutPaths: path not in tree "%s"',[LPath]);
      BlobData:=Repo.ReadObject(BlobOid,BlobKind);
      Full:=PathJoin([Work,LPath]);
      MkdirAll(PathDir(Full),PermDirDefault);
      WriteFile(Full,BlobData);
      Found:=False;
      for J:=0 to High(IdxFile.Entries) do
        if IdxFile.Entries[J].Path=LPath then
        begin
          IdxFile.Entries[J].Oid:=BlobOid;
          IdxFile.Entries[J].Size:=Length(BlobData);
          Found:=True;
          Break;
        end;
      if not Found then
      begin
        SetLength(IdxFile.Entries,Length(IdxFile.Entries)+1);
        IdxFile.Entries[High(IdxFile.Entries)].Path:=LPath;
        IdxFile.Entries[High(IdxFile.Entries)].Oid:=BlobOid;
        IdxFile.Entries[High(IdxFile.Entries)].Mode:=$81A4;
        IdxFile.Entries[High(IdxFile.Entries)].Size:=Length(BlobData);
        IdxFile.Entries[High(IdxFile.Entries)].Stage:=0;
      end;
    end;
    GitWriteIndex(AGitDir,IdxFile.Entries,2);
  finally
    Repo.Free;
  end;
end;

end.
