unit nextpas.core.mem.arena.local;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf;

type
  {** TLocalArena
   *
   *  固定大小 bump 分配器，分配只前进，Reset 一次性释放全部。
   *  实现 IArena 接口，支持引用计数。
   *
   *  非线程安全。适用于请求/帧/文档等有限生命周期的场景。
   *}
  TLocalArena = class(TInterfacedObject, IArena)
  private
    FBacking: Pointer;
    FCapacity: SizeUInt;
    FOffset: SizeUInt;
    FPeakUsed: SizeUInt;
    FTotalAllocs: SizeUInt;
  public
    {** 创建 Arena 并分配 ACapacity 字节的后备内存。ACapacity=0 时不做分配。 }
    constructor Create(const ACapacity: SizeUInt);
    {** 释放后备内存。 }
    destructor Destroy; override;

    { IArena }
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(AMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;

    {** 快速分配（无检查版本，极致性能）。 }
    function AllocFast(ASize: SizeUInt): Pointer; inline;
    {** 快速对齐分配（无检查版本，极致性能）。 }
    function AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer; inline;

    {** 返回峰值使用量。 }
    property PeakUsed: SizeUInt read FPeakUsed;
    {** 返回总分配次数。 }
    property TotalAllocCount: SizeUInt read FTotalAllocs;
    {** 返回 Arena 总容量。 }
    property Capacity: SizeUInt read FCapacity;
  end;

implementation

{ TLocalArena }

constructor TLocalArena.Create(const ACapacity: SizeUInt);
begin
  inherited Create;
  if ACapacity > 0 then
  begin
    FBacking := GetMem(ACapacity);
    if FBacking = nil then
      raise EOutOfMemory.Create(aeOutOfMemory, 'TLocalArena.Create: out of memory');
  end
  else
    FBacking := nil;
  FCapacity := ACapacity;
  FOffset := 0;
  FPeakUsed := 0;
  FTotalAllocs := 0;
end;

destructor TLocalArena.Destroy;
begin
  if FBacking <> nil then
  begin
    FreeMem(FBacking);
    FBacking := nil;
  end;
  FCapacity := 0;
  FOffset := 0;
  inherited;
end;

function TLocalArena.Alloc(ASize: SizeUInt): Pointer;
var
  LRemaining: SizeUInt;
begin
  Result := nil;
  if (ASize = 0) or (FBacking = nil) then
    Exit;
  if FOffset > FCapacity then
    Exit;
  LRemaining := FCapacity - FOffset;
  if ASize > LRemaining then
    Exit;
  Result := Pointer(PtrUInt(FBacking) + FOffset);
  Inc(FOffset, ASize);
  Inc(FTotalAllocs);
  if FOffset > FPeakUsed then
    FPeakUsed := FOffset;
end;

function TLocalArena.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
var
  LCurrent: PtrUInt;
  LAligned: SizeUInt;
  LPadding: SizeUInt;
  LRemaining: SizeUInt;
  LMask: SizeUInt;
begin
  Result := nil;
  if (ASize = 0) or (FBacking = nil) then
    Exit;
  if not IsPowerOfTwo(AAlign) then
    Exit;
  if FOffset > FCapacity then
    Exit;
  if PtrUInt(FBacking) > High(PtrUInt) - FOffset then
    Exit;

  LCurrent := PtrUInt(FBacking) + FOffset;
  LMask := AAlign - 1;
  if LCurrent > High(PtrUInt) - LMask then
    Exit;

  LAligned := (LCurrent + LMask) and not LMask;
  LPadding := LAligned - LCurrent;
  LRemaining := FCapacity - FOffset;
  if LPadding > LRemaining then
    Exit;
  if ASize > LRemaining - LPadding then
    Exit;
  Inc(FOffset, LPadding + ASize);
  Result := Pointer(LAligned);
  Inc(FTotalAllocs);
  if FOffset > FPeakUsed then
    FPeakUsed := FOffset;
end;

function TLocalArena.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  Result := Alloc(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TLocalArena.AllocFast(ASize: SizeUInt): Pointer;
begin
  {$IFDEF DEBUG}
  Assert(FBacking <> nil, 'AllocFast: FBacking is nil');
  Assert(ASize > 0, 'AllocFast: ASize = 0');
  Assert(FOffset <= FCapacity, 'AllocFast: FOffset > FCapacity');
  Assert(ASize <= FCapacity - FOffset, 'AllocFast: ASize exceeds remaining capacity');
  {$ENDIF}
  Result := Pointer(PtrUInt(FBacking) + FOffset);
  Inc(FOffset, ASize);
end;

function TLocalArena.AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer;
var
  LCurrent: PtrUInt;
  LAligned: SizeUInt;
  LMask: SizeUInt;
begin
  {$IFDEF DEBUG}
  Assert(FBacking <> nil, 'AllocAlignedFast: FBacking is nil');
  Assert(ASize > 0, 'AllocAlignedFast: ASize = 0');
  Assert(AAlign > 0, 'AllocAlignedFast: AAlign = 0');
  Assert(IsPowerOfTwo(AAlign), 'AllocAlignedFast: AAlign is not power of two');
  Assert(FOffset <= FCapacity, 'AllocAlignedFast: FOffset > FCapacity');
  {$ENDIF}
  LCurrent := PtrUInt(FBacking) + FOffset;
  LMask := AAlign - 1;
  LAligned := (LCurrent + LMask) and not LMask;
  Inc(FOffset, (LAligned - LCurrent) + ASize);
  Result := Pointer(LAligned);
end;

function TLocalArena.SaveMark: TArenaMark;
begin
  Result.FrontOffset := FOffset;
  Result.BackOffset := 0;
  Result.TotalUsed := FOffset;
end;

procedure TLocalArena.RestoreToMark(AMark: TArenaMark);
begin
  if AMark.FrontOffset <= FOffset then
    FOffset := AMark.FrontOffset;
end;

procedure TLocalArena.Reset;
begin
  FOffset := 0;
  { 注意：FPeakUsed 和 FTotalAllocs 不重置，保留统计信息 }
end;

function TLocalArena.UsedSize: SizeUInt;
begin
  Result := FOffset;
end;

function TLocalArena.RemainingSize: SizeUInt;
begin
  Result := FCapacity - FOffset;
end;

function TLocalArena.Stats: TArenaStats;
begin
  Result.TotalAllocated := FCapacity;
  Result.TotalUsed := FOffset;
  Result.PeakUsed := FPeakUsed;
  Result.AllocCount := FTotalAllocs;
end;

end.
