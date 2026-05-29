unit nextpas.core.lockfree.deque;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TWorkStealingDeque<T> = class
  private
    type
      TItemArray = array of T;
  private
    FBuffer: TItemArray;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FTop: Int64;
    FBottom: Int64;
  public
    constructor Create(const ACapacity: PtrUInt);
    procedure Push(const AValue: T);
    function TryPop(out AValue: T): Boolean;
    function TrySteal(out AValue: T): Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
    function Capacity: PtrUInt;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TWorkStealingDeque.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
begin
  inherited Create;
  if ACapacity = 0 then
    raise EArgumentError.Create('TWorkStealingDeque: capacity must be > 0');
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FBuffer, LCap);
  FTop := 0;
  FBottom := 0;
end;

procedure TWorkStealingDeque.Push(const AValue: T);
var
  LBottom: Int64;
begin
  LBottom := AtomicLoad64(FBottom, moRelaxed);
  FBuffer[PtrUInt(LBottom) and FMask] := AValue;
  AtomicStore64(FBottom, LBottom + 1, moRelease);
end;

function TWorkStealingDeque.TryPop(out AValue: T): Boolean;
var
  LBottom, LTop: Int64;
begin
  LBottom := AtomicLoad64(FBottom, moRelaxed) - 1;
  AtomicStore64(FBottom, LBottom, moRelaxed);
  LTop := AtomicLoad64(FTop, moAcquire);
  if LTop <= LBottom then
  begin
    AValue := FBuffer[PtrUInt(LBottom) and FMask];
    if LTop = LBottom then
    begin
      if AtomicCompareExchange64(FTop, LTop, LTop + 1, moAcqRel) <> LTop then
      begin
        AtomicStore64(FBottom, LBottom + 1, moRelaxed);
        Exit(False);
      end;
      AtomicStore64(FBottom, LBottom + 1, moRelaxed);
    end;
    Result := True;
  end
  else
  begin
    AtomicStore64(FBottom, LBottom + 1, moRelaxed);
    Result := False;
  end;
end;

function TWorkStealingDeque.TrySteal(out AValue: T): Boolean;
var
  LTop, LBottom: Int64;
begin
  LTop := AtomicLoad64(FTop, moAcquire);
  LBottom := AtomicLoad64(FBottom, moAcquire);
  if LTop >= LBottom then
    Exit(False);
  AValue := FBuffer[PtrUInt(LTop) and FMask];
  if AtomicCompareExchange64(FTop, LTop, LTop + 1, moAcqRel) <> LTop then
    Exit(False);
  Result := True;
end;

function TWorkStealingDeque.IsEmpty: Boolean;
var
  LTop, LBottom: Int64;
begin
  LTop := AtomicLoad64(FTop, moAcquire);
  LBottom := AtomicLoad64(FBottom, moAcquire);
  Result := LTop >= LBottom;
end;

function TWorkStealingDeque.ApproxCount: PtrUInt;
var
  LTop, LBottom: Int64;
begin
  LTop := AtomicLoad64(FTop, moAcquire);
  LBottom := AtomicLoad64(FBottom, moAcquire);
  if LBottom > LTop then
    Result := PtrUInt(LBottom - LTop)
  else
    Result := 0;
end;

function TWorkStealingDeque.Capacity: PtrUInt;
begin
  Result := FCapacity;
end;

end.
