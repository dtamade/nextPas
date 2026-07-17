unit nextpas.core.lockfree.stack;
{**
 * @desc Lock-free bounded LIFO stack.
 *
 * @details Array-based stack with free-list recycling:
 *   - Bounded capacity
 *   - Non-blocking TryPush/TryPop
 *   - Close semantics with drain support
 *   - Cache-line padding for producer/consumer separation
 *
 * @concurrency Thread-safe for multiple threads:
 *   - TryPush: multiple threads compete via CAS
 *   - TryPop: multiple threads compete via CAS
 *   - Close: safe to call from any thread
 *
 * @see Treiber Stack — classic lock-free stack
 * @see Lock-free data structures — CAS-based algorithms
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TLockFreeStackImpl<T> = class
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
    {$PUSH} {$WARN 05029 OFF}
    FPadTop: TCacheLinePad;
    {$POP}
    FFreeHead: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadFree: TCacheLinePad;
    {$POP}
    FCount: Int64;
    FClosed: Int32;
    function PackTagIdx(AIdx: Int32; ATag: UInt32): Int64; inline;
    function UnpackIdx(ATagged: Int64): Int32; inline;
    function UnpackTag(ATagged: Int64): UInt32; inline;
  public
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;
    function TryPush(const AValue: T): Boolean;
    {** @desc 非阻塞压栈并返回失败原因（full vs closed）；成功 AError=lfteNone }
    function TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function TryPop(out AValue: T): Boolean;
    {** @desc 非阻塞弹栈并返回失败原因（empty vs closed-empty）；成功 AError=lfteNone }
    function TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function Drain(const AMaxCount: PtrUInt = High(PtrUInt)): PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
  end;

  generic TLockFreeStack<T> = class(specialize TLockFreeStackImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

function TLockFreeStackImpl.PackTagIdx(AIdx: Int32; ATag: UInt32): Int64; inline;
begin
  Result := Int64(UInt32(AIdx)) or (Int64(ATag) shl 32);
end;

function TLockFreeStackImpl.UnpackIdx(ATagged: Int64): Int32; inline;
begin
  Result := Int32(ATagged and $FFFFFFFF);
end;

function TLockFreeStackImpl.UnpackTag(ATagged: Int64): UInt32; inline;
begin
  Result := UInt32((ATagged shr 32) and $FFFFFFFF);
end;

constructor TLockFreeStackImpl.Create(const ACapacity: PtrUInt);
var
  LI: Int32;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeStack: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeStack: capacity must be > 0');
  if ACapacity > PtrUInt(High(Int32)) then
    raise EArgumentError.Create('TLockFreeStack: capacity exceeds 32-bit slot index limit');
  inherited Create;
  FCapacity := Int32(ACapacity);
  SetLength(FSlots, FCapacity);
  for LI := 0 to FCapacity - 2 do
    FSlots[LI].Next := LI + 1;
  FSlots[FCapacity - 1].Next := -1;
  FTop := PackTagIdx(-1, 0);
  FFreeHead := PackTagIdx(0, 0);
  FCount := 0;
  FClosed := 0;
end;

function TLockFreeStackImpl.TryPush(const AValue: T): Boolean;
var
  LOldFree, LNewFree, LOldTop, LNewTop: Int64;
  LIdx: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  repeat
    LOldFree := AtomicLoad64(FFreeHead, moAcquire);
    LIdx := UnpackIdx(LOldFree);
    if LIdx = -1 then
      Exit(False);
    LNewFree := PackTagIdx(FSlots[LIdx].Next, UnpackTag(LOldFree) + 1);
  until AtomicCompareExchange64(FFreeHead, LOldFree, LNewFree, moAcqRel) = LOldFree;

  AtomicFetchAdd64(FCount, 1, moRelaxed);
  FSlots[LIdx].Value := AValue;

  repeat
    LOldTop := AtomicLoad64(FTop, moAcquire);
    FSlots[LIdx].Next := UnpackIdx(LOldTop);
    LNewTop := PackTagIdx(LIdx, UnpackTag(LOldTop) + 1);
  until AtomicCompareExchange64(FTop, LOldTop, LNewTop, moAcqRel) = LOldTop;
  Result := True;
end;

function TLockFreeStackImpl.TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryPush(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteFull;
  Result := False;
end;

function TLockFreeStackImpl.TryPop(out AValue: T): Boolean;
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

  AtomicFetchSub64(FCount, 1, moRelaxed);
  AValue := FSlots[LIdx].Value;
  FSlots[LIdx].Value := Default(T);

  repeat
    LOldFree := AtomicLoad64(FFreeHead, moAcquire);
    FSlots[LIdx].Next := UnpackIdx(LOldFree);
    LNewFree := PackTagIdx(LIdx, UnpackTag(LOldFree) + 1);
  until AtomicCompareExchange64(FFreeHead, LOldFree, LNewFree, moAcqRel) = LOldFree;
  Result := True;
end;

function TLockFreeStackImpl.TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryPop(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteEmpty;
  Result := False;
end;

function TLockFreeStackImpl.IsEmpty: Boolean;
begin
  Result := UnpackIdx(AtomicLoad64(FTop, moAcquire)) = -1;
end;

function TLockFreeStackImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
var
  LValue: T;
  LCount: PtrUInt;
begin
  LCount := 0;
  while LCount < AMaxCount do
  begin
    if not TryPop(LValue) then
      Break;
    Inc(LCount);
  end;
  Result := LCount;
end;

procedure TLockFreeStackImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

destructor TLockFreeStackImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TLockFreeStackImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLockFreeStackImpl.ApproxCount: PtrUInt;
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
