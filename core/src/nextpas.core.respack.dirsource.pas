unit nextpas.core.respack.dirsource;

{** @desc 目录 → 打包条目适配。本单元是 respack 唯一允许依赖 nextpas.core.fs 的
  地方（L2→L2 seam，registry 记录）。策略：仅收 ftRegular 文件；symlink 一律跳过；
  相对路径 '/' 分隔（Windows 宿主做分隔符归一）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base;

type
  { 返回 False 剔除该文件；APath 为相对包路径 }
  TResPackIncludeFunc = reference to function(
    const ARelativePath: string): Boolean;

  { 目录枚举产物。Contents 是 Entries[].Data 的生命期锚点：两字段为托管
    数组、整体按值返回，调用方持有 bundle 期间内容缓冲保证存活；送入
    ResPackBuild 后即可丢弃。S4 修复：此前锚点是函数局部变量，返回即释放，
    调用方拿到悬垂 Data 指针（gate 靠分配器运气通过）。 }
  TResPackDirEntries = record
    Entries: TResPackInputArray;
    Contents: array of TBytes;
  end;

{ 枚举目录树为打包条目。超过 RESPACK_MAX_INPUT_BYTES raise EResPackTooLarge；
  遍历错误 raise EResPackDirSourceFailed。 }
function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc = nil): TResPackDirEntries;

{** 解包 blob 全部条目到 ADestDir（include_dir extract 对等物，调试/迁移用）。
  目录不存在则创建（含中间层）；同名已存在文件直接覆盖；不恢复 mtime（v1）。
  条目路径经 reader 的 FORMAT.md 校验且为 unrooted 无 '..' 形态，不存在越界
  写出。打开失败按 reader 错误族抛出。 }
procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string);

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.respack.reader,
  nextpas.core.respack.writer;

type
  PDirContext = ^TDirContext;
  TDirContext = record
    RootPrefixLen: Integer;
    Include: TResPackIncludeFunc;
    Entries: TResPackInputArray;
    Bytes: array of TBytes;   { 内容生命期锚点 }
    Total: SizeUInt;
    Failed: Boolean;
    FailMsg: string;
  end;

function Relativize(const ACtx: TDirContext; const AFullPath: string): string;
var
  S: string;
begin
  S := Copy(AFullPath, ACtx.RootPrefixLen + 1, MaxInt);
  while (Length(S) > 0) and (S[1] = '/') do
    Delete(S, 1, 1);
{$IFDEF WINDOWS}
  while Pos('\', S) > 0 do
    S[Pos('\', S)] := '/';
{$ENDIF}
  Result := S;
end;

function WalkProc(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  Ctx: PDirContext;
  Rel: string;
  Idx: SizeUInt;
  St: TFileInfo;
begin
  Result := True;
  Ctx := PDirContext(AUserData);
  if AErr <> nil then
  begin
    Ctx^.Failed := True;
    Ctx^.FailMsg := AErr.Message;
    Exit(False);
  end;
  if AInfo.FileType <> ftRegular then
    Exit(True);   { symlink/目录/特殊文件不入包 }
  Rel := Relativize(Ctx^, APath);
  if not ResPackValidPath(Rel, True) then
    Exit(True);   { 无法成名的宿主产物跳过，不污染包 }
  if (Ctx^.Include <> nil) and (not Ctx^.Include(Rel)) then
    Exit(True);
  { walk 回调的 TFileInfo 不携带 Size/ModTime（fs.dir BuildWalkInfo 现状），
    而两者都是打包元数据：Size 支撑 INV-R10 上限、ModTime 进条目供 HTTP 条件
    请求使用。seam 单元内显式补一次 Stat。 }
  St := Stat(APath);
  if Ctx^.Total + SizeUInt(St.Size) > RESPACK_MAX_INPUT_BYTES then
  begin
    Ctx^.Failed := True;
    Ctx^.FailMsg := 'total input exceeds limit';
    Exit(False);
  end;
  Idx := SizeUInt(Length(Ctx^.Entries));
  SetLength(Ctx^.Entries, Idx + 1);
  SetLength(Ctx^.Bytes, Idx + 1);
  Ctx^.Bytes[Idx] := ReadFile(APath);
  Ctx^.Entries[Idx].Path := Rel;
  Ctx^.Entries[Idx].Data := Pointer(Ctx^.Bytes[Idx]);
  Ctx^.Entries[Idx].DataSize := SizeUInt(Length(Ctx^.Bytes[Idx]));
  Ctx^.Entries[Idx].ModTime := St.ModTime div 1000000000;
  Ctx^.Total := Ctx^.Total + SizeUInt(St.Size);
end;

function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc): TResPackDirEntries;
var
  Ctx: TDirContext;
  RootClean: string;
begin
  Result.Entries := nil;
  Result.Contents := nil;
  RootClean := ARoot;
  while (Length(RootClean) > 1)
    and ((RootClean[Length(RootClean)] = '/')
      or (RootClean[Length(RootClean)] = '\')) do
    Delete(RootClean, Length(RootClean), 1);
  if (not Exists(RootClean)) or (not IsDir(RootClean)) then
    raise EResPackDirSourceFailed.Create('respack.dirsource: not a directory "'
      + ARoot + '"');

  Ctx.RootPrefixLen := Length(RootClean);
  Ctx.Include := AInclude;
  Ctx.Entries := nil;
  Ctx.Bytes := nil;
  Ctx.Total := 0;
  Ctx.Failed := False;
  Ctx.FailMsg := '';
  WalkEx(RootClean, @WalkProc, @Ctx);
  if Ctx.Failed then
    raise EResPackDirSourceFailed.Create('respack.dirsource: ' + Ctx.FailMsg);
  Result.Entries := Ctx.Entries;
  Result.Contents := Ctx.Bytes;   { 锚点随 bundle 逃逸，生命期与 Entries 绑定 }
end;

procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string);
var
  RP: TResPack;
  Idx: SizeUInt;
  Entry: TResPackEntry;
  DestPath, ParentDir: string;
  Content: TBytes;
begin
  if ABlob.Data = nil then
    raise EResPackCorrupted.CreateStep(1, 'extract: blob is nil');
  RP := TResPack.Open(ABlob.Data, ABlob.Size);
  try
    MkdirAll(ADestDir);
    if RP.Count > 0 then
      for Idx := 0 to RP.Count - 1 do
      begin
        Entry := RP.EntryAt(Idx);
        DestPath := ADestDir + '/' + RP.PathOf(Entry);
        { 条目可带子目录层级，先确保父目录存在 }
        ParentDir := DestPath;
        while (Length(ParentDir) > 0)
          and (ParentDir[Length(ParentDir)] <> '/') do
          Delete(ParentDir, Length(ParentDir), 1);
        SetLength(ParentDir, Length(ParentDir) - 1);   { 去掉尾部 '/' }
        MkdirAll(ParentDir);
        SetLength(Content, SizeInt(Entry.Size));
        if Entry.Size > 0 then
          Move(RP.ContentPtr(Entry)^, Content[0], SizeUInt(Entry.Size));
        WriteFile(DestPath, Content);
      end;
  finally
    RP.Close;
  end;
end;

end.
