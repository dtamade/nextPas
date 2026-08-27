unit nextpas.core.vfs.embedded;

{** @desc embedded 后端：respack blob 上的只读 IVfs 视图——资产嵌入主路径。
  零拷贝：Stat/Find 直通 respack 二分索引；读取窗口直接落在 blob 区间内
  （INV-V6/P8）。EResPackCorrupted 原样透传，不用 vfs 错误语义掩盖格式层错误
  （设计决策记录见 core/docs/vfs/README.md）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.respack.base,
  nextpas.core.respack.reader,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

{ 打开已校验的 pack 缓冲为只读 VFS。
  AOwnsBlob=True：接口持所有权，最后一个引用释放时 FreeMem（heaptrc 可证）；
  AOwnsBlob=False：调用方保活缓冲（const 段/静态数据场景，INV-V6）。 }
function CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean): IVfs;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.time.httpdate;

type
  { 只读窗口流：读窗口 = blob 内 [FOffset, FOffset+FSize)，零拷贝直达 }
  TWindowStream = class(TInterfacedObject, IStream, IReaderAt)
  private
    FBase: PByte;
    FOffset: Int64;
    FSize: Int64;
    FPos: Int64;
    FOpen: Boolean;
    procedure CheckOpen;
  public
    constructor Create(ABase: PByte; const AOffset, ASize: Int64);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function ReadAt(var ABuf; const ACount: SizeUInt;
      const AOffset: Int64): SizeUInt;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

  TEmbeddedVfs = class(TInterfacedObject, IVfs, IVfsETag)
  private
    FRp: TResPack;
    FData: PByte;
    FSize: SizeUInt;
    FOwnsBlob: Boolean;
    FPaths: TVfsNameArray; { cached sorted file paths — O(1) reuse, avoids per-call EntryPaths alloc }
    FETags: array of string; { parallel ETag cache — precomputed at Create, O(1) ServeVfs }
    FLastMods: array of string; { parallel Last-Modified cache — FormatHttpDate at Create }
    function EntryPaths: TVfsNameArray; inline;
    function HasSubtreePath(const APath: string): Boolean;
    function StartsWithPath(const AStr, APrefix: string): Boolean;
    function IndexOfPath(const APath: string): SizeInt;
  public
    constructor Create(AData: PByte; ASize: SizeUInt; AOwnsBlob: Boolean);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
  end;

function CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean): IVfs;
begin
  Result := TEmbeddedVfs.Create(AData, ASize, AOwnsBlob);
end;

{ ── TWindowStream ── }

constructor TWindowStream.Create(ABase: PByte; const AOffset, ASize: Int64);
begin
  inherited Create;
  FBase := ABase;
  FOffset := AOffset;
  FSize := ASize;
  FPos := 0;
  FOpen := True;
end;

procedure TWindowStream.CheckOpen;
begin
  if not FOpen then
    raise EVfsClosed.CreateCtx('read', '', 'stream already closed');
end;

function TWindowStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  Avail: SizeUInt;
begin
  CheckOpen;
  if FPos >= FSize then
    Exit(0);
  Avail := SizeUInt(FSize) - SizeUInt(FPos);
  if ACount < Avail then
    Avail := ACount;
  if Avail > 0 then
    Move((FBase + SizeUInt(FOffset) + SizeUInt(FPos))^, ABuf, Avail);
  Inc(FPos, Int64(Avail));
  Result := Avail;
end;

function TWindowStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;  { 只读流：写入一律抛错，返回值仅为满足签名 }
  raise EVfsError.CreateCtx('write', '', 'stream is read-only');
end;

function TWindowStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  CheckOpen;
  case AOrigin of
    soBeginning: FPos := AOffset;
    soCurrent:   FPos := FPos + AOffset;
    soEnd:       FPos := FSize + AOffset;
  end;
  if FPos < 0 then
    FPos := 0;
  if FPos > FSize then
    FPos := FSize;
  Result := FPos;
end;

procedure TWindowStream.Close;
begin
  FOpen := False;
end;

function TWindowStream.GetSize: Int64;
begin
  CheckOpen;
  Result := FSize;
end;

function TWindowStream.GetPosition: Int64;
begin
  CheckOpen;
  Result := FPos;
end;

procedure TWindowStream.SetPosition(const AValue: Int64);
begin
  CheckOpen;
  FPos := AValue;
end;

function TWindowStream.ReadAt(var ABuf; const ACount: SizeUInt;
  const AOffset: Int64): SizeUInt;
var
  Avail: SizeUInt;
begin
  CheckOpen;
  if (AOffset < 0) or (AOffset >= FSize) then
    Exit(0);
  Avail := SizeUInt(FSize) - SizeUInt(AOffset);
  if ACount < Avail then
    Avail := ACount;
  if Avail > 0 then
    Move((FBase + SizeUInt(FOffset) + SizeUInt(AOffset))^, ABuf, Avail);
  Result := Avail;
end;

{ ── TEmbeddedVfs ── }

constructor TEmbeddedVfs.Create(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean);
var
  I: SizeUInt;
  E: TResPackEntry;
