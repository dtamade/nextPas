unit nextpas.core.lockfree.segqueue;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.ebr;

const
  SEGQUEUE_SEGMENT_CAPACITY = 32;

type
  generic TSegQueueImpl<T> = class
  private type
    TSegSlot = record
      Sequence: Int64;
      Value: T;
    end;

    PSegment = ^TSegment;
    TSegment = record
      Next: PSegment;
      StartIndex: Int64;
      Slots: array[0..SEGQUEUE_SEGMENT_CAPACITY - 1] of TSegSlot;
    end;
  private
    FHead: PSegment;
    FTail: PSegment;
    FEnqueuePos: Int64;
    FDequeuePos: Int64;
    FEbr: TEbrDomain;
    class procedure SegQueueReclaimSegment(const AData: Pointer; const AUserData: Pointer); static;
    class function AllocSegment(const AStartIndex: Int64): PSegment; static;
  public
    {** @desc 创建无界 MPSC 队列（EBR 回收段） }
    constructor Create;
    destructor Destroy; override;
    {** @desc 无界入队；段不足时自动扩展 }
    procedure Enqueue(const AValue: T);
    {** @desc 非阻塞出队；队列空时返回 False }
    function TryDequeue(out AValue: T): Boolean;
    {** @desc 近似空判断 }
    function IsEmpty: Boolean;
    {** @desc 近似计数 }
    function ApproxCount: PtrUInt;
  end;

  generic TSegQueue<T> = class(specialize TSegQueueImpl<T>)
  end;

implementation

class function TSegQueueImpl.AllocSegment(const AStartIndex: Int64): PSegment;
var
  LI: Integer;
begin
  Result := GetMem(SizeOf(TSegment));
  FillChar(Result^, SizeOf(TSegment), 0);
  Result^.StartIndex := AStartIndex;
  for LI := 0 to SEGQUEUE_SEGMENT_CAPACITY - 1 do
    Result^.Slots[LI].Sequence := AStartIndex + LI;
end;

constructor TSegQueueImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TSegQueue: T must be unmanaged');
  inherited Create;
  FEbr := TEbrDomain.Create;
  FHead := AllocSegment(0);
  FTail := FHead;
  FEnqueuePos := 0;
  FDequeuePos := 0;
end;

destructor TSegQueueImpl.Destroy;
var
  LSeg: PSegment;
  LNext: PSegment;
begin
  LSeg := FHead;
  while LSeg <> nil do
  begin
    LNext := LSeg^.Next;
    FreeMem(LSeg);
    LSeg := LNext;
  end;
  FEbr.Free;
  inherited;
end;

class procedure TSegQueueImpl.SegQueueReclaimSegment(const AData: Pointer; const AUserData: Pointer);
begin
  FreeMem(AData);
end;

procedure TSegQueueImpl.Enqueue(const AValue: T);
var
  LPos: Int64;
  LIdx: Integer;
  LSeg: PSegment;
  LNext: PSegment;
  LNewSeg: PSegment;
  LGuard: TEbrGuard;
begin
  LPos := AtomicFetchAdd64(FEnqueuePos, 1, moRelaxed);
  LIdx := Integer(LPos mod SEGQUEUE_SEGMENT_CAPACITY);

  LGuard := TEbrGuard.Acquire(FEbr);
  try
    LSeg := PSegment(AtomicLoadPtr(Pointer(FHead), moAcquire));

    while (LSeg^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) <= LPos do
    begin
      LNext := PSegment(AtomicLoadPtr(Pointer(LSeg^.Next), moAcquire));
      if LNext = nil then
      begin
        LNewSeg := AllocSegment(LSeg^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY);
        if AtomicCompareExchangePtr(Pointer(LSeg^.Next), nil, LNewSeg, moRelease) = nil then
          LNext := LNewSeg
        else
        begin
          FreeMem(LNewSeg);
          LNext := PSegment(AtomicLoadPtr(Pointer(LSeg^.Next), moAcquire));
        end;
      end;

      AtomicCompareExchangePtr(Pointer(FTail), LSeg, LNext, moRelease);
      LSeg := LNext;
    end;

    LSeg^.Slots[LIdx].Value := AValue;
    AtomicStore64(LSeg^.Slots[LIdx].Sequence, LPos + 1, moRelease);
  finally
    LGuard.Release;
  end;
end;

function TSegQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: Integer;
  LSeg: PSegment;
  LNext: PSegment;
  LOldHead: PSegment;
  LSeq: Int64;
  LGuard: TEbrGuard;
begin
  while True do
  begin
    LPos := AtomicLoad64(FDequeuePos, moRelaxed);
    LGuard := TEbrGuard.Acquire(FEbr);
    try
      LSeg := PSegment(AtomicLoadPtr(Pointer(FHead), moAcquire));
      while (LSeg <> nil) and ((LSeg^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) <= LPos) do
      begin
        LOldHead := LSeg;
        LNext := PSegment(AtomicLoadPtr(Pointer(LSeg^.Next), moAcquire));
        if LNext = nil then
        begin
          Result := False;
          Exit;
        end;
        if AtomicCompareExchangePtr(Pointer(FHead), LOldHead, LNext, moAcqRel) = LOldHead then
        begin
          AtomicCompareExchangePtr(Pointer(FTail), LOldHead, LNext, moRelease);
          FEbr.Retire(LOldHead, @SegQueueReclaimSegment);
          LSeg := LNext;
        end
        else
          LSeg := PSegment(AtomicLoadPtr(Pointer(FHead), moAcquire));
      end;

      if LSeg = nil then
      begin
        Result := False;
        Exit;
      end;

      LIdx := Integer(LPos mod SEGQUEUE_SEGMENT_CAPACITY);
      LSeq := AtomicLoad64(LSeg^.Slots[LIdx].Sequence, moAcquire);
      if LSeq = (LPos + 1) then
      begin
        if AtomicCompareExchange64(FDequeuePos, LPos, LPos + 1, moRelaxed) = LPos then
        begin
          AValue := LSeg^.Slots[LIdx].Value;
          LSeg^.Slots[LIdx].Value := Default(T);
          Result := True;
          Exit;
        end;
      end
      else if LSeq < (LPos + 1) then
      begin
        Result := False;
        Exit;
      end;
    finally
      LGuard.Release;
    end;
    CpuPause;
  end;
end;

function TSegQueueImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FEnqueuePos, moRelaxed) <= AtomicLoad64(FDequeuePos, moRelaxed);
end;

function TSegQueueImpl.ApproxCount: PtrUInt;
var
  LEnq: Int64;
  LDeq: Int64;
begin
  LEnq := AtomicLoad64(FEnqueuePos, moRelaxed);
  LDeq := AtomicLoad64(FDequeuePos, moRelaxed);
  if LEnq > LDeq then
    Result := PtrUInt(LEnq - LDeq)
  else
    Result := 0;
end;

end.
