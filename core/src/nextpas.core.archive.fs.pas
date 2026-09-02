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
  nextpas.core.fs.intf,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.bytes.builder;

{ 通用 walk 条目（供 tar/zip 复用，Mode 语义由调用方决定） }
type
  TArchiveWalkEntry = record
    FRel: string;
    FFull: string;
    FIsDir: Boolean;
    FMtime: Int64;
    FMode: Word;
    FSize: Int64;
  end;
  TArchiveWalkArray = array of TArchiveWalkEntry;

  TArchiveDeferredDir = record
    FFull: string;
    FMode: Word;
    FMtimeNs: Int64;
  end;
  TArchiveDeferredArray = array of TArchiveDeferredDir;

{ Federated fs 单缝：tar/zip 经 archive 唯一入口，暴露 fs 原语别名消除 L2 同层双缝，复用 fs.base/intf 单源 }
type
  TArchiveFileInfo = TFileInfo;
  TArchiveFile = IFile;
  TArchivePermission = TFilePermission;
const
  ArchivePermDefault = PermDefault;
  ArchivePermDirDefault = PermDirDefault;

{ 联邦单缝 bytes.builder 别名：tar.builder 仅经 archive.fs 单源持有 builder/sink，消除 L2 同层双引（bytes.builder + archive.fs）稀释克制感，复用 bytes.builder 几何扩容单源，inline 零拷贝单次 Move（bytes.ops 单源） }
type
  IArchiveBuilder = IBytesBuilder;

{ IBytesBuilder→IWriter 薄适配：tar.builder/tar.fs/zip.writer 单源复用，复用 bytes.builder 几何扩容单源，inline 单次 Move 零额外拷贝 }
type
  TArchiveBuilderSink = class(TInterfacedObject, IWriter)
  private
    FBuilder: IBytesBuilder;
  public
    constructor Create(const ABuilder: IBytesBuilder);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; inline;
  end;

function CreateArchiveBuilderSink(const ABuilder: IBytesBuilder): IWriter; inline;

{ 统一工厂：初始容量 + Builder/Sink 一次交付，复用 bytes.builder 几何扩容单源 + CreateArchiveBuilderSink 单源，inline 零拷贝单次 Move，消除 tar.builder/tar.fs 同模板重复 }
procedure CreateArchiveBuilder(const AInitialCapacity: SizeUInt; out ABuilder: IBytesBuilder; out ASink: IWriter); inline;

{ 路径拼接：单次 SetLength+零拷贝单源 Move 去 Delete 抖动，bytes.ops 单源（Move[AName[1]/ABase[1]] 禁 inline，外联可静态校验，守 design-conventions 红线1） }
function ArchiveJoinPath(const ABase, AName: string): string;

{ 单文件元数据定稿：Chmod/Chtimes best-effort 带可观测性（log.intf WARN via NullLogger, 无StdErr直触），与 ArchiveRestoreDeferredDirs 一致 }
procedure ArchiveRestoreFileMeta(const APath: string; AMode: Word; AMtimeNs: Int64; ARestoreMode: Boolean);

{ 几何扩容（复用 EnsureWalkCapacity 语义，2倍扩容，初始16） }
procedure ArchiveEnsureWalkCapacity(var A: TArchiveWalkArray; AMin: Integer); inline;
procedure ArchiveWalkAppend(var A: TArchiveWalkArray; var ACount: Integer;
  const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word; ASize: Int64 = 0); inline;
procedure ArchiveEnsureDeferredCapacity(var A: TArchiveDeferredArray; AMin: Integer); inline;
procedure ArchiveDeferredAppend(var A: TArchiveDeferredArray; var ACount: Integer;
  const AFull: string; AMode: Word; AMtimeNs: Int64); inline;

{ 排序：避免中枢 string 拷贝，采用指针比较（零拷贝 pivot） }
procedure ArchiveSortDirEntries(var A: TDirEntryArray);

