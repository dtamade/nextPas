unit nextpas.core.collections.stack;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.stack.intf,
  nextpas.core.collections.vec;

type
  generic TStack<T> = class(TInterfacedObject, specialize IStack<T>)
  type
    PElement = ^T;
    TInternalVec = specialize TVec<T>;
  private
    FVec: TInternalVec;

  public
    constructor Create(const aAllocator: IAllocator = nil);
    destructor Destroy; override;

    { IStack implementation }
    procedure Push(const aElement: T); overload;
    procedure Push(const aSrc: array of T); overload;
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    function Pop(out aElement: T): Boolean; overload;
    function Pop: T; overload;

    function TryPeek(out aElement: T): Boolean; overload;
    function Peek: T; overload;

    function IsEmpty: Boolean;
    procedure Clear;
    function Count: SizeUInt;
  end;

  generic function MakeStack<T>: specialize IStack<T>;
  generic function MakeStack<T>(const aSrc: array of T): specialize IStack<T>;
  generic function MakeStack<T>(const aAllocator: IAllocator): specialize IStack<T>;

implementation

{ TStack<T> }

constructor TStack.Create(const aAllocator: IAllocator = nil);
begin
  inherited Create;
  if aAllocator <> nil then
    FVec := TInternalVec.Create(aAllocator)
  else
    FVec := TInternalVec.Create(GetRtlAllocator);
end;

destructor TStack.Destroy;
begin
  FVec.Free;
  inherited Destroy;
end;

procedure TStack.Push(const aElement: T);
begin
  FVec.Push(aElement);
end;

procedure TStack.Push(const aSrc: array of T);
begin
  FVec.Push(aSrc);
end;

procedure TStack.Push(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LIdx: SizeUInt;
  LElement: T;
begin
  for LIdx := 0 to aElementCount - 1 do
  begin
    LElement := PElement(aSrc)[LIdx];
    FVec.Push(LElement);
  end;
end;

function TStack.Pop(out aElement: T): Boolean;
begin
  Result := FVec.TryPop(aElement);
end;

function TStack.Pop: T;
begin
  if FVec.IsEmpty then
    raise EEmptyCollection.Create('TStack.Pop: collection is empty');
  Result := FVec.Pop;
end;

function TStack.TryPeek(out aElement: T): Boolean;
begin
  Result := FVec.TryPeek(aElement);
end;

function TStack.Peek: T;
begin
  if FVec.IsEmpty then
    raise EEmptyCollection.Create('TStack.Peek: collection is empty');
  Result := FVec.Peek;
end;

function TStack.IsEmpty: Boolean;
begin
  Result := FVec.IsEmpty;
end;

procedure TStack.Clear;
begin
  FVec.Clear;
end;

function TStack.Count: SizeUInt;
begin
  Result := FVec.Count;
end;

{ MakeStack factories }

generic function MakeStack<T>: specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
begin
  Result := TStackImpl.Create;
end;

generic function MakeStack<T>(const aSrc: array of T): specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create;
  try
    LStack.Push(aSrc);
    Result := LStack;
  except
    LStack.Free;
    raise;
  end;
end;

generic function MakeStack<T>(const aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
begin
  Result := TStackImpl.Create(aAllocator);
end;

end.
