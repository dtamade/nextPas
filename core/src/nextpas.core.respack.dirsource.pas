unit nextpas.core.respack.dirsource;

{** @desc 目录 → 打包适配：唯一 L2→L2 IO seam，流式mmap 零双驻留 ~1×+头，generic TWalkCtx/EnsureWalkCapacity/WalkPrePlain/WalkPreEmbed 单源。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.respack.embed,
  nextpas.core.respack.writer.stream;

type
  { 返回 False 剔除该文件；APath 为相对包路径 }
  TResPackIncludeFunc = reference to function(
    const ARelativePath: string): Boolean;

  { 目录枚举产物。Contents 是 Entries[].Data 的生命期锚点：两字段为托管
    数组、整体按值返回，调用方持有 bundle 期间内容缓冲保证存活；送入
    ResPackBuild 后即可丢弃。S4 修复：此前锚点是函数局部变量，返回即释放，
    调用方拿到悬垂 Data 指针（gate 靠分配器运气通过）。 }
  TResPackDirEntries = record
    Entries: TResPackInputArray;
    Contents: array of TBytes;
  end;

{ 枚举目录树为打包条目。超过 RESPACK_MAX_INPUT_BYTES raise EResPackTooLarge；
  遍历错误 raise EResPackDirSourceFailed。
  @deprecated 小包便捷保留；大包请优先 ResPackBuildStreamFromDir 流式mmap 管线。 }
function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc = nil): TResPackDirEntries; deprecated 'use ResPackBuildStreamFromDir / ResPackBuildFromDir (streaming mmap)';

{ 流式mmap：目录 → 流式两遍分段零双驻留打包。映射零拷贝（经 dirsource.mmap 单源），映射生命期至
  AWrite 完成，try..finally 释放不丢。 }
procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc = nil);

{ 目录 → 内存 blob 便捷：流式mmap 版，复用 ResPackBuildStreamFromDir 管线。 }
function ResPackBuildFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions;
  const AInclude: TResPackIncludeFunc = nil): TResPackBlob;

{ 预计算目录打包总字节（零分配首遍，仅布局计算）}
function ResPackBuildStreamSizeFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions;
  const AInclude: TResPackIncludeFunc = nil): UInt64;

{** 解包 blob 全部条目到 ADestDir（include_dir extract 对等物，调试/迁移用）。
  目录不存在则创建（含中间层）；同名已存在文件直接覆盖；不恢复 mtime（v1）。
  条目路径经 reader 的 FORMAT.md 校验且为 unrooted 无 '..' 形态，不存在越界
  写出。打开失败按 reader 错误族抛出。 }
procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string);

{** 目录 → blob 嵌入打包（IO 管线，唯一 L2→L2 FS seam）。
  过滤/映射管线（StripPrefix→ValidPath→GlobMatch→AddPrefix→ValidPath）复用
  L1 text.strings GlobMatch 单源（PChar 零拷贝 + inline + O(pat×name) 双追踪器）
  + bytes.ops 单源；过滤后 0 条目显式报错（空包几乎总是 glob 写错），绝不静默产出。 }
function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;

{** 流式嵌入打包：目录 → 分段 AWrite 回调，峰值 ~1×+头（mmap 零堆拷贝 + writer.stream 两遍零双驻留）。
  与 ResPackEmbedBuild 同确定性，抽取为独立流式候选供大资产目录复用；ResPackEmbedBuild 为其内存 sink 薄封装。 }
procedure ResPackEmbedBuildStream(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions; const AWrite: TResPackWriteProc);

{ 预计算嵌入打包总字节（零分配首遍，仅布局计算；与 ResPackEmbedBuildStream 同 Walk 确定性）。
  inline 薄转发于实现节 Collect 单源，外部预取嵌入流总长入口。 }
function ResPackEmbedStreamSizeFromDir(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): UInt64;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.path,
  nextpas.core.io.mapped,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.respack.dirsource.mmap,
  nextpas.core.respack.reader,
  nextpas.core.respack.writer,
  nextpas.core.respack.writer.layout;

