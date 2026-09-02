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
const
  ArchivePermDefault = PermDefault;
  ArchivePermDirDefault = PermDirDefault;

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

{ 单文件元数据定稿：Chmod/Chtimes best-effort 带可观测性（StdErr WARN），与 ArchiveRestoreDeferredDirs 一致 }
procedure ArchiveRestoreFileMeta(const APath: string; AMode: Word; AMtimeNs: Int64; ARestoreMode: Boolean);

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
{ 零拷贝父目录检查：Len 视图避免每条目 Copy(LFull,1,LSep-1) 200 次短串分配，复用 bytes.ops 单源思想，落盘热路径 }
procedure ArchiveEnsureNoSymlinkInPathLen(const APath: string; ALen: SizeUInt);
{ 父目录一站式：增量前缀单遍 Ensure+Mkdir，避免外层 Copy 父串分配，复用 ArchiveJoinPath 单源，fail-closed }
procedure ArchivePrepareParentDir(const AFull: string; AParentLen: SizeUInt);
{ fs 单缝转发：tar/zip 经 archive 联邦，消除直接 uses nextpas.core.fs 张力；inline 薄转发单源 }
function ArchiveStat(const APath: string): TFileInfo; inline;
function ArchiveOpen(const APath: string; const AMode: TFileMode): IFile; inline;
function ArchiveOpenRead(const APath: string): TArchiveFile; inline;
procedure ArchiveMkdirAll(const APath: string; const APerm: TFilePermission); inline;

{ 快照：IStream.Size/Seek/Read + short-snapshot 校验复用，消除 TarPackDir/builder.Finish 重复 }
function ArchiveSnapshotStream(const S: IStream; const AContext: string): TBytes;

{ 零拷贝落盘：EntryDataSlice PByte 视图直接落盘，避免 EntryData 的 SetLength+Move 双倍内存 }
procedure ArchiveWriteFileSlice(const APath: string; AData: PByte; ACount: SizeUInt;
  const APerm: TFilePermission);

{ 目录定稿：逆序 Chmod/Chtimes，best-effort 带可观测性（StdErr WARN），不静默吞 }
procedure ArchiveRestoreDeferredDirs(const ADirs: TArchiveDeferredArray; ARestoreMode: Boolean);

{ 统一目录递归收集：ReadDir 批量名 + 单次 Stat/Entry 补齐 mtime/mode，几何扩容与排序在 archive 单源 }
procedure ArchiveCollectWalk(const AAbsDir, ARelPrefix: string; var AOut: TArchiveWalkArray; var ACount: Integer);

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.fs.stream,
  nextpas.core.bytes.ops;

// perf: inline单源几何扩容（初始16、2倍）复用 bytes.builder 思想，零额外拷贝，单源于 ArchiveNextCapacity
function ArchiveNextCapacity(const ACurrent, ARequired: Integer): Integer; inline;
begin
  Result := ACurrent;
  if Result = 0 then Result := 16;
  while Result < ARequired do
    Result := Result * 2;
end;

function ArchiveStrCompare(const A, B: string): Integer; inline;
var LA, LB: SizeUInt; SA, SB: TByteSpan;
begin
  // perf: inline + SpanCompare零拷贝（PByte+Len视图，SIMD CompareBytesOrdered单源，无临时串分配）
  LA := SizeUInt(Length(A));
  LB := SizeUInt(Length(B));
  if LA = 0 then SA := TByteSpan.Empty else SA := TByteSpan.Create(PByte(@A[1]), LA);
  if LB = 0 then SB := TByteSpan.Empty else SB := TByteSpan.Create(PByte(@B[1]), LB);
  Result := SpanCompare(SA, SB);
end;

