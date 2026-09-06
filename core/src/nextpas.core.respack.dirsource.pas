unit nextpas.core.respack.dirsource;

{** @desc 目录 → 打包适配：唯一 L2→L2 FS seam（fs+path；io.mapped 经 dirsource.mmap 单源，本单元不直引），流式mmap 零双驻留 ~1×+头，WalkPrePlain/Embed + CleanRootDir 单源 inline 零拷贝，内存组装契约镜像 writer.stream.ResPackBuildLayoutBlob（GetMem 单次+BytesCopy 直填+Off 校验+OOM→TooLarge，见 writer.stream.ResPackBuildLayoutBlob；文件背与内存背不同源故骨架镜像非直调），布局基座经 ResPackComputeLayout 1× + 文件背 fnv/哈希回验补丁（去重哈希经 respack.hasharena.ResPackDedupInit 单源，tiny≤4 线性免 arena），发射按槽单映射写+摘要融合（见 writer.stream.ResPackEmitLayout 四阶段镜像；头/哈希经 builder 单源，零页经 BYTES_ZERO_PAGE 单源）。embed 纯逻辑归 embed 拥有（选项校验/Glob/Inc 源），本单元仅收口 IO 走查（ResPackEmbedBuild 系内存 sink 薄封装）。约1100 行：枚举/有界布局/发射/解包同 seam 收口，超阈按 dirsource.walk/embed/extract 拆子模块。 }

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
  nextpas.core.mem.arena.local,
  nextpas.core.mem.base,
  nextpas.core.path,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.respack.dirsource.mmap,
  nextpas.core.respack.hasharena,
  nextpas.core.respack.reader,
  nextpas.core.respack.writer.builder,
  nextpas.core.respack.writer.layout;

type
  TResPackBytesArray = array of TBytes;
  { 锚点类型单源于 dirsource.mmap（io.mapped 经该缝单源，本单元不直引 io.mapped；TResPackMapsArray 为历史 mmap 常驻管线锚点别名保留，当前有界管线 0 映射不再具化） }
  IMappedFile = nextpas.core.respack.dirsource.mmap.IMappedFile;
  TResPackMapsArray = nextpas.core.respack.dirsource.mmap.TResPackMapsArray;
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

  { 有界 Walk 上下文：TDirContext 供 deprecated 小包保留（TBytes 锚点 ≤64MiB），TBoundCtx 供有界 0 映射收集（路径/大小，单活发射）；旧 mmap 常驻 N 锚点管线已删（并发映射无界），有界管线并发映射 ≤2。 }

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

{ 共享收集前检单源：尾斜杠归一 + Exists/IsDir 校验；plain/stream/embed 三收集入口
  共用，失败按 EResPackDirSourceFailed(opendir) 抛出。冷路径，不 inline（守 I-Cache）。 }
function CleanRootDir(const ARoot: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(ARoot);
  if (not Exists(Result)) or (not IsDir(Result)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ARoot, 'respack.dirsource: not a directory "'
      + ARoot + '"');
end;

{ 小包双数组扩容单源：BytesNextCapacity 几何单源 inline 零拷贝。 }
{ 小包双数组扩容单源：BytesNextCapacity 几何单源 inline 零拷贝。 }
procedure EnsureDual(var ACap: SizeUInt; const ACount, ANeeded: SizeUInt; var AEntries: TResPackInputArray; var ASecond: TResPackBytesArray); inline;
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

{ Walk 失败归一单源：置 Failed + 留言；WalkPre 共用，inline 冷抛守卫。 }
procedure WalkFail(var AFailed: Boolean; var AFailMsg: string; const AMsg: string); inline;
begin
  AFailed := True;
  AFailMsg := AMsg;
end;

{ Walk 单源：WalkPre 统一 Stat/Filter/TryReserve，inline 零拷贝；
  有界收集经 CollectBoundMetas/CollectBoundEmbedMetas 单次 Walk（0 映射，并发映射 ≤2）。 }
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

function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc): TResPackDirEntries;
var
  Ctx: TDirContext;
  RootClean: string;
begin
  Result.Entries := nil;
  Result.Contents := nil;
  { 尾斜杠归一 + 小包 ≤64MiB；流式 ~1×+头，无双驻留。前检经 CleanRootDir 单源。 }
  RootClean := CleanRootDir(ARoot);

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

