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
  nextpas.core.collections.algorithms;

type
  TOverlayVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FList: array of IVfs;
    function FindStat(const APath: string; out AInfo: TStatInfo): Boolean; inline;
    function FindFsForPath(const APath: string; out ARemain: string; out AFs: IVfs): Boolean; inline;
  public
    constructor Create(const AList: array of IVfs);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
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
end;

function TOverlayVfs.FindFsForPath(const APath: string; out ARemain: string; out AFs: IVfs): Boolean; inline;
var
  I: Integer;
begin
  ARemain := APath;
  for I := 0 to High(FList) do
    if FList[I].Exists(APath) then
    begin
      AFs := FList[I];
      Exit(True);
    end;
  AFs := nil;
  Result := False;
end;

function TOverlayVfs.FindStat(const APath: string; out AInfo: TStatInfo): Boolean; inline;
var
  I: Integer;
begin
  for I := 0 to High(FList) do
  begin
    try
      AInfo := FList[I].Stat(APath);
      Exit(True);
    except
      on E: EVfsNotFound do Continue;
      on E: EVfsInvalidPath do raise;
    end;
  end;
  Result := False;
end;

function TOverlayVfs.Exists(const APath: string): Boolean; inline;
var
  I: Integer;
begin
  if not VfsValidPath(APath, True) then Exit(False);
  if VfsIsRoot(APath) then Exit(True);
  for I := 0 to High(FList) do
    if FList[I].Exists(APath) then Exit(True);
  Result := False;
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

function TOverlayVfs.List(const ADirPath: string): TEntryArray;
var
  I, J, OutN, TempN: Integer;
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
  SetLength(Result, TempN);
  OutN := 0;
  for I := 0 to TempN - 1 do
  begin
    if (OutN > 0) and (Result[OutN - 1].Name = Temp[I].Entry.Name) then Continue;
    Result[OutN] := Temp[I].Entry;
    Inc(OutN);
  end;
  SetLength(Result, OutN);
end;

function TOverlayVfs.OpenRead(const APath: string): IStream;
var
  I: Integer;
  FirstIsDir: Boolean;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  if VfsIsRoot(APath) then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  FirstIsDir := False;
  for I := 0 to High(FList) do
  begin
    if FList[I].Exists(APath) then
      Exit(FList[I].OpenRead(APath));
    // 若某层认定为目录，记忆
    try
      if FList[I].Stat(APath).Info.IsDir then FirstIsDir := True;
    except
    end;
  end;
  if FirstIsDir then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  raise EVfsNotFound.CreateCtx('open', APath, 'not found');
end;

function TOverlayVfs.CaseSensitive: Boolean;
var
  I: Integer;
  First: Boolean;
begin
  if Length(FList) = 0 then Exit(True);
  First := FList[0].CaseSensitive;
  for I := 1 to High(FList) do
    if FList[I].CaseSensitive <> First then Exit(True);
  Result := First;
end;

function TOverlayVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  I: Integer;
  Intf: IVfsETag;
begin
  AETag := '';
  for I := 0 to High(FList) do
    if FList[I].Exists(APath) then
    begin
      if Supports(FList[I], IVfsETag, Intf) then
        Exit(Intf.TryGetETag(APath, AETag));
      Exit(False);
    end;
  Result := False;
end;

function TOverlayVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var
  I: Integer;
  Intf: IVfsETag;
begin
  ALastModified := '';
  for I := 0 to High(FList) do
    if FList[I].Exists(APath) then
    begin
      if Supports(FList[I], IVfsETag, Intf) then
        Exit(Intf.TryGetLastModified(APath, ALastModified));
      Exit(False);
    end;
  Result := False;
end;

function TOverlayVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
var
  I: Integer;
  Intf: IVfsServeMeta;
  ETagIntf: IVfsETag;
begin
  AETag := '';
  ALastModified := '';
  for I := 0 to High(FList) do
    if FList[I].Exists(APath) then
    begin
      if Supports(FList[I], IVfsServeMeta, Intf) then
        Exit(Intf.TryGetServeMeta(APath, AETag, ALastModified));
      if Supports(FList[I], IVfsETag, ETagIntf) then
      begin
        Result := ETagIntf.TryGetETag(APath, AETag);
        if Result then ETagIntf.TryGetLastModified(APath, ALastModified);
        Exit;
      end;
      Exit(False);
    end;
  Result := False;
end;

end.