type
  TResPackBytesArray = array of TBytes;
  TResPackMapsArray = array of IMappedFile;
  PDirContext = ^TDirContext;
  TDirContext = record
    Root: string;             { 归一前缀单源：供 PathStripPrefix 复用，零拷贝视图 }
    RootPrefixLen: Integer;   { 兼容长度，保留用于调试；主路径剥离走 PathStripPrefix 单源 }
    Include: TResPackIncludeFunc;
    Entries: TResPackInputArray;
    Bytes: TResPackBytesArray;   { 内容生命期锚点 }
    Count: SizeUInt;          { 已用条目数；Length 为容量 }
    Cap: SizeUInt;            { 已分配容量，指数增长消 O(n²) }
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

  { 通用 Walk 上下文单源：generic TWalkCtx<TAnchor> 收敛 plain/stream/embed 三套
    Count/Cap/Total/Failed（legacy TDirContext 仅 deprecated 小包保留）；
    stream/embed 同为 IMappedFile 锚点，Entries[] Data 为其零拷贝视图。 }
  generic TWalkCtx<TAnchor> = record
    Root: string;
    Include: TResPackIncludeFunc;
    EmbedOpts: TResPackEmbedOptions;
    IsEmbed: Boolean;
    Entries: TResPackInputArray;
    Anchors: array of TAnchor;
    Count: SizeUInt;
    Cap: SizeUInt;
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

  TStreamWalkCtx = specialize TWalkCtx<IMappedFile>;
  PStreamContext = ^TStreamWalkCtx;
  TStreamContext = TStreamWalkCtx;
  TEmbedWalkCtx = specialize TWalkCtx<IMappedFile>;
  PEmbedStreamContext = ^TEmbedWalkCtx;
  TEmbedStreamContext = TEmbedWalkCtx;

{ 单源前缀剥离：PathStripPrefix 单源转发，inline 零拷贝，替代手写 Copy/while/StringReplace/$IFDEF }
function RelativizePath(const ARoot, AFullPath: string): string; inline;
begin
  Result := PathStripPrefix(AFullPath, ARoot);
  if Result = '.' then
    Result := '';
end;

{ 公共过滤管线：前缀剥离 → ValidPath → Include；返回 False 表示跳过（非错误）}
function FilterRelPath(const ARoot, AFullPath: string; const AInclude: TResPackIncludeFunc; out ARel: string): Boolean; inline;
begin
  ARel := RelativizePath(ARoot, AFullPath);
  if not ResPackValidPath(ARel, True) then
    Exit(False);
  if (AInclude <> nil) and (not AInclude(ARel)) then
    Exit(False);
  Result := True;
end;

{ 32 位回绕防护：TryAddSizeUInt 单源（inline 零开销），超 512MB 返回 False }
function TryReserveTotal(const ATotal: SizeUInt; const AFileSize: Int64; out ANewTotal: SizeUInt): Boolean; inline;
begin
  if AFileSize < 0 then
    Exit(False);
  if not TryAddSizeUInt(ATotal, SizeUInt(AFileSize), ANewTotal) then
    Exit(False);
  if ANewTotal > RESPACK_MAX_INPUT_BYTES then
    Exit(False);
  Result := True;
end;

{ 公共双数组扩容 helper：EnsureDual 双重载（TBytes / IMappedFile），复用 bytes.ops 单源，inline 零拷贝 }
procedure EnsureDual(var ACap: SizeUInt; const ACount, ANeeded: SizeUInt; var AEntries: TResPackInputArray; var ASecond: TResPackBytesArray); overload; inline;
begin
  if ACount < ACap then Exit;
  ACap := BytesNextCapacity(ACap, ANeeded);
  SetLength(AEntries, ACap);
  SetLength(ASecond, ACap);
end;

procedure EnsureDual(var ACap: SizeUInt; const ACount, ANeeded: SizeUInt; var AEntries: TResPackInputArray; var ASecond: TResPackMapsArray); overload; inline;
begin
  if ACount < ACap then Exit;
  ACap := BytesNextCapacity(ACap, ANeeded);
  SetLength(AEntries, ACap);
  SetLength(ASecond, ACap);
end;

