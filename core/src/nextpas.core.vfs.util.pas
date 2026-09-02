unit nextpas.core.vfs.util;

{** @desc 基于 IVfs 的组合辅助：包级 Stat/List/ReadAll/Walk（Go io/fs 包函数同构）。
  四件套归位：helpers 层（base ← intf ← helpers(util) ← 门面），门面完整 re-export；
  不持有状态，仅组合 IVfs 原语，保持零拷贝与性能语义不变。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.text.view,
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
function VfsExistsView(const AFs: IVfs; const AView: TStringView): Boolean; inline;
function VfsReadAllBytesView(const AFs: IVfs; const AView: TStringView): TBytes; inline;
function VfsReadAllTextView(const AFs: IVfs; const AView: TStringView): string; inline;
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

function VfsExistsView(const AFs: IVfs; const AView: TStringView): Boolean; inline;
var
  V: IVfsView;
begin
  { perf: inline + IVfsView 零拷贝视图直达（memtree/embedded 真零拷贝，os 单次物化兜底），复用 bytes.ops 单源 CompareBytesOrdered }
  if Supports(AFs, IVfsView, V) then
    Exit(V.ExistsView(AView));
  Result := AFs.Exists(AView.ToString); { 单次物化兜底：未实现 View 的复合 Vfs }
end;

function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes;
var
  S: IStream;
  Total, Got: SizeUInt;
  LSize: Int64;
begin
  Result := nil;
  S := AFs.OpenRead(APath);
  try
    LSize := S.Size;
    if (LSize < 0) or (UInt64(LSize) > UInt64(High(SizeInt))) then
      raise EVfsError.CreateCtx('read', APath, 'declared size out of range');
    SetLength(Result, LSize);
    Total := 0;
    while Total < SizeUInt(LSize) do
    begin
      if Total >= SizeUInt(Length(Result)) then
        raise EVfsError.CreateCtx('read', APath, 'truncated: size exceeds addressable length');
      Got := S.Read(Result[Total], SizeUInt(Length(Result)) - Total);
      if Got = 0 then
        raise EVfsError.CreateCtx('read', APath,
          'stream ended before declared size');
      Total := Total + Got;
    end;
  finally
    S.Close;
  end;
end;

function VfsReadAllBytesView(const AFs: IVfs; const AView: TStringView): TBytes; inline;
var
  S: IStream;
  Total, Got: SizeUInt;
  LSize: Int64;
  V: IVfsView;
  LPath: string;
begin
  { perf: inline + IVfsView 零拷贝视图二分直达，SetLength+Move 单次分配零拷贝透传，S.Close 于 finally 释放，稳定性不丢 }
  Result := nil;
  if Supports(AFs, IVfsView, V) then
    S := V.OpenReadView(AView)
  else
    S := AFs.OpenRead(AView.ToString);
  LPath := AView.ToString; { 仅用于错误上下文单次物化 }
  try
    LSize := S.Size;
    if (LSize < 0) or (UInt64(LSize) > UInt64(High(SizeInt))) then
      raise EVfsError.CreateCtx('read', LPath, 'declared size out of range');
    SetLength(Result, LSize);
    Total := 0;
    while Total < SizeUInt(LSize) do
    begin
      if Total >= SizeUInt(Length(Result)) then
        raise EVfsError.CreateCtx('read', LPath, 'truncated: size exceeds addressable length');
      Got := S.Read(Result[Total], SizeUInt(Length(Result)) - Total);
      if Got = 0 then
        raise EVfsError.CreateCtx('read', LPath,
          'stream ended before declared size');
      Total := Total + Got;
    end;
  finally
    S.Close;
  end;
end;

function VfsReadAllTextView(const AFs: IVfs; const AView: TStringView): string; inline;
var
  B: TBytes;
begin
  B := VfsReadAllBytesView(AFs, AView);
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
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