{ 有界单活锚点：Walk 仅收路径/大小 (0 映射)，布局经 ResPackComputeLayout 1× 基座 + 文件背 fnv/哈希回验补丁（去重哈希经 respack.hasharena.ResPackDedupInit 单源，tiny≤4 线性免 arena；回验外层单映射复用，FNV 段与发射段各 1 映射/文件，并发映射 ≤2），发射按槽单映射写+摘要融合；内存组装契约镜像 writer.stream.ResPackBuildLayoutBlob（文件背与内存背不同源故骨架镜像，GetMem 单次+BytesCopy 直填+Off 校验+OOM→TooLarge）；峰值 ~1×+头，try..finally 不丢。 }
type
  TBoundMeta = record
    EntryPath: string;
    FilePath: string;
    Size: SizeUInt;
    ModTime: Int64;
  end;
  TBoundMetaArray = array of TBoundMeta;
  PBoundCtx = ^TBoundCtx;
  TBoundCtx = record
    Root: string;
    Include: TResPackIncludeFunc;
    EmbedOpts: TResPackEmbedOptions;
    IsEmbed: Boolean;
    Metas: TBoundMetaArray;
    Count: SizeUInt;
    Cap: SizeUInt;
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

{ inline 零拷贝：直行扩容，BytesNextCapacity 单源 }
procedure EnsureBoundCap(var Ctx: TBoundCtx; const ANeeded: SizeUInt); inline;
begin
  if Ctx.Count < Ctx.Cap then Exit;
  Ctx.Cap := BytesNextCapacity(Ctx.Cap, ANeeded);
  SetLength(Ctx.Metas, Ctx.Cap);
end;

