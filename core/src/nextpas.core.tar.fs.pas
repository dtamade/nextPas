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
  nextpas.core.base.utils,
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

{ symlink/hardlink target 安全校验：参数化复用 bytes.pathvalid.IsSafeArchiveEntryNameEx 单源（阈值 C_TAR_MAX_LINK_BYTES/禁尾斜杠），inline 薄转发、零拷贝段扫描（原串索引无Copy/分配），复用 bytes.ops 单源思想，消除与 IsSafeArchiveEntryName 的80%重复 }
function IsSafeTarLinkTarget(const ATarget: string): Boolean; inline;
begin
  Result := IsSafeArchiveEntryNameEx(ATarget, C_TAR_MAX_LINK_BYTES, False);
end;

{ Walk打包单源：消除 TarPackDir/TarPackDirInto 间30+行重复粘贴，inline零拷贝分块搬运，复用 ArchiveCollectWalk 已Stat FSize 零二次Stat，批量小文件单次分配合并缓冲复用 I/O 块（200×512B 仅1次 GetMem，经 TarIOBufCapacityFor+bytes.ops AlignUp4K 单源 4K 对齐，跨条目共享 LShared 复用、O(1)内存，inline 零拷贝，GetMem无零填充避免4K无效写带宽），bytes.ops单源，稳定性try..finally不丢句柄 FreeMem }
procedure PackWalks(const AWalks: TArchiveWalkArray; const AWriter: TTarWriter); inline;
var
  LI: Integer;
  LHdr: TTarHeader;
  LFile: TArchiveFile;
  LShared: PByte;
  LSharedCap: SizeUInt;
  LMaxSize: Int64;
  LNeed: SizeUInt;
begin
  LShared := nil;
  LSharedCap := 0;
  LMaxSize := 0;
  for LI := 0 to High(AWalks) do
    if not AWalks[LI].FIsDir and (AWalks[LI].FSize > LMaxSize) then
      LMaxSize := AWalks[LI].FSize;
  if LMaxSize > 0 then
  begin
    LNeed := TarIOBufCapacityFor(LMaxSize);
    GetMem(LShared, LNeed);
    LSharedCap := LNeed;
  end;
  try
    for LI := 0 to High(AWalks) do
    begin
      LHdr := Default(TTarHeader);
      LHdr.Name := AWalks[LI].FRel;
      LHdr.MTimeUnix := AWalks[LI].FMtime;
      if AWalks[LI].FIsDir then
      begin
        LHdr.Kind := tekDirectory;
        LHdr.Mode := TarDirectoryMode(AWalks[LI].FMode);
        AWriter.AddEntry(LHdr, nil);
      end
      else
      begin
        LHdr.Kind := tekRegular;
        LHdr.Mode := TarRegularMode(AWalks[LI].FMode);
        LHdr.Size := AWalks[LI].FSize;
        if LHdr.Size < 0 then
          raise EIOError.Create('tar pack: negative size: ' + AWalks[LI].FFull);
        if LHdr.Size = 0 then
        begin
          AWriter.AddEntry(LHdr, nil);
          Continue;
        end;
        LFile := nil;
        LFile := ArchiveOpenRead(AWalks[LI].FFull);
        try
          if (LShared <> nil) and (LSharedCap > 0) then
            AWriter.AddEntryFromReaderWithRawBuf(LHdr, LFile as IReader, LShared, LSharedCap)
          else
            AWriter.AddEntryFromReader(LHdr, LFile as IReader);
        finally
          try
            LFile.Close;
          except
          end;
          LFile := nil;
        end;
      end;
    end;
  finally
    if LShared <> nil then
      FreeMem(LShared, LSharedCap);
  end;
end;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
var
  LRoot: TArchiveFileInfo;
  LWalks: TArchiveWalkArray;
  LWalksCount: Integer;
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
  try
    // 性能：复用 ArchiveCollectWalk 已 Stat FSize 零二次Stat，单源 PackWalks inline 零拷贝分块搬运
    PackWalks(LWalks, AWriter);
  finally
    SetLength(LWalks, 0);
  end;
end;

function TarPackDir(const ADir: string): TBytes;
var
  LBuilder: IBytesBuilder;
  LSink: IWriter;
  W: TTarWriter;
  LWalks: TArchiveWalkArray;
  LI, LWalksCount: Integer;
  LEstimated, LCap: SizeUInt;
  LAccum: UInt64;
