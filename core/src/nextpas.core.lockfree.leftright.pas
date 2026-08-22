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
    destructor Destroy; override;
    { Read side: lock-free }
    function EnterRead: Int32;
    procedure ExitRead(AIndex: Int32);
    { Write side: exclusive }
    procedure Write(AWriteCallback: TLeftRightWriteCallback; ACopyCallback: TLeftRightCopyCallback; AData: Pointer);
    { State }
    function GetReadIndex: Int32; inline;
    function GetReaderCount: Int32; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
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
  LReadIdx: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(-1);
  while True do
  begin
    LReadIdx := atomic_load(FReadIndex, mo_acquire);
    atomic_fetch_add_64(FReaders[LReadIdx], 1, mo_acq_rel);
    if atomic_load(FReadIndex, mo_acquire) = LReadIdx then
      Break;
    atomic_fetch_sub_64(FReaders[LReadIdx], 1, mo_release);
  end;
  atomic_fetch_add(FReaderCount, 1, mo_acq_rel);
  Result := LReadIdx;
end;

procedure TLeftRight.ExitRead(AIndex: Int32);
var
  LReaders: Int64;
  LTotalReaders: Int32;
begin
  if (AIndex < 0) or (AIndex > 1) then
    Exit;
  repeat
    LReaders := atomic_load_64(FReaders[AIndex], mo_acquire);
    if LReaders <= 0 then
      Exit;
  until atomic_compare_exchange_strong_64(FReaders[AIndex], LReaders, LReaders - 1, mo_release, mo_relaxed);
  repeat
    LTotalReaders := atomic_load(FReaderCount, mo_acquire);
    if LTotalReaders <= 0 then
      Exit;
  until atomic_compare_exchange_strong(FReaderCount, LTotalReaders, LTotalReaders - 1, mo_release, mo_relaxed);
end;

function TLeftRight.HasReaders(AIndex: Int32): Boolean;
begin
  Result := atomic_load_64(FReaders[AIndex], mo_acquire) > 0;
end;

procedure TLeftRight.ToggleIndex;
var
  LOld, LNew: Int32;
begin
  repeat
    LOld := atomic_load(FReadIndex, mo_acquire);
    LNew := 1 - LOld;
  until atomic_compare_exchange_strong(FReadIndex, LOld, LNew, mo_acq_rel, mo_acquire);
end;

procedure TLeftRight.Write(AWriteCallback: TLeftRightWriteCallback; ACopyCallback: TLeftRightCopyCallback; AData: Pointer);
var
  LInactive, LActive: Int32;
  LCasExpected: Int32;
begin
  if not Assigned(AWriteCallback) or not Assigned(ACopyCallback) then
    raise EArgumentError.Create('TLeftRight.Write: callbacks must not be nil');
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit;
  { Acquire write lock }
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FWriteLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit;
    ThreadSwitch;
  end;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit;
    { Step 1: Write to inactive copy }
    LActive := atomic_load(FReadIndex, mo_acquire);
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
    atomic_store(FWriteLock, 0, mo_release);
  end;
end;

function TLeftRight.GetReadIndex: Int32; inline;
begin
  Result := atomic_load(FReadIndex, mo_acquire);
end;

function TLeftRight.GetReaderCount: Int32; inline;
begin
  Result := atomic_load(FReaderCount, mo_acquire);
end;

procedure TLeftRight.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TLeftRight.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TLeftRight.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
