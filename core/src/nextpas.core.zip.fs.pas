unit nextpas.core.zip.fs;
{**
 * @desc ZIP 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 *
 * 打包：只收常规文件与目录；符号链接及非常规文件（设备/FIFO/socket）跳过；
 * 相对路径一律正斜杠，目录条目补尾随 '/'；条目 mtime 取文件 mtime，unix
 * 权限位随外部属性保留（S_IFREG/S_IFDIR | 低 12 位）；同目录内按名字节序
 * 排序，输出确定。
 * 解包：敌意条目名（zip-slip）在落盘前拒绝；重名条目按序后写覆盖；默认跳过
 * 符号链接条目，SkipSymlinks=False 时按归档保真创建真实符号链接（opt-in，
 * 目标经 IsSafeSymlinkTarget 拒绝绝对路径/".."/空段/反斜杠/超长4096）；
 * 文件与目录的 mtime 尽力还原（DOS 时间 2 秒粒度）；unix 归档还原 posix 权限
 * 位。目录的权限与 mtime 延迟到全部内容写完后再还原（否则子条目写入会刷新
 * 目录 mtime，收紧的目录权限也可能阻断后续落盘）。解包非原子：已落盘文件不
 * 回滚；异常时已收集的 LDirs 仍在 finally 中逆序定稿（权限/mtime），需外层
 * 整体清理或改用原子变体 `ZipExtractToDirAtomic*`（临时目录+rename，见下）。
 * TOCTOU 已加固为落盘前/后双重 EnsureNoSymlinkInPath + 落盘结果非 symlink
 * 校验；原子变体在同文件系统内 `TempDir`+`Rename` 原子提交，异常时自动清理
 * 临时目录，已存在目标则拒绝覆盖以保原子语义。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zip.base,
  nextpas.core.zip.writer,
  nextpas.core.zip.reader;

type
  {** @desc 解包选项：RestoreMode 还原归档内 posix 权限位（仅 unix 归档）；
       SkipSymlinks 跳过符号链接条目；MaxOutputSize=0 取读端默认上限；
       MaxTotalOutputSize 为跨条目总输出上限，0=不限 *}
  TZipExtractOptions = record
  RestoreMode: Boolean;
  SkipSymlinks: Boolean;
  MaxOutputSize: SizeUInt;
  MaxTotalOutputSize: UInt64;
end;

{** 递归打包 ADir 内容（不含 ADir 自身条目）追加到 AWriter。 *}
procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter);

{** ZipPackDirInto + Finish 的便捷封装。 *}
function ZipPackDir(const ADir: string): TBytes;

{** 默认解包选项。 *}
function DefaultZipExtractOptions: TZipExtractOptions; inline;

{** 解包归档字节到 ADestDir（不存在则创建），带完整选项。 *}
procedure ZipExtractToDirWithOptions(const AData: TBytes; const ADestDir: string;
  const AOptions: TZipExtractOptions);

{** 同上，按默认选项。AMaxOutputSize=0 取读端默认上限。 *}
procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt = 0); overload;
{** 同上，按完整选项（保留 MaxTotalOutputSize/SkipSymlinks 语义）。 *}
procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AOptions: TZipExtractOptions); overload;

{** 原子解包：先解到同文件系统临时目录，成功后 Rename 原子提交；
    ADestDir 已存在则拒绝覆盖（抛 EArgumentError），异常时自动清理临时目录。
    其余语义同 ZipExtractToDirWithOptions（含 TOCTOU 双校验与 MaxTotal 守卫）。 *}
procedure ZipExtractToDirAtomicWithOptions(const AData: TBytes;
  const ADestDir: string; const AOptions: TZipExtractOptions);

{** 同上，按默认选项。AMaxOutputSize=0 取读端默认上限。 *}
procedure ZipExtractToDirAtomic(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt = 0); overload;
{** 同上，按完整选项。 *}
procedure ZipExtractToDirAtomic(const AData: TBytes; const ADestDir: string;
  const AOptions: TZipExtractOptions); overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs;

type
  TWalkEntry = record
    FRel: string;      { 相对路径，正斜杠 }
    FFull: string;
    FIsDir: Boolean;
    FMtime: Int64;
    FMode: Word;       { unix 模式字（S_IFREG/S_IFDIR | 权限位） }
  end;
  TWalkArray = array of TWalkEntry;

  { 延迟定稿的目录条目：内容全部落盘后再还原权限与 mtime }
  TDeferredDir = record
    FFull: string;
    FMode: Word;       { unix 模式字；0 = 非 unix 归档，不还原权限 }
    FMtimeNs: Int64;
  end;
  TDeferredDirArray = array of TDeferredDir;

