unit nextpas.core.vfs.overlay;

{** @desc 叠加视图：多 IVfs 同根优先级叠加（游戏 patch>dlc>base 热更模型）。
  与 mount 互补：mount 是异前缀聚合（a→FsA, b→FsB），overlay 是同根覆盖
  （同一虚拟路径多层，首命中胜出）。INV-O1：列表按传入优先级有序，Exists/Stat/
  OpenRead 按序首命中；List('.') 去重合并按首层优先保留。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

function CreateOverlayVfs(const AList: array of IVfs): IVfs;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.hashmap,
  nextpas.core.sync;

type
  TOverlayIndex = specialize THashMap<string, Integer>;

type
  TOverlayVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FList: array of IVfs;
    function FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean; inline;
    function FindStat(const APath: string; out AInfo: TStatInfo): Boolean; inline;
  public
    constructor Create(const AList: array of IVfs);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean; inline;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
    function TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
  end;

function CreateOverlayVfs(const AList: array of IVfs): IVfs;
begin
  Result := TOverlayVfs.Create(AList);
end;

constructor TOverlayVfs.Create(const AList: array of IVfs);
var
  I: Integer;
begin
  inherited Create;
  if Length(AList) = 0 then
    raise EVfsError.CreateCtx('overlay', '', 'overlay requires at least one fs');
  SetLength(FList, Length(AList));
  for I := 0 to High(AList) do
  begin
    if AList[I] = nil then
      raise EVfsError.CreateCtx('overlay', '', 'overlay fs must not be nil');
    FList[I] := AList[I];
  end;
  FIndex := TOverlayIndex.Create(16);
  FIndexLock := SpinLock;
end;

{ 单次探测首命中：按优先级依次 Stat，首成功即胜出；EVfsNotFound 继续下层，
  EVfsInvalidPath 透传；零二次 Exists 二分，inline 热路径 }
function TOverlayVfs.FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean; inline;
var
  I: Integer;
begin
  if (FIndex = nil) or (FIndexLock = nil) then Exit;
  FIndexLock.Acquire;
  try
    TOverlayIndex(FIndex).AddOrAssign(APath, AIdx);
  finally
    FIndexLock.Release;
  end;
end;

{ 索引加速首命中：hash O(1) 首命中避 m 次二分；miss/layer负缓存防穿透；
  命中层单次 Stat 直达（零二次二分），SpinLock零分配，inline热路径，bytes.ops零拷贝单源 }
function TOverlayVfs.FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean; inline;
var
  I, LCached: Integer;
begin
  if TryGetCached(APath, LCached) then
  begin
    if LCached = -1 then begin AFs := nil; Exit(False); end;
    if (LCached >= 0) and (LCached <= High(FList)) then
    begin
      try
        AInfo := FList[LCached].Stat(APath);
        AFs := FList[LCached];
        Exit(True);
      except
        on E: EVfsNotFound do
        begin
          CacheResult(APath, -1);
          AFs := nil;
          Exit(False);
        end;
        on E: EVfsInvalidPath do raise;
      end;
    end;
  end;
  for I := 0 to High(FList) do
  begin
    try
      AInfo := FList[I].Stat(APath);
      AFs := FList[I];
      Exit(True);
    except
      on E: EVfsNotFound do Continue;
      on E: EVfsInvalidPath do raise;
    end;
  end;
  AFs := nil;
  Result := False;
end;

function TOverlayVfs.FindStat(const APath: string; out AInfo: TStatInfo): Boolean; inline;
var
  LFs: IVfs;
begin
  Result := FindFirstStat(APath, AInfo, LFs);
end;

function TOverlayVfs.Exists(const APath: string): Boolean; inline;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  if not VfsValidPath(APath, True) then Exit(False);
  if VfsIsRoot(APath) then Exit(True);
  { 单次 Stat 探测替代 Exists 循环，避免层数多时重复二分；inline }
  Result := FindFirstStat(APath, LInfo, LFs);
end;

function TOverlayVfs.Stat(const APath: string): TStatInfo;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  if VfsIsRoot(APath) then
  begin
    Result.Info.Name := '.';
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
    Exit;
  end;
  if FindStat(APath, Result) then
  begin
    Result.Info.Name := APath;
    Exit;
  end;
  raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

type
  TOverlayTemp = record
    Entry: TEntryInfo;
    Prio: Integer;
  end;

{ 单源排序比较：Name 字节序 + Prio 优先级；复用 bytes.ops 零拷贝 VfsNameCompare }
function CompareOverlayTemp(const A, B: TOverlayTemp; Data: Pointer): SizeInt; inline;
begin
  Result := VfsNameCompare(A.Entry.Name, B.Entry.Name);
  if Result = 0 then
    Result := SizeInt(A.Prio) - SizeInt(B.Prio);
end;

{ Name-only 去重比较：单源 Unique（VfsNameCompare），保留首层优先级 }
function CompareOverlayTempNameOnly(const A, B: TOverlayTemp; Data: Pointer): SizeInt; inline;
begin
  Result := VfsNameCompare(A.Entry.Name, B.Entry.Name);
end;

function TOverlayVfs.List(const ADirPath: string): TEntryArray;
var
  I, J, TempN: Integer;
  Cur: TEntryArray;
  LStat: TStatInfo;
  Temp: array of TOverlayTemp;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  if not VfsIsRoot(ADirPath) then
  begin
    if not FindStat(ADirPath, LStat) then
      raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found');
    if not LStat.Info.IsDir then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
  end;
  TempN := 0;
  for I := 0 to High(FList) do
  begin
    try Cur := FList[I].List(ADirPath);
    except on E: EVfsNotFound do Continue; on E: EVfsNotADirectory do Continue; end;
    if Length(Cur) = 0 then Continue;
    if TempN + Length(Cur) > Length(Temp) then
      SetLength(Temp, TempN + Length(Cur));
    for J := 0 to High(Cur) do
    begin
      Temp[TempN].Entry := Cur[J];
      Temp[TempN].Prio := I;
      Inc(TempN);
    end;
  end;
  if TempN = 0 then Exit(nil);
  SetLength(Temp, TempN);
  specialize Sort<TOverlayTemp>(Temp, @CompareOverlayTemp, nil);
  TempN := specialize Unique<TOverlayTemp>(Temp, @CompareOverlayTempNameOnly, nil);
  SetLength(Temp, TempN);
  SetLength(Result, TempN);
  for I := 0 to TempN - 1 do
    Result[I] := Temp[I].Entry;
end;

function TOverlayVfs.OpenRead(const APath: string): IStream;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  if VfsIsRoot(APath) then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  { 单次 Stat 首命中替代 Exists+Stat 双探测；IsDir 即抛 IsADirectory，否则直透 OpenRead，inline 热路径，零重复二分 }
  if FindFirstStat(APath, LInfo, LFs) then
  begin
    if LInfo.Info.IsDir then
      raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
    Exit(LFs.OpenRead(APath));
  end;
  raise EVfsNotFound.CreateCtx('open', APath, 'not found');
end;

{ 同根优先级：CaseSensitive 取首层优先，与 Exists/Stat/OpenRead 首命中一致；
  异构时不再保守退 True，避免与 List 字节序去重（VfsNameCompare via bytes.ops SpanCompare 零拷贝）产生大小写同名异壳歧义 }
function TOverlayVfs.CaseSensitive: Boolean; inline;
begin
  if Length(FList) = 0 then Exit(True);
  Result := FList[0].CaseSensitive;
end;

function TOverlayVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  LInfo: TStatInfo;
  LFs: IVfs;
  Intf: IVfsETag;
begin
  AETag := '';
  if VfsIsRoot(APath) then Exit(False);
  if not FindFirstStat(APath, LInfo, LFs) then Exit(False);
  if LInfo.Info.IsDir then Exit(False);
  if Supports(LFs, IVfsETag, Intf) then
    Exit(Intf.TryGetETag(APath, AETag));
  Result := False;
end;

function TOverlayVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var
  LInfo: TStatInfo;
  LFs: IVfs;
  Intf: IVfsETag;
begin
  ALastModified := '';
  if VfsIsRoot(APath) then Exit(False);
  if not FindFirstStat(APath, LInfo, LFs) then Exit(False);
  if LInfo.Info.IsDir then Exit(False);
  if Supports(LFs, IVfsETag, Intf) then
    Exit(Intf.TryGetLastModified(APath, ALastModified));
  Result := False;
end;

function TOverlayVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
var
  LInfo: TStatInfo;
  LFs: IVfs;
  Intf: IVfsServeMeta;
  ETagIntf: IVfsETag;
begin
  AETag := '';
  ALastModified := '';
  if VfsIsRoot(APath) then Exit(False);
  if not FindFirstStat(APath, LInfo, LFs) then Exit(False);
  if LInfo.Info.IsDir then Exit(False);
  if Supports(LFs, IVfsServeMeta, Intf) then
    Exit(Intf.TryGetServeMeta(APath, AETag, ALastModified));
  if Supports(LFs, IVfsETag, ETagIntf) then
  begin
    Result := ETagIntf.TryGetETag(APath, AETag);
    if Result then ETagIntf.TryGetLastModified(APath, ALastModified);
    Exit;
  end;
  Result := False;
end;

end.