procedure EnsureDirCapacity(var Ctx: TDirContext; const ANeeded: SizeUInt); inline;
begin
  EnsureDual(Ctx.Cap, Ctx.Count, ANeeded, Ctx.Entries, Ctx.Bytes);
end;

{ 通用扩容实现单源：stream/embed 经此收敛，BytesNextCapacity 单源 inline 零拷贝。 }
generic procedure EnsureWalkCapacity<TAnchor>(
  var Ctx: specialize TWalkCtx<TAnchor>; const ANeeded: SizeUInt); inline;
begin
  if Ctx.Count < Ctx.Cap then Exit;
  Ctx.Cap := BytesNextCapacity(Ctx.Cap, ANeeded);
  SetLength(Ctx.Entries, Ctx.Cap);
  SetLength(Ctx.Anchors, Ctx.Cap);
end;

procedure EnsureStreamCapacity(var Ctx: TStreamContext; const ANeeded: SizeUInt); inline;
begin
  specialize EnsureWalkCapacity<IMappedFile>(Ctx, ANeeded);
end;

procedure EnsureEmbedCapacity(var Ctx: TEmbedStreamContext; const ANeeded: SizeUInt); inline;
begin
  specialize EnsureWalkCapacity<IMappedFile>(Ctx, ANeeded);
end;

{ Walk 单源：WalkPre 统一 Stat/Filter/TryReserve，inline 零拷贝；
  上下文/扩容经 generic TWalkCtx<T>/EnsureWalkCapacity<T> 单源收敛，
  收集经 CollectStream/EmbedEntries 单次 Walk 单源（>800 行拆子模块门禁内）。 }
procedure WalkFail(var AFailed: Boolean; var AFailMsg: string; const AMsg: string); inline;
begin
  AFailed := True;
  AFailMsg := AMsg;
end;

function WalkHandleErr(const AErr: Exception; var AFailed: Boolean; var AFailMsg: string): Boolean; inline;
begin
  if AErr <> nil then
  begin
    WalkFail(AFailed, AFailMsg, AErr.Message);
    Exit(False);
  end;
  Result := True;
end;

function WalkTryStat(const APath: string; out ASt: TFileInfo; var AFailed: Boolean; var AFailMsg: string): Boolean;
begin
  try
    ASt := Stat(APath);
    Result := True;
  except
    on E: Exception do
    begin
      WalkFail(AFailed, AFailMsg, 'stat failed: ' + E.Message + ' (path=' + APath + ')');
      Result := False;
    end;
  end;
end;

function WalkTryReserve(const ATotal: SizeUInt; const AFileSize: Int64; out ANewTotal: SizeUInt; var AFailed: Boolean; var AFailMsg: string): Boolean; inline;
begin
  if not TryReserveTotal(ATotal, AFileSize, ANewTotal) then
  begin
    WalkFail(AFailed, AFailMsg, 'total input exceeds limit');
    Exit(False);
  end;
  Result := True;
end;

function MapAndFilter(const AOpts: TResPackEmbedOptions; const ARel: string; out AOut: string): Boolean; forward;

{ Walk 通用预检单源：plain Embed 共用 WalkHandleErr/WalkTryStat/WalkTryReserve，inline 零拷贝，替代三回调重复；RelativizePath/FilterRelPath/TryReserveTotal 单源复用，失败经 WalkFail 归一不丢资源 }
function WalkPrePlain(const APath: string; const AInfo: TFileInfo; const AErr: Exception;
  const ARoot: string; const AInclude: TResPackIncludeFunc;
  var AFailed: Boolean; var AFailMsg: string;
  out ARel: string; out ASt: TFileInfo; out ALSum: SizeUInt; var ATotal: SizeUInt): Boolean; inline;
begin
  if not WalkHandleErr(AErr, AFailed, AFailMsg) then Exit(False);
  if AInfo.FileType <> ftRegular then Exit(False); { skip: symlink/目录/特殊文件 }
  if not FilterRelPath(ARoot, APath, AInclude, ARel) then Exit(False); { skip: 过滤 }
  if not WalkTryStat(APath, ASt, AFailed, AFailMsg) then Exit(False);
  if not WalkTryReserve(ATotal, ASt.Size, ALSum, AFailed, AFailMsg) then Exit(False);
  Result := True;
