unit nextpas.core.mem.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error;

type
  {**
   * @desc 固定大小 bump 分配器，分配只前进，Reset 一次性释放全部
   * @note 非线程安全。适用于请求/帧/文档等有限生命周期的场景
   *}
  TLocalArena = record
  private
    FBacking: Pointer;
    FCapacity: SizeUInt;
    FOffset: SizeUInt;
  public
    procedure Init(const ACapacity: SizeUInt);
    procedure Done;

    function Alloc(const ASize: SizeUInt): Pointer;
    function AllocAligned(const ASize: SizeUInt; const AAlign: SizeUInt): Pointer;
    procedure Reset;

    function Mark: TArenaMarker;
    procedure Restore(const AMarker: TArenaMarker);

    function BytesUsed: SizeUInt; inline;
    function BytesRemaining: SizeUInt; inline;
    function Capacity: SizeUInt; inline;
  end;

  TArena = TLocalArena;

implementation

function IsPowerOfTwo(const AValue: SizeUInt): Boolean; inline;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

{ TLocalArena }

procedure TLocalArena.Init(const ACapacity: SizeUInt);
begin
  FBacking := GetMem(ACapacity);
  if (ACapacity > 0) and (FBacking = nil) then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TLocalArena.Init: out of memory');
  FCapacity := ACapacity;
  FOffset := 0;
end;

procedure TLocalArena.Done;
begin
  if FBacking <> nil then
  begin
    FreeMem(FBacking);
    FBacking := nil;
  end;
  FCapacity := 0;
  FOffset := 0;
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
    Exit(nil);
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
    Exit(nil);
  Inc(FOffset, LPadding + ASize);
  Result := Pointer(LAligned);
end;

procedure TLocalArena.Reset;
begin
  FOffset := 0;
end;

function TLocalArena.Mark: TArenaMarker;
begin
  Result := FOffset;
end;

procedure TLocalArena.Restore(const AMarker: TArenaMarker);
begin
  if AMarker <= FOffset then
    FOffset := AMarker;
end;

function TLocalArena.BytesUsed: SizeUInt;
begin
  Result := FOffset;
end;

function TLocalArena.BytesRemaining: SizeUInt;
begin
  Result := FCapacity - FOffset;
end;

function TLocalArena.Capacity: SizeUInt;
begin
  Result := FCapacity;
end;

end.
