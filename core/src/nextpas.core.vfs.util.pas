unit nextpas.core.vfs.util;

{** @desc 基于 IVfs 的组合辅助：包级 Stat/List/ReadAll/Walk（Go io/fs 包函数同构）。
  四件套归位：helpers 层（base ← intf ← helpers(util) ← 门面），门面完整 re-export；
  不持有状态，仅组合 IVfs 原语，保持零拷贝与性能语义不变。
  单源收敛：声明尺寸校验与 FillFromStream 单源（复用 bytes.ops 零拷贝词汇），
  IReaderAt 单次直读（embedded/os 零额外虚调用/边界校验）。 }

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

uses
  nextpas.core.bytes.ops;

{ 单源：声明尺寸越界校验（High(SizeInt) 守可寻址上限），两 ReadAll 共用，避免样板漂移；inline 热路径 }
procedure VfsCheckDeclaredSize(const APath: string; const LSize: Int64); inline;
begin
  if (LSize < 0) or (UInt64(LSize) > UInt64(High(SizeInt))) then
    raise EVfsError.CreateCtx('read', APath, 'declared size out of range');
end;

{ 单源填充器：IReaderAt 单次直读 + 回退 Read 循环；入参 ADst 直指 TBytes/string 存储零拷贝无中间分配/Move，
  复用 bytes.ops 零拷贝词汇（BytesCopy 单源语义，Move 直达目的缓冲）；
  非 inline：含循环体守 design-conventions §2 红线；稳定性 try-finally Close 由调用方保障不丢 }
procedure VfsFillFromStream(const S: IStream; const APath: string; ADst: PByte; const ALen: SizeUInt);
var
  LReaderAt: IReaderAt;
  Got, Total, Rem: SizeUInt;
begin
  if ALen = 0 then Exit;
  if ADst = nil then
    raise EVfsError.CreateCtx('read', APath, 'nil destination');
  { perf: 探测 IReaderAt（INV-V12 三后端一致），命中则单次 ReadAt(0) 直达 blob/文件窗口，
    省循环内每次 Read 虚调用 + 边界校验；embedded/os 实测单 Move 零拷贝（bytes.ops 单源） }
  if (S.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil) then
  begin
    Got := LReaderAt.ReadAt(ADst^, ALen, 0);
    if Got = ALen then Exit;
    if Got = 0 then
      raise EVfsError.CreateCtx('read', APath, 'stream ended before declared size');
    Total := Got;
    while Total < ALen do
    begin
      Rem := ALen - Total;
      Got := LReaderAt.ReadAt(ADst[Total], Rem, Int64(Total));
      if Got = 0 then
        raise EVfsError.CreateCtx('read', APath, 'stream ended before declared size');
      Total := Total + Got;
    end;
    Exit;
  end;
  Total := 0;
  while Total < ALen do
  begin
    if Total >= ALen then
      raise EVfsError.CreateCtx('read', APath, 'truncated: size exceeds addressable length');
    Rem := ALen - Total;
    Got := S.Read(ADst[Total], Rem);
    if Got = 0 then
      raise EVfsError.CreateCtx('read', APath, 'stream ended before declared size');
    Total := Total + Got;
  end;
end;

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
  LSize: Int64;
begin
  // perf: zero-copy single alloc — SetLength 后直填 TBytes 存储，无中间分配；单源 FillFromStream 复用 IReaderAt 直读与校验
  // stability: try-finally S.Close 不丢；非 inline 守 §2 循环红线（循环在 FillFromStream 侧）
  Result := nil;
  S := AFs.OpenRead(APath);
  try
    LSize := S.Size;
    VfsCheckDeclaredSize(APath, LSize);
    SetLength(Result, LSize);
    if LSize = 0 then Exit;
    VfsFillFromStream(S, APath, PByte(@Result[0]), SizeUInt(LSize));
  finally
    S.Close;
  end;
end;

function VfsReadAllText(const AFs: IVfs; const APath: string): string;
var
  S: IStream;
  LSize: Int64;
begin
  // perf: zero-copy single alloc — direct SetLength(Result) + stream→string buffer, no TBytes intermediate
  // saves 1 alloc + 1 Move (2× mem) vs prior B:=VfsReadAllBytes+Move; 单源 FillFromStream 复用 size 校验与 IReaderAt 直读
  // stability: try-finally S.Close preserved; 非 inline 守 §2 循环红线（循环在 FillFromStream 侧）
  Result := '';
  S := AFs.OpenRead(APath);
  try
    LSize := S.Size;
    VfsCheckDeclaredSize(APath, LSize);
    SetLength(Result, LSize);
    if LSize = 0 then Exit;
    VfsFillFromStream(S, APath, PByte(@Result[1]), SizeUInt(LSize));
  finally
    S.Close;
  end;
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