function WalkProcBoundPlain(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PBoundCtx;
  Rel: string;
  St: TFileInfo;
  LSum: SizeUInt;
  Idx: SizeUInt;
begin
  Result := True;
  Ctx := PBoundCtx(AUserData);
  if not WalkPrePlain(APath, AInfo, AErr, Ctx^.Root, Ctx^.Include, Ctx^.Failed, Ctx^.FailMsg, Rel, St, LSum, Ctx^.Total) then
  begin
    if Ctx^.Failed then Exit(False) else Exit(True);
  end;
  Idx := Ctx^.Count;
  EnsureBoundCap(Ctx^, Idx + 1);
  Ctx^.Metas[Idx].EntryPath := Rel;
  Ctx^.Metas[Idx].FilePath := APath;
  Ctx^.Metas[Idx].Size := SizeUInt(St.Size);
  Ctx^.Metas[Idx].ModTime := St.ModTime div 1000000000;
  Inc(Ctx^.Count);
  Ctx^.Total := LSum;
end;

function WalkProcBoundEmbed(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PBoundCtx;
  Rel, Mapped: string;
  St: TFileInfo;
  LSum: SizeUInt;
  Idx: SizeUInt;
begin
  Result := True;
  Ctx := PBoundCtx(AUserData);
  if not WalkPreEmbed(APath, AInfo, AErr, Ctx^.Root, Ctx^.EmbedOpts, Ctx^.Failed, Ctx^.FailMsg, Rel, Mapped, St, LSum, Ctx^.Total) then
  begin
    if Ctx^.Failed then Exit(False) else Exit(True);
  end;
  Idx := Ctx^.Count;
  EnsureBoundCap(Ctx^, Idx + 1);
  Ctx^.Metas[Idx].EntryPath := Mapped;
  Ctx^.Metas[Idx].FilePath := APath;
  Ctx^.Metas[Idx].Size := SizeUInt(St.Size);
  Ctx^.Metas[Idx].ModTime := St.ModTime div 1000000000;
  Inc(Ctx^.Count);
  Ctx^.Total := LSum;
end;

{ 0 映射收集：仅路径/大小，失败清串抛 walk 错，不丢 }
procedure CollectBoundMetas(const ARoot: string;
  const AInclude: TResPackIncludeFunc; out AMetas: TBoundMetaArray);
var
  Ctx: TBoundCtx;
  RootClean: string;
begin
  AMetas := nil;
  RootClean := CleanRootDir(ARoot);
  Ctx.Root := RootClean;
  Ctx.Include := AInclude;
  Ctx.IsEmbed := False;
  Ctx.Metas := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  WalkEx(RootClean, @WalkProcBoundPlain, @Ctx);
  if Ctx.Failed then
  begin
    Ctx.Metas := nil;
    raise EResPackDirSourceFailed.CreateCtx('walk', ARoot, 'respack.dirsource: ' + Ctx.FailMsg);
  end;
  if SizeUInt(Length(Ctx.Metas)) <> Ctx.Count then
    SetLength(Ctx.Metas, Ctx.Count);
  AMetas := Ctx.Metas;
end;

{ 0 映射嵌入收集：校验委派 embed 拥有，空匹配显式报错 }
procedure CollectBoundEmbedMetas(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions; out AMetas: TBoundMetaArray);
var
  Ctx: TBoundCtx;
  RootClean: string;
begin
  AMetas := nil;
  ResPackEmbedCheckOptions(AOpts);
  RootClean := CleanRootDir(ASourceDir);
  Ctx.Root := RootClean;
  Ctx.EmbedOpts := AOpts;
  Ctx.IsEmbed := True;
  Ctx.Include := nil;
  Ctx.Metas := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  WalkEx(RootClean, @WalkProcBoundEmbed, @Ctx);
  if Ctx.Failed then
  begin
    Ctx.Metas := nil;
    raise EResPackDirSourceFailed.CreateCtx('walk', ASourceDir, 'respack.dirsource: ' + Ctx.FailMsg);
  end;
  if SizeUInt(Length(Ctx.Metas)) <> Ctx.Count then
    SetLength(Ctx.Metas, Ctx.Count);
  if Ctx.Count = 0 then
  begin
    Ctx.Metas := nil;
    raise EResPackError.Create('respack.embed: no entries matched after ' +
      'filter/mapping (source "' + ASourceDir + '")');
  end;
  AMetas := Ctx.Metas;
end;

{ 单活零拷贝：单文件视图哈希，finally 释锚，不 inline 冷路径 }
function BoundFileFnv(const AFilePath: string; const ASize: SizeUInt): UInt32;
var
  LMap: IMappedFile;
  LErr: string;
begin
  if ASize = 0 then
    Exit(ResPackFnv1a32(nil, 0));
  if not TryMmapRequire(AFilePath, Int64(ASize), LMap, LErr) then
    raise EResPackDirSourceFailed.CreateCtx('mmap', AFilePath, 'respack.dirsource: ' + LErr);
  try
    if (LMap = nil) or (LMap.Data = nil) then
      raise EResPackDirSourceFailed.CreateCtx('mmap', AFilePath, 'respack.dirsource: empty mapping');
    Result := ResPackFnv1a32(LMap.Data, ASize);
  finally
    LMap := nil;
  end;
end;

{ 双活上限：两文件视图比对，SpanEqual 单源，finally 双释；去重内循环优先用外层单映射复用版（见下），免每候选重映射外层文件。 }
function BoundFilesEqual(const APathA, APathB: string; const ASize: SizeUInt): Boolean;
var
  LMapA, LMapB: IMappedFile;
  LErr: string;
begin
  if ASize = 0 then Exit(True);
  if APathA = APathB then Exit(True);
  if not TryMmapRequire(APathA, Int64(ASize), LMapA, LErr) then
    raise EResPackDirSourceFailed.CreateCtx('mmap', APathA, 'respack.dirsource: ' + LErr);
  try
    if not TryMmapRequire(APathB, Int64(ASize), LMapB, LErr) then
      raise EResPackDirSourceFailed.CreateCtx('mmap', APathB, 'respack.dirsource: ' + LErr);
    try
      Result := SpanEqual(TByteSpan.Create(LMapA.Data, ASize), TByteSpan.Create(LMapB.Data, ASize));
    finally
      LMapB := nil;
    end;
  finally
    LMapA := nil;
  end;
end;

{ 外层单映射复用回验：AOuterData 为外层文件已映射视图（Size>0 时非 nil），本函数仅映射槽候选单次，SpanEqual 单源 inline 零拷贝；去重内循环经此收敛，外层每 I 仅 1 映射。 }
function BoundOuterEqualSlot(const AOuterData: PByte; const ASlotPath: string; const ASize: SizeUInt): Boolean; inline;
var
  LMapB: IMappedFile;
  LErr: string;
begin
  if ASize = 0 then Exit(True);
  if not TryMmapRequire(ASlotPath, Int64(ASize), LMapB, LErr) then
    raise EResPackDirSourceFailed.CreateCtx('mmap', ASlotPath, 'respack.dirsource: ' + LErr);
  try
    if (LMapB = nil) or (LMapB.Data = nil) then
      raise EResPackDirSourceFailed.CreateCtx('mmap', ASlotPath, 'respack.dirsource: empty mapping');
    Result := SpanEqual(TByteSpan.Create(AOuterData, ASize), TByteSpan.Create(LMapB.Data, ASize));
  finally
    LMapB := nil;
  end;
end;

{ 单映射融合发射：单文件单次映射内完成 AWrite 直写 + 可选摘要（ADigestOut=nil 则跳过摘要），空文件零映射（摘要传 nil/0）；三遍独立映射（哈希/写出/摘要）收敛为哈希段 1 映射 + 发射段 1 映射，缺页摊销。finally 释锚，不 inline 冷路径。 }
procedure BoundEmitSlot(const AFilePath: string; const ASize: SizeUInt;
  const AWrite: TResPackWriteProc; const AFunc: TResPackDigestFunc; const ADigestOut: PByte);
var
  LMap: IMappedFile;
  LErr: string;
begin
  if ASize = 0 then
  begin
    if (AFunc <> nil) and (ADigestOut <> nil) then
      AFunc(nil, 0, ADigestOut);
    Exit;
  end;
  if not TryMmapRequire(AFilePath, Int64(ASize), LMap, LErr) then
    raise EResPackDirSourceFailed.CreateCtx('mmap', AFilePath, 'respack.dirsource: ' + LErr);
  try
    if (LMap = nil) or (LMap.Data = nil) then
      raise EResPackDirSourceFailed.CreateCtx('mmap', AFilePath, 'respack.dirsource: empty mapping');
    AWrite(LMap.Data, ASize);
    if (AFunc <> nil) and (ADigestOut <> nil) then
      AFunc(LMap.Data, ASize, ADigestOut);
  finally
    LMap := nil;
  end;
end;

{ 零页分段：BYTES_ZERO_PAGE 单源；循环体外联守 I-Cache，≤4K 快道 inline（镜像 writer.stream.WriteZeros）。 }
procedure BoundWriteZerosLoop(const AWrite: TResPackWriteProc; ACount: UInt64);
var
  N: UInt64;
  L: SizeUInt;
begin
  N := ACount;
  while N > 0 do
  begin
    if N >= BYTES_ZERO_PAGE_SIZE then L := BYTES_ZERO_PAGE_SIZE else L := SizeUInt(N);
    AWrite(@BYTES_ZERO_PAGE[0], L);
    Dec(N, L);
  end;
end;

procedure BoundWriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
begin
  if ACount = 0 then Exit;
  if ACount <= BYTES_ZERO_PAGE_SIZE then
  begin
    AWrite(@BYTES_ZERO_PAGE[0], SizeUInt(ACount));
    Exit;
  end;
  BoundWriteZerosLoop(AWrite, ACount);
end;

{ 有界布局：dummy 基座排序（熔断前置，免大额瞬时分配）+ 单活哈希 + 哈希去重（respack.hasharena.ResPackDedupInit 单源，tiny≤4 线性免 arena；回验外层单映射复用，并发映射 ≤2）；尾段 digest/hash/total 镜像 writer.layout 溢出钳制，对齐经 mem.base.AlignUp64 单源。 }
procedure BuildBoundLayout(const AMetas: TBoundMetaArray;
  const AOpts: TResPackBuildOptions; out ALayout: TResPackLayout);
var
  N, I, J, K: SizeUInt;
  LDummy: Byte;
  Dummy: TResPackInputArray;
  BaseOpts: TResPackBuildOptions;
  Fnv: array of UInt32;
  Cur, EndData, DigOff, Total, HashBase: UInt64;
  Buckets: SizeUInt;
  BucketIdx, BucketCount: SizeUInt;
  BucketsHead: nextpas.core.respack.base.PSizeInt;
  SlotNext: nextpas.core.respack.base.PSizeInt;
  Probe: SizeInt;
  DedupArena: TLocalArena;
  LOuterMap: IMappedFile;
  LOuterData: PByte;
  LErr: string;
begin
  ResPackLayoutClear(ALayout);
  N := SizeUInt(Length(AMetas));
  if N > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackTooLarge.Create('respack: entry count exceeds limit');
  LDummy := 0;
  try
    SetLength(Dummy, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      Dummy[I].Path := AMetas[I].EntryPath;
      Dummy[I].DataSize := AMetas[I].Size;
      Dummy[I].ModTime := AMetas[I].ModTime;
      if AMetas[I].Size = 0 then Dummy[I].Data := nil else Dummy[I].Data := @LDummy;
    end;
  BaseOpts := AOpts;
  BaseOpts.Deduplicate := False;
  BaseOpts.Hashes := False;
  ResPackComputeLayout(Dummy, BaseOpts, ALayout);
  Dummy := nil;
  if N = 0 then Exit;
  if (not AOpts.Deduplicate) and (not AOpts.Hashes) then Exit;
  try
    SetLength(Fnv, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
  for I := 0 to N - 1 do
    Fnv[I] := BoundFileFnv(AMetas[I].FilePath, AMetas[I].Size);
  if not AOpts.Deduplicate then
  begin
    SetLength(ALayout.FnvBuf, N);
    for I := 0 to N - 1 do
      ALayout.FnvBuf[I] := Fnv[I];
    for K := 0 to ALayout.SlotCount - 1 do
      ALayout.Slots[K].Fnv := Fnv[ALayout.Slots[K].SrcIdx];
    Fnv := nil;
    Exit;
  end;
  SetLength(ALayout.FnvBuf, N);
  for I := 0 to N - 1 do
    ALayout.FnvBuf[I] := Fnv[I];
  ALayout.SlotCount := 0;
  Cur := ALayout.DataStart;
  if N <= 4 then
  begin
    { tiny 线性免 arena：外层每 I 单映射复用，免每候选重映射外层文件。 }
    for I := 0 to N - 1 do
    begin
      J := ALayout.Order[I];
      ALayout.EntrySlots[J] := SizeUInt(-1);
      LOuterMap := nil;
      LOuterData := nil;
      if AMetas[J].Size > 0 then
      begin
        if not TryMmapRequire(AMetas[J].FilePath, Int64(AMetas[J].Size), LOuterMap, LErr) then
          raise EResPackDirSourceFailed.CreateCtx('mmap', AMetas[J].FilePath, 'respack.dirsource: ' + LErr);
        try
          if (LOuterMap = nil) or (LOuterMap.Data = nil) then
            raise EResPackDirSourceFailed.CreateCtx('mmap', AMetas[J].FilePath, 'respack.dirsource: empty mapping');
          LOuterData := LOuterMap.Data;
          if ALayout.SlotCount > 0 then
            for K := 0 to ALayout.SlotCount - 1 do
              if (ALayout.Slots[K].Fnv = Fnv[J]) and (AMetas[J].Size = AMetas[ALayout.Slots[K].SrcIdx].Size) then
                if (AMetas[J].FilePath = AMetas[ALayout.Slots[K].SrcIdx].FilePath) or
                   BoundOuterEqualSlot(LOuterData, AMetas[ALayout.Slots[K].SrcIdx].FilePath, AMetas[J].Size) then
                begin
                  ALayout.EntrySlots[J] := K;
                  Break;
                end;
        finally
          LOuterMap := nil;
        end;
      end
      else if ALayout.SlotCount > 0 then
        for K := 0 to ALayout.SlotCount - 1 do
          if (ALayout.Slots[K].Fnv = Fnv[J]) and (AMetas[ALayout.Slots[K].SrcIdx].Size = 0) then
          begin
            ALayout.EntrySlots[J] := K;
            Break;
          end;
      if ALayout.EntrySlots[J] = SizeUInt(-1) then
      begin
        Cur := nextpas.core.mem.base.AlignUp64(Cur, RESPACK_DATA_ALIGN);
        ALayout.Slots[ALayout.SlotCount].Offset := Cur;
        ALayout.Slots[ALayout.SlotCount].SrcIdx := J;
        ALayout.Slots[ALayout.SlotCount].Fnv := Fnv[J];
        ALayout.EntrySlots[J] := ALayout.SlotCount;
        Cur := Cur + UInt64(AMetas[J].Size);
        Inc(ALayout.SlotCount);
      end;
    end;
  end
  else
  begin
    { 哈希去重单源于 respack.hasharena.ResPackDedupInit（与 writer.layout 同桶/链语义，O(n) 回验）；外层单映射复用，槽候选单映射，finally 双释不丢。 }
    BucketsHead := nil;
    SlotNext := nil;
    DedupArena := nil;
    nextpas.core.respack.hasharena.ResPackDedupInit(N, DedupArena, BucketsHead, SlotNext, BucketCount);
    try
      for I := 0 to N - 1 do
      begin
        J := ALayout.Order[I];
        ALayout.EntrySlots[J] := SizeUInt(-1);
        BucketIdx := SizeUInt(Fnv[J]) and (BucketCount - 1);
        LOuterMap := nil;
        LOuterData := nil;
        if AMetas[J].Size > 0 then
        begin
          if not TryMmapRequire(AMetas[J].FilePath, Int64(AMetas[J].Size), LOuterMap, LErr) then
            raise EResPackDirSourceFailed.CreateCtx('mmap', AMetas[J].FilePath, 'respack.dirsource: ' + LErr);
          try
            if (LOuterMap = nil) or (LOuterMap.Data = nil) then
              raise EResPackDirSourceFailed.CreateCtx('mmap', AMetas[J].FilePath, 'respack.dirsource: empty mapping');
            LOuterData := LOuterMap.Data;
            Probe := BucketsHead[BucketIdx];
            while Probe <> -1 do
            begin
              K := SizeUInt(Probe);
              if (ALayout.Slots[K].Fnv = Fnv[J]) and (AMetas[J].Size = AMetas[ALayout.Slots[K].SrcIdx].Size) then
                if (AMetas[J].FilePath = AMetas[ALayout.Slots[K].SrcIdx].FilePath) or
                   BoundOuterEqualSlot(LOuterData, AMetas[ALayout.Slots[K].SrcIdx].FilePath, AMetas[J].Size) then
                begin
                  ALayout.EntrySlots[J] := K;
                  Break;
                end;
              Probe := SlotNext[K];
            end;
          finally
            LOuterMap := nil;
          end;
        end
        else
        begin
          Probe := BucketsHead[BucketIdx];
          while Probe <> -1 do
          begin
            K := SizeUInt(Probe);
            if (ALayout.Slots[K].Fnv = Fnv[J]) and (AMetas[ALayout.Slots[K].SrcIdx].Size = 0) then
            begin
              ALayout.EntrySlots[J] := K;
              Break;
            end;
            Probe := SlotNext[K];
          end;
        end;
        if ALayout.EntrySlots[J] = SizeUInt(-1) then
        begin
          Cur := nextpas.core.mem.base.AlignUp64(Cur, RESPACK_DATA_ALIGN);
          ALayout.Slots[ALayout.SlotCount].Offset := Cur;
          ALayout.Slots[ALayout.SlotCount].SrcIdx := J;
          ALayout.Slots[ALayout.SlotCount].Fnv := Fnv[J];
          SlotNext[ALayout.SlotCount] := BucketsHead[BucketIdx];
          BucketsHead[BucketIdx] := SizeInt(ALayout.SlotCount);
          ALayout.EntrySlots[J] := ALayout.SlotCount;
          Cur := Cur + UInt64(AMetas[J].Size);
          Inc(ALayout.SlotCount);
        end;
      end;
    finally
      nextpas.core.respack.hasharena.ResPackDedupDone(DedupArena);
    end;
  end;
  Fnv := nil;
  EndData := Cur;
  if AOpts.DigestFunc <> nil then
  begin
    DigOff := nextpas.core.mem.base.AlignUp64(EndData, 4);
    if (DigOff = 0) and (EndData <> 0) then
      raise EResPackError.Create('respack: digest offset overflow');
    if N > High(UInt64) div RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.Create('respack: digest size overflow');
    if DigOff > High(UInt64) - UInt64(N) * RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.Create('respack: total size overflow');
    Total := DigOff + UInt64(N) * RESPACK_DIGEST_SIZE;
  end
  else
  begin
    DigOff := 0;
    Total := EndData;
  end;
  Buckets := ALayout.HashBuckets;
  if AOpts.HashIndex and (N > 0) then
  begin
    if Buckets > High(UInt64) div SizeUInt(RESPACK_HASH_ENTRY_SIZE) then
      raise EResPackTooLarge.Create('respack: hash segment too large for host');
    if Total > High(UInt64) - (RESPACK_HASH_ALIGN - 1) then
      raise EResPackTooLarge.Create('respack: hash alignment overflow');
    HashBase := nextpas.core.mem.base.AlignUp64(Total, RESPACK_HASH_ALIGN);
    if HashBase > High(UInt64) - UInt64(Buckets) * RESPACK_HASH_ENTRY_SIZE then
      raise EResPackTooLarge.Create('respack: total size overflow');
    ALayout.HashBase := HashBase;
    Total := HashBase + UInt64(Buckets) * RESPACK_HASH_ENTRY_SIZE;
  end;
  if Total > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  ALayout.DigOff := DigOff;
  ALayout.Total := Total;
end;

{ 有界发射：四阶段镜像 writer.stream.ResPackEmitLayout（头经 builder 单源直排、数据按槽单映射写+摘要融合、摘要按 EntrySlots 直排复用、哈希经 builder 单源；文件背与内存背不同源故骨架镜像非直调，直调需 N 并发映射）；槽单调前置拒绝防 Gap 下溢，Dummy 熔断前置，finally 外层清布局。 }
procedure EmitBoundLayout(const AMetas: TBoundMetaArray;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc);
var
  N, I, J, K, S: SizeUInt;
  Cur, Gap: UInt64;
  HeadBuf, HashSeg: TBytes;
  Dummy: TResPackInputArray;
  LDummy: Byte;
  SlotDigests: array of TResPackDigest;
  HasDigest: Boolean;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.stream: Write proc is nil');
  N := ALayout.N;
  if N > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackTooLarge.Create('respack: entry count exceeds limit');
  if N <> SizeUInt(Length(AMetas)) then
    raise EResPackError.Create('respack.stream: layout entry count mismatch');
  if ALayout.SlotCount > SizeUInt(Length(ALayout.Slots)) then
    raise EResPackError.Create('respack.stream: layout slot count exceeds slots');
  HasDigest := AOpts.DigestFunc <> nil;
  LDummy := 0;
  try
    SetLength(Dummy, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      Dummy[I].Path := AMetas[I].EntryPath;
      Dummy[I].DataSize := AMetas[I].Size;
      Dummy[I].ModTime := AMetas[I].ModTime;
      if AMetas[I].Size = 0 then Dummy[I].Data := nil else Dummy[I].Data := @LDummy;
    end;
  if ALayout.DataStart > 0 then
  begin
    SetLength(HeadBuf, SizeUInt(ALayout.DataStart));
    ResPackWriterFillHead(@HeadBuf[0], Dummy, AOpts, ALayout);
    AWrite(@HeadBuf[0], SizeUInt(ALayout.DataStart));
    HeadBuf := nil;
  end;
  Cur := ALayout.DataStart;
  if HasDigest and (ALayout.SlotCount > 0) then
  begin
    try
      SetLength(SlotDigests, ALayout.SlotCount);
    except
      on E: EOutOfMemory do
        raise EResPackTooLarge.Create('respack: digest slots too large for host');
    end;
    for K := 0 to ALayout.SlotCount - 1 do
      BytesZero(@SlotDigests[K][0], RESPACK_DIGEST_SIZE);
  end;
  if ALayout.SlotCount > 0 then
    for K := 0 to ALayout.SlotCount - 1 do
    begin
      J := ALayout.Slots[K].SrcIdx;
      if J >= N then
        raise EResPackError.Create('respack.stream: layout slot source out of range');
      if ALayout.Slots[K].Offset < Cur then
        raise EResPackError.Create('respack.stream: layout slot offsets not monotonic');
      Gap := ALayout.Slots[K].Offset - Cur;
      if Gap > 0 then
        BoundWriteZeros(AWrite, Gap);
      if HasDigest then
        BoundEmitSlot(AMetas[J].FilePath, AMetas[J].Size, AWrite, AOpts.DigestFunc, @SlotDigests[K][0])
      else if AMetas[J].Size > 0 then
        BoundEmitSlot(AMetas[J].FilePath, AMetas[J].Size, AWrite, nil, nil);
      Cur := ALayout.Slots[K].Offset + UInt64(AMetas[J].Size);
    end;
  if HasDigest then
  begin
    if ALayout.DigOff > Cur then
      BoundWriteZeros(AWrite, ALayout.DigOff - Cur);
    Cur := ALayout.DigOff;
    if N > 0 then
      for I := 0 to N - 1 do
      begin
        J := ALayout.Order[I];
        S := ALayout.EntrySlots[J];
        if S >= ALayout.SlotCount then
          raise EResPackError.Create('respack.stream: layout entry-slot out of range');
        AWrite(@SlotDigests[S][0], RESPACK_DIGEST_SIZE);
      end;
    if N > 0 then
      Cur := ALayout.DigOff + UInt64(N) * RESPACK_DIGEST_SIZE;
  end;
  SlotDigests := nil;
  if ALayout.HashBuckets > 0 then
  begin
    if ALayout.HashBase > Cur then
      BoundWriteZeros(AWrite, ALayout.HashBase - Cur);
    SetLength(HashSeg, ALayout.HashBuckets * SizeUInt(RESPACK_HASH_ENTRY_SIZE));
    if Length(HashSeg) > 0 then
    begin
      ResPackWriterFillHash(@HashSeg[0], Dummy, AOpts, ALayout);
      AWrite(@HashSeg[0], SizeUInt(Length(HashSeg)));
    end;
    HashSeg := nil;
  end;
  Dummy := nil;
end;

{ 有界内存组装：契约镜像 writer.stream.ResPackBuildLayoutBlob（GetMem 单次+BytesCopy inline 零拷贝直填+Off 越界前置 guard+OOM→EResPackTooLarge，异常 FreeMem 不丢）；文件背经 EmitBoundLayout 单活发射，内存背经 ResPackEmitLayout，两骨架因背存储不同源故镜像非直调。 }
function BuildBoundBlob(const AMetas: TBoundMetaArray;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout): TResPackBlob;
var
  Total: UInt64;
  Buf: PByte;
  Off: SizeUInt;
  Sink: TResPackWriteProc;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  Total := ALayout.Total;
  if Total = 0 then Exit;
  if Total > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  Buf := nil;
  try
    GetMem(Buf, SizeUInt(Total));
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: blob too large for host');
  end;
  Off := 0;
  Sink :=
    procedure(const AData: PByte; const ASize: SizeUInt)
    var
      Rem: SizeUInt;
    begin
      if ASize = 0 then Exit;
      if AData = nil then
        raise EResPackError.Create('respack: stream chunk has nil data');
      if Off > SizeUInt(Total) then
        raise EResPackError.Create('respack: stream size mismatch');
      Rem := SizeUInt(Total) - Off;
      if ASize > Rem then
        raise EResPackError.Create('respack: stream size mismatch');
      BytesCopy(Buf + Off, AData, ASize);
      Inc(Off, ASize);
    end; { 越界前置 guard，布局/发射分叉即拒，零堆越界写；BytesCopy inline 快道 }
  try
    EmitBoundLayout(AMetas, AOpts, ALayout, Sink);
    if Off <> SizeUInt(Total) then
      raise EResPackError.Create('respack: stream size mismatch');
    Result.Data := Buf;
    Result.Size := SizeUInt(Total);
    Result.Owned := True;
    Buf := nil;
  except
    if Buf <> nil then
      FreeMem(Buf);
    raise;
  end;
end;

procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc);
var
  Metas: TBoundMetaArray;
  L: TResPackLayout;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.dirsource: Write proc is nil');
  CollectBoundMetas(ARoot, AInclude, Metas);
  try
    BuildBoundLayout(Metas, AOpts, L);
    try
      EmitBoundLayout(Metas, AOpts, L, AWrite);
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Metas, 0);
  end;
end;

function ResPackBuildFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): TResPackBlob;
var
  Metas: TBoundMetaArray;
  L: TResPackLayout;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 有界单活：0 映射收集 + 单布局 + 单活发射，峰值 ~1×+头，finally 不丢 }
  CollectBoundMetas(ARoot, AInclude, Metas);
  try
    BuildBoundLayout(Metas, AOpts, L);
    try
      Result := BuildBoundBlob(Metas, AOpts, L);
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Metas, 0);
  end;
