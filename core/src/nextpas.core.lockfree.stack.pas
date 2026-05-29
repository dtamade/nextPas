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
    FTop: Int64;
    function PackTaggedPtr(APtr: PNode; ATag: UInt16): Int64; inline;
    function UnpackPtr(ATagged: Int64): PNode; inline;
    function UnpackTag(ATagged: Int64): UInt16; inline;
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

function TLockFreeStack.PackTaggedPtr(APtr: PNode; ATag: UInt16): Int64; inline;
begin
  Result := Int64(PtrUInt(APtr)) or (Int64(ATag) shl 48);
end;

function TLockFreeStack.UnpackPtr(ATagged: Int64): PNode; inline;
begin
  Result := PNode(PtrUInt(ATagged and $0000FFFFFFFFFFFF));
end;

function TLockFreeStack.UnpackTag(ATagged: Int64): UInt16; inline;
begin
  Result := UInt16((ATagged shr 48) and $FFFF);
end;

constructor TLockFreeStack.Create;
begin
  inherited Create;
  FTop := 0;
end;

destructor TLockFreeStack.Destroy;
var
  LNode, LNext: PNode;
begin
  LNode := UnpackPtr(FTop);
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
  LNode: PNode;
  LOldTagged, LNewTagged: Int64;
  LOldTag: UInt16;
begin
  New(LNode);
  LNode^.Value := AValue;
  repeat
    LOldTagged := AtomicLoad64(FTop, moAcquire);
    LNode^.Next := UnpackPtr(LOldTagged);
    LOldTag := UnpackTag(LOldTagged);
    LNewTagged := PackTaggedPtr(LNode, LOldTag + 1);
  until AtomicCompareExchange64(FTop, LOldTagged, LNewTagged, moAcqRel) = LOldTagged;
end;

function TLockFreeStack.TryPop(out AValue: T): Boolean;
var
  LOldTagged, LNewTagged: Int64;
  LOldNode: PNode;
  LOldTag: UInt16;
begin
  repeat
    LOldTagged := AtomicLoad64(FTop, moAcquire);
    LOldNode := UnpackPtr(LOldTagged);
    if LOldNode = nil then
      Exit(False);
    LOldTag := UnpackTag(LOldTagged);
    LNewTagged := PackTaggedPtr(LOldNode^.Next, LOldTag + 1);
  until AtomicCompareExchange64(FTop, LOldTagged, LNewTagged, moAcqRel) = LOldTagged;
  AValue := LOldNode^.Value;
  Dispose(LOldNode);
  Result := True;
end;

function TLockFreeStack.IsEmpty: Boolean;
begin
  Result := UnpackPtr(AtomicLoad64(FTop, moAcquire)) = nil;
end;

end.