end;

function WalkPreEmbed(const APath: string; const AInfo: TFileInfo; const AErr: Exception;
  const ARoot: string; const AEmbedOpts: TResPackEmbedOptions;
  var AFailed: Boolean; var AFailMsg: string;
  out ARel, AMapped: string; out ASt: TFileInfo; out ALSum: SizeUInt; var ATotal: SizeUInt): Boolean;
var
  LRel: string;
begin
  if not WalkHandleErr(AErr, AFailed, AFailMsg) then Exit(False);
  if AInfo.FileType <> ftRegular then Exit(False);
  LRel := RelativizePath(ARoot, APath);
  try
    if not MapAndFilter(AEmbedOpts, LRel, AMapped) then Exit(False);
  except
    on E: Exception do
    begin
      WalkFail(AFailed, AFailMsg, E.Message);
      Exit(False);
    end;
  end;
  ARel := LRel;
  if not WalkTryStat(APath, ASt, AFailed, AFailMsg) then Exit(False);
  if not WalkTryReserve(ATotal, ASt.Size, ALSum, AFailed, AFailMsg) then Exit(False);
  Result := True;
end;

function WalkProc(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PDirContext;
  Rel: string;
  Idx: SizeUInt;
  St: TFileInfo;
  LSum: SizeUInt;
begin
  Result := True;
  Ctx := PDirContext(AUserData);
  if not WalkPrePlain(APath, AInfo, AErr, Ctx^.Root, Ctx^.Include, Ctx^.Failed, Ctx^.FailMsg, Rel, St, LSum, Ctx^.Total) then
  begin
    if Ctx^.Failed then Exit(False) else Exit(True);
  end;
  { 小包便捷：同步 ReadFile 驻留 ~2×+头；大包走流式mmap ~1×+头，限 64MiB 防 OOM。 }
  if LSum > RESPACK_DIRSOURCE_LEGACY_LIMIT then
  begin
    WalkFail(Ctx^.Failed, Ctx^.FailMsg, 'deprecated ResPackEntriesFromDir exceeds 64MiB (2× peak ~128MiB+头), use ResPackBuildStreamFromDir/ResPackBuildFromDir streaming mmap');
    Exit(False);
  end;
  Idx := Ctx^.Count;
  EnsureDirCapacity(Ctx^, Idx + 1);
  try
    Ctx^.Bytes[Idx] := ReadFile(APath); { TBytes 全量锚点：小包便捷≤RESPACK_DIRSOURCE_LEGACY_LIMIT，大包请走流式mmap }
  except
    on E: Exception do
    begin
      Ctx^.Failed := True;
      Ctx^.FailMsg := 'read failed: ' + E.Message + ' (path=' + APath + ')';
      Exit(False);
    end;
  end;
  Ctx^.Entries[Idx].Path := Rel;
  Ctx^.Entries[Idx].Data := Pointer(Ctx^.Bytes[Idx]);
  Ctx^.Entries[Idx].DataSize := SizeUInt(Length(Ctx^.Bytes[Idx]));
  Ctx^.Entries[Idx].ModTime := St.ModTime div 1000000000;
  Inc(Ctx^.Count);
  Ctx^.Total := LSum; { 复用已校验的 LSum，避免二次裸加回绕；inline 零拷贝 }
end;

function WalkProcStream(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PStreamContext;
  Rel: string;
  Idx: SizeUInt;
  St: TFileInfo;
  LSum: SizeUInt;
  LMap: IMappedFile;
  LErr: string;
begin
  Result := True;
  Ctx := PStreamContext(AUserData);
  if not WalkPrePlain(APath, AInfo, AErr, Ctx^.Root, Ctx^.Include, Ctx^.Failed, Ctx^.FailMsg, Rel, St, LSum, Ctx^.Total) then
  begin
    if Ctx^.Failed then Exit(False) else Exit(True);
  end;
  { 流式mmap：映射零拷贝 ~1×+头；复用 Walk 单源，仅 Data 加载分叉。 }
  Idx := Ctx^.Count;
  EnsureStreamCapacity(Ctx^, Idx + 1);
  if not TryMmapRequire(APath, St.Size, LMap, LErr) then
  begin
    WalkFail(Ctx^.Failed, Ctx^.FailMsg, LErr);
    Exit(False);
  end;
  Ctx^.Anchors[Idx] := LMap; { 接口锚点，零拷贝视图生命期与 Entries 绑定，try..finally 释放不丢 }
  Ctx^.Entries[Idx].Path := Rel;
  if LMap <> nil then
  begin
    Ctx^.Entries[Idx].Data := LMap.Data;
    Ctx^.Entries[Idx].DataSize := SizeUInt(LMap.Size);
  end
  else
  begin
    Ctx^.Entries[Idx].Data := nil;
    Ctx^.Entries[Idx].DataSize := 0;
  end;
  Ctx^.Entries[Idx].ModTime := St.ModTime div 1000000000;
  Inc(Ctx^.Count);
  Ctx^.Total := LSum;
end;

function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc): TResPackDirEntries;
var
  Ctx: TDirContext;
  RootClean: string;
begin
  Result.Entries := nil;
  Result.Contents := nil;
  { 尾斜杠归一 + 小包 ≤64MiB；流式 ~1×+头，无双驻留。 }
  RootClean := ExcludeTrailingPathDelimiter(ARoot);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ARoot, 'respack.dirsource: not a directory "'
      + ARoot + '"');

  Ctx.Root := RootClean;
  Ctx.Include := AInclude;
  Ctx.Entries := nil;
  Ctx.Bytes := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  WalkEx(RootClean, @WalkProc, @Ctx);
  if Ctx.Failed then
    raise EResPackDirSourceFailed.CreateCtx('walk', ARoot, 'respack.dirsource: ' + Ctx.FailMsg);
  if SizeUInt(Length(Ctx.Entries)) <> Ctx.Count then
  begin
    SetLength(Ctx.Entries, Ctx.Count);
    SetLength(Ctx.Bytes, Ctx.Count);
  end;
  if Ctx.Total > RESPACK_DIRSOURCE_LEGACY_LIMIT then
    raise EResPackTooLarge.Create('deprecated ResPackEntriesFromDir exceeds 64MiB (2× peak ~128MiB+头), use ResPackBuildStreamFromDir/ResPackBuildFromDir streaming mmap');
  Result.Entries := Ctx.Entries;
  Result.Contents := Ctx.Bytes;