function IsSafeSymlinkTarget(const ATarget: string): Boolean; inline;
var
  LI, LSegStart: Integer;
begin
  Result := False;
  if (ATarget = '') or (Length(ATarget) > 4096) then Exit;
  if (ATarget[1] = '/') or (ATarget[1] = '\') then Exit;
  if (Length(ATarget) >= 2) and (ATarget[2] = ':') and (UpCase(ATarget[1]) in ['A'..'Z']) then Exit;
  if Pos('\', ATarget) > 0 then Exit;
  LSegStart := 1;
  for LI := 1 to Length(ATarget) + 1 do
  begin
    if (LI <= Length(ATarget)) and (ATarget[LI] <> '/') then Continue;
    if LI - LSegStart = 0 then
    begin
      if LI <= Length(ATarget) then Exit;
    end
    else if (LI - LSegStart = 2) and (ATarget[LSegStart] = '.') and (ATarget[LSegStart + 1] = '.') then
      Exit;
    LSegStart := LI + 1;
  end;
  Result := True;
end;

procedure EnsureNoSymlinkInPath(const APath: string); inline;
var
  LI: Integer;
  LPrefix: string;
begin
  if APath = '' then Exit;
  for LI := 1 to Length(APath) do
  begin
    if (APath[LI] = '/') or (LI = Length(APath)) then
    begin
      if LI = Length(APath) then
        LPrefix := APath
      else
        LPrefix := Copy(APath, 1, LI - 1);
      if (LPrefix <> '') and IsSymlink(LPrefix) then
        raise EParseError.Create('zip extract: symlink in path: ' + LPrefix);
    end;
  end;
end;

procedure EnsureWalkCapacity(var A: TWalkArray; AMin: Integer); inline;
var
  LCap, LNew: Integer;
begin
  LCap := Length(A);
  if LCap >= AMin then Exit;
  if LCap = 0 then LCap := 16;
  LNew := LCap;
  while LNew < AMin do
    LNew := LNew * 2;
  SetLength(A, LNew);
end;

procedure WalkAppend(var A: TWalkArray; var ACount: Integer;
  const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word); inline;
begin
  EnsureWalkCapacity(A, ACount + 1);
  A[ACount].FRel := ARel;
  A[ACount].FFull := AFull;
  A[ACount].FIsDir := AIsDir;
  A[ACount].FMtime := AMtime;
  A[ACount].FMode := AMode;
  Inc(ACount);
end;

procedure SortDirEntries(var A: TDirEntryArray);
var
  LStackLo, LStackHi: array[0..63] of Integer;
  LSp, LLo, LHi, LI, LJ: Integer;
  LPivot: string;
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
    LPivot := A[(LLo + LHi) shr 1].Name;
    repeat
      while A[LI].Name < LPivot do Inc(LI);
      while A[LJ].Name > LPivot do Dec(LJ);
      if LI <= LJ then
      begin
        LTmp := A[LI];
        A[LI] := A[LJ];
        A[LJ] := LTmp;
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

{ 深度优先收集子树：目录先于其内容，同层级按名字节序 }
procedure CollectLevel(const AAbsDir, ARelPrefix: string;
  var AOut: TWalkArray; var ACount: Integer);
var
  LEntries: TDirEntryArray;
  LI: Integer;
  LName, LChildAbs, LChildRel: string;
  LInfo: TFileInfo;
begin
  LEntries := ReadDir(AAbsDir);
  SortDirEntries(LEntries);
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
      WalkAppend(AOut, ACount, LChildRel, LChildAbs, True,
        LInfo.ModTime div 1000000000,
        ZipDirectoryMode(Word(LInfo.Permission) and $0FFF));
      CollectLevel(LChildAbs, LChildRel, AOut, ACount);
    end
    else if LEntries[LI].FileType = ftRegular then
    begin
      WalkAppend(AOut, ACount, LChildRel, LChildAbs, False,
        LInfo.ModTime div 1000000000,
        ZipRegularMode(Word(LInfo.Permission) and $0FFF));
    end;
    { 符号链接/设备/FIFO/socket 跳过，见单元头注释 }
  end;
end;

procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter);
var
  LRoot: TFileInfo;
  LWalks: TWalkArray;
  LI, LWalksCount: Integer;
  LOpts: TZipAddOptions;
  LData: TBytes;
begin
  LRoot := Stat(ADir);
  if not LRoot.IsDir then
    raise EArgumentError.Create('zip pack: not a directory: ' + ADir);
  SetLength(LWalks, 0);
  LWalksCount := 0;
  CollectLevel(ADir, '', LWalks, LWalksCount);
  SetLength(LWalks, LWalksCount);
  for LI := 0 to High(LWalks) do
  begin
    LOpts := DefaultZipAddOptions;
    LOpts.ModTimeUnixSec := LWalks[LI].FMtime;
    LOpts.Mode := LWalks[LI].FMode;
    if LWalks[LI].FIsDir then
      AWriter.AddEntryWithOptions(LWalks[LI].FRel + '/', nil, LOpts)
    else
    begin
      LData := nil;
      LData := ReadFile(LWalks[LI].FFull);
      AWriter.AddEntryWithOptions(LWalks[LI].FRel, LData, LOpts);
    end;
  end;
end;

function ZipPackDir(const ADir: string): TBytes;
var
  LW: IZipWriter;
begin
  LW := NewZipWriter;
  ZipPackDirInto(ADir, LW);
  Result := LW.Finish;
end;

function DefaultZipExtractOptions: TZipExtractOptions;
begin
  Result.RestoreMode := True;
  Result.SkipSymlinks := True;
  Result.MaxOutputSize := 0;
  Result.MaxTotalOutputSize := 0;
end;

procedure ZipExtractToDirWithOptions(const AData: TBytes;
  const ADestDir: string; const AOptions: TZipExtractOptions);
var
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LI, LSep: Integer;
  LE: TZipEntryInfo;
  LFull, LParent, LTarget: string;
  LNs: Int64;
  LMode: Word;
  LPayload: TBytes;
  LDirs: TDeferredDirArray;
begin
  LOpts.MaxOutputSize := AOptions.MaxOutputSize;
  LOpts.MaxTotalOutputSize := AOptions.MaxTotalOutputSize;
  LR := NewZipReaderWithOptions(AData, LOpts);
  EnsureNoSymlinkInPath(ADestDir);
  MkdirAll(ADestDir, PermDirDefault);
  EnsureNoSymlinkInPath(ADestDir);
  SetLength(LDirs, 0);
  try
  for LI := 0 to LR.EntryCount - 1 do
  begin
    LE := LR.Entry(LI);
    { 条目名来自不可信输入：落盘前强制 zip-slip 防护 }
    if not IsSafeZipEntryName(LE.Name) then
      raise EParseError.Create('zip extract: refusing unsafe entry name: ' +
        LE.Name);
    { 符号链接条目默认跳过：归档内容不可信，链接目标可指向任意路径形成
      后续劫持；显式 SkipSymlinks=False 时按归档保真创建真实符号链接 }
    if LE.IsSymlink and AOptions.SkipSymlinks then
      Continue;
    LFull := ADestDir;
    while (LFull <> '') and (LFull[Length(LFull)] = '/') do
      Delete(LFull, Length(LFull), 1);
    LFull := LFull + '/' + LE.Name;
    { 目录条目名可能不带尾随 '/'（依赖外部属性判定的归档） }
    while (LFull <> '') and (LFull[Length(LFull)] = '/') do
      Delete(LFull, Length(LFull), 1);
    LSep := Length(LFull);
    while (LSep > 0) and (LFull[LSep] <> '/') do
      Dec(LSep);
    if LSep > 0 then
    begin
      LParent := Copy(LFull, 1, LSep - 1);
      EnsureNoSymlinkInPath(LParent);
      MkdirAll(LParent, PermDirDefault);
      EnsureNoSymlinkInPath(LParent);
    end;
    { 仅 unix 归档（高 16 位模式字非零）还原权限；其余保持平台默认。
      权限位 = 模式字低 12 位（含 setuid/sticky）。 }
    LMode := ZipUnixModeOf(LE);
    if LE.IsDirectory then
    begin
      MkdirAll(LFull, PermDirDefault);
      EnsureNoSymlinkInPath(LFull);
    end
    else if LE.IsSymlink then
    begin
      { opt-in 保真路径：条目载荷即链接目标文本，二次校验防绝对/..穿越 }
      LPayload := LR.ExtractToBytes(LI);
      if (Length(LPayload) = 0) or (Length(LPayload) > 4096) then
        raise EParseError.Create('zip extract: bad symlink target: ' + LE.Name);
      SetString(LTarget, PAnsiChar(@LPayload[0]), Length(LPayload));
      if not IsSafeSymlinkTarget(LTarget) then
        raise EParseError.Create('zip extract: refusing unsafe symlink target: ' + LE.Name + ' -> ' + LTarget);
      EnsureNoSymlinkInPath(LParent);
      Symlink(LTarget, LFull);
      EnsureNoSymlinkInPath(LParent);
    end
    else
    begin
      WriteFile(LFull, LR.ExtractToBytes(LI), PermDefault);
      { TOCTOU 加固：落盘后二次校验父路径仍无 symlink 穿透，且落盘结果非 symlink }
      EnsureNoSymlinkInPath(LParent);
      if IsSymlink(LFull) then
        raise EParseError.Create('zip extract: symlink in path after write: ' + LFull);
    end;
    if not LE.IsSymlink then
    begin
      if LE.IsDirectory then
      begin
        SetLength(LDirs, Length(LDirs) + 1);
        LDirs[High(LDirs)].FFull := LFull;
        LDirs[High(LDirs)].FMode := LMode;
        LDirs[High(LDirs)].FMtimeNs := LE.ModTimeUnixSec * 1000000000;
      end
      else
      begin
        if AOptions.RestoreMode and (LMode <> 0) then
          Chmod(LFull, TFilePermission(LMode and $0FFF));
        { 文件内容已定稿：mtime 可立即还原（2 秒粒度） }
        LNs := LE.ModTimeUnixSec * 1000000000;
        Chtimes(LFull, LNs, LNs);
      end;
    end;
  end;
  finally
    { 收尾逆序定稿目录：先深层后浅层，权限收紧不阻断兄弟/祖先处理；
      置于 finally 保证异常时已收集的目录仍定稿（非原子语义，见单元头）。 }
    for LI := High(LDirs) downto 0 do
    begin
      if AOptions.RestoreMode and (LDirs[LI].FMode <> 0) then
        try
          Chmod(LDirs[LI].FFull,
            TFilePermission(LDirs[LI].FMode and $0FFF));
        except
          on E: Exception do ;
        end;
      try
        Chtimes(LDirs[LI].FFull, LDirs[LI].FMtimeNs, LDirs[LI].FMtimeNs);
      except
        on E: Exception do ;
      end;
    end;
  end;
end;

procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt);
var
  LOpts: TZipExtractOptions;
