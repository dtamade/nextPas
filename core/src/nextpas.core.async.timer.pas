unit nextpas.core.async.timer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.async.base;

type
  TTimerEntry = record
    Deadline: TDeadline;
    Callback: TAsyncCallback;
    Context: Pointer;
    Gen: UInt32;
    Cancelled: Boolean;
    NextFree: Int32;
  end;

  TTimerHeap = record
  private
    FEntries: array of TTimerEntry;
    FHeap: array of UInt32;
    FHeapCount: UInt32;
    FEntryCap: UInt32;
    FEntryCount: UInt32;
    FFreeHead: Int32;
    FNextGen: UInt32;
    procedure SiftUp(AIdx: UInt32);
    procedure SiftDown(AIdx: UInt32);
    function HeapParent(AIdx: UInt32): UInt32; inline;
    function HeapLeft(AIdx: UInt32): UInt32; inline;
    function HeapRight(AIdx: UInt32): UInt32; inline;
    function IsBefore(A, B: UInt32): Boolean; inline;
    procedure SwapHeap(A, B: UInt32); inline;
    function AllocEntry: UInt32;
  public
    class function Create: TTimerHeap; static;
    procedure Clear;
    function Schedule(const ADeadline: TDeadline; ACallback: TAsyncCallback;
      AContext: Pointer): TAsyncTimerHandle;
    function ScheduleAfter(const ADelay: TDuration; ACallback: TAsyncCallback;
      AContext: Pointer): TAsyncTimerHandle;
    function Cancel(const AHandle: TAsyncTimerHandle): Boolean;
    function NextDeadline: TDeadline;
    function FireExpired: UInt32;
    function Count: UInt32; inline;
  end;

implementation

const
  INITIAL_CAP = 16;

{ TTimerHeap }

class function TTimerHeap.Create: TTimerHeap;
begin
  Result := Default(TTimerHeap);
  Result.FEntryCap := INITIAL_CAP;
  SetLength(Result.FEntries, INITIAL_CAP);
  SetLength(Result.FHeap, INITIAL_CAP);
  Result.FHeapCount := 0;
  Result.FEntryCount := 0;
  Result.FFreeHead := -1;
  Result.FNextGen := 1;
end;

function TTimerHeap.HeapParent(AIdx: UInt32): UInt32;
begin
  Result := (AIdx - 1) div 2;
end;

function TTimerHeap.HeapLeft(AIdx: UInt32): UInt32;
begin
  Result := AIdx * 2 + 1;
end;

function TTimerHeap.HeapRight(AIdx: UInt32): UInt32;
begin
  Result := AIdx * 2 + 2;
end;

function TTimerHeap.IsBefore(A, B: UInt32): Boolean;
var
  LInstA, LInstB: TInstant;
  LHasA, LHasB: Boolean;
begin
  LHasA := FEntries[A].Deadline.ToInstant(LInstA);
  LHasB := FEntries[B].Deadline.ToInstant(LInstB);
  if (not LHasA) and (not LHasB) then
    Exit(False);
  if not LHasA then
    Exit(False);
  if not LHasB then
    Exit(True);
  Result := LInstA < LInstB;
end;

procedure TTimerHeap.SwapHeap(A, B: UInt32);
var
  LTmp: UInt32;
begin
  LTmp := FHeap[A];
  FHeap[A] := FHeap[B];
  FHeap[B] := LTmp;
end;

procedure TTimerHeap.SiftUp(AIdx: UInt32);
var
  LParent: UInt32;
begin
  while AIdx > 0 do
  begin
    LParent := HeapParent(AIdx);
    if IsBefore(FHeap[AIdx], FHeap[LParent]) then
    begin
      SwapHeap(AIdx, LParent);
      AIdx := LParent;
    end
    else
      Break;
  end;
end;

procedure TTimerHeap.SiftDown(AIdx: UInt32);
var
  LSmallest, LLeft, LRight: UInt32;
begin
  while True do
  begin
    LSmallest := AIdx;
    LLeft := HeapLeft(AIdx);
    LRight := HeapRight(AIdx);
    if (LLeft < FHeapCount) and IsBefore(FHeap[LLeft], FHeap[LSmallest]) then
      LSmallest := LLeft;
    if (LRight < FHeapCount) and IsBefore(FHeap[LRight], FHeap[LSmallest]) then
      LSmallest := LRight;
    if LSmallest = AIdx then
      Break;
    SwapHeap(AIdx, LSmallest);
    AIdx := LSmallest;
  end;