end;

{ 单次 Walk 收集单源：目录 → Entries + mmap 锚点（调用方持有 Anchors 至 Build/Size 完成）；
  inline 薄封装 WalkEx + 修剪，零拷贝视图，失败按 EResPackDirSourceFailed 抛出。 }
procedure CollectStreamEntries(const ARoot: string;
  const AInclude: TResPackIncludeFunc;
  out AEntries: TResPackInputArray; out AAnchors: TResPackMapsArray);
var
  Ctx: TStreamContext;
  RootClean: string;
begin
  AEntries := nil;
  AAnchors := nil;
  RootClean := ExcludeTrailingPathDelimiter(ARoot);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ARoot, 'respack.dirsource: not a directory "'
      + ARoot + '"');
  Ctx.Root := RootClean;
  Ctx.Include := AInclude;
  Ctx.EmbedOpts := ResPackDefaultEmbedOptions;
  Ctx.IsEmbed := False;
  Ctx.Entries := nil;
  Ctx.Anchors := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  WalkEx(RootClean, @WalkProcStream, @Ctx);
  if Ctx.Failed then
  begin
    SetLength(Ctx.Anchors, 0);
    SetLength(Ctx.Entries, 0);
    raise EResPackDirSourceFailed.CreateCtx('walk', ARoot, 'respack.dirsource: ' + Ctx.FailMsg);
  end;
  if SizeUInt(Length(Ctx.Entries)) <> Ctx.Count then
  begin
    SetLength(Ctx.Entries, Ctx.Count);
    SetLength(Ctx.Anchors, Ctx.Count);
  end;
  AEntries := Ctx.Entries;
  AAnchors := Ctx.Anchors;
