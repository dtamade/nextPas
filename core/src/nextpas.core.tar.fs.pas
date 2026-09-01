unit nextpas.core.tar.fs;
{**
 * @desc Tar 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 * 委托 nextpas.core.archive.fs 的排序、几何扩容、symlink 拒绝、快照、零拷贝落盘、
 * deferred-dir 逆序定稿与统一目录 Walk（ArchiveCollectWalk 单源），消除与 zip.fs 的 150+ 行拷贝，
 * 保持确定性与 fail-closed；L2 单 seam：fs 仅经 archive 联邦，注册层级见 module-registry archive/tar。
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
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.archive.fs;

type
  TWalkEntry = TArchiveWalkEntry;
  TWalkArray = TArchiveWalkArray;
  TDeferredDir = TArchiveDeferredDir;
  TDeferredDirArray = TArchiveDeferredArray;

{ 兼容原内部调用名，委托 archive 几何扩容/排序/防劫持 }
procedure EnsureWalkCapacity(var A: TWalkArray; AMin: Integer); inline;
begin
  ArchiveEnsureWalkCapacity(A, AMin);
end;

procedure WalkAppend(var A: TWalkArray; var ACount: Integer; const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word); inline;
begin
  ArchiveWalkAppend(A, ACount, ARel, AFull, AIsDir, AMtime, AMode);
end;

procedure SortDirEntries(var A: TDirEntryArray); inline;
begin
  ArchiveSortDirEntries(A);
end;

procedure EnsureNoSymlinkInPath(const APath: string); inline;
begin
  ArchiveEnsureNoSymlinkInPath(APath);
end;

procedure EnsureDeferredCapacity(var A: TDeferredDirArray; AMin: Integer); inline;
begin
  ArchiveEnsureDeferredCapacity(A, AMin);
end;

{ CollectLevel 已完全下沉至 archive.fs: ArchiveCollectWalk 单源复用，tar 仅薄委托，避免重复递归实现 }

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
var
  LRoot: TFileInfo;
  LWalks: TWalkArray;
  LI, LWalksCount: Integer;
  LData: TBytes;
  LHdr: TTarHeader;
begin
  if AWriter = nil then
    raise EArgumentError.Create('tar pack: writer is nil');
  LRoot := Stat(ADir);
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
      LData := ReadFile(LWalks[LI].FFull);
      LHdr.Size := Length(LData);
      AWriter.AddEntry(LHdr, LData);
    end;
  end;
  SetLength(LWalks, 0);
end;

function TarPackDir(const ADir: string): TBytes;
var
  S: IStream;
  W: TTarWriter;
begin
  Result := nil;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    TarPackDirInto(ADir, W);
    W.Finish;
    Result := ArchiveSnapshotStream(S, 'tar pack');
  finally
    W.Free;
  end;
end;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
var
  ROpts: TTarReadOptions;
  R: TTarReader;
  H: TTarHeader;
  LFull, LParent: string;
  LSep: Integer;
  LMode: Word;
  LDirs: TDeferredDirArray;
  LDirCount: Integer;
  LMaxEntry: SizeUInt;
  LMaxTotal: UInt64;
  LSlice: PByte;
  LSliceCount: SizeUInt;
begin
  if AOptions.MaxEntrySize = 0 then
    LMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    LMaxEntry := AOptions.MaxEntrySize;
  LMaxTotal := AOptions.MaxTotalSize;
  ROpts.MaxEntrySize := LMaxEntry;
  ROpts.MaxTotalSize := LMaxTotal;
  R := TTarReader.CreateWithOptions(AData, ROpts);
  try
    MkdirAll(ADestDir, PermDirDefault);
    ArchiveEnsureNoSymlinkInPath(ADestDir);
    SetLength(LDirs, 0);
    LDirCount := 0;
    try
      while R.Next(H) do
      begin
        GuardTarNameForRead(H.Name);
        if (H.Kind <> tekRegular) and (H.Kind <> tekDirectory) and AOptions.SkipSpecial then
          Continue;
        LFull := ADestDir;
        while (LFull <> '') and (LFull[Length(LFull)] = '/') do
          Delete(LFull, Length(LFull), 1);
        LFull := LFull + '/' + H.Name;
        while (LFull <> '') and (LFull[Length(LFull)] = '/') do
          Delete(LFull, Length(LFull), 1);
        LSep := Length(LFull);
        while (LSep > 0) and (LFull[LSep] <> '/') do
          Dec(LSep);
        if LSep > 0 then
        begin
          LParent := Copy(LFull, 1, LSep - 1);
          ArchiveEnsureNoSymlinkInPath(LParent);
          MkdirAll(LParent, PermDirDefault);
        end;
        LMode := Word(H.Mode and $0FFF);
        if H.Kind = tekDirectory then
          MkdirAll(LFull, PermDirDefault)
        else if H.Kind = tekRegular then
        begin
          { 零拷贝：复用 Reader 已有的 EntryDataSlice/OpenEntryStream，避免 EntryData 的 SetLength+Move 双倍内存 }
          if R.EntryDataSlice(LSlice, LSliceCount) then
            ArchiveWriteFileSlice(LFull, LSlice, LSliceCount, PermDefault)
          else
            ArchiveWriteFileSlice(LFull, nil, 0, PermDefault);
          if AOptions.RestoreMode and (LMode <> 0) then
          begin
            try
              Chmod(LFull, TFilePermission(LMode));
            except
              on E: Exception do
              begin
                { best-effort 权限还原，保留上下文但不中断解包 }
              end;
            end;
          end;
          try
            Chtimes(LFull, H.MTimeUnix * 1000000000, H.MTimeUnix * 1000000000);
          except
            on E: Exception do
            begin
              { best-effort mtime 还原 }
            end;
          end;
        end
        else
          Continue;
        if H.Kind = tekDirectory then
        begin
          ArchiveDeferredAppend(LDirs, LDirCount, LFull, LMode, H.MTimeUnix * 1000000000);
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
