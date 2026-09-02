unit nextpas.core.respack.dirsource;

{** @desc 目录 → 打包条目适配。respack 唯一 L2→L2 IO seam（fs + io.mapped + path/mmap via mem.memory_map）。
  4 职责承载：枚举/流式mmap/嵌入管线/extract；约 730 行已以通用 Walk 单源（generic TWalkCtx<T> + EnsureWalkCapacity<T> + WalkPre 统一模板，inline 零拷贝）收口，近 800 指引候选拆分已评估，当前以单源模板化守阈，超限再抽子模块（CONTRACT 业务为准，缺能力反哺 owner）。 }

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

{ 流式mmap：目录 → 流式两遍分段零双驻留打包。MmapOpen 零拷贝，映射生命期至
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
  nextpas.core.respack.reader,
  nextpas.core.respack.writer;

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

  PStreamContext = ^TStreamContext;
  TStreamContext = record
    Root: string;
    Include: TResPackIncludeFunc;
    Entries: TResPackInputArray;
    Maps: TResPackMapsArray; { mmap 生命期锚点，接口引用计数的零拷贝视图 }
    Count: SizeUInt;
    Cap: SizeUInt;
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

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

{ 指数扩容单源：bytes.ops BytesNextCapacity 单源 O(n²)→O(n)，inline 零拷贝，回绕防护收口 }
function WalkGrowCap(const ACap, ANeeded: SizeUInt): SizeUInt; inline;
begin
  Result := BytesNextCapacity(ACap, ANeeded);
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

procedure EnsureStreamCapacity(var Ctx: TStreamContext; const ANeeded: SizeUInt); inline;
begin
  EnsureDual(Ctx.Cap, Ctx.Count, ANeeded, Ctx.Entries, Ctx.Maps);
end;

type
  PEmbedStreamContext = ^TEmbedStreamContext;
  TEmbedStreamContext = record
    Root: string;
    EmbedOpts: TResPackEmbedOptions;
    Entries: TResPackInputArray;
    Maps: TResPackMapsArray;
    Count: SizeUInt;
    Cap: SizeUInt;
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

procedure EnsureEmbedCapacity(var Ctx: TEmbedStreamContext; const ANeeded: SizeUInt); inline;
begin
  EnsureDual(Ctx.Cap, Ctx.Count, ANeeded, Ctx.Entries, Ctx.Maps);
end;

{ Walk 通用单源：WalkPre 统一 Stat/Filter/TryReserve，inline 零拷贝，替代三回调仅靠 helper 的分散；4 职责枚举/mmap/embed/extract 仍单文件承载 ~730 行，近 800 指引候选拆分已评估（CONTRACT 业务为准，缺能力反哺 owner，当前以通用 Walk 单源收口，超限再抽子模块） }
{ Walk 热路径泛型上下文：Stat/FilterRelPath/TryReserveTotal/Ensure*Capacity/失败归一单源，inline 零拷贝 }
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

{ mmap 零拷贝单源：Stat Size → MmapOpen → 空文件/大小校验/异常归一，~45 行重复收口 MmapRequire }
function TryMmapRequire(const APath: string; const AStatSize: Int64; out AMap: IMappedFile; out AErrMsg: string): Boolean;
begin
  AMap := nil;
  AErrMsg := '';
  if AStatSize = 0 then Exit(True);
  try
    AMap := MmapOpen(APath);
    if (AMap = nil) or (AMap.Size = 0) or (AMap.Data = nil) then
    begin
      if AStatSize <> 0 then
      begin
        AErrMsg := 'mmap failed: empty mapping for non-empty file (path=' + APath + ')';
        AMap := nil;
        Exit(False);
      end;
      AMap := nil;
    end
    else if SizeUInt(AMap.Size) <> SizeUInt(AStatSize) then
    begin
      AErrMsg := 'mmap size mismatch: stat=' + IntToStr(AStatSize) + ' cmap=' + IntToStr(AMap.Size) + ' (path=' + APath + ')';
      Exit(False);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      AErrMsg := 'mmap failed: ' + E.Message + ' (path=' + APath + ')';
      AMap := nil;
      Result := False;
    end;
  end;
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
  { 热路径说明（万文件场景）：当前回调内同步 Stat+ReadFile 并以 TBytes 锚点驻留至
    Build 结束，峰值 ≈2×输入+~14MB（512MB→~1038MB，parity: FPC ~1050MiB/Go ~1060MiB/Rust ~1055MiB）
    为 v1 纯内存设计预期（CONTRACT INV-R10、FORMAT.md §Data Section、writer.pas 流式两遍候选
    nextpas.core.respack.writer.stream 可降至 ~1×+头；CONTRACT 业务为准，缺能力先反哺 owner
    nextpas.core.mem.memory_map/nextpas.core.io.mapped，已落地 ResPackBuildStreamFromDir 流式mmap
    管线（MmapOpen 零拷贝 + ResPackBuildStream 分段写，峰值 ~1×+头，接口锚点 try..finally 释放不丢）；
    大包请优先流式mmap 管线（ResPackBuildStreamFromDir/ResPackBuildFromDir），本函数保留作小包便捷
    （deprecated 兼容，Stream 为统一抽象，硬性 RESPACK_DIRSOURCE_LEGACY_LIMIT 限额防 2× 堆 OOM，超限显式 EResPackTooLarge）。
    已做指数扩容单源 EnsureDirCapacity→WalkGrowCap 消 O(n²)，Data 指针零拷贝 BytesCopy 单源于 bytes.ops。
    Stat/Read 失败经受控 try/except 归一为 EResPackDirSourceFailed 且不丢资源（Failed 标志 + Walk 提前终止 + 调用方 raise 前局部托管自动释放）。
    单源证据：WalkPrePlain→RelativizePath→PathStripPrefix / TryReserveTotal→TryAddSizeUInt / WalkGrowCap / WalkFail 均为 inline 零拷贝转发，通用 Walk 单源 TWalkCtx<T> + EnsureWalkCapacity<T> 模板化。 }
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
  { 流式mmap 热路径：Stat 取 ModTime/Size，上限校验复用 TryReserveTotal/TryAddSizeUInt 单源（inline 零开销），
    随后 MmapOpen 零拷贝视图（owner: mem.memory_map/io.mapped，接口托管，零 heap 拷贝，inline 零开销）；
    空文件 Size=0 时 Mmap Size 0 合法；mmap 失败按受控 EResPackDirSourceFailed 上抛且不丢已映射资源。
    指数扩容单源 EnsureStreamCapacity→WalkGrowCap。泛型上下文单源：与 WalkProc 共用 WalkPrePlain/WalkTryStat/WalkTryReserve/WalkGrowCap/WalkFail，锚点分叉仅在 Data 加载 (MmapOpen) 处，模板化 TWalkCtx<IMappedFile> + EnsureWalkCapacity<IMappedFile>。 }
  Idx := Ctx^.Count;
  EnsureStreamCapacity(Ctx^, Idx + 1);
  if not TryMmapRequire(APath, St.Size, LMap, LErr) then
  begin
    WalkFail(Ctx^.Failed, Ctx^.FailMsg, LErr);
    Exit(False);
  end;
  Ctx^.Maps[Idx] := LMap; { 接口锚点，零拷贝视图生命期与 Entries 绑定，try..finally 释放不丢 }
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
  { 单源收口：尾斜杠归一复用 nextpas.core.path.ExcludeTrailingPathDelimiter
    （内部 FsPathTrimSep → platform_path_trim_sep 单源，原地去重 '\\'/'/'，保留根 '/'，
    inline 零额外分配，替代手写 while Delete O(n) 多次移动）。
    收敛：本函数仅保留 TBytes 小包便捷路径（ReadFile + EnsureDirCapacity→BytesNextCapacity 单源，inline 零拷贝，峰值 ~1×+头≤64MiB）；
    大包流式mmap 零拷贝路径已收口至 ResPackBuildStreamFromDir/WalkProcStream/MmapOpen 单源（峰值 ~1×+头，无 TBytes 全量驻留），
    消除此前 mmap→TBytes BytesCopy 双驻留 2× 峰值；64MiB 硬限额防堆 OOM，超限显式 EResPackTooLarge 引导流式。 }
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

procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc);
var
  Ctx: TStreamContext;
  RootClean: string;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.dirsource: Write proc is nil');
  RootClean := ExcludeTrailingPathDelimiter(ARoot);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ARoot, 'respack.dirsource: not a directory "'
      + ARoot + '"');
  Ctx.Root := RootClean;
  Ctx.Include := AInclude;
  Ctx.Entries := nil;
  Ctx.Maps := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  try
    WalkEx(RootClean, @WalkProcStream, @Ctx);
    if Ctx.Failed then
      raise EResPackDirSourceFailed.CreateCtx('walk', ARoot, 'respack.dirsource: ' + Ctx.FailMsg);
    if SizeUInt(Length(Ctx.Entries)) <> Ctx.Count then
    begin
      SetLength(Ctx.Entries, Ctx.Count);
      SetLength(Ctx.Maps, Ctx.Count);
    end;
    { 流式两遍零双驻留：复用 writer.stream 单源布局，峰值 ~1×+头，接口锚点在 BuildStream 期间保活 }
    ResPackBuildStream(Ctx.Entries, AOpts, AWrite);
  finally
    { 稳定性：接口托管的 mmap 视图随 Maps 清空自动 Unmap，异常路径亦不丢资源 }
    SetLength(Ctx.Maps, 0);
    SetLength(Ctx.Entries, 0);
  end;