begin
  inherited Create;
  FRp := TResPack.Open(AData, ASize);   { 校验失败 EResPackCorrupted 原样透传 }
  FData := AData;
  FSize := ASize;
  FOwnsBlob := AOwnsBlob;
  { Materialize sorted path index + parallel ETag/Last-Modified cache once — O(n) upfront, O(1) per ServeVfs }
  SetLength(FPaths, FRp.Count);
  SetLength(FETags, FRp.Count);
  SetLength(FLastMods, FRp.Count);
  if FRp.Count > 0 then
    for I := 0 to FRp.Count - 1 do
    begin
      E := FRp.EntryAt(I);
      FPaths[I] := FRp.PathOf(E);
      if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
        FETags[I] := '"fnv-' + nextpas.core.text.conv.IntToHex(UInt64(E.Hash), 8) + '"'
      else
        FETags[I] := '"' + nextpas.core.text.conv.IntToHex(E.Size, 16) + '-' + nextpas.core.text.conv.IntToHex(UInt64(E.ModTime), 16) + '"';
      if E.ModTime > 0 then
        FLastMods[I] := nextpas.core.time.httpdate.FormatHttpDate(E.ModTime)
      else
        FLastMods[I] := '';
    end;
end;

destructor TEmbeddedVfs.Destroy;
begin
  SetLength(FLastMods, 0);
  SetLength(FETags, 0);
  SetLength(FPaths, 0);
  if FOwnsBlob and (FData <> nil) then
    FreeMem(FData);
  FData := nil;
  inherited Destroy;
end;

function TEmbeddedVfs.EntryPaths: TVfsNameArray;
begin
  Result := FPaths; { zero-alloc reuse — caller must not mutate }
end;

function TEmbeddedVfs.Exists(const APath: string): Boolean;
var
  E: TResPackEntry;
begin
  if not VfsValidPath(APath, True) then
    Exit(False);
  if VfsIsRoot(APath) then
    Exit(True);
  if FRp.Find(APath, E) then
    Exit(True);
  Result := HasSubtreePath(APath);
end;

function TEmbeddedVfs.HasSubtreePath(const APath: string): Boolean;
var
  Prefix: string;
  Lo, Hi, Mid: SizeInt;
begin
  { 子目录存在性：排序路径首个 ≥ prefix 的项即判定点 — O(log n) }
  Result := False;
  if Length(FPaths) = 0 then
    Exit;
  Prefix := APath + '/';
  Lo := 0;
  Hi := Length(FPaths);
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    if FPaths[Mid] < Prefix then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  if (Lo < Length(FPaths)) and StartsWithPath(FPaths[Lo], Prefix) then
    Exit(True);
end;

function TEmbeddedVfs.IndexOfPath(const APath: string): SizeInt;
var
  Lo, Hi, Mid: SizeInt;
begin
  Lo := 0;
  Hi := Length(FPaths);
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    if FPaths[Mid] = APath then Exit(Mid);
    if FPaths[Mid] < APath then Lo := Mid + 1 else Hi := Mid;
  end;
  Result := -1;
end;

function TEmbeddedVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  Idx: SizeInt;
begin
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    AETag := FETags[Idx];
    Exit(True);
  end;
  AETag := '';
  Result := False;
end;

function TEmbeddedVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var
  Idx: SizeInt;
begin
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    ALastModified := FLastMods[Idx];
    Exit(True);
  end;
  ALastModified := '';
  Result := False;
end;

{ 前缀判断：显式处理空前缀（FPC Pos('',S)=0 陷阱） }
function TEmbeddedVfs.StartsWithPath(const AStr, APrefix: string): Boolean;
begin
  if Length(APrefix) = 0 then
    Exit(True);
  Result := (Length(AStr) >= Length(APrefix))
    and (Pos(APrefix, AStr) = 1);
end;

function TEmbeddedVfs.Stat(const APath: string): TStatInfo;
var
  E: TResPackEntry;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  if FRp.Find(APath, E) then
  begin
    Result.Info.Name := APath;
    Result.Info.Size := Int64(E.Size);
    Result.Info.ModTime := E.ModTime;
    Result.Info.IsDir := False;
    if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
      Result.ContentHash := E.Hash
    else
      Result.ContentHash := 0;
  end
  else if VfsIsRoot(APath) or HasSubtreePath(APath) then
  begin
    Result.Info.Name := APath;
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
  end
  else
    raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

function TEmbeddedVfs.List(const ADirPath: string): TEntryArray;
var
  Prefix: string;
  Seen: TVfsNameArray;
  SI: TStatInfo;
  I: SizeUInt;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  if not VfsIsRoot(ADirPath) then
  begin
    { 目录存在性：是文件则 NotADirectory，两者皆非则 NotFound }
    SI := Stat(ADirPath);
    if not SI.Info.IsDir then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
  end;
  if VfsIsRoot(ADirPath) then
    Prefix := ''
  else
    Prefix := ADirPath + '/';

  Seen := VfsDeriveChildNames(EntryPaths, Prefix);

  Result := nil;
  SetLength(Result, SizeUInt(Length(Seen)));
  if SizeUInt(Length(Seen)) > 0 then
    for I := 0 to SizeUInt(Length(Seen)) - 1 do
    begin
      SI := Stat(Seen[I]);
      Result[I] := SI.Info;
    end;
  VfsSortEntries(Result);
end;

function TEmbeddedVfs.OpenRead(const APath: string): IStream;
var
  E: TResPackEntry;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  if not FRp.Find(APath, E) then
  begin
    if HasSubtreePath(APath) then
      raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
    raise EVfsNotFound.CreateCtx('open', APath, 'not found');
  end;
  Result := TWindowStream.Create(FData, Int64(E.DataOffset), Int64(E.Size));
end;

function TEmbeddedVfs.CaseSensitive: Boolean;
begin
  Result := True;
end;

end.
