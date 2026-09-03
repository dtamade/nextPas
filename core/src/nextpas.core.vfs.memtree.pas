unit nextpas.core.vfs.memtree;

{** @desc 内存不可变树：Builder（可变期）→ Freeze → IVfs 快照。
  fstest.MapFS 对等物；embedded 后端底座与测试替身。目录由路径隐含推导（INV-V8），
  文件与同名子树重叠在 Freeze 时拒绝，保持模型干净。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
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
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.text.view,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.mem.dynarray;

type
  TMemVfs = class(TInterfacedObject, IVfs, IVfsView)
  private
    FFiles: array of TVfsMemEntry;
    function LowerBound(const AName: string): SizeUInt;
    function LowerBoundView(const AView: TStringView): SizeUInt; inline;
    function FindExact(const AName: string): SizeUInt; { Count 当未命中 }
    function FindExactView(const AView: TStringView): SizeUInt; inline;
    function HasSubtree(const ADirPrefix: string): Boolean;
    function HasSubtreeView(const AView: TStringView): Boolean; inline;
    procedure StatInto(const APath: string; out AInfo: TStatInfo);
  public
    constructor Create(AItems: array of TVfsMemEntry);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function ExistsView(const APath: TStringView): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function OpenReadView(const APath: TStringView): IStream;
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

  TMemListCtx = record
    Owner: TMemVfs;
    Result: TEntryArray;
    OutN: SizeInt;
    N: SizeInt;
  end;
  PMemListCtx = ^TMemListCtx;

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
  LOld, LReq, LCap: SizeUInt;
  LCurCap: SizeUInt;
begin
  CheckMutable;
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('add', APath,
      'invalid virtual path');
  LOld := SizeUInt(Length(FItems));
  LReq := LOld + 1;
  // perf: geometric via bytes.ops.BytesGrowCapacity single source amortized O(1) (BYTES_BUILDER_MIN_GROW 0→64→2×), zero-copy via mem.dynarray poke, not inline per red-line 2
  LCap := BytesGrowCapacity(LOld, LReq);
  LCurCap := DynArrayCapacityElem(Pointer(FItems), LOld, SizeOf(TVfsMemEntry));
  if (LCurCap < LCap) or (DynArrayRefCountElem(Pointer(FItems)) <> 1) then
  begin
    if LCap <> LOld then
      SetLength(FItems, LCap);
  end;
  if SizeUInt(Length(FItems)) <> LReq then
    DynArraySetLengthElem(Pointer(FItems), LReq);
  FItems[LOld].Name := APath;
  FItems[LOld].Data := AData;
  FItems[LOld].ModTime := AModTime;
  FItems[LOld].Hash := AHash;
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

function TMemVfs.LowerBoundView(const AView: TStringView): SizeUInt; inline;
var
  Lo, Hi, Mid: SizeUInt;
begin
  { perf: inline + VfsNameCompareView 零拷贝视图比较，复用 bytes.ops CompareBytesOrdered 单源，零堆分配，O(log n) }
  Lo := 0;
  Hi := SizeUInt(Length(FFiles));
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if VfsNameCompareView(AView, FFiles[Mid].Name) > 0 then
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

function TMemVfs.FindExactView(const AView: TStringView): SizeUInt; inline;
var
  I: SizeUInt;
begin
  Result := SizeUInt(Length(FFiles));
  I := LowerBoundView(AView);
  if (I < SizeUInt(Length(FFiles)))
    and (VfsNameCompareView(AView, FFiles[I].Name) = 0) then
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

function TMemVfs.HasSubtreeView(const AView: TStringView): Boolean; inline;
var
  I: SizeUInt;
begin
  { perf: inline 零拷贝前缀判定，单次 LowerBoundView + CompareMem 前缀直比，零堆分配 }
  Result := False;
  I := LowerBoundView(AView);
  if I >= SizeUInt(Length(FFiles)) then Exit(False);
  if SizeUInt(Length(FFiles[I].Name)) <= AView.Len then Exit(False);
  if FFiles[I].Name[AView.Len + 1] <> '/' then Exit(False);
  if AView.Len = 0 then Exit(True);
  if not CompareMem(@FFiles[I].Name[1], AView.Data, AView.Len) then Exit(False);
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

function TMemVfs.ExistsView(const APath: TStringView): Boolean; inline;
begin
  { perf: inline + VfsValidPathView 零拷贝校验 + O(log n) 二分视图比较，复用 bytes.ops 单源，零堆分配；HasSubtreeView 零拷贝前缀直比 }
  if VfsIsRootView(APath) then
    Exit(True);
  if not VfsValidPathView(APath, False) then
    Exit(False);
  if FindExactView(APath) < SizeUInt(Length(FFiles)) then
    Exit(True);
  Result := HasSubtreeView(APath);
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

function MemtreeGetter(AIdx: SizeInt; AUserData: Pointer): TByteSpan;
var
  V: TMemVfs;
begin
  V := TMemVfs(AUserData);
  if Length(V.FFiles[AIdx].Name) = 0 then
    Result := TByteSpan.Empty
  else
    Result := TByteSpan.FromStr(V.FFiles[AIdx].Name);
end;

procedure MemtreeHandler(const AChildSpan: TByteSpan; const AFullSpan: TByteSpan;
  ASourceIdx: SizeInt; AUserData: Pointer); inline;
var
  Ctx: PMemListCtx;
  Cap: SizeInt;
begin
  Ctx := PMemListCtx(AUserData);
  if Ctx^.OutN >= Length(Ctx^.Result) then
  begin
    Cap := SizeInt(BytesNextCapacity(SizeUInt(Length(Ctx^.Result)), SizeUInt(Ctx^.OutN + 1)));
    if Cap > Ctx^.N then Cap := Ctx^.N;
    SetLength(Ctx^.Result, Cap);
  end;
  Ctx^.Result[Ctx^.OutN].Name := SpanToString(AChildSpan); { bytes.ops 单源 inline 零拷贝+单 Move，批量池化外层 BytesNextCapacity }
  if AFullSpan.Len = AChildSpan.Len then
  begin
    Ctx^.Result[Ctx^.OutN].Size := Length(Ctx^.Owner.FFiles[ASourceIdx].Data);
    Ctx^.Result[Ctx^.OutN].ModTime := Ctx^.Owner.FFiles[ASourceIdx].ModTime;
    Ctx^.Result[Ctx^.OutN].IsDir := False;
  end
  else
  begin
    Ctx^.Result[Ctx^.OutN].Size := 0;
    Ctx^.Result[Ctx^.OutN].ModTime := 0;
    Ctx^.Result[Ctx^.OutN].IsDir := True;
  end;
  Inc(Ctx^.OutN);
end;

function TMemVfs.List(const ADirPath: string): TEntryArray;
var
  Prefix: string;
  DirIdx: SizeUInt;
  Ctx: TMemListCtx;
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

  // 单源收敛：经 VfsEnumerateChildSpans (vfs.base 通用 helper) 零拷贝直读 FFiles+bytes.ops，O(k) 直取无二次二分；与 embedded FRp.StoredPathSpan 同模板收口
  // perf: TByteSpan.FromStr 零拷贝视图直指 string 存储，热路径 SpanStartsWith/SpanEqual/SpanCompare bytes.ops 单源 inline 零拷贝；扇出限界 16 倍增 Cap≤N，O(k) 直取 FFiles 并行缓存无 FindExact 二分，资源释放不丢（Ctx.Result 局部管理，Result 归调用方）
  Result := nil;
  if Length(FFiles) = 0 then
    Exit(nil);
  Ctx.Owner := Self;
  Ctx.Result := nil;
  Ctx.OutN := 0;
  Ctx.N := SizeInt(Length(FFiles));
  VfsEnumerateChildSpans(Ctx.N, @MemtreeGetter, Self, Prefix, @MemtreeHandler, @Ctx);
  SetLength(Ctx.Result, Ctx.OutN);
  Result := Ctx.Result;
  // Ctx.Result 已 LowerBound+SpanStartsWith 有序去重保证字典序，省去 VfsSortEntries O(k log k)，与 embedded 同源单源
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

function TMemVfs.OpenReadView(const APath: TStringView): IStream;
var
  Idx: SizeUInt;
  LPathStr: string;
begin
  { perf: inline 零拷贝视图二分，命中单次 VfsReadAllBytes Move 零拷贝透传，目录/非法路径零重度 I/O }
  if not VfsValidPathView(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath.ToString, 'invalid virtual path');
  Idx := FindExactView(APath);
  if (Idx >= SizeUInt(Length(FFiles)))
    and (VfsIsRootView(APath) or HasSubtreeView(APath)) then
    raise EVfsIsADirectory.CreateCtx('open', APath.ToString, 'target is a directory');
  if Idx >= SizeUInt(Length(FFiles)) then
    raise EVfsNotFound.CreateCtx('open', APath.ToString, 'not found');
  LPathStr := APath.ToString; { 仅为流诊断路径单次物化，无数据拷贝 }
  Result := TMemStream.Create(FFiles[Idx].Data, LPathStr);
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
    BytesCopy(@ABuf, @FData[FPos], Avail); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, INV-5)
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
    BytesCopy(@ABuf, @FData[AOffset], Avail); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, INV-5)
  Result := Avail;
end;

end.
