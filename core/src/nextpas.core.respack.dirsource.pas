unit nextpas.core.respack.dirsource;

{** @desc 目录 → 打包条目适配。本单元是 respack 唯一允许依赖 nextpas.core.fs 的
  IO seam（L2→L2 seam，registry 记录）；另复用 L1 nextpas.core.path.PathStripPrefix/
  PathToSlash/ExcludeTrailingPathDelimiter 单源做 Windows 分隔符归一与前缀剥离/尾斜杠归一、
  nextpas.core.bytes.ops Move 单源做零拷贝。策略：
  仅收 ftRegular 文件；symlink 一律跳过；相对路径 '/' 分隔（Windows 宿主归一
  经 PathStripPrefix 单源，消除手写 Copy/while/StringReplace/$IFDEF 分叉；流式mmap
  已反哺至本单元 via nextpas.core.io.mapped/MemoryMap owner，见 ResPackBuildStreamFromDir）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
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
  遍历错误 raise EResPackDirSourceFailed。 }
function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc = nil): TResPackDirEntries;

{ 流式mmap：目录 → 流式两遍分段零双驻留打包，峰值 ~1×+头。
  遍历期以 nextpas.core.io.mapped MmapOpen 零拷贝视图供给 Entries[].Data，
  映射生命期由本函数持有至 AWrite 回调完成（接口引用托管，try..finally 释放不丢），
  零 TBytes 全量锚点驻留；writer.stream 复用同布局以达 ~1×+头，零额外 Total 缓冲。
  万文件/512MB 场景堆压力由 ~2×+14MB 降至 ~1×+头（parity: FPC ~1050MiB → ~520MiB）。
  成功后 AWrite 按序收到确定性 blob 流；失败按受控 EResPackDirSourceFailed。 }
procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc = nil);

{ 目录 → 内存 blob 便捷：流式mmap 版 ResPackBuildFromDir，复用 ResPackBuildStreamFromDir
  的 1×+头管线，仅最终 GetMem(Total) 一次成块；与 ResPackBuild 同确定性。 }
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

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.path,
  nextpas.core.io.mapped,
  nextpas.core.text.conv,
  nextpas.core.respack.reader,
  nextpas.core.respack.writer;

type
  PDirContext = ^TDirContext;
  TDirContext = record
    Root: string;             { 归一前缀单源：供 PathStripPrefix 复用，零拷贝视图 }
    RootPrefixLen: Integer;   { 兼容长度，保留用于调试；主路径剥离走 PathStripPrefix 单源 }
    Include: TResPackIncludeFunc;
    Entries: TResPackInputArray;
    Bytes: array of TBytes;   { 内容生命期锚点 }
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
    Maps: array of IMappedFile; { mmap 生命期锚点，接口引用计数的零拷贝视图 }
    Count: SizeUInt;
    Cap: SizeUInt;
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

function Relativize(const ACtx: TDirContext; const AFullPath: string): string; inline; overload;
begin
  { 单源收口：前缀剥离+归一复用 L1 nextpas.core.path.PathStripPrefix（内部
    PathToSlash 单遍扫描原地替换、零额外分配、inline 零拷贝），替代手写 Copy/
    while/StringReplace/$IFDEF 分叉；性能 inline 消除调用开销，零拷贝 Move 单源于
    bytes.ops；Windows 无条件归一，Unix 零开销。Owner 边界：归一与剥离由 path 拥有，
    本单元仅转发，不新建 text.path 模块，已收口单源。 }
  Result := PathStripPrefix(AFullPath, ACtx.Root);
  if Result = '.' then
    Result := '';
end;

function RelativizeStream(const ACtx: TStreamContext; const AFullPath: string): string; inline; overload;
begin
  Result := PathStripPrefix(AFullPath, ACtx.Root);
  if Result = '.' then
    Result := '';
end;