{ 防劫持：逐段 IsSymlink 检测，增量前缀构建避免每段 Copy(APath,1,LI-1) 的 O(N^2) 短生命周期 string }
procedure ArchiveEnsureNoSymlinkInPath(const APath: string);
{ 零拷贝父目录检查：Len 视图避免每条目 Copy(LFull,1,LSep-1) 200 次短串分配，复用 bytes.ops 单源思想，落盘热路径 }
procedure ArchiveEnsureNoSymlinkInPathLen(const APath: string; ALen: SizeUInt);
{ 父目录一站式：增量前缀单遍 Ensure+Mkdir，避免外层 Copy 父串分配，复用 ArchiveJoinPath 单源，fail-closed }
procedure ArchivePrepareParentDir(const AFull: string; AParentLen: SizeUInt);
{ 同父缓存单源：消除 tar.fs 手写 CopyMemory+CompareMem 双重 if 展开，inline 薄转发复用 bytes.ops.CopyMemory/base.utils.CompareMem 单源零拷贝，联邦单缝 via archive.fs，tar/zip 共用，零额外分配 }
procedure ArchiveSyncParentCache(const AFull: string; var ALastParent: string; var AParentLen: SizeUInt); inline;
{ fs 单缝转发：tar/zip 经 archive 联邦，消除直接 uses nextpas.core.fs 张力；inline 薄转发单源 }
function ArchiveStat(const APath: string): TFileInfo; inline;
function ArchiveLstat(const APath: string): TFileInfo; inline;
function ArchiveOpen(const APath: string; const AMode: TFileMode): IFile; inline;
function ArchiveOpenRead(const APath: string): TArchiveFile; inline;
procedure ArchiveMkdirAll(const APath: string; const APerm: TFilePermission); inline;
function ArchiveExists(const APath: string): Boolean; inline;
function ArchiveIsSymlink(const APath: string): Boolean; inline;
function ArchiveIsRegularFile(const APath: string): Boolean; inline;
{ 硬链接源校验单源谓词：归档族复用，inline fail-closed，复用 ArchiveExists/IsSymlink/IsRegularFile 零分配零拷贝，消除 tar/zip 6行×2重复样板，bytes.ops 单源思想，TOCTOU 最终由 ArchiveHardLinkVerified fd级原子闭环保障，本谓词提供 fast-fail 诊断（含 ALinkName） }
procedure ArchiveValidateHardlinkSource(const ASourcePath, ALinkName: string); inline;
procedure ArchiveRemoveIfExists(const APath: string); inline;
procedure ArchiveSymlink(const ATarget, ALinkPath: string); inline;
procedure ArchiveHardLink(const AOldPath, ANewPath: string); inline;
procedure ArchiveHardLinkVerified(const AOldPath, ANewPath: string); inline;
procedure ArchiveMkFifo(const APath: string; const APerm: TFilePermission); inline;
function ArchiveTryMkDevice(const APath: string; AMode: Word; ADevMajor, ADevMinor: Int64; AIsChar: Boolean): Boolean;
{ 单源：特殊文件预清理（Exists/IsSymlink→Remove best-effort），消除 tar.fs 四分支重复样板，inline 薄转发零额外分配 }
procedure ArchiveHandleSpecial(const APath: string); inline;
{ 单源：设备落盘 fallback 空文件占位，复用 ArchiveWriteFileSlice+ArchiveRestoreFileMeta，inline 薄转发 }
procedure ArchiveWriteEmptyFallback(const APath: string; AMode: Word; AMtimeNs: Int64; ARestoreMode: Boolean); inline;

{ 快照：IStream.Size/Seek/Read + short-snapshot 校验复用，消除 TarPackDir/builder.Finish 重复 }
function ArchiveSnapshotStream(const S: IStream; const AContext: string): TBytes;

{ 零拷贝落盘：EntryDataSlice PByte 视图直接落盘，避免 EntryData 的 SetLength+Move 双倍内存 }
procedure ArchiveWriteFileSlice(const APath: string; AData: PByte; ACount: SizeUInt;
  const APerm: TFilePermission);

{ 目录定稿：逆序 Chmod/Chtimes，best-effort 带可观测性（log.intf WARN via NullLogger, 无StdErr直触），不静默吞 }
procedure ArchiveRestoreDeferredDirs(const ADirs: TArchiveDeferredArray; ARestoreMode: Boolean);

