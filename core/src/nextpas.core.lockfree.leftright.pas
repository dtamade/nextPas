{******************************************************************************
  nextpas.core.lockfree.leftright

  Left-Right Concurrency — dual-copy concurrent read/write.

  Design:
  - Two copies of data (left and right)
  - Readers access via readIndex (0 or 1): lock-free, just read the copy
  - Writers modify the inactive copy, then flip readIndex
  - Writers wait for all readers on the old copy to finish before flipping
  - ReadIndex flips atomically, so all readers see consistent data
  - Much simpler than RCU for the same read-side performance

  Key insight: readers never block, never retry. Writers pay the cost.

  Theory: Ramalhete & Correia "Left-Right: A Concurrency Control Technique"
  Use cases: read-heavy workloads, configuration updates, routing tables.

  2026-07-06  Phase 11
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.leftright;

interface

uses
  nextpas.core.lockfree.base;

const
  LR_MAX_READERS = 64;

type
  TLeftRightResult = (lrOk, lrClosed);

  TLeftRightReadCallback = procedure(AIndex: Int32; AData: Pointer);
  TLeftRightWriteCallback = procedure(AIndex: Int32; AData: Pointer);
  TLeftRightCopyCallback = procedure(ASrc, ADst: Int32; AData: Pointer);

  {** @desc Left-Right 并发控制
    @details 双副本交替读写。读无锁，写等待所有读者完成后翻转。
      比 RCU 更结构化，比 RwLock 读性能更好。 }
  TLeftRight = class
  private
    FReadIndex: Int32;
    FReaders: array[0..LR_MAX_READERS - 1] of Int64;
    FReaderCount: Int32;
    FWriteLock: Int32;
    FClosed: Int32;
    procedure ToggleIndex;
    function HasReaders(AIndex: Int32): Boolean;
  public
    constructor Create;
    { Read side: lock-free }
    function EnterRead: Int32;
    procedure ExitRead(AIndex: Int32);
    { Write side: exclusive }
    procedure Write(AWriteCallback: TLeftRightWriteCallback; ACopyCallback: TLeftRightCopyCallback; AData: Pointer);
    { State }
    function GetReadIndex: Int32;
    function GetReaderCount: Int32;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TLeftRight.Create;
var
  LI: Int32;
begin
  inherited Create;
  FReadIndex := 0;
  for LI := 0 to LR_MAX_READERS - 1 do
    FReaders[LI] := 0;
  FReaderCount := 0;
  FWriteLock := 0;
  FClosed := 0;
end;

function TLeftRight.EnterRead: Int32;
var
  LIdx: Int32;
  LOldVal, LNewVal: Int64;
  LReadIdx: Int32;
begin
  { Atomically get a reader slot }
  repeat
    LIdx := AtomicLoad32(FReaderCount, moAcquire);
    if LIdx >= LR_MAX_READERS then
    begin
      ThreadSwitch;
      Continue;
    end;
  until AtomicCompareExchange32(FReaderCount, LIdx, LIdx + 1, moAcqRel) = LIdx;
  { Increment the counter for the current read index using CAS }
  LReadIdx := AtomicLoad32(FReadIndex, moAcquire);
  repeat
    LOldVal := AtomicLoad64(FReaders[LReadIdx], moAcquire);
    LNewVal := LOldVal + 1;
  until AtomicCompareExchange64(FReaders[LReadIdx], LOldVal, LNewVal, moAcqRel) = LOldVal;
  Result := LIdx;
end;

procedure TLeftRight.ExitRead(AIndex: Int32);
var
  LOldVal, LNewVal: Int64;
  LReadIdx: Int32;
begin
  { Decrement the counter for the current read index using CAS }
  LReadIdx := AtomicLoad32(FReadIndex, moAcquire);
  repeat
    LOldVal := AtomicLoad64(FReaders[LReadIdx], moAcquire);
    LNewVal := LOldVal - 1;
  until AtomicCompareExchange64(FReaders[LReadIdx], LOldVal, LNewVal, moAcqRel) = LOldVal;
end;

function TLeftRight.HasReaders(AIndex: Int32): Boolean;
begin
  Result := AtomicLoad64(FReaders[AIndex], moAcquire) > 0;
end;

procedure TLeftRight.ToggleIndex;
var
  LOld, LNew: Int32;
begin
  repeat
    LOld := AtomicLoad32(FReadIndex, moAcquire);
    LNew := 1 - LOld;
  until AtomicCompareExchange32(FReadIndex, LOld, LNew, moAcqRel) = LOld;
end;

procedure TLeftRight.Write(AWriteCallback: TLeftRightWriteCallback; ACopyCallback: TLeftRightCopyCallback; AData: Pointer);
var
  LInactive, LActive: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  { Acquire write lock }
  while AtomicCompareExchange32(FWriteLock, 1, 0, moAcqRel) <> 0 do
    ThreadSwitch;
  try
    { Step 1: Write to inactive copy }
    LActive := AtomicLoad32(FReadIndex, moAcquire);
    LInactive := 1 - LActive;
    AWriteCallback(LInactive, AData);
    { Step 2: Toggle read index so readers see the updated copy }
    ToggleIndex;
    { Step 3: Wait for all readers on the old (now inactive) copy to finish }
    while HasReaders(LActive) do
      ThreadSwitch;
    { Step 4: Copy the update to the other copy (now inactive) }
    ACopyCallback(LInactive, LActive, AData);
  finally
    AtomicStore32(FWriteLock, 0, moRelease);
  end;
end;

function TLeftRight.GetReadIndex: Int32;
begin
  Result := AtomicLoad32(FReadIndex, moAcquire);
end;

function TLeftRight.GetReaderCount: Int32;
begin
  Result := AtomicLoad32(FReaderCount, moAcquire);
end;

procedure TLeftRight.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TLeftRight.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
