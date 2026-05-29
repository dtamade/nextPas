unit nextpas.core.lockfree.stack;

{$I nextpas.core.settings.inc}

interface

type
  generic TLockFreeStack<T> = class
  private
    type
      PNode = ^TNode;
      TNode = record
        Value: T;
        Next: PNode;
      end;
  private
    FTop: PNode;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(const AValue: T);
    function TryPop(out AValue: T): Boolean;
    function IsEmpty: Boolean;
  end;

implementation

uses
  nextpas.core.atomic;

constructor TLockFreeStack.Create;
begin
  inherited Create;
  FTop := nil;
end;

destructor TLockFreeStack.Destroy;
var
  LNode, LNext: PNode;
begin
  LNode := FTop;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    Dispose(LNode);
    LNode := LNext;
  end;
  inherited;
end;

procedure TLockFreeStack.Push(const AValue: T);
var
  LNode, LOldTop: PNode;
begin
  New(LNode);
  LNode^.Value := AValue;
  repeat
    LOldTop := PNode(PtrUInt(AtomicLoad64(Int64(PtrUInt(FTop)), moAcquire)));
    LNode^.Next := LOldTop;
  until PNode(PtrUInt(AtomicCompareExchange64(
    Int64(PtrUInt(FTop)), Int64(PtrUInt(LOldTop)), Int64(PtrUInt(LNode)), moAcqRel)))
    = LOldTop;
end;

function TLockFreeStack.TryPop(out AValue: T): Boolean;
var
  LOldTop, LNext: PNode;
begin
  repeat
    LOldTop := PNode(PtrUInt(AtomicLoad64(Int64(PtrUInt(FTop)), moAcquire)));
    if LOldTop = nil then
      Exit(False);
    LNext := LOldTop^.Next;
  until PNode(PtrUInt(AtomicCompareExchange64(
    Int64(PtrUInt(FTop)), Int64(PtrUInt(LOldTop)), Int64(PtrUInt(LNext)), moAcqRel)))
    = LOldTop;
  AValue := LOldTop^.Value;
  Dispose(LOldTop);
  Result := True;
end;

function TLockFreeStack.IsEmpty: Boolean;
begin
  Result := PNode(PtrUInt(AtomicLoad64(Int64(PtrUInt(FTop)), moAcquire))) = nil;
end;

end.