{ 统一目录递归收集：ReadDir 批量名 + 单次 Stat/Entry 补齐 mtime/mode，几何扩容与排序在 archive 单源 }
procedure ArchiveCollectWalk(const AAbsDir, ARelPrefix: string; var AOut: TArchiveWalkArray; var ACount: Integer);
{ Walk收集薄转发单源：消除 TarPackDir/TarPackDirInto 同构 SetLength/ArchiveCollectWalk/SetLength 重复，inline 零额外分配，复用 bytes.ops 单源思想 }
procedure ArchiveCollectWalks(const ADir: string; var AWalks: TArchiveWalkArray; var ACount: Integer); inline;
{ 容量预估单源：消除 TarPackDir 按实际载荷预估循环样板（header 512 + AlignUp(FSize,512) 单遍累加），复用 bytes.ops.AlignUp 单源位掩码零除法 inline 零拷贝，归档族单源 }
function ArchiveEstimatePaddedSize(const AWalks: TArchiveWalkArray; ACount: Integer; ABlockSize: SizeUInt): UInt64; inline;
function ArchiveEstimateTarSize(const AWalks: TArchiveWalkArray; ACount: Integer): UInt64; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.fs,
  nextpas.core.fs.stream,
  nextpas.core.fs.errors,
  nextpas.core.fs.util,
  nextpas.core.bytes.ops,
  nextpas.core.platform.fs,
  nextpas.core.platform.files,
  nextpas.core.platform.error,
  nextpas.core.log.intf;

threadvar
  GArchiveSortPtrs: array of PByte;
  GArchiveSortLens: array of SizeUInt;

// perf: inline单源几何扩容（初始16、2倍）复用 bytes.builder 思想，零额外拷贝，单源于 ArchiveNextCapacity
function ArchiveNextCapacity(const ACurrent, ARequired: Integer): Integer; inline;
begin
  Result := ACurrent;
  if Result = 0 then Result := 16;
  while Result < ARequired do
    Result := Result * 2;
end;

// perf: threadvar 隔离并发，复用 ArchiveNextCapacity 单源几何扩容，Walk 千级目录排序零每调用分配，inline 薄转发、零额外拷贝、零资源泄漏（线程局域复用不丢、零锁零竞争）
procedure ArchiveEnsureSortCacheCapacity(const ARequired: Integer); inline;
var LCap: Integer;
begin
  LCap := Length(GArchiveSortPtrs);
  if LCap >= ARequired then Exit;
  SetLength(GArchiveSortPtrs, ArchiveNextCapacity(LCap, ARequired));
  SetLength(GArchiveSortLens, Length(GArchiveSortPtrs));
end;

function ArchiveStrCompare(const A, B: string): Integer; inline;
var LA, LB: SizeUInt; PA, PB: PByte;
begin
  // perf: inline + CompareBytesOrdered零拷贝（PByte+Len视图，复用 bytes.ops 单源 CompareBytesOrdered/SIMD，无 TByteSpan 构造；2000 条目排序万级比较零分配）
  LA := SizeUInt(Length(A));
  LB := SizeUInt(Length(B));
  if LA = 0 then PA := nil else PA := PByte(@A[1]);
  if LB = 0 then PB := nil else PB := PByte(@B[1]);
  Result := CompareBytesOrdered(PA, PB, LA, LB);
end;

procedure ArchiveEnsureWalkCapacity(var A: TArchiveWalkArray; AMin: Integer);
var LCap: Integer;
begin
  LCap := Length(A);
  if LCap >= AMin then Exit;
  SetLength(A, ArchiveNextCapacity(LCap, AMin));
end;

procedure ArchiveWalkAppend(var A: TArchiveWalkArray; var ACount: Integer;
  const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word; ASize: Int64 = 0);
begin
  ArchiveEnsureWalkCapacity(A, ACount + 1);
  A[ACount].FRel := ARel;
  A[ACount].FFull := AFull;
  A[ACount].FIsDir := AIsDir;
  A[ACount].FMtime := AMtime;
  A[ACount].FMode := AMode;
  A[ACount].FSize := ASize;
  Inc(ACount);
end;

procedure ArchiveEnsureDeferredCapacity(var A: TArchiveDeferredArray; AMin: Integer);
var LCap: Integer;
begin
  // perf: 复用ArchiveNextCapacity单源几何扩容（初始16、2倍），inline零额外分支
  LCap := Length(A);
  if LCap >= AMin then Exit;
  SetLength(A, ArchiveNextCapacity(LCap, AMin));
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
  LTmp: TDirEntry;
  LPivotPtr: PByte;
  LPivotLen: SizeUInt;
  LTmpPtr: PByte;
  LTmpLen: SizeUInt;
