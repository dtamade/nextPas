unit nextpas.core.collections.vec;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.collections.base;

type
  generic TVec<T> = record
  private
    FItems: array of T;
    FCount: SizeUInt;
    procedure Grow;
    procedure EnsureCapacity(const AMinCapacity: SizeUInt);
    function GetItem(const AIndex: SizeUInt): T; inline;
    procedure SetItem(const AIndex: SizeUInt; const AValue: T); inline;
  public
    procedure Init;
    procedure Done;
    procedure Clear;

    function Add(const AValue: T): SizeUInt;
    procedure Insert(const AIndex: SizeUInt; const AValue: T);
    procedure Delete(const AIndex: SizeUInt);
    procedure DeleteSwap(const AIndex: SizeUInt);
    function Pop: T;

    procedure Reserve(const ACapacity: SizeUInt);
    procedure Shrink;

    function Contains(const AValue: T): Boolean;
    function IndexOf(const AValue: T): Int64;

    function ToArray: specialize TArray<T>;
    function Clone: specialize TVec<T>;

    function GetCount: SizeUInt; inline;
    function GetCapacity: SizeUInt; inline;
    function IsEmpty: Boolean; inline;

    property Items[const AIndex: SizeUInt]: T read GetItem write SetItem; default;
    property Count: SizeUInt read GetCount;
    property Capacity: SizeUInt read GetCapacity;
  end;

implementation

{ TVec<T> }

procedure TVec.Init;
begin
  FItems := nil;
  FCount := 0;
end;

procedure TVec.Done;
begin
  FItems := nil;
  FCount := 0;
end;

procedure TVec.Clear;
begin
  FCount := 0;
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

procedure TVec.EnsureCapacity(const AMinCapacity: SizeUInt);
begin
  if AMinCapacity > SizeUInt(Length(FItems)) then
    SetLength(FItems, AMinCapacity);
end;

function TVec.GetItem(const AIndex: SizeUInt): T;
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('TVec: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  Result := FItems[AIndex];
end;

procedure TVec.SetItem(const AIndex: SizeUInt; const AValue: T);
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('TVec: index %d out of range [0..%d]', [AIndex, FCount - 1]);
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
    raise EIndexOutOfRangeError.CreateFmt('TVec.Insert: index %d out of range [0..%d]', [AIndex, FCount]);
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
    raise EIndexOutOfRangeError.CreateFmt('TVec.Delete: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  for LI := AIndex to FCount - 2 do
    FItems[LI] := FItems[LI + 1];
  Dec(FCount);
  FItems[FCount] := Default(T);
end;

procedure TVec.DeleteSwap(const AIndex: SizeUInt);
begin
  if AIndex >= FCount then
    raise EIndexOutOfRangeError.CreateFmt('TVec.DeleteSwap: index %d out of range [0..%d]', [AIndex, FCount - 1]);
  Dec(FCount);
  if AIndex <> FCount then
    FItems[AIndex] := FItems[FCount];
  FItems[FCount] := Default(T);
end;

function TVec.Pop: T;
begin
  if FCount = 0 then
    raise EInvalidOperationError.Create('TVec.Pop: empty');
  Dec(FCount);
  Result := FItems[FCount];
  FItems[FCount] := Default(T);
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

function TVec.ToArray: specialize TArray<T>;
var
  LI: SizeUInt;
begin
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
    Result[LI] := FItems[LI];
end;

function TVec.Clone: specialize TVec<T>;
var
  LI: SizeUInt;
begin
  Result.Init;
  Result.Reserve(FCount);
  for LI := 0 to FCount - 1 do
    Result.Add(FItems[LI]);
end;

function TVec.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TVec.GetCapacity: SizeUInt;
begin
  Result := SizeUInt(Length(FItems));
end;

function TVec.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

end.
