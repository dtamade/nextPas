unit nextpas.core.mem.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error;

type
  {**
   * @desc 固定大小 bump 分配器，分配只前进，Reset 一次性释放全部。
   *       以 class 实现以避免 owning record 的隐式复制 double-free 风险。
   * @note 非线程安全。适用于请求/帧/文档等有限生命周期的场景。
   *}
  TLocalArena = class
  private
    FBacking: Pointer;
    FCapacity: SizeUInt;
    FOffset: SizeUInt;
  public
    {** 创建 Arena 并分配 ACapacity 字节的后备内存。ACapacity=0 时不做分配。 }
    constructor Create(const ACapacity: SizeUInt);
    {** 释放后备内存。 }
    destructor Destroy; override;

    {** 从 Arena 分配 ASize 字节，返回指针；空间不足返回 nil。 }
    function Alloc(const ASize: SizeUInt): Pointer;
    {** 从 Arena 对齐分配 ASize 字节；对齐不是 2 的幂或空间不足返回 nil。 }
    function AllocAligned(const ASize: SizeUInt; const AAlign: SizeUInt): Pointer;
    {** 从 Arena 分配 ASize 字节并清零；空间不足返回 nil。 }
    function AllocZeroed(const ASize: SizeUInt): Pointer;
    {** 重置 Arena，所有已分配内存可重新使用。 }
    procedure Reset;

    {** 保存当前分配位置的标记，后续可用 RestoreToMark 回退。 }
    function SaveMark: TArenaMarker;
    {** 恢复到之前保存的标记位置。 }
    procedure RestoreToMark(const AMarker: TArenaMarker);

    {** 返回后备内存总字节数。 }
    function TotalSize: SizeUInt; inline;
    {** 返回已分配字节数。 }
    function UsedSize: SizeUInt; inline;
    {** 返回剩余可用字节数。 }
    function RemainingSize: SizeUInt; inline;
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

function TLocalArena.Alloc(const ASize: SizeUInt): Pointer;
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
end;

function TLocalArena.AllocAligned(const ASize: SizeUInt; const AAlign: SizeUInt): Pointer;
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
end;

function TLocalArena.AllocZeroed(const ASize: SizeUInt): Pointer;
begin
  Result := Alloc(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

procedure TLocalArena.Reset;
begin
  FOffset := 0;
end;

function TLocalArena.SaveMark: TArenaMarker;
begin
  Result := FOffset;
end;

procedure TLocalArena.RestoreToMark(const AMarker: TArenaMarker);
begin
  if AMarker <= FOffset then
    FOffset := AMarker;
end;

function TLocalArena.TotalSize: SizeUInt;
begin
  Result := FCapacity;
end;

function TLocalArena.UsedSize: SizeUInt;
begin
  Result := FOffset;
end;

function TLocalArena.RemainingSize: SizeUInt;
begin
  Result := FCapacity - FOffset;
end;

end.