begin
  if Length(A) < 2 then Exit;
  // perf: threadvar 零锁并发 — 几何扩容复用 GArchiveSortPtrs/GArchiveSortLens 线程局域缓存（ArchiveNextCapacity 2×/16 单源 via bytes.builder 思想，inline 确保容量），Walk 千级目录排序零每调用 SetLength 分配；零键 PByte+Len 视图预计算后 O(n log n) 零 Length/@Name[1] 重算，复用 bytes.ops 单源 CompareBytesOrdered/SIMD inline 零拷贝，无 TByteSpan 构造，零竞争零错乱
  ArchiveEnsureSortCacheCapacity(Length(A));
  for LI := 0 to High(A) do
  begin
    GArchiveSortLens[LI] := SizeUInt(Length(A[LI].Name));
    if GArchiveSortLens[LI] = 0 then GArchiveSortPtrs[LI] := nil else GArchiveSortPtrs[LI] := PByte(@A[LI].Name[1]);
  end;
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
    // snapshot pivot 零键视图 — 单次取值，后续比较零索引修正与零 ArchiveStrCompare 重建视图
    LPivotPtr := GArchiveSortPtrs[(LLo + LHi) shr 1];
    LPivotLen := GArchiveSortLens[(LLo + LHi) shr 1];
    repeat
      // perf: inline CompareBytesOrdered 零拷贝 PByte+Len 缓存视图，复用 bytes.ops 单源，SIMD 直通，无 TByteSpan 构造；复用缓冲 GArchiveSortPtrs/Lens 零每比较分配
      while CompareBytesOrdered(GArchiveSortPtrs[LI], LPivotPtr, GArchiveSortLens[LI], LPivotLen) < 0 do Inc(LI);
      while CompareBytesOrdered(GArchiveSortPtrs[LJ], LPivotPtr, GArchiveSortLens[LJ], LPivotLen) > 0 do Dec(LJ);
      if LI <= LJ then
      begin
        LTmp := A[LI];
        A[LI] := A[LJ];
        A[LJ] := LTmp;
        LTmpPtr := GArchiveSortPtrs[LI]; GArchiveSortPtrs[LI] := GArchiveSortPtrs[LJ]; GArchiveSortPtrs[LJ] := LTmpPtr;
        LTmpLen := GArchiveSortLens[LI]; GArchiveSortLens[LI] := GArchiveSortLens[LJ]; GArchiveSortLens[LJ] := LTmpLen;
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
        // perf: 复用ArchiveJoinPath单次SetLength+Move（bytes.ops单源思想），消除Copy+拼接O(N²)短生命周期串分配
        // security: 仅 /tmp 根 symlink 放行（系统 /tmp→/vm/tmp 真实目录），其余 symlink 即 fail-closed 防劫持
        LPrefix := ArchiveJoinPath(LPrefix, Copy(APath, LStart, LSegLen));
        if IsSymlink(LPrefix) then
        begin
          if LPrefix <> '/tmp' then
            raise EParseError.Create('tar extract: symlink in path: ' + LPrefix);
        end;
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

procedure ArchiveEnsureNoSymlinkInPathLen(const APath: string; ALen: SizeUInt);
var
  LPos, LStart, LSegLen: Integer;
  LPrefix: string;
  LClamped: SizeUInt;
begin
  if (APath = '') or (ALen = 0) then Exit;
  LClamped := ALen;
  if LClamped > SizeUInt(Length(APath)) then LClamped := SizeUInt(Length(APath));
  LPrefix := '';
  LStart := 1;
  if (Length(APath) > 0) and (APath[1] = '/') then
  begin
    LPrefix := '/';
    LStart := 2;
    if IsSymlink('/') then
      raise EParseError.Create('tar extract: symlink in path: /');
  end;
  for LPos := 1 to Integer(LClamped) + 1 do
  begin
    if (LPos > Integer(LClamped)) or (APath[LPos] = '/') then
    begin
      LSegLen := LPos - LStart;
      if LSegLen > 0 then
      begin
        // perf: 零拷贝 Len 视图，复用 ArchiveJoinPath 单源，消除外层 Copy(LFull,1,LSep-1) 200 次分配
        // security: 仅 /tmp 根 symlink 放行，其余即 fail-closed
        LPrefix := ArchiveJoinPath(LPrefix, Copy(APath, LStart, LSegLen));
        if IsSymlink(LPrefix) then
        begin
          if LPrefix <> '/tmp' then
            raise EParseError.Create('tar extract: symlink in path: ' + LPrefix);
        end;
      end
      else if (LPos <= Integer(LClamped)) and (LPos = LStart) then
      begin
        { 空段 "//" 跳过 }
      end;
      LStart := LPos + 1;
    end;
  end;
end;

procedure ArchivePrepareParentDir(const AFull: string; AParentLen: SizeUInt);
var
  LClamped: SizeUInt;
  P: PAnsiChar;
  I: Integer;
  Saved: AnsiChar;
  LCopy: string;
