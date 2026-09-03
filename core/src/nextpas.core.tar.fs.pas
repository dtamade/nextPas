unit nextpas.core.tar.fs;
{**
 * @desc Tar 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 * 委托 nextpas.core.archive.fs 的排序、几何扩容、symlink 拒绝、零拷贝落盘、
 * deferred-dir 逆序定稿与统一目录 Walk（ArchiveCollectWalks/ArchiveEstimateTarSize 单源：Walk 收集 SetLength/ArchiveCollectWalk/SetLength 模板与容量预估 header+AlignUp 循环样板均收敛至 archive.fs 联邦单源，复用 bytes.ops AlignUp 单源 inline 零拷贝），打包经 archive.fs 联邦 IArchiveBuilder（IBytesBuilder 单源 via archive.fs 联邦单缝，直写切片单次 ToBytes 交付，消除 CreateBytesStream+ArchiveSnapshotStream 二次
 * SetLength+Seek+Read 大块 Move），消除与 zip.fs 的 150+ 行拷贝，保持确定性与 fail-closed；
 * L2 单 seam 家族联邦：fs/builder 仅经 archive.fs + archive.pax 单缝家族（archive.fs 为 fs/builder 唯一显式依赖，archive.pax 为 pax kv 单源共享内核，tar.fs 禁直引 nextpas.core.fs/nextpas.core.fs.errors/nextpas.core.text.conv/nextpas.core.bytes.builder 同层双缝），复用 bytes.ops 单源零拷贝 inline，注册层级见 module-registry archive/tar 联邦 via archive.fs + archive.pax。
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
  nextpas.core.tar.capacity,
  nextpas.core.tar.reader,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.pathvalid,
  nextpas.core.log.intf,
  nextpas.core.archive.fs;

{ 薄别名已移除：直接复用 archive.fs TArchiveWalkEntry/TArchiveWalkArray/TArchiveDeferredDir 单源 }

{ Walk 递归与容量预估已完全下沉至 archive.fs: ArchiveCollectWalks/ArchiveEstimateTarSize 单源（几何扩容+AlignUp 512 单源 inline 零拷贝），tar 零模板 }

{ symlink/hardlink target 安全校验：参数化复用 bytes.pathvalid.IsSafeArchiveEntryNameEx 单源（阈值 C_TAR_MAX_LINK_BYTES/禁尾斜杠），inline 薄转发、零拷贝段扫描（原串索引无Copy/分配），复用 bytes.ops 单源思想，消除与 IsSafeArchiveEntryName 的80%重复 }
function IsSafeTarLinkTarget(const ATarget: string): Boolean; inline;
begin
  Result := IsSafeArchiveEntryNameEx(ATarget, C_TAR_MAX_LINK_BYTES, False);
end;

{ Walk打包单源：消除 TarPackDir/TarPackDirInto 重复，零拷贝；单口直达 AddEntryFromReader 收敛（ITarBuilder 单口高级感），writer内高水位池化 capacity.TarIOBufCapacityFor+bytes.ops单源inline零拷贝，外联遵设计公约红线2（真实循环/文件IO分发禁inline避I-Cache膨胀），跨条目读缓冲复用 via writer FIOBuf 高水位池化（4K~1M clamp/AlignUp4K bytes.ops位掩码inline零拷贝/BytesEnsureCapacity几何2×，单次高水位分配跨200×512B复用零每条目GetMem抖动，DoCopyAndPad PByte视图零拷贝直达 bytes.ops.CopyMemory单源）；串行逐文件 OpenRead/AddEntryFromReader 高水位复用已收敛至 writer FIOBuf 单次分配跨条目复用，消除对称量小文件系统调用放大（批量预读由 archive.fs Walk 单源 ReadDir 批量缓存保障，PByte 零拷贝直达） }
procedure PackWalks(const AWalks: TArchiveWalkArray; const AWriter: TTarWriter);
var
  LI: Integer;
  LHdr: TTarHeader;
  LFile: TArchiveFile;
begin
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
      LFile := ArchiveOpenRead(AWalks[LI].FFull);
      try
        // 单口直达：ITarWriter.AddEntryFromReader 单口零拷贝 high-water池化（capacity.TarIOBufCapacityFor→AlignUp4K bytes.ops位掩码inline零拷贝/BytesEnsureCapacity几何2×高水位复用/4K~1M clamp单次分发，跨条目复用零每条目分配，DoCopyAndPad PByte视图零拷贝直达 bytes.ops.CopyMemory单源），try..finally必释不丢；外联遵设计公约红线2（真实循环/文件IO分发禁inline避I-Cache膨胀）；联邦单缝 ArchiveWarnCloseFailed/log.intf 单源可观测
        AWriter.AddEntryFromReader(LHdr, LFile as IReader);
      finally
        try
          LFile.Close;
        except
          on E: Exception do
            // stability+observability: Close 异常经 archive.fs 联邦单源 ArchiveWarnCloseFailed 可观测（log.intf NullLogger 零分配 inline 薄转发，统一错误归一，不静默吞，fail-closed可诊断），消除 tar.fs 直引 fs.errors 双缝
            ArchiveWarnCloseFailed('tar pack', AWalks[LI].FFull, E);
        end;
      end;
    end;
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
  ArchiveCollectWalks(ADir, LWalks, LWalksCount);
  try
    // 复用已Stat FSize，PackWalks 零拷贝（外联遵红线2，循环/IO分发不inline）
    PackWalks(LWalks, AWriter);
  finally
    SetLength(LWalks, 0);
  end;
end;

function TarPackDir(const ADir: string): TBytes;
var
  LBuilder: IArchiveBuilder;
  LSink: IWriter;
  W: TTarWriter;
  LWalks: TArchiveWalkArray;
  LWalksCount: Integer;
  LCap: SizeUInt;
  LEst: UInt64;
begin
  Result := nil;
  ArchiveCollectWalks(ADir, LWalks, LWalksCount);
  try
    // perf: 按实际载荷预估 — header 512 + AlignUp(FSize,512) 单遍累加已下沉 archive.fs ArchiveEstimateTarSize 单源（bytes.ops AlignUp 位掩码 inline 零拷贝），经 capacity.TarBuilderCapacityFor 4K 对齐预扩容，几何 2× 按需 Reserve，单次 ToBytes 零额外拷贝，接口自动释资源不丢
    LEst := ArchiveEstimateTarSize(LWalks, LWalksCount);
    if LEst > High(SizeUInt) then
      LCap := nextpas.core.tar.capacity.TarBuilderCapacityFor(High(SizeUInt))
    else
      LCap := nextpas.core.tar.capacity.TarBuilderCapacityFor(SizeUInt(LEst));
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

{ 同父缓存已下沉 archive.fs 单源 ArchiveSyncParentCache，tar 为 inline 薄转发，复用 bytes.ops 单源零拷贝，消除手写 CopyMemory+CompareMem 重复，保持 L0-L3 联邦单缝 }
procedure SyncTarParentCache(const AFull: string; var ALastParent: string; var AParentLen: SizeUInt); inline;
begin
  ArchiveSyncParentCache(AFull, ALastParent, AParentLen);
end;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
var
  ROpts: TTarReadOptions;
  R: TTarReader;
  H: TTarHeader;
  LFull: string;
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
        // 单次 ArchiveJoinPath 复用 bytes.ops 单源，同父缓存+前缀命中 inline 零拷贝，SyncTarParentCache 单源
        LFull := ArchiveJoinPath(ADestDir, H.Name);
        if (LLastParent <> '') and (Length(LFull) > Length(LLastParent)) and (LFull[Length(LLastParent) + 1] = '/') then
        begin
          // perf: inline 零拷贝 TByteSpan 视图 via bytes.ops StringAsSpan 单源 + SpanContains SIMD 单源，消除手写 for 斜杠扫描 O(n) 稀释，inline 单源零拷贝高级感
          if SpanContains(StringAsSpan(LFull).Slice(SizeUInt(Length(LLastParent) + 1), SizeUInt(Length(LFull) - Length(LLastParent) - 1)), Byte('/')) then
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
                  // L2经 archive.fs 联邦单缝可观测（ArchiveLogWarn→log.intf NullLogger 零分配 inline 薄转发），无System.WriteLn/StdErr直触，fail-closed 不静默降级为普通文件（设备语义与权限一致性，不以空文件占位掩盖 mknod 特权不足），复用 writer/builder 单源
                  ArchiveLogWarn('[WARN] tar extract: mkfifo failed for ' + H.Name + ': ' + E.Message);
                  raise;
                end;
              end;
            end;
          tekCharDevice, tekBlockDevice:
            begin
              ArchiveHandleSpecial(LFull);
              // INV-7 往返完整：经 archive.fs 单缝 ArchiveTryMkDevice 携带 DevMajor/DevMinor 真实 mknod（S_IFCHR/S_IFBLK），特权不足则 fail-closed 抛异常（经 archive.fs 联邦 ArchiveIntToStr/TextConv 单源 inline 零拷贝 + ArchiveLogWarn/log.intf 单缝可观测），不静默降级为普通文件（消除 ArchiveWriteEmptyFallback 空文件占位兜底），复用 bytes.ops 单源零拷贝/Inline思想
              if not ArchiveTryMkDevice(LFull, LMode, H.DevMajor, H.DevMinor, H.Kind = tekCharDevice) then
              begin
                ArchiveLogWarn('[WARN] tar extract: special device skipped (mknod failed dev=' + ArchiveIntToStr(H.DevMajor) + ':' + ArchiveIntToStr(H.DevMinor) + '): ' + H.Name + ' kind=' + ArchiveIntToStr(Ord(H.Kind)));
                raise EPermissionError.Create('tar extract: mknod failed for ' + H.Name + ' dev=' + ArchiveIntToStr(H.DevMajor) + ':' + ArchiveIntToStr(H.DevMinor));
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