end;

function ResPackBuildFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): TResPackBlob;
var
  SinkBuf: TBytes;
  SinkLen: SizeUInt;
  SinkCap: SizeUInt;
  SinkProc: TResPackWriteProc;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 单源复用：ResPackBuildStreamFromDir 管线 + BytesNextCapacity sink 收集，零重复 WalkEx/ResPackBuild 组装；
    布局/头/槽间隙/数据/digest 全链路于 writer.builder/layout 单源，BytesCopy/BytesZero inline 零拷贝；
    峰值 ~1×+头（mmap 零堆拷贝），接口锚点由 stream 内层 try..finally 释放不丢，sink 侧 BytesNextCapacity 指数扩容消 O(n²)。 }
  SinkBuf := nil;
  SinkLen := 0;
  SinkCap := 0;
  SinkProc :=
    procedure(const AData: PByte; const ASize: SizeUInt)
    begin
      if ASize = 0 then Exit;
      if SinkLen + ASize > SinkCap then
      begin
        SinkCap := BytesNextCapacity(SinkCap, SinkLen + ASize);
        SetLength(SinkBuf, SinkCap);
      end;
      BytesCopy(@SinkBuf[SinkLen], AData, ASize);
      Inc(SinkLen, ASize);
    end;
  ResPackBuildStreamFromDir(ARoot, AOpts, SinkProc, AInclude);
  if SinkLen = 0 then Exit;
  GetMem(Result.Data, SinkLen);
  Result.Size := SinkLen;
  Result.Owned := True;
  BytesCopy(Result.Data, @SinkBuf[0], SinkLen);