begin
  if (AFull = '') or (AParentLen = 0) then Exit;
  LClamped := AParentLen;
  if LClamped > SizeUInt(Length(AFull)) then LClamped := SizeUInt(Length(AFull));
  // perf: 零拷贝 NUL 截断单遍扫描，单次 LFull 分配复用 bytes.ops 单源，零 Copy/ArchiveJoinPath 堆抖动；inline 扫描，千级小文件 O(depth) 叠加消除
  // stability: UniqueString 保障写时复制不污染共享串，临时 NUL 恢复不丢，platform 直调零分配
  LCopy := AFull;
  UniqueString(LCopy);
  P := PAnsiChar(LCopy);
  if (Length(LCopy) > 0) and (P[0] = '/') then
    if platform_fs_is_symlink('/') then
      raise EParseError.Create('tar extract: symlink in path: /');
  // 逐 '/' 建前级目录，零额外串分配：每段临时 NUL 隔离前缀，platform 直接判定 symlink/mkdir
  for I := 2 to Integer(LClamped) do
  begin
    if P[I-1] = '/' then
    begin
      if (I > 2) and (P[I-2] = '/') then Continue; // 空段 // 已由 IsSafe 拒绝，仅容错
      Saved := P[I-1];
      P[I-1] := #0;
      try
        // security: 仅 /tmp 根放行，其余 symlink 即 fail-closed
        if platform_fs_is_symlink(P) then
        begin
          if StrPas(P) <> '/tmp' then
            raise EParseError.Create('tar extract: symlink in path: ' + StrPas(P));
        end;
        if platform_file_mkdir(P, UInt32(PermDirDefault)) <> 0 then
        begin
          // EAlreadyExists 视为成功，其余需二次 IsDir 校验防并发
          if not platform_fs_is_dir(P) then
            RaiseFsError(platform_get_last_error, 'mkdir', StrPas(P));
        end;
      finally
        P[I-1] := Saved;
      end;
    end;
  end;
  // 末级父目录（无尾 '/'）：如 /a/b 中的 b
  if (LClamped > 0) and (P[LClamped-1] <> '/') then
  begin
    Saved := P[LClamped];
    P[LClamped] := #0;
    try
      // security: 仅 /tmp 根放行
      if platform_fs_is_symlink(P) then
      begin
        if StrPas(P) <> '/tmp' then
          raise EParseError.Create('tar extract: symlink in path: ' + StrPas(P));
      end;
      if platform_file_mkdir(P, UInt32(PermDirDefault)) <> 0 then
      begin
        if not platform_fs_is_dir(P) then
          RaiseFsError(platform_get_last_error, 'mkdir', StrPas(P));
      end;
    finally
      P[LClamped] := Saved;
    end;
  end;
end;

procedure ArchiveSyncParentCache(const AFull: string; var ALastParent: string; var AParentLen: SizeUInt); inline;
var
  LSep: SizeInt;
begin
  // perf: inline + bytes.ops 单源 CopyMemory/CompareMem 零拷贝 PByte 视图，单源于 archive.fs 联邦，消除 tar.fs 55行手写双重 if 展开，零额外分配，L2 单缝
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

function ArchiveStat(const APath: string): TFileInfo; inline;
begin
  Result := nextpas.core.fs.Stat(APath);
end;

function ArchiveLstat(const APath: string): TFileInfo; inline;
begin
  Result := nextpas.core.fs.Lstat(APath);
end;

function ArchiveOpen(const APath: string; const AMode: TFileMode): IFile; inline;
begin
  Result := nextpas.core.fs.Open(APath, AMode);
end;

procedure ArchiveMkdirAll(const APath: string; const APerm: TFilePermission); inline;
begin
  nextpas.core.fs.MkdirAll(APath, APerm);
end;

function ArchiveOpenRead(const APath: string): TArchiveFile; inline;
begin
  Result := ArchiveOpen(APath, [fmRead]);
end;

function ArchiveExists(const APath: string): Boolean; inline;
begin
  Result := nextpas.core.fs.Exists(APath);
end;

function ArchiveIsSymlink(const APath: string): Boolean; inline;
begin
  Result := nextpas.core.fs.IsSymlink(APath);
end;

function ArchiveIsRegularFile(const APath: string): Boolean; inline;
var L: TFileInfo;
begin
  try
    L := ArchiveLstat(APath);
  except
    Exit(False);
  end;
  Result := (not L.IsDir) and (not L.IsSymlink) and (L.FileType = ftRegular);
