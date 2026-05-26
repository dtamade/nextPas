unit nextpas.core.mem.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

type
  {**
   * @desc 固定大小 bump 分配器，分配只前进，Reset 一次性释放全部
   * @note 非线程安全。适用于请求/帧/文档等有限生命周期的场景
   *}
  TArena = record
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

implementation

{ TArena }

procedure TArena.Init(const ACapacity: SizeUInt);
begin
  FBacking := GetMem(ACapacity);
  FCapacity := ACapacity;
  FOffset := 0;
end;

procedure TArena.Done;
begin
  if FBacking <> nil then
  begin
    FreeMem(FBacking);
    FBacking := nil;
  end;
  FCapacity := 0;
  FOffset := 0;
end;

function TArena.Alloc(const ASize: SizeUInt): Pointer;
begin
  if FOffset + ASize > FCapacity then
    Exit(nil);
  Result := FBacking + FOffset;
  Inc(FOffset, ASize);
end;

function TArena.AllocAligned(const ASize: SizeUInt; const AAlign: SizeUInt): Pointer;
var
  LAligned: SizeUInt;
  LPadding: SizeUInt;
begin
  LAligned := (SizeUInt(FBacking) + FOffset + AAlign - 1) and not (AAlign - 1);
  LPadding := LAligned - (SizeUInt(FBacking) + FOffset);
  if FOffset + LPadding + ASize > FCapacity then
    Exit(nil);
  Inc(FOffset, LPadding + ASize);
  Result := Pointer(LAligned);
end;

procedure TArena.Reset;
begin
  FOffset := 0;
end;

function TArena.Mark: TArenaMarker;
begin
  Result := FOffset;
end;

procedure TArena.Restore(const AMarker: TArenaMarker);
begin
  if AMarker <= FOffset then
    FOffset := AMarker;
end;

function TArena.BytesUsed: SizeUInt;
begin
  Result := FOffset;
end;

function TArena.BytesRemaining: SizeUInt;
begin
  Result := FCapacity - FOffset;
end;

function TArena.Capacity: SizeUInt;
begin
  Result := FCapacity;
end;

end.