end;

{ 分片直写单源：PByte → IFile 64K 分片，零堆拷贝；返回 0 防活锁抛异常，finally Close 不丢。 }
procedure WriteFileSlice(const APath: string; AData: PByte; ASize: UInt64);
var
  F: IFile;
  Rem: UInt64;
  Chunk, Wrote, Step: SizeUInt;
  P: PByte;
begin
  F := Create(APath);
  try
    if ASize = 0 then Exit;
    P := AData;
    Rem := ASize;
    while Rem > 0 do
    begin
      if Rem > RESPACK_WRITER_HEAD_CHUNK then Chunk := RESPACK_WRITER_HEAD_CHUNK
      else Chunk := SizeUInt(Rem);
      Wrote := 0;
      while Wrote < Chunk do
      begin
        Step := F.Write((P + Wrote)^, Chunk - Wrote);
        if Step = 0 then
          raise EResPackDirSourceFailed.CreateCtx('write', APath, 'respack.dirsource: write returned 0');
        Inc(Wrote, Step);
      end;
      Inc(P, Chunk);
      Dec(Rem, Chunk);
    end;
  finally
    F.Close;
  end;
end;

procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc);
var
  Entries: TResPackInputArray;
  Anchors: TResPackMapsArray;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.dirsource: Write proc is nil');
  CollectStreamEntries(ARoot, AInclude, Entries, Anchors);
  try
    { 流式两遍零双驻留：复用 writer.stream 单源布局，峰值 ~1×+头，接口锚点在 BuildStream 期间保活 }
    ResPackBuildStream(Entries, AOpts, AWrite);
  finally
    { 稳定性：接口托管的 mmap 视图随 Anchors 清空自动 Unmap，异常路径亦不丢资源 }
    SetLength(Anchors, 0);
    SetLength(Entries, 0);
  end;
end;

function ResPackBuildFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): TResPackBlob;
var
  L: TResPackLayout;
  Entries: TResPackInputArray;
  Anchors: TResPackMapsArray;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 单次 Walk + 单次布局：Collect 单源枚举一次，ComputeLayout 1×（排序/fnv/去重），
    BuildLayoutBlob 直排堆 blob；禁 Size+BuildStream 双算（stream 单源语）。
    峰值 ~1×+头，try..finally 释放不丢 }
  CollectStreamEntries(ARoot, AInclude, Entries, Anchors);
  try
    ResPackComputeLayout(Entries, AOpts, L);
    try
      Result := ResPackBuildLayoutBlob(Entries, AOpts, L);
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Anchors, 0);
    SetLength(Entries, 0);
  end;
end;

function ResPackBuildStreamSizeFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): UInt64;
var
  Entries: TResPackInputArray;
  Anchors: TResPackMapsArray;
begin
  CollectStreamEntries(ARoot, AInclude, Entries, Anchors);
  try
    Result := ResPackBuildStreamSize(Entries, AOpts);
  finally
    SetLength(Anchors, 0);
    SetLength(Entries, 0);
  end;
end;

procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string);
var
  RP: TResPack;
  Idx: SizeUInt;
  Entry: TResPackEntry;
  DestPath, ParentDir: string;
begin
  if ABlob.Data = nil then
    raise EResPackCorrupted.CreateStep(1, 'extract', '', 'blob is nil');
  RP := TResPack.Open(ABlob.Data, ABlob.Size);
  try
    MkdirAll(ADestDir);
    if RP.Count > 0 then
      for Idx := 0 to RP.Count - 1 do
      begin
        Entry := RP.EntryAt(Idx);
        DestPath := PathJoin(ADestDir, RP.PathOf(Entry));
        { 父目录：复用 nextpas.core.path.PathDir 单源（零拷贝视图，inline），替代手写 downto 逐字符扫 '/' + Copy 分叉。 }
        ParentDir := PathDir(DestPath);
        if (ParentDir <> '') and (ParentDir <> '.') then
          MkdirAll(ParentDir);
        { 零堆拷贝：ContentPtr 视图 → IFile 64K 分片直写（WriteFileSlice 单源），
          消逐文件 SetLength+BytesCopy 整块中转（大文件省一次堆拷贝与峰值），finally Close 不丢。 }
        WriteFileSlice(DestPath, RP.ContentPtr(Entry), Entry.Size);
      end;
  finally
    RP.Close;
  end;