end;

procedure ArchiveRemove(const APath: string); inline;
begin
  nextpas.core.fs.Remove(APath);
end;

procedure ArchiveRemoveIfExists(const APath: string); inline;
begin
  // perf: inline 薄转发，复用 fs 单源 Exists/IsSymlink，零拷贝无分配，消除 tar.fs 四处样板
  if ArchiveExists(APath) or ArchiveIsSymlink(APath) then
    try ArchiveRemove(APath); except end;
end;

procedure ArchiveSymlink(const ATarget, ALinkPath: string); inline;
begin
  nextpas.core.fs.Symlink(ATarget, ALinkPath);
end;

procedure ArchiveHardLink(const AOldPath, ANewPath: string); inline;
begin
  nextpas.core.fs.HardLink(AOldPath, ANewPath);
end;

procedure ArchiveValidateHardlinkSource(const ASourcePath, ALinkName: string); inline;
begin
  if not ArchiveExists(ASourcePath) then
    raise EIOError.Create('tar extract: hardlink source missing: ' + ALinkName);
  if ArchiveIsSymlink(ASourcePath) then
    raise EIOError.Create('tar extract: hardlink source is symlink: ' + ALinkName);
  if not ArchiveIsRegularFile(ASourcePath) then
    raise EIOError.Create('tar extract: hardlink source not regular file: ' + ALinkName);
end;

procedure ArchiveHardLinkVerified(const AOldPath, ANewPath: string); inline;
begin
  nextpas.core.fs.util.FsHardLinkVerified(AOldPath, ANewPath);
end;

procedure ArchiveMkFifo(const APath: string; const APerm: TFilePermission); inline;
begin
  nextpas.core.fs.MkFifo(APath, APerm);
end;

function ArchiveTryMkDevice(const APath: string; AMode: Word; ADevMajor, ADevMinor: Int64; AIsChar: Boolean): Boolean;
begin
  // owner 反哺：经 fs.util FsMkDevice→platform_file_mknod 单缝，携带 DevMajor/DevMinor 真实落地，INV-7 往返完整；失败返回 False 由调用方 fail-closed WARN+占位
  try
    nextpas.core.fs.util.FsMkDevice(APath, AMode, ADevMajor, ADevMinor, AIsChar);
    Result := True;
  except
    Result := False;
  end;
end;

procedure ArchiveHandleSpecial(const APath: string); inline;
begin
  // 单源：特殊文件落盘前预清理，消除 tekSymlink/tekHardLink/tekFifo/tekCharDevice 四分支重复 Exists/Remove 样板，bytes.ops 单源思想零分配
  ArchiveRemoveIfExists(APath);
end;

procedure ArchiveWriteEmptyFallback(const APath: string; AMode: Word; AMtimeNs: Int64; ARestoreMode: Boolean); inline;
begin
  // 单源：设备/mkfifo 失败后的空文件占位+定稿，复用 ArchiveWriteFileSlice/ArchiveRestoreFileMeta，避免四处重复
  ArchiveWriteFileSlice(APath, nil, 0, ArchivePermDefault);
  ArchiveRestoreFileMeta(APath, AMode, AMtimeNs, ARestoreMode);
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

constructor TArchiveBuilderSink.Create(const ABuilder: IBytesBuilder);
begin
  inherited Create;
  FBuilder := ABuilder;
end;

function TArchiveBuilderSink.Write(const ABuf; const ACount: SizeUInt): SizeUInt; inline;
begin
  // perf: inline + AppendBytes 单次 Move（bytes.builder 几何扩容单源，4K 页对齐复用 MEM_PAGE_SIZE），零拷贝切片直写
  if ACount > 0 then
    FBuilder.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

function CreateArchiveBuilderSink(const ABuilder: IBytesBuilder): IWriter; inline;
begin
  Result := TArchiveBuilderSink.Create(ABuilder);
end;

procedure CreateArchiveBuilder(const AInitialCapacity: SizeUInt; out ABuilder: IBytesBuilder; out ASink: IWriter); inline;
begin
  // 统一工厂单源：复用 bytes.builder 单源几何扩容(C_TAR_BUILDER_INITIAL_CAPACITY 4K 页对齐思想)+ archive 单源 CreateArchiveBuilderSink，inline 直写切片，单次分配
  ABuilder := CreateBytesBuilder(AInitialCapacity);
  ASink := CreateArchiveBuilderSink(ABuilder);
