unit nextpas.core.zip.fs;
{**
 * @desc ZIP 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 *
 * 打包：只收常规文件与目录；符号链接及非常规文件（设备/FIFO/socket）跳过；
 * 相对路径一律正斜杠，目录条目补尾随 '/'；条目 mtime 取文件 mtime，unix
 * 权限位随外部属性保留（S_IFREG/S_IFDIR | 低 12 位）；同目录内按名字节序
 * 排序，输出确定。
 * 解包：敌意条目名（zip-slip）在落盘前拒绝；重名条目按序后写覆盖；默认跳过
 * 符号链接条目，SkipSymlinks=False 时按归档保真创建真实符号链接（opt-in）；
 * 文件与目录的 mtime 尽力还原（DOS 时间 2 秒粒度）；unix 归档还原 posix 权限
 * 位。目录的权限与 mtime 延迟到全部内容写完后再还原（否则子条目写入会刷新
 * 目录 mtime，收紧的目录权限也可能阻断后续落盘）。
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
       SkipSymlinks 跳过符号链接条目；MaxOutputSize=0 取读端默认上限 *}
  TZipExtractOptions = record
  RestoreMode: Boolean;
  SkipSymlinks: Boolean;
  MaxOutputSize: SizeUInt;
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
  const AMaxOutputSize: SizeUInt = 0);

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

function SortWalkCompare(const AA, AB: string): Boolean; inline;
begin
  Result := AA > AB;
end;

procedure SortDirEntries(var A: TDirEntryArray);
var
  LI, LJ: Integer;
  LTmp: TDirEntry;
begin
  for LI := 1 to High(A) do
  begin
    LTmp := A[LI];
    LJ := LI - 1;
    while (LJ >= 0) and SortWalkCompare(A[LJ].Name, LTmp.Name) do
    begin
      A[LJ + 1] := A[LJ];
      Dec(LJ);
    end;
    A[LJ + 1] := LTmp;
  end;
end;

{ 深度优先收集子树：目录先于其内容，同层级按名字节序 }
procedure CollectLevel(const AAbsDir, ARelPrefix: string;
  var AOut: TWalkArray);
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
      SetLength(AOut, Length(AOut) + 1);
      AOut[High(AOut)].FRel := LChildRel;
      AOut[High(AOut)].FFull := LChildAbs;
      AOut[High(AOut)].FIsDir := True;
      AOut[High(AOut)].FMtime := LInfo.ModTime div 1000000000;
      AOut[High(AOut)].FMode :=
        ZipDirectoryMode(Word(LInfo.Permission) and $0FFF);
      CollectLevel(LChildAbs, LChildRel, AOut);
    end
    else if LEntries[LI].FileType = ftRegular then
    begin
      SetLength(AOut, Length(AOut) + 1);
      AOut[High(AOut)].FRel := LChildRel;
      AOut[High(AOut)].FFull := LChildAbs;
      AOut[High(AOut)].FIsDir := False;
      AOut[High(AOut)].FMtime := LInfo.ModTime div 1000000000;
      AOut[High(AOut)].FMode :=
        ZipRegularMode(Word(LInfo.Permission) and $0FFF);
    end;
    { 符号链接/设备/FIFO/socket 跳过，见单元头注释 }
  end;
end;

procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter);
var
  LRoot: TFileInfo;
  LWalks: TWalkArray;
  LI: Integer;
  LOpts: TZipAddOptions;
  LData: TBytes;
begin
  LRoot := Stat(ADir);
  if not LRoot.IsDir then
    raise EArgumentError.Create('zip pack: not a directory: ' + ADir);
  SetLength(LWalks, 0);
  CollectLevel(ADir, '', LWalks);
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
  LR := NewZipReaderWithOptions(AData, LOpts);
  MkdirAll(ADestDir, PermDirDefault);
  SetLength(LDirs, 0);
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
      MkdirAll(LParent, PermDirDefault);
    end;
    { 仅 unix 归档（高 16 位模式字非零）还原权限；其余保持平台默认。
      权限位 = 模式字低 12 位（含 setuid/sticky）。 }
    LMode := ZipUnixModeOf(LE);
    if LE.IsDirectory then
      MkdirAll(LFull, PermDirDefault)
    else if LE.IsSymlink then
    begin
      { opt-in 保真路径：条目载荷即链接目标文本 }
      LPayload := LR.ExtractToBytes(LI);
      if (Length(LPayload) = 0) or (Length(LPayload) > 4096) then
        raise EParseError.Create('zip extract: bad symlink target: ' + LE.Name);
      SetLength(LTarget, Length(LPayload));
      Move(LPayload[0], LTarget[1], Length(LPayload));
      Symlink(LTarget, LFull);
    end
    else
      WriteFile(LFull, LR.ExtractToBytes(LI), PermDefault);
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
  { 收尾逆序定稿目录：先深层后浅层，权限收紧不阻断兄弟/祖先处理 }
  for LI := High(LDirs) downto 0 do
  begin
    if AOptions.RestoreMode and (LDirs[LI].FMode <> 0) then
      Chmod(LDirs[LI].FFull,
        TFilePermission(LDirs[LI].FMode and $0FFF));
    Chtimes(LDirs[LI].FFull, LDirs[LI].FMtimeNs, LDirs[LI].FMtimeNs);
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

end.