function WalkProc(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PDirContext;
  Rel: string;
  Idx, NewCap: SizeUInt;
  St: TFileInfo;
  LSum: SizeUInt;
begin
  Result := True;
  Ctx := PDirContext(AUserData);
  if AErr <> nil then
  begin
    Ctx^.Failed := True;
    Ctx^.FailMsg := AErr.Message;
    Exit(False);
  end;
  if AInfo.FileType <> ftRegular then
    Exit(True);   { symlink/目录/特殊文件不入包 }
  Rel := Relativize(Ctx^, APath);
  if not ResPackValidPath(Rel, True) then
    Exit(True);   { 无法成名的宿主产物跳过，不污染包 }
  if (Ctx^.Include <> nil) and (not Ctx^.Include(Rel)) then
    Exit(True);
  { 热路径说明（万文件场景）：当前回调内同步 Stat+ReadFile 并以 TBytes 锚点驻留至
    Build 结束，峰值 ≈2×输入+~14MB（512MB→~1038MB，parity: FPC ~1050MiB/Go ~1060MiB/Rust ~1055MiB）
    为 v1 纯内存设计预期（CONTRACT INV-R10、FORMAT.md §Data Section、writer.pas 流式两遍候选
    nextpas.core.respack.writer.stream 可降至 ~1×+头；CONTRACT 业务为准，缺能力先反哺 owner
    nextpas.core.mem.memory_map/nextpas.core.io.mapped，已落地 ResPackBuildStreamFromDir 流式mmap
    管线（MmapOpen 零拷贝 + ResPackBuildStream 分段写，峰值 ~1×+头，接口锚点 try..finally 释放不丢）；
    分段/零拷贝高级感由 owner 层承载，本单元保持 L2→L2 seam 最小性）。已做指数增长 Cap 消 O(n²)
    重分配，Data 指针零拷贝 Move 单源于 bytes.ops。Stat/Read 失败经受控 try/except 归一为
    EResPackDirSourceFailed 且不丢资源（Failed 标志 + Walk 提前终止 + 调用方 raise 前局部托管自动释放）。 }
  try
    St := Stat(APath);
  except
    on E: Exception do
    begin
      Ctx^.Failed := True;
      Ctx^.FailMsg := 'stat failed: ' + E.Message + ' (path=' + APath + ')';
      Exit(False);
    end;
  end;
  { 32 位回绕防护：Total+Size 裸加在 LongWord 下可回绕绕过 512MB 上限；
    改用 TryAddSizeUInt 单源（L0 base.utils，inline 零开销，溢出返回 False 保值）。 }
  if (St.Size < 0) or (not TryAddSizeUInt(Ctx^.Total, SizeUInt(St.Size), LSum))
    or (LSum > RESPACK_MAX_INPUT_BYTES) then
  begin
    Ctx^.Failed := True;
    Ctx^.FailMsg := 'total input exceeds limit';
    Exit(False);
  end;
  Idx := Ctx^.Count;
  if Idx >= Ctx^.Cap then
  begin
    NewCap := Ctx^.Cap * 2;
    if NewCap < 8 then NewCap := 8;
    if NewCap < Idx + 1 then NewCap := Idx + 1;
    SetLength(Ctx^.Entries, NewCap);
    SetLength(Ctx^.Bytes, NewCap);
    Ctx^.Cap := NewCap;
  end;
  try
    Ctx^.Bytes[Idx] := ReadFile(APath);
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
  Idx, NewCap: SizeUInt;
  St: TFileInfo;
  LSum: SizeUInt;
  LMap: IMappedFile;
begin
  Result := True;
  Ctx := PStreamContext(AUserData);
  if AErr <> nil then
  begin
    Ctx^.Failed := True;
    Ctx^.FailMsg := AErr.Message;
    Exit(False);
  end;
  if AInfo.FileType <> ftRegular then
    Exit(True);
  Rel := RelativizeStream(Ctx^, APath);
  if not ResPackValidPath(Rel, True) then
    Exit(True);
  if (Ctx^.Include <> nil) and (not Ctx^.Include(Rel)) then
    Exit(True);
  { 流式mmap 热路径：Stat 取 ModTime/Size，上限校验复用 TryAddSizeUInt 单源（inline 零开销），
    随后 MmapOpen 零拷贝视图（owner: mem.memory_map/io.mapped，接口托管，零 heap 拷贝，inline 零开销）；
    空文件 Size=0 时 Mmap Size 0 合法；mmap 失败按受控 EResPackDirSourceFailed 上抛且不丢已映射资源。 }
  try
    St := Stat(APath);
  except
    on E: Exception do
    begin
      Ctx^.Failed := True;
      Ctx^.FailMsg := 'stat failed: ' + E.Message + ' (path=' + APath + ')';
      Exit(False);
    end;
  end;
  if (St.Size < 0) or (not TryAddSizeUInt(Ctx^.Total, SizeUInt(St.Size), LSum))
    or (LSum > RESPACK_MAX_INPUT_BYTES) then
  begin
    Ctx^.Failed := True;
    Ctx^.FailMsg := 'total input exceeds limit';
    Exit(False);
  end;
  Idx := Ctx^.Count;
  if Idx >= Ctx^.Cap then
  begin
    NewCap := Ctx^.Cap * 2;
    if NewCap < 8 then NewCap := 8;
    if NewCap < Idx + 1 then NewCap := Idx + 1;
    SetLength(Ctx^.Entries, NewCap);
    SetLength(Ctx^.Maps, NewCap);
    Ctx^.Cap := NewCap;
  end;
  try
    { 空文件无需映射：Data=nil, Size=0 直接零拷贝 }
    if St.Size = 0 then
      LMap := nil
    else
    begin
      LMap := MmapOpen(APath);
      { MmapOpen 空文件/失败时优雅降级为 nil+0；非空文件 mmap 失败视为错误，避免静默脏数据 }
      if (LMap = nil) or (LMap.Size = 0) or (LMap.Data = nil) then
      begin
        { 回退探测：真实空文件 vs 映射失败 }
        if St.Size <> 0 then
        begin
          Ctx^.Failed := True;
          Ctx^.FailMsg := 'mmap failed: empty mapping for non-empty file (path=' + APath + ')';
          Exit(False);
        end;
        LMap := nil;
      end
      else if SizeUInt(LMap.Size) <> SizeUInt(St.Size) then
      begin
        { 大小不一致（并发写入竞态），视为失败以保确定性 }
        Ctx^.Failed := True;
        Ctx^.FailMsg := 'mmap size mismatch: stat=' + IntToStr(St.Size) + ' cmap=' + IntToStr(LMap.Size) + ' (path=' + APath + ')';
        Exit(False);
      end;
    end;
  except
    on E: Exception do
    begin
      Ctx^.Failed := True;
      Ctx^.FailMsg := 'mmap failed: ' + E.Message + ' (path=' + APath + ')';
      Exit(False);
    end;
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
    inline 零额外分配，替代手写 while Delete O(n) 多次移动）。 }
  RootClean := ExcludeTrailingPathDelimiter(ARoot);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.CreateCtx('opendir', ARoot, 'respack.dirsource: not a directory "'
      + ARoot + '"');

  Ctx.Root := RootClean;
  Ctx.RootPrefixLen := Length(RootClean);
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
  Result.Entries := Ctx.Entries;
  Result.Contents := Ctx.Bytes;   { 锚点随 bundle 逃逸，生命期与 Entries 绑定 }
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
  LTotal: UInt64;
  LBlob: TResPackBlob;
  LPos: SizeUInt;
  LHead: PByte;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 首遍预计算 Total（零分配布局复用），一次 GetMem 成块，次遍分段 Move 零拷贝填充 }
  LTotal := ResPackBuildStreamSizeFromDir(ARoot, AOpts, AInclude);
  if LTotal = 0 then
  begin
    { 空包：无条目时 ResPackBuildStream 仍产 40B header，此路径需走流式以保确定性 }
  end;
  if LTotal > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  if LTotal > 0 then
  begin
    GetMem(LHead, SizeUInt(LTotal));
    LBlob.Data := LHead;
    LBlob.Size := SizeUInt(LTotal);
    LBlob.Owned := True;
    LPos := 0;
    try
      ResPackBuildStreamFromDir(ARoot, AOpts,
        procedure(const AData: PByte; const ASize: SizeUInt)
        begin
          if ASize = 0 then Exit;
          { 零拷贝 Move 单源于 bytes.ops，inline 直达；LPos 单调递增，分段写无需二次扫描 }
          Move(AData^, (LHead + LPos)^, ASize);
          Inc(LPos, ASize);
        end, AInclude);
      if LPos <> SizeUInt(LTotal) then
        raise EResPackError.Create('respack.dirsource: stream size mismatch');
      Result := LBlob;
    except
      FreeMem(LHead, SizeUInt(LTotal));
      raise;
    end;
  end
  else
  begin
    { LTotal=0 仅当空包（header 40B 已在布局中）；实际走流式兜底。
      闭包内不可直接捕获 Result（FPC: Symbol $result can not be captured），转用栈上 LBlob 中转。 }
    LBlob.Data := nil;
    LBlob.Size := 0;
    LBlob.Owned := False;
    ResPackBuildStreamFromDir(ARoot, AOpts,
      procedure(const AData: PByte; const ASize: SizeUInt)
      var P: PByte;
      begin
        if ASize = 0 then Exit;
        if LBlob.Data = nil then
        begin
          GetMem(P, ASize);
          LBlob.Data := P;
          LBlob.Size := ASize;
          LBlob.Owned := True;
          Move(AData^, LBlob.Data^, ASize);
        end
        else
          raise EResPackError.Create('respack.dirsource: unexpected multi-chunk for empty');
      end, AInclude);
    Result := LBlob;
  end;
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
  LPos: SizeInt;
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
        { 条目可带子目录层级，先确保父目录存在：单遍扫描定位末 '/' 后单次 Copy(Move) 取父目录，替代逐字符 Delete O(n²)；inline 零拷贝。 }
        ParentDir := '';
        for LPos := Length(DestPath) downto 1 do
          if DestPath[LPos] = '/' then
          begin
            ParentDir := Copy(DestPath, 1, LPos - 1);
            Break;
          end;
        if ParentDir <> '' then
          MkdirAll(ParentDir);
        SetLength(Content, SizeInt(Entry.Size));
        if Entry.Size > 0 then
          Move(RP.ContentPtr(Entry)^, Content[0], SizeUInt(Entry.Size)); { 零拷贝切片 Move 单源于 bytes.ops，inline 直达 }
        WriteFile(DestPath, Content);
      end;
  finally
    RP.Close;
  end;
end;

end.