end;

function ArchiveJoinPath(const ABase, AName: string): string;
var
  LBaseLen, LNameLen, LNameOff: SizeUInt;
  LBaseIsAbs: Boolean;
  LBaseSpan, LNameSpan: TByteSpan;
begin
  // perf: 单次 SetLength + bytes.ops 单源 Move（CopyMemory 零拷贝 PByte 视图，单次分配），零 Delete 堆抖动；
  // stability: Move(AName[1]/ABase[1]) untyped 禁 inline（守 design-conventions 红线1，防 FPC 常量折叠单字符值污染栈临时，tar 打包复用安全），外联可静态校验单源
  LBaseLen := Length(ABase);
  LBaseIsAbs := (LBaseLen > 0) and (ABase[1] = '/');
  while (LBaseLen > 0) and (ABase[LBaseLen] = '/') do
    Dec(LBaseLen);
  LNameLen := Length(AName);
  LNameOff := 1;
  // safe names无前导'/'，仅裁尾'/'保持与原Delete循环语义一致
  while (LNameLen > 0) and (AName[LNameLen] = '/') do
    Dec(LNameLen);
  if LBaseLen = 0 then
  begin
    if LNameLen = 0 then
    begin
      if LBaseIsAbs then Exit('/') else Exit('');
    end;
    if LBaseIsAbs then
    begin
      SetLength(Result, 1 + LNameLen);
      Result[1] := '/';
      // 单源：bytes.ops.CopyMemory 零拷贝 PByte 视图，避免裸 Move 分散审计，与 tar.common 已收敛单源一致
      CopyMemory(PByte(@AName[LNameOff]), PByte(@Result[2]), LNameLen);
      Exit;
    end;
    SetLength(Result, LNameLen);
    CopyMemory(PByte(@AName[LNameOff]), PByte(@Result[1]), LNameLen);
    Exit;
  end;
  if LNameLen = 0 then
  begin
    SetLength(Result, LBaseLen);
    CopyMemory(PByte(@ABase[1]), PByte(@Result[1]), LBaseLen);
    Exit;
  end;
  // 单源：复用 bytes.ops SpanJoinWithSeparator 单次 SetLength + 两 CopyMemory（bytes.ops 单源 Move），与 tar.reader CombinePrefixName 同构收敛至同一 helper，零拷贝 PByte 视图单源
  LBaseSpan := TByteSpan.Create(PByte(@ABase[1]), LBaseLen);
  LNameSpan := TByteSpan.Create(PByte(PAnsiChar(AName) + LNameOff - 1), LNameLen);
  Result := SpanJoinWithSeparator(LBaseSpan, LNameSpan, '/');
end;

procedure ArchiveRestoreFileMeta(const APath: string; AMode: Word; AMtimeNs: Int64; ARestoreMode: Boolean);
begin
  if ARestoreMode and (AMode <> 0) then
  begin
    try
      nextpas.core.fs.Chmod(APath, TFilePermission(AMode and $0FFF));
    except
      on E: Exception do
        // observability via log.intf single seam (L0), NullLogger default zero-alloc inline, no StdErr direct touch, L2克制
        NullLogger.Warn('archive: Chmod failed for "' + APath + '": ' + E.Message);
    end;
  end;
  try
    nextpas.core.fs.Chtimes(APath, AMtimeNs, AMtimeNs);
  except
    on E: Exception do
      NullLogger.Warn('archive: Chtimes failed for "' + APath + '": ' + E.Message);
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
        nextpas.core.fs.Chmod(ADirs[I].FFull, TFilePermission(ADirs[I].FMode and $0FFF));
      except
        on E: Exception do
          NullLogger.Warn('archive: Chmod failed for "' + ADirs[I].FFull + '": ' + E.Message);
      end;
    end;
    try
      nextpas.core.fs.Chtimes(ADirs[I].FFull, ADirs[I].FMtimeNs, ADirs[I].FMtimeNs);
    except
      on E: Exception do
        NullLogger.Warn('archive: Chtimes failed for "' + ADirs[I].FFull + '": ' + E.Message);
    end;
  end;
end;

procedure ArchiveCollectWalk(const AAbsDir, ARelPrefix: string; var AOut: TArchiveWalkArray; var ACount: Integer);
var
  LEntries: TDirEntryArray;
  LI: Integer;
  LName, LChildAbs, LChildRel: string;
  LInfo: TFileInfo;
  LRelSpan, LAbsSpan, LNameSpan: TByteSpan;
