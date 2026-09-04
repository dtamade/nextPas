unit nextpas.core.git.native.repository.diff.query;

{$I nextpas.core.settings.inc}

{ repository.diff 查询域: 修订间/工作树 diff + 补丁文本.
  内容行化/hunk 经 read/hunks 域单源复用.
  依赖: read/hunks (repository.diff.*) + L0-L1 owner + repo/revparse/diff. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.base,
  nextpas.core.git.native.diff;

function RepositoryDiffEx(const AGitDir, AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff;
function RepositoryDiffWorkingTreeEx(const AGitDir, AWorkTree, ARef: string; const AOptions: TGitDiffOptions): TGitDiff;
function RepositoryWorkdirPatchText(const AGitDir, AWorkTree, ARevspec: string; const APaths: TStringArray; AShowBinary: Boolean): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.repository.diff.read,
  nextpas.core.git.native.repository.diff.hunks;

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

end.
