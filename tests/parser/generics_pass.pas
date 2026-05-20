program Generics_pass;

{$mode objfpc}{$H+}

type
  generic TStack<T> = class
  private
    FItems: array of T;
    FCount: Integer;
  public
    constructor Create;
    procedure Push(const AItem: T);
    function Pop: T;
    function Peek: T;
    function IsEmpty: Boolean;
    property Count: Integer read FCount;
  end;

constructor TStack.Create;
begin
  FCount := 0;
  SetLength(FItems, 4);
end;

procedure TStack.Push(const AItem: T);
begin
  if FCount >= Length(FItems) then
    SetLength(FItems, Length(FItems) * 2);
  FItems[FCount] := AItem;
  Inc(FCount);
end;

function TStack.Pop: T;
begin
  Dec(FCount);
  Result := FItems[FCount];
end;

function TStack.Peek: T;
begin
  Result := FItems[FCount - 1];
end;

function TStack.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

type
  TIntStack = specialize TStack<Integer>;
  TStrStack = specialize TStack<string>;

var
  S: TIntStack;
  V: Integer;
begin
  S := TIntStack.Create;
  try
    S.Push(10);
    S.Push(20);
    S.Push(30);
    V := S.Pop;
    V := S.Peek;
  finally
    S.Free;
  end;
end.