end;

function ResPackBuildStreamSizeFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): UInt64;
var
  Ctx: TStreamContext;
  RootClean: string;
  TmpEntries: TResPackInputArray;
begin
  RootClean := ExcludeTrailingPathDelimiter(ARoot);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ARoot, 'respack.dirsource: not a directory "'
      + ARoot + '"');
  Ctx.Root := RootClean;
  Ctx.Include := AInclude;
  Ctx.Entries := nil;
  Ctx.Maps := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  try
    WalkEx(RootClean, @WalkProcStream, @Ctx);
    if Ctx.Failed then
      raise EResPackDirSourceFailed.CreateCtx('walk', ARoot, 'respack.dirsource: ' + Ctx.FailMsg);
    if SizeUInt(Length(Ctx.Entries)) <> Ctx.Count then
      SetLength(Ctx.Entries, Ctx.Count);
    TmpEntries := Ctx.Entries;
    Result := ResPackBuildStreamSize(TmpEntries, AOpts);
  finally
    SetLength(Ctx.Maps, 0);
    SetLength(Ctx.Entries, 0);
  end;
end;

procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string);
var
  RP: TResPack;
  Idx: SizeUInt;
  Entry: TResPackEntry;
  DestPath, ParentDir: string;
  Content: TBytes;
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
        DestPath := ADestDir + '/' + RP.PathOf(Entry);
        { 父目录：复用 nextpas.core.path.PathDir 单源（FsPathDir→platform_path_dirname 零拷贝视图，inline），替代手写 downto 逐字符扫 '/' + Copy 分叉。 }
        ParentDir := PathDir(DestPath);
        if (ParentDir <> '') and (ParentDir <> '.') then
          MkdirAll(ParentDir);
        SetLength(Content, SizeInt(Entry.Size));
        if Entry.Size > 0 then
          BytesCopy(@Content[0], RP.ContentPtr(Entry), SizeUInt(Entry.Size)); { 零拷贝 BytesCopy 单源于 bytes.ops，inline 直达 }
        WriteFile(DestPath, Content);
      end;
  finally
    RP.Close;
  end;