begin
  LOpts := DefaultZipExtractOptions;
  LOpts.MaxOutputSize := AMaxOutputSize;
  ZipExtractToDirWithOptions(AData, ADestDir, LOpts);
end;

procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AOptions: TZipExtractOptions);
begin
  ZipExtractToDirWithOptions(AData, ADestDir, AOptions);
end;

procedure ZipExtractToDirAtomicWithOptions(const AData: TBytes;
  const ADestDir: string; const AOptions: TZipExtractOptions);
var
  LDestTrim, LParent, LTemp: string;
  LSep: Integer;
begin
  if ADestDir = '' then
    raise EArgumentError.Create('zip extract atomic: empty dest dir');
  LDestTrim := ADestDir;
  while (LDestTrim <> '') and (LDestTrim[Length(LDestTrim)] = '/') do
    Delete(LDestTrim, Length(LDestTrim), 1);
  if LDestTrim = '' then
    raise EArgumentError.Create('zip extract atomic: empty dest dir');
  LSep := Length(LDestTrim);
  while (LSep > 0) and (LDestTrim[LSep] <> '/') do
    Dec(LSep);
  if LSep > 0 then
    LParent := Copy(LDestTrim, 1, LSep - 1)
  else
    LParent := '.';
  if LParent = '' then
    LParent := '.';
  EnsureNoSymlinkInPath(LParent);
  if Exists(LDestTrim) then
    raise EArgumentError.Create('zip extract atomic: destination already exists: ' + LDestTrim);
  { 同文件系统临时目录：sibling + 16hex 随机，FsTempDir 保证唯一与 32 次重试 }
  LTemp := TempDir(LParent, '.zip-atomic-');
  try
    ZipExtractToDirWithOptions(AData, LTemp, AOptions);
    EnsureNoSymlinkInPath(LParent);
    if Exists(LDestTrim) then
      raise EArgumentError.Create('zip extract atomic: destination appeared during extract: ' + LDestTrim);
    Rename(LTemp, LDestTrim);
    LTemp := '';
  finally
    if (LTemp <> '') and Exists(LTemp) then
      try
        RemoveAll(LTemp);
      except
        on E: Exception do ;
      end;
  end;
end;

procedure ZipExtractToDirAtomic(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt);
var
  LOpts: TZipExtractOptions;
begin
  LOpts := DefaultZipExtractOptions;
  LOpts.MaxOutputSize := AMaxOutputSize;
  ZipExtractToDirAtomicWithOptions(AData, ADestDir, LOpts);
end;

procedure ZipExtractToDirAtomic(const AData: TBytes; const ADestDir: string;
  const AOptions: TZipExtractOptions);
begin
  ZipExtractToDirAtomicWithOptions(AData, ADestDir, AOptions);
end;

end.
