unit nextpas.core.lockfree.stack;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TLockFreeStack<T> = class
  private
    type
      TSlot = record
        Value: T;
        Next: Int32;
      end;
  private
    FSlots: array of TSlot;
    FCapacity: Int32;
    FTop: Int64;
    FFreeHead: Int64;
    function PackTagIdx(AIdx: Int32; ATag: UInt32): Int64; inline;
    function UnpackIdx(ATagged: Int64): Int32; inline;
    function UnpackTag(ATagged: Int64): UInt32; inline;
  public
    constructor Create(const ACapacity: PtrUInt);
    function TryPush(const AValue: T): Boolean;
    function TryPop(out AValue: T): Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

function TLockFreeStack.PackTagIdx(AIdx: Int32; ATag: UInt32): Int64; inline;
begin
  Result := Int64(UInt32(AIdx)) or (Int64(ATag) shl 32);
end;

function TLockFreeStack.UnpackIdx(ATagged: Int64): Int32; inline;
begin
  Result := Int32(ATagged and $FFFFFFFF);
end;

function TLockFreeStack.UnpackTag(ATagged: Int64): UInt32; inline;
begin
  Result := UInt32((ATagged shr 32) and $FFFFFFFF);
end;

constructor TLockFreeStack.Create(const ACapacity: PtrUInt);
var
  LI: Int32;
begin
  inherited Create;
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeStack: T must be unmanaged');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeStack: capacity must be > 0');
  FCapacity := Int32(ACapacity);
  SetLength(FSlots, FCapacity);
  for LI := 0 to FCapacity - 2 do
    FSlots[LI].Next := LI + 1;
  FSlots[FCapacity - 1].Next := -1;
  FTop := PackTagIdx(-1, 0);
  FFreeHead := PackTagIdx(0, 0);
end;

function TLockFreeStack.TryPush(const AValue: T): Boolean;
var
  LOldFree, LNewFree, LOldTop, LNewTop: Int64;
  LIdx: Int32;
begin
  repeat
    LOldFree := AtomicLoad64(FFreeHead, moAcquire);
    LIdx := UnpackIdx(LOldFree);
    if LIdx = -1 then
      Exit(False);
    LNewFree := PackTagIdx(FSlots[LIdx].Next, UnpackTag(LOldFree) + 1);
  until AtomicCompareExchange64(FFreeHead, LOldFree, LNewFree, moAcqRel) = LOldFree;

  FSlots[LIdx].Value := AValue;

  repeat
    LOldTop := AtomicLoad64(FTop, moAcquire);
    FSlots[LIdx].Next := UnpackIdx(LOldTop);
    LNewTop := PackTagIdx(LIdx, UnpackTag(LOldTop) + 1);
  until AtomicCompareExchange64(FTop, LOldTop, LNewTop, moAcqRel) = LOldTop;
  Result := True;
end;

function TLockFreeStack.TryPop(out AValue: T): Boolean;
var
  LOldTop, LNewTop, LOldFree, LNewFree: Int64;
  LIdx: Int32;
begin
  repeat
    LOldTop := AtomicLoad64(FTop, moAcquire);
    LIdx := UnpackIdx(LOldTop);
    if LIdx = -1 then
      Exit(False);
    LNewTop := PackTagIdx(FSlots[LIdx].Next, UnpackTag(LOldTop) + 1);
  until AtomicCompareExchange64(FTop, LOldTop, LNewTop, moAcqRel) = LOldTop;

  AValue := FSlots[LIdx].Value;
  FSlots[LIdx].Value := Default(T);

  repeat
    LOldFree := AtomicLoad64(FFreeHead, moAcquire);
    FSlots[LIdx].Next := UnpackIdx(LOldFree);
    LNewFree := PackTagIdx(LIdx, UnpackTag(LOldFree) + 1);
  until AtomicCompareExchange64(FFreeHead, LOldFree, LNewFree, moAcqRel) = LOldFree;
  Result := True;
end;

function TLockFreeStack.IsEmpty: Boolean;
begin
  Result := UnpackIdx(AtomicLoad64(FTop, moAcquire)) = -1;
end;

function TLockFreeStack.ApproxCount: PtrUInt;
var
  LIdx: Int32;
  LCount: PtrUInt;
begin
  LCount := 0;
  LIdx := UnpackIdx(AtomicLoad64(FTop, moAcquire));
  while LIdx <> -1 do
  begin
    Inc(LCount);
    if LCount > FCapacity then Break;
    LIdx := FSlots[LIdx].Next;
  end;
  Result := LCount;
end;

end.
