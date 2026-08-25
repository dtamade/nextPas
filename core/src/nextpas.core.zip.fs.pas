unit nextpas.core.zip.fs;
{**
 * @desc ZIP 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 *
 * 打包：只收常规文件与目录；符号链接及非常规文件（设备/FIFO/socket）跳过；
 * 相对路径一律正斜杠，目录条目补尾随 '/'；条目 mtime 取文件 mtime；
 * 同目录内按名字节序排序，输出确定。
 * 解包：敌意条目名（zip-slip）在落盘前拒绝；重名条目按序后写覆盖；
 * 文件与目录 mtime 尽力还原（受 DOS 时间 2 秒粒度限制）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zip.base,
  nextpas.core.zip.writer,
  nextpas.core.zip.reader;

{** 递归打包 ADir 内容（不含 ADir 自身条目）追加到 AWriter。 *}
procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter);

{** ZipPackDirInto + Finish 的便捷封装。 *}
function ZipPackDir(const ADir: string): TBytes;

{** 解包归档字节到 ADestDir（不存在则创建）。AMaxOutputSize=0 取读端默认上限。 *}
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
  end;
  TWalkArray = array of TWalkEntry;

procedure SortDirEntries(var A: TDirEntryArray);
var
  LI, LJ: Integer;
  LTmp: TDirEntry;
begin
  for LI := 1 to High(A) do
  begin
    LTmp := A[LI];
    LJ := LI - 1;
    while (LJ >= 0) and (A[LJ].Name > LTmp.Name) do
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
    if LEntries[LI].IsDir then
    begin
      LInfo := Stat(LChildAbs);
      SetLength(AOut, Length(AOut) + 1);
      AOut[High(AOut)].FRel := LChildRel;
      AOut[High(AOut)].FFull := LChildAbs;
      AOut[High(AOut)].FIsDir := True;
      AOut[High(AOut)].FMtime := LInfo.ModTime;
      CollectLevel(LChildAbs, LChildRel, AOut);
    end
    else if LEntries[LI].FileType = ftRegular then
    begin
      LInfo := Stat(LChildAbs);
      SetLength(AOut, Length(AOut) + 1);
      AOut[High(AOut)].FRel := LChildRel;
      AOut[High(AOut)].FFull := LChildAbs;
      AOut[High(AOut)].FIsDir := False;
      AOut[High(AOut)].FMtime := LInfo.ModTime;
    end;
    { 符号链接/设备/FIFO/socket 跳过，见单元头注释 }
  end;
end;

procedure ZipPackDirInto(const ADir: string; const AWriter: IZipWriter);
var
  LRoot: TFileInfo;
  LWalks: TWalkArray;
  LI: Integer;
  LData: TBytes;
begin
  LRoot := Stat(ADir);
  if not LRoot.IsDir then
    raise EArgumentError.Create('zip pack: not a directory: ' + ADir);
  SetLength(LWalks, 0);
  CollectLevel(ADir, '', LWalks);
  for LI := 0 to High(LWalks) do
  begin
    if LWalks[LI].FIsDir then
      AWriter.AddDirectoryWithTime(LWalks[LI].FRel,
        LWalks[LI].FMtime div 1000000000)
    else
    begin
      LData := nil;
      LData := ReadFile(LWalks[LI].FFull);
      AWriter.AddEntryWithTime(LWalks[LI].FRel, LData,
        LWalks[LI].FMtime div 1000000000);
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

procedure ZipExtractToDir(const AData: TBytes; const ADestDir: string;
  const AMaxOutputSize: SizeUInt);
var
  LOpts: TZipReadOptions;
  LR: IZipReader;
  LI, LSep: Integer;
  LE: TZipEntryInfo;
  LFull, LParent: string;
  LNs: Int64;
begin
  LOpts.MaxOutputSize := AMaxOutputSize;
  LR := NewZipReaderWithOptions(AData, LOpts);
  MkdirAll(ADestDir, PermDirDefault);
  for LI := 0 to LR.EntryCount - 1 do
  begin
    LE := LR.Entry(LI);
    { 条目名来自不可信输入：落盘前强制 zip-slip 防护 }
    if not IsSafeZipEntryName(LE.Name) then
      raise EParseError.Create('zip extract: refusing unsafe entry name: ' +
        LE.Name);
    LFull := ADestDir;
    while (LFull <> '') and (LFull[Length(LFull)] = '/') do
      Delete(LFull, Length(LFull), 1);
    LFull := LFull + '/' + LE.Name;
    LSep := Length(LFull);
    while (LSep > 0) and (LFull[LSep] <> '/') do
      Dec(LSep);
    if LSep > 0 then
    begin
      LParent := Copy(LFull, 1, LSep - 1);
      MkdirAll(LParent, PermDirDefault);
    end;
    if LE.IsDirectory then
      MkdirAll(LFull, PermDirDefault)
    else
      WriteFile(LFull, LR.ExtractToBytes(LI), PermDefault);
    { 还原 mtime（DOS 时间 2 秒粒度；ns 换算不溢出 Int64） }
    LNs := LE.ModTimeUnixSec * 1000000000;
    Chtimes(LFull, LNs, LNs);
  end;
end;

end.