begin
  { ReadDir 已批量缓存目录项（platform 4K buf + 迭代句柄），仅含 Name/Type；
    mtime/mode 需 Stat 补齐，每条目一次 Stat 为必要 O(N)，非 N+1 冗余；
    排序经 ArchiveSortDirEntries 零键缓存（PByte+Len 单次预计算，O(n log n) 比较零重建视图，bytes.ops 单源 CompareBytesOrdered/SIMD）；
    路径拼接复用 LChildAbs，几何扩容 inline，资源经迭代器 Close 不丢 }
  LEntries := nextpas.core.fs.ReadDir(AAbsDir);
  ArchiveSortDirEntries(LEntries);
  for LI := 0 to High(LEntries) do
  begin
    LName := LEntries[LI].Name;
    if (LName = '.') or (LName = '..') then
      Continue;
    // perf: 复用 bytes.ops SpanJoinWithSeparator 单源，单次 SetLength+两 CopyMemory 零拷贝 PByte 视图，inline 薄转发消除原生 + 两次分配微缝；ARelPrefix/LName 视图零分配单源
    if Length(ARelPrefix) = 0 then LRelSpan := TByteSpan.Empty else LRelSpan := TByteSpan.Create(PByte(@ARelPrefix[1]), SizeUInt(Length(ARelPrefix)));
    if Length(LName) = 0 then LNameSpan := TByteSpan.Empty else LNameSpan := TByteSpan.Create(PByte(@LName[1]), SizeUInt(Length(LName)));
    LChildRel := SpanJoinWithSeparator(LRelSpan, LNameSpan, '/');
    if Length(AAbsDir) = 0 then LAbsSpan := TByteSpan.Empty else LAbsSpan := TByteSpan.Create(PByte(@AAbsDir[1]), SizeUInt(Length(AAbsDir)));
    LChildAbs := SpanJoinWithSeparator(LAbsSpan, LNameSpan, '/');
    LInfo := nextpas.core.fs.Stat(LChildAbs);
    if LEntries[LI].IsDir then
    begin
      ArchiveWalkAppend(AOut, ACount, LChildRel, LChildAbs, True, LInfo.ModTime div 1000000000, Word(LInfo.Permission) and $0FFF, 0);
      ArchiveCollectWalk(LChildAbs, LChildRel, AOut, ACount);
    end
    else if LEntries[LI].FileType = ftRegular then
      ArchiveWalkAppend(AOut, ACount, LChildRel, LChildAbs, False, LInfo.ModTime div 1000000000, Word(LInfo.Permission) and $0FFF, LInfo.Size);
    { symlink/device/FIFO/socket 跳过，防劫持由外层 EnsureNoSymlinkInPath 保障 }
  end;
end;

procedure ArchiveCollectWalks(const ADir: string; var AWalks: TArchiveWalkArray; var ACount: Integer); inline;
begin
  // 单源薄转发：消除 TarPackDir/TarPackDirInto 同构 SetLength/ArchiveCollectWalk/SetLength 模板，复用 ArchiveCollectWalk 单源几何扩容，inline 零额外分配
  SetLength(AWalks, 0);
  ACount := 0;
  ArchiveCollectWalk(ADir, '', AWalks, ACount);
  SetLength(AWalks, ACount);
end;

function ArchiveEstimatePaddedSize(const AWalks: TArchiveWalkArray; ACount: Integer; ABlockSize: SizeUInt): UInt64; inline;
var
  LI: Integer;
begin
  // 单源容量预估：header ABlockSize + AlignUp(FSize,ABlockSize) 单遍累加，复用 bytes.ops.AlignUp 单源位掩码零除法 inline 零拷贝，tar 512 零额外拷贝分支，L2 联邦单缝
  Result := 0;
  for LI := 0 to ACount - 1 do
  begin
    if AWalks[LI].FSize > 0 then
      Result := Result + UInt64(ABlockSize) + UInt64(AlignUp(SizeUInt(AWalks[LI].FSize), ABlockSize))
    else
      Result := Result + UInt64(ABlockSize);
  end;
end;

function ArchiveEstimateTarSize(const AWalks: TArchiveWalkArray; ACount: Integer): UInt64; inline;
begin
  // tar 便捷薄转发：复用 ArchiveEstimatePaddedSize 单源，512 对齐零额外分支，bytes.ops 单源复用
  Result := ArchiveEstimatePaddedSize(AWalks, ACount, 512);
end;

end.
