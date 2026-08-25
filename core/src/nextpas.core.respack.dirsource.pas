unit nextpas.core.respack.dirsource;

{** @desc 目录 → 打包条目适配。本单元是 respack 唯一允许依赖 nextpas.core.fs 的
  地方（L2→L2 seam，registry 记录）。策略：仅收 ftRegular 文件；symlink 一律跳过；
  相对路径 '/' 分隔（Windows 宿主做分隔符归一）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base;

type
  { 返回 False 剔除该文件；APath 为相对包路径 }
  TResPackIncludeFunc = reference to function(
    const ARelativePath: string): Boolean;

{ 枚举目录树为打包条目；内容由本函数持有至返回，调用方应立即送入 ResPackBuild。
  超过 RESPACK_MAX_INPUT_BYTES raise EResPackTooLarge；遍历错误 raise
  EResPackDirSourceFailed。 }
function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc = nil): TResPackInputArray;

implementation

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
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
  if Ctx^.Total + SizeUInt(AInfo.Size) > RESPACK_MAX_INPUT_BYTES then
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
  Ctx^.Entries[Idx].ModTime := AInfo.ModTime div 1000000000;
  Ctx^.Total := Ctx^.Total + SizeUInt(AInfo.Size);
end;

function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc): TResPackInputArray;
var
  Ctx: TDirContext;
  RootClean: string;
begin
  Result := nil;
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
  Result := Ctx.Entries;
end;

end.
