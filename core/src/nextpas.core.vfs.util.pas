unit nextpas.core.vfs.util;

{** @desc 基于 IVfs 的组合辅助：包级 Stat/List/ReadAll/Walk（Go io/fs 包函数同构）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

type
  { AStop 置 True 后遍历立即终止（含当前层） }
  TVfsVisitProc = reference to procedure(const APath: string;
    const AInfo: TEntryInfo; var AStop: Boolean);

function VfsStat(const AFs: IVfs; const APath: string): TStatInfo; inline;
function VfsList(const AFs: IVfs; const ADirPath: string): TEntryArray; inline;
function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes;
function VfsReadAllText(const AFs: IVfs; const APath: string): string;
{ 字典序确定性全树遍历（Go fs.WalkDir 对等物）：先访问 ARoot 自身再逐层深入 }
procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc);

implementation

function VfsStat(const AFs: IVfs; const APath: string): TStatInfo;
begin
  Result := AFs.Stat(APath);
end;

function VfsList(const AFs: IVfs; const ADirPath: string): TEntryArray;
begin
  Result := AFs.List(ADirPath);
end;

function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes;
var
  S: IStream;
  Total, Got: SizeUInt;
begin
  Result := nil;
  S := AFs.OpenRead(APath);
  SetLength(Result, S.Size);
  Total := 0;
  while Total < SizeUInt(S.Size) do
  begin
    if Total >= SizeUInt(Length(Result)) then Break;
    Got := S.Read(Result[Total], SizeUInt(Length(Result)) - Total);
    if Got = 0 then
      raise EVfsError.CreateCtx('read', APath,
        'stream ended before declared size');
    Total := Total + Got;
  end;
  S.Close;
end;

function VfsReadAllText(const AFs: IVfs; const APath: string): string;
var
  B: TBytes;
begin
  B := VfsReadAllBytes(AFs, APath);
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

procedure WalkLevel(const AFs: IVfs; const ADirPath: string;
  const AVisit: TVfsVisitProc; var AStop: Boolean);
var
  Entries: TEntryArray;
  I: SizeUInt;
begin
  if AStop then Exit;
  Entries := AFs.List(ADirPath);
  { Length 为 SizeUInt，空目录时 0-1 回绕 ⇒ 必须先判空 }
  if SizeUInt(Length(Entries)) = 0 then
    Exit;
  for I := 0 to SizeUInt(Length(Entries)) - 1 do
  begin
    if AStop then Exit;
    AVisit(Entries[I].Name, Entries[I], AStop);
    if AStop then Exit;
    if Entries[I].IsDir then
      WalkLevel(AFs, Entries[I].Name, AVisit, AStop);
  end;
end;

procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc);
var
  Root: TStatInfo;
  Stop: Boolean;
begin
  if not VfsValidPath(ARoot, True) then
    raise EVfsInvalidPath.CreateCtx('walk', ARoot, 'invalid virtual path');
  Stop := False;
  Root := AFs.Stat(ARoot);
  AVisit(Root.Info.Name, Root.Info, Stop);
  if (not Stop) and Root.Info.IsDir and (not VfsIsRoot(ARoot)) then
    WalkLevel(AFs, ARoot, AVisit, Stop)
  else if (not Stop) and Root.Info.IsDir then
    WalkLevel(AFs, '.', AVisit, Stop);
end;

end.
