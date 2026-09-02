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
  nextpas.core.tar.capacity,
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

{ Walk打包单源：消除 TarPackDir/TarPackDirInto 重复，零拷贝；单口直达 AddEntryFromReader 收敛（ITarBuilder 单口高级感），writer内高水位池化 capacity.TarIOBufCapacityFor+bytes.ops单源inline零拷贝，外联遵设计公约红线2（真实循环/文件IO分发禁inline避I-Cache膨胀） }
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
        // 单口直达：ITarWriter.AddEntryFromReader 单口零拷贝 high-water池化，capacity.TarIOBufCapacityFor+bytes.ops单源inline，try..finally必释不丢
        AWriter.AddEntryFromReader(LHdr, LFile as IReader);
      finally
        try
          LFile.Close;
        except
        end;
      end;
    end;
  end;
end;

{ Walk 收集前奏单源：消除 TarPackDir/TarPackDirInto 同构 SetLength/ArchiveCollectWalk/SetLength 重复，inline 薄转发 ArchiveCollectWalk 单源，几何扩容复用，零额外分配 }
procedure CollectTarWalks(const ADir: string; var AWalks: TArchiveWalkArray; var ACount: Integer); inline;
begin
  SetLength(AWalks, 0);
  ACount := 0;
  ArchiveCollectWalk(ADir, '', AWalks, ACount);
  SetLength(AWalks, ACount);
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
  CollectTarWalks(ADir, LWalks, LWalksCount);
  try
    // 复用已Stat FSize，PackWalks 零拷贝（外联遵红线2，循环/IO分发不inline）
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
  LWalksCount: Integer;
  LCap: SizeUInt;
  LI: Integer;
  LEst: UInt64;
begin
  Result := nil;
  CollectTarWalks(ADir, LWalks, LWalksCount);
  try
    // perf: 按实际载荷预估 — header 512 + AlignUp(FSize,512) 单遍累加（bytes.ops AlignUp 单源 512 对齐），经 capacity.TarBuilderCapacityFor 4K 对齐预扩容，几何 2× 按需 Reserve，单次 ToBytes 零额外拷贝，接口自动释资源不丢
    LEst := 0;
    for LI := 0 to LWalksCount - 1 do
    begin
      if LWalks[LI].FSize > 0 then
        LEst := LEst + UInt64(C_TAR_BLOCK_SIZE) + UInt64(AlignUp(SizeUInt(LWalks[LI].FSize), SizeUInt(C_TAR_BLOCK_SIZE)))
      else
        LEst := LEst + UInt64(C_TAR_BLOCK_SIZE);
    end;
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
        // 单次 ArchiveJoinPath 复用 bytes.ops 单源，同父缓存+前缀命中 inline 零拷贝，SyncTarParentCache 单源
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