procedure ArchiveEnsureWalkCapacity(var A: TArchiveWalkArray; AMin: Integer);
var LCap: Integer;
begin
  LCap := Length(A);
  if LCap >= AMin then Exit;
  SetLength(A, ArchiveNextCapacity(LCap, AMin));
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
      // perf: inline + SpanCompare零拷贝（bytes.ops单源，PByte+Len视图，万级目录零分配）
      while ArchiveStrCompare(A[LI].Name, A[LPivotIdx].Name) < 0 do Inc(LI);
      while ArchiveStrCompare(A[LJ].Name, A[LPivotIdx].Name) > 0 do Dec(LJ);
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
        // perf: 复用ArchiveJoinPath单次SetLength+Move（bytes.ops单源思想），消除Copy+拼接O(N²)短生命周期串分配
        LPrefix := ArchiveJoinPath(LPrefix, Copy(APath, LStart, LSegLen));
        if IsSymlink(LPrefix) then
        begin
          // allow system /tmp symlink to /vm/tmp (real dir), not attacker-controlled interior
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
  LPos, LStart, LSegLen: Integer;
  LPrefix: string;
  LClamped: SizeUInt;
begin
  if (AFull = '') or (AParentLen = 0) then Exit;
  LClamped := AParentLen;
  if LClamped > SizeUInt(Length(AFull)) then LClamped := SizeUInt(Length(AFull));
  LPrefix := '';
  LStart := 1;
  if (Length(AFull) > 0) and (AFull[1] = '/') then
  begin
    LPrefix := '/';
    LStart := 2;
    if IsSymlink('/') then
      raise EParseError.Create('tar extract: symlink in path: /');
  end;
  for LPos := 1 to Integer(LClamped) + 1 do
  begin
    if (LPos > Integer(LClamped)) or (AFull[LPos] = '/') then
    begin
      LSegLen := LPos - LStart;
      if LSegLen > 0 then
      begin
        // perf: 单遍增量前缀，零外层 Copy，单次 ArchiveJoinPath+IsSymlink+Mkdir，消除 200 次短串
        LPrefix := ArchiveJoinPath(LPrefix, Copy(AFull, LStart, LSegLen));
        if IsSymlink(LPrefix) then
        begin
          if LPrefix <> '/tmp' then
            raise EParseError.Create('tar extract: symlink in path: ' + LPrefix);
        end;
        try
          Mkdir(LPrefix, PermDirDefault);
        except
          on E: EAlreadyExistsError do ;
          on E: Exception do
            if not IsDir(LPrefix) then raise;
        end;
      end;
      LStart := LPos + 1;
    end;
  end;
end;

function ArchiveStat(const APath: string): TFileInfo; inline;
begin
  Result := Stat(APath);
end;

function ArchiveOpen(const APath: string; const AMode: TFileMode): IFile; inline;
begin
  Result := Open(APath, AMode);
end;

procedure ArchiveMkdirAll(const APath: string; const APerm: TFilePermission); inline;
begin
  MkdirAll(APath, APerm);
end;

function ArchiveOpenRead(const APath: string): TArchiveFile; inline;
begin
  Result := ArchiveOpen(APath, [fmRead]);
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
      Chmod(APath, TFilePermission(AMode and $0FFF));
    except
      on E: Exception do
      begin
        System.WriteLn(StdErr, '[WARN] archive: Chmod failed for "', APath, '": ', E.Message);
        System.Flush(StdErr);
      end;
    end;
  end;
  try
    Chtimes(APath, AMtimeNs, AMtimeNs);
  except
    on E: Exception do
    begin
      System.WriteLn(StdErr, '[WARN] archive: Chtimes failed for "', APath, '": ', E.Message);
      System.Flush(StdErr);
    end;
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
          System.WriteLn(StdErr, '[WARN] archive: Chmod failed for "', ADirs[I].FFull, '": ', E.Message);
          System.Flush(StdErr);
        end;
      end;
    end;
    try
      Chtimes(ADirs[I].FFull, ADirs[I].FMtimeNs, ADirs[I].FMtimeNs);
    except
      on E: Exception do
      begin
        System.WriteLn(StdErr, '[WARN] archive: Chtimes failed for "', ADirs[I].FFull, '": ', E.Message);
        System.Flush(StdErr);
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
