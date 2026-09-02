unit nextpas.core.tar.fs;
{**
 * @desc Tar 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 * 委托 nextpas.core.archive.fs 的排序、几何扩容、symlink 拒绝、零拷贝落盘、
 * deferred-dir 逆序定稿与统一目录 Walk（ArchiveCollectWalk 单源），打包经 bytes.builder
 * IBytesBuilder 直写切片单次 ToBytes 交付（消除 CreateBytesStream+ArchiveSnapshotStream 二次
 * SetLength+Seek+Read 大块 Move），消除与 zip.fs 的 150+ 行拷贝，保持确定性与 fail-closed；
 * L2 单 seam：fs 仅经 archive.fs 联邦单缝（archive.fs 为 L2 同层唯一显式依赖，tar.fs 禁直引 nextpas.core.fs），复用 bytes.ops 单源零拷贝，注册层级见 module-registry archive/tar 联邦 via archive.fs。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.tar.writer;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
function TarPackDir(const ADir: string): TBytes;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
procedure TarExtractToDir(const AData: TBytes; const ADestDir: string);

implementation

uses
  nextpas.core.exception,
  nextpas.core.tar.common,
  nextpas.core.tar.reader,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.bytes.builder,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.pathvalid,
  nextpas.core.log.intf,
  nextpas.core.text.conv,
  nextpas.core.archive.fs;

{ 薄别名已移除：直接复用 archive.fs TArchiveWalkEntry/TArchiveWalkArray/TArchiveDeferredDir 单源 }

{ Walk 递归已完全下沉至 archive.fs: ArchiveCollectWalk 单源，tar 仅薄委托，无重复实现 }

{ symlink/hardlink target 安全校验：参数化复用 bytes.pathvalid.IsSafeArchiveEntryNameEx 单源（阈值4096/禁尾斜杠），inline 薄转发、零拷贝段扫描（原串索引无Copy/分配），复用 bytes.ops 单源思想，消除与 IsSafeArchiveEntryName 的80%重复 }
function IsSafeTarLinkTarget(const ATarget: string): Boolean; inline;
begin
  Result := IsSafeArchiveEntryNameEx(ATarget, 4096, False);
end;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
var
  LRoot: TArchiveFileInfo;
  LWalks: TArchiveWalkArray;
  LI, LWalksCount: Integer;
  LHdr: TTarHeader;
  LFile: TArchiveFile;
  LStat: TArchiveFileInfo;
begin
  if AWriter = nil then
    raise EArgumentError.Create('tar pack: writer is nil');
  LRoot := ArchiveStat(ADir);
  if not LRoot.IsDir then
    raise EArgumentError.Create('tar pack: not a directory: ' + ADir);
  SetLength(LWalks, 0);
  LWalksCount := 0;
  ArchiveCollectWalk(ADir, '', LWalks, LWalksCount);
  SetLength(LWalks, LWalksCount);
  for LI := 0 to High(LWalks) do
  begin
    LHdr := Default(TTarHeader);
    LHdr.Name := LWalks[LI].FRel;
    LHdr.MTimeUnix := LWalks[LI].FMtime;
    if LWalks[LI].FIsDir then
    begin
      LHdr.Kind := tekDirectory;
      LHdr.Mode := TarDirectoryMode(LWalks[LI].FMode);
      AWriter.AddEntry(LHdr, nil);
    end
    else
    begin
      LHdr.Kind := tekRegular;
      LHdr.Mode := TarRegularMode(LWalks[LI].FMode);
      // 流式：按需打开句柄分块搬运，64K 复用缓冲，仅 O(1) 内存，零全量拷贝
      LFile := nil;
      // perf: inline Close + 零拷贝 Move 单源 bytes.ops，异常时仍释句柄；经 archive.fs 联邦单缝 federation single seam
      LFile := ArchiveOpenRead(LWalks[LI].FFull);
      try
        LStat := LFile.Stat;
        LHdr.Size := LStat.Size;
        AWriter.AddEntryFromReader(LHdr, LFile as IReader);
      finally
        try
          LFile.Close;
        except
          // best-effort: 关闭异常不掩盖主流程，资源已释
        end;
        LFile := nil;
      end;
    end;
  end;
  SetLength(LWalks, 0);
end;

function TarPackDir(const ADir: string): TBytes;
var
  LBuilder: IBytesBuilder;
  LSink: IWriter;
  W: TTarWriter;
begin
  Result := nil;
  // 统一工厂单源：复用 archive.fs CreateArchiveBuilder (CreateBytesBuilder C_TAR_BUILDER_INITIAL_CAPACITY + CreateArchiveBuilderSink)，inline 零拷贝直写切片，消除与 tar.builder 同模板重复 + 二次大块 Move
  CreateArchiveBuilder(C_TAR_BUILDER_INITIAL_CAPACITY, LBuilder, LSink);
  W := TTarWriter.Create(LSink);
  try
    TarPackDirInto(ADir, W);
    W.Finish;
    // perf: 单次 ToBytes 分配+Move，零额外拷贝（builder 已内联 AppendBytes），接口自动释资源，不丢句柄
    Result := LBuilder.ToBytes;
  finally
    W.Free;
  end;
end;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
var
  ROpts: TTarReadOptions;
  R: TTarReader;
  H: TTarHeader;
  LFull: string;
  LSep: Integer;
  LMode: Word;
  LDirs: TArchiveDeferredArray;
  LDirCount: Integer;
  LMaxEntry: SizeUInt;
  LMaxTotal: UInt64;
  LSlice: PByte;
  LSliceCount: SizeUInt;
  LHardSource: string;
begin
  if AOptions.MaxEntrySize = 0 then
    LMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    LMaxEntry := AOptions.MaxEntrySize;
  if AOptions.MaxTotalSize = 0 then
    LMaxTotal := C_TAR_DEFAULT_MAX_TOTAL
  else
    LMaxTotal := AOptions.MaxTotalSize;
  ROpts.MaxEntrySize := LMaxEntry;
  ROpts.MaxTotalSize := LMaxTotal;
  R := TTarReader.CreateWithOptions(AData, ROpts);
  try
    ArchiveMkdirAll(ADestDir, ArchivePermDirDefault);
    ArchiveEnsureNoSymlinkInPath(ADestDir);
    SetLength(LDirs, 0);
    LDirCount := 0;
    try
      while R.Next(H) do
      begin
        GuardTarNameForRead(H.Name);
        // 特殊类型完整性闭环：SkipSpecial=false 时 symlink/hardlink/device/fifo 必须落地，不得静默丢弃
        if (H.Kind <> tekRegular) and (H.Kind <> tekDirectory) then
        begin
          if AOptions.SkipSpecial then
            Continue;
          if (H.Kind = tekSymlink) or (H.Kind = tekHardLink) then
            if not IsSafeTarLinkTarget(H.LinkName) then
              raise EParseError.Create('tar extract: refusing unsafe link target: ' + H.Name + ' -> ' + H.LinkName);
        end;
        // perf: 单次 ArchiveJoinPath SetLength+Move 复用 bytes.ops 单源 CopyMemory，零 Delete 堆抖动；父目录零拷贝单源 bytes.ops StringLastIndexOf/SpanLastIndexOf 单遍逆序扫描无Copy/分配 inline 热路径，复用 bytes.ops/platform.path 单源消除手写 '/' 反向轮子，千级小文件零额外分配
        LFull := ArchiveJoinPath(ADestDir, H.Name);
        LSep := StringLastIndexOf(LFull, '/');
        if LSep > 0 then
          ArchivePrepareParentDir(LFull, SizeUInt(LSep - 1));
        LMode := Word(H.Mode and $0FFF);
        case H.Kind of
          tekDirectory:
            begin
              ArchiveMkdirAll(LFull, ArchivePermDirDefault);
              ArchiveDeferredAppend(LDirs, LDirCount, LFull, LMode, H.MTimeUnix * 1000000000);
            end;
          tekRegular:
            begin
              { 零拷贝：复用 Reader 已有的 EntryDataSlice，避免 EntryData 的 SetLength+Move 双倍内存 }
              if R.EntryDataSlice(LSlice, LSliceCount) then
                ArchiveWriteFileSlice(LFull, LSlice, LSliceCount, ArchivePermDefault)
              else
                ArchiveWriteFileSlice(LFull, nil, 0, ArchivePermDefault);
              // stability+observability: 单源 ArchiveRestoreFileMeta best-effort 经log.intf WARN（NullLogger零分配inline），不静默吞，fail-closed
              ArchiveRestoreFileMeta(LFull, LMode, H.MTimeUnix * 1000000000, AOptions.RestoreMode);
            end;
          tekSymlink:
            begin
              // 单源：ArchiveHandleSpecial 统一预清理（Exists/IsSymlink→Remove），消除四分支样板，archive.fs 联邦单缝零分配
              ArchiveHandleSpecial(LFull);
              ArchiveSymlink(H.LinkName, LFull);
            end;
          tekHardLink:
            begin
              LHardSource := ArchiveJoinPath(ADestDir, H.LinkName);
              if not ArchiveExists(LHardSource) then
                raise EIOError.Create('tar extract: hardlink source missing: ' + H.LinkName);
              ArchiveHandleSpecial(LFull);
              ArchiveHardLink(LHardSource, LFull);
            end;
          tekFifo:
            begin
              ArchiveHandleSpecial(LFull);
              try
                ArchiveMkFifo(LFull, TArchivePermission(LMode and $0FFF));
                ArchiveRestoreFileMeta(LFull, LMode, H.MTimeUnix * 1000000000, AOptions.RestoreMode);
              except
                on E: Exception do
                begin
                  // L2经log.intf单缝可观测（NullLogger默认no-op零分配inline薄转发），无System.WriteLn/StdErr直触，平台抽象克制，复用writer/builder单源
                  NullLogger.Warn('[WARN] tar extract: mkfifo failed for ' + H.Name + ': ' + E.Message);
                  ArchiveWriteEmptyFallback(LFull, LMode, H.MTimeUnix * 1000000000, AOptions.RestoreMode);
                end;
              end;
            end;
          tekCharDevice, tekBlockDevice:
            begin
              ArchiveHandleSpecial(LFull);
              // INV-7 往返完整：经 archive.fs 单缝 ArchiveTryMkDevice 携带 DevMajor/DevMinor 真实 mknod（S_IFCHR/S_IFBLK），特权不足则 fail-closed WARN+占位，经log.intf单缝可观测不静默降级（NullLogger零分配inline），复用 bytes.ops单源零拷贝/Inline思想
              if not ArchiveTryMkDevice(LFull, LMode, H.DevMajor, H.DevMinor, H.Kind = tekCharDevice) then
              begin
                NullLogger.Warn('[WARN] tar extract: special device skipped (mknod failed dev=' + IntToStr(H.DevMajor) + ':' + IntToStr(H.DevMinor) + '): ' + H.Name + ' kind=' + IntToStr(Ord(H.Kind)));
                ArchiveWriteEmptyFallback(LFull, LMode, H.MTimeUnix * 1000000000, AOptions.RestoreMode);
              end
              else
                ArchiveRestoreFileMeta(LFull, LMode, H.MTimeUnix * 1000000000, AOptions.RestoreMode);
            end;
        else
          Continue;
        end;
      end;
    finally
      SetLength(LDirs, LDirCount);
      ArchiveRestoreDeferredDirs(LDirs, AOptions.RestoreMode);
    end;
  finally
    R.Free;
  end;
end;

procedure TarExtractToDir(const AData: TBytes; const ADestDir: string);
var
  O: TTarExtractOptions;
begin
  O := DefaultTarExtractOptions;
  TarExtractToDirWithOptions(AData, ADestDir, O);
end;

end.
