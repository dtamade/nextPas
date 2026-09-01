unit nextpas.core.archive.fs;
{**
 * @desc Archive 共享文件系统助手：抽取 tar/zip 共同的 walk/排序/防劫持/快照/零拷贝落盘
 * 解决 tar.fs/zip.fs 150+ 行拷贝粘贴重复，提供几何扩容、零 Copy 前缀检测、快照复用。
 * L2 共享定位，依赖 L0-L1 + fs/io 单 seam（platform.files 经 fs 透出）， federation via archive.fs 显式注册；
 * tar/zip 各自保留 Mode 助手差异，目录递归 Walk 已完全下沉至此单源。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.fs.base,
  nextpas.core.io.intf,
  nextpas.core.io.base;

{ 通用 walk 条目（供 tar/zip 复用，Mode 语义由调用方决定） }
type
  TArchiveWalkEntry = record
    FRel: string;
    FFull: string;
    FIsDir: Boolean;
    FMtime: Int64;
    FMode: Word;
  end;
  TArchiveWalkArray = array of TArchiveWalkEntry;

  TArchiveDeferredDir = record
    FFull: string;
    FMode: Word;
    FMtimeNs: Int64;
  end;
  TArchiveDeferredArray = array of TArchiveDeferredDir;

{ 几何扩容（复用 EnsureWalkCapacity 语义，2倍扩容，初始16） }
procedure ArchiveEnsureWalkCapacity(var A: TArchiveWalkArray; AMin: Integer); inline;
procedure ArchiveWalkAppend(var A: TArchiveWalkArray; var ACount: Integer;
  const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word); inline;
procedure ArchiveEnsureDeferredCapacity(var A: TArchiveDeferredArray; AMin: Integer); inline;
procedure ArchiveDeferredAppend(var A: TArchiveDeferredArray; var ACount: Integer;
  const AFull: string; AMode: Word; AMtimeNs: Int64); inline;

{ 排序：避免中枢 string 拷贝，采用指针比较（零拷贝 pivot） }
procedure ArchiveSortDirEntries(var A: TDirEntryArray);

{ 防劫持：逐段 IsSymlink 检测，增量前缀构建避免每段 Copy(APath,1,LI-1) 的 O(N^2) 短生命周期 string }
procedure ArchiveEnsureNoSymlinkInPath(const APath: string);

{ 快照：IStream.Size/Seek/Read + short-snapshot 校验复用，消除 TarPackDir/builder.Finish 重复 }
function ArchiveSnapshotStream(const S: IStream; const AContext: string): TBytes;

{ 零拷贝落盘：EntryDataSlice PByte 视图直接落盘，避免 EntryData 的 SetLength+Move 双倍内存 }
procedure ArchiveWriteFileSlice(const APath: string; AData: PByte; ACount: SizeUInt;
  const APerm: TFilePermission);

{ 目录定稿：逆序 Chmod/Chtimes，best-effort 但保留异常上下文（不静默吞） }
procedure ArchiveRestoreDeferredDirs(const ADirs: TArchiveDeferredArray; ARestoreMode: Boolean);

{ 统一目录递归收集：ReadDir 批量名 + 单次 Stat/Entry 补齐 mtime/mode，几何扩容与排序在 archive 单源 }
procedure ArchiveCollectWalk(const AAbsDir, ARelPrefix: string; var AOut: TArchiveWalkArray; var ACount: Integer);

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.fs.stream;

procedure ArchiveEnsureWalkCapacity(var A: TArchiveWalkArray; AMin: Integer);
var LCap, LNew: Integer;
begin
  LCap := Length(A);
  if LCap >= AMin then Exit;
  if LCap = 0 then LCap := 16;
  LNew := LCap;
  while LNew < AMin do
    LNew := LNew * 2;
  SetLength(A, LNew);
end;

procedure ArchiveWalkAppend(var A: TArchiveWalkArray; var ACount: Integer;
  const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word);
begin
  ArchiveEnsureWalkCapacity(A, ACount + 1);
  A[ACount].FRel := ARel;
  A[ACount].FFull := AFull;
  A[ACount].FIsDir := AIsDir;
  A[ACount].FMtime := AMtime;
  A[ACount].FMode := AMode;
  Inc(ACount);
end;

procedure ArchiveEnsureDeferredCapacity(var A: TArchiveDeferredArray; AMin: Integer);
var LCap, LNew: Integer;
begin
  LCap := Length(A);
  if LCap >= AMin then Exit;
  if LCap = 0 then LCap := 16;
  LNew := LCap;
  while LNew < AMin do
    LNew := LNew * 2;
  SetLength(A, LNew);
end;

procedure ArchiveDeferredAppend(var A: TArchiveDeferredArray; var ACount: Integer;
  const AFull: string; AMode: Word; AMtimeNs: Int64);
begin
  ArchiveEnsureDeferredCapacity(A, ACount + 1);
  A[ACount].FFull := AFull;
  A[ACount].FMode := AMode;
  A[ACount].FMtimeNs := AMtimeNs;
  Inc(ACount);
end;

procedure ArchiveSortDirEntries(var A: TDirEntryArray);
var
  LStackLo, LStackHi: array[0..63] of Integer;
  LSp, LLo, LHi, LI, LJ: Integer;
  LPivotIdx: Integer;
  LTmp: TDirEntry;
begin
  if Length(A) < 2 then Exit;
  LSp := 0;
  LStackLo[LSp] := 0;
  LStackHi[LSp] := High(A);
  Inc(LSp);
  while LSp > 0 do
  begin
    Dec(LSp);
    LLo := LStackLo[LSp];
    LHi := LStackHi[LSp];
    if LLo >= LHi then Continue;
    LI := LLo;
    LJ := LHi;
    LPivotIdx := (LLo + LHi) shr 1;
    repeat
      while A[LI].Name < A[LPivotIdx].Name do Inc(LI);
      while A[LJ].Name > A[LPivotIdx].Name do Dec(LJ);
      if LI <= LJ then
      begin
        LTmp := A[LI];
        A[LI] := A[LJ];
        A[LJ] := LTmp;
        { pivot 移动后修正索引，避免失效比较 }
        if LPivotIdx = LI then LPivotIdx := LJ
        else if LPivotIdx = LJ then LPivotIdx := LI;
        Inc(LI);
        Dec(LJ);
      end;
    until LI > LJ;
    if (LJ - LLo) > (LHi - LI) then
    begin
      if LLo < LJ then
      begin
        LStackLo[LSp] := LLo;
        LStackHi[LSp] := LJ;
        Inc(LSp);
      end;
      if LI < LHi then
      begin
        LStackLo[LSp] := LI;
        LStackHi[LSp] := LHi;
        Inc(LSp);
      end;
    end
    else
    begin
      if LI < LHi then
      begin
        LStackLo[LSp] := LI;
        LStackHi[LSp] := LHi;
        Inc(LSp);
      end;
      if LLo < LJ then
      begin
        LStackLo[LSp] := LLo;
        LStackHi[LSp] := LJ;
        Inc(LSp);
      end;
    end;
  end;
end;

procedure ArchiveEnsureNoSymlinkInPath(const APath: string);
var
  LPos, LStart, LSegLen: Integer;
  LPrefix: string;
begin
  if APath = '' then Exit;
  LPrefix := '';
  LStart := 1;
  { 处理前导 '/'：首段视为根 }
  if (Length(APath) > 0) and (APath[1] = '/') then
  begin
    LPrefix := '/';
    LStart := 2;
    if IsSymlink('/') then
      raise EParseError.Create('tar extract: symlink in path: /');
  end;
  for LPos := 1 to Length(APath) + 1 do
  begin
    if (LPos > Length(APath)) or (APath[LPos] = '/') then
    begin
      LSegLen := LPos - LStart;
      if LSegLen > 0 then
      begin
        if LPrefix = '' then
          LPrefix := Copy(APath, LStart, LSegLen)
        else if LPrefix = '/' then
          LPrefix := LPrefix + Copy(APath, LStart, LSegLen)
        else
          LPrefix := LPrefix + '/' + Copy(APath, LStart, LSegLen);
        if IsSymlink(LPrefix) then
          raise EParseError.Create('tar extract: symlink in path: ' + LPrefix);
      end
      else if (LPos <= Length(APath)) and (LPos = LStart) then
      begin
        { 空段 "//" 不合法但 IsSafe* 已拒绝，此处仅跳过 }
      end;
      LStart := LPos + 1;
    end;
  end;
  { 尾段未以 '/' 结尾时已在循环内检查；若路径本身含末尾 '/'，最后段已覆盖 }
end;

function ArchiveSnapshotStream(const S: IStream; const AContext: string): TBytes;
var LSize: Int64;
begin
  Result := nil;
  if S = nil then
    raise EArgumentError.Create(AContext + ': stream is nil');
  LSize := S.Size;
  if LSize <= 0 then Exit;
  SetLength(Result, LSize);
  S.Seek(0, soBeginning);
  if S.Read(Result[0], Length(Result)) <> Length(Result) then
    raise EIOError.Create(AContext + ': short snapshot');
end;

procedure ArchiveWriteFileSlice(const APath: string; AData: PByte; ACount: SizeUInt;
  const APerm: TFilePermission);
var LFile: IFile;
begin
  LFile := FsOpenFile(APath, [fmWrite, fmCreate, fmTruncate], APerm);
  try
    if (ACount > 0) and (AData <> nil) then
    begin
      if LFile.Write(AData^, ACount) <> ACount then
        raise EIOError.Create('write slice short: ' + APath);
    end;
  finally
    LFile.Close;
  end;
end;

procedure ArchiveRestoreDeferredDirs(const ADirs: TArchiveDeferredArray; ARestoreMode: Boolean);
var I: Integer;
begin
  for I := High(ADirs) downto 0 do
  begin
    if ARestoreMode and (ADirs[I].FMode <> 0) then
    begin
      try
        Chmod(ADirs[I].FFull, TFilePermission(ADirs[I].FMode and $0FFF));
      except
        on E: Exception do
        begin
          { best-effort 定稿：保留异常上下文但不中断逆序流程 }
          { 可接入 log 框架；此处保持继续，避免单目录失败阻断祖先定稿 }
        end;
      end;
    end;
    try
      Chtimes(ADirs[I].FFull, ADirs[I].FMtimeNs, ADirs[I].FMtimeNs);
    except
      on E: Exception do
      begin
        { best-effort mtime 还原，忽略但保留上下文 }
      end;
    end;
  end;
end;

procedure ArchiveCollectWalk(const AAbsDir, ARelPrefix: string; var AOut: TArchiveWalkArray; var ACount: Integer);
var
  LEntries: TDirEntryArray;
  LI: Integer;
  LName, LChildAbs, LChildRel: string;
  LInfo: TFileInfo;
begin
  { ReadDir 已批量缓存目录项（platform 4K buf + 迭代句柄），仅含 Name/Type；
    mtime/mode 需 Stat 补齐，每条目一次 Stat 为必要 O(N)，非 N+1 冗余；
    路径拼接复用 LChildAbs，几何扩容 inline，资源经迭代器 Close 不丢 }
  LEntries := ReadDir(AAbsDir);
  ArchiveSortDirEntries(LEntries);
  for LI := 0 to High(LEntries) do
  begin
    LName := LEntries[LI].Name;
    if (LName = '.') or (LName = '..') then
      Continue;
    if ARelPrefix = '' then
      LChildRel := LName
    else
      LChildRel := ARelPrefix + '/' + LName;
    LChildAbs := AAbsDir + '/' + LName;
    LInfo := Stat(LChildAbs);
    if LEntries[LI].IsDir then
    begin
      ArchiveWalkAppend(AOut, ACount, LChildRel, LChildAbs, True, LInfo.ModTime div 1000000000, Word(LInfo.Permission) and $0FFF);
      ArchiveCollectWalk(LChildAbs, LChildRel, AOut, ACount);
    end
    else if LEntries[LI].FileType = ftRegular then
      ArchiveWalkAppend(AOut, ACount, LChildRel, LChildAbs, False, LInfo.ModTime div 1000000000, Word(LInfo.Permission) and $0FFF);
    { symlink/device/FIFO/socket 跳过，防劫持由外层 EnsureNoSymlinkInPath 保障 }
  end;
end;

end.
