unit nextpas.core.git.native.repository.diff.mutate;

{$I nextpas.core.settings.inc}

{ repository.diff 写路径域: 补丁应用 + 路径检出 (工作树/index 落盘).
  内容行化经 read 域单源复用.
  依赖: read (repository.diff.*) + L0-L1 owner + repo/objmodel/revparse/index. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.base;

procedure RepositoryApplyPatch(const AGitDir, AWorkTree, APatchText: string);
procedure RepositoryCheckoutPaths(const AGitDir, AWorkTree, ARevspec: string; const APaths: TStringArray);

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.index,
  nextpas.core.git.native.util,
  nextpas.core.git.native.repository.diff.read,
  nextpas.core.git.native.repository.diff.hunks;

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