end;

{ ResPackEmbedBuild — IO 管线实现（dirsource 唯一 FS seam；选项校验归 embed 拥有） }

{ 前向声明：CollectEmbedEntries 经 WalkEx 回调嵌入 Walk（实现在后） }
function WalkProcEmbedStream(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean; forward;

{ 嵌入收集单源：目录 → Entries + mmap 锚点；选项校验委派 embed 拥有，
  过滤/映射管线（StripPrefix→ValidPath→GlobMatch→AddPrefix→ValidPath）仍复用
  L1 text.strings GlobMatch 单源；空匹配显式报错，绝不静默产出空包。 }
procedure CollectEmbedEntries(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions;
  out AEntries: TResPackInputArray; out AAnchors: TResPackMapsArray);
var
  Ctx: TEmbedStreamContext;
  RootClean: string;
begin
  AEntries := nil;
  AAnchors := nil;
  ResPackEmbedCheckOptions(AOpts);
  RootClean := ExcludeTrailingPathDelimiter(ASourceDir);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ASourceDir, 'respack.dirsource: not a directory "'
      + ASourceDir + '"');
  Ctx.Root := RootClean;
  Ctx.EmbedOpts := AOpts;
  Ctx.IsEmbed := True;
  Ctx.Include := nil;
  Ctx.Entries := nil;
  Ctx.Anchors := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  WalkEx(RootClean, @WalkProcEmbedStream, @Ctx);
  if Ctx.Failed then
  begin
    SetLength(Ctx.Anchors, 0);
    SetLength(Ctx.Entries, 0);
    raise EResPackDirSourceFailed.CreateCtx('walk', ASourceDir, 'respack.dirsource: ' + Ctx.FailMsg);
  end;
  if SizeUInt(Length(Ctx.Entries)) <> Ctx.Count then
  begin
    SetLength(Ctx.Entries, Ctx.Count);
    SetLength(Ctx.Anchors, Ctx.Count);
  end;
  if Ctx.Count = 0 then
  begin
    SetLength(Ctx.Anchors, 0);
    SetLength(Ctx.Entries, 0);
    raise EResPackError.Create('respack.embed: no entries matched after ' +
      'filter/mapping (source "' + ASourceDir + '")');
  end;
  AEntries := Ctx.Entries;
  AAnchors := Ctx.Anchors;
end;

function MapAndFilter(const AOpts: TResPackEmbedOptions;
  const ARel: string; out AOut: string): Boolean;
var
  Logical: string;
  I: SizeUInt;
begin
  Result := False;
  { StripPrefix：复用同文件 RelativizePath→PathStripPrefix 单源（PathToSlash 归一 + 零拷贝 Copy 单次，inline），替代手写 Copy 比较/截取双套前缀实现。 }
  if AOpts.StripPrefix <> '' then
  begin
    Logical := PathStripPrefix(ARel, AOpts.StripPrefix);
    if Logical = '' then Exit;        { 非前缀 }
    if Logical = '.' then Exit;       { ARel == StripPrefix（无剩余逻辑路径）}
    { PathStripPrefix 已去前缀及单分隔符，Logical 即剥离后相对路径 }
  end
  else
    Logical := ARel;
  if not ResPackValidPath(Logical, True) then
    Exit;
  if SizeUInt(Length(AOpts.ExcludeGlobs)) > 0 then
    for I := 0 to SizeUInt(Length(AOpts.ExcludeGlobs)) - 1 do
      if GlobMatch(AOpts.ExcludeGlobs[I], Logical) then
        Exit;
  if SizeUInt(Length(AOpts.IncludeGlobs)) > 0 then
  begin
    for I := 0 to SizeUInt(Length(AOpts.IncludeGlobs)) - 1 do
      if GlobMatch(AOpts.IncludeGlobs[I], Logical) then
      begin
        Result := True;
        Break;
      end;
    if not Result then
      Exit;
  end;
  AOut := AOpts.AddPrefix + Logical;
  if not ResPackValidPath(AOut, True) then
    raise EResPackInvalidPath.Create('respack.embed: mapped path invalid "'
      + AOut + '"');
  Result := True;