end;

{ ResPackEmbedBuild — IO 管线实现（dirsource 唯一 FS seam） }

function StartsSlash(const S: string): Boolean; inline;
begin
  Result := (Length(S) > 0) and (S[Length(S)] = '/');
end;

procedure CheckGlobList(const AList: TStringArray; const AWhat: string);
var
  I: SizeUInt;
begin
  if SizeUInt(Length(AList)) = 0 then
    Exit;
  for I := 0 to SizeUInt(Length(AList)) - 1 do
    if Length(AList[I]) = 0 then
      raise EResPackError.Create('respack.embed: empty ' + AWhat
        + ' glob pattern');
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
  Ctx^.Maps[Idx] := LMap;
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
  Ctx: TEmbedStreamContext;
  RootClean: string;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.dirsource: Write proc is nil');
  if (AOpts.StripPrefix <> '') and (not StartsSlash(AOpts.StripPrefix)) then
    raise EResPackError.Create('respack.embed: StripPrefix must be empty or ' +
      'end with "/" ("' + AOpts.StripPrefix + '")');
  if (AOpts.AddPrefix <> '') and (not StartsSlash(AOpts.AddPrefix)) then
    raise EResPackError.Create('respack.embed: AddPrefix must be empty or ' +
      'end with "/" ("' + AOpts.AddPrefix + '")');
  CheckGlobList(AOpts.IncludeGlobs, 'include');
  CheckGlobList(AOpts.ExcludeGlobs, 'exclude');
  RootClean := ExcludeTrailingPathDelimiter(ASourceDir);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ASourceDir, 'respack.dirsource: not a directory "'
      + ASourceDir + '"');
  Ctx.Root := RootClean;
  Ctx.EmbedOpts := AOpts;
  Ctx.Entries := nil;
  Ctx.Maps := nil;
  Ctx.Count := 0;
  Ctx.Cap := 0;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  try
    WalkEx(RootClean, @WalkProcEmbedStream, @Ctx);
    if Ctx.Failed then
      raise EResPackDirSourceFailed.CreateCtx('walk', ASourceDir, 'respack.dirsource: ' + Ctx.FailMsg);
    if SizeUInt(Length(Ctx.Entries)) <> Ctx.Count then
    begin
      SetLength(Ctx.Entries, Ctx.Count);
      SetLength(Ctx.Maps, Ctx.Count);
    end;
    if Ctx.Count = 0 then
      raise EResPackError.Create('respack.embed: no entries matched after ' +
        'filter/mapping (source "' + ASourceDir + '")');
    { 流式mmap 零拷贝 + writer.stream 两遍零双驻留：峰值 ~1×+头（mmap 虚存零堆拷贝 + 头块 KB 级分段 AWrite），稳定性 try..finally 释放不丢；单源 ResPackBuildStream 复用 writer.layout }
    ResPackBuildStream(Ctx.Entries, AOpts.Build, AWrite);
  finally
    SetLength(Ctx.Maps, 0);
    SetLength(Ctx.Entries, 0);
  end;
end;

function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;
var
  SinkBuf: TBytes;
  SinkLen: SizeUInt;
  SinkCap: SizeUInt;
  SinkProc: TResPackWriteProc;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 单源复用：委托 ResPackEmbedBuildStream 流式mmap 管线 + BytesNextCapacity/BytesCopy sink 收集；峰值 ~1×+头，接口锚点由 stream 内层 try..finally 释放不丢 }
  SinkBuf := nil;
  SinkLen := 0;
  SinkCap := 0;
  SinkProc :=
    procedure(const AData: PByte; const ASize: SizeUInt)
    begin
      if ASize = 0 then Exit;
      if SinkLen + ASize > SinkCap then
      begin
        SinkCap := BytesNextCapacity(SinkCap, SinkLen + ASize);
        SetLength(SinkBuf, SinkCap);
      end;
      BytesCopy(@SinkBuf[SinkLen], AData, ASize);
      Inc(SinkLen, ASize);
    end;
  ResPackEmbedBuildStream(ASourceDir, AOpts, SinkProc);
  if SinkLen = 0 then Exit;
  GetMem(Result.Data, SinkLen);
  Result.Size := SinkLen;
  Result.Owned := True;
  BytesCopy(Result.Data, @SinkBuf[0], SinkLen);
end;

end.
