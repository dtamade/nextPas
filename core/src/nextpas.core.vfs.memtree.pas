unit nextpas.core.vfs.memtree;

{** @desc 内存不可变树：Builder（可变期）→ Freeze → IVfs 快照。
  fstest.MapFS 对等物；embedded 后端底座与测试替身。目录由路径隐含推导（INV-V8），
  文件与同名子树重叠在 Freeze 时拒绝，保持模型干净。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

type
  TVfsMemEntry = record
    Name: string;      { 规范虚拟路径 }
    Data: TBytes;
    ModTime: Int64;
    Hash: UInt32;
  end;

  { 可变构造期对象；Freeze 后不可复用 }
  TVfsTreeBuilder = class
  private
    FItems: array of TVfsMemEntry;
    FFrozen: Boolean;
    procedure CheckMutable; inline;
  public
    destructor Destroy; override;
    { AHash=0 表示不提供内容哈希 }
    procedure AddFile(const APath: string; const AData: TBytes;
      const AModTime: Int64; AHash: UInt32 = 0);
    { 排序、查重、文件/子树重叠检查后产出不可变快照 }
    function Freeze: IVfs;
  end;

{ 便捷入口：等价于 Builder+AddFile…+Freeze }
function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs;

implementation

uses
  nextpas.core.collections.algorithms;

type
  TMemVfs = class(TInterfacedObject, IVfs)
  private
    FFiles: array of TVfsMemEntry;
    function LowerBound(const AName: string): SizeUInt;
    function FindExact(const AName: string): SizeUInt; { Count 当未命中 }
    function HasSubtree(const ADirPrefix: string): Boolean;
    procedure StatInto(const APath: string; out AInfo: TStatInfo);
  public
    constructor Create(AItems: array of TVfsMemEntry);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
  end;

  TMemStream = class(TInterfacedObject, IStream, IReaderAt)
  private
    FData: TBytes;
    FPos: Int64;
    FClosed: Boolean;
    FPath: string;
    procedure CheckOpen; inline;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  public
    constructor Create(const AData: TBytes; const APath: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function ReadAt(var ABuf; const ACount: SizeUInt;
      const AOffset: Int64): SizeUInt;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

{ ── 局部工具 ── }

function CompareMemEntry(const A, B: TVfsMemEntry; Data: Pointer): SizeInt;
begin
  Result := VfsNameCompare(A.Name, B.Name);
end;

{ ── TVfsTreeBuilder ── }

destructor TVfsTreeBuilder.Destroy;
begin
  inherited Destroy;
end;

procedure TVfsTreeBuilder.CheckMutable;
begin
  if FFrozen then
    raise EVfsClosed.CreateCtx('add', '', 'memtree builder already frozen');
end;

procedure TVfsTreeBuilder.AddFile(const APath: string; const AData: TBytes;
  const AModTime: Int64; AHash: UInt32);
var
  N: SizeUInt;
begin
  CheckMutable;
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('add', APath,
      'invalid virtual path');
  N := SizeUInt(Length(FItems));
  SetLength(FItems, N + 1);
  FItems[N].Name := APath;
  FItems[N].Data := AData;
  FItems[N].ModTime := AModTime;
  FItems[N].Hash := AHash;
end;

function TVfsTreeBuilder.Freeze: IVfs;
var
  I: SizeUInt;
begin
  CheckMutable;
  if SizeUInt(Length(FItems)) > 1 then
  begin
    specialize Sort<TVfsMemEntry>(FItems, @CompareMemEntry, nil);
    { 查重/重叠检查：Length-1 在 SizeUInt 上回绕 ⇒ 仅在 >1 时执行 }
    for I := 1 to SizeUInt(Length(FItems)) - 1 do
    begin
      if VfsNameCompare(FItems[I - 1].Name, FItems[I].Name) = 0 then
        raise EVfsError.CreateCtx('freeze', FItems[I].Name,
          'duplicate path in memtree');
      if VfsIsParentPath(FItems[I - 1].Name, FItems[I].Name) then
        raise EVfsError.CreateCtx('freeze', FItems[I - 1].Name,
          'file overlaps directory subtree');
    end;
  end;
  FFrozen := True;
  Result := TMemVfs.Create(FItems);
end;

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs;
var
  B: TVfsTreeBuilder;
  I: SizeUInt;
begin
  B := TVfsTreeBuilder.Create;
  try
    if SizeUInt(Length(AItems)) > 0 then
      for I := 0 to SizeUInt(Length(AItems)) - 1 do
        B.AddFile(AItems[I].Name, AItems[I].Data, AItems[I].ModTime,
          AItems[I].Hash);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

{ ── TMemVfs ── }

constructor TMemVfs.Create(AItems: array of TVfsMemEntry);
var
  I: SizeUInt;
begin
  inherited Create;
  SetLength(FFiles, Length(AItems));
  if SizeUInt(Length(AItems)) > 0 then
    for I := 0 to SizeUInt(Length(AItems)) - 1 do
      FFiles[I] := AItems[I];
end;

destructor TMemVfs.Destroy;
begin
  SetLength(FFiles, 0);
  inherited Destroy;
end;

function TMemVfs.LowerBound(const AName: string): SizeUInt;
var
  Lo, Hi, Mid: SizeUInt;
begin
  Lo := 0;
  Hi := SizeUInt(Length(FFiles));
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if VfsNameCompare(FFiles[Mid].Name, AName) < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TMemVfs.FindExact(const AName: string): SizeUInt;
var
  I: SizeUInt;
begin
  Result := SizeUInt(Length(FFiles));
  I := LowerBound(AName);
  if (I < SizeUInt(Length(FFiles)))
    and (VfsNameCompare(FFiles[I].Name, AName) = 0) then
    Result := I;
end;

function TMemVfs.HasSubtree(const ADirPrefix: string): Boolean;
var
  I: SizeUInt;
begin
  Result := False;
  I := LowerBound(ADirPrefix);
  if (I < SizeUInt(Length(FFiles)))
    and VfsPathHasPrefix(FFiles[I].Name, ADirPrefix)
    and (Length(FFiles[I].Name) > Length(ADirPrefix)) then
    Result := True;
end;

function TMemVfs.Exists(const APath: string): Boolean;
begin
  if VfsIsRoot(APath) then
    Exit(True);
  if not VfsValidPath(APath, False) then
    Exit(False);
  if FindExact(APath) < SizeUInt(Length(FFiles)) then
    Exit(True);
  Result := HasSubtree(APath + '/');
end;

procedure TMemVfs.StatInto(const APath: string; out AInfo: TStatInfo);
var
  Idx: SizeUInt;
begin
  Idx := FindExact(APath);
  if Idx < SizeUInt(Length(FFiles)) then
  begin
    AInfo.Info.Name := FFiles[Idx].Name;
    AInfo.Info.Size := Length(FFiles[Idx].Data);
    AInfo.Info.ModTime := FFiles[Idx].ModTime;
    AInfo.Info.IsDir := False;
    AInfo.ContentHash := FFiles[Idx].Hash;
  end
  else if VfsIsRoot(APath) or HasSubtree(APath + '/') then
  begin
    AInfo.Info.Name := APath;
    AInfo.Info.Size := 0;
    AInfo.Info.ModTime := 0;
    AInfo.Info.IsDir := True;
    AInfo.ContentHash := 0;
  end
  else
    raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

function TMemVfs.Stat(const APath: string): TStatInfo;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  StatInto(APath, Result);
end;

function TMemVfs.List(const ADirPath: string): TEntryArray;
var
  Prefix: string;
  DirIdx: SizeUInt;
  I: SizeUInt;
  K: SizeUInt;
  Seen: TVfsNameArray;
  Info: TStatInfo;
  Paths: array of string;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  if VfsIsRoot(ADirPath) then
    Prefix := ''
  else
  begin
    DirIdx := FindExact(ADirPath);
    if DirIdx < SizeUInt(Length(FFiles)) then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
    if not HasSubtree(ADirPath + '/') then
      raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found');
    Prefix := ADirPath + '/';
  end;

  { 单源模板收敛：委托 base.VfsDeriveChildNames 的 LowerBound+SpanStartsWith+Early-Break 零拷贝模板
    扇出限界分配消除 Hi-Lo 全量预分配与重复 LowerBound 手写分支，与 embedded 同构单源 }
  Result := nil;
  if Length(FFiles) = 0 then
  begin
    Seen := nil;
  end
  else
  begin
    // 零拷贝单源路径数组：利用有序 FFiles 名称视图委托基座扫描模板，避免三处同构重复
    SetLength(Paths, Length(FFiles));
    for K := 0 to SizeUInt(Length(FFiles)) - 1 do
      Paths[K] := FFiles[K].Name;
    Seen := VfsDeriveChildNames(Paths, Prefix);
    SetLength(Paths, 0);
  end;

  SetLength(Result, SizeUInt(Length(Seen)));
  for I := 0 to SizeUInt(Length(Seen)) - 1 do
  begin
    StatInto(Seen[I], Info);
    Result[I] := Info.Info;
  end;
  VfsSortEntries(Result);
end;

function TMemVfs.OpenRead(const APath: string): IStream;
var
  Idx: SizeUInt;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  Idx := FindExact(APath);
  if (Idx >= SizeUInt(Length(FFiles)))
    and (VfsIsRoot(APath) or HasSubtree(APath + '/')) then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  if Idx >= SizeUInt(Length(FFiles)) then
    raise EVfsNotFound.CreateCtx('open', APath, 'not found');
  Result := TMemStream.Create(FFiles[Idx].Data, APath);
end;

function TMemVfs.CaseSensitive: Boolean;
begin
  Result := True;
end;

{ ── TMemStream ── }

constructor TMemStream.Create(const AData: TBytes; const APath: string);
begin
  inherited Create;
  FData := AData;
  FPath := APath;
  FPos := 0;
end;

procedure TMemStream.CheckOpen;
begin
  if FClosed then
    raise EVfsClosed.CreateCtx('read', FPath, 'stream closed');
end;

function TMemStream.GetSize: Int64;
begin
  CheckOpen;
  Result := Length(FData);
end;

function TMemStream.GetPosition: Int64;
begin
  CheckOpen;
  Result := FPos;
end;

procedure TMemStream.SetPosition(const AValue: Int64);
begin
  CheckOpen;
  if AValue < 0 then
    FPos := 0
  else if AValue > Length(FData) then
    FPos := Length(FData)
  else
    FPos := AValue;
end;

function TMemStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  Avail: SizeUInt;
begin
  CheckOpen;
  if FPos < 0 then
    FPos := 0;
  if FPos >= Length(FData) then
    Exit(0);
  Avail := SizeUInt(Length(FData)) - SizeUInt(FPos);
  if ACount < Avail then
    Avail := ACount;
  if Avail > 0 then
    Move(FData[FPos], ABuf, Avail);
  Inc(FPos, Int64(Avail));
  Result := Avail;
end;

function TMemStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;  { 只读流：写入一律抛错，返回值仅为满足签名 }
  raise EVfsError.CreateCtx('write', FPath, 'stream is read-only');
end;

function TMemStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  CheckOpen;
  case AOrigin of
    soBeginning: FPos := AOffset;
    soCurrent:   FPos := FPos + AOffset;
    soEnd:       FPos := Length(FData) + AOffset;
  end;
  if FPos < 0 then
    FPos := 0
  else if FPos > Length(FData) then
    FPos := Length(FData);
  Result := FPos;
end;

procedure TMemStream.Close;
begin
  FClosed := True;
  SetLength(FData, 0);
end;

function TMemStream.ReadAt(var ABuf; const ACount: SizeUInt;
  const AOffset: Int64): SizeUInt;
var
  Avail: SizeUInt;
begin
  CheckOpen;
  if (AOffset < 0) or (AOffset >= Length(FData)) then
    Exit(0);
  Avail := SizeUInt(Length(FData)) - SizeUInt(AOffset);
  if ACount < Avail then
    Avail := ACount;
  if Avail > 0 then
    Move(FData[AOffset], ABuf, Avail);
  Result := Avail;
end;

end.