end;

{ 嵌入专用 mmap Walk：复用 MapAndFilter/GlobMatch 单源，零 TBytes 锚点，峰值 ~1×+头；通用 Walk 单源 WalkPreEmbed 模板化，inline 零拷贝 }
function WalkProcEmbedStream(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PEmbedStreamContext;
  Rel, Mapped: string;
  Idx: SizeUInt;
  St: TFileInfo;
  LSum: SizeUInt;
  LMap: IMappedFile;
  LErr: string;
begin
  Result := True;
  Ctx := PEmbedStreamContext(AUserData);
  if not WalkPreEmbed(APath, AInfo, AErr, Ctx^.Root, Ctx^.EmbedOpts, Ctx^.Failed, Ctx^.FailMsg, Rel, Mapped, St, LSum, Ctx^.Total) then
  begin
    if Ctx^.Failed then Exit(False) else Exit(True);
  end;
  Idx := Ctx^.Count;
  EnsureEmbedCapacity(Ctx^, Idx + 1);
  if not TryMmapRequire(APath, St.Size, LMap, LErr) then
  begin
    WalkFail(Ctx^.Failed, Ctx^.FailMsg, LErr);
    Exit(False);
  end;
  Ctx^.Anchors[Idx] := LMap;
  Ctx^.Entries[Idx].Path := Mapped;
  if LMap <> nil then
  begin
    Ctx^.Entries[Idx].Data := LMap.Data;
    Ctx^.Entries[Idx].DataSize := SizeUInt(LMap.Size);
  end
  else
  begin
    Ctx^.Entries[Idx].Data := nil;
    Ctx^.Entries[Idx].DataSize := 0;
  end;
  Ctx^.Entries[Idx].ModTime := St.ModTime div 1000000000;
  Inc(Ctx^.Count);
  Ctx^.Total := LSum;
end;

procedure ResPackEmbedBuildStream(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions; const AWrite: TResPackWriteProc);
var
  Entries: TResPackInputArray;
  Anchors: TResPackMapsArray;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.dirsource: Write proc is nil');
  CollectEmbedEntries(ASourceDir, AOpts, Entries, Anchors);
  try
    { 流式mmap 零拷贝 + writer.stream 两遍零双驻留：峰值 ~1×+头（mmap 虚存零堆拷贝 + 头块 KB 级分段 AWrite），稳定性 try..finally 释放不丢；单源 ResPackBuildStream 复用 writer.layout }
    ResPackBuildStream(Entries, AOpts.Build, AWrite);
  finally
    SetLength(Anchors, 0);
    SetLength(Entries, 0);
  end;
end;

function ResPackEmbedStreamSizeFromDir(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): UInt64;
var
  Entries: TResPackInputArray;
  Anchors: TResPackMapsArray;
begin
  CollectEmbedEntries(ASourceDir, AOpts, Entries, Anchors);
  try
    Result := ResPackBuildStreamSize(Entries, AOpts.Build);
  finally
    SetLength(Anchors, 0);
    SetLength(Entries, 0);
  end;
end;

function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;
var
  L: TResPackLayout;
  Entries: TResPackInputArray;
  Anchors: TResPackMapsArray;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 单次 Walk + 单次布局：Collect 单源枚举一次，ComputeLayout 1×（排序/fnv/去重），
    BuildLayoutBlob 直排堆 blob；禁 Size+BuildStream 双算（stream 单源语）。
    峰值 ~1×+头，try..finally 释放不丢 }
  CollectEmbedEntries(ASourceDir, AOpts, Entries, Anchors);
  try
    ResPackComputeLayout(Entries, AOpts.Build, L);
    try
      Result := ResPackBuildLayoutBlob(Entries, AOpts.Build, L);
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Anchors, 0);
    SetLength(Entries, 0);
  end;
end;

end.