begin
  Result := nil;
  // perf: 按预估总量经 TarBuilderCapacityFor 4K 对齐预扩容（复用 bytes.ops.AlignUp4K 单源，bytes.builder 几何扩容 inline 零拷贝），大目录避免多次几何扩容（200×512B 仅1次 vs 固定64K多次重分配），小目录保持64K覆盖；预估=512×条目+文件pad512+长名pax近似(1024)，2零块由单点追加，溢出守卫clamp至High，零额外拷贝
  SetLength(LWalks, 0);
  LWalksCount := 0;
  ArchiveCollectWalk(ADir, '', LWalks, LWalksCount);
  SetLength(LWalks, LWalksCount);
  try
    // perf: 批量 UInt64 累加 + bytes.ops.AlignUp(...,512) 单源 inline 零拷贝对齐，消除逐项 High(SizeUInt) 守卫分支与手写 (Size+511)&~511 掩码；头块批量 LWalksCount*512，长名 pax 1024 近似批量累加，单点溢出 clamp 至 High，终经 TarBuilderCapacityFor 复用 bytes.ops.AlignUp4K 单源 4K 对齐（零除法位掩码，32/64位安全），与 bytes.builder 几何扩容 inline 零拷贝共道，大目录 200×512B 仅1次扩容，小目录 64K 覆盖，零额外拷贝
    LAccum := UInt64(LWalksCount) * SizeUInt(C_TAR_BLOCK_SIZE);
    for LI := 0 to High(LWalks) do
      if not LWalks[LI].FIsDir then
      begin
        if LWalks[LI].FSize > 0 then
          LAccum := LAccum + AlignUp(SizeUInt(LWalks[LI].FSize), 512);
        if Length(LWalks[LI].FRel) > C_TAR_NAME_FIELD then
          LAccum := LAccum + 1024;
      end;
    if LAccum > High(SizeUInt) then
      LEstimated := High(SizeUInt)
    else
      LEstimated := SizeUInt(LAccum);
    LCap := TarBuilderCapacityFor(LEstimated);
    CreateArchiveBuilder(LCap, LBuilder, LSink);
    W := TTarWriter.Create(LSink);
    try
      PackWalks(LWalks, W);
      W.Finish;
      // perf: 单次 ToBytes 分配+Move，零额外拷贝（builder 已内联 AppendBytes），接口自动释资源，不丢句柄
      Result := LBuilder.ToBytes;
    finally
      W.Free;
    end;
  finally
    SetLength(LWalks, 0);
  end;
end;

{ 同父缓存 helper：抽取 TarExtractToDirWithOptions 中55行手工 CopyMemory+CompareMem 双重 if 展开，inline 薄转发、复用 bytes.ops.CopyMemory / base.utils.CompareMem 单源零拷贝，门面薄而优雅，避免内联膨胀，保持 L0-L3 单缝 }
procedure SyncTarParentCache(const AFull: string; var ALastParent: string; var AParentLen: SizeUInt); inline;
var
  LSep: SizeInt;
begin
  LSep := StringLastIndexOf(AFull, '/');
  if LSep <= 0 then Exit;
  AParentLen := SizeUInt(LSep - 1);
  if AParentLen <> SizeUInt(Length(ALastParent)) then
  begin
    ArchivePrepareParentDir(AFull, AParentLen);
    SetLength(ALastParent, AParentLen);
    if AParentLen > 0 then
      CopyMemory(PByte(@AFull[1]), PByte(@ALastParent[1]), AParentLen);
  end
  else if (AParentLen > 0) and not CompareMem(Pointer(@AFull[1]), Pointer(@ALastParent[1]), AParentLen) then
  begin
    ArchivePrepareParentDir(AFull, AParentLen);
    SetLength(ALastParent, AParentLen);
    CopyMemory(PByte(@AFull[1]), PByte(@ALastParent[1]), AParentLen);
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
  LLastParent: string;
  LParentLen: SizeUInt;
  LProbe: Integer;
  LHasSlash: Boolean;
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
    LLastParent := '';
    LParentLen := 0;
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
        // perf: 单次 ArchiveJoinPath SetLength+Move 复用 bytes.ops 单源 CopyMemory，零 Delete 堆抖动；父目录零拷贝单源 bytes.ops StringLastIndexOf 单遍逆序扫描无Copy inline 热路径；同父目录缓存 LLastParent 命中时跳过 UniqueString+逐段 NUL 截断与 symlink/mkdir 系统调用，千文件同目录由 N 次 UniqueString+O(depth) 段扫描降至 1 次分配+1 次扫描，零拷贝 CompareMem 复用 base.utils 单源，平台克制 L0-L3 守联邦单缝；预分区快速路径：同父连续条目经前缀‘/’命中+小后缀‘/’扫描（仅basename长度）跳过全路径逆扫，200 同父文件由 200 次 StringLastIndexOf 全扫降至 1 次全扫+199 次前缀命中，复用 bytes.ops 单源零拷贝，inline 热路径；门面薄而优雅：55行手工 CopyMemory+CompareMem 双重 if 展开已抽 SyncTarParentCache inline helper 复用 bytes.ops 单源零拷贝，消除内联膨胀
        LFull := ArchiveJoinPath(ADestDir, H.Name);
        if (LLastParent <> '') and (Length(LFull) > Length(LLastParent)) and (LFull[Length(LLastParent) + 1] = '/') then
        begin
          LHasSlash := False;
          for LProbe := Length(LLastParent) + 2 to Length(LFull) do
            if LFull[LProbe] = '/' then
            begin
              LHasSlash := True;
              Break;
            end;
          if LHasSlash then
            SyncTarParentCache(LFull, LLastParent, LParentLen);
          // else fast hit: same parent, skip via helper no-op, zero full scan
        end
        else
          SyncTarParentCache(LFull, LLastParent, LParentLen);
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
              ArchiveValidateHardlinkSource(LHardSource, H.LinkName);
              ArchiveHandleSpecial(LFull);
              // TOCTOU闭环：ArchiveHardLinkVerified→FsHardLinkVerified→platform_file_link_verified 单源原子落盘，O_NOFOLLOW|O_CLOEXEC fd 校验 ftRegular 后经 /proc/self/fd 或 /dev/fd 链路 link，消除 Validate→HandleSpecial→HardLink 窗口并发替换源为 symlink 的绕过，inline 单源 fd 级 Verified 闭环（前置 ArchiveValidateHardlinkSource fail-fast 诊断 via archive.fs 单源复用 bytes.ops 零拷贝 inline，零额外分配）
              ArchiveHardLinkVerified(LHardSource, LFull);
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
