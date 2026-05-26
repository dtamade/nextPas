unit nextpas.core.collections.vec;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.mem.intf,
  nextpas.core.collections.base;

type
  generic IVec<T> = interface
    ['{A1B2C3D4-0001-0001-0001-000000000001}']
    function GetCount: SizeUInt;
    function GetCapacity: SizeUInt;
    function GetItem(const AIndex: SizeUInt): T;
    procedure SetItem(const AIndex: SizeUInt; const AValue: T);

    function Add(const AValue: T): SizeUInt;
    procedure Insert(const AIndex: SizeUInt; const AValue: T);
    procedure Delete(const AIndex: SizeUInt);
    procedure DeleteSwap(const AIndex: SizeUInt);
    function Pop: T;
    procedure Clear;

    procedure Reserve(const ACapacity: SizeUInt);
    procedure Shrink;

    function Contains(const AValue: T): Boolean;
    function IndexOf(const AValue: T): Int64;
    function IsEmpty: Boolean;

    function ToArray: specialize TArray<T>;

    property Items[const AIndex: SizeUInt]: T read GetItem write SetItem; default;
    property Count: SizeUInt read GetCount;
    property Capacity: SizeUInt read GetCapacity;
  end;

  generic TVec<T> = class(TInterfacedObject, specialize IVec<T>)
  private
    FItems: array of T;
    FCount: SizeUInt;
    FAllocator: IAllocator;
    procedure Grow;
  public
    constructor Create; overload;
    constructor Create(const ACapacity: SizeUInt); overload;
    constructor Create(const ACapacity: SizeUInt; const AAllocator: IAllocator); overload;
    destructor Destroy; override;

    function GetCount: SizeUInt;
    function GetCapacity: SizeUInt;
    function GetItem(const AIndex: SizeUInt): T;
    procedure SetItem(const AIndex: SizeUInt; const AValue: T);

    function Add(const AValue: T): SizeUInt;
    procedure Insert(const AIndex: SizeUInt; const AValue: T);
    procedure Delete(const AIndex: SizeUInt);
    procedure DeleteSwap(const AIndex: SizeUInt);
    function Pop: T;
    procedure Clear;

    procedure Reserve(const ACapacity: SizeUInt);
    procedure Shrink;

    function Contains(const AValue: T): Boolean;
    function IndexOf(const AValue: T): Int64;
    function IsEmpty: Boolean;

    function ToArray: specialize TArray<T>;

    property Allocator: IAllocator read FAllocator;
  end;

implementation

{ TVec<T> }

constructor TVec.Create;
begin
  inherited Create;
  FCount := 0;
  FAllocator := nil;
end;

constructor TVec.Create(const ACapacity: SizeUInt);
begin
  inherited Create;
  FCount := 0;
  FAllocator := nil;
  if ACapacity > 0 then
    SetLength(FItems, ACapacity);
end;

constructor TVec.Create(const ACapacity: SizeUInt; const AAllocator: IAllocator);
begin
  inherited Create;
  FCount := 0;
  FAllocator := AAllocator;
  if ACapacity > 0 then
    SetLength(FItems, ACapacity);
end;

destructor TVec.Destroy;
begin
  FItems := nil;
  FAllocator := nil;
  inherited;
end;

procedure TVec.Grow;
var
  LNewCap: SizeUInt;
begin
  LNewCap := SizeUInt(Length(FItems));
  if LNewCap = 0 then
    LNewCap := VEC_INITIAL_CAPACITY
  else if LNewCap < VEC_GROW_THRESHOLD then
    LNewCap := LNewCap * 2
  else
    LNewCap := LNewCap + LNewCap div 2;
  SetLength(FItems, LNewCap);
end;

function TVec.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TVec.GetCapacity: SizeUInt;
begin
  Result := SizeUInt(Length(FItems));
end;

function TVec.GetItem(const AIndex: SizeUInt): T;
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('IVec: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  Result := FItems[AIndex];
end;

procedure TVec.SetItem(const AIndex: SizeUInt; const AValue: T);
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('IVec: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  FItems[AIndex] := AValue;
end;

function TVec.Add(const AValue: T): SizeUInt;
begin
  if FCount >= SizeUInt(Length(FItems)) then
    Grow;
  FItems[FCount] := AValue;
  Result := FCount;
  Inc(FCount);
end;

procedure TVec.Insert(const AIndex: SizeUInt; const AValue: T);
var
  LI: SizeUInt;
begin
  if AIndex > FCount then
    raise EIndexOutOfRangeError.CreateFmt('IVec.Insert: index %d out of range [0..%d]', [AIndex, FCount]);
  if FCount >= SizeUInt(Length(FItems)) then
    Grow;
  LI := FCount;
  while LI > AIndex do
  begin
    FItems[LI] := FItems[LI - 1];
    Dec(LI);
  end;
  FItems[AIndex] := AValue;
  Inc(FCount);
end;

procedure TVec.Delete(const AIndex: SizeUInt);
var
  LI: SizeUInt;
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('IVec.Delete: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  for LI := AIndex to FCount - 2 do
    FItems[LI] := FItems[LI + 1];
  Dec(FCount);
  FItems[FCount] := Default(T);
end;

procedure TVec.DeleteSwap(const AIndex: SizeUInt);
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('IVec.DeleteSwap: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  Dec(FCount);
  if AIndex <> FCount then
    FItems[AIndex] := FItems[FCount];
  FItems[FCount] := Default(T);
end;

function TVec.Pop: T;
begin
  if FCount = 0 then
    raise EInvalidOperationError.Create('IVec.Pop: empty');
  Dec(FCount);
  Result := FItems[FCount];
  FItems[FCount] := Default(T);
end;

procedure TVec.Clear;
begin
  FCount := 0;
end;

procedure TVec.Reserve(const ACapacity: SizeUInt);
begin
  if ACapacity > SizeUInt(Length(FItems)) then
    SetLength(FItems, ACapacity);
end;

procedure TVec.Shrink;
begin
  if FCount < SizeUInt(Length(FItems)) then
    SetLength(FItems, FCount);
end;

function TVec.Contains(const AValue: T): Boolean;
var
  LI: SizeUInt;
begin
  for LI := 0 to FCount - 1 do
    if FItems[LI] = AValue then
      Exit(True);
  Result := False;
end;

function TVec.IndexOf(const AValue: T): Int64;
var
  LI: SizeUInt;
begin
  for LI := 0 to FCount - 1 do
    if FItems[LI] = AValue then
      Exit(Int64(LI));
  Result := -1;
end;

function TVec.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

function TVec.ToArray: specialize TArray<T>;
var
  LI: SizeUInt;
begin
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
    Result[LI] := FItems[LI];
end;

end.
