unit nextpas.core.tar.fs;
{**
 * @desc Tar 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 * 委托 nextpas.core.archive.fs 的排序、几何扩容、symlink 拒绝、零拷贝落盘、
 * deferred-dir 逆序定稿与统一目录 Walk（ArchiveCollectWalk 单源），打包经 bytes.builder
 * IBytesBuilder 直写切片单次 ToBytes 交付（消除 CreateBytesStream+ArchiveSnapshotStream 二次
 * SetLength+Seek+Read 大块 Move），消除与 zip.fs 的 150+ 行拷贝，保持确定性与 fail-closed；
 * L2 单 seam：fs 仅经 archive 联邦，注册层级见 module-registry archive/tar。
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
  nextpas.core.bytes.builder,
  nextpas.core.archive.fs;

type
  TWalkEntry = TArchiveWalkEntry;
  TWalkArray = TArchiveWalkArray;
  TDeferredDir = TArchiveDeferredDir;
  TDeferredDirArray = TArchiveDeferredArray;

{ IBytesBuilder 最小 IWriter 适配：直写切片至 builder，复用 bytes.builder 几何扩容单源，inline 单次 Move 零额外拷贝 }
type
  TBuilderSink = class(TInterfacedObject, IWriter)
  private
    FBuilder: IBytesBuilder;
  public
    constructor Create(const ABuilder: IBytesBuilder);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; inline;
  end;

constructor TBuilderSink.Create(const ABuilder: IBytesBuilder);
begin
  inherited Create;
  FBuilder := ABuilder;
end;

function TBuilderSink.Write(const ABuf; const ACount: SizeUInt): SizeUInt; inline;
begin
  // perf: inline + AppendBytes 单次 Move（bytes.builder 几何扩容单源，4K 页对齐），零拷贝切片直写
  if ACount > 0 then
    FBuilder.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

{ Walk 递归已完全下沉至 archive.fs: ArchiveCollectWalk 单源，tar 仅薄委托，无重复实现 }

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
var
  LRoot: TFileInfo;
  LWalks: TWalkArray;
  LI, LWalksCount: Integer;
  LHdr: TTarHeader;
  LFile: IFile;
  LStat: TFileInfo;
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
      // 流式：按需打开句柄分块搬运，64K 复用缓冲，仅 O(1) 内存，零全量拷贝
      LFile := nil;
      // perf: inline Close + 零拷贝 Move 单源 bytes.ops，异常时仍释句柄
      LFile := Open(LWalks[LI].FFull, [fmRead]);
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
  // IBytesBuilder 直写切片，复用 bytes.builder 几何扩容单源，消除 CreateBytesStream+ArchiveSnapshotStream 二次 SetLength+Seek+Read 大块 Move
  LBuilder := CreateBytesBuilder(4096);
  LSink := TBuilderSink.Create(LBuilder);
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