end;

function ResPackBuildStreamSizeFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): UInt64;
var
  Metas: TBoundMetaArray;
  L: TResPackLayout;
begin
  { 有界预取：布局 Total 直读，单活哈希/双活回验，并发映射 ≤2 }
  CollectBoundMetas(ARoot, AInclude, Metas);
  try
    BuildBoundLayout(Metas, AOpts, L);
    try
      Result := L.Total;
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Metas, 0);
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

{ ResPackEmbedBuild — IO 管线实现（dirsource 唯一 FS seam；选项校验/Glob/Inc 纯逻辑归 embed 拥有，本单元仅收口走查 + 有界 0 映射收集/布局/单活发射，内存版为流式 thin sink 封装） }

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

procedure ResPackEmbedBuildStream(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions; const AWrite: TResPackWriteProc);
var
  Metas: TBoundMetaArray;
  L: TResPackLayout;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.dirsource: Write proc is nil');
  { 有界单活：嵌入收集 0 映射 + 单布局 + 单活发射，finally 不丢 }
  CollectBoundEmbedMetas(ASourceDir, AOpts, Metas);
  try
    BuildBoundLayout(Metas, AOpts.Build, L);
    try
      EmitBoundLayout(Metas, AOpts.Build, L, AWrite);
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Metas, 0);
  end;
end;

function ResPackEmbedStreamSizeFromDir(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): UInt64;
var
  Metas: TBoundMetaArray;
  L: TResPackLayout;
begin
  { 有界预取：嵌入布局 Total 直读，并发映射 ≤2 }
  CollectBoundEmbedMetas(ASourceDir, AOpts, Metas);
  try
    BuildBoundLayout(Metas, AOpts.Build, L);
    try
      Result := L.Total;
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Metas, 0);
  end;
end;

function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;
var
  Metas: TBoundMetaArray;
  L: TResPackLayout;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 有界内存组装：单次 Walk + 单布局 + 单活直排，禁双算，finally 不丢 }
  CollectBoundEmbedMetas(ASourceDir, AOpts, Metas);
  try
    BuildBoundLayout(Metas, AOpts.Build, L);
    try
      Result := BuildBoundBlob(Metas, AOpts.Build, L);
    finally
      ResPackLayoutClear(L);
    end;
  finally
    SetLength(Metas, 0);
  end;
end;

end.