end;

function TTimerHeap.AllocEntry: UInt32;
var
  LNewCap: UInt32;
begin
  if FFreeHead >= 0 then
  begin
    Result := UInt32(FFreeHead);
    FFreeHead := FEntries[Result].NextFree;
  end
  else
  begin
    if FEntryCount >= FEntryCap then
    begin
      if FEntryCap = 0 then
        LNewCap := INITIAL_CAP
      else
        LNewCap := FEntryCap * 2;
      SetLength(FEntries, LNewCap);
      SetLength(FHeap, LNewCap);
      FEntryCap := LNewCap;
    end;
    Result := FEntryCount;
    Inc(FEntryCount);
  end;
end;

procedure TTimerHeap.Clear;
begin
  SetLength(FEntries, 0);
  SetLength(FHeap, 0);
  FHeapCount := 0;
  FEntryCap := 0;
  FEntryCount := 0;
  FFreeHead := -1;
  if FNextGen = 0 then
    FNextGen := 1;
end;

function TTimerHeap.Schedule(const ADeadline: TDeadline; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
var
  LIdx: UInt32;
begin
  LIdx := AllocEntry;
  FEntries[LIdx].Deadline := ADeadline;
  FEntries[LIdx].Callback := ACallback;
  FEntries[LIdx].Context := AContext;
  FEntries[LIdx].Gen := FNextGen;
  FEntries[LIdx].Cancelled := False;
  FEntries[LIdx].NextFree := -1;

  Result.FId := LIdx;
  Result.FGen := FNextGen;
  Inc(FNextGen);
  if FNextGen = 0 then FNextGen := 1;

  FHeap[FHeapCount] := LIdx;
  Inc(FHeapCount);
  SiftUp(FHeapCount - 1);
end;

function TTimerHeap.ScheduleAfter(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  Result := Schedule(TDeadline.After(ADelay), ACallback, AContext);
end;

function TTimerHeap.Cancel(const AHandle: TAsyncTimerHandle): Boolean;
begin
  if not AHandle.IsValid then
    Exit(False);
  if AHandle.FId >= FEntryCount then
    Exit(False);
  if FEntries[AHandle.FId].Gen <> AHandle.FGen then
    Exit(False);
  if FEntries[AHandle.FId].Cancelled then
    Exit(False);
  FEntries[AHandle.FId].Cancelled := True;
  Result := True;
end;

function TTimerHeap.NextDeadline: TDeadline;
var
  LI: UInt32;
begin
  { Skip cancelled entries at the top }
  while (FHeapCount > 0) and FEntries[FHeap[0]].Cancelled do
  begin
    { Pop cancelled entry and recycle }
    LI := FHeap[0];
    Dec(FHeapCount);
    if FHeapCount > 0 then
    begin
      FHeap[0] := FHeap[FHeapCount];
      SiftDown(0);
    end;
    FEntries[LI].NextFree := FFreeHead;
    FFreeHead := Int32(LI);
  end;
  if FHeapCount = 0 then
    Result := TDeadline.Infinite
  else
    Result := FEntries[FHeap[0]].Deadline;
end;

function TTimerHeap.FireExpired: UInt32;
var
  LIdx: UInt32;
  LCb: TAsyncCallback;
  LCtx: Pointer;
begin
  Result := 0;
  while FHeapCount > 0 do
  begin
    LIdx := FHeap[0];
    { Skip cancelled }
    if FEntries[LIdx].Cancelled then
    begin
      Dec(FHeapCount);
      if FHeapCount > 0 then
      begin
        FHeap[0] := FHeap[FHeapCount];
        SiftDown(0);
      end;
      FEntries[LIdx].NextFree := FFreeHead;
      FFreeHead := Int32(LIdx);
      Continue;
    end;
    { Check if expired }
    if not FEntries[LIdx].Deadline.IsExpired then
      Break;
    { Pop and fire }
    LCb := FEntries[LIdx].Callback;
    LCtx := FEntries[LIdx].Context;
    Dec(FHeapCount);
    if FHeapCount > 0 then
    begin
      FHeap[0] := FHeap[FHeapCount];
      SiftDown(0);
    end;
    FEntries[LIdx].NextFree := FFreeHead;
    FFreeHead := Int32(LIdx);
    if Assigned(LCb) then
      LCb(LCtx);
    Inc(Result);
  end;
end;

function TTimerHeap.Count: UInt32;
begin
  Result := FHeapCount;
end;

end.
